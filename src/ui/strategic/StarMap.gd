extends Node2D

var systems_positions: Array[Dictionary] = []
var jump_routes: Array[Dictionary] = []
var selected_system: Dictionary = {}
var path_start: Dictionary = {}
var jump_path: Array = []
var _faction_territory: Dictionary = {}
var _disputed_territory: Dictionary = {}
var _placed_labels: Array[Rect2] = []
var _adjacency: Dictionary = {}
var _waypoints: Array[Dictionary] = []

var dragging: bool = false

const JUMP_DISTANCE: float = 30.0
const SYSTEM_BASE_RADIUS: float = 3.0
const NAME_ZOOM_THRESHOLD: float = 2.5

@onready var camera: Camera2D = $Camera2D
@onready var info_panel = $CanvasLayer/StrategicActions/MarginContainer/VBox/SystemInfoPanel
@onready var org_mgmt = $CanvasLayer/OrganizationManagement
@onready var contract_board = $CanvasLayer/ContractBoard
@onready var personnel_mgmt = $CanvasLayer/PersonnelManagement
@onready var sidebar = $CanvasLayer/StrategicActions
@onready var event_log_ui = $CanvasLayer/EventLog
@onready var unit_roster_ui = $CanvasLayer/UnitRoster
@onready var mech_lab_ui = $CanvasLayer/MechLab
@onready var logistics_ui = $CanvasLayer/LogisticsPanel

func _ready() -> void:
	Helpers.debug_print("StarMap", "_ready start")
	Helpers.debug_print("StarMap", "sidebar=%s org=%s contract=%s personnel=%s event=%s roster=%s mech=%s log=%s" % [
		sidebar, org_mgmt, contract_board, personnel_mgmt,
		event_log_ui, unit_roster_ui, mech_lab_ui, logistics_ui])
	sidebar.organization_tree_requested.connect(_on_organization_tree)
	sidebar.contract_board_requested.connect(_on_contract_board)
	sidebar.personnel_management_requested.connect(_on_personnel_management)
	sidebar.unit_roster_requested.connect(_on_unit_roster)
	sidebar.mech_lab_requested.connect(_on_mech_lab)
	sidebar.logistics_requested.connect(_on_logistics)
	sidebar.event_log_requested.connect(_on_event_log)
	org_mgmt.closed.connect(_on_org_mgmt_closed)
	contract_board.closed.connect(_on_contract_board_closed)
	personnel_mgmt.closed.connect(_on_personnel_mgmt_closed)
	event_log_ui.connect("closed", _on_event_log_closed)
	unit_roster_ui.connect("closed", _on_unit_roster_closed)
	mech_lab_ui.connect("closed", _on_mech_lab_closed)
	logistics_ui.connect("closed", _on_logistics_closed)
	Helpers.debug_print("StarMap", "signals connected, loading systems")
	_load_systems()
	_compute_faction_territory()
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

func _on_contract_board() -> void:
	if not contract_board:
		Helpers.debug_warn("StarMap", "_on_contract_board — contract_board is null")
		return
	Helpers.debug_print("StarMap", "opening contract board")
	sidebar.hide_sidebar()
	contract_board.populate()
	contract_board.show()

func _on_contract_board_closed() -> void:
	contract_board.hide()
	sidebar.show_sidebar()

func _on_organization_tree() -> void:
	if not org_mgmt:
		Helpers.debug_warn("StarMap", "_on_organization_tree — org_mgmt is null")
		return
	Helpers.debug_print("StarMap", "opening org tree")
	sidebar.hide_sidebar()
	org_mgmt.populate_tree()
	org_mgmt.show()

func _on_org_mgmt_closed() -> void:
	Helpers.debug_print("StarMap", "closing org tree")
	org_mgmt.hide()
	sidebar.show_sidebar()

func _on_personnel_management() -> void:
	if not personnel_mgmt:
		Helpers.debug_warn("StarMap", "_on_personnel_management — personnel_mgmt is null")
		return
	Helpers.debug_print("StarMap", "opening personnel mgmt")
	sidebar.hide_sidebar()
	personnel_mgmt.populate_roster()
	personnel_mgmt.show()

func _on_unit_roster() -> void:
	if not unit_roster_ui:
		Helpers.debug_warn("StarMap", "_on_unit_roster — unit_roster_ui is null")
		return
	Helpers.debug_print("StarMap", "opening unit roster")
	sidebar.hide_sidebar()
	unit_roster_ui.populate_tree()
	unit_roster_ui.show()

func _on_mech_lab() -> void:
	if not mech_lab_ui:
		Helpers.debug_warn("StarMap", "_on_mech_lab — mech_lab_ui is null")
		return
	Helpers.debug_print("StarMap", "opening mech lab")
	sidebar.hide_sidebar()
	mech_lab_ui.populate()
	mech_lab_ui.show()

