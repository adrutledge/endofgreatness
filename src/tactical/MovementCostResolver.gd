class_name MovementCostResolver
extends Node

## Resolves movement costs and restrictions per unit type and terrain.
##
## Data-driven: reads terrain costs from data/rules/terrain_types.json and
## global constants from data/rules/terrain_movement.json.
##
## Ground units pay MP per hex entered based on terrain type + movement mode.
## Aerospace units use thrust-based movement (separate resolver).

const HexMap = preload("res://src/data/HexMap.gd")

static var _terrain_cache: Array = []
static var _movement_config: Dictionary = {}


static func _ensure_loaded() -> void:
	if not _terrain_cache.is_empty():
		return
	var file = FileAccess.open("res://data/rules/terrain_types.json", FileAccess.READ)
	if file:
		var j = JSON.new()
		if j.parse(file.get_as_text()) == OK:
			_terrain_cache = j.data.get("terrain_types", [])

	var cfg_file = FileAccess.open("res://data/rules/terrain_movement.json", FileAccess.READ)
	if cfg_file:
		var j = JSON.new()
		if j.parse(cfg_file.get_as_text()) == OK:
			_movement_config = j.data


## Returns the terrain definition dictionary for a terrain string ID.
static func get_terrain_def(terrain_id: String) -> Dictionary:
	_ensure_loaded()
	for t in _terrain_cache:
		if t.get("id") == terrain_id:
			return t
	return {}


## Resolves MP cost to enter a hex for mechs.
## Parameters:
##   terrain_id: String terrain ID from terrain_types.json
##   mode: String — "walk", "run", or "jump"
##   current_mp: unit's remaining MP
##   elevation_change: height difference across the edge being crossed (0, 1, or 2)
##   water_depth: int — depth level for water hexes (0 if not water)
## Returns Dictionary: {can_enter (bool), mp_cost (int), blocked_by (String), effects (Array), risks (Dictionary)}
func resolve(terrain_id: String, mode: String, current_mp: int = 99,
		elevation_change: int = 0, water_depth: int = 0) -> Dictionary:
	_ensure_loaded()
	var def = get_terrain_def(terrain_id)
	if def.is_empty():
		return {"can_enter": false, "mp_cost": 999, "blocked_by": "unknown_terrain", "effects": [], "risks": {}}

	var base_cost: int
	match mode:
		"walk": base_cost = def.get("walk_cost", 1)
		"run": base_cost = def.get("run_cost", 1)
		"jump": base_cost = def.get("jump_cost", 1)
		_: base_cost = 1

	var total_cost := base_cost
	var blocked := ""
	var effects: Array = def.get("effects", []).duplicate()

	if terrain_id == "water" and water_depth > 0:
		var depths: Array = def.get("water_depths", [])
		var depth_entry: Dictionary = {}
		for d in depths:
			if d.get("depth") == water_depth:
				depth_entry = d
				break
		if not depth_entry.is_empty():
			total_cost += depth_entry.get("walk_cost_add", 0)
			if mode == "run" and not depth_entry.get("run_allowed", true):
				blocked = "no_run_water"
			for de in depth_entry.get("effects", []):
				if de not in effects:
					effects.append(de)
		else:
			blocked = "unknown_water_depth"

	if mode == "run" and terrain_id == "water" and water_depth > 0:
		blocked = "no_run_water"

	if elevation_change > 0 and mode != "jump":
		var elev_cost = _movement_config.get("walk_elevation_change_cost", 1)
		if mode == "run":
			elev_cost = _movement_config.get("run_elevation_change_cost", 1)
		var max_elev = _movement_config.get("max_elevation_change", 2)
		if elevation_change > max_elev:
			blocked = "elevation_too_steep"
		else:
			total_cost += elev_cost * elevation_change

	var risks = EffectRegistry.evaluate(effects, mode, {"mode": mode})

	if risks.get("blocked", false):
		blocked = risks.get("blocked_by", "effect_blocked")

	total_cost += risks.get("cost_mod", 0)

	if not blocked.is_empty():
		return {"can_enter": false, "mp_cost": total_cost, "blocked_by": blocked, "effects": effects, "risks": risks}
	if current_mp < total_cost:
		return {"can_enter": false, "mp_cost": total_cost, "blocked_by": "insufficient_mp", "effects": effects, "risks": risks}
	return {"can_enter": true, "mp_cost": total_cost, "blocked_by": "", "effects": effects, "risks": risks}


## Legacy compatibility: resolve using HexMap.Terrain enum.
func resolve_from_enum(terrain_enum: int, mode: String, current_mp: int = 99) -> Dictionary:
	var id := _enum_to_id(terrain_enum)
	return resolve(id, mode, current_mp)


static func _enum_to_id(e: int) -> String:
	match e:
		HexMap.Terrain.PLAINS: return "clear"
		HexMap.Terrain.FOREST: return "light_woods"
		HexMap.Terrain.MOUNTAIN: return "rough"
		HexMap.Terrain.WATER: return "water"
		HexMap.Terrain.URBAN: return "paved"
		HexMap.Terrain.DESERT: return "sand"
		HexMap.Terrain.ROUGH: return "rough"
		_: return "clear"
