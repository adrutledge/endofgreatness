class_name Helpers
extends RefCounted

static var DEBUG: bool = false


static var _debug_checked: bool = false


static func _ensure_debug() -> void:
	if _debug_checked:
		return
	_debug_checked = true
	if Engine.is_editor_hint():
		return
	for arg in OS.get_cmdline_user_args():
		if arg == "--opencode-debug" or arg == "-d":
			DEBUG = true
			break
	if not DEBUG:
		var env = OS.get_environment("OPENCODE_DEBUG")
		if env and env.to_lower() in ["1", "true", "yes"]:
			DEBUG = true


static func debug_print(tag: String, msg: String) -> void:
	_ensure_debug()
	if not DEBUG:
		return
	printerr("[DBG][%s] %s" % [tag, msg])


static func debug_warn(tag: String, msg: String) -> void:
	_ensure_debug()
	if not DEBUG:
		return
	push_warning("[DBG][%s] %s" % [tag, msg])


static func validate_nodes(tag: String, pairs) -> void:
	if not DEBUG:
		return
	for pair in pairs:
		var name = pair[0]
		var node = pair[1]
		if node == null:
			push_warning("[DBG][%s] NODE NULL: %s" % [tag, name])


static func fmt_money(amount: int) -> String:
	if amount >= 1000000:
		var m = amount / 1000000
		var frac = (amount % 1000000) / 100000
		return str(m) + "." + str(frac) + "M CSB"
	elif amount >= 1000:
		var k = amount / 1000
		var frac = (amount % 1000) / 100
		return str(k) + "." + str(frac) + "K CSB"
	return str(amount) + " CSB"