func _on_mech_lab_closed() -> void:
	Helpers.debug_print("StarMap", "closing mech lab")
	mech_lab_ui.hide()
	sidebar.show_sidebar()

func _on_unit_roster_closed() -> void:
	Helpers.debug_print("StarMap", "closing unit roster")
	unit_roster_ui.hide()
	sidebar.show_sidebar()

func _on_event_log() -> void:
	if not event_log_ui:
		Helpers.debug_warn("StarMap", "_on_event_log — event_log_ui is null")
		return
	Helpers.debug_print("StarMap", "opening event log")
	sidebar.hide_sidebar()
	event_log_ui.populate()
	event_log_ui.show()

func _on_logistics() -> void:
	if not logistics_ui:
		Helpers.debug_warn("StarMap", "_on_logistics — logistics_ui is null")
		return
	Helpers.debug_print("StarMap", "opening logistics")
	sidebar.hide_sidebar()
	logistics_ui.populate()
	logistics_ui.show()

func _on_logistics_closed() -> void:
	Helpers.debug_print("StarMap", "closing logistics")
	logistics_ui.hide()
	sidebar.show_sidebar()

func _on_event_log_closed() -> void:
	Helpers.debug_print("StarMap", "closing event log")
	event_log_ui.hide()
	sidebar.show_sidebar()

func _on_personnel_mgmt_closed() -> void:
	Helpers.debug_print("StarMap", "closing personnel mgmt")
	personnel_mgmt.hide()
	sidebar.show_sidebar()

func _load_systems() -> void:
	var data = DataManager.systems_data
	if data.is_empty():
		return
	var pathfind_exclude = ["I(H)", "CS(H)"]
	pathfind_exclude.append_array(["C", "CBS", "CBR", "CCC", "CCY", "CDS", "CFM", "CGB", "CHH", "CI", "CIH", "CJF", "CNC", "CSA", "CSJ", "CSV", "CWF"])
	var display_exclude = ["A", "UNM"]
	for name in data:
		var sys = data[name]
		var owner = sys.get("owner_faction", "")
		if owner in pathfind_exclude or name.begins_with("SLSC"):
			continue
		var coords = sys.get("coordinates", {})
		var cx = coords.get("x", 0.0)
		var cy = coords.get("y", 0.0)
		var dist = sqrt(cx * cx + cy * cy)
		if dist > 720.0:
			continue
		var pos = Vector2(cx, -cy)
		var entry = {"name": name, "pos": pos, "data": sys}
		_waypoints.append(entry)
		if owner not in display_exclude:
			systems_positions.append(entry)

func _compute_faction_territory() -> void:
	# Build influence map via nearest-system Voronoi on a coarse grid.
	# Each faction's territory is the region closest to any of its systems.
	var groups: Dictionary = {}
	for sys in systems_positions:
		var owner = sys["data"].get("owner_faction", "")
		if owner.is_empty() or owner in ["I", "X", "U"]:
			continue
		if not groups.has(owner):
			groups[owner] = []
		groups[owner].append(sys["pos"])

	# Only compute territory for major factions (exclude disputed, hidden, very minor)
	var territory: Dictionary = {}
	var major_codes = ["CC", "DC", "FS", "FWL", "LC", "TC", "MOC", "OA", "I", "AuC", "MH", "OC", "CF", "LL", "TD", "MV", "EF", "IP", "NCR", "CDP", "RC", "FrR", "IE", "MC"]
	for owner in groups:
		if owner in major_codes and groups[owner].size() >= 3:
			territory[owner] = groups[owner]

	# Sample grid step in world units — balance performance vs resolution
	var step = 4.0
	var extent = 800.0
	var grid: Dictionary = {}
	var x_start = -int(extent)
	var x_end = int(extent)
	var y_start = -int(extent)
	var y_end = int(extent)
	for x in range(x_start, x_end + 1, int(step)):
		for y in range(y_start, y_end + 1, int(step)):
			var pt = Vector2(x, y)
			var best_owner = ""
			var best_dist = INF
			# Check major territory factions first (fast path — only ~20 factions)
			for owner in territory:
				for sp in territory[owner]:
					var d = pt.distance_squared_to(sp)
					if d < best_dist:
						best_dist = d
						best_owner = owner
			# Check disputed systems separately (only a handful of them)
			var disputed_pair = ""
			for owner in groups:
				if not owner.begins_with("D("):
					continue
				for sp in groups[owner]:
					var d = pt.distance_squared_to(sp)
					if d < best_dist:
						best_dist = d
						var inner = owner.substr(2, owner.length() - 3)
						if "/" in inner:
							var parts = inner.split("/")
							if parts.size() == 2 and parts[0] in major_codes and parts[1] in major_codes:
								disputed_pair = inner
								best_owner = ""
			if not disputed_pair.is_empty():
				if not _disputed_territory.has(disputed_pair):
					_disputed_territory[disputed_pair] = []
				_disputed_territory[disputed_pair].append(pt)
			elif not best_owner.is_empty():
				if not grid.has(best_owner):
					grid[best_owner] = []
				grid[best_owner].append(pt)

	# Compute density-aware influence radius per faction: tighter for dense clusters,
	# wider for sparse ones, but never exceed 90 LY or go below 30 LY.
	var faction_radius: Dictionary = {}
	for owner in territory:
		var pts = territory[owner]
		var total_nn := 0.0
		var count := 0
		for p in pts:
			var closest = INF
			for q in pts:
				if q == p: continue
				var d = p.distance_squared_to(q)
				if d < closest: closest = d
			if closest < INF:
				total_nn += sqrt(closest)
				count += 1
		var avg_nn = total_nn / max(count, 1)
		var min_r = 45.0 if owner in ["CC", "DC", "FS", "FWL", "LC"] else 30.0
		faction_radius[owner] = clampf(avg_nn * 2.0, min_r, 90.0)

	for owner in grid:
		var pts = grid[owner]
		var max_r = faction_radius.get(owner, 90.0)
		var max_r_sq = max_r * max_r
		var filtered: Array[Vector2] = []
		for pt in pts:
			var min_dist_sq = INF
			for sp in territory[owner]:
				var d = pt.distance_squared_to(sp)
				if d < min_dist_sq:
					min_dist_sq = d
			if min_dist_sq <= max_r_sq:
				filtered.append(pt)
		if filtered.size() >= 3:
			_faction_territory[owner] = filtered


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
		open_set.sort_custom(func(a, b): return f_score.get(a, INF) < f_score.get(b, INF))
		var current = open_set.pop_front()
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
			var tentative_g = g_score.get(current, INF) + 1.0 + neighbor["pos"].distance_to(current) / 10000.0
			if tentative_g < g_score.get(npos, INF):
				came_from[npos] = current
				g_score[npos] = tentative_g
				f_score[npos] = tentative_g + npos.distance_to(to_pos) / JUMP_DISTANCE
				if not npos in open_set:
					open_set.append(npos)
	return []

