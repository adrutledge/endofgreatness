extends Node

## Resolves movement costs and restrictions per unit type and terrain.
##
## Each unit type (mech, vehicle with motive type, aerospace) has different
## terrain costs and restrictions defined in data/unit_types/*.json and
## data/rules/terrain_movement.json.
##
## Ground units pay MP per hex entered based on terrain type.
## Aerospace units use thrust-based movement (different resolver).

const HexMap = preload("res://src/data/HexMap.gd")


## Returns the MP cost to enter a given hex.
##
## Parameters:
##   unit_type: Enums.UnitType (MECH, VEHICLE, AEROSPACE, etc.)
##   motion_type: String for vehicles — "tracked", "wheeled", "hover", "vtol", "wi_ge"
##   terrain: HexMap.Terrain value
##   current_mp: unit's remaining MP this phase
##   has_motive_damage: true if the vehicle has sustained motive damage
## Returns Dictionary: {can_enter (bool), mp_cost (int), blocked_by (String)}
func resolve(unit_type: int, motion_type: String, terrain: int, current_mp: int = 99,
		has_motive_damage: bool = false) -> Dictionary:

	if unit_type == Enums.UnitType.VEHICLE:
		return _resolve_vehicle(motion_type, terrain, current_mp, has_motive_damage)

	if unit_type == Enums.UnitType.MECH:
		return _resolve_mech(terrain, current_mp)

	return {"can_enter": true, "mp_cost": 1, "blocked_by": ""}


func _resolve_mech(terrain: int, current_mp: int) -> Dictionary:
	var cost = 1
	match terrain:
		HexMap.Terrain.PLAINS: cost = 1
		HexMap.Terrain.FOREST: cost = 2
		HexMap.Terrain.MOUNTAIN: cost = 3
		HexMap.Terrain.WATER: cost = 2
		HexMap.Terrain.URBAN: cost = 1
		HexMap.Terrain.DESERT: cost = 1
		HexMap.Terrain.ROUGH: cost = 2

	if current_mp < cost:
		return {"can_enter": false, "mp_cost": cost, "blocked_by": "insufficient_mp"}
	return {"can_enter": true, "mp_cost": cost, "blocked_by": ""}


func _resolve_vehicle(motion_type: String, terrain: int, current_mp: int, has_motive_damage: bool) -> Dictionary:
	var cost_mult = 1
	var blocked = ""

	match motion_type.to_lower():
		"hover":
			match terrain:
				HexMap.Terrain.WATER: cost_mult = 1
				HexMap.Terrain.PLAINS: cost_mult = 1
				HexMap.Terrain.DESERT: cost_mult = 1
				HexMap.Terrain.URBAN: cost_mult = 2
				HexMap.Terrain.FOREST: cost_mult = 3
				_: blocked = "impassable"

		"wheeled":
			match terrain:
				HexMap.Terrain.PLAINS: cost_mult = 1
				HexMap.Terrain.URBAN: cost_mult = 1
				HexMap.Terrain.DESERT: cost_mult = 2
				HexMap.Terrain.FOREST: cost_mult = 3
				HexMap.Terrain.ROUGH: cost_mult = 4
				_: blocked = "impassable"

		"tracked":
			match terrain:
				HexMap.Terrain.PLAINS: cost_mult = 1
				HexMap.Terrain.URBAN: cost_mult = 1
				HexMap.Terrain.DESERT: cost_mult = 1
				HexMap.Terrain.FOREST: cost_mult = 2
				HexMap.Terrain.ROUGH: cost_mult = 2
				HexMap.Terrain.WATER: cost_mult = 3
				_: blocked = "impassable"

		_:
			cost_mult = 2

	if not blocked.is_empty():
		return {"can_enter": false, "mp_cost": 999, "blocked_by": blocked}

	var motive_penalty = 2 if has_motive_damage else 0
	var cost = max(1, cost_mult + motive_penalty)

	if current_mp < cost:
		return {"can_enter": false, "mp_cost": cost, "blocked_by": "insufficient_mp"}
	return {"can_enter": true, "mp_cost": cost, "blocked_by": ""}
