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
	ASSETS,
	ENEMY,
	EVENT,
}

## Base movement cost in days per hex for a reference speed-4 mech.
## Road reduces cost to 1 regardless of terrain. WATER is impassable.
const TERRAIN_MOVEMENT_COST: Dictionary = {
	Terrain.PLAINS: 1.0,
	Terrain.FOREST: 1.5,
	Terrain.MOUNTAIN: 3.0,
	Terrain.WATER: -1.0,
	Terrain.URBAN: 3.0,
	Terrain.DESERT: 1.0,
	Terrain.ROUGH: 1.5,
}

const REFERENCE_SPEED: int = 4

var width: int
var height: int
var hexes: Array[Array] = []
var landing_zone: Vector2i = Vector2i(0, 0)

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
				"objective_completed": false,
				"explored": false,
				"has_road": false,
				"has_river": false,
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


## Returns the base travel cost in days for a hex, given the slowest mech's walk MP.
## Returns -1 for impassable terrain.
func get_hex_travel_cost(q: int, r: int, slowest_walk_mp: int) -> float:
	var h = get_hex(q, r)
	if h.is_empty():
		return -1.0
	var terrain = h.get("terrain", Terrain.PLAINS)
	if h.get("has_road", false):
		return 1.0
	var base = TERRAIN_MOVEMENT_COST.get(terrain, 1.0)
	if base < 0:
		return -1.0
	var speed_factor = float(REFERENCE_SPEED) / float(max(1, slowest_walk_mp))
	var cost = base * speed_factor
	if h.get("has_river", false):
		cost += 0.5
	return cost


## A* pathfinding on the hex grid. Returns an Array of Vector2i from start to end (inclusive),
## or an empty array if no path exists. Cost is travel days per hex.
func find_path(start_q: int, start_r: int, end_q: int, end_r: int, slowest_walk_mp: int) -> Array[Vector2i]:
	var start = Vector2i(start_q, start_r)
	var end = Vector2i(end_q, end_r)
	if start == end:
		return [start]

	var open_set: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}

	var key := func(pos: Vector2i) -> String: return "%d,%d" % [pos.x, pos.y]

	g_score[key.call(start)] = 0.0
	f_score[key.call(start)] = _hex_distance(start, end)

	while not open_set.is_empty():
		var current = open_set[0]
		var current_f = f_score.get(key.call(current), INF)
		for pos in open_set:
			var pf = f_score.get(key.call(pos), INF)
			if pf < current_f:
				current = pos
				current_f = pf

		if current == end:
			return _reconstruct_path(came_from, current)

		open_set.erase(current)

		for adj in get_adjacent(current.x, current.y):
			var cost = get_hex_travel_cost(adj.x, adj.y, slowest_walk_mp)
			if cost < 0:
				continue
			var h_adj = get_hex(adj.x, adj.y)
			if h_adj.is_empty():
				continue

			var tentative_g = g_score.get(key.call(current), INF) + cost
			if tentative_g < g_score.get(key.call(adj), INF):
				came_from[key.call(adj)] = current
				g_score[key.call(adj)] = tentative_g
				f_score[key.call(adj)] = tentative_g + _hex_distance(adj, end)
				if adj not in open_set:
					open_set.append(adj)

	return []


static func _hex_distance(a: Vector2i, b: Vector2i) -> float:
	var dq = abs(a.x - b.x)
	var dr = abs(a.y - b.y)
	var ds = abs(-a.x - a.y + b.x + b.y)
	return max(dq, dr, ds)


static func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	var key := func(pos: Vector2i) -> String: return "%d,%d" % [pos.x, pos.y]
	while came_from.has(key.call(current)):
		current = came_from[key.call(current)]
		path.append(current)
	path.reverse()
	return path