func _draw() -> void:
	_placed_labels.clear()
	draw_rect(Rect2(-5000, -5000, 10000, 10000), Color(0.06, 0.06, 0.1, 1.0))

	var cell_size = 12.0
	var half_cell = cell_size * 0.5
	for owner in _faction_territory:
		var color = _get_faction_color(owner)
		color.a = 0.07
		for pt in _faction_territory[owner]:
			draw_rect(Rect2(pt.x - half_cell, pt.y - half_cell, cell_size, cell_size), color)

	for pair in _disputed_territory:
		var parts = pair.split("/")
		if parts.size() != 2: continue
		var bg_color = _get_faction_color(parts[0])
		var stripe_color = _get_faction_color(parts[1])
		bg_color.a = 0.07
		stripe_color.a = 0.15
		for pt in _disputed_territory[pair]:
			draw_rect(Rect2(pt.x - half_cell, pt.y - half_cell, cell_size, cell_size), bg_color)
			var s = half_cell * 0.7
			var from = Vector2(pt.x - s, pt.y - s)
			var to = Vector2(pt.x + s, pt.y + s)
			draw_line(from, to, stripe_color, 1.5, true)

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
				for s in range(stripe_count):
					var offset = (s - 1) * r * 0.8
					var from = Vector2(pos.x - r * 0.7 + offset, pos.y - r * 1.1)
					var to = Vector2(pos.x + r * 0.7 + offset, pos.y + r * 1.1)
					draw_line(from, to, c2, 1.0, true)
				continue

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

		# Draw A* jump path
		if jump_path.size() >= 2:
			var path_color = Color(0.2, 0.8, 1.0, 0.9)
			for i in range(jump_path.size() - 1):
				draw_line(jump_path[i], jump_path[i + 1], path_color, 3.0, true)
				draw_circle(jump_path[i], 3.0, path_color)
			draw_circle(jump_path[jump_path.size() - 1], 3.0, path_color)

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
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if mech_lab_ui.visible:
			_on_mech_lab_closed()
			get_viewport().set_input_as_handled()
		elif unit_roster_ui.visible:
			_on_unit_roster_closed()
			get_viewport().set_input_as_handled()
		elif event_log_ui.visible:
			_on_event_log_closed()
			get_viewport().set_input_as_handled()
		elif org_mgmt.visible:
			_on_org_mgmt_closed()
			get_viewport().set_input_as_handled()
		elif contract_board.visible:
			_on_contract_board_closed()
			get_viewport().set_input_as_handled()
		elif logistics_ui.visible:
			_on_logistics_closed()
			get_viewport().set_input_as_handled()
		elif personnel_mgmt.visible:
			_on_personnel_mgmt_closed()
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
			info_panel.show_system(closest["data"])
	else:
		selected_system = {}
		path_start = {}
		jump_path = []
		info_panel.hide_panel()
	queue_redraw()
