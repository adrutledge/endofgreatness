extends Node2D

signal planetary_map_requested(contract: Contract)

var systems_positions: Array[Dictionary] = []
var jump_routes: Array[Dictionary] = []
var selected_system: Dictionary = {}
var path_start: Dictionary = {}
var jump_path: Array = []
var _hex_territory: Array[Dictionary] = []
var _placed_labels: Array[Rect2] = []
var _adjacency: Dictionary = {}
var _waypoints: Array[Dictionary] = []

var dragging: bool = false

const JUMP_DISTANCE: float = 30.0
const SYSTEM_BASE_RADIUS: float = 3.0
const NAME_ZOOM_THRESHOLD: float = 2.5
const HEX_DIAMETER: float = 20.0
const HEX_RADIUS: float = 10.0
const HEX_SIDE: float = 10.0
const HEX_HEIGHT: float = HEX_SIDE * sqrt(3.0)
const HEX_WIDTH: float = HEX_DIAMETER

const TERRITORY_CACHE_PATH = "user://cache/starmap_territory.json"

@onready var camera: Camera2D = $Camera2D
@onready var info_panel = $CanvasLayer/StrategicActions/MarginContainer/VBox/SystemInfoPanel
@onready var sidebar = $CanvasLayer/StrategicActions


func _ready() -> void:
	Helpers.debug_print("StarMap", "_ready start")

	sidebar.organization_tree_requested.connect(func(): PanelManager.open_panel("org_mgmt"))
	sidebar.contract_board_requested.connect(func(): PanelManager.open_panel("contract_board"))
	sidebar.personnel_management_requested.connect(func(): PanelManager.open_panel("personnel"))
	sidebar.mech_lab_requested.connect(func(): PanelManager.open_panel("mech_lab"))
	sidebar.logistics_requested.connect(func(): PanelManager.open_panel("logistics"))
	sidebar.event_log_requested.connect(func(): PanelManager.open_panel("event_log"))
	$CanvasLayer/StrategicActions/%ContractBoardButton.pressed.connect(func(): PanelManager.open_panel("contract_board"))
	$CanvasLayer/StrategicActions/%OrganizationTreeButton.pressed.connect(func(): PanelManager.open_panel("org_mgmt"))
	_load_systems()
	_load_territory_cache()
	_calculate_jump_routes()
	camera.zoom = Vector2(4.0, 4.0)
	var home = GameState.player.current_planet if GameState.player and not GameState.player.current_planet.is_empty() else "Galatea"
	var home_data = DataManager.systems_data.get(home, {})
	var home_coords = home_data.get("coordinates", {})
	var cx = home_coords.get("x", 0.0)
	var cy = home_coords.get("y", 0.0)
	camera.position = Vector2(cx, -cy)
	queue_redraw()
	Helpers.debug_print("StarMap", "_ready done, systems=%d routes=%d" % [systems_positions.size(), jump_routes.size()])


func _on_planetary_map_requested(contract: Contract) -> void:
	planetary_map_requested.emit(contract)


func _load_systems() -> void:
	var data = DataManager.systems_data
	Helpers.debug_print("StarMap", "_load_systems data.size=%d is_empty=%s" % [data.size(), data.is_empty()])
	if data.is_empty():
		return

	var display_exclude = ["A", "UNM"]
	var clan_codes = ["C", "CBS", "CBR", "CCC", "CCY", "CDS", "CFM", "CGB", "CHH", "CI", "CIH", "CJF", "CNC", "CSA", "CSJ", "CSV", "CWF"]
	for name in data:
		var sys = data[name]
		var owner = sys.get("owner_faction", "")
		if name.begins_with("SLSC"):
			continue
		if owner in clan_codes:
			continue
		if sys.get("hide", false):
			continue
		var coords = sys.get("coordinates", {})
		var cx = coords.get("x", 0.0)
		var cy = coords.get("y", 0.0)
		var dist = sqrt(cx * cx + cy * cy)
		if dist > 720.0:
			continue
		var pos = Vector2(cx, -cy)
		var entry = {"name": name, "pos": pos, "data": sys}
		if not sys.get("pathfinding_exclude", false):
			_waypoints.append(entry)
		if owner not in display_exclude:
			systems_positions.append(entry)


