extends Node2D

var systems_positions: Array[Dictionary] = []
var jump_routes: Array[Dictionary] = []
var selected_system: Dictionary = {}

var dragging: bool = false

const JUMP_DISTANCE: float = 30.0
const SYSTEM_BASE_RADIUS: float = 5.0

@onready var camera: Camera2D = $Camera2D
@onready var info_panel = $CanvasLayer/StrategicActions/MarginContainer/VBox/SystemInfoPanel
@onready var org_mgmt = $CanvasLayer/OrganizationManagement
@onready var contract_board = $CanvasLayer/ContractBoard
@onready var sidebar: StrategicActions = $CanvasLayer/StrategicActions

func _ready() -> void:
	sidebar.organization_tree_requested.connect(_on_organization_tree)
	sidebar.contract_board_requested.connect(_on_contract_board)
	org_mgmt.closed.connect(_on_org_mgmt_closed)
	contract_board.closed.connect(_on_contract_board_closed)
	_load_systems()
	_calculate_jump_routes()
	queue_redraw()

func _on_contract_board() -> void:
	sidebar.hide()
	contract_board.populate()
	contract_board.show()

func _on_contract_board_closed() -> void:
	contract_board.hide()
	sidebar.show()

func _on_organization_tree() -> void:
	sidebar.hide()
	org_mgmt.populate_tree()
	org_mgmt.show()

func _on_org_mgmt_closed() -> void:
	org_mgmt.hide()
	sidebar.show()

func _load_systems() -> void:
	var data = DataManager.systems_data
	if data.is_empty():
		return
	for name in data:
		var sys = data[name]
		var coords = sys.get("coordinates", {})
		var pos = Vector2(coords.get("x", 0.0), coords.get("y", 0.0))
		systems_positions.append({
			"name": name,
			"pos": pos,
			"data": sys
		})

func _calculate_jump_routes() -> void:
	for i in range(systems_positions.size()):
		for j in range(i + 1, systems_positions.size()):
			var a = systems_positions[i]
			var b = systems_positions[j]
			if a["pos"].distance_to(b["pos"]) <= JUMP_DISTANCE:
				jump_routes.append({"from": a["pos"], "to": b["pos"]})

func _draw() -> void:
	draw_rect(Rect2(-5000, -5000, 10000, 10000), Color(0.06, 0.06, 0.1, 1.0))

	for route in jump_routes:
		draw_line(route["from"], route["to"], Color(0.35, 0.35, 0.55, 0.4), 1.0, true)

	for sys in systems_positions:
		var pos = sys["pos"]
		var data = sys["data"]
		var owner = data.get("owner_faction", "")
		var color = _get_faction_color(owner)
		var radius = _get_spectral_radius(data.get("spectral_class", ""))

		draw_circle(pos, radius, color)
		draw_circle(pos, radius + 1, Color(1, 1, 1, 0.25), false, 1.0)

		var font = ThemeDB.fallback_font
		var font_size = ThemeDB.fallback_font_size
		var text_pos = pos + Vector2(radius + 3, -radius)
		draw_string(font, text_pos, sys["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.85))

	if not selected_system.is_empty():
		var sel_pos = selected_system.get("pos", Vector2.ZERO)
		var sel_radius = _get_spectral_radius(selected_system.get("data", {}).get("spectral_class", ""))
		draw_circle(sel_pos, sel_radius + 4, Color(1, 1, 0, 0.6), false, 2.0)

func _get_faction_color(owner: String) -> Color:
	if owner.is_empty():
		return Color(0.55, 0.55, 0.55)
	var faction: Faction = GameState.factions.get(owner)
	if faction:
		return faction.color
	return Color(0.55, 0.55, 0.55)

func _get_spectral_radius(spectral: String) -> float:
	match spectral.to_upper():
		"O": return 9.0
		"B": return 8.0
		"A": return 7.0
		"F": return 6.0
		"G": return 5.5
		"K": return 5.0
		"M": return 4.5
	return SYSTEM_BASE_RADIUS

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var btn = event.button_index

		if btn == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var world_pos = _screen_to_world(event.position)
				_check_system_click(world_pos)
				dragging = true
			else:
				dragging = false

		elif btn == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom = clamp(camera.zoom * 1.15, 0.1, 10.0)
			queue_redraw()

		elif btn == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom = clamp(camera.zoom / 1.15, 0.1, 10.0)
			queue_redraw()

	if event is InputEventMouseMotion and dragging:
		camera.position -= event.relative / camera.zoom

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var viewport_size = get_viewport_rect().size
	return camera.global_position + (screen_pos - viewport_size * 0.5) / camera.zoom

func _check_system_click(world_pos: Vector2) -> void:
	var closest = null
	var closest_dist = SYSTEM_BASE_RADIUS + 6.0

	for sys in systems_positions:
		var dist = sys["pos"].distance_to(world_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest = sys

	if closest:
		selected_system = closest
		info_panel.show_system(closest["data"])
	else:
		selected_system = {}
		info_panel.hide_panel()

	queue_redraw()
