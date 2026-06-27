class_name LOSResolver
extends Node

## Resolves Line of Sight between two units on a hex map.
## LOS is symmetric — results are cached per round so that resolving
## LOS(attacker, target) also covers LOS(target, attacker) for free.

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

var _cache: Dictionary = {}
var _cache_enabled: bool = true


## Clears the per-round cache. Call at the start of each combat round.
func clear_cache() -> void:
	_cache.clear()


## Disables caching (useful for one-off LOS checks outside combat).
func disable_cache() -> void:
	_cache_enabled = false
	_cache.clear()


## terrain_heights: Dictionary keyed by "q,r" string -> int (max height of that hex).
## Returns a Dictionary with: los (String), intervening_terrain_height (int).
func resolve(attacker_hex: Vector2i, attacker_height: int,
		target_hex: Vector2i, target_height: int,
		terrain_heights: Dictionary = {}) -> Dictionary:

	if _cache_enabled:
		var key = _cache_key(attacker_hex, target_hex)
		if _cache.has(key):
			return _cache[key].duplicate()

	# Defender-favoured edge bias: when LOS falls exactly on the line between
	# two hexes, take the worse result for the attacker. We compute two
	# slightly offset lines and union their hex sets — if either would block
	# or partially obscure, that result is used.
	var hexes: Array[Vector2i] = _line_bresenham(attacker_hex, target_hex, 0.0)
	var alt_hexes: Array[Vector2i] = _line_bresenham(attacker_hex, target_hex, 0.05)

	var max_unit_height = max(attacker_height, target_height)
	var min_unit_height = min(attacker_height, target_height)
	var result = {"los": "clear", "intervening_terrain_height": 0}

	for hexes_set in [hexes, alt_hexes]:
		for hex in hexes_set:
			var key = "%d,%d" % [hex.x, hex.y]
			var terrain_h = terrain_heights.get(key, 0)
			if terrain_h >= max_unit_height:
				result = {"los": "blocked", "intervening_terrain_height": terrain_h}
				if _cache_enabled:
					_cache[_cache_key(attacker_hex, target_hex)] = result
				return result
			if terrain_h > 0 and terrain_h >= min_unit_height and result.los != "blocked":
				result = {"los": "partial", "intervening_terrain_height": terrain_h}

	if _cache_enabled:
		_cache[_cache_key(attacker_hex, target_hex)] = result
	return result


## Produces a symmetric cache key so LOS(A,B) and LOS(B,A) hit the same entry.
func _cache_key(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return "%d,%d:%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d:%d,%d" % [b.x, b.y, a.x, a.y]


## Bresenham-like line through hex coordinates. Returns Array[Vector2i]
## of hexes between start and end (exclusive of both endpoints).
## epsilon: lateral offset as fraction of hex width (0.0 = centre line,
## 0.05 = slightly offset). Used for defender-favoured edge bias.
func _line_bresenham(from: Vector2i, to: Vector2i, epsilon: float = 0.0) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var p_from = HexMap.axial_to_pixel(from.x, from.y, 1.0)
	var p_to = HexMap.axial_to_pixel(to.x, to.y, 1.0)
	var dist = p_to - p_from

	# Apply epsilon as a perpendicular offset to create a slightly different path
	if epsilon != 0.0:
		var perp = Vector2(-dist.y, dist.x).normalized()
		p_from += perp * epsilon
		p_to += perp * epsilon

	var steps = max(abs(dist.x), abs(dist.y)) / 2.0
	steps = max(steps, 1.0)

	for i in range(1, int(steps)):
		var t = i / steps
		var mid_x = p_from.x + (p_to.x - p_from.x) * t
		var mid_y = p_from.y + (p_to.y - p_from.y) * t
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
