class_name MegaMekParser
extends RefCounted


static func parse_mtf(file_path: String, component_defs: Dictionary = {}) -> TacticalUnit:
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

		var loc = _match_location(line)
		if loc != "":
			current_location = loc
			in_location_block = true
			continue

		if in_location_block:
			if line == "-Empty-":
				continue
			if ":" in line and _match_location(line) == "":
				in_location_block = false
				current_location = ""
			else:
				component_entries.append({
					"name": line,
					"location": current_location
				})
				continue

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
				if parts.size() > 1:
					unit.engine_type = parts[1]
			"gyro":
				unit.gyro_type = value
			"structure":
				unit.internal_structure_type = value
			"armor":
				var armor_parts = value.split(" ")
				if armor_parts.size() > 0 and armor_parts[0].is_valid_int():
					unit.total_armor_points = int(armor_parts[0])
				for ap in armor_parts:
					var stripped = ap.strip_edges().trim_prefix("(").trim_suffix(")")
					if stripped and stripped != str(unit.total_armor_points):
						unit.armor_type = stripped
			"heat sinks":
				var hs_parts = value.split(" ")
				if hs_parts.size() > 0 and hs_parts[0].is_valid_int():
					unit.heat_sink_count = int(hs_parts[0])
			"rules level":
				unit.rules_level = int(value)
			_:
				if key.ends_with(" armor"):
					armor_values[key] = int(value)

	# Sum per-location armor values for total_armor_points
	var total_armor := 0
	for ak in armor_values:
		total_armor += armor_values[ak]
	if total_armor > 0:
		unit.total_armor_points = total_armor

	if chassis != "" and model != "":
		unit.unit_name = chassis + " " + model
	elif chassis != "":
		unit.unit_name = chassis
	else:
		unit.unit_name = "Unknown"
	unit.chassis_name = chassis
	unit.model_name = model
	unit.engine_rating = engine_rating

	unit.movement_mp = raw_walk_mp
	unit.run_mp = max(1, int(ceil(raw_walk_mp * 1.5)))
	unit.jump_mp = raw_jump_mp

	var location_data: Dictionary = _build_location_data(unit.tonnage, armor_values)
	var location_map: Dictionary = {}

	for loc_name in location_data:
		var ld = location_data[loc_name]
		var cl = ComponentLocation.new()
		cl.location_name = ld.name
		cl.hit_chance = ld.hit_chance
		cl.armor = ld.armor
		cl.rear_armor = ld.get("rear_armor", 0)
		cl.structure = ld.structure
		cl.max_armor = ld.armor
		cl.max_structure = ld.structure
		location_map[ld.name] = cl

	var context := {
		"engine_rating": unit.engine_rating,
		"engine_type": unit.engine_type,
		"gyro_type": unit.gyro_type,
		"unit_tonnage": unit.tonnage,
	}

	var seen: Dictionary = {}
	for entry in component_entries:
		entry["location"] = _normalize_location(entry["location"])
		var raw_name = entry["name"]
		var loc_name = entry["location"]

		var norm_name = _normalize_component_name(raw_name, engine_rating)
		var key = norm_name + "|" + loc_name

		if seen.has(key):
			seen[key].critical_slots += 1
			var jc = _get_json_critical_slots(norm_name, component_defs)
			if jc <= 1:
				var def = component_defs.get(norm_name)
				if def:
					seen[key].tonnage += _compute_def_weight(def, context, norm_name)
				else:
					seen[key].tonnage += 0.0
		else:
			var comp = Component.new()
			comp.component_name = norm_name
			comp.critical_slots = 1
			comp.location = location_map.get(loc_name, null)
			comp.status = Enums.ComponentStatus.UNDAMAGED

			if component_defs.has(norm_name):
				var def = component_defs[norm_name]
				comp.tonnage = _compute_def_weight(def, context, norm_name)
				comp.cost = def.get("cost", 0)
				comp.tech_base = def.get("tech_base", "")
				var qr = def.get("quality_range", {})
				comp.quality_range = Vector2(qr.get("min", 1), qr.get("max", 5))
				comp.repair_difficulty = def.get("repair_difficulty", 1)
				comp.tech_level = def.get("tech_level", 1)
				var fhs = def.get("slot_free_heat_sinks", 0)
				if fhs > 0:
					unit.slot_free_heat_sinks = fhs
				var whs = def.get("weight_free_heat_sinks", 0)
				if whs > 0:
					unit.weight_free_heat_sinks = whs
				seen[key] = comp
			else:
				comp.tonnage = 0.0
				comp.cost = 1000
				comp.tech_base = "inner_sphere"
				comp.quality_range = Vector2(1, 5)
				comp.repair_difficulty = 1
				comp.tech_level = 1
				seen[key] = comp

	for key in seen:
		var comp = seen[key]
		var cname = comp.component_name
		if component_defs.has(cname):
			var def = component_defs[cname]
			var json_crit = def.get("critical_slots", 1)
			if json_crit > comp.critical_slots:
				comp.critical_slots = json_crit
		unit.components.append(comp)

	var jj_weight = _get_jump_jet_weight(unit.tonnage)
	if jj_weight > 0.0:
		for c in unit.components:
			if c.component_name == "Jump Jet":
				c.tonnage = c.critical_slots * jj_weight

	for c in unit.components:
		if c.component_name == "Hatchet":
			c.tonnage = ceil(unit.tonnage * 0.1) * 0.5

	return unit


