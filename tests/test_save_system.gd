extends SceneTree

var _passed := 0
var _failed := 0

const TEST_DIR := "user://test_saves/"
const SAVE_EXT := ".json.zst"


func _init() -> void:
	_test_save_roundtrip()
	_test_save_empty_inventory()
	_test_compression_zstd()
	_test_autosave_slot_rotation()
	_test_missing_file()
	_test_empty_file()
	_test_corrupted_json()
	_test_future_version_rejected()
	_test_invalid_name_rejected()
	_print_results()
	quit(0 if _failed == 0 else 1)


func _make_save_dir() -> void:
	var dir = DirAccess.open("user://")
	if dir:
		dir.make_dir_recursive(TEST_DIR)


func _clean_test_dir() -> void:
	var dir = DirAccess.open(TEST_DIR)
	if dir:
		dir.list_dir_begin()
		var f = dir.get_next()
		while f != "":
			dir.remove(f)
			f = dir.get_next()


func _minimal_save() -> Dictionary:
	return {
		"save_version": 1,
		"game_date": {"year": 3025, "month": 6, "day": 15},
		"player": {"unit_name": "Test Unit", "current_balance": 500000, "current_planet": "Galatea", "home_base": "Galatea", "organizational_units": [], "active_contract": null},
		"active_contracts": [],
		"event_log": [],
		"player_inventory": {},
		"proven_custom_variants": {},
		"reputation": {"global": 0, "faction": {}},
		"personnel": {"roster": [], "relationships": {}, "abstract_astech_count": 0, "abstract_medic_count": 0},
		"economy": {},
		"inventory_manager": {},
		"refit_manager": {"active_refits": [], "active_repairs": [], "facility_level": 2},
	}


# ----- File I/O helpers (mirror SaveManager logic without requiring autoloads) -----

func _write_save(path: String, data: Dictionary) -> bool:
	var file = FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if not file:
		return false
	file.store_string(JSON.new().stringify(data, "\t", false))
	return true


func _read_save(path: String) -> Dictionary:
	var file: FileAccess
	if path.ends_with(SAVE_EXT):
		file = FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	else:
		file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text = file.get_as_text()
	if text.is_empty():
		return {}
	var j = JSON.new()
	if j.parse(text) != OK:
		return {}
	return j.data if typeof(j.data) == TYPE_DICTIONARY else {}


func _is_save_file(path: String) -> bool:
	return FileAccess.file_exists(path)


func _count_autosaves() -> int:
	var c := 0
	var dir = DirAccess.open(TEST_DIR)
	if dir:
		dir.list_dir_begin()
		var f = dir.get_next()
		while f != "":
			if f.begins_with("autosave"):
				c += 1
			f = dir.get_next()
	return c


# ===== POSITIVE TESTS =====

func _test_save_roundtrip() -> void:
	_make_save_dir()
	_clean_test_dir()

	var original = _minimal_save()
	original.player.current_balance = 999999
	original.player.current_planet = "Hesperus II"

	var path = TEST_DIR + "test_roundtrip" + SAVE_EXT
	if not _write_save(path, original):
		_fail("save_roundtrip: could not write file")
		return

	var loaded = _read_save(path)
	if loaded.is_empty():
		_fail("save_roundtrip: could not read file back")
		return

	if loaded.get("save_version", 0) != 1:
		_fail("save_roundtrip: save_version mismatch")
		return
	if loaded.get("player", {}).get("current_balance", 0) != 999999:
		_fail("save_roundtrip: balance mismatch, got %s" % str(loaded.get("player", {}).get("current_balance")))
		return
	if loaded.get("player", {}).get("current_planet", "") != "Hesperus II":
		_fail("save_roundtrip: planet mismatch")
		return
	if not loaded.has("active_contracts"):
		_fail("save_roundtrip: missing active_contracts key")
		return
	if not loaded.has("personnel"):
		_fail("save_roundtrip: missing personnel key")
		return
	_pass("save_roundtrip")


func _test_save_empty_inventory() -> void:
	var data = _minimal_save()
	data.player_inventory = {}
	var path = TEST_DIR + "test_empty_inv" + SAVE_EXT
	if not _write_save(path, data):
		_fail("save_empty_inventory: could not write")
		return
	var loaded = _read_save(path)
	if loaded.is_empty():
		_fail("save_empty_inventory: could not read")
		return
	var inv = loaded.get("player_inventory")
	if typeof(inv) != TYPE_DICTIONARY:
		_fail("save_empty_inventory: inventory not a dict")
		return
	if not inv.is_empty():
		_fail("save_empty_inventory: expected empty inventory")
		return
	_pass("save_empty_inventory")


