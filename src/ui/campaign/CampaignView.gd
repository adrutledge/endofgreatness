extends Node2D

## Root campaign view. Owns all layers (strategic, planetary, tactical) and
## manages transitions between them via LayerManager.

signal campaign_exited()

@onready var strategic_layer = $StrategicLayer
@onready var planetary_layer = $PlanetaryLayer
@onready var tactical_layer = $TacticalLayer
@onready var layer_mgr: LayerManager = $LayerManager

func _ready() -> void:
	layer_mgr.register_layer("strategic", strategic_layer)
	layer_mgr.register_layer("planetary", planetary_layer)
	layer_mgr.register_layer("tactical", tactical_layer)

	tactical_layer.hide()

	strategic_layer.planetary_map_requested.connect(_on_strategic_planetary)
	planetary_layer.closed.connect(_on_planetary_closed)

	layer_mgr.push("strategic")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		var top = layer_mgr.current()
		if top != "strategic" and not top.is_empty():
			layer_mgr.pop()
			get_viewport().set_input_as_handled()


func _on_strategic_planetary(contract: Contract) -> void:
	planetary_layer.load_contract(contract)
	layer_mgr.push("planetary")


func _on_planetary_closed() -> void:
	layer_mgr.pop()