func _check_system_click(world_pos: Vector2) -> void:
	var closest = null
	var closest_dist = SYSTEM_BASE_RADIUS + 6.0

	for sys in systems_positions:
		var dist = sys["pos"].distance_to(world_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest = sys

	if closest:
		if selected_system == closest:
			selected_system = {}
			path_start = {}
			jump_path = []
			info_panel.hide_panel()
		else:
			if not selected_system.is_empty() and selected_system != closest:
				path_start = selected_system
				var from_pos = path_start["pos"]
				var to_pos = closest["pos"]
				jump_path = _a_star_jump_path(from_pos, to_pos)
			selected_system = closest
			var sys_name = closest["data"].get("name", "")
			var detail = DataManager.get_system_detail(sys_name)
			var display_data = closest["data"].duplicate()
			for key in detail:
				if key != "_file":
					display_data[key] = detail[key]
			info_panel.show_system(display_data)
	else:
		selected_system = {}
		path_start = {}
		jump_path = []
		info_panel.hide_panel()
	queue_redraw()


# ---- Hex territory cache ----

func _load_territory_cache() -> bool:
	var source_mtime = FileAccess.get_modified_time("res://data/systems_index.json")
	if source_mtime < 0:
		return false
	var cache_file = FileAccess.open(TERRITORY_CACHE_PATH, FileAccess.READ)
	if not cache_file:
		return false
	var parser = JSON.new()
	if parser.parse(cache_file.get_as_text()) != OK:
		return false
	var cache = parser.data
	if cache.get("source_mtime", 0) != source_mtime:
		return false
	if cache.get("format_version") != 2:
		return false
	for h in cache.get("hexes", []):
		_hex_territory.append(h)
	Helpers.debug_print("StarMap", "loaded %d hex territory cells from cache" % _hex_territory.size())
	return not _hex_territory.is_empty()


# ---- Flat-top hex geometry ----

static func _flat_top_hex_corners(cx: float, cy: float, radius: float) -> PackedVector2Array:
	var corners: PackedVector2Array = []
	for i in range(6):
		var angle_deg = 60.0 * i - 30.0
		var angle_rad = deg_to_rad(angle_deg)
		corners.append(Vector2(
			cx + radius * cos(angle_rad),
			cy + radius * sin(angle_rad)
		))
	return corners


func _get_visible_rect() -> Rect2:
	var viewport = get_viewport_rect().size
	var top_left = camera.global_position - viewport / (2.0 * camera.zoom)
	var bottom_right = camera.global_position + viewport / (2.0 * camera.zoom)
	return Rect2(top_left, bottom_right - top_left).grow(HEX_DIAMETER)


# ---- Jump routes ----

func _calculate_jump_routes() -> void:
	_adjacency.clear()
	jump_routes.clear()
	for i in range(_waypoints.size()):
		var a = _waypoints[i]
		var key = a["pos"]
		if not _adjacency.has(key):
			_adjacency[key] = []
		for j in range(i + 1, _waypoints.size()):
			var b = _waypoints[j]
			if a["pos"].distance_to(b["pos"]) <= JUMP_DISTANCE:
				jump_routes.append({"from": a["pos"], "to": b["pos"]})
				_adjacency[key].append({"pos": b["pos"], "sys": b})
				var bkey = b["pos"]
				if not _adjacency.has(bkey):
					_adjacency[bkey] = []
				_adjacency[bkey].append({"pos": a["pos"], "sys": a})


func _a_star_jump_path(from_pos: Vector2, to_pos: Vector2) -> Array:
	if from_pos == to_pos or not _adjacency.has(from_pos) or not _adjacency.has(to_pos):
		return []
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}
	var open_set: Array[Vector2] = [from_pos]
	g_score[from_pos] = 0.0
	f_score[from_pos] = from_pos.distance_to(to_pos) / JUMP_DISTANCE

	while not open_set.is_empty():
		# Linear scan for minimum f_score — typical open set < 100 nodes
		var best_idx := 0
		var best_f := INF
		for i in range(open_set.size()):
			var f = f_score.get(open_set[i], INF)
			if f < best_f:
				best_f = f
				best_idx = i
		var current = open_set[best_idx]
		open_set[best_idx] = open_set[open_set.size() - 1]
		open_set.pop_back()

		if current == to_pos:
			var path: Array[Vector2] = []
			var node = current
			while node != from_pos:
				path.push_front(node)
				node = came_from[node]
			path.push_front(from_pos)
			return path

		for neighbor in _adjacency.get(current, []):
			var npos = neighbor["pos"]
			var tentative_g = g_score.get(current, INF) + 1.0 + npos.distance_to(current) / 10000.0
			if tentative_g < g_score.get(npos, INF):
				came_from[npos] = current
				g_score[npos] = tentative_g
				f_score[npos] = tentative_g + npos.distance_to(to_pos) / JUMP_DISTANCE
				if npos not in open_set:
					open_set.append(npos)
	return []


# ---- Drawing ----

