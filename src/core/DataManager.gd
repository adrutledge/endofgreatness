extends Node

var factions: Dictionary = {}
var unit_templates: Dictionary = {}
var component_defs: Dictionary = {}
var systems_data: Dictionary = {}

func _ready() -> void:
	load_all_data()

func load_all_data() -> void:
	load_factions()
	load_components()
	load_unit_templates()
	load_starmap()
	load_timeline()

func load_factions() -> void:
	var dir = DirAccess.open("res://data/factions")
	if not dir:
		push_warning("Factions directory not found")
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path = "res://data/factions/" + file_name
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var json_str = file.get_as_text()
				var json = JSON.new()
				if json.parse(json_str) == OK:
					var data = json.data
					var faction = Faction.new()
					faction.faction_name = data.get("name", "")
					faction.short_code = data.get("short_code", "")
					faction.color = Color(data.get("color", "#ffffff"))
					faction.home_worlds = data.get("home_worlds", [])
					faction.unique_units = data.get("unique_units", [])
					faction.unique_components = data.get("unique_components", [])
					faction.reputation_levels_gates = data.get("reputation_levels_gates", {})
					faction.contracts_offered = data.get("contracts_offered", [])
					faction.allies = data.get("allies", [])
					faction.enemies = data.get("enemies", [])
					faction.is_rebel = data.get("is_rebel", false)
					faction.is_pirate = data.get("is_pirate", false)
					faction.is_civilian = data.get("is_civilian", false)
					factions[faction.short_code] = faction
					GameState.register_faction(faction)
		file_name = dir.get_next()

func load_components() -> void:
	var dir = DirAccess.open("res://data/components")
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path = "res://data/components/" + file_name
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var json_str = file.get_as_text()
				var json = JSON.new()
				if json.parse(json_str) == OK:
					var data = json.data
					component_defs[data.get("name", "")] = data
		file_name = dir.get_next()

func load_unit_templates() -> void:
	_scan_unit_dir("res://data/units")

