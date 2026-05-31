extends Node

## Resolves Line of Sight between two units on a hex map.

const HexMap = preload("res://src/data/HexMap.gd")
##
## LOS is blocked when intervening terrain's highest point is at or above
## the higher of the two units' relevant height. A mech has height 2 (cockpit
## at level 2, legs at level 1). Terrain has height (woods=2, hill=1 per level,
## building=per level).
##
## Usage:
##   var resolver = LOSResolver.new()
##   var result = resolver.resolve(attacker_hex, attacker_height,
##                                  target_hex, target_height,
##                                  terrain_heights)

## Returns "clear", "blocked", or "partial" (partial = intervening terrain
## at same height as the lower unit — partial cover/obscurement).

const HEX_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0),
]


## terrain_heights: Dictionary keyed by "q,r" string -> int (max height of that hex).
## Returns a Dictionary with: los (String), intervening_terrain_height (int).
func resolve(attacker_hex: Vector2i, attacker_height: int,
		target_hex: Vector2i, target_height: int,
		terrain_heights: Dictionary = {}) -> Dictionary:

	var hexes = _line_bresenham(attacker_hex, target_hex)
	var max_unit_height = max(attacker_height, target_height)

	for hex in hexes:
		var key = "%d,%d" % [hex.x, hex.y]
		var terrain_h = terrain_heights.get(key, 0)
		if terrain_h >= max_unit_height:
			# Terrain blocks LOS
			return {"los": "blocked", "intervening_terrain_height": terrain_h}
		if terrain_h > 0 and terrain_h >= min(attacker_height, target_height):
			# Terrain partially blocks (partial cover)
			return {"los": "partial", "intervening_terrain_height": terrain_h}

	return {"los": "clear", "intervening_terrain_height": 0}


## Bresenham-like line through hex coordinates. Returns Array[Vector2i]
## of hexes between start and end (exclusive of both endpoints).
func _line_bresenham(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dist = HexMap.axial_to_pixel(to.x, to.y, 1.0) - HexMap.axial_to_pixel(from.x, from.y, 1.0)
	var steps = max(abs(dist.x), abs(dist.y)) / 2.0
	steps = max(steps, 1.0)

	for i in range(1, int(steps)):
		var t = i / steps
		var px = HexMap.axial_to_pixel(from.x, from.y, 1.0)
		var qx = HexMap.axial_to_pixel(to.x, to.y, 1.0)
		var mid_x = px.x + (qx.x - px.x) * t
		var mid_y = px.y + (qx.y - px.y) * t
		var hex = _pixel_to_axial(Vector2(mid_x, mid_y))
		if hex != from and hex != to and not hex in result:
			result.append(hex)

	return result


func _pixel_to_axial(pixel: Vector2) -> Vector2i:
	var q = (sqrt(3.0) / 3.0 * pixel.x - 1.0 / 3.0 * pixel.y)
	var r = (2.0 / 3.0 * pixel.y)
	return _round_to_axial(q, r)


func _round_to_axial(q: float, r: float) -> Vector2i:
	var s = -q - r
	var rq = round(q)
	var rr = round(r)
	var rs = round(s)
	var q_diff = abs(rq - q)
	var r_diff = abs(rr - r)
	var s_diff = abs(rs - s)
	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))
