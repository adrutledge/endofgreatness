extends Panel

const HexMap = preload("res://src/data/HexMap.gd")

## Right-side HUD for the planetary map layer.
## Shows contract info, hex selection details, and action buttons.
## Owns no hex grid — communicates with PlanetaryMap via direct calls.

var _map: Node = null

@onready var title_label: Label = %Title
@onready var contract_label: Label = %ContractLabel
@onready var hex_info_label: Label = %HexInfoLabel
@onready var explore_button: Button = %ExploreButton
@onready var engage_button: Button = %EngageButton
@onready var unit_selector: OptionButton = %UnitSelector
@onready var move_button: Button = %MoveButton
@onready var abandon_button: Button = %AbandonButton


func _ready() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	add_theme_stylebox_override("panel", bg)

	explore_button.pressed.connect(_on_explore)
	engage_button.pressed.connect(_on_engage)
	move_button.pressed.connect(_on_move)
	abandon_button.pressed.connect(_on_abandon)


func set_map_layer(map_node: Node) -> void:
	_map = map_node
	if _map.has_signal("hex_selected"):
		_map.hex_selected.connect(_on_hex_selected)
	if _map.has_signal("reachable_updated"):
		_map.reachable_updated.connect(_on_reachable_updated)
	if _map.has_signal("engagement_triggered"):
		_map.engagement_triggered.connect(_on_engagement_triggered)

	# Show contract info from the planetary map
	if _map.has_method("get_contract"):
		var c = _map.get_contract()
		if c:
			contract_label.text = "%s — %s" % [c.activity_type, c.planet]
	title_label.text = "Planetary Map"

	_refresh_unit_selector()


func _refresh_unit_selector() -> void:
	if not _map or not _map.has_method("get_deployed_units_list"):
		return
	unit_selector.clear()
	var units = _map.get_deployed_units_list()
	for i in range(units.size()):
		unit_selector.add_item(units[i].name)
		unit_selector.set_item_metadata(i, i)
	if unit_selector.item_count > 0:
		unit_selector.select(0)
		_on_unit_selected(0)
	unit_selector.item_selected.connect(_on_unit_selected)


func _on_unit_selected(idx: int) -> void:
	if _map and _map.has_method("set_selected_unit_index"):
		_map.set_selected_unit_index(idx)


func _on_hex_selected(hex_dict: Dictionary) -> void:
	var q = hex_dict.get("q", 0)
	var r = hex_dict.get("r", 0)
	hex_info_label.text = "Hex (%d, %d)" % [q, r]
	explore_button.disabled = hex_dict.get("revealed", false)
	var obj = hex_dict.get("objective", HexMap.ObjectiveType.NONE)
	if obj == HexMap.ObjectiveType.ENEMY or obj == HexMap.ObjectiveType.PRIMARY:
		engage_button.show()
	else:
		engage_button.hide()
	# Enable move if path is available
	move_button.disabled = not (_map and _map.has_method("has_path_preview") and _map.has_path_preview())


func _on_reachable_updated(reachable: Dictionary) -> void:
	# Called when movement mode changes — update unit selector
	pass


func _on_engagement_triggered(contract, hex_data) -> void:
	pass


func _on_explore() -> void:
	if _map and _map.has_method("explore_selected_hex"):
		_map.explore_selected_hex()
		explore_button.disabled = true


func _on_engage() -> void:
	if _map and _map.has_method("engage_selected_hex"):
		_map.engage_selected_hex()


func _on_move() -> void:
	if _map and _map.has_method("execute_move"):
		_map.execute_move()


func _on_abandon() -> void:
	if _map and _map.has_method("abandon_contract"):
		_map.abandon_contract()
