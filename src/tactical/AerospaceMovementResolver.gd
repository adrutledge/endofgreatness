extends Node

## Resolves movement for aerospace fighters, VTOLs, and conventional aircraft.
##
## Unlike ground units, aerospace uses thrust-based movement:
##   - Safe thrust: MP available without control check risk
##   - Max thrust: safe thrust + 1 (requires control check)
##   - Afterburner: beyond max thrust (requires control check, possible damage)
##
## Movement follows a pattern rather than hex-by-hex terrain costs:
##   - Straight: no thrust cost beyond base
##   - Turn: costs 1 thrust per hex-side turned, minimum 3 hexes forward between turns
##   - Loop: costs 2 thrust, ends facing opposite direction at same altitude
##   - Split-S: costs 2 thrust, ends facing opposite direction 1 altitude lower
##   - VTOL spin: costs 1 thrust, changes facing by 1 hex-side


## Returns a dict with: possible (bool), thrust_cost (int), description (String),
## requires_control_check (bool).
##
## Parameters:
##   maneuver: "straight"/"turn"/"loop"/"split_s"/"vtol_spin"
##   safe_thrust: unit's safe thrust rating
##   max_thrust: unit's maximum thrust rating
##   current_thrust: remaining thrust this turn
##   is_vtol: true for VTOLs (different costs)
func resolve(maneuver: String, safe_thrust: int, max_thrust: int, current_thrust: int,
		is_vtol: bool = false) -> Dictionary:

	match maneuver:
		"straight":
			return _resolve_straight(current_thrust)

		"turn":
			return _resolve_turn(safe_thrust, max_thrust, current_thrust)

		"loop":
			return _resolve_loop(safe_thrust, current_thrust)

		"split_s":
			return _resolve_split_s(safe_thrust, current_thrust)

		"vtol_spin":
			return _resolve_vtol_spin(current_thrust)

		_:
			return {"possible": false, "thrust_cost": 0, "requires_control_check": false, "description": "Unknown maneuver"}


func _resolve_straight(current_thrust: int) -> Dictionary:
	var cost = 0
	return {
		"possible": true,
		"thrust_cost": cost,
		"requires_control_check": false,
		"description": "Straight: 0 thrust",
	}


func _resolve_turn(safe_thrust: int, max_thrust: int, current_thrust: int) -> Dictionary:
	var cost = 1
	if current_thrust < cost:
		return {"possible": false, "thrust_cost": cost, "requires_control_check": false, "description": "Insufficient thrust for turn"}
	var requires_check = cost > safe_thrust
	return {
		"possible": true,
		"thrust_cost": cost,
		"requires_control_check": requires_check,
		"description": "Turn: %d thrust%s" % [cost, " (control check)" if requires_check else ""],
	}


func _resolve_loop(safe_thrust: int, current_thrust: int) -> Dictionary:
	var cost = 2
	if current_thrust < cost:
		return {"possible": false, "thrust_cost": cost, "requires_control_check": false, "description": "Insufficient thrust for loop"}
	var requires_check = cost > safe_thrust
	return {
		"possible": true,
		"thrust_cost": cost,
		"requires_control_check": requires_check,
		"description": "Loop: %d thrust%s" % [cost, " (control check)" if requires_check else ""],
	}


func _resolve_split_s(safe_thrust: int, current_thrust: int) -> Dictionary:
	var cost = 2
	if current_thrust < cost:
		return {"possible": false, "thrust_cost": cost, "requires_control_check": false, "description": "Insufficient thrust for split-S"}
	var requires_check = true
	return {
		"possible": true,
		"thrust_cost": cost,
		"requires_control_check": requires_check,
		"description": "Split-S: %d thrust, control check required" % cost,
	}


func _resolve_vtol_spin(current_thrust: int) -> Dictionary:
	var cost = 1
	if current_thrust < cost:
		return {"possible": false, "thrust_cost": cost, "requires_control_check": false, "description": "Insufficient thrust for VTOL spin"}
	return {
		"possible": true,
		"thrust_cost": cost,
		"requires_control_check": false,
		"description": "VTOL spin: %d thrust" % cost,
	}
