class_name PlanetaryMap
extends Panel

signal closed()
signal tactical_requested(contract: Contract, hex_data: Dictionary)
signal hex_selected(hex_dict: Dictionary)
signal reachable_updated(reachable: Dictionary)

const HexMap = preload("res://src/data/HexMap.gd")
const PlanetaryMapGenerator = preload("res://src/strategic/PlanetaryMapGenerator.gd")

var contract: Contract
var hex_map: HexMap
var hex_size: float = 30.0
var selected_hex: Dictionary = {}
var generated: bool = false

var terrain_colors: Dictionary = {}
var objective_labels: Dictionary = {}

var camera_offset: Vector2 = Vector2(200, 100)
var camera_zoom: float = 1.0
var panning: bool = false
var pan_start: Vector2 = Vector2()

var deployed_units: Array[Dictionary] = []
var selected_unit_idx: int = -1
var path_preview: Array[Vector2i] = []
var elapsed_days: int = 0

var marker_palette: Array[Color] = [
	Color(0.3, 0.8, 1.0),
	Color(0.9, 0.5, 0.2),
	Color(0.4, 0.9, 0.4),
	Color(1.0, 0.8, 0.2),
	Color(0.8, 0.4, 0.8),
	Color(0.3, 0.6, 0.9),
	Color(0.9, 0.3, 0.3),
	Color(0.5, 0.9, 0.8),
]

@onready var map_draw: Control = %MapDraw
@onready var detail_label: RichTextLabel = %DetailLabel

var unit_selector: OptionButton
var move_button: Button
var elapsed_label: Label


func _ready() -> void:
	terrain_colors = {
		HexMap.Terrain.PLAINS: Color(0.5, 0.7, 0.3),
		HexMap.Terrain.FOREST: Color(0.2, 0.5, 0.15),
		HexMap.Terrain.MOUNTAIN: Color(0.5, 0.4, 0.25),
		HexMap.Terrain.WATER: Color(0.2, 0.4, 0.7),
		HexMap.Terrain.URBAN: Color(0.6, 0.6, 0.6),
		HexMap.Terrain.DESERT: Color(0.8, 0.7, 0.3),
		HexMap.Terrain.ROUGH: Color(0.45, 0.35, 0.2),
	}
	objective_labels = {
		HexMap.ObjectiveType.NONE: "",
		HexMap.ObjectiveType.PRIMARY: "★ " + tr("Primary"),
		HexMap.ObjectiveType.SECONDARY: "● " + tr("Secondary"),
		HexMap.ObjectiveType.ASSETS: "⚙ " + tr("Assets"),
		HexMap.ObjectiveType.ENEMY: "⚔ " + tr("Enemy"),
		HexMap.ObjectiveType.EVENT: "! " + tr("Event"),
	}

func _unhandled_input(event: InputEvent) -> void:
	if not hex_map or not visible:
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_on_map_input(event)


func load_contract(c: Contract) -> void:
	contract = c
	if not contract:
		return
	elapsed_days = 0
	_generate_map()
	_init_deployed_units()
	_generate_opfor_pool()
	_center_on_landing_zone()


func get_contract() -> Contract:
	return contract


func abandon_contract() -> void:
	if contract and GameState:
		GameState.remove_active_contract(contract)
	hide()
	closed.emit()


func explore_selected_hex() -> void:
	if selected_hex.is_empty():
		return
	var q = selected_hex.get("q", 0)
	var r = selected_hex.get("r", 0)
	hex_map.reveal_hex(q, r)
	var obj = selected_hex.get("objective", HexMap.ObjectiveType.NONE)
	if obj == HexMap.ObjectiveType.ASSETS:
		_show_asset_dialog(selected_hex)
	map_draw.queue_redraw()


func engage_selected_hex() -> void:
	if selected_hex.is_empty() or not contract:
		return
	var strength = selected_hex.get("objective_data", {}).get("strength", 2)
	PlanetaryMapGenerator.draw_from_pool(contract.opfor_pool, strength)
	tactical_requested.emit(contract, selected_hex)


