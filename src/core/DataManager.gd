extends Node

var factions: Dictionary = {}
var unit_templates: Dictionary = {}
var canon_units: Dictionary = {}
var component_defs: Dictionary = {}
var systems_data: Dictionary = {}
var _parser = null


func _get_parser():
	if _parser == null:
		_parser = load("res://src/tactical/MegaMekParser.gd")
	return _parser

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
		if Helpers.debug:
			EventBus.emit_parse_error("res://data/factions/", "Directory not found")
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
					faction.is_periphery = data.get("is_periphery", false)
					factions[faction.short_code] = faction
					var snake_key = file_name.replace(".json", "")
					factions[snake_key] = faction
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
	var is_custom = path.contains("/custom")
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var file_path = path + "/" + file_name
		if file_name.ends_with(".mtf"):
			var unit = _get_parser().parse_mtf(file_path, component_defs)
			if unit:
				unit_templates[unit.unit_name] = unit
				if not is_custom:
					canon_units[unit.unit_name] = true
		elif file_name.ends_with(".blk"):
			var unit = _get_parser().parse_blk(file_path, component_defs)
			if unit:
				unit_templates[unit.unit_name] = unit
				if not is_custom:
					canon_units[unit.unit_name] = true
		elif dir.current_is_dir() and not file_name.begins_with("."):
			_scan_unit_dir(file_path)
		file_name = dir.get_next()

var _system_cache: Dictionary = {}


func get_system_detail(name: String) -> Dictionary:
	if _system_cache.has(name):
		return _system_cache[name]
	var entry = systems_data.get(name)
	if not entry or not entry.get("_file"):
		return {}
	var file = FileAccess.open(entry["_file"], FileAccess.READ)
	if not file:
		return {}
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK:
		return {}
	var detail = j.data
	_system_cache[name] = detail
	return detail


func load_starmap() -> void:
	var file = FileAccess.open("res://data/systems_index.json", FileAccess.READ)
	if not file:
		push_warning("systems_index.json not found")
		if Helpers.debug:
			EventBus.emit_parse_error("res://data/systems_index.json", "File not found")
		return
	var json_str = file.get_as_text()
	var json = JSON.new()
	if json.parse(json_str) == OK:
		var data = json.data
		if data is Array:
			for entry in data:
				var sys = {
					"name": entry.get("name", ""),
					"coordinates": {"x": entry.get("x", 0.0), "y": entry.get("y", 0.0)},
					"owner_faction": entry.get("owner_faction", ""),
					"spectral_class": entry.get("spectral_class", "G"),
					"_file": entry.get("file", ""),
				}
				systems_data[sys["name"]] = sys
	Helpers.debug_print("DataManager", "starmap loaded: %d systems" % systems_data.size())

func load_timeline() -> void:
	var file = FileAccess.open("res://data/timeline_events.json", FileAccess.READ)
	if not file:
		return
	var json_str = file.get_as_text()
	var json = JSON.new()
	if json.parse(json_str) == OK:
		GameState.set("timeline_events", json.data)

func get_variants_for_chassis(chassis: String, canon_only: bool = true) -> Array[TacticalUnit]:
	var results: Array[TacticalUnit] = []
	var lower = chassis.to_lower().strip_edges()
	for name in unit_templates:
		if canon_only and not canon_units.has(name):
			continue
		var tu = unit_templates[name]
		if tu.chassis_name.to_lower().strip_edges() == lower:
			results.append(tu)
	return results


func is_canon_unit(unit_name: String) -> bool:
	return canon_units.has(unit_name)

# ----- Faction data helpers (kept in DataManager) -----

func get_component_tech_level(component_name: String) -> int:
	var def = component_defs.get(component_name)
	return def.get("tech_level", 1) if def else 1


func is_component_available_to_faction(component_name: String, faction_code: String) -> bool:
	var tech_lvl = get_component_tech_level(component_name)
	if tech_lvl <= 1:
		return true
	var faction: Faction = GameState.factions.get(faction_code)
	if not faction:
		return false
	return faction.unique_components.has(component_name)


func get_faction_market_units(faction_code: String) -> Array[TacticalUnit]:
	var faction: Faction = GameState.factions.get(faction_code)
	var results: Array[TacticalUnit] = []
	for name in unit_templates:
		var tu = unit_templates[name]
		if tu.unit_type != Enums.UnitType.MECH:
			continue
		if tu.chassis_name.is_empty():
			continue
		var has_high_tech = false
		for c in tu.components:
			if c.tech_level >= 2:
				has_high_tech = true
				break
		if not has_high_tech:
			results.append(tu)
		elif faction and faction.unique_units.has(tu.chassis_name):
			results.append(tu)
	return results


func get_faction_market_components(faction_code: String) -> Array[String]:
	var faction: Faction = GameState.factions.get(faction_code)
	var results: Array[String] = []
	for name in component_defs:
		var def = component_defs[name]
		if def.get("tech_level", 1) <= 1:
			results.append(name)
		elif faction and faction.unique_components.has(name):
			results.append(name)
	return results
