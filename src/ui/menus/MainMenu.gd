extends Control

func _ready() -> void:
	$VBoxContainer/NewGame.pressed.connect(_on_new_game)
	$VBoxContainer/LoadGame.pressed.connect(_on_load_game)
	$VBoxContainer/Settings.pressed.connect(_on_settings)
	$VBoxContainer/Credits.pressed.connect(_on_credits)
	$VBoxContainer/Quit.pressed.connect(_on_quit)

func _on_new_game() -> void:
	get_tree().change_scene_to_file("res://src/ui/menus/NewGameDialog.tscn")

func _on_load_game() -> void:
	get_tree().change_scene_to_file("res://src/ui/menus/SaveLoadMenu.tscn")

func _on_settings() -> void:
	pass

func _on_credits() -> void:
	pass

func _on_quit() -> void:
	get_tree().quit()