func _scan_unit_dir(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var file_path = path + "/" + file_name
		if file_name.ends_with(".mtf"):
			var unit = parse_mtf(file_path)
			if unit:
				unit_templates[unit.unit_name] = unit
		elif file_name.ends_with(".blk"):
			var unit = parse_blk(file_path)
			if unit:
				unit_templates[unit.unit_name] = unit
		elif dir.current_is_dir() and not file_name.begins_with("."):
			_scan_unit_dir(file_path)
		file_name = dir.get_next()

func load_starmap() -> void:
	var file = FileAccess.open("res://data/starmap.json", FileAccess.READ)
	if not file:
		push_warning("starmap.json not found")
		return
	var json_str = file.get_as_text()
	var json = JSON.new()
	if json.parse(json_str) == OK:
		var data = json.data
		for system in data:
			systems_data[system.get("name", "")] = system

func load_timeline() -> void:
	var file = FileAccess.open("res://data/timeline_events.json", FileAccess.READ)
	if not file:
		return
	var json_str = file.get_as_text()
	var json = JSON.new()
	if json.parse(json_str) == OK:
		GameState.set("timeline_events", json.data)

func parse_mtf(file_path: String) -> TacticalUnit:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return null

	var unit = TacticalUnit.new()
	var lines = file.get_as_text().split("\n")

	var chassis = ""
	var model = ""
	var engine_rating = 0
	var raw_walk_mp = 0
	var raw_jump_mp = 0

	var armor_values: Dictionary = {}
	var component_entries: Array = []

	var current_location = ""
	var in_location_block = false

	for raw_line in lines:
		var line = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with("Weapons:"):
			continue

		# Detect location block headers
		var loc = _match_location(line)
		if loc != "":
			current_location = loc
			in_location_block = true
			continue

		if in_location_block:
			if line == "-Empty-":
				continue
			# Exit location block on non-location k:v lines (fluff, manufacturer, etc.)
			if ":" in line and _match_location(line) == "":
				in_location_block = false
				current_location = ""
				# fall through to header parsing below
			else:
				component_entries.append({
					"name": line,
					"location": current_location
				})
				continue

		# Parse key:value header fields
		var colon_pos = line.find(":")
		if colon_pos == -1:
			continue
		var key = line.substr(0, colon_pos).strip_edges().to_lower()
		var value = line.substr(colon_pos + 1).strip_edges()

		match key:
			"chassis":
				chassis = value
			"model":
				model = value
			"mass":
				unit.tonnage = float(value)
			"walk mp":
				raw_walk_mp = int(value)
			"jump mp":
				raw_jump_mp = int(value)
			"unittype":
				var tv = value.to_lower()
				if tv in ["0", "mech"]:
					unit.unit_type = Enums.UnitType.MECH
				elif tv in ["1", "vehicle"]:
					unit.unit_type = Enums.UnitType.VEHICLE
				elif tv in ["2", "infantry"]:
					unit.unit_type = Enums.UnitType.INFANTRY
			"name":
				pass
			"config":
				if value.to_lower() in ["biped", "tripod", "quad", "lamm"]:
					unit.unit_type = Enums.UnitType.MECH
			"engine":
				var parts = value.split(" ")
				if parts.size() > 0 and parts[0].is_valid_int():
					engine_rating = int(parts[0])
			_:
				# Check for armor fields: LA armor, RA armor, LT armor, etc.
				if key.ends_with(" armor"):
					armor_values[key] = int(value)

	if chassis != "" and model != "":
		unit.unit_name = chassis + " " + model
	elif chassis != "":
		unit.unit_name = chassis
	else:
		unit.unit_name = "Unknown"

	# Compute movement from MTF raw values
	unit.movement_mp = raw_walk_mp
	unit.run_mp = max(1, int(ceil(raw_walk_mp * 1.5)))
	unit.jump_mp = raw_jump_mp

	# Build location data (armor + structure)
	var location_data: Dictionary = _build_location_data(unit.tonnage, armor_values)
	var location_map: Dictionary = {}

	for loc_name in location_data:
		var ld = location_data[loc_name]
		var cl = ComponentLocation.new()
		cl.location_name = ld.name
		cl.hit_chance = ld.hit_chance
		cl.armor = ld.armor
		cl.structure = ld.structure
		cl.max_armor = ld.armor
		cl.max_structure = ld.structure
		location_map[ld.name] = cl

	# Create Component objects from slot entries, deduplicating by (name, location)
	var seen: Dictionary = {}
	for entry in component_entries:
		entry["location"] = _normalize_location(entry["location"])
		var raw_name = entry["name"]
		var loc_name = entry["location"]

		var norm_name = _normalize_component_name(raw_name, engine_rating)
		var key = norm_name + "|" + loc_name

		if seen.has(key):
			seen[key].critical_slots += 1
		else:
			var comp = Component.new()
			comp.component_name = norm_name
			comp.critical_slots = 1
			comp.location = location_map.get(loc_name, null)
			comp.status = Enums.ComponentStatus.UNDAMAGED

			# Fill from component_defs if available
			if component_defs.has(norm_name):
				var def = component_defs[norm_name]
				comp.tonnage = def.get("tonnage", 0.0)
				comp.cost = def.get("cost", 0)
				comp.tech_base = def.get("tech_base", "")
				var qr = def.get("quality_range", {})
				comp.quality_range = Vector2(qr.get("min", 1), qr.get("max", 5))
				comp.repair_difficulty = def.get("repair_difficulty", 1)
			else:
				comp.tonnage = 0.0
				comp.cost = 1000
				comp.tech_base = "inner_sphere"
				comp.quality_range = Vector2(1, 5)
				comp.repair_difficulty = 1

			seen[key] = comp

	for key in seen:
		unit.components.append(seen[key])

	# Recalculate jump jet tonnage based on mech weight (BT rules)
	var jj_weight = _get_jump_jet_weight(unit.tonnage)
	if jj_weight > 0.0:
		for c in unit.components:
			if c.component_name == "Jump Jet":
				c.tonnage = c.critical_slots * jj_weight

	# Recalculate hatchet tonnage = tonnage / 20 (round up to nearest 0.5)
	for c in unit.components:
		if c.component_name == "Hatchet":
			c.tonnage = ceil(unit.tonnage * 0.1) * 0.5

	return unit

func parse_blk(file_path: String) -> TacticalUnit:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return null

	var lines = file.get_as_text().split("\n")
	var unit = TacticalUnit.new()
	unit.unit_type = Enums.UnitType.VEHICLE
	unit.jump_mp = 0

	var tags = {}
	var current_tag = ""
	var content_lines = []
	var armor_values = []
	var in_armor = false
	var equipment_sections = []
	var equip_section = ""
	var equip_items = []
	var in_equip = false

	for raw_line in lines:
		var line = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue

		# Closing tag on its own line: </tag>
		if line.begins_with("</") and line.ends_with(">"):
			var tag_name = line.substr(2, line.length() - 3).strip_edges()
			if in_armor:
				in_armor = false
				tags["_armor_values"] = armor_values.duplicate()
				armor_values = []
			elif in_equip:
				in_equip = false
				equipment_sections.append({"section": equip_section, "items": equip_items.duplicate()})
				equip_items = []
			else:
				tags[tag_name] = "\n".join(content_lines).strip_edges()
			current_tag = ""
			content_lines = []
			continue

		# Self-contained inline tag: <tag>content</tag>
		if line.begins_with("<") and "</" in line and line.ends_with(">"):
			var gt = line.find(">")
			var tag = line.substr(1, gt - 1).strip_edges()
			var closepos = line.find("</", gt)
			var content = line.substr(gt + 1, closepos - gt - 1).strip_edges()
			tags[tag] = content
			continue

		# Opening tag on its own line: <tag>
		if line.begins_with("<") and line.ends_with(">"):
			current_tag = line.substr(1, line.length() - 2).strip_edges()
			content_lines = []
			in_armor = (current_tag == "armor")
			in_equip = current_tag.ends_with(" Equipment")
			if in_equip:
				equip_section = current_tag
				equip_items = []
			continue

		if current_tag != "":
			if in_armor:
				var v = int(line)
				armor_values.append(v)
			elif in_equip:
				if line != "":
					equip_items.append(line)
			else:
				content_lines.append(line)

	# ---- Build unit from parsed data ----
	unit.unit_name = tags.get("Name", tags.get("name", "Unknown"))
	var tonnage_str = tags.get("tonnage", tags.get("mass", "0"))
	unit.tonnage = float(tonnage_str)

	var cruise = int(tags.get("cruiseMP", tags.get("SafeThrust", "0")))
	unit.movement_mp = cruise
	unit.run_mp = max(1, int(ceil(cruise * 1.5)))

	# ---- Build vehicle locations ----
	var blk_armor = tags.get("_armor_values", [])
	var motion_type = tags.get("motion_type", "")
	var loc_names = ["Front", "Left Side", "Right Side", "Rear", "Turret"]
	var loc_hit = { "Front": 0.2778, "Left Side": 0.1667, "Right Side": 0.1667, "Rear": 0.1111, "Turret": 0.2778 }
	var loc_struct = { "Front": 10, "Left Side": 6, "Right Side": 6, "Rear": 6, "Turret": 8 }

	if motion_type == "VTOL":
		loc_names = ["Front", "Left Side", "Right Side", "Rear", "Rotor"]
		loc_hit = { "Front": 0.2778, "Left Side": 0.1667, "Right Side": 0.1667, "Rear": 0.1111, "Rotor": 0.2778 }
		loc_struct = { "Front": 10, "Left Side": 6, "Right Side": 6, "Rear": 6, "Rotor": 8 }
	elif motion_type == "WiGE":
		loc_names = ["Front", "Left Side", "Right Side", "Rear"]
		loc_hit = { "Front": 0.5556, "Left Side": 0.1667, "Right Side": 0.1667, "Rear": 0.1111 }
		loc_struct = { "Front": 10, "Left Side": 6, "Right Side": 6, "Rear": 6 }
	elif motion_type == "Aerodyne":
		loc_names = ["Nose", "Left Wing", "Right Wing", "Aft"]
		loc_hit = { "Nose": 0.3333, "Left Wing": 0.1944, "Right Wing": 0.2500, "Aft": 0.2222 }
		loc_struct = { "Nose": 8, "Left Wing": 5, "Right Wing": 5, "Aft": 5 }
	var location_map = {}

	for i in range(min(blk_armor.size(), loc_names.size())):
		var name = loc_names[i]
		var armor_val = blk_armor[i]
		var cl = ComponentLocation.new()
		cl.location_name = name
		cl.armor = armor_val
		cl.max_armor = armor_val
		cl.hit_chance = loc_hit.get(name, 0.1)
		cl.structure = loc_struct.get(name, 10)
		cl.max_structure = loc_struct.get(name, 10)
		location_map[name] = cl

	# ---- Create engine component from type and rating ----
	var engine_type_code = int(tags.get("engine_type", "0"))
	var suspension = _get_suspension_factor(motion_type, unit.tonnage)
	var base_rating = int(unit.tonnage * unit.movement_mp) - suspension
	if base_rating % 5 != 0:
		base_rating = base_rating + (5 - base_rating % 5)
	var engine_rating = max(0, base_rating)
	var engine_prefix = ""
	match engine_type_code:
		0, 2:
			engine_prefix = "Fusion Engine"
		1:
			engine_prefix = "ICE Engine"
		3:
			engine_prefix = "Light Engine"
		4:
			engine_prefix = "Compact Engine"
		6:
			engine_prefix = "XL Engine"
		7:
			engine_prefix = "XXL Engine"
		8:
			engine_prefix = "Fuel Cell Engine"
	if engine_rating > 0 and engine_prefix != "":
		var engine_name = engine_prefix + " " + str(engine_rating)
		var comp = Component.new()
		comp.component_name = engine_name
		comp.critical_slots = 1
		comp.location = location_map.get("Front", null)
		comp.status = Enums.ComponentStatus.UNDAMAGED
		if component_defs.has(engine_name):
			var def = component_defs[engine_name]
			comp.tonnage = def.get("tonnage", 0.0)
			comp.cost = def.get("cost", 0)
			comp.tech_base = def.get("tech_base", "")
			var qr = def.get("quality_range", {})
			comp.quality_range = Vector2(qr.get("min", 1), qr.get("max", 5))
			comp.repair_difficulty = def.get("repair_difficulty", 1)
		else:
			comp.tonnage = 0.0
			comp.cost = 1000
			comp.tech_base = "inner_sphere"
			comp.quality_range = Vector2(1, 5)
			comp.repair_difficulty = 1
		unit.components.append(comp)

	# ---- Create components from equipment ----
	var seen = {}
	for section in equipment_sections:
		var sec_name = section.section
		var loc_name = sec_name.replace(" Equipment", "").strip_edges()
		if loc_name == "Body":
			loc_name = "Front"
		elif loc_name == "Left":
			loc_name = "Left Side"
		elif loc_name == "Right":
			loc_name = "Right Side"
		elif loc_name == "Wings":
			loc_name = "Left Wing"
		elif loc_name == "Fuselage":
			loc_name = "Nose"
		for item_name in section.items:
			var norm_name = _normalize_component_name(item_name, 0)
			var key = norm_name + "|" + loc_name
			if seen.has(key):
				seen[key].critical_slots += 1
			else:
				var comp = Component.new()
				comp.component_name = norm_name
				comp.critical_slots = 1
				comp.location = location_map.get(loc_name, null)
				comp.status = Enums.ComponentStatus.UNDAMAGED
				if component_defs.has(norm_name):
					var def = component_defs[norm_name]
					comp.tonnage = def.get("tonnage", 0.0)
					comp.cost = def.get("cost", 0)
					comp.tech_base = def.get("tech_base", "")
					var qr = def.get("quality_range", {})
					comp.quality_range = Vector2(qr.get("min", 1), qr.get("max", 5))
					comp.repair_difficulty = def.get("repair_difficulty", 1)
				else:
					comp.tonnage = 0.0
					comp.cost = 1000
					comp.tech_base = "inner_sphere"
					comp.quality_range = Vector2(1, 5)
					comp.repair_difficulty = 1
				seen[key] = comp

	for key in seen:
		unit.components.append(seen[key])

	return unit

# ----- MTF helpers -----

func _match_location(raw_line: String) -> String:
	var trimmed = raw_line.strip_edges().trim_suffix(":")
	var locs = {
		"Left Arm": "Left Arm",
		"Right Arm": "Right Arm",
		"Left Torso": "Left Torso",
		"Right Torso": "Right Torso",
		"Center Torso": "Center Torso",
		"Head": "Head",
		"Left Leg": "Left Leg",
		"Right Leg": "Right Leg",
		"Hull": "Hull",
		"Front": "Front",
		"Rear": "Rear",
		"Turret": "Turret",
	}
	if locs.has(trimmed):
		return locs[trimmed]
	return ""

func _normalize_location(loc: String) -> String:
	var m = {
		"LA": "Left Arm",
		"RA": "Right Arm",
		"LT": "Left Torso",
		"RT": "Right Torso",
		"CT": "Center Torso",
		"HD": "Head",
		"LL": "Left Leg",
		"RL": "Right Leg",
	}
	return m.get(loc, loc)

func _normalize_component_name(name: String, engine_rating: int) -> String:
	var n = name.strip_edges()

	if n.ends_with(" (R)"):
		n = n.substr(0, n.length() - 4).strip_edges()

	if n.begins_with("Communications Equipment:SIZE:"):
		n = "Communications Equipment"

	match n:
		"Shoulder":
			return "Shoulder Actuator"
		"Hip":
			return "Hip Actuator"
		"Gyro":
			return "Gyroscope"
		"Cockpit":
			return "Standard Cockpit"
		"Fusion Engine":
			if engine_rating > 0:
				return "Fusion Engine " + str(engine_rating)
			return "Fusion Engine"
		"Fusion Engine (Clan)":
			if engine_rating > 0:
				return "Fusion Engine " + str(engine_rating)
			return "Fusion Engine"
		"XL Engine":
			if engine_rating > 0:
				return "XL Engine " + str(engine_rating)
			return "XL Engine"
		"Light Engine":
			if engine_rating > 0:
				return "Light Engine " + str(engine_rating)
			return "Light Engine"
		"Heavy Engine":
			if engine_rating > 0:
				return "Heavy Engine " + str(engine_rating)
			return "Heavy Engine"
		"Compact Engine":
			if engine_rating > 0:
				return "Compact Engine " + str(engine_rating)
			return "Compact Engine"
		"Large Laser":
			return "Large Laser"
		"Medium Laser":
			return "Medium Laser"
		"Small Laser":
			return "Small Laser"
		"Machine Gun":
			return "Machine Gun"
		"PPC":
			return "PPC"
		"Flamer":
			return "Flamer"
		"Flamer (Vehicle)":
			return "Vehicle Flamer"
		"IS Vehicle Flamer Ammo":
			return "Vehicle Flamer Ammo"
		"LRM 5":
			return "LRM-5"
		"LRM 10":
			return "LRM-10"
		"LRM 15":
			return "LRM-15"
		"LRM 20":
			return "LRM-20"
		"SRM 2":
			return "SRM-2"
		"SRM 4":
			return "SRM-4"
		"SRM 6":
			return "SRM-6"
		"SRT 2":
			return "SRT-2"
		"SRT 4":
			return "SRT-4"
		"SRT 6":
			return "SRT-6"
		"LRT 5":
			return "LRT-5"
		"LRT 10":
			return "LRT-10"
		"LRT 15":
			return "LRT-15"
		"LRT 20":
			return "LRT-20"
		"AC/2":
			return "Autocannon/2"
		"AC/5":
			return "Autocannon/5"
		"AC/10":
			return "Autocannon/10"
		"AC/20":
			return "Autocannon/20"
		"Heat Sink":
			return "Heat Sink"
		"Double Heat Sink":
			return "Double Heat Sink"
		"IS Ammo MG - Full":
			return "Machine Gun Ammo"
		"IS Ammo MG - Half":
			return "Machine Gun Ammo - Half"
		"IS Machine Gun Ammo - Half":
			return "Machine Gun Ammo - Half"
		"IS Ammo SRTorpedo-6":
			return "SRT-6 Ammo"
	return n

func _build_location_data(tonnage: float, armor_values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var t = max(1.0, tonnage)

	var structure_ct = int(ceil(t / 5.0))
	var structure_st = int(ceil(t / 5.0))
	var structure_arm = max(1, int(ceil(t / 10.0)))
	var structure_leg = max(1, int(ceil(t / 10.0)))

	var hit_chances = {
		"Head": 0.0278,
		"Center Torso": 0.1944,
		"Left Torso": 0.1389,
		"Right Torso": 0.1389,
		"Left Arm": 0.1389,
		"Right Arm": 0.1389,
		"Left Leg": 0.1111,
		"Right Leg": 0.1111,
	}

	var armor_keys = {
		"Head": "hd armor",
		"Center Torso": "ct armor",
		"Left Torso": "lt armor",
		"Right Torso": "rt armor",
		"Left Arm": "la armor",
		"Right Arm": "ra armor",
		"Left Leg": "ll armor",
		"Right Leg": "rl armor",
	}

	var struct_map = {
		"Head": 3,
		"Center Torso": structure_ct,
		"Left Torso": structure_st,
		"Right Torso": structure_st,
		"Left Arm": structure_arm,
		"Right Arm": structure_arm,
		"Left Leg": structure_leg,
		"Right Leg": structure_leg,
	}

	for display_name in armor_keys:
		var ak = armor_keys[display_name]
		var armor = armor_values.get(ak, 0)
		var structure = struct_map[display_name]
		var hc = hit_chances[display_name]
		result[display_name] = {
			"name": display_name,
			"armor": armor,
			"structure": structure,
			"hit_chance": hc,
		}

	return result

func _get_suspension_factor(motion_type: String, tonnage: float) -> int:
	match motion_type:
		"Tracked":
			return 0
		"Wheeled":
			return 20
		"Hover":
			if tonnage <= 10.0: return 40
			elif tonnage <= 20.0: return 85
			elif tonnage <= 30.0: return 130
			elif tonnage <= 40.0: return 175
			else: return 235
		"VTOL":
			if tonnage <= 10.0: return 95
			elif tonnage <= 20.0: return 140
			else: return 175
		"WiGE":
			if tonnage <= 15.0: return 80
			elif tonnage <= 30.0: return 115
			elif tonnage <= 45.0: return 140
			else: return 165
		"Naval":
			return 30  # Displacement Hull
		"Hydrofoil":
			if tonnage <= 10.0: return 60
			elif tonnage <= 20.0: return 105
			elif tonnage <= 30.0: return 150
			elif tonnage <= 40.0: return 195
			elif tonnage <= 50.0: return 255
			elif tonnage <= 60.0: return 300
			elif tonnage <= 70.0: return 345
			elif tonnage <= 80.0: return 390
			elif tonnage <= 90.0: return 435
			else: return 480
		"Submarine":
			return 30
	return 0

func _get_jump_jet_weight(tonnage: float) -> float:
	if tonnage <= 55.0:
		return 0.5
	elif tonnage <= 85.0:
		return 1.0
	else:
		return 2.0
