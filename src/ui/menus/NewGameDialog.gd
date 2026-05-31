extends Control

@onready var faction_list = $VBoxContainer/FactionList
@onready var start_button = $VBoxContainer/StartButton
@onready var back_button = $VBoxContainer/BackButton
@onready var status_label = $VBoxContainer/StatusLabel
@onready var company_name_edit = $VBoxContainer/CompanyName

var _Generator = null


func _ready() -> void:
	_Generator = load("res://src/strategic/StrategicUnitGenerator.gd")
	setup_faction_list()
	start_button.pressed.connect(_on_start)
	back_button.pressed.connect(_on_back)


func setup_faction_list() -> void:
	var faction_keys := [
		"fed_suns", "lyran", "fwl", "drac_combine", "capellan",
		"magistracy", "taurian", "outworlds", "marian",
		"is_general", "merc", "periphery",
	]
	var faction_labels := {
		"fed_suns": "Federated Suns",
		"lyran": "Lyran Commonwealth",
		"fwl": "Free Worlds League",
		"drac_combine": "Draconis Combine",
		"capellan": "Capellan Confederation",
		"magistracy": "Magistracy of Canopus",
		"taurian": "Taurian Concordat",
		"outworlds": "Outworlds Alliance",
		"marian": "Marian Hegemony",
		"is_general": "Inner Sphere General",
		"merc": "Mercenary",
		"periphery": "Periphery",
	}

	var selected := 0
	for i in range(faction_keys.size()):
		var key = faction_keys[i]
		var label = faction_labels.get(key, key)
		faction_list.add_item(label)
		if key == "merc":
			selected = i

	faction_list.select(selected)


func _on_start() -> void:
	var selected = faction_list.get_selected_items()
	if selected.is_empty():
		return

	var faction_key := ""
	var faction_keys := [
		"fed_suns", "lyran", "fwl", "drac_combine", "capellan",
		"magistracy", "taurian", "outworlds", "marian",
		"is_general", "merc", "periphery",
	]
	faction_key = faction_keys[selected[0]]

	var company_name = company_name_edit.text.strip_edges()
	if company_name.is_empty():
		company_name = ""

	status_label.text = tr("Generating force...")
	start_button.disabled = true
	back_button.disabled = true

	var gen = _Generator.new()
	var result = gen.generate(faction_key, company_name)
	gen = null

	if result.get("success", false):
		get_tree().change_scene_to_file("res://src/ui/campaign/CampaignView.tscn")
	else:
		status_label.text = tr("Error: ") + result.get("error", "Unknown error")
		start_button.disabled = false
		back_button.disabled = false


func _on_back() -> void:
	get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
