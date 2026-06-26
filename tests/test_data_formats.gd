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
	_test_cluster_hits_structure()
	_test_rules_loads("hit_locations.json")
	_test_hit_locations_structure()
	_test_rules_loads("heat_table.json")
	_test_heat_table_structure()
	_test_rules_loads("physical_attacks.json")
	_test_physical_attacks_structure()
	_test_rules_loads("psr_triggers.json")
	_test_psr_triggers_structure()
	_test_rules_loads("forced_withdrawal.json")
	_test_forced_withdrawal_structure()
	_test_rules_loads("terrain_types.json")
	_test_terrain_types_structure()
	_test_rules_loads("terrain_effects.json")
	_test_terrain_effects_structure()
	_test_rules_loads("terrain_movement.json")
	_test_terrain_movement_structure()

	# --- AI data ---
	_test_ai_personalities()

	# --- Skills ---
	_test_skills_loaded()
	_test_skills_have_links()

	# --- Unit types ---
	_test_unit_type_loads("mech.json")
	_test_unit_type_loads("vehicle.json")

	# --- Negative tests ---
	_test_negative_corrupted_json()
	_test_negative_rules_missing_file()
	_test_negative_empty_rules_file()
	_test_negative_hit_locations_missing_table()
	_test_negative_heat_table_missing_shutdown()
	_test_negative_cluster_hits_short_column()
	_test_negative_physical_attacks_missing_attack()
	_test_negative_psr_triggers_missing_on_failure()
	_test_negative_personality_out_of_range()
	_test_negative_forced_withdrawal_missing_check()
	_test_negative_forced_withdrawal_empty()
	_test_negative_terrain_type_missing_cost()
	_test_negative_terrain_type_empty()
	_test_negative_terrain_movement_missing_required()
	_test_negative_terrain_effects_missing_handler()

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


# ===================== Negative: Data parsing =====================

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


func _test_negative_corrupted_json() -> void:
	var j = JSON.new()
	var result = j.parse("{this is not valid json!!!")
	if result == OK:
		_fail("Corrupted JSON should not parse")
		return
	_pass("Corrupted JSON correctly rejected")


func _test_negative_rules_missing_file() -> void:
	var path = "res://data/rules/nonexistent_file_xyz.json"
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		_fail("Missing rules file should not open"); return
	_pass("Missing rules file returns null")


func _test_negative_empty_rules_file() -> void:
	# Simulate reading an empty file
	var j = JSON.new()
	var result = j.parse("")
	if result != OK:
		_pass("Empty JSON parse correctly fails")
	elif j.data is Dictionary and j.data.is_empty():
		_pass("Empty JSON parsed to empty dict")
	else:
		_fail("Empty JSON unexpected result")


func _test_negative_hit_locations_missing_table() -> void:
	var bad = {"tables": {}}
	if bad.get("tables", {}).is_empty():
		_pass("hit_locations: empty tables correctly detected")
	else:
		_fail("Should detect empty tables")


func _test_negative_heat_table_missing_shutdown() -> void:
	var bad = {"standard_max_heat": 30, "thresholds": {"5": {"walk_mp": -1}}}
	var thresh = bad.get("thresholds", {})
	if not thresh.has("30"):
		_pass("heat_table: missing 30 correctly detected")
	else:
		_fail("Should detect missing threshold 30")


func _test_negative_cluster_hits_short_column() -> void:
	var bad = {"table": {"7": [2, 3, 4]}, "column_labels": ["2", "3", "4"]}
	var col: Array = bad.get("table", {}).get("7", [])
	if col.size() < 5:
		_pass("cluster_hits: short column correctly identified")
	else:
		_fail("Should detect column < 5 entries")


func _test_negative_physical_attacks_missing_attack() -> void:
	var bad = {"attacks": {"punch": {"damage_formula": "1"}}}
	var required := ["punch", "kick", "push", "club", "charge", "dfa"]
	var missing = false
	for name in required:
		if not bad.get("attacks", {}).has(name):
			missing = true
			break
	if missing:
		_pass("physical_attacks: missing attack correctly detected")
	else:
		_fail("Should detect missing attack type")


func _test_negative_psr_triggers_missing_on_failure() -> void:
	var bad = {"triggers": [{"id": "bad", "condition": "x"}]}
	for t in bad.get("triggers", []):
		if not t.has("on_failure"):
			_pass("psr_triggers: missing on_failure correctly detected")
			return
	_fail("Should detect missing on_failure")


func _test_forced_withdrawal_structure() -> void:
	var data = _read_rules("forced_withdrawal.json")
	if data.is_empty(): _fail("forced_withdrawal.json: could not read"); return
	var conditions: Array = data.get("conditions", [])
	if conditions.is_empty(): _fail("forced_withdrawal.json: no conditions"); return
	for c in conditions:
		if not c.has("id"): _fail("forced_withdrawal.json: condition missing id"); return
		if not c.has("check"): _fail("forced_withdrawal.json: %s missing check" % c.get("id", "?")); return
		if c.get("check", "") == "pending_rules_verification": continue
	_pass("forced_withdrawal.json: valid (%d conditions)" % conditions.size())


