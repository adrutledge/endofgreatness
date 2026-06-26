class_name SaveIO
extends RefCounted


static func write_save_file(path: String, data: Dictionary) -> void:
	var json_str := JSON.new().stringify(data, "\t", false)
	var file = FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file:
		file.store_string(json_str)


static func read_json_file(path: String) -> Dictionary:
	var file: FileAccess
	if path.ends_with(".json.zst"):
		file = FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	elif path.ends_with(".json.gz"):
		file = FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
	else:
		file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	if text.is_empty():
		return {}
	var j := JSON.new()
	if j.parse(text) != OK:
		if Helpers.debug:
			EventBus.emit_parse_error(path, j.get_error_message())
		return {}
	if typeof(j.data) != TYPE_DICTIONARY:
		return {}
	return j.data


static func is_save_file(fname: String) -> bool:
	return fname.ends_with(".json.zst")


static func is_autosave_file(fname: String) -> bool:
	return fname.begins_with("autosave") and fname.ends_with(".json.zst")


static func ensure_save_dir(path: String) -> void:
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists(path):
		dir.make_dir_recursive(path)


static func next_autosave_slot(save_dir: String, prefix: String, ext: String, rotation_count: int) -> String:
	var max_idx := -1
	var dir = DirAccess.open(save_dir)
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.begins_with(prefix) and fname.ends_with(ext):
				var base = fname.trim_suffix(ext)
				var parts = base.split("_")
				if parts.size() >= 2:
					var idx = int(parts[parts.size() - 1])
					if idx > max_idx:
						max_idx = idx
			fname = dir.get_next()
	var next_idx: int = maxi(0, (max_idx + 1) % rotation_count)
	return prefix + "_%03d" % next_idx + ext


static func prune_autosaves(save_dir: String, prefix: String, ext: String, max_count: int) -> void:
	var autosaves: Array[String] = []
	var dir = DirAccess.open(save_dir)
	if not dir:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.begins_with(prefix) and fname.ends_with(ext):
			autosaves.append(fname)
		fname = dir.get_next()
	autosaves.sort()
	while autosaves.size() > max_count:
		var oldest = autosaves.pop_front()
		DirAccess.remove_absolute(save_dir + oldest)


static func list_saves(save_dir: String) -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	var dir = DirAccess.open(save_dir)
	if not dir:
		return saves
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not is_save_file(fname):
			fname = dir.get_next()
			continue
		var label = fname.trim_suffix(".json").trim_suffix(".zst")
		var meta = read_metadata(save_dir + fname)
		if meta.is_empty():
			meta = {"label": label}
		meta["filename"] = fname
		meta["is_autosave"] = fname.begins_with("autosave")
		meta["modified_time"] = FileAccess.get_modified_time(save_dir + fname)
		saves.append(meta)
		fname = dir.get_next()
	dir.list_dir_end()
	saves.sort_custom(func(a, b): return a.get("modified_time", 0) > b.get("modified_time", 0))
	return saves


static func read_metadata(path: String) -> Dictionary:
	var data = read_json_file(path)
	if data.is_empty():
		return {}
	var meta = data.get("metadata")
	return meta if typeof(meta) == TYPE_DICTIONARY else {}


static func delete_save_file(path: String) -> bool:
	return DirAccess.remove_absolute(path) == OK


static func sanitize_name(name: String) -> String:
	var cleaned := ""
	for c in name.strip_edges():
		if c.is_valid_identifier() or c == " " or c == "-" or c == "'":
			cleaned += c
		else:
			cleaned += "_"
	cleaned = cleaned.strip_edges().replace(" ", "_")
	if cleaned.length() > 60:
		cleaned = cleaned.substr(0, 60)
	while cleaned.ends_with("_"):
		cleaned = cleaned.substr(0, cleaned.length() - 1)
	return cleaned
