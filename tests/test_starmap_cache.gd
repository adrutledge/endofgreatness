extends SceneTree

var _passed := 0
var _failed := 0

const TEST_CACHE_PATH = "user://cache/test_territory.json"


func _init() -> void:
	_print_sep()
	print("Starmap Cache Generation Tests")
	_print_sep()

	_test_build_groups_synthetic()
	_test_voronoi_synthetic()
	_test_parse_systems_index()
	_test_cache_save_load_cycle()
	_test_cache_freshness_check()

	_print_sep()
	print("Results: %d passed, %d failed, %d total" % [_passed, _failed, _passed + _failed])
	_print_sep()

	_cleanup()
	quit(0 if _failed == 0 else 1)


func _build_test_systems() -> Dictionary:
	return {
		"Terra": {"coordinates": {"x": 0.0, "y": 0.0}, "owner_faction": "LC"},
		"New Earth": {"coordinates": {"x": 10.0, "y": 5.0}, "owner_faction": "LC"},
		"Luthien": {"coordinates": {"x": 90.0, "y": 80.0}, "owner_faction": "DC"},
		"New Samarkand": {"coordinates": {"x": 100.0, "y": 85.0}, "owner_faction": "DC"},
		"Canopus": {"coordinates": {"x": -50.0, "y": -60.0}, "owner_faction": "MOC"},
		"Pirate Haven": {"coordinates": {"x": 200.0, "y": 150.0}, "owner_faction": "PIR"},
	}


func _build_groups(systems: Dictionary) -> Dictionary:
	var groups: Dictionary = {}
	for name in systems:
		var sys = systems[name]
		var owner = sys.get("owner_faction", "")
		if owner.is_empty() or owner in ["I", "X", "U"]:
			continue
		var coords = sys.get("coordinates", {})
		var pos = Vector2(coords.get("x", 0.0), -coords.get("y", 0.0))
		if not groups.has(owner):
			groups[owner] = []
		groups[owner].append(pos)
	return groups


func _test_build_groups_synthetic() -> void:
	var systems = _build_test_systems()
	var groups = _build_groups(systems)

	if groups.size() != 4:
		_fail("Group count", "expected 4, got %d" % groups.size())
		return
	if "PIR" not in groups:
		_fail("Group PIR", "expected PIR group")
		return
	if groups.get("LC", []).size() != 2:
		_fail("LC count", "expected 2 LC systems, got %d" % groups.get("LC", []).size())
		return
	_pass("Build groups from synthetic data (%d groups)" % groups.size())


func _test_voronoi_synthetic() -> void:
	var systems = _build_test_systems()
	var groups = _build_groups(systems)
	var major_codes = ["LC", "DC", "MOC"]

	var territory: Dictionary = {}
	for owner in groups:
		if owner in major_codes:
			territory[owner] = groups[owner]

	var step = 10.0
	var extent = 120.0
	var grid: Dictionary = {}
	var disputed: Dictionary = {}

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

			if not best_owner.is_empty():
				if not grid.has(best_owner):
					grid[best_owner] = []
				grid[best_owner].append(pt)

	if grid.is_empty():
		_fail("Voronoi output", "grid is empty — no territory assigned")
		return
	if not grid.has("LC"):
		_fail("Voronoi LC", "no LC territory found")
		return
	if not grid.has("DC"):
		_fail("Voronoi DC", "no DC territory found")
		return
	if not grid.has("MOC"):
		_fail("Voronoi MOC", "no MOC territory found")
		return

	var lc_count = grid["LC"].size()
	var dc_count = grid["DC"].size()
	if lc_count <= 0 or dc_count <= 0:
		_fail("Territory counts", "LC=%d DC=%d" % [lc_count, dc_count])
		return
	_pass("Voronoi produced %d territory groups (%d total grid points)" % [grid.size(), lc_count + dc_count + grid.get("MOC", []).size()])


func _test_cache_save_load_cycle() -> void:
	var test_faction: Dictionary = {
		"LC": [Vector2(1.0, 2.0), Vector2(3.0, 4.0)],
		"DC": [Vector2(5.0, 6.0)],
	}
	var test_disputed: Dictionary = {
		"LC/DC": [Vector2(2.0, 3.0)],
	}

	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("user://cache"):
		dir.make_dir("user://cache")

	var cache = {
		"source_mtime": 42,
		"faction_territory": {},
		"disputed_territory": {},
	}
	for owner in test_faction:
		var pts: Array = []
		for v in test_faction[owner]:
			pts.append({"x": v.x, "y": v.y})
		cache["faction_territory"][owner] = pts
	for pair in test_disputed:
		var pts: Array = []
		for v in test_disputed[pair]:
			pts.append({"x": v.x, "y": v.y})
		cache["disputed_territory"][pair] = pts

	var file = FileAccess.open(TEST_CACHE_PATH, FileAccess.WRITE)
	if not file:
		_fail("Cache save", "could not open for writing")
		return
	file.store_string(JSON.new().stringify(cache))
	file.close()

	var read_file = FileAccess.open(TEST_CACHE_PATH, FileAccess.READ)
	if not read_file:
		_fail("Cache load", "could not open for reading")
		return
	var parser = JSON.new()
	if parser.parse(read_file.get_as_text()) != OK:
		_fail("Cache parse", "JSON parse error")
		return
	var loaded = parser.data

	if loaded.get("source_mtime", 0) != 42:
		_fail("Cache mtime", "expected 42, got %d" % loaded.get("source_mtime", 0))
		return
	var lc = loaded.get("faction_territory", {}).get("LC", [])
	if lc.size() != 2:
		_fail("Cache LC", "expected 2 points, got %d" % lc.size())
		return

	DirAccess.remove_absolute(TEST_CACHE_PATH)
	_pass("Cache save/load round-trip")


func _test_cache_freshness_check() -> void:
	var no_such_mtime = FileAccess.get_modified_time("res://data/nonexistent.json")
	if no_such_mtime > 0:
		_fail("Bad mtime", "expected <=0 for missing file, got %d" % no_such_mtime)
		return

	var source_mtime = FileAccess.get_modified_time("res://data/systems_index.json")
	if source_mtime <= 0:
		_fail("Source mtime", "could not read systems_index.json mtime")
		return
	_pass("systems_index.json mtime: %d" % source_mtime)


func _test_parse_systems_index() -> void:
	var file = FileAccess.open("res://data/systems_index.json", FileAccess.READ)
	if not file:
		_fail("Open index", "could not open systems_index.json")
		return
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		_fail("Parse index", "JSON parse error")
		return
	var data = parser.data
	if not data is Array:
		_fail("Index type", "expected Array, got %s" % typeof(data))
		return
	if data.size() < 3000:
		_fail("Index size", "expected >= 3000 entries, got %d" % data.size())
		return
	var has_owner = 0
	for entry in data:
		if entry.get("owner_faction", ""):
			has_owner += 1
	if has_owner < 500:
		_fail("Owned systems", "expected >= 500 with owner, got %d" % has_owner)
		return
	_pass("systems_index.json: %d entries, %d with owner" % [data.size(), has_owner])


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_CACHE_PATH):
		DirAccess.remove_absolute(TEST_CACHE_PATH)


func _pass(n: String) -> void:
	_passed += 1
	print("  PASS  %s" % n)


func _fail(n: String, m: String) -> void:
	_failed += 1
	print("  FAIL  %s  %s" % [n, m])


func _print_sep() -> void:
	var s := ""
	for i in range(60):
		s += "="
	print(s)
