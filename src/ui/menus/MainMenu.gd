extends Control

func _ready() -> void:
	if "--test-generator" in OS.get_cmdline_user_args():
		_test_generator()
		return
	$VBoxContainer/NewGame.pressed.connect(_on_new_game)
	$VBoxContainer/LoadGame.pressed.connect(_on_load_game)
	$VBoxContainer/Settings.pressed.connect(_on_settings)
	$VBoxContainer/Credits.pressed.connect(_on_credits)
	$VBoxContainer/Quit.pressed.connect(_on_quit)

func _test_generator() -> void:
	print("=== Generator Test ===")
	var gen = load("res://src/strategic/StrategicUnitGenerator.gd").new()
	if not gen:
		print("FAILED: could not load generator")
		get_tree().quit(1)
		return
	print("Testing drac_combine...")
	var result = gen.generate("drac_combine", "Test Unit")
	print("Success: ", result.get("success", false))
	print("Mechs: ", result.get("mech_count", 0))
	print("Personnel generated: ", result.get("personnel_count", 0))
	print("PersonnelManager roster: ", PersonnelManager.personnel_roster.size())
	for p in PersonnelManager.personnel_roster:
		print("  ", p.personnel_name, " role=", Enums.PersonnelRole.keys()[p.role], " founder=", p.is_founder)
	if PersonnelManager.personnel_roster.is_empty():
		print("FAILED: roster is empty!")
	else:
		print("PASSED: personnel found in roster")
	if not GameState.player or GameState.player.organizational_units.is_empty():
		print("FAILED: no organizational units!")
	else:
		var count := 0
		for ou in GameState.player.organizational_units:
			for opu in ou.sub_units:
				count += opu.tactical_units.size()
		print("PASSED: " + str(count) + " tactical units in " + str(GameState.player.organizational_units.size()) + " org unit(s)")
	print("=== End ===")
	get_tree().quit(0)


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
