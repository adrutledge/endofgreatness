class_name TacticalMovementResolver
extends RefCounted

## Dial's bucket reachable-set pathfinder for the tactical hex grid.
##
## State space: (hex_q, hex_r, facing, height) — 6 facings × up to N valid heights per hex.
## Edge costs: terrain cost (data-driven via MovementCostResolver) + turning cost + elevation change.
## Valid heights per hex: natural elevation + structure heights (building roofs, bridge decks).
##
## Structure interaction rules:
##   - Walk-through (ground elevation, building present):  blocked if unit_mass < CF  (too light to breach)
##   - Roof entry (building roof height):                  collapse_warning if unit_mass > CF
##   - Bridge entry (bridge deck height):                  collapse_warning if unit_mass > CF
##   - Collapse is a warning, not a block — player may confirm.

const HexMap = preload("res://src/data/HexMap.gd")

## Facing directions in axial coordinates for a flat-top hex.
## Facing 0 = east, going clockwise.
const FACING_DELTAS: Array = [
	Vector2i(1, 0),   # 0: east
	Vector2i(1, -1),  # 1: northeast
	Vector2i(0, -1),  # 2: northwest
	Vector2i(-1, 0),  # 3: west
	Vector2i(-1, 1),  # 4: southwest
	Vector2i(0, 1),   # 5: southeast
]

const FACING_COUNT: int = 6

var _cost_resolver: MovementCostResolver


func _init() -> void:
	_cost_resolver = MovementCostResolver.new()


## Returns all states reachable within the unit's MP.
##
## Parameters:
##   hex_map: HexMap — the tactical hex grid
##   start_q, start_r: int — starting hex coordinates
##   start_facing: int — starting facing (0-5)
##   start_height: int — starting height (typically hex elevation)
##   mp: int — total movement points available
##   mode: String — "walk", "run", or "jump"
##   unit_tonnage: float — for collapse warnings (0 = no check)
##
## Returns Dictionary:
##   {
##     costs: { "q,r,f,h": float },
##     came_from: { "q,r,f,h": "q,r,f,h" },
##     edges: [ { from_key, to_key, mp_cost, psr_risks, collapse_warning, blocked_by } ],
##     reachable_hexes: { "q,r": { min_cost, facings: [int], heights: [int] } },
##     start: { q, r, facing, height }
##   }
func find_reachable(hex_map: HexMap, start_q: int, start_r: int, start_facing: int,
		start_height: int, mp: int, mode: String, unit_tonnage: float = 0.0) -> Dictionary:

	var result := {
		"costs": {},
		"came_from": {},
		"edges": [],
		"reachable_hexes": {},
		"start": {"q": start_q, "r": start_r, "facing": start_facing, "height": start_height},
	}

	var _key := func(q: int, r: int, f: int, h: int) -> String:
		return "%d,%d,%d,%d" % [q, r, f, h]

	var start_key = _key.call(start_q, start_r, start_facing, start_height)

	# Dial's buckets
	var max_buckets := mp + 1
	var buckets: Array[Array] = []
	buckets.resize(max_buckets + 1)
	for i in range(max_buckets + 1):
		buckets[i] = []

	buckets[0].append(start_key)
	result.costs[start_key] = 0

	# Water depth lookup helper
	var _get_depth := func(q: int, r: int) -> int:
		var h = hex_map.get_hex(q, r)
		return h.get("water_depth", 0) if not h.is_empty() else 0

	var _get_terrain_id := func(q: int, r: int) -> String:
		var h = hex_map.get_hex(q, r)
		if h.is_empty():
			return ""
		var terrain_enum = h.get("terrain", HexMap.Terrain.PLAINS)
		match terrain_enum:
			HexMap.Terrain.PLAINS: return "clear"
			HexMap.Terrain.FOREST: return "light_woods"
			HexMap.Terrain.MOUNTAIN: return "rough"
			HexMap.Terrain.WATER: return "water"
			HexMap.Terrain.URBAN: return "paved"
			HexMap.Terrain.DESERT: return "sand"
			HexMap.Terrain.ROUGH: return "rough"
		return "clear"

	var _get_elevation := func(q: int, r: int) -> int:
		var h = hex_map.get_hex(q, r)
		return h.get("elevation", 0) if not h.is_empty() else 0

	var bucket_idx := 0
	while bucket_idx <= max_buckets:
		var current_bucket = buckets[bucket_idx]
		if current_bucket.is_empty():
			bucket_idx += 1
			continue

		var state_key = current_bucket.pop_back()
		if state_key == null:
			bucket_idx += 1
			continue

		var current_cost = result.costs.get(state_key, INF) as float
		if current_cost > bucket_idx + 0.001:
			continue

		var parts = state_key.split(",")
		var cq = int(parts[0])
		var cr = int(parts[1])
		var cf = int(parts[2])
		var current_height = int(parts[3])

		# Track reachable hex summaries (merge all facings + heights for same hex)
		var hex_key = "%d,%d" % [cq, cr]
		if not result.reachable_hexes.has(hex_key):
			result.reachable_hexes[hex_key] = {"min_cost": current_cost, "facings": [], "heights": []}
		elif result.reachable_hexes[hex_key].min_cost > current_cost:
			result.reachable_hexes[hex_key].min_cost = current_cost
		if cf not in result.reachable_hexes[hex_key].facings:
			result.reachable_hexes[hex_key].facings.append(cf)
		if current_height not in result.reachable_hexes[hex_key].heights:
			result.reachable_hexes[hex_key].heights.append(current_height)

		# --- Turn transitions (cost = turn_cost, height unchanged) ---
		var turn_cost = _movement_config("turn_cost", 1)

		for turn_delta in [-1, 1]:
			var nf = (cf + turn_delta + FACING_COUNT) % FACING_COUNT
			var nkey = _key.call(cq, cr, nf, current_height)
			var new_cost = current_cost + turn_cost
			if new_cost <= mp and new_cost < result.costs.get(nkey, INF):
				result.costs[nkey] = new_cost
				result.came_from[nkey] = state_key
				var bi = int(min(new_cost, max_buckets))
				buckets[bi].append(nkey)
				result.edges.append({
					"from": state_key,
					"to": nkey,
					"mp_cost": turn_cost,
					"psr_risks": [],
					"collapse_warning": false,
					"blocked_by": "",
				})

		# --- Advance transition: one edge per valid target height ---
		var delta = FACING_DELTAS[cf]
		var nq = cq + delta.x
		var nr = cr + delta.y

		var h_target = hex_map.get_hex(nq, nr)
		if h_target.is_empty():
			continue

		var terrain_id = _get_terrain_id.call(nq, nr)
		var water_depth = _get_depth.call(nq, nr)
		var valid_heights = _get_valid_heights(h_target)

		for target_height in valid_heights:
			var elev_change = abs(current_height - target_height)
			var max_elev = _movement_config("max_elevation_change", 2)
			if elev_change > max_elev:
				continue

			var resolution = _cost_resolver.resolve(terrain_id, mode, 99, elev_change, water_depth)
			if not resolution.can_enter:
				continue

			# Structure interaction check
			var struct_check = _check_structure_interaction(h_target, target_height, unit_tonnage)
			if struct_check.blocked:
				continue

			var edge_cost = resolution.mp_cost
			var nkey = _key.call(nq, nr, cf, target_height)
			var new_cost = current_cost + edge_cost

			if new_cost <= mp and new_cost < result.costs.get(nkey, INF):
				result.costs[nkey] = new_cost
				result.came_from[nkey] = state_key
				var bi = int(min(new_cost, max_buckets))
				buckets[bi].append(nkey)

			var risks = resolution.get("risks", {})
			var psr_risks: Array = []
			if not risks.get("psr_trigger", "").is_empty():
				psr_risks.append({
					"trigger": risks.psr_trigger,
					"modifier": risks.get("psr_modifier", 0),
					"data": risks.get("psr_data", {}),
				})

				result.edges.append({
					"from": state_key,
					"to": nkey,
					"mp_cost": edge_cost,
					"psr_risks": psr_risks,
					"collapse_warning": struct_check.collapse_warning,
					"blocked_by": "",
				})

	return result


