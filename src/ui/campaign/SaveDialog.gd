extends Panel

signal dismissed()

@onready var name_edit = %NameEdit
@onready var save_button = %SaveButton
@onready var cancel_button = %CancelButton
@onready var saves_list = %SavesList
@onready var status_label = %StatusLabel
@onready var overwrite_label = %OverwriteLabel


func _ready() -> void:
	save_button.pressed.connect(_on_save)
	cancel_button.pressed.connect(_on_cancel)
	name_edit.text_changed.connect(_on_name_changed)
	_populate_list()

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.3, 0.3, 0.4)
	add_theme_stylebox_override("panel", bg)

	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))


func _populate_list() -> void:
	saves_list.clear()
	var saves := SaveManager.list_saves()
	for s in saves:
		var label = s.get("label", "?")
		var date = s.get("date_saved", "?")
		var planet = s.get("planet", "?")
		var funds = s.get("funds", 0)
		var units = s.get("unit_count", 0)
		var personnel = s.get("personnel_count", 0)
		var contract = s.get("current_contract", "")
		var is_auto = s.get("is_autosave", false)
		var prefix = tr("[A] ") if is_auto else ""
		var text = prefix + label + "  |  " + date + "  |  " + planet
		text += "  |  " + Helpers.fmt_money(funds)
		if not contract.is_empty():
			text += "  |  " + contract
		saves_list.add_item(text)


func _on_name_changed(_new_text: String) -> void:
	var name: String = name_edit.text.strip_edges()
	save_button.disabled = name.is_empty()
	_check_overwrite(name)


func _check_overwrite(name: String) -> void:
	if name.is_empty():
		overwrite_label.hide()
		return
	var cleaned: String = SaveManager._sanitize_name(name)
	var date_str: String = TimeManager.get_date_string() if TimeManager else ""
	var target: String = cleaned + "_" + date_str
	var saves := SaveManager.list_saves()
	for s in saves:
		var label = s.get("label", "")
		if label == cleaned or label.begins_with(cleaned + "_"):
			var fname = s.get("filename", "")
			if fname.contains(target):
				overwrite_label.text = tr("Will overwrite existing save")
				overwrite_label.show()
				return
	overwrite_label.hide()


func _on_save() -> void:
	var name: String = name_edit.text.strip_edges()
	if name.is_empty():
		return
	var result := SaveManager.manual_save(name)
	if result.get("success", false):
		status_label.text = tr("Game saved!")
		save_button.disabled = true
		_populate_list()
		await get_tree().create_timer(0.8).timeout
		dismissed.emit()
	else:
		status_label.text = tr("Save failed: ") + tr(result.get("reason", "Unknown error"))


func _on_cancel() -> void:
	dismissed.emit()