static func parse_blk(file_path: String, component_defs: Dictionary = {}) -> TacticalUnit:
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

		if line.begins_with("<") and "</" in line and line.ends_with(">"):
			var gt = line.find(">")
			var tag = line.substr(1, gt - 1).strip_edges()
			var closepos = line.find("</", gt)
			var content = line.substr(gt + 1, closepos - gt - 1).strip_edges()
			tags[tag] = content
			continue

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

	unit.unit_name = tags.get("Name", tags.get("name", "Unknown"))
	unit.chassis_name = unit.unit_name
	var tonnage_str = tags.get("tonnage", tags.get("mass", "0"))
	unit.tonnage = float(tonnage_str)

	var cruise = int(tags.get("cruiseMP", tags.get("SafeThrust", "0")))
	unit.movement_mp = cruise
	unit.run_mp = max(1, int(ceil(cruise * 1.5)))

	var blk_armor = tags.get("_armor_values", [])
	if blk_armor.size() > 0:
		var total := 0
		for v in blk_armor:
			total += v
		unit.total_armor_points = total
	var motion_type = tags.get("motion_type", "")
	unit.motion_type = motion_type
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
	unit.engine_rating = engine_rating
	if engine_prefix != "":
		unit.engine_type = engine_prefix.replace(" Engine", "")
	var blk_ctx := {"engine_rating": unit.engine_rating, "engine_type": unit.engine_type,
		"gyro_type": unit.gyro_type, "unit_tonnage": unit.tonnage, "unit_type": "VEHICLE"}
	if engine_rating > 0 and engine_prefix != "":
		var engine_name = engine_prefix + " " + str(engine_rating)
		var comp = Component.new()
		comp.component_name = engine_name
		comp.critical_slots = 1
		comp.location = location_map.get("Front", null)
		comp.status = Enums.ComponentStatus.UNDAMAGED
		if component_defs.has(engine_name):
			var def = component_defs[engine_name]
			comp.tonnage = _compute_def_weight(def, blk_ctx, engine_name)
			comp.cost = def.get("cost", 0)
			comp.tech_base = def.get("tech_base", "")
			var qr = def.get("quality_range", {})
			comp.quality_range = Vector2(qr.get("min", 1), qr.get("max", 5))
			comp.repair_difficulty = def.get("repair_difficulty", 1)
			comp.tech_level = def.get("tech_level", 1)
			var fhs_blk = def.get("slot_free_heat_sinks", 0)
			if fhs_blk > 0:
				unit.slot_free_heat_sinks = fhs_blk
			var whs_blk = def.get("weight_free_heat_sinks", 0)
			if whs_blk > 0:
				unit.weight_free_heat_sinks = whs_blk
		else:
			comp.tonnage = 0.0
			comp.cost = 1000
			comp.tech_base = "inner_sphere"
			comp.quality_range = Vector2(1, 5)
			comp.repair_difficulty = 1
			comp.tech_level = 1
		unit.components.append(comp)

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
				var jc = _get_json_critical_slots(norm_name, component_defs)
				if jc <= 1:
					var def = component_defs.get(norm_name)
					if def:
						seen[key].tonnage += _compute_def_weight(def, blk_ctx, norm_name)
					else:
						seen[key].tonnage += 0.0
			else:
				var comp = Component.new()
				comp.component_name = norm_name
				comp.critical_slots = 1
				comp.location = location_map.get(loc_name, null)
				comp.status = Enums.ComponentStatus.UNDAMAGED
				if component_defs.has(norm_name):
					var def = component_defs[norm_name]
					comp.tonnage = _compute_def_weight(def, blk_ctx, norm_name)
					comp.cost = def.get("cost", 0)
					comp.tech_base = def.get("tech_base", "")
					var qr = def.get("quality_range", {})
					comp.quality_range = Vector2(qr.get("min", 1), qr.get("max", 5))
					comp.repair_difficulty = def.get("repair_difficulty", 1)
					comp.tech_level = def.get("tech_level", 1)
				else:
					comp.tonnage = 0.0
					comp.cost = 1000
					comp.tech_base = "inner_sphere"
					comp.quality_range = Vector2(1, 5)
					comp.repair_difficulty = 1
					comp.tech_level = 1
				seen[key] = comp

	for key in seen:
		var comp = seen[key]
		var cname = comp.component_name
		if component_defs.has(cname):
			var def = component_defs[cname]
			var json_crit = def.get("critical_slots", 1)
			if json_crit > comp.critical_slots:
				comp.critical_slots = json_crit
		unit.components.append(comp)

	# --- Add mandatory vehicle equipment ---
	# Power amplifier (10% of energy weapon tonnage, min 0.5t)
	var energy_weight := 0.0
	var has_energy := false
	for c in unit.components:
		var n = c.component_name.to_lower()
		if n in ["medium laser", "large laser", "small laser", "ppc", "flamer"]:
			energy_weight += c.tonnage
			has_energy = true
	if has_energy:
		var pa_weight: float = 0.5 if energy_weight * 0.10 < 0.5 else energy_weight * 0.10
		var pa = Component.new()
		pa.component_name = "Power Amplifier"
		pa.critical_slots = 1
		pa.tonnage = pa_weight
		pa.status = Enums.ComponentStatus.UNDAMAGED
		unit.components.append(pa)

	# Lift equipment for Hover/VTOL/WiGE (10% of tonnage, min 0.5t)
	var lift_types = ["hover", "vtol", "wige"]
	if motion_type.to_lower() in lift_types:
		var lift_weight: float = 0.5 if unit.tonnage * 0.10 < 0.5 else unit.tonnage * 0.10
		var le = Component.new()
		le.component_name = "Lift Equipment"
		le.critical_slots = 1
		le.tonnage = lift_weight
		le.status = Enums.ComponentStatus.UNDAMAGED
		unit.components.append(le)

	return unit


