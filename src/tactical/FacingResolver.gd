extends Node

## Resolves attack direction (front/side/rear) based on target facing
## and attacker position in hex coordinates.
##
## Each unit type defines its facing arcs in its JSON as hex-offset lists
## relative to the target's facing direction (0-5, clockwise).
##
## Example (mech, facing north):
##   front: [0, 1, 5]  — directly ahead and 60° to each side
##   right_side: [2]   — 120° clockwise
##   left_side: [4]    — 120° counter-clockwise
##   rear: [3]         — directly behind

const HEX_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),  # 0 = top
	Vector2i(1, -1),  # 1 = top-right
	Vector2i(1, 0),   # 2 = bottom-right
	Vector2i(0, 1),   # 3 = bottom
	Vector2i(-1, 1),  # 4 = bottom-left
	Vector2i(-1, 0),  # 5 = top-left
]


## Returns the attack direction table name for a given engagement.
## target_hex: axial coordinates of the target unit.
## attacker_hex: axial coordinates of the attacking unit.
## target_facing: 0-5, the direction the target is facing.
## arcs: dictionary from the unit type definition, e.g.
##   {"front": [0,1,5], "right_side": [2], "left_side": [4], "rear": [3]}
## Falls back to "front" if arcs are empty or hex data is missing.
func resolve(target_hex: Vector2i, attacker_hex: Vector2i, target_facing: int, arcs: Dictionary) -> String:
	if arcs.is_empty():
		return "front"

	var offset = attacker_hex - target_hex
	var dir = _hex_to_direction(offset)
	if dir < 0:
		return "front"

	var relative = (dir - target_facing + 6) % 6

	for arc_name in arcs:
		var offsets: Array = arcs[arc_name]
		for o in offsets:
			if (relative + 6) % 6 == (o + 6) % 6:
				return arc_name

	return "front"


## Converts a hex offset vector to the nearest hex direction (0-5).
## Returns -1 if the offset is zero.
func _hex_to_direction(offset: Vector2i) -> int:
	if offset == Vector2i.ZERO:
		return -1

	var best_dir = 0
	var best_dot = -INF

	for i in range(6):
		var d = HEX_DIRECTIONS[i]
		var dot_val = offset.x * d.x + offset.y * d.y
		var len_sq = offset.x * offset.x + offset.y * offset.y
		if len_sq > 0:
			var cos_angle = dot_val / sqrt(len_sq)
			if cos_angle > best_dot:
				best_dot = cos_angle
				best_dir = i

	return best_dir
