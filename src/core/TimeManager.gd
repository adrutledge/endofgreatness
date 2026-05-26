extends Node

var current_date: Dictionary = {
	"year": 3025,
	"month": 1,
	"day": 1
}

var is_paused: bool = false
var tick_interval: float = 1.0
var elapsed_time: float = 0.0
var tactical_round: int = 0
var is_tactical_mode: bool = false
var total_days: int = 0

signal date_changed(date: Dictionary)

func _process(delta: float) -> void:
	if is_paused or is_tactical_mode:
		return
	elapsed_time += delta
	if elapsed_time >= tick_interval:
		elapsed_time = 0.0
		advance_day()

func pause() -> void:
	is_paused = true

func resume() -> void:
	is_paused = false

func toggle_pause() -> void:
	is_paused = not is_paused

func advance_day() -> void:
	var days_in_month = get_days_in_month(current_date.month, current_date.year)
	current_date.day += 1
	if current_date.day > days_in_month:
		current_date.day = 1
		current_date.month += 1
		if current_date.month > 12:
			current_date.month = 1
			current_date.year += 1
	total_days += 1
	date_changed.emit(current_date.duplicate())
	EventBus.emit_time_tick(current_date.duplicate())
	if current_date.day == 1:
		EventBus.emit_month_started(current_date.duplicate())
	_check_timeline_events()


func _check_timeline_events() -> void:
	var events = GameState.get("timeline_events")
	if not events or events.is_empty():
		return
	var date_str = get_date_string()
	for event in events:
		if event.get("date", "") == date_str:
			EventBus.emit_event_triggered(event)
			if event.get("type") == "ownership_change":
				var d = event.get("data", {})
				var system = d.get("system", "")
				var to_faction = d.get("to_faction", "")
				if system and to_faction and GameState.known_systems.has(system):
					GameState.known_systems[system]["owner_faction"] = to_faction

func enter_tactical_mode() -> void:
	is_tactical_mode = true
	tactical_round = 0

func exit_tactical_mode() -> void:
	is_tactical_mode = false
	tactical_round = 0

func advance_tactical_round() -> void:
	tactical_round += 1

func get_days_in_month(month: int, year: int) -> int:
	var days: Dictionary = {
		1: 31, 2: 28, 3: 31, 4: 30, 5: 31, 6: 30,
		7: 31, 8: 31, 9: 30, 10: 31, 11: 30, 12: 31
	}
	if month == 2 and (year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)):
		return 29
	return days.get(month, 30)

func get_date_string() -> String:
	return "%d-%02d-%02d" % [current_date.year, current_date.month, current_date.day]

func set_tick_interval(seconds: float) -> void:
	tick_interval = max(seconds, 0.1)