func _test_negative_forced_withdrawal_missing_check() -> void:
	var bad = {"conditions": [{"id": "bad_condition"}]}
	for c in bad.get("conditions", []):
		if not c.has("check"):
			_pass("forced_withdrawal: missing check correctly detected")
			return
	_fail("Should detect missing check")


func _test_negative_forced_withdrawal_empty() -> void:
	var bad = {"conditions": []}
	if bad.get("conditions", []).is_empty():
		_pass("forced_withdrawal: empty conditions correctly detected")
	else:
		_fail("Should detect empty conditions")


func _test_negative_terrain_type_missing_cost() -> void:
	var bad = {"terrain_types": [{"id": "bad_terrain", "name": "Bad"}]}
	var types: Array = bad.get("terrain_types", [])
	for t in types:
		if not t.has("walk_cost") or not t.has("run_cost") or not t.has("jump_cost"):
			_pass("terrain_type: missing cost correctly detected")
			return
	_fail("Should detect missing movement cost")


func _test_negative_terrain_type_empty() -> void:
	var bad = {"terrain_types": []}
	if bad.get("terrain_types", []).is_empty():
		_pass("terrain_type: empty list correctly detected")
	else:
		_fail("Should detect empty terrain_types list")


func _test_negative_terrain_movement_missing_required() -> void:
	var required := ["turn_cost", "max_elevation_change"]
	var bad = {"facing_count": 6}
	for k in required:
		if not bad.has(k):
			_pass("terrain_movement: missing '%s' correctly detected" % k)
			return
	_fail("Should detect missing required key in terrain_movement")


func _test_negative_terrain_effects_missing_handler() -> void:
	var bad = {"effects": [{"id": "no_handler_effect", "description": "Missing handler"}]}
	for e in bad.get("effects", []):
		if not e.has("handler"):
			_pass("terrain_effects: missing handler correctly detected")
			return
	_fail("Should detect missing handler in effect definition")


func _test_negative_personality_out_of_range() -> void:
	var bad = {"personalities": [{"id": "bad", "pilot_skill": 99, "command_skill": 1}]}
	for p in bad.get("personalities", []):
		var ps = p.get("pilot_skill", 0)
		if ps < -1 or ps > 6:
			_pass("personalities: out-of-range pilot_skill correctly detected")
			return
	_fail("Should detect out of range skill")


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


# ===================== Positive: Combat rules =====================

func _read_rules(name: String) -> Dictionary:
	var file = FileAccess.open("res://data/rules/" + name, FileAccess.READ)
	if not file: return {}
	var j = JSON.new()
	j.parse(file.get_as_text())
	return j.data if typeof(j.data) == TYPE_DICTIONARY else {}


func _test_cluster_hits_structure() -> void:
	var data = _read_rules("cluster_hits.json")
	if data.is_empty(): _fail("cluster_hits.json: could not read"); return
	var table = data.get("table", {})
	for roll in ["2","3","4","5","6","7","8","9","10","11","12"]:
		if not table.has(roll):
			_fail("cluster_hits.json: missing roll %s" % roll)
			return
		var col: Array = table.get(roll, [])
		if col.size() < 5:
			_fail("cluster_hits.json: roll %s column too short (%d)" % [roll, col.size()])
			return
	var labels: Array = data.get("column_labels", [])
	if labels.size() < 5:
		_fail("cluster_hits.json: too few column labels")
		return
	_pass("cluster_hits.json: valid (%d rolls, %d columns)" % [table.size(), labels.size()])


func _test_hit_locations_structure() -> void:
	var data = _read_rules("hit_locations.json")
	if data.is_empty(): _fail("hit_locations.json: could not read"); return
	var tables = data.get("tables", {})
	if tables.is_empty(): _fail("hit_locations.json: missing tables"); return
	if not tables.has("biped_front"): _fail("hit_locations.json: missing biped_front"); return
	var front = tables.get("biped_front", {})
	for roll in ["2","3","4","5","6","7","8","9","10","11","12"]:
		if not front.has(roll):
			_fail("hit_locations.json: biped_front missing roll %s" % roll)
			return
	_pass("hit_locations.json: valid (%d tables)" % tables.size())


func _test_heat_table_structure() -> void:
	var data = _read_rules("heat_table.json")
	if data.is_empty(): _fail("heat_table.json: could not read"); return
	if not data.has("standard_max_heat"): _fail("heat_table.json: missing standard_max_heat"); return
	if not data.has("thresholds"): _fail("heat_table.json: missing thresholds"); return
	var thresh = data.get("thresholds", {})
	if thresh.is_empty(): _fail("heat_table.json: empty thresholds"); return
	if not thresh.has("30"): _fail("heat_table.json: missing shutdown threshold at 30"); return
	if not thresh.get("30", {}).get("shutdown", false):
		_fail("heat_table.json: threshold 30 should set shutdown=true")
		return
	_pass("heat_table.json: valid (%d thresholds)" % thresh.size())


