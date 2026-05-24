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
	var dir = DirAccess.open("res://data/units")
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".mtf"):
			var file_path = "res://data/units/" + file_name
			var unit = parse_mtf(file_path)
			if unit:
				unit_templates[unit.unit_name] = unit
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
	var section = ""
	var component_data = {}
	var component_name = ""
	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("UnitType:"):
			var type_str = line.substr(9).strip_edges()
			if type_str == "0" or type_str == "Mech":
				unit.unit_type = Enums.UnitType.MECH
			elif type_str == "1" or type_str == "Vehicle":
				unit.unit_type = Enums.UnitType.VEHICLE
			elif type_str == "2" or type_str == "Infantry":
				unit.unit_type = Enums.UnitType.INFANTRY
		elif line.begins_with("Name:"):
			unit.unit_name = line.substr(5).strip_edges()
		elif line.begins_with("Tonnage:"):
			unit.tonnage = float(line.substr(8).strip_edges())
		elif line.begins_with("WalkMP:"):
			unit.movement_mp = int(line.substr(7).strip_edges())
		elif line.begins_with("block"):
			section = "block"
			component_data = {}
			component_name = ""
	return unit
