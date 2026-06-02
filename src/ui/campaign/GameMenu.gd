extends Panel

signal dismissed()


func _ready() -> void:
	%SaveButton.pressed.connect(_on_save)
	%LoadButton.pressed.connect(_on_load)
	%QuitButton.pressed.connect(_on_quit)
	%CancelButton.pressed.connect(_on_cancel)

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.3, 0.3, 0.4)
	add_theme_stylebox_override("panel", bg)

	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))


func _on_save() -> void:
	Helpers.debug_print("GameMenu", "Save not yet implemented")
	dismissed.emit()


func _on_load() -> void:
	Helpers.debug_print("GameMenu", "Load not yet implemented")
	dismissed.emit()


func _on_quit() -> void:
	_quit_to_main_menu()


func _on_cancel() -> void:
	dismissed.emit()


func _quit_to_main_menu() -> void:
	var err = get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
	if err != OK:
		printerr("GameMenu: change_scene_to_file failed with error %d" % err)
