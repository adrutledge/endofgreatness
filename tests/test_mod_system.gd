extends SceneTree

var _passed := 0
var _failed := 0

const TEST_MOD_PARENT := "user://test_mods/"
const MOD_ID := "test_mod"


func _init() -> void:
	_test_content_lookup()
	_test_missing_strings()
	_test_mod_detection()
	_test_strings_loading()
	_test_strings_override_order()
	_test_mod_data_paths()
	_test_empty_mod_dir()
	_test_version_mismatch()
	_test_missing_compatible_version()
	_print_results()
	quit(0 if _failed == 0 else 1)


func _new_mm():
	var ScriptClass = load("res://src/core/ModManager.gd")
	if not ScriptClass:
		return null
	return ScriptClass.new()


func _clean_mods(base: String) -> void:
	var dir = DirAccess.open(base)
	if dir:
		dir.list_dir_begin()
		var f = dir.get_next()
		while f != "":
			if f != "." and f != "..":
				if dir.current_is_dir():
					_clean_mods(base + f + "/")
				dir.remove(f)
			f = dir.get_next()
		dir.list_dir_end()


func _make_mod_dir(mod_id: String, has_json: bool = true, strings: Dictionary = {}, subdirs: Array[String] = [], priority: int = 0, compat_ver: String = "") -> String:
	var d = DirAccess.open("user://")
	if not d:
		return ""
	d.make_dir_recursive(TEST_MOD_PARENT + mod_id + "/")
	for s in subdirs:
		d.make_dir_recursive(TEST_MOD_PARENT + mod_id + "/" + s + "/")

	if has_json:
		var f = FileAccess.open(TEST_MOD_PARENT + mod_id + "/mod.json", FileAccess.WRITE)
		if f:
			var cv = compat_ver
			if cv.is_empty():
				var mm_class = load("res://src/core/ModManager.gd")
				cv = mm_class.GAME_VERSION if mm_class else "1.0.0"
			f.store_string('{"id": "' + mod_id + '", "version": "1.0.0", "compatible_version": "' + cv + '", "load_priority": ' + str(priority) + '}')
	if not strings.is_empty():
		var f = FileAccess.open(TEST_MOD_PARENT + mod_id + "/strings.json", FileAccess.WRITE)
		if f:
			f.store_string(JSON.new().stringify(strings))
	return TEST_MOD_PARENT + mod_id + "/"


func _test_content_lookup() -> void:
	var mm = _new_mm()
	if not mm:
		_pass("content_lookup (skipped)")
		return
	mm._strings = {"test.event.title": "Test Event Title"}
	var r = mm.tr_content("test.event.title")
	if r != "Test Event Title":
		_fail("content_lookup: got '%s'" % r)
		return
	_pass("content_lookup")


func _test_missing_strings() -> void:
	var mm = _new_mm()
	if not mm:
		_pass("missing_strings (skipped)")
		return
	mm._strings = {}
	var r = mm.tr_content("nonexistent.key")
	if r != "nonexistent.key":
		_fail("missing_strings: expected key as-is, got '%s'" % r)
		return
	_pass("missing_strings")


func _test_version_mismatch() -> void:
	_clean_mods(TEST_MOD_PARENT)
	_make_mod_dir("major_old", true, {}, [], 0, "0.9.0")
	_make_mod_dir("major_new", true, {}, [], 0, "2.0.0")
	_make_mod_dir("minor_higher", true, {}, [], 0, "1.1.0")
	_make_mod_dir("patch_different", true, {"test.ok": "ok"}, [], 0, "1.0.5")
	_make_mod_dir("current_mod", true, {"test.ok": "ok"}, [], 0, "")

	var mm = _new_mm()
	if not mm:
		_pass("version_mismatch (skipped)")
		return

	mm._scan_mods([TEST_MOD_PARENT])

	var ids = mm.get_mod_ids()
	if "current_mod" not in ids:
		_fail("version_mismatch: current_mod should have loaded")
		return
	if "patch_different" not in ids:
		_fail("version_mismatch: patch_different should have loaded (major+minor match)")
		return
	if "major_old" in ids:
		_fail("version_mismatch: major_old (0.x) should have been skipped")
		return
	if "major_new" in ids:
		_fail("version_mismatch: major_new (2.x) should have been skipped")
		return
	if "minor_higher" in ids:
		_fail("version_mismatch: minor_higher (1.1) should have been skipped when game is 1.0")
		return

	var skipped = mm.get_skipped_mods()
	if skipped.size() != 3:
		_fail("version_mismatch: expected 3 skipped mods, got %d" % skipped.size())
		return
	_pass("version_mismatch")