func execute_move() -> void:
	if path_preview.is_empty() or selected_unit_idx < 0:
		return
	var du = deployed_units[selected_unit_idx]
	var total_cost := 0.0
	for p in path_preview:
		if p.x == du.hex_pos.x and p.y == du.hex_pos.y:
			continue
		var cost = hex_map.get_hex_travel_cost(p.x, p.y, du.speed)
		if cost > 0:
			total_cost += cost
	var dest = path_preview[path_preview.size() - 1]
	du.hex_pos = dest
	du.opu.hex_position = dest
	elapsed_days += int(ceil(total_cost))
	for p in path_preview:
		hex_map.reveal_hex(p.x, p.y)
	path_preview.clear()
	_save_map_state()
	map_draw.queue_redraw()


# ---- Camera centering ----

func _center_on_landing_zone() -> void:
	if not hex_map:
		return
	var lz = hex_map.landing_zone
	var lz_pixel = HexMap.axial_to_pixel(lz.x, lz.y, hex_size * camera_zoom)
	camera_offset = map_draw.size / 2 - lz_pixel
	map_draw.queue_redraw()


# ---- Hex generation and input ----

func _generate_map() -> void:
	if generated or not contract:
		return
	if not contract.planetary_map_data.is_empty():
		hex_map = _deserialize_hex_map(contract.planetary_map_data)
		generated = true
		return
	var generator = PlanetaryMapGenerator.new()
	add_child(generator)
	hex_map = generator.generate(contract)
	generator.queue_free()
	generated = true
	contract.planetary_map_data = _serialize_hex_map()
	if not hex_map:
		push_warning("PlanetaryMap: hex_map is null after _generate_map")


func _serialize_hex_map() -> Dictionary:
	if not hex_map:
		return {}
	var hex_list: Array[Dictionary] = []
	for h in hex_map.get_all_hexes():
		hex_list.append({
			"q": h.q, "r": h.r,
			"terrain": h.terrain, "revealed": h.revealed, "explored": h.explored,
			"objective": h.objective, "objective_data": h.objective_data.duplicate(),
			"objective_completed": h.objective_completed,
			"has_road": h.has_road, "has_river": h.has_river,
		})
	return {"width": hex_map.width, "height": hex_map.height, "landing_zone": [hex_map.landing_zone.x, hex_map.landing_zone.y], "hexes": hex_list}


func _deserialize_hex_map(data: Dictionary) -> HexMap:
	var hm = HexMap.new(data.get("width", 10), data.get("height", 10))
	var lz = data.get("landing_zone", [0, 0])
	hm.landing_zone = Vector2i(lz[0], lz[1])
	for entry in data.get("hexes", []):
		var h = hm.get_hex(entry.q, entry.r)
		if h.is_empty(): continue
		h.terrain = entry.get("terrain", 0)
		h.revealed = entry.get("revealed", false)
		h.explored = entry.get("explored", false)
		h.objective = entry.get("objective", 0)
		h.objective_data = entry.get("objective_data", {}).duplicate()
		h.objective_completed = entry.get("objective_completed", false)
		h.has_road = entry.get("has_road", false)
		h.has_river = entry.get("has_river", false)
	return hm


# ---- Input ----

func _on_map_input(event: InputEvent) -> void:
	if not hex_map:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos = map_draw.get_local_mouse_position() - map_draw.size / 2 - camera_offset
			var clicked = _pixel_to_hex(local_pos)
			if clicked:
				var h = hex_map.get_hex(clicked.x, clicked.y)
				if not h.is_empty() and (h.revealed or _is_adjacent_to_revealed(clicked.x, clicked.y)):
					selected_hex = h
					hex_selected.emit(h)
					_update_path_preview()
					map_draw.queue_redraw()
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			panning = true
			pan_start = map_draw.get_local_mouse_position()
		if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			panning = false
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var mouse_map = map_draw.get_local_mouse_position() - map_draw.size / 2
			var world_before = (mouse_map - camera_offset) / camera_zoom
			camera_zoom = clamp(camera_zoom * 1.1, 0.3, 3.0)
			camera_offset = mouse_map - world_before * camera_zoom
			map_draw.queue_redraw()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var mouse_map = map_draw.get_local_mouse_position() - map_draw.size / 2
			var world_before = (mouse_map - camera_offset) / camera_zoom
			camera_zoom = clamp(camera_zoom / 1.1, 0.3, 3.0)
			camera_offset = mouse_map - world_before * camera_zoom
			map_draw.queue_redraw()
	if event is InputEventMouseMotion and panning:
		camera_offset += event.relative
		map_draw.queue_redraw()


