extends Node2D

## Root campaign view. Owns all layers (strategic, planetary, tactical) and
## manages transitions between them via LayerManager.
## Also owns the HUD and overlay panels accessible from any layer.

signal campaign_exited()

@onready var strategic_layer = $StrategicLayer
@onready var planetary_layer = $PlanetaryLayer
@onready var tactical_layer = $TacticalLayer
@onready var layer_mgr = $LayerManager

func _ready() -> void:
	layer_mgr.register_layer("strategic", strategic_layer)
	layer_mgr.register_layer("planetary", planetary_layer)
	layer_mgr.register_layer("tactical", tactical_layer)
	tactical_layer.hide()

	_setup_panels()
	_setup_hud()

	strategic_layer.planetary_map_requested.connect(_on_strategic_planetary)
	planetary_layer.closed.connect(_on_planetary_closed)
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
	var overlay = $PanelOverlay
	PanelManager.register_panel("personnel", overlay.PersonnelManagement, func(): overlay.PersonnelManagement.populate_roster())
	PanelManager.register_panel("event_log", overlay.EventLog, func(): overlay.EventLog.populate())
	PanelManager.register_panel("mech_lab", overlay.MechLab, func(): overlay.MechLab.populate())
	PanelManager.register_panel("logistics", overlay.LogisticsPanel, func(): overlay.LogisticsPanel.populate())
	PanelManager.register_panel("contract_board", overlay.ContractBoard, func(): overlay.ContractBoard.populate())
	PanelManager.register_panel("org_mgmt", overlay.OrganizationManagement, func(): overlay.OrganizationManagement.populate_tree())


func _setup_hud() -> void:
	pass


func _on_strategic_planetary(contract: Contract) -> void:
	planetary_layer.load_contract(contract)
	layer_mgr.push("planetary")


func _on_planetary_closed() -> void:
	layer_mgr.pop()