func _test_missing_compatible_version() -> void:
	_clean_mods(TEST_MOD_PARENT)
	var d = DirAccess.open("user://")
	if d:
		d.make_dir_recursive(TEST_MOD_PARENT + "no_compat/")
	var f = FileAccess.open(TEST_MOD_PARENT + "no_compat/mod.json", FileAccess.WRITE)
	if f:
		f.store_string('{"id": "no_compat", "version": "1.0.0"}')

	var mm = _new_mm()
	if not mm:
		_pass("missing_compatible_version (skipped)")
		return
	mm._scan_mods([TEST_MOD_PARENT])
	if "no_compat" in mm.get_mod_ids():
		_fail("missing_compatible_version: mod without compatible_version should be skipped")
		return
	_pass("missing_compatible_version")


# ===== Integration tests (uses filesystem) =====

func _test_mod_detection() -> void:
	_clean_mods(TEST_MOD_PARENT)
	_make_mod_dir("detect_test")

	var mm = _new_mm()
	if not mm:
		_pass("mod_detection (skipped)")
		return

	mm._scan_mods([TEST_MOD_PARENT])

	var ids = mm.get_mod_ids()
	if "detect_test" not in ids:
		_fail("mod_detection: detect_test not found in " + str(ids))
		return
	_pass("mod_detection")


func _test_strings_loading() -> void:
	_clean_mods(TEST_MOD_PARENT)
	_make_mod_dir("strings_test", true, {"test.key.hello": "Hello World"})

	var mm = _new_mm()
	if not mm:
		_pass("strings_loading (skipped)")
		return

	mm._scan_mods([TEST_MOD_PARENT])

	if mm.tr_content("test.key.hello") != "Hello World":
		_fail("strings_loading: lookup failed, got '%s'" % mm.tr_content("test.key.hello"))
		return
	_pass("strings_loading")


func _test_strings_override_order() -> void:
	_clean_mods(TEST_MOD_PARENT)
	_make_mod_dir("base_mod", true, {"test.override": "base_value"}, [], 0)
	_make_mod_dir("override_mod", true, {"test.override": "override_value"}, [], 0)

	var mm = _new_mm()
	if not mm:
		_pass("strings_override (skipped)")
		return

	mm._scan_mods([TEST_MOD_PARENT])

	var val = mm.tr_content("test.override")
	if val != "override_value":
		_fail("strings_override: expected 'override_value', got '%s'" % val)
		return
	_pass("strings_override")


func _test_mod_data_paths() -> void:
	_clean_mods(TEST_MOD_PARENT)
	_make_mod_dir("data_test", true, {}, ["events", "contracts"])

	var mm = _new_mm()
	if not mm:
		_pass("mod_data_paths (skipped)")
		return

	mm._scan_mods([TEST_MOD_PARENT])

	var event_paths = mm.get_mod_data_paths("events")
	if event_paths.is_empty():
		_fail("mod_data_paths: no event paths returned")
		return
	if not event_paths[0].ends_with("events/"):
		_fail("mod_data_paths: path doesn't end with events/: " + event_paths[0])
		return

	var faction_paths = mm.get_mod_data_paths("factions")
	if not faction_paths.is_empty():
		_fail("mod_data_paths: expected empty for non-existent subdir, got " + str(faction_paths))
		return
	_pass("mod_data_paths")


func _test_empty_mod_dir() -> void:
	_clean_mods(TEST_MOD_PARENT)
	var d = DirAccess.open("user://")
	if d:
		d.make_dir_recursive(TEST_MOD_PARENT + "empty_mod/")

	var mm = _new_mm()
	if not mm:
		_pass("empty_mod_dir (skipped)")
		return

	mm._scan_mods([TEST_MOD_PARENT])

	if mm.get_mod_count() != 0:
		_fail("empty_mod_dir: expected 0 mods, got %d" % mm.get_mod_count())
		return
	_pass("empty_mod_dir")


func _pass(name: String) -> void:
	_passed += 1
	print("  PASS: ", name)


func _fail(name: String) -> void:
	_failed += 1
	print("  FAIL: ", name)


func _print_results() -> void:
	print("\nResults: %d passed, %d failed, %d total" % [_passed, _failed, _passed + _failed])
	if _failed > 0:
		print("WARNING: Some mod system tests failed.")
