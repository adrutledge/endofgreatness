extends SceneTree

## Data format tests — validates that all config/rules data files can be parsed
## without errors and contain expected structure. Positive tests verify valid data
## loads correctly; negative tests verify missing/invalid data doesn't crash.

var _passed := 0
var _failed := 0
var _data_dirs := [
	"res://data/config/",
	"res://data/rules/",
	"res://data/unit_types/",
]

func _init() -> void:
	_print_sep()
	print("Data Format Tests")
	_print_sep()

	# --- Config files ---
	_test_config_loads("contract_generation.json")
	_test_config_has_required("contract_generation.json", ["min_contracts", "contract_types", "low_rep_types"])
	_test_config_contract_types_valid("contract_generation.json")
	_test_config_loads("spares_config.json")
	_test_config_has_required("spares_config.json", ["refit_canon_only", "aerospace_enabled", "vehicles_enabled"])
	_test_config_negative_missing_file()
	_test_config_negative_empty_dict()

	# --- Rules files ---
	_test_rules_loads("suspension_factors.json")
	_test_rules_loads("combat_config.json")
	_test_rules_loads("cluster_hits.json")

	# --- Skills ---
	_test_skills_loaded()
	_test_skills_have_links()

	# --- Unit types ---
	_test_unit_type_loads("mech.json")
	_test_unit_type_loads("vehicle.json")

	# --- Systems index ---
	_test_systems_index_loaded()

	_print_sep()
	print("Results: %d passed, %d failed, %d total" % [_passed, _failed, _passed + _failed])
	_print_sep()
	quit(0 if _failed == 0 else 1)


# ===================== Positive: Config loads =====================

func _test_rules_loads(filename: String) -> void:
	var path = "res://data/rules/" + filename
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: _fail("Cannot open %s" % path); return
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK: _fail("%s: JSON parse error" % filename); return
	_pass("%s: parsed OK" % filename)


func _test_config_loads(filename: String) -> void:
	var path = "res://data/config/" + filename
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		_fail("Cannot open %s" % path)
		return
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK:
		_fail("%s: JSON parse error" % filename)
		return
	_pass("%s: parsed OK" % filename)


func _test_config_has_required(filename: String, keys: Array) -> void:
	var path = "res://data/config/" + filename
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: _fail("Cannot open %s" % path); return
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK: _fail("%s: parse error" % filename); return
	for k in keys:
		if not j.data.has(k):
			_fail("%s: missing required key '%s'" % [filename, k])
			return
	_pass("%s: has all %d required keys" % [filename, keys.size()])


func _test_config_contract_types_valid(filename: String) -> void:
	var path = "res://data/config/" + filename
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: _fail("Cannot open %s" % path); return
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK: _fail("%s: parse error" % filename); return
	var types: Array = j.data.get("contract_types", [])
	if types.is_empty(): _fail("No contract types"); return
	for t in types:
		if not t.has("name"): _fail("Type missing name"); return
		if not t.has("max_range"): _fail("%s missing max_range" % t.get("name", "?")); return
		if not t.has("weight"): _fail("%s missing weight" % t.get("name", "?")); return
	_pass("%s: %d valid contract types" % [filename, types.size()])


# ===================== Negative: Config =====================

func _test_config_negative_missing_file() -> void:
	var path = "res://data/config/nonexistent_file_xyz.json"
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		_fail("Missing file should not open"); return
	_pass("Missing config file returns null")


func _test_config_negative_empty_dict() -> void:
	var d = {}
	if d.get("nonexistent", null) != null: _fail("Empty dict get should return null"); return
	_pass("Empty dict .get() returns null")


# ===================== Positive: Skills =====================

func _test_skills_loaded() -> void:
	var file = FileAccess.open("res://data/skills.json", FileAccess.READ)
	if not file: _fail("Cannot open skills.json"); return
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK: _fail("skills.json parse error"); return
	var skills: Array = j.data.get("skills", [])
	if skills.is_empty(): _fail("No skills loaded"); return
	_pass("skills.json: %d skills loaded" % skills.size())


func _test_skills_have_links() -> void:
	var file = FileAccess.open("res://data/skills.json", FileAccess.READ)
	if not file: _fail("Cannot open skills.json"); return
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK: _fail("skills.json parse error"); return
	var skills: Array = j.data.get("skills", [])
	for s in skills:
		if not s.has("name"): _fail("Skill missing name"); return
		if not s.has("links"): _fail("%s missing links" % s.get("name", "?")); return
	_pass("All %d skills have name + links" % skills.size())


# ===================== Positive: Unit types =====================

func _test_unit_type_loads(filename: String) -> void:
	var path = "res://data/unit_types/" + filename
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: _fail("Cannot open %s" % path); return
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK: _fail("%s parse error" % filename); return
	if not j.data.has("name"): _fail("%s missing name" % filename); return
	_pass("%s: parsed OK (name: %s)" % [filename, j.data.get("name", "?")])


# ===================== Positive: Systems index =====================

func _test_systems_index_loaded() -> void:
	var file = FileAccess.open("res://data/systems_index.json", FileAccess.READ)
	if not file: _fail("Cannot open systems_index.json"); return
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK: _fail("systems_index.json parse error"); return
	var data = j.data
	if data is Array:
		_pass("systems_index.json: %d systems" % data.size())
	elif data is Dictionary:
		var entries = data.get("systems", data.get("entries", []))
		_pass("systems_index.json: %d systems" % entries.size())
	else:
		_pass("systems_index.json: loaded (%s)" % typeof(data))


# ===================== Helpers =====================

func _pass(msg: String) -> void:
	_passed += 1
	print("  PASS: %s" % msg)


func _fail(msg: String) -> void:
	_failed += 1
	print("  FAIL: %s" % msg)


func _print_sep() -> void:
	print("----------------------------------------")
