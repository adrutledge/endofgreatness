extends Panel

signal dismissed()
signal load_requested(path: String)

@onready var load_button = %LoadButton
@onready var delete_button = %DeleteButton
@onready var cancel_button = %CancelButton
@onready var saves_list = %SavesList
@onready var status_label = %StatusLabel
@onready var info_label = %InfoLabel


func _ready() -> void:
	load_button.pressed.connect(_on_load)
	delete_button.pressed.connect(_on_delete)
	cancel_button.pressed.connect(_on_cancel)
	saves_list.item_selected.connect(_on_selection_changed)
	_populate_list()

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.3, 0.3, 0.4)
	add_theme_stylebox_override("panel", bg)

	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))

	load_button.disabled = true
	delete_button.disabled = true


func _populate_list() -> void:
	saves_list.clear()
	var saves := SaveManager.list_saves()
	for s in saves:
		var label = s.get("label", "?")
		var date = s.get("date_saved", "?")
		var planet = s.get("planet", "?")
		var funds = s.get("funds", 0)
		var units = s.get("unit_count", 0)
		var person = s.get("personnel_count", 0)
		var contract = s.get("current_contract", "")
		var is_auto = s.get("is_autosave", false)
		var prefix = tr("[A] ") if is_auto else ""
		var text = prefix + label + "  |  " + date + "  |  " + planet
		text += "  |  " + Helpers.fmt_money(funds)
		if not contract.is_empty():
			text += "  |  " + contract

		var idx = saves_list.add_item(text)
		saves_list.set_item_metadata(idx, s)


func _on_selection_changed(idx: int) -> void:
	var meta = saves_list.get_item_metadata(idx)
	load_button.disabled = false
	delete_button.disabled = false
	var label = meta.get("label", "?")
	var date = meta.get("date_saved", "?")
	var planet = meta.get("planet", "?")
	var funds = meta.get("funds", 0)
	var units = meta.get("unit_count", 0)
	var person = meta.get("personnel_count", 0)
	var contract = meta.get("current_contract", "")
	var info = tr("Planet: %s  |  Funds: %s  |  Units: %d  |  Personnel: %d") % [planet, Helpers.fmt_money(funds), units, person]
	if not contract.is_empty():
		info += "\n" + tr("Contract: %s") % contract
	info_label.text = info


func _on_load() -> void:
	var selected: Array[int] = saves_list.get_selected_items()
	if selected.is_empty():
		return
	var meta = saves_list.get_item_metadata(selected[0])
	var filename = meta.get("filename", "")
	if filename.is_empty():
		return

	var path = SaveManager.get_save_path(filename)
	status_label.text = tr("Loading...")
	load_button.disabled = true
	delete_button.disabled = true

	if get_tree().current_scene and get_tree().current_scene is Node2D:
		var err := get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
		if err != OK:
			status_label.text = tr("Error switching scene")
			return
		await get_tree().process_frame
		await get_tree().process_frame

	_load_and_enter(path)


func _load_and_enter(path: String) -> void:
	var result := SaveManager.load_game(path)
	if not result.get("success", false):
		status_label.text = tr("Load failed: ") + result.get("reason", "Unknown error")
		load_button.disabled = false
		return

	var err := get_tree().change_scene_to_file("res://src/ui/campaign/CampaignView.tscn")
	if err != OK:
		printerr("LoadDialog: Failed to load CampaignView: ", err)
		return

	dismissed.emit()


func _on_delete() -> void:
	var selected: Array[int] = saves_list.get_selected_items()
	if selected.is_empty():
		return
	var meta = saves_list.get_item_metadata(selected[0])
	var filename = meta.get("filename", "")
	if filename.is_empty():
		return
	if SaveManager.delete_save(filename):
		status_label.text = tr("Save deleted")
		_populate_list()
		load_button.disabled = true
		delete_button.disabled = true
		info_label.text = ""
	else:
		status_label.text = tr("Could not delete save")


func _on_cancel() -> void:
	dismissed.emit()
