extends Node2D

## Root campaign view. Owns all layers (strategic, planetary, tactical) and
## manages transitions between them via LayerManager.
## Also owns the HUD and overlay panels accessible from any layer.

const HUD_HEIGHT: float = 28.0

signal campaign_exited()

const LAYER_HUD_SCENES = {
	"strategic": "res://src/ui/strategic/StrategicHUD.tscn",
	"planetary": "res://src/ui/operational/PlanetaryHUD.tscn",
}

@onready var strategic_layer = $StrategicLayer
@onready var planetary_layer = $PlanetaryLayer
@onready var tactical_layer = $TacticalLayer
@onready var layer_mgr = $LayerManager
@onready var modal_layer = $ModalLayer
@onready var layer_hud = $LayerHUD

var _current_hud: Node = null

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
	_show_layer_hud("strategic", strategic_layer)
	get_viewport().size_changed.connect(_on_viewport_resized)


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


func _show_layer_hud(layer: String, map_node: Node) -> void:
	_hide_layer_hud()
	var path = LAYER_HUD_SCENES.get(layer)
	if not path:
		return
	var scene = ResourceLoader.load(path)
	if not scene:
		return
	var hud = scene.instantiate()
	if hud.has_method("set_map_layer"):
		hud.set_map_layer(map_node)
	layer_hud.add_child(hud)
	_position_hud(hud)
	_current_hud = hud


func _position_hud(hud: Control) -> void:
	var vp = get_viewport().get_visible_rect().size
	hud.position = Vector2(vp.x - 260, 28)
	hud.size = Vector2(260, vp.y - 28)


func _hide_layer_hud() -> void:
	if _current_hud:
		_current_hud.queue_free()
		_current_hud = null


func _on_viewport_resized() -> void:
	if _current_hud:
		_position_hud(_current_hud)


var _last_arrived_contract: int = 0


func _on_strategic_planetary(contract: Contract) -> void:
	if contract.get_instance_id() == _last_arrived_contract:
		return
	_last_arrived_contract = contract.get_instance_id()
	planetary_layer.load_contract(contract)
	layer_mgr.push("planetary")
	_show_layer_hud("planetary", planetary_layer)
	if EventBus:
		EventBus.emit_contract_arrived(contract)


func _on_planetary_closed() -> void:
	_last_arrived_contract = 0
	layer_mgr.pop()
	_show_layer_hud("strategic", strategic_layer)


func _on_planetary_tactical(contract: Contract, hex_data: Dictionary) -> void:
	tactical_layer.load_engagement(contract, hex_data, _get_deployed_units())
	layer_mgr.push("tactical")
	if EventBus:
		EventBus.emit_tactical_engagement_started(contract, hex_data)


func _on_tactical_closed() -> void:
	var result = tactical_layer._get_result_copy() if tactical_layer.has_method("_get_result_copy") else tactical_layer._result
	_hide_layer_hud()
	layer_mgr.pop()
	_show_layer_hud("strategic", strategic_layer)

	# Remove destroyed player units from their parent OperationalUnit
	if result and result.has("destroyed_player_units"):
		var destroyed: Array = result.destroyed_player_units
		if not destroyed.is_empty():
			for ou in GameState.player.organizational_units:
				for su in ou.sub_units:
					su.tactical_units = su.tactical_units.filter(func(tu): return tu.unit_name not in destroyed)
					for sub in su.sub_units:
						sub.tactical_units = sub.tactical_units.filter(func(tu): return tu.unit_name not in destroyed)

	if EventBus and result:
		EventBus.emit_tactical_engagement_resolved(result)


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