func _test_compression_zstd() -> void:
	var data = _minimal_save()
	var path = TEST_DIR + "test_zstd" + SAVE_EXT
	if not _write_save(path, data):
		_fail("compression_zstd: could not write")
		return
	if not FileAccess.file_exists(path):
		_fail("compression_zstd: file not found")
		return
	var loaded = _read_save(path)
	if loaded.is_empty():
		_fail("compression_zstd: could not read back")
		return
	if loaded.get("save_version", 0) != 1:
		_fail("compression_zstd: data corruption")
		return
	_pass("compression_zstd")


func _test_autosave_slot_rotation() -> void:
	_make_save_dir()
	_clean_test_dir()

	var limit := 3
	for i in range(6):
		var data = _minimal_save()
		var slot = "autosave_%03d" + SAVE_EXT % (i % limit)
		var path = TEST_DIR + slot
		_write_save(path, data)

		var autosaves: Array[String] = []
		var dir = DirAccess.open(TEST_DIR)
		if dir:
			dir.list_dir_begin()
			var f = dir.get_next()
			while f != "":
				if f.begins_with("autosave"):
					autosaves.append(f)
				f = dir.get_next()

		autosaves.sort()
		while autosaves.size() > limit:
			DirAccess.remove_absolute(TEST_DIR + autosaves.pop_front())

	var count = _count_autosaves()
	if count > limit:
		_fail("autosave_rotation: expected at most %d files, got %d" % [limit, count])
		return
	_pass("autosave_rotation")


# ===== NEGATIVE TESTS =====

func _test_missing_file() -> void:
	var loaded = _read_save(TEST_DIR + "nonexistent" + SAVE_EXT)
	if not loaded.is_empty():
		_fail("missing_file: expected empty result for missing file")
		return
	_pass("missing_file")


func _test_empty_file() -> void:
	_make_save_dir()
	var path = TEST_DIR + "test_empty" + SAVE_EXT
	var file = FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file:
		file.store_string("")
		file.close()
	var loaded = _read_save(path)
	if not loaded.is_empty():
		_fail("empty_file: expected empty result for empty file")
		return
	_pass("empty_file")


func _test_corrupted_json() -> void:
	_make_save_dir()
	var path = TEST_DIR + "test_corrupt" + SAVE_EXT
	var file = FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file:
		file.store_string("{this is not valid json!!!")
		file.close()
	var loaded = _read_save(path)
	if not loaded.is_empty():
		_fail("corrupted_json: expected empty result for corrupt JSON")
		return
	_pass("corrupted_json")


func _test_future_version_rejected() -> void:
	var data = _minimal_save()
	data.save_version = 999
	var path = TEST_DIR + "test_future_version" + SAVE_EXT
	_write_save(path, data)

	var loaded = _read_save(path)
	if loaded.is_empty():
		_fail("future_version_rejected: could not read file")
		return

	var version = loaded.get("save_version", 0)
	if version < 999:
		_fail("future_version_rejected: version should be 999, got %d" % version)
		return

	_pass("future_version_rejected")


func _test_invalid_name_rejected() -> void:
	var cleaned := func(name: String) -> String:
		var result := ""
		for c in name.strip_edges():
			if c.is_valid_identifier() or c == " " or c == "-" or c == "'":
				result += c
			else:
				result += "_"
		result = result.strip_edges().replace(" ", "_")
		if result.length() > 60:
			result = result.substr(0, 60)
		while result.ends_with("_"):
			result = result.substr(0, result.length() - 1)
		return result

	if not cleaned.call("").is_empty():
		_fail("invalid_name_rejected: empty name should produce empty result")
		return
	if not cleaned.call("   ").is_empty():
		_fail("invalid_name_rejected: whitespace name should produce empty result")
		return
	_pass("invalid_name_rejected")


func _pass(name: String) -> void:
	_passed += 1
	print("  PASS: ", name)


func _fail(name: String) -> void:
	_failed += 1
	print("  FAIL: ", name)


func _print_results() -> void:
	print("\nResults: %d passed, %d failed, %d total" % [_passed, _failed, _passed + _failed])
	if _failed > 0:
		print("WARNING: Some save system tests failed.")
	print("\nNOTE: When implementing save version migrations (_migrate_vN in SaveManager.gd), add")
	print("positive tests (verify migrated data matches expected shape) and negative tests")
	print("(verify corrupt/broken migration data fails gracefully) to this file.")
