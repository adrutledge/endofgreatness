extends Node2D

## Root campaign view. Owns all layers (strategic, planetary, tactical) and
## manages transitions between them via LayerManager.
## Also owns the HUD and overlay panels accessible from any layer.

const HUD_HEIGHT: float = 28.0

signal campaign_exited()

@onready var strategic_layer = $StrategicLayer
@onready var planetary_layer = $PlanetaryLayer
@onready var tactical_layer = $TacticalLayer
@onready var layer_mgr = $LayerManager
@onready var modal_layer = $ModalLayer

func _ready() -> void:
	layer_mgr.register_layer("strategic", strategic_layer)
	layer_mgr.register_layer("planetary", planetary_layer)
	layer_mgr.register_layer("tactical", tactical_layer)
	tactical_layer.hide()

	_setup_panels()
	_setup_hud()

	for child in $PanelOverlay.get_children():
		if child is Control:
			child.offset_top = HUD_HEIGHT
	planetary_layer.offset_top = HUD_HEIGHT
	tactical_layer.offset_top = HUD_HEIGHT

	strategic_layer.planetary_map_requested.connect(_on_strategic_planetary)
	planetary_layer.closed.connect(_on_planetary_closed)
	planetary_layer.tactical_requested.connect(_on_planetary_tactical)
	tactical_layer.closed.connect(_on_tactical_closed)
	$PanelOverlay/ContractBoard.view_map_requested.connect(_on_strategic_planetary)

	layer_mgr.push("strategic")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if PanelManager.close_top_panel():
			get_viewport().set_input_as_handled()
		else:
			var top = layer_mgr.current()
			if top != "strategic" and not top.is_empty():
				layer_mgr.pop()
				get_viewport().set_input_as_handled()


func _setup_panels() -> void:
	PanelManager.register_panel("personnel", $PanelOverlay/PersonnelManagement, func(): $PanelOverlay/PersonnelManagement.populate_roster())
	PanelManager.register_panel("event_log", $PanelOverlay/EventLog, func(): $PanelOverlay/EventLog.populate())
	PanelManager.register_panel("mech_lab", $PanelOverlay/MechLab, func(): $PanelOverlay/MechLab.populate())
	PanelManager.register_panel("logistics", $PanelOverlay/LogisticsPanel, func(): $PanelOverlay/LogisticsPanel.populate())
	PanelManager.register_panel("contract_board", $PanelOverlay/ContractBoard, func(): $PanelOverlay/ContractBoard.populate())
	PanelManager.register_panel("org_mgmt", $PanelOverlay/OrganizationManagement, func(): $PanelOverlay/OrganizationManagement.populate_tree())
	$PanelOverlay/OrganizationManagement.deploy_and_travel_requested.connect(_on_strategic_planetary)


func _setup_hud() -> void:
	pass


func _on_strategic_planetary(contract: Contract) -> void:
	planetary_layer.load_contract(contract)
	layer_mgr.push("planetary")


func _on_planetary_closed() -> void:
	layer_mgr.pop()


func _on_planetary_tactical(contract: Contract, hex_data: Dictionary) -> void:
	tactical_layer.load_engagement(contract, hex_data, _get_deployed_units())
	layer_mgr.push("tactical")


func _on_tactical_closed() -> void:
	layer_mgr.pop()


func _get_deployed_units() -> Array[OperationalUnit]:
	var result: Array[OperationalUnit] = []
	for ou in GameState.player.organizational_units:
		for su in ou.sub_units:
			if su.is_deployed:
				result.append(su)
	return result


func show_modal(content: Control, pauses_game: bool = false) -> void:
	modal_layer.queue_modal(content, pauses_game)


func dismiss_modal() -> void:
	modal_layer.dismiss()
