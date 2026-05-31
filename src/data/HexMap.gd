class_name HexMap
extends Resource

enum Terrain {
	PLAINS,
	FOREST,
	MOUNTAIN,
	WATER,
	URBAN,
	DESERT,
	ROUGH,
}

enum ObjectiveType {
	NONE,
	PRIMARY,
	SECONDARY,
	SALVAGE,
	ENEMY,
	EVENT,
}

var width: int
var height: int
var hexes: Array[Array] = []

var _axial_to_index: Dictionary = {}


func _init(w: int = 10, h: int = 10) -> void:
	width = w
	height = h
	hexes.clear()
	_axial_to_index.clear()
	var idx := 0
	for row in range(h):
		var row_data: Array[Dictionary] = []
		var offset = row / 2
		for col in range(-offset, w - offset):
			var q = col
			var r = row
			var hd = {
				"q": q, "r": r,
				"terrain": Terrain.PLAINS,
				"revealed": false,
				"objective": ObjectiveType.NONE,
				"objective_data": {},
				"explored": false,
			}
			row_data.append(hd)
			_axial_to_index[Vector2i(q, r)] = idx
			idx += 1
		hexes.append(row_data)


func get_hex(q: int, r: int) -> Dictionary:
	for row in hexes:
		for h in row:
			if h.q == q and h.r == r:
				return h
	return {}


func reveal_hex(q: int, r: int) -> void:
	var h = get_hex(q, r)
	if not h.is_empty():
		h.revealed = true
		h.explored = true


func is_revealed(q: int, r: int) -> bool:
	var h = get_hex(q, r)
	return false if h.is_empty() else h.get("revealed", false)


func has_objective(q: int, r: int) -> bool:
	var h = get_hex(q, r)
	return false if h.is_empty() else h.get("objective", ObjectiveType.NONE) != ObjectiveType.NONE


func get_all_hexes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in hexes:
		for h in row:
			result.append(h)
	return result


func get_revealed_hexes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in hexes:
		for h in row:
			if h.revealed:
				result.append(h)
	return result


## Returns adjacent hex coordinates for a given hex in axial coords.
static func get_adjacent(q: int, r: int) -> Array[Vector2i]:
	return [
		Vector2i(q + 1, r),
		Vector2i(q - 1, r),
		Vector2i(q, r - 1),
		Vector2i(q, r + 1),
		Vector2i(q + 1, r - 1),
		Vector2i(q - 1, r + 1),
	]


## Converts axial hex coords to pixel center position.
## hex_size = distance from center to vertex.
static func axial_to_pixel(q: int, r: int, hex_size: float) -> Vector2:
	var x = hex_size * (sqrt(3.0) * q + sqrt(3.0) / 2.0 * r)
	var y = hex_size * (3.0 / 2.0 * r)
	return Vector2(x, y)


## Returns the 6 vertices of a flat-top hexagon centered at origin.
## hex_size = distance from center to vertex.
static func hex_corners(center: Vector2, hex_size: float) -> PackedVector2Array:
	var corners: PackedVector2Array = []
	for i in range(6):
		var angle_deg = 60.0 * i - 30.0
		var angle_rad = deg_to_rad(angle_deg)
		corners.append(Vector2(
			center.x + hex_size * cos(angle_rad),
			center.y + hex_size * sin(angle_rad)
		))
	return corners
