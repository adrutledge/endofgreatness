extends Control

@onready var saves_list = %SavesList
@onready var load_button = %LoadButton
@onready var delete_button = %DeleteButton
@onready var back_button = %BackButton
@onready var status_label = %StatusLabel
@onready var info_label = %InfoLabel


func _ready() -> void:
	load_button.pressed.connect(_on_load)
	delete_button.pressed.connect(_on_delete)
	back_button.pressed.connect(_on_back)
	saves_list.item_selected.connect(_on_selection_changed)
	_populate_list()
	load_button.disabled = true
	delete_button.disabled = true


func _populate_list() -> void:
	saves_list.clear()
	var saves := SaveManager.list_saves()
	if saves.is_empty():
		saves_list.add_item(tr("No saves found."))
		return

	for s in saves:
		var label = s.get("label", "?")
		var date = s.get("date_saved", "?")
		var planet = s.get("planet", "?")
		var funds = s.get("funds", 0)
		var units = s.get("unit_count", 0)
		var person = s.get("personnel_count", 0)
		var contract = s.get("current_contract", "")
		var is_auto = s.get("is_autosave", false)
		var prefix = tr("[Autosave] ") if is_auto else ""
		var text = prefix + label
		text += "  |  " + date + "  |  " + planet
		text += "  |  " + Helpers.fmt_money(funds)
		if not contract.is_empty():
			text += "  |  " + contract

		var idx: int = saves_list.add_item(text)
		saves_list.set_item_metadata(idx, s)


func _on_selection_changed(idx: int) -> void:
	var meta = saves_list.get_item_metadata(idx)
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
	load_button.disabled = false
	delete_button.disabled = false


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

	var result := SaveManager.load_game(path)
	if not result.get("success", false):
		status_label.text = tr("Load failed: ") + tr(result.get("reason", "Unknown error"))
		load_button.disabled = false
		return

	var err := get_tree().change_scene_to_file("res://src/ui/campaign/CampaignView.tscn")
	if err != OK:
		printerr("SaveLoadMenu: Failed to load CampaignView: ", err)
		return


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


func _on_back() -> void:
	get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