func _draw() -> void:
	_placed_labels.clear()
	draw_rect(Rect2(-5000, -5000, 10000, 10000), Color(0.06, 0.06, 0.1, 1.0))

	var visible_rect = _get_visible_rect()
	_draw_hex_territory(visible_rect)

	var show_names = camera.zoom.x >= NAME_ZOOM_THRESHOLD
	for sys in systems_positions:
		var pos = sys["pos"]
		var data = sys["data"]
		var owner = data.get("owner_faction", "")
		var color = _get_faction_color(owner)
		var r = SYSTEM_BASE_RADIUS

		if owner.begins_with("D("):
			var inner = owner.substr(2, owner.length() - 3)
			var parts = inner.split("/")
			if parts.size() == 2:
				var c1 = _get_faction_color(parts[0])
				var c2 = _get_faction_color(parts[1])
				draw_circle(pos, r, c1)
				draw_circle(pos, r + 1, Color(1, 1, 1, 0.25), false, 1.0)
				var stripe_count = 3
				for si in range(stripe_count):
					var offset = (si - 1) * r * 0.8
					var from = Vector2(pos.x - r * 0.7 + offset, pos.y - r * 1.1)
					var to = Vector2(pos.x + r * 0.7 + offset, pos.y + r * 1.1)
					draw_line(from, to, c2, 1.0, true)
			continue

		if visible_rect.has_point(pos):
			draw_circle(pos, r, color)
			draw_circle(pos, r + 1, Color(1, 1, 1, 0.25), false, 1.0)

			if show_names:
				var font = ThemeDB.fallback_font
				var font_size = ThemeDB.fallback_font_size
				var text_pos = pos + Vector2(SYSTEM_BASE_RADIUS + 3, -SYSTEM_BASE_RADIUS)
				var label_width = sys["name"].length() * font_size * 0.5 / camera.zoom.x
				var label_height = font_size * 1.2 / camera.zoom.x
				var label_rect = Rect2(text_pos.x, text_pos.y - label_height, label_width, label_height)
				var overlaps := false
				for placed in _placed_labels:
					if label_rect.intersects(placed):
						overlaps = true
						break
				if not overlaps:
					_placed_labels.append(label_rect)
					draw_string(font, text_pos, sys["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.85))

	if not selected_system.is_empty():
		var sel_pos = selected_system.get("pos", Vector2.ZERO)
		draw_circle(sel_pos, SYSTEM_BASE_RADIUS + 4, Color(1, 1, 0, 0.6), false, 2.0)

		for sys in systems_positions:
			if sys == selected_system:
				continue
			var dist = sel_pos.distance_to(sys["pos"])
			if dist <= JUMP_DISTANCE:
				draw_line(sel_pos, sys["pos"], Color(0.5, 1.0, 0.5, 0.5), 2.0, true)

		if jump_path.size() >= 2:
			var path_color = Color(0.2, 0.8, 1.0, 0.9)
			for i in range(jump_path.size() - 1):
				draw_line(jump_path[i], jump_path[i + 1], path_color, 3.0, true)
				draw_circle(jump_path[i], 3.0, path_color)
			draw_circle(jump_path[jump_path.size() - 1], 3.0, path_color)


func _draw_hex_territory(visible_rect: Rect2) -> void:
	for h in _hex_territory:
		var cx = h["cx"]
		var cy = h["cy"]
		if not visible_rect.has_point(Vector2(cx, cy)):
			continue

		var corners = _flat_top_hex_corners(cx, cy, HEX_RADIUS)
		var factions: Array = h.get("factions", [])

		if factions.is_empty():
			continue

		if factions.size() == 1:
			var color = _get_faction_color(factions[0]["id"])
			color.a = 0.07
			draw_colored_polygon(corners, color)
		else:
			factions.sort_custom(func(a, b): return a["count"] > b["count"])
			var bg_color = _get_faction_color(factions[0]["id"])
			bg_color.a = 0.07
			draw_colored_polygon(corners, bg_color)

			for fi in range(1, factions.size()):
				if factions[fi]["count"] < 2:
					continue
				var stripe_color = _get_faction_color(factions[fi]["id"])
				stripe_color.a = 0.12
				_draw_hex_stripes(corners, stripe_color, fi)


func _draw_hex_stripes(corners: PackedVector2Array, color: Color, pattern_idx: int) -> void:
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for c in corners:
		if c.x < min_x: min_x = c.x
		if c.x > max_x: max_x = c.x
		if c.y < min_y: min_y = c.y
		if c.y > max_y: max_y = c.y

	var spacing := 4.0
	var offset := spacing * 0.5 * pattern_idx
	var y = min_y + offset
	while y <= max_y:
		var from = Vector2(min_x - 2, y)
		var to = Vector2(max_x + 2, y + (max_x - min_x))
		draw_line(from, to, color, 1.5, true)
		y += spacing


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


# ---- Input ----

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if PanelManager.close_top_panel():
			get_viewport().set_input_as_handled()
		elif info_panel.visible:
			selected_system = {}
			info_panel.hide_panel()
			queue_redraw()
			get_viewport().set_input_as_handled()
		return

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
			var z = camera.zoom * 1.15
			camera.zoom = Vector2(clampf(z.x, 0.3, 5.0), clampf(z.y, 0.3, 5.0))
			queue_redraw()

		elif btn == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var z = camera.zoom / 1.15
			camera.zoom = Vector2(clampf(z.x, 0.3, 5.0), clampf(z.y, 0.3, 5.0))
			queue_redraw()

	if event is InputEventMouseMotion and dragging:
		camera.position -= event.relative / camera.zoom


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var viewport_size = get_viewport_rect().size
	return camera.global_position + (screen_pos - viewport_size * 0.5) / camera.zoom
