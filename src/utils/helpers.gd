class_name Helpers
extends RefCounted

static var debug: bool = false


static var _debug_checked: bool = false


static func _ensure_debug() -> void:
	if _debug_checked:
		return
	_debug_checked = true
	if Engine.is_editor_hint():
		return
	for arg in OS.get_cmdline_user_args():
		if arg == "--opencode-debug" or arg == "-d":
			debug = true
			break
	if not debug:
		var env = OS.get_environment("OPENCODE_debug")
		if env and env.to_lower() in ["1", "true", "yes"]:
			debug = true


static func debug_print(tag: String, msg: String) -> void:
	_ensure_debug()
	if not debug:
		return
	printerr("[DBG][%s] %s" % [tag, msg])


static func debug_warn(tag: String, msg: String) -> void:
	_ensure_debug()
	if not debug:
		return
	push_warning("[DBG][%s] %s" % [tag, msg])


static func validate_nodes(tag: String, pairs) -> void:
	if not debug:
		return
	for pair in pairs:
		var name = pair[0]
		var node = pair[1]
		if node == null:
			push_warning("[DBG][%s] NODE NULL: %s" % [tag, name])


static func fmt_number(amount: float) -> String:
	var n = int(round(amount))
	var s = str(n)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result


static func fmt_money(amount: int) -> String:
	var abs_amt = abs(amount)
	var prefix = "-" if amount < 0 else ""
	if abs_amt >= 100000000:
		return prefix + str(abs_amt / 1000000) + "M CSB"
	elif abs_amt >= 1000000:
		var m = abs_amt / 1000000
		var frac = (abs_amt % 1000000) / 100000
		return prefix + str(m) + "." + str(frac) + "M CSB"
	elif abs_amt >= 1000:
		var k = abs_amt / 1000
		var frac = (abs_amt % 1000) / 100
		return prefix + str(k) + "." + str(frac) + "K CSB"
	return prefix + fmt_number(amount) + " CSB"
