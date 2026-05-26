class_name EventLog
extends Panel

signal closed()

@onready var event_list: ItemList = %EventList
@onready var detail_title: Label = %DetailTitle
@onready var detail_date: Label = %DetailDate
@onready var detail_body: Label = %DetailBody
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	Helpers.debug_print("EventLog", "_ready start")
	Helpers.validate_nodes("EventLog", [
		["event_list", event_list], ["detail_title", detail_title],
		["detail_date", detail_date], ["detail_body", detail_body],
		["close_button", close_button],
	])
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	add_theme_stylebox_override("panel", bg_style)

	var detail_style = StyleBoxFlat.new()
	detail_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	%DetailPanel.add_theme_stylebox_override("panel", detail_style)

	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	detail_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	detail_date.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	close_button.pressed.connect(_on_close)
	event_list.item_selected.connect(_on_event_selected)
	Helpers.debug_print("EventLog", "_ready done")

func populate() -> void:
	Helpers.debug_print("EventLog", "populate — log_size=%d" % GameState.event_log.size())
	event_list.clear()
	detail_title.text = ""
	detail_date.text = ""
	detail_body.text = ""

	var log = GameState.event_log
	for i in range(log.size() - 1, -1, -1):
		var entry = log[i]
		var label = _format_entry_label(entry)
		event_list.add_item(label)
		var idx = event_list.get_item_count() - 1
		event_list.set_item_metadata(idx, i)

func _format_entry_label(entry: Dictionary) -> String:
	var date = entry.get("date", "????-??-??")
	var type_str = entry.get("type", "unknown")
	var data = entry.get("data", {})
	var title = ""
	match type_str:
		"strategic_event":
			title = data.get("title", "Strategic Event")
		"event_outcome":
			title = data.get("message", "Event Outcome")
		_:
			title = type_str.capitalize()
	return date + "  " + title

func _on_event_selected(index: int) -> void:
	if index < 0 or index >= event_list.get_item_count():
		return
	var log_idx = event_list.get_item_metadata(index)
	var entry = GameState.event_log[log_idx]
	_show_detail(entry)

func _show_detail(entry: Dictionary) -> void:
	var type_str = entry.get("type", "")
	var data = entry.get("data", {})
	var date = entry.get("date", "")

	detail_date.text = date
	match type_str:
		"strategic_event":
			detail_title.text = data.get("title", "Strategic Event")
			detail_body.text = data.get("description", "")
		"event_outcome":
			detail_title.text = tr("Outcome: ")
			var lines = []
			var msg = data.get("message", "")
			if msg:
				lines.append(msg)
			var funds = data.get("funds_delta", 0)
			if funds != 0:
				lines.append("Funds: " + ("+" if funds > 0 else "") + str(funds) + " C-Bills")
			var rep = data.get("reputation_delta", {})
			if not rep.is_empty():
				for k in rep:
					var v = rep[k]
					lines.append("Reputation [" + k + "]: " + ("+" if v > 0 else "") + str(v))
			var pe = data.get("personnel_effect", "")
			if pe:
				lines.append("Personnel effect: " + pe)
			detail_body.text = tr("\n")
		_:
			detail_title.text = type_str.capitalize()
			var lines = []
			for k in data:
				lines.append(k + ": " + str(data[k]))
			detail_body.text = tr("\n")

func _on_close() -> void:
	hide()
	closed.emit()
