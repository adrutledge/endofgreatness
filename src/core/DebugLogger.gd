extends Node

## Structured debug logger — autoload that subscribes to EventBus signals
## and writes formatted log entries to stderr.
##
## Maintains a ring buffer (MAX_ENTRIES) accessible via get_recent() for
## in-game debug UI panels.
##
## Loads after EventBus but before DataManager so boot-time parse errors
## are captured.

var log_entries: Array[Dictionary] = []
const MAX_ENTRIES := 1000


func _ready() -> void:
	if not EventBus:
		return

	EventBus.parse_error.connect(func(path: String, msg: String): _log("ERROR", "parse", "%s — %s" % [path, msg]))
	EventBus.rules_check.connect(func(_id: String, _params: Dictionary, _res): null)  # only stderr in debug; too verbose for normal output
	EventBus.personnel_joined.connect(func(p, reason: String, _d): _log("INFO", "personnel", "%s joined (%s)" % [p.personnel_name, reason]))
	EventBus.personnel_left.connect(func(p, reason: String, _d): _log("INFO", "personnel", "%s left (%s)" % [p.personnel_name, reason]))
	EventBus.jump_completed.connect(func(from_sys: String, to_sys: String, _r): _log("INFO", "travel", "%s → %s" % [from_sys, to_sys]))
	EventBus.contract_arrived.connect(func(c): _log("INFO", "contract", "Arrived at %s (%s)" % [c.planet, c.activity_type]))

	EventBus.contract_accepted.connect(func(c): _log("INFO", "contract", "Accepted: %s — %s on %s" % [c.issuer, c.activity_type, c.planet]))
	EventBus.contract_completed.connect(func(c): _log("INFO", "contract", "Completed: %s — %s on %s" % [c.issuer, c.activity_type, c.planet]))
	EventBus.tactical_engagement_started.connect(func(c, _h): _log("INFO", "combat", "Engagement started on %s" % c.planet))
	EventBus.tactical_engagement_resolved.connect(func(r): _log("INFO", "combat", "Engagement resolved"))
	EventBus.unit_damaged.connect(func(u, comp): _log("WARN", "combat", "%s damaged: %s" % [u.unit_name, comp.component_name]))
	EventBus.funds_depleted.connect(func(b): _log("WARN", "economy", "Funds depleted: %s" % Helpers.fmt_money(b)))
	EventBus.funds_low_for_reorder.connect(func(b, r): _log("WARN", "economy", "Funds low for reorder: balance=%s required=%s" % [Helpers.fmt_money(b), Helpers.fmt_money(r)]))
	EventBus.bills_paid.connect(func(amount, _b): _log("INFO", "economy", "Bills paid: %s" % Helpers.fmt_money(amount)))
	EventBus.save_completed.connect(func(s): _log("INFO", "save", "Save %s" % ("succeeded" if s else "failed")))
	EventBus.load_completed.connect(func(s): _log("INFO", "save", "Load %s" % ("succeeded" if s else "failed")))


func _log(level: String, category: String, msg: String) -> void:
	var entry := {
		"time": _timestamp(),
		"level": level,
		"category": category,
		"message": msg,
	}
	log_entries.append(entry)
	if log_entries.size() > MAX_ENTRIES:
		log_entries.pop_front()
	if Engine.has_singleton("OpenCodeDebugger"):
		Engine.get_singleton("OpenCodeDebugger").debug_log(level, category, msg)
	else:
		printerr("[%s][%s] %s" % [level, category, msg])


static func _timestamp() -> String:
	var d = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [d.year, d.month, d.day, d.hour, d.minute, d.second]


func get_recent(count: int = 50) -> Array[Dictionary]:
	return log_entries.slice(-count)