## Returns the set of valid heights for a hex: natural elevation plus any structure heights.
func _get_valid_heights(hex_data: Dictionary) -> Array[int]:
	var heights: Array[int] = []
	var elev = hex_data.get("elevation", 0)
	heights.append(elev)
	for s in hex_data.get("structures", []):
		var sh = s.get("height", elev)
		if sh not in heights:
			heights.append(sh)
	return heights


## Evaluates structure interaction for entering a hex at a specific height.
## Returns { blocked: bool, blocked_by: String, collapse_warning: bool }.
func _check_structure_interaction(hex_data: Dictionary, height: int, unit_tonnage: float) -> Dictionary:
	var result := { "blocked": false, "blocked_by": "", "collapse_warning": false }
	if unit_tonnage <= 0:
		return result
	var elev = hex_data.get("elevation", 0)
	for s in hex_data.get("structures", []):
		var s_height = s.get("height", elev)
		if s_height != height:
			continue
		var cf = s.get("construction_factor", 999999)
		if s.get("type") == "building" and height == elev:
			if unit_tonnage < cf:
				result.blocked = true
				result.blocked_by = "too_light_for_building"
		else:
			if unit_tonnage > cf:
				result.collapse_warning = true
	return result


## Reconstructs a path from start to a specific state using the came_from map.
## Returns Array[String] of state keys in order from start to target, or empty if unreachable.
## state_key format: "q,r,facing,height"
static func reconstruct_path(came_from: Dictionary, target_key: String) -> Array[String]:
	var path: Array[String] = [target_key]
	var current = target_key
	var seen: Dictionary = {}
	while came_from.has(current):
		if seen.has(current):
			break
		seen[current] = true
		current = came_from[current]
		path.append(current)
	path.reverse()
	return path


## Returns the minimum MP cost to reach any (facing, height) at a hex from the find_reachable result.
static func min_cost_to_hex(costs: Dictionary, q: int, r: int) -> float:
	var best := INF
	for f in range(FACING_COUNT):
		for h in range(20):  # reasonable height bound
			var key = "%d,%d,%d,%d" % [q, r, f, h]
			if costs.has(key) and costs[key] < best:
				best = costs[key]
	return best


static func _movement_config(key: String, default):
	var cfg_file = FileAccess.open("res://data/rules/terrain_movement.json", FileAccess.READ)
	if not cfg_file:
		return default
	var j = JSON.new()
	if j.parse(cfg_file.get_as_text()) != OK:
		return default
	return j.data.get(key, default)
