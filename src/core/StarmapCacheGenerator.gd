extends Node

const CACHE_PATH = "user://cache/starmap_territory.json"

var _generating: bool = false


func _ready() -> void:
	if _cache_fresh():
		return
	if _generating:
		return
	_generating = true
	call_deferred("_generate")


func _cache_fresh() -> bool:
	var source_mtime = FileAccess.get_modified_time("res://data/systems_index.json")
	if source_mtime < 0:
		return true
	var cache_file = FileAccess.open(CACHE_PATH, FileAccess.READ)
	if not cache_file:
		return false
	var parser = JSON.new()
	if parser.parse(cache_file.get_as_text()) != OK:
		return false
	return parser.data.get("source_mtime", 0) == source_mtime


func _generate() -> void:
	Helpers.debug_print("StarmapCache", "generating territory cache in background")
	var groups = _build_groups()
	var major_codes = ["CC", "DC", "FS", "FWL", "LC", "TC", "MOC", "OA", "I", "AuC", "MH", "OC", "CF", "LL", "TD", "MV", "EF", "IP", "NCR", "CDP", "RC", "FrR", "IE", "MC"]

	var territory: Dictionary = {}
	for owner in groups:
		if owner in major_codes and groups[owner].size() >= 3:
			territory[owner] = groups[owner]

	var step = 4.0
	var extent = 800.0
	var grid: Dictionary = {}
	var disputed: Dictionary = {}
	var computed_rows := 0

	for x in range(-int(extent), int(extent) + 1, int(step)):
		for y in range(-int(extent), int(extent) + 1, int(step)):
			var pt = Vector2(x, y)
			var best_owner = ""
			var best_dist = INF

			for owner in territory:
				for sp in territory[owner]:
					var d = pt.distance_squared_to(sp)
					if d < best_dist:
						best_dist = d
						best_owner = owner

			var disputed_pair = ""
			for owner in groups:
				if not owner.begins_with("D("):
					continue
				for sp in groups[owner]:
					var d = pt.distance_squared_to(sp)
					if d < best_dist:
						best_dist = d
						var inner = owner.substr(2, owner.length() - 3)
						if "/" in inner:
							var parts = inner.split("/")
							if parts.size() == 2 and parts[0] in major_codes and parts[1] in major_codes:
								disputed_pair = inner
								best_owner = ""

			if not disputed_pair.is_empty():
				if not disputed.has(disputed_pair):
					disputed[disputed_pair] = []
				disputed[disputed_pair].append(pt)
			elif not best_owner.is_empty():
				if not grid.has(best_owner):
					grid[best_owner] = []
				grid[best_owner].append(pt)

		computed_rows += 1
		if computed_rows % 10 == 0:
			await get_tree().process_frame

	# Compute density-aware radius and filter
	var faction_radius: Dictionary = {}
	for owner in territory:
		var pts = territory[owner]
		var total_nn := 0.0
		var count := 0
		for p in pts:
			var closest = INF
			for q in pts:
				if q == p:
					continue
				var d = p.distance_squared_to(q)
				if d < closest:
					closest = d
			if closest < INF:
				total_nn += sqrt(closest)
				count += 1
		var avg_nn = total_nn / max(count, 1)
		var min_r = 45.0 if owner in ["CC", "DC", "FS", "FWL", "LC"] else 30.0
		faction_radius[owner] = clampf(avg_nn * 2.0, min_r, 90.0)

	var faction_territory: Dictionary = {}
	for owner in grid:
		var pts = grid[owner]
		var max_r = faction_radius.get(owner, 90.0)
		var max_r_sq = max_r * max_r
		var filtered: Array[Vector2] = []
		for pt in pts:
			var min_dist_sq = INF
			for sp in territory[owner]:
				var d = pt.distance_squared_to(sp)
				if d < min_dist_sq:
					min_dist_sq = d
			if min_dist_sq <= max_r_sq:
				filtered.append(pt)
		if filtered.size() >= 3:
			faction_territory[owner] = filtered

	_save_cache(faction_territory, disputed)
	_generating = false
	Helpers.debug_print("StarmapCache", "territory cache generated and saved")


func _build_groups() -> Dictionary:
	var groups: Dictionary = {}
	if not DataManager or DataManager.systems_data.is_empty():
		return groups
	for name in DataManager.systems_data:
		var sys = DataManager.systems_data[name]
		var owner = sys.get("owner_faction", "")
		if owner.is_empty() or owner in ["I", "X", "U"]:
			continue
		var coords = sys.get("coordinates", {})
		var pos = Vector2(coords.get("x", 0.0), -coords.get("y", 0.0))
		if not groups.has(owner):
			groups[owner] = []
		groups[owner].append(pos)
	return groups


func _save_cache(faction_territory: Dictionary, disputed: Dictionary) -> void:
	var cache = {
		"source_mtime": FileAccess.get_modified_time("res://data/systems_index.json"),
		"faction_territory": {},
		"disputed_territory": {},
	}
	for owner in faction_territory:
		var pts: Array = []
		for v in faction_territory[owner]:
			pts.append({"x": v.x, "y": v.y})
		cache["faction_territory"][owner] = pts
	for pair in disputed:
		var pts: Array = []
		for v in disputed[pair]:
			pts.append({"x": v.x, "y": v.y})
		cache["disputed_territory"][pair] = pts

	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("user://cache"):
		dir.make_dir("user://cache")
	var file = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.new().stringify(cache))
