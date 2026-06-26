extends Node

const GAME_VERSION: String = "1.0.0"  # MAJOR = V number (plan.md V1–V8)

var mods: Array[Dictionary] = []
var _strings: Dictionary = {}
var _loaded: bool = false
var _search_paths_override: Array[String] = []
var _skipped_mods: Array[Dictionary] = []


func _ready() -> void:
	pass


func ensure_loaded() -> void:
	if _loaded:
		return
	_scan_mods()


func _scan_mods(paths_override: Array = []) -> void:
	if _loaded:
		return
	_loaded = true
	var paths = paths_override if not paths_override.is_empty() else (_search_paths_override if not _search_paths_override.is_empty() else _get_mod_search_paths())
	for base_path in paths:
		var dir = DirAccess.open(base_path)
		if not dir:
			continue
		dir.list_dir_begin()
		var entry = dir.get_next()
		while entry != "":
			if entry == "." or entry == "..":
				entry = dir.get_next()
				continue
			if dir.current_is_dir():
				_load_mod(base_path + entry + "/")
			entry = dir.get_next()

	mods.sort_custom(func(a, b): return a.get("load_priority", 0) < b.get("load_priority", 0))

	for m in mods:
		_load_strings(m)


func _get_mod_search_paths() -> Array[String]:
	var result: Array[String] = ["res://mods/"]
	var user_mods = "user://mods/"
	var udir = DirAccess.open("user://")
	if udir and not udir.dir_exists(user_mods):
		udir.make_dir_recursive(user_mods)
	if udir:
		result.append(user_mods + "/")
	return result


func _load_mod(mod_dir: String) -> void:
	var mod_file := mod_dir + "mod.json"
	var file = FileAccess.open(mod_file, FileAccess.READ)
	if not file:
		return
	var j := JSON.new()
	if j.parse(file.get_as_text()) != OK:
		if Helpers.debug:
			EventBus.emit_parse_error(mod_file, j.get_error_message())
		return
	if typeof(j.data) != TYPE_DICTIONARY:
		printerr("ModManager: Invalid mod.json in ", mod_dir)
		return
	var meta = j.data
	var mod_id = meta.get("id", "?")
	var mod_ver = str(meta.get("version", "0"))
	var compat = meta.get("compatible_version", "")
	if compat.is_empty():
		push_warning("ModManager: Mod '%s' v%s has no compatible_version — skipped." % [mod_id, mod_ver])
		meta["_dir"] = mod_dir
		_skipped_mods.append(meta)
		return
	if not _is_version_compatible(compat):
		push_warning("ModManager: Mod '%s' v%s requires game v%s but current is v%s — skipped." % [mod_id, mod_ver, compat, GAME_VERSION])
		meta["_dir"] = mod_dir
		_skipped_mods.append(meta)
		return
	meta["_dir"] = mod_dir
	mods.append(meta)
	Helpers.debug_print("ModManager", "Loaded mod: " + mod_id + " v" + mod_ver)


static func _parse_version(ver: String) -> Array:
	var parts = ver.split(".")
	var major = int(parts[0]) if parts.size() >= 1 else 0
	var minor = int(parts[1]) if parts.size() >= 2 else 0
	var patch = int(parts[2]) if parts.size() >= 3 else 0
	return [major, minor, patch]


func _is_version_compatible(mod_compat: String) -> bool:
	var game = _parse_version(GAME_VERSION)
	var modv = _parse_version(mod_compat)
	return game[0] == modv[0] and game[1] == modv[1]


func _load_strings(mod: Dictionary) -> void:
	var strings_file = mod.get("_dir", "") + "strings.json"
	var file = FileAccess.open(strings_file, FileAccess.READ)
	if not file:
		return
	var j := JSON.new()
	if j.parse(file.get_as_text()) != OK:
		if Helpers.debug:
			EventBus.emit_parse_error("strings.json:" + mod.get("id", "?"), j.get_error_message())
		return
	if typeof(j.data) != TYPE_DICTIONARY:
		return
	for key in j.data:
		_strings[key] = j.data[key]


func tr_content(key: String) -> String:
	assert(typeof(key) == TYPE_STRING, "tr_content: key must be a String")
	if key.is_empty():
		return key
	ensure_loaded()
	if _strings.has(key):
		return _strings[key]
	var translated := tr(key)
	if translated != key:
		return translated
	return key


func has_string(key: String) -> bool:
	assert(typeof(key) == TYPE_STRING, "has_string: key must be a String")
	if key.is_empty():
		return false
	ensure_loaded()
	return _strings.has(key)