# ---- Drawing ----

func _on_map_draw() -> void:
	if not hex_map:
		return
	var draw = map_draw
	var center = draw.size / 2 + camera_offset
	for row in hex_map.hexes:
		for h in row:
			var pixel = HexMap.axial_to_pixel(h.q, h.r, hex_size * camera_zoom) + center
			if not h.revealed and not _is_adjacent_to_revealed(h.q, h.r):
				continue
			var corners = HexMap.hex_corners(pixel, hex_size * camera_zoom)
			var color = terrain_colors.get(h.terrain, Color(0.3, 0.3, 0.3))
			if not h.revealed:
				color = color * 0.4
			draw.draw_colored_polygon(corners, color)
			draw.draw_polyline(corners, Color(0.15, 0.15, 0.18), 1.0, true)
			if h.revealed and h.objective != HexMap.ObjectiveType.NONE:
				var label_pos = pixel - Vector2(0, hex_size * camera_zoom * 0.4)
				var marker = "*"
				match h.objective:
					HexMap.ObjectiveType.PRIMARY: marker = "★"
					HexMap.ObjectiveType.ENEMY: marker = "⚔"
					HexMap.ObjectiveType.ASSETS: marker = "⚙"
					HexMap.ObjectiveType.SECONDARY: marker = "●"
				draw.draw_string(ThemeDB.fallback_font, label_pos, marker, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1, 1, 0.6))
	_draw_force_markers(draw, center)


func _draw_force_markers(draw: Control, center: Vector2) -> void:
	for du in deployed_units:
		var pos = du.hex_pos
		var pixel = HexMap.axial_to_pixel(pos.x, pos.y, hex_size * camera_zoom) + center
		var size = hex_size * camera_zoom * 0.3
		var is_selected = deployed_units.find(du) == selected_unit_idx
		var top = pixel - Vector2(0, size)
		var bl = pixel + Vector2(-size * 0.7, size * 0.5)
		var br = pixel + Vector2(size * 0.7, size * 0.5)
		if is_selected:
			var sel_corners = HexMap.hex_corners(pixel, size * 1.6)
			draw.draw_colored_polygon(sel_corners, Color(1, 1, 0.3, 0.12))
		draw.draw_colored_polygon(PackedVector2Array([top, bl, br]), du.color)
		draw.draw_polyline(PackedVector2Array([top, bl, br, top]), Color(0.1, 0.15, 0.2, 0.8), 2.0, true)
		var label_y = pixel.y + size * 1.6
		draw.draw_string(ThemeDB.fallback_font, Vector2(pixel.x, label_y), du.name, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(1, 1, 1, 0.85))


# ---- Helper ----

func _pixel_to_hex(pos: Vector2) -> Vector2i:
	var size = hex_size * camera_zoom
	var q = (sqrt(3.0) / 3.0 * pos.x - 1.0 / 3.0 * pos.y) / size
	var r = (2.0 / 3.0 * pos.y) / size
	return _round_to_axial(q, r)


static func _round_to_axial(q: float, r: float) -> Vector2i:
	var s = -q - r
	var rq = round(q)
	var rr = round(r)
	var rs = round(s)
	var q_diff = abs(rq - q)
	var r_diff = abs(rr - r)
	var s_diff = abs(rs - s)
	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))


func _is_adjacent_to_revealed(q: int, r: int) -> bool:
	var adj = HexMap.get_adjacent(q, r)
	for a in adj:
		if hex_map.is_revealed(a.x, a.y):
			return true
	return false


