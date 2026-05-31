class_name LayerManager
extends Node

## Manages full-screen layer transitions (strategic ↔ planetary ↔ tactical).
## Layers are registered as named nodes; push/pop maintains a stack so the
## player can walk down (strategic → planetary → tactical) and back up.

var _layer_stack: Array[String] = []
var _layers: Dictionary = {}

signal layer_changed(from_layer: String, to_layer: String)


func register_layer(name: String, node: Control) -> void:
	_layers[name] = node
	node.hide()


func push(name: String) -> void:
	var node = _layers.get(name)
	if not node:
		push_warning("LayerManager: unknown layer '%s'" % name)
		return
	if _layer_stack.size() > 0:
		var current = _layers[_layer_stack.back()]
		if current:
			current.hide()
	_layer_stack.append(name)
	node.show()
	Helpers.debug_print("LayerManager", "push '%s' — stack: %s" % [name, str(_layer_stack)])
	layer_changed.emit(_layer_stack[_layer_stack.size() - 2] if _layer_stack.size() >= 2 else "", name)


func pop() -> bool:
	if _layer_stack.size() <= 1:
		return false
	var current_name = _layer_stack.pop_back()
	var current = _layers.get(current_name)
	if current:
		current.hide()
	var prev_name = _layer_stack.back()
	var prev = _layers.get(prev_name)
	if prev:
		prev.show()
	Helpers.debug_print("LayerManager", "pop '%s' — stack: %s" % [current_name, str(_layer_stack)])
	layer_changed.emit(current_name, prev_name)
	return true


func current() -> String:
	return _layer_stack.back() if _layer_stack.size() > 0 else ""


func is_on_top(name: String) -> bool:
	return name == current()
