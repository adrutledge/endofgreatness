extends Node

const SAVE_VERSION: int = 1
const SAVE_DIR: String = "user://saves/"
var AUTOSAVE_PREFIX: String = "autosave"
const SAVE_EXTENSION: String = ".json.zst"

var autosave_enabled: bool = true
var autosave_interval: String = "monthly"
var autosave_rotation_count: int = 5
var last_autosave_day: int = -1

var _save_lock: bool = false


func _ready() -> void:
	SaveIO.ensure_save_dir(SAVE_DIR)
	_connect_autosave()


func _exit_tree() -> void:
	var eb = _get_eventbus()
	if eb and eb.month_started.is_connected(_on_month_started):
		eb.month_started.disconnect(_on_month_started)


func _connect_autosave() -> void:
	var eb = _get_eventbus()
	if eb and eb.has_signal("month_started"):
		eb.month_started.connect(_on_month_started)


func _get_eventbus():
	return get_node_or_null("/root/EventBus")


func _emit(event_name: String, args: Array = []) -> void:
	var eb = _get_eventbus()
	if not eb or not eb.has_method("emit_" + event_name):
		return
	eb.callv("emit_" + event_name, args)


func _on_month_started(_date: Dictionary) -> void:
	if not autosave_enabled:
		return
	if autosave_interval != "monthly":
		return
	if not TimeManager:
		push_error("SaveManager: TimeManager not available")
		return
	var today = TimeManager.total_days
	if today == last_autosave_day:
		return
	last_autosave_day = today
	autosave()


func _on_deploy() -> void:
	if not autosave_enabled:
		return
	autosave()


func autosave() -> void:
	assert(not SAVE_DIR.is_empty(), "SaveManager: SAVE_DIR is empty")
	if _save_lock:
		return
	_emit("save_started")
	var data := SaveSerializer.capture_state()
	SaveSerializer.attach_metadata(data, "autosave")
	var slot := SaveIO.next_autosave_slot(SAVE_DIR, AUTOSAVE_PREFIX, SAVE_EXTENSION, autosave_rotation_count)
	SaveIO.write_save_file(SAVE_DIR + slot, data)
	SaveIO.prune_autosaves(SAVE_DIR, AUTOSAVE_PREFIX, SAVE_EXTENSION, autosave_rotation_count)
	_emit("save_completed", [true])


func manual_save(save_name: String) -> Dictionary:
	assert(typeof(save_name) == TYPE_STRING, "manual_save: save_name must be a String")
	if save_name.is_empty():
		return {"success": false, "reason": tr("Invalid save name")}
	if _save_lock:
		return {"success": false, "reason": tr("Save already in progress")}
	_save_lock = true
	var result := _do_manual_save(save_name)
	_save_lock = false
	return result


func _do_manual_save(save_name: String) -> Dictionary:
	var cleaned := SaveIO.sanitize_name(save_name)
	if cleaned.is_empty():
		return {"success": false, "reason": tr("Invalid save name")}
	_emit("save_started")
	var data := SaveSerializer.capture_state()
	SaveSerializer.attach_metadata(data, cleaned)
	var date_str := TimeManager.get_date_string()
	var filename := cleaned + "_" + date_str + SAVE_EXTENSION
	SaveIO.write_save_file(SAVE_DIR + filename, data)
	_emit("save_completed", [true])
	return {"success": true, "path": SAVE_DIR + filename, "filename": filename}


func load_game(path: String) -> Dictionary:
	assert(typeof(path) == TYPE_STRING, "load_game: path must be a String")
	if path.is_empty():
		return {"success": false, "reason": "No save path provided"}
	if _save_lock:
		return {"success": false, "reason": "Load already in progress"}
	_save_lock = true
	var result := _do_load(path)
	_save_lock = false
	return result


func _do_load(path: String) -> Dictionary:
	_emit("load_started")
	var data := SaveIO.read_json_file(path)
	if data.is_empty():
		_emit("load_completed", [false])
		return {"success": false, "reason": tr("Could not read save file")}
	data = _run_migrations(data)
	if data.is_empty():
		_emit("load_completed", [false])
		return {"success": false, "reason": tr("Migration failed")}
	if not data.has("player") or data.player.is_empty():
		_emit("load_completed", [false])
		return {"success": false, "reason": tr("Save file missing player data")}

	# Check mod version consistency
	_check_mod_versions(data)

	# Restore mod extra data
	if data.has("mod_extras") and ModManager:
		ModManager.clear_mod_data()
		for mod_id in data.mod_extras:
			ModManager.set_mod_data(mod_id, data.mod_extras[mod_id])

	# Run mod migrations
	if data.has("mod_versions") and ModManager:
		ModManager.run_mod_migrations(data.mod_versions)

	SaveSerializer.restore_time_state(data)
	SaveSerializer.restore_player(data)
	SaveSerializer.restore_contracts(data)
	SaveSerializer.restore_inventory(data)
	SaveSerializer.restore_reputation(data)
	SaveSerializer.restore_personnel(data)
	SaveSerializer.restore_economy(data)
	SaveSerializer.restore_inventory_manager(data)
	SaveSerializer.restore_refit_manager(data)
	_emit("load_completed", [true])
	return {"success": true}


func _run_migrations(data: Dictionary) -> Dictionary:
	var version = data.get("save_version", 1)
	if version > SAVE_VERSION:
		printerr("SaveManager: save version ", version, " is newer than current ", SAVE_VERSION)
		return {}
	while version < SAVE_VERSION:
		version += 1
		var func_name := "_upgrade_to_v%d" % version
		if has_method(func_name):
			data = call(func_name, data)
			if data.is_empty():
				return {}
	data["save_version"] = SAVE_VERSION
	return data


func _upgrade_to_v2(data: Dictionary) -> Dictionary:
	return data


func list_saves() -> Array[Dictionary]:
	return SaveIO.list_saves(SAVE_DIR)


func delete_save(filename: String) -> bool:
	return SaveIO.delete_save_file(SAVE_DIR + SaveIO.sanitize_name(filename))


func get_save_path(filename: String) -> String:
	return SAVE_DIR + filename.replace("..", "").replace("~", "").replace("/", "_").replace("\\", "_")


func _check_mod_versions(data: Dictionary) -> void:
	if not ModManager or not data.has("mod_versions"):
		return
	var saved: Dictionary = data.mod_versions
	var current: Dictionary = ModManager.get_loaded_versions()

	# Warn for mods that were present at save time but are now missing
	for mod_id in saved:
		if not current.has(mod_id):
			push_warning("SaveManager: Save has data for mod '%s' v%s but it is not currently loaded" % [mod_id, saved[mod_id]])

	# Warn for mods whose version changed since save time
	for mod_id in current:
		if saved.has(mod_id) and str(saved[mod_id]) != str(current[mod_id]):
			push_warning("SaveManager: Mod '%s' version changed: saved v%s, current v%s" % [mod_id, saved[mod_id], current[mod_id]])


func get_mod_data(mod_id: String) -> Dictionary:
	if not ModManager:
		return {}
	return ModManager.get_mod_data(mod_id)


func set_mod_data(mod_id: String, data: Dictionary) -> void:
	if not ModManager:
		return
	ModManager.set_mod_data(mod_id, data)
