extends Node

## Manages notification dispatch: toasts (corner fade-in) and popups (modal + pause).
##
## Each event type has a configurable mode: "silent" (ignore), "queue" (toast),
## or "popup" (modal + pause). Defaults can be overridden by the player via
## notification_settings.json in user://.
##
## Toast UI lives on a dedicated CanvasLayer at layer 4 (above HUD at layer 3).

var _config: Dictionary = {
	"contract_arrived": "popup",
	"event_triggered": "popup",
	"tactical_engagement_started": "popup",
	"funds_depleted": "popup",
	"month_started": "queue",
	"delivery_arrived": "queue",
	"bills_paid": "queue",
	"tactical_engagement_resolved": "queue",
	"day_started": "silent",
	"save_completed": "silent",
	"load_completed": "silent",
	"personnel_joined": "silent",
	"personnel_left": "silent",
	"contract_completed": "queue",
	"contract_accepted": "queue",
}

var _toast_container: VBoxContainer


func _ready() -> void:
	_load_config()

	# Create toast canvas layer
	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 4
	add_child(toast_layer)

	var margin := MarginContainer.new()
	margin.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.margin_right = -16
	margin.margin_bottom = -16
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.add_child(margin)

	_toast_container = VBoxContainer.new()
	_toast_container.size_flags_horizontal = Control.SIZE_SHRINK_END
	_toast_container.size_flags_vertical = Control.SIZE_SHRINK_END
	_toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_toast_container)

	# Subscribe to EventBus signals
	if not EventBus:
		return

	EventBus.contract_arrived.connect(func(c): _notify("contract_arrived", TranslationServer.translate("Arrived at %s") % c.planet))
	EventBus.event_triggered.connect(func(d): _notify("event_triggered", d.get("type", "?")))
	EventBus.tactical_engagement_started.connect(func(c, _h): _notify("tactical_engagement_started", TranslationServer.translate("Tactical engagement on %s") % c.planet))
	EventBus.funds_depleted.connect(func(b): _notify("funds_depleted", TranslationServer.translate("FUNDS DEPLETED!")))
	EventBus.month_started.connect(func(_d): _notify("month_started", TranslationServer.translate("New month")))
	EventBus.delivery_arrived.connect(func(n, q): _notify("delivery_arrived", TranslationServer.translate("Delivery: %s x%d") % [n, q]))
	EventBus.bills_paid.connect(func(a, _b): _notify("bills_paid", TranslationServer.translate("Bills paid: %s") % Helpers.fmt_money(a)))
	EventBus.tactical_engagement_resolved.connect(func(_r): _notify("tactical_engagement_resolved", TranslationServer.translate("Engagement resolved")))
	EventBus.contract_accepted.connect(func(c): _notify("contract_accepted", TranslationServer.translate("Contract accepted: %s") % c.planet))
	EventBus.contract_completed.connect(func(c): _notify("contract_completed", TranslationServer.translate("Contract completed: %s") % c.planet))


func _notify(event_type: String, message: String) -> void:
	var mode = _config.get(event_type, "silent")
	match mode:
		"popup":
			_show_popup(event_type, message)
		"queue":
			_show_toast(message)
		_:
			pass


func _show_toast(msg: String) -> void:
	var label := RichTextLabel.new()
	label.text = msg
	label.bbcode_enabled = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(280, 0)
	label.modulate = Color(1, 1, 1, 0.9)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_container.add_child(label)
	await get_tree().create_timer(4.0).timeout
	label.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.5)
	await tween.finished
	label.queue_free()


func _show_popup(event_type: String, message: String) -> void:
	if TimeManager:
		TimeManager.pause()

	var dialog := AcceptDialog.new()
	dialog.title = event_type
	dialog.dialog_text = message
	dialog.min_size = Vector2i(400, 120)
	dialog.popup_centered()
	add_child(dialog)


func set_mode(event_type: String, mode: String) -> void:
	if _config.has(event_type):
		_config[event_type] = mode
		_save_config()


func get_config() -> Dictionary:
	return _config.duplicate()


func _save_config() -> void:
	var file = FileAccess.open("user://notification_settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.new().stringify(_config))


func _load_config() -> void:
	var file = FileAccess.open("user://notification_settings.json", FileAccess.READ)
	if file:
		var j = JSON.new()
		if j.parse(file.get_as_text()) == OK:
			for key in j.data:
				if _config.has(key):
					_config[key] = j.data[key]
