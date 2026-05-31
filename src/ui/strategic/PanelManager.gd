class_name PanelManager
extends Node

## Manages panel lifecycle (open/close/ESC stack) for the StarMap.
## Panels register with a name, node reference, and optional populate callable.
## The sidebar is hidden when any panel opens and restored when all panels close.

var _sidebar: Control
var _panel_stack: Array[String] = []
var _panels: Dictionary = {}

signal panel_opened(panel_name: String)
signal panel_closed(panel_name: String)


func set_sidebar(node: Control) -> void:
	_sidebar = node


func register_panel(name: String, node: Control, populate: Callable = Callable()) -> void:
	_panels[name] = {"node": node, "populate": populate}
	if node.has_signal("closed"):
		if not node.closed.is_connected(_on_panel_closed_signal):
			node.closed.connect(_on_panel_closed_signal.bind(name))


func open_panel(name: String) -> void:
	var panel = _panels.get(name)
	if not panel:
		push_warning("PanelManager: unknown panel '%s'" % name)
		return
	if panel.node.visible:
		return
	if _sidebar:
		_sidebar.hide_sidebar()
	if panel.populate.is_valid():
		panel.populate.call()
	panel.node.show()
	_panel_stack.append(name)
	panel_opened.emit(name)


func close_panel(name: String) -> void:
	var panel = _panels.get(name)
	if not panel:
		return
	if not panel.node.visible:
		return
	panel.node.hide()
	_panel_stack.erase(name)
	if _panel_stack.is_empty() and _sidebar:
		_sidebar.show_sidebar()
	panel_closed.emit(name)


## Closes the topmost panel in the stack. Returns true if a panel was closed.
func close_top_panel() -> bool:
	if _panel_stack.is_empty():
		return false
	var name = _panel_stack.pop_back()
	close_panel(name)
	return true


func is_open(name: String) -> bool:
	var panel = _panels.get(name)
	return panel and panel.node.visible


func has_open_panels() -> bool:
	for name in _panels:
		if _panels[name].node.visible:
			return true
	return false


func get_top_panel() -> String:
	return _panel_stack.back() if not _panel_stack.is_empty() else ""


func get_panel(name: String) -> Control:
	var panel = _panels.get(name)
	return panel.get("node") if panel else null


func _on_panel_closed_signal(name: String) -> void:
	close_panel(name)