static func _match_location(raw_line: String) -> String:
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


static func _normalize_location(loc: String) -> String:
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


static func _normalize_component_name(name: String, engine_rating: int) -> String:
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


static func _build_location_data(tonnage: float, armor_values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var t = max(1.0, tonnage)

	var structure_ct = int(round(t / 3.2))
	var structure_st = int(round(t / 3.2))
	var structure_arm = max(3, int(ceil(t / 10.0)) + 4)
	var structure_leg = max(3, int(ceil(t / 10.0)) + 8)

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

	var rear_keys = {
		"Center Torso": "rtc armor",
		"Left Torso": "rtl armor",
		"Right Torso": "rtr armor",
	}

	for display_name in armor_keys:
		var ak = armor_keys[display_name]
		var armor = armor_values.get(ak, 0)
		var rear = armor_values.get(rear_keys.get(display_name, ""), 0)
		var structure = struct_map[display_name]
		var hc = hit_chances[display_name]
		result[display_name] = {
			"name": display_name,
			"armor": armor,
			"rear_armor": rear,
			"structure": structure,
			"hit_chance": hc,
		}

	return result


static func _get_suspension_factor(motion_type: String, tonnage: float) -> int:
	var data = _load_suspension_factors()
	var entry = data.get(motion_type)
	if entry == null:
		return 0
	if entry is int:
		return entry
	if entry is Array:
		for bracket in entry:
			if tonnage <= float(bracket.get("max_tonnage", 999)):
				return bracket.get("factor", 0)
	return 0


static var _suspension_cache = null
static func _load_suspension_factors() -> Dictionary:
	if _suspension_cache != null:
		return _suspension_cache
	var file = FileAccess.open("res://data/rules/suspension_factors.json", FileAccess.READ)
	if not file:
		_suspension_cache = {}
		return _suspension_cache
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK:
		_suspension_cache = {}
		return _suspension_cache
	_suspension_cache = j.data
	return _suspension_cache


static func _compute_def_weight(def: Dictionary, context: Dictionary, component_name: String = "") -> float:
	var wc = def.get("weight_calc", {})
	var wtype = wc.get("type", "static")
	match wtype:
		"fusion_engine":
			var rating = context.get("engine_rating", 0)
			var etype = context.get("engine_type", "Standard")
			var mults = wc.get("type_multipliers", {})
			var mult = mults.get(etype, 1.0)
			if context.get("unit_type", "") == "VEHICLE":
				return def.get("vehicle_tonnage", float(rating) * 0.1)
			var base = _STANDARD_FUSION_WEIGHTS.get(rating, float(rating) * 0.1)
			return base * mult
		"gyro":
			var rating = context.get("engine_rating", 0)
			var gtype = context.get("gyro_type", "Standard")
			var base = max(1.0, ceil(rating / 100.0))
			var mults = wc.get("type_multipliers", {})
			var mult = mults.get(gtype, 1.0)
			return base * mult
		"jump_jet":
			var t = context.get("unit_tonnage", 20.0)
			var factor = 0.5
			if t > 85.0:
				factor = 2.0
			elif t > 55.0:
				factor = 1.0
			return factor
		"hatchet":
			var t = context.get("unit_tonnage", 20.0)
			return ceil(t * 0.1) * 0.5
		_:
			return wc.get("value", def.get("tonnage", 0.0))


static func _get_json_critical_slots(name: String, defs: Dictionary) -> int:
	if defs.has(name):
		return defs[name].get("critical_slots", 1)
	return 1


static func _get_json_tonnage(name: String, defs: Dictionary) -> float:
	if defs.has(name):
		return defs[name].get("tonnage", 0.0)
	return 0.0


static func _is_engine_component_name(name: String) -> bool:
	var lower = name.to_lower()
	var prefixes = ["fusion engine", "xl engine", "light engine", "compact engine", "xxl engine", "heavy engine", "ice engine", "fuel cell engine"]
	for p in prefixes:
		if lower.begins_with(p):
			return true
	return false


const _STANDARD_FUSION_WEIGHTS: Dictionary = {
	10: 0.5, 15: 0.5, 20: 0.5, 25: 1.0, 30: 1.0, 35: 1.0,
	40: 1.5, 45: 1.5, 50: 1.5, 55: 2.0, 60: 2.0, 65: 2.0,
	70: 2.5, 75: 2.5, 80: 2.5, 85: 3.0, 90: 3.0, 95: 3.0,
	100: 3.0, 105: 3.5, 110: 3.5, 115: 3.5, 120: 4.0, 125: 4.0,
	130: 4.0, 135: 4.5, 140: 4.5, 145: 4.5, 150: 5.5, 155: 5.5,
	160: 5.5, 165: 6.0, 170: 6.5, 175: 7.0, 180: 7.0, 185: 7.5,
	190: 7.5, 195: 8.0, 200: 8.5, 205: 8.5, 210: 9.0, 215: 9.5,
	220: 9.5, 225: 10.0, 230: 10.5, 235: 11.0, 240: 11.5, 245: 11.5,
	250: 12.5, 255: 13.0, 260: 13.5, 265: 14.0, 270: 14.5, 275: 15.5,
	280: 16.0, 285: 16.5, 290: 17.5, 295: 18.0, 300: 19.0, 305: 19.5,
	310: 20.5, 315: 21.0, 320: 22.5, 325: 23.5, 330: 24.5, 335: 25.5,
	340: 27.0, 345: 28.0, 350: 29.5, 355: 30.5, 360: 32.0, 365: 33.0,
	370: 34.5, 375: 35.5, 380: 37.0, 385: 38.5, 390: 40.0, 395: 41.5,
	400: 52.5,
}


static func _get_jump_jet_weight(tonnage: float) -> float:
	if tonnage <= 55.0:
		return 0.5
	elif tonnage <= 85.0:
		return 1.0
	else:
		return 2.0