func _update_path_preview() -> void:
	path_preview.clear()
	if selected_hex.is_empty() or selected_unit_idx < 0:
		return
	var du = deployed_units[selected_unit_idx]
	var tx = selected_hex.get("q", 0)
	var ty = selected_hex.get("r", 0)
	var speed = du.speed
	path_preview = hex_map.find_path(du.hex_pos.x, du.hex_pos.y, tx, ty, speed)


func _save_map_state() -> void:
	if contract and hex_map:
		contract.planetary_map_data = _serialize_hex_map()


func _init_deployed_units() -> void:
	deployed_units.clear()
	if not contract:
		return
	# Reveal landing zone so the map isn't entirely fog-of-war
	if hex_map:
		hex_map.reveal_hex(hex_map.landing_zone.x, hex_map.landing_zone.y)
		for adj in HexMap.get_adjacent(hex_map.landing_zone.x, hex_map.landing_zone.y):
			hex_map.reveal_hex(adj.x, adj.y)
	for ou in GameState.player.organizational_units:
		if ou.contract_id == str(contract.get_instance_id()) and ou.is_deployed:
			for su in ou.sub_units:
				_collect_unit(su)
			break
	if deployed_units.is_empty():
		return
	for i in range(deployed_units.size()):
		var du = deployed_units[i]
		if du.opu.hex_position != Vector2i(0, 0) and _hex_on_map(du.opu.hex_position):
			du.hex_pos = du.opu.hex_position
		else:
			du.hex_pos = hex_map.landing_zone
			du.opu.hex_position = du.hex_pos
		du.color = marker_palette[i % marker_palette.size()]
	map_draw.queue_redraw()


func _collect_unit(opu) -> void:
	if opu.tactical_units.size() > 0:
		var speed := 99
		for tu in opu.get_all_tactical_units():
			if tu.movement_mp > 0 and tu.movement_mp < speed:
				speed = tu.movement_mp
		if speed == 99: speed = 4
		deployed_units.append({
			"opu": opu, "name": opu.unit_name, "hex_pos": hex_map.landing_zone,
			"speed": speed, "color": Color(0.3, 0.8, 1.0),
		})
	for sub in opu.sub_units:
		_collect_unit(sub)


func _generate_opfor_pool() -> void:
	if not contract or (not contract.opfor_pool.is_empty() and not contract.opfor_template_id.is_empty()):
		return
	var biome_name = "temperate"
	var tmpl = PlanetaryMapGenerator.select_opfor_template(contract.activity_type, biome_name)
	if tmpl.is_empty():
		return
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	contract.opfor_pool = PlanetaryMapGenerator.generate_opfor_pool(tmpl, rng)
	contract.opfor_template_id = tmpl.get("id", "")


func _hex_on_map(pos: Vector2i) -> bool:
	return not hex_map.get_hex(pos.x, pos.y).is_empty()


func _show_asset_dialog(hex_data: Dictionary) -> void:
	var data = hex_data.get("objective_data", {})
	var asset_type = data.get("type", "unknown")
	var description = data.get("description", "")
	var value = data.get("value", 0)
	var asset_names = {
		"battlefield_remnants": "Battlefield Remnants", "artifact": "Artifact",
		"civilian_equipment": "Civilian Equipment", "salvageable_mech": "Salvageable 'Mech",
		"military_supplies": "Military Supplies", "comms_equipment": "Communications Equipment",
		"precious_metals": "Precious Metals", "currency_cache": "Currency Cache",
	}
	var title = asset_names.get(asset_type, "Unknown Asset")
	var msg = "%s\n\n%s\n\n" % [title, description]
	msg += "Estimated value: %s" % Helpers.fmt_money(value) + "\n\n" + "Take these assets?"
	var dialog = AcceptDialog.new()
	dialog.title = "Assets Found"
	dialog.dialog_text = msg
	dialog.min_size = Vector2i(450, 250)
	dialog.confirmed.connect(func():
		EconomySystem.add_funds(value, "Assets recovered: " + title)
		selected_hex.objective_completed = true
		_save_map_state()
	)
	dialog.ok_button_text = "Take Assets"
	add_child(dialog)
	dialog.popup_centered()