func get_mod_ids() -> Array[String]:
	ensure_loaded()
	var result: Array[String] = []
	for m in mods:
		result.append(m.get("id", ""))
	return result


func get_string_count() -> int:
	ensure_loaded()
	return _strings.size()


func get_mod_count() -> int:
	ensure_loaded()
	return mods.size()


func get_skipped_mods() -> Array[Dictionary]:
	ensure_loaded()
	return _skipped_mods.duplicate()


func get_loaded_versions() -> Dictionary:
	ensure_loaded()
	var result: Dictionary = {}
	for m in mods:
		result[m.get("id", "")] = m.get("version", "0.0.0")
	return result


var _mod_migrations: Dictionary = {}


func register_migration(mod_id: String, callable: Callable, from_version: String, to_version: String) -> void:
	var key = "%s:%s->%s" % [mod_id, from_version, to_version]
	_mod_migrations[key] = callable


func run_mod_migrations(saved_versions: Dictionary) -> void:
	for mod_id in saved_versions:
		var saved_ver = str(saved_versions[mod_id])
		var current_ver = get_loaded_versions().get(mod_id, "")
		if current_ver.is_empty():
			push_warning("ModManager: Save has data for mod '%s' v%s but it is not loaded" % [mod_id, saved_ver])
			continue
		if saved_ver == current_ver:
			continue
		# Downgrades not supported
		if _semver_compare(current_ver, saved_ver) < 0:
			push_warning("ModManager: Mod '%s' downgraded from v%s to v%s — migrations skipped" % [mod_id, saved_ver, current_ver])
			continue
		var mod_data = _mod_extras.get(mod_id, {})
		var migrated = _run_mod_migration_chain(mod_id, saved_ver, current_ver, mod_data)
		if migrated != null:
			_mod_extras[mod_id] = migrated


func _semver_compare(a: String, b: String) -> int:
	var pa = _parse_version(a)
	var pb = _parse_version(b)
	for i in range(3):
		if pa[i] < pb[i]:
			return -1
		if pa[i] > pb[i]:
			return 1
	return 0


func _run_mod_migration_chain(mod_id: String, from_ver: String, to_ver: String, mod_data: Dictionary):
	# Iterate through intermediate versions, chaining migrations step by step.
	# Each step receives the output of the previous step.
	var current = from_ver
	var data = mod_data.duplicate(true)

	# Split versions into components for iteration
	var parts_from = _parse_version(from_ver)
	var parts_to = _parse_version(to_ver)

	while _semver_compare(current, to_ver) < 0:
		var next = _next_version(current, parts_to)
		var key = "%s:%s->%s" % [mod_id, current, next]
		if not _mod_migrations.has(key):
			push_warning("ModManager: No migration registered for mod '%s' v%s -> v%s" % [mod_id, current, next])
			return null
		var result = _call_migration_safe(key, data)
		if result == null:
			push_error("ModManager: Migration failed for mod '%s' v%s -> v%s — original data preserved" % [mod_id, current, next])
			return mod_data  # Return original, not partially-migrated
		data = result
		current = next

	return data


func _call_migration_safe(key: String, data: Dictionary) -> Dictionary:
	var result = _mod_migrations[key].call(data)
	if typeof(result) == TYPE_DICTIONARY:
		return result
	push_error("ModManager: Migration '%s' returned non-Dictionary — data preserved" % key)
	return {}


func _next_version(current: String, target_parts: Array) -> String:
	# Step by patch, then minor, then major until we reach the target.
	var parts = _parse_version(current)
	if parts[2] < target_parts[2]:
		parts[2] += 1
	elif parts[1] < target_parts[1]:
		parts[1] += 1
		parts[2] = 0
	elif parts[0] < target_parts[0]:
		parts[0] += 1
		parts[1] = 0
		parts[2] = 0
	return "%d.%d.%d" % parts


var _mod_extras: Dictionary = {}


func set_mod_data(mod_id: String, data: Dictionary) -> void:
	_mod_extras[mod_id] = data.duplicate()


func get_mod_data(mod_id: String) -> Dictionary:
	return _mod_extras.get(mod_id, {}).duplicate()


func get_all_mod_data() -> Dictionary:
	return _mod_extras.duplicate()


func clear_mod_data() -> void:
	_mod_extras.clear()


func get_mod_data_paths(data_type: String) -> Array[String]:
	ensure_loaded()
	var result: Array[String] = []
	for m in mods:
		var dir = m.get("_dir", "")
		var sub = dir + data_type + "/"
		if DirAccess.dir_exists_absolute(sub):
			result.append(sub)
	return result
