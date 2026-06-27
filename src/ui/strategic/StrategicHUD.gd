extends Panel

## Right-side HUD for the strategic star map layer.
## Shows faction list + reputation by default, system details on star click.
## Buttons open PanelManager overlays.

var _map: Node = null

@onready var faction_list: ItemList = %FactionList
@onready var system_info: RichTextLabel = %SystemInfo
@onready var title: Label = %Title


func _ready() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	add_theme_stylebox_override("panel", bg)

	%ContractBoardButton.pressed.connect(func(): PanelManager.open_panel("contract_board"))
	%OrgMgmtButton.pressed.connect(func(): PanelManager.open_panel("org_mgmt"))
	%PersonnelButton.pressed.connect(func(): PanelManager.open_panel("personnel"))
	%MechLabButton.pressed.connect(func(): PanelManager.open_panel("mech_lab"))
	%LogisticsButton.pressed.connect(func(): PanelManager.open_panel("logistics"))
	%EventLogButton.pressed.connect(func(): PanelManager.open_panel("event_log"))

	_populate_factions()


func set_map_layer(map_node: Node) -> void:
	_map = map_node
	if _map and _map.has_signal("system_selected"):
		_map.system_selected.connect(_on_system_selected)


func _populate_factions() -> void:
	if not GameState or not GameState.factions:
		return
	faction_list.clear()
	for code in GameState.factions:
		var f = GameState.factions[code]
		var rep = 0
		if ReputationSystem:
			rep = ReputationSystem.get_faction_reputation(code)
		var rep_str = ""
		if rep >= 50: rep_str = "[color=#44ff44]Ally[/color]"
		elif rep >= 10: rep_str = "[color=#88ff88]Friendly[/color]"
		elif rep >= -10: rep_str = "[color=#ffffff]Neutral[/color]"
		elif rep >= -50: rep_str = "[color=#ffaa44]Unfriendly[/color]"
		else: rep_str = "[color=#ff4444]Hostile[/color]"
		var label = "%s — %s (%d)" % [f.faction_name, rep_str, rep]
		faction_list.add_item(label)


func _on_system_selected(system_data: Dictionary) -> void:
	system_info.text = ""
	faction_list.hide()
	var data = system_data.get("data", system_data)
	var name = data.get("name", system_data.get("name", "Unknown"))
	var owner = data.get("owner_faction", "")
	var owner_name = ""
	if owner and GameState.factions.has(owner):
		owner_name = GameState.factions[owner].faction_name
	var pop = data.get("population", 0)
	var tech = data.get("tech_level", "?")
	var industry = data.get("industrial_level", "?")

	var text = "[b]%s[/b]\n" % name
	if not owner_name.is_empty():
		text += "Owner: %s\n" % owner_name
	if pop > 0:
		text += "Population: %s\n" % Helpers.fmt_number(pop)
	text += "Tech: %s  Industry: %s\n" % [tech, industry]
	system_info.text = text
	system_info.show()
	title.text = "System Info"


func _clear_system() -> void:
	faction_list.show()
	system_info.text = ""
	system_info.hide()
	title.text = "Inner Sphere"