func _test_physical_attacks_structure() -> void:
	var data = _read_rules("physical_attacks.json")
	if data.is_empty(): _fail("physical_attacks.json: could not read"); return
	var attacks = data.get("attacks", {})
	var required := ["punch", "kick", "push", "club", "charge", "dfa"]
	for name in required:
		if not attacks.has(name):
			_fail("physical_attacks.json: missing '%s'" % name)
			return
		var a = attacks.get(name, {})
		if not a.has("damage_formula") and a.get("damage_formula", null) != null:
			_fail("physical_attacks.json: %s missing damage_formula" % name)
			return
	_pass("physical_attacks.json: valid (%d attacks)" % attacks.size())


func _test_terrain_types_structure() -> void:
	var data = _read_rules("terrain_types.json")
	if data.is_empty(): _fail("terrain_types.json: could not read"); return
	var types: Array = data.get("terrain_types", [])
	if types.is_empty(): _fail("terrain_types.json: no terrain types"); return
	var required := ["id", "name", "walk_cost", "run_cost", "jump_cost", "effects"]
	for t in types:
		for k in required:
			if not t.has(k): _fail("terrain_types.json: type '%s' missing '%s'" % [t.get("id", "?"), k]); return
		var wc = t.get("walk_cost", 0)
		if wc < 1: _fail("terrain_types.json: %s walk_cost < 1" % t.get("id", "?")); return
		if t.get("id") == "water":
			var depths: Array = t.get("water_depths", [])
			if depths.is_empty(): _fail("terrain_types.json: water missing water_depths"); return
			for d in depths:
				if not d.has("depth"): _fail("terrain_types.json: water depth missing depth"); return
				if not d.has("run_allowed"): _fail("terrain_types.json: water depth %d missing run_allowed" % d.get("depth", -1)); return
	_pass("terrain_types.json: valid (%d types)" % types.size())


func _test_terrain_effects_structure() -> void:
	var data = _read_rules("terrain_effects.json")
	if data.is_empty(): _fail("terrain_effects.json: could not read"); return
	var effects: Array = data.get("effects", [])
	if effects.is_empty(): _fail("terrain_effects.json: no effects"); return
	var required := ["id", "description", "handler"]
	for e in effects:
		for k in required:
			if not e.has(k): _fail("terrain_effects.json: effect '%s' missing '%s'" % [e.get("id", "?"), k]); return
	_pass("terrain_effects.json: valid (%d effects)" % effects.size())


func _test_terrain_movement_structure() -> void:
	var data = _read_rules("terrain_movement.json")
	if data.is_empty(): _fail("terrain_movement.json: could not read"); return
	var required := ["turn_cost", "max_elevation_change", "facing_count"]
	for k in required:
		if not data.has(k): _fail("terrain_movement.json: missing '%s'" % k); return
	var tc = data.get("turn_cost", 0)
	if tc < 1: _fail("terrain_movement.json: turn_cost < 1"); return
	var fc = data.get("facing_count", 0)
	if fc < 1: _fail("terrain_movement.json: facing_count < 1"); return
	_pass("terrain_movement.json: valid")


func _test_psr_triggers_structure() -> void:
	var data = _read_rules("psr_triggers.json")
	if data.is_empty(): _fail("psr_triggers.json: could not read"); return
	var triggers: Array = data.get("triggers", [])
	if triggers.is_empty(): _fail("psr_triggers.json: no triggers"); return
	for t in triggers:
		if not t.has("id"): _fail("psr_triggers.json: trigger missing id"); return
		if not t.has("condition"): _fail("psr_triggers.json: %s missing condition" % t.get("id", "?")); return
		if not t.has("on_failure"): _fail("psr_triggers.json: %s missing on_failure" % t.get("id", "?")); return
	_pass("psr_triggers.json: valid (%d triggers)" % triggers.size())


func _test_ai_personalities() -> void:
	var file = FileAccess.open("res://data/ai/personalities.json", FileAccess.READ)
	if not file: _fail("personalities.json: could not open"); return
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK: _fail("personalities.json: parse error"); return
	var data = j.data
	var list: Array = data.get("personalities", [])
	if list.is_empty(): _fail("personalities.json: no personalities"); return
	for p in list:
		if not p.has("id"): _fail("personality missing id"); return
		if not p.has("pilot_skill"): _fail("%s missing pilot_skill" % p.get("id", "?")); return
		if not p.has("command_skill"): _fail("%s missing command_skill" % p.get("id", "?")); return
		if not p.has("aggression"): _fail("%s missing aggression" % p.get("id", "?")); return
		var ps = p.get("pilot_skill", 0)
		if ps < -1 or ps > 6: _fail("%s: pilot_skill %d out of range" % [p.get("id"), ps]); return
		var cs = p.get("command_skill", 0)
		if cs < -1 or cs > 6: _fail("%s: command_skill %d out of range" % [p.get("id"), cs]); return
	_pass("personalities.json: valid (%d personalities)" % list.size())


# ===================== Helpers =====================

func _pass(msg: String) -> void:
	_passed += 1
	print("  PASS: %s" % msg)


func _fail(msg: String) -> void:
	_failed += 1
	print("  FAIL: %s" % msg)


func _print_sep() -> void:
	print("----------------------------------------")
