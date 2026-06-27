class_name PlanetaryMap
extends Panel

signal closed()
signal tactical_requested(contract: Contract, hex_data: Dictionary)

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
@onready var hex_info_label: Label = %HexInfoLabel
@onready var explore_button: Button = %ExploreButton
@onready var engage_button: Button = %EngageButton
@onready var close_button: Button = %CloseButton
@onready var contract_label: Label = %ContractLabel

var unit_selector: OptionButton
var progress_label: Label
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

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	add_theme_stylebox_override("panel", bg)

	Helpers.validate_nodes("PlanetaryMap", [
		["map_draw", map_draw], ["detail_label", detail_label],
		["hex_info_label", hex_info_label], ["explore_button", explore_button],
		["close_button", close_button], ["contract_label", contract_label],
	])

	_build_move_ui()

	close_button.pressed.connect(_on_close)
	explore_button.pressed.connect(_on_explore)
	engage_button.pressed.connect(_on_engage)
	map_draw.gui_input.connect(_on_map_input)
	map_draw.draw.connect(_on_map_draw)

	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))


func _build_move_ui() -> void:
	var side = %HexInfoLabel.get_parent()
	var sep = HSeparator.new()
	side.add_child(sep)

	progress_label = Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.text = ""
	progress_label.add_theme_font_size_override("font_size", 12)
	side.add_child(progress_label)

	elapsed_label = Label.new()
	elapsed_label.text = tr("Days: 0")
	elapsed_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	elapsed_label.add_theme_font_size_override("font_size", 12)
	side.add_child(elapsed_label)

	var unit_lbl = Label.new()
	unit_lbl.text = tr("Selected Unit:")
	unit_lbl.add_theme_font_size_override("font_size", 11)
	side.add_child(unit_lbl)

	unit_selector = OptionButton.new()
	unit_selector.name = "UnitSelector"
	unit_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_selector.item_selected.connect(_on_unit_selected)
	side.add_child(unit_selector)

	var move_sep = HSeparator.new()
	side.add_child(move_sep)

	move_button = Button.new()
	move_button.text = tr("Move Here")
	move_button.disabled = true
	move_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_button.pressed.connect(_on_move)
	side.add_child(move_button)


func load_contract(c: Contract) -> void:
	contract = c
	if not contract:
		return
	contract_label.text = "%s — %s" % [contract.activity_type, contract.planet]
	elapsed_days = 0
	_generate_map()
	_init_deployed_units()
	_generate_opfor_pool()


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


func _serialize_hex_map() -> Dictionary:
	if not hex_map:
		return {}
	var hex_list: Array[Dictionary] = []
	for h in hex_map.get_all_hexes():
		hex_list.append({
			"q": h.q, "r": h.r,
			"terrain": h.terrain,
			"revealed": h.revealed,
			"explored": h.explored,
			"objective": h.objective,
			"objective_data": h.objective_data.duplicate(),
			"objective_completed": h.objective_completed,
			"has_road": h.has_road,
			"has_river": h.has_river,
		})
	return {
		"width": hex_map.width,
		"height": hex_map.height,
		"landing_zone": [hex_map.landing_zone.x, hex_map.landing_zone.y],
		"hexes": hex_list,
	}


func _deserialize_hex_map(data: Dictionary) -> HexMap:
	var hm = HexMap.new(data.get("width", 10), data.get("height", 10))
	var lz = data.get("landing_zone", [0, 0])
	hm.landing_zone = Vector2i(lz[0], lz[1])
	var hex_list: Array = data.get("hexes", [])
	for entry in hex_list:
		var h = hm.get_hex(entry.q, entry.r)
		if h.is_empty():
			continue
		h.terrain = entry.get("terrain", 0)
		h.revealed = entry.get("revealed", false)
		h.explored = entry.get("explored", false)
		h.objective = entry.get("objective", 0)
		h.objective_data = entry.get("objective_data", {}).duplicate()
		h.objective_completed = entry.get("objective_completed", false)
		h.has_road = entry.get("has_road", false)
		h.has_river = entry.get("has_river", false)
	return hm


func _init_deployed_units() -> void:
	deployed_units.clear()
	unit_selector.clear()
	if not contract:
		return

	for ou in GameState.player.organizational_units:
		if ou.contract_id == str(contract.get_instance_id()) and ou.is_deployed:
			for su in ou.sub_units:
				_collect_sub_units(su)
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
		var marker_color = marker_palette[i % marker_palette.size()]
		du.color = marker_color
		unit_selector.add_item(du.name)
		unit_selector.set_item_metadata(i, i)

	selected_unit_idx = 0
	unit_selector.selected = 0
	map_draw.queue_redraw()


func _collect_sub_units(opu) -> void:
	if opu.tactical_units.size() > 0:
		var speed := 99
		for tu in opu.get_all_tactical_units():
			if tu.movement_mp > 0 and tu.movement_mp < speed:
				speed = tu.movement_mp
		if speed == 99:
			speed = 4
		var label = opu.unit_name
		if label.is_empty():
			label = tr("Unit %d") % deployed_units.size()
		deployed_units.append({
			"opu": opu,
			"name": label,
			"hex_pos": hex_map.landing_zone,
			"speed": speed,
			"color": Color(0.3, 0.8, 1.0),
		})
	for sub in opu.sub_units:
		_collect_sub_units(sub)


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


func _draw_map() -> void:
	if not map_draw or not hex_map:
		return
	map_draw.queue_redraw()


func _on_map_draw() -> void:
	if not hex_map:
		return

	var draw = map_draw
	var center = draw.size / 2 + camera_offset

	for row in hex_map.hexes:
		for h in row:
			var pixel = HexMap.axial_to_pixel(h.q, h.r, hex_size) + center

			if not h.revealed and not _is_adjacent_to_revealed(h.q, h.r):
				continue

			var corners = HexMap.hex_corners(pixel, hex_size * camera_zoom)
			var color = terrain_colors.get(h.terrain, Color(0.3, 0.3, 0.3))

			if not h.revealed:
				color = color * 0.4

			if _hex_in_path(h.q, h.r):
				var path_corners = HexMap.hex_corners(pixel, hex_size * camera_zoom + 2)
				draw.draw_colored_polygon(path_corners, Color(0.3, 0.7, 1.0, 0.25))

			var highlight = Color(1, 1, 0.6) if selected_hex.get("q") == h.q and selected_hex.get("r") == h.r else Color()
			if highlight.a > 0:
				var hl_corners = HexMap.hex_corners(pixel, hex_size * camera_zoom + 3)
				draw.draw_colored_polygon(hl_corners, Color(1, 0.9, 0.3, 0.4))

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


func _hex_in_path(q: int, r: int) -> bool:
	for p in path_preview:
		if p.x == q and p.y == r:
			return true
	return false


func _draw_force_markers(draw: Control, center: Vector2) -> void:
	for du in deployed_units:
		var pos = du.hex_pos
		var pixel = HexMap.axial_to_pixel(pos.x, pos.y, hex_size) + center
		var size = hex_size * camera_zoom * 0.3
		var is_selected = deployed_units.find(du) == selected_unit_idx

		var top = pixel - Vector2(0, size)
		var bl = pixel + Vector2(-size * 0.7, size * 0.5)
		var br = pixel + Vector2(size * 0.7, size * 0.5)
		var fill = du.color
		var outline = Color(0.1, 0.15, 0.2, 0.8)

		if is_selected:
			var sel_corners = HexMap.hex_corners(pixel, size * 1.6)
			draw.draw_colored_polygon(sel_corners, Color(1, 1, 0.3, 0.12))

		draw.draw_colored_polygon(PackedVector2Array([top, bl, br]), fill)
		draw.draw_polyline(PackedVector2Array([top, bl, br, top]), outline, 2.0, true)

		var label_y = pixel.y + size * 1.6
		draw.draw_string(ThemeDB.fallback_font, Vector2(pixel.x, label_y), du.name,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(1, 1, 1, 0.85))


func _hex_on_map(pos: Vector2i) -> bool:
	return not hex_map.get_hex(pos.x, pos.y).is_empty()


func _save_map_state() -> void:
	if contract and hex_map:
		contract.planetary_map_data = _serialize_hex_map()


func _is_adjacent_to_revealed(q: int, r: int) -> bool:
	var adj = HexMap.get_adjacent(q, r)
	for a in adj:
		if hex_map.is_revealed(a.x, a.y):
			return true
	return false


func _on_map_input(event: InputEvent) -> void:
	if not hex_map:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos = event.position - map_draw.size / 2 - camera_offset
			var clicked = _pixel_to_hex(local_pos)
			if clicked:
				var h = hex_map.get_hex(clicked.x, clicked.y)
				if not h.is_empty() and (h.revealed or _is_adjacent_to_revealed(clicked.x, clicked.y)):
					selected_hex = h
					_try_select_unit_at_hex(clicked)
					_update_path_preview()
					_update_hex_info()
					map_draw.queue_redraw()

		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			panning = true
			pan_start = event.position

		if event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
			panning = false

		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_zoom = clamp(camera_zoom * 1.1, 0.3, 3.0)
			map_draw.queue_redraw()

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_zoom = clamp(camera_zoom / 1.1, 0.3, 3.0)
			map_draw.queue_redraw()

	if event is InputEventMouseMotion and panning:
		camera_offset += event.relative
		map_draw.queue_redraw()


func _try_select_unit_at_hex(clicked: Vector2i) -> void:
	for i in range(deployed_units.size()):
		var du = deployed_units[i]
		if du.hex_pos == clicked:
			selected_unit_idx = i
			unit_selector.selected = i
			return


func _on_unit_selected(index: int) -> void:
	if index < 0 or index >= deployed_units.size():
		return
	selected_unit_idx = index
	path_preview.clear()
	var du = deployed_units[index]
	if not selected_hex.is_empty():
		var sq = selected_hex.get("q", 0)
		var sr = selected_hex.get("r", 0)
		if sq == du.hex_pos.x and sr == du.hex_pos.y:
			_update_hex_info()
			map_draw.queue_redraw()
			return
		_update_path_preview()
	_update_hex_info()
	map_draw.queue_redraw()


func _get_selected_unit() -> Dictionary:
	if selected_unit_idx >= 0 and selected_unit_idx < deployed_units.size():
		return deployed_units[selected_unit_idx]
	return {}


func _update_path_preview() -> void:
	path_preview.clear()
	var du = _get_selected_unit()
	if du.is_empty() or selected_hex.is_empty():
		return
	var tx = selected_hex.get("q", 0)
	var ty = selected_hex.get("r", 0)
	if tx == du.hex_pos.x and ty == du.hex_pos.y:
		return
	path_preview = hex_map.find_path(du.hex_pos.x, du.hex_pos.y, tx, ty, du.speed)


## Approximate pixel to axial hex conversion for flat-top hexes.
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


func _update_progress() -> void:
	if not hex_map:
		return
	var total_primary := 0
	var done_primary := 0
	var total_secondary := 0
	var done_secondary := 0
	var total_assets := 0
	var done_assets := 0
	var total_enemy := 0
	var done_enemy := 0
	for h in hex_map.get_all_hexes():
		if not h.revealed:
			continue
		match h.objective:
			HexMap.ObjectiveType.PRIMARY:
				total_primary += 1
				if h.objective_completed:
					done_primary += 1
			HexMap.ObjectiveType.SECONDARY:
				total_secondary += 1
				if h.objective_completed:
					done_secondary += 1
			HexMap.ObjectiveType.ASSETS:
				total_assets += 1
				if h.objective_completed:
					done_assets += 1
			HexMap.ObjectiveType.ENEMY:
				total_enemy += 1
				if h.objective_completed:
					done_enemy += 1

	var parts: Array[String] = []
	if total_primary > 0:
		parts.append(tr("★ %d/%d") % [done_primary, total_primary])
	if total_secondary > 0:
		parts.append(tr("● %d/%d") % [done_secondary, total_secondary])
	if total_assets > 0:
		parts.append(tr("⚙ %d/%d") % [done_assets, total_assets])
	if total_enemy > 0:
		parts.append(tr("⚔ %d/%d") % [done_enemy, total_enemy])
	progress_label.text = "  ".join(parts)


func _update_hex_info() -> void:
	if selected_hex.is_empty():
		hex_info_label.text = ""
		explore_button.disabled = true
		engage_button.hide()
		move_button.disabled = true
		return

	var q = selected_hex.get("q", 0)
	var r = selected_hex.get("r", 0)
	var terrain_names = HexMap.Terrain.keys()
	var terrain_name = terrain_names[selected_hex.get("terrain", 0)].capitalize()

	var du = _get_selected_unit()
	var is_du_here = (not du.is_empty() and du.hex_pos.x == q and du.hex_pos.y == r)

	var info = tr("Hex (%d, %d) — %s") % [q, r, terrain_name]

	var units_here := 0
	for d in deployed_units:
		if d.hex_pos.x == q and d.hex_pos.y == r:
			units_here += 1

	if units_here > 0:
		info += "\n" + tr("Units here: %d") % units_here

	if selected_hex.get("revealed", false):
		var obj = selected_hex.get("objective", HexMap.ObjectiveType.NONE)
		if obj != HexMap.ObjectiveType.NONE:
			info += "\n" + objective_labels.get(obj, "")
		if obj == HexMap.ObjectiveType.ENEMY:
			engage_button.show()
		else:
			engage_button.hide()
	else:
		info += "\n" + tr("Unexplored")
		if is_du_here:
			explore_button.disabled = true
		else:
			explore_button.disabled = false
		engage_button.hide()

	if not du.is_empty() and not is_du_here and not path_preview.is_empty():
		var total_cost := 0.0
		for p in path_preview:
			if p.x == du.hex_pos.x and p.y == du.hex_pos.y:
				continue
			var cost = hex_map.get_hex_travel_cost(p.x, p.y, du.speed)
			if cost > 0:
				total_cost += cost
		var days_str = str(total_cost) if total_cost == floor(total_cost) else "%2.f" % [total_cost]
		info += "\n[b]" + (tr("Travel: ~%s days") % [days_str]) + "[/b]"
		move_button.disabled = false
	else:
		move_button.disabled = true

	if is_du_here:
		info += "\n" + tr("[color=#88ccff]%s is here[/color]") % du.name

	hex_info_label.text = info
	explore_button.disabled = selected_hex.get("revealed", false) or is_du_here


func _on_explore() -> void:
	if selected_hex.is_empty():
		return
	var q = selected_hex.get("q", 0)
	var r = selected_hex.get("r", 0)
	hex_map.reveal_hex(q, r)
	explore_button.disabled = true

	var obj = selected_hex.get("objective", HexMap.ObjectiveType.NONE)
	var is_empty_hex = (obj == HexMap.ObjectiveType.NONE)
	if not is_empty_hex:
		var obj_data = selected_hex.get("objective_data", {})
		var found_text = ""
		match obj:
			HexMap.ObjectiveType.PRIMARY:
				found_text = tr("Primary objective found! Engage the target.")
				detail_label.text = "[b]" + tr("Exploration Result:") + "[/b]\n" + found_text
			HexMap.ObjectiveType.SECONDARY:
				found_text = tr("Secondary objective discovered: %s") % obj_data.get("type", tr("unknown"))
				detail_label.text = "[b]" + tr("Exploration Result:") + "[/b]\n" + found_text
			HexMap.ObjectiveType.ASSETS:
				_show_asset_dialog(selected_hex)
			HexMap.ObjectiveType.ENEMY:
				var strength = obj_data.get("strength", 1)
				found_text = tr("Enemy force detected! Strength level: %d") % strength
				detail_label.text = "[b]" + tr("Exploration Result:") + "[/b]\n" + found_text

	if is_empty_hex:
		var explored_count := 0
		for h in hex_map.get_all_hexes():
			if h.explored:
				explored_count += 1
		var ev = PlanetaryMapGenerator.check_event({"has_objective": false}, explored_count, "")
		if not ev.is_empty():
			var msg = ev.get("effect", {}).get("message", "")
			var actions: Array = ev.get("effect", {}).get("actions", [])
			for action in actions:
				match action.get("type", ""):
					"add_objective":
						var ot = action.get("objective_type", "ASSETS")
						var od = action.get("data", {})
						match ot:
							"ASSETS":
								selected_hex.objective = HexMap.ObjectiveType.ASSETS
							"ENEMY":
								selected_hex.objective = HexMap.ObjectiveType.ENEMY
							"SECONDARY":
								selected_hex.objective = HexMap.ObjectiveType.SECONDARY
						selected_hex.objective_data = od.duplicate()
			if msg:
				detail_label.text = "[b]" + tr("Event!") + "[/b]\n" + msg
			_save_map_state()
			_update_progress()
			map_draw.queue_redraw()
			return

	if is_empty_hex:
		detail_label.text = "[b]" + tr("Exploration Result:") + "[/b]\n" + tr("Nothing of interest in this hex.")

	if obj == HexMap.ObjectiveType.SECONDARY:
		selected_hex.objective_completed = true
	_save_map_state()
	_update_progress()
	map_draw.queue_redraw()


func _on_move() -> void:
	var du = _get_selected_unit()
	if du.is_empty() or path_preview.is_empty():
		return

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
	elapsed_label.text = tr("Days: %d") % elapsed_days

	for p in path_preview:
		hex_map.reveal_hex(p.x, p.y)

	path_preview.clear()
	move_button.disabled = true
	explore_button.disabled = true
	_save_map_state()
	detail_label.text = "[b]" + tr("Force Moved") + "[/b]\n" + tr("%s arrived at hex (%d, %d) after ~%d days.") % [du.name, dest.x, dest.y, int(ceil(total_cost))]
	map_draw.queue_redraw()


func _on_engage() -> void:
	if selected_hex.is_empty() or not contract:
		return
	var obj = selected_hex.get("objective", HexMap.ObjectiveType.NONE)
	if obj == HexMap.ObjectiveType.ENEMY or obj == HexMap.ObjectiveType.PRIMARY:
		selected_hex.objective_completed = true
		_save_map_state()
		_update_progress()
	var strength = selected_hex.get("objective_data", {}).get("strength", 2)
	var opfor_subset = PlanetaryMapGenerator.draw_from_pool(contract.opfor_pool, strength)
	tactical_requested.emit(contract, selected_hex)


func _show_asset_dialog(hex_data: Dictionary) -> void:
	var data = hex_data.get("objective_data", {})
	var asset_type = data.get("type", "unknown")
	var description = data.get("description", "")
	var value = data.get("value", 0)

	var asset_names = {
		"battlefield_remnants": tr("Battlefield Remnants"),
		"artifact": tr("Artifact"),
		"civilian_equipment": tr("Civilian Equipment"),
		"salvageable_mech": tr("Salvageable 'Mech"),
		"military_supplies": tr("Military Supplies"),
		"comms_equipment": tr("Communications Equipment"),
		"precious_metals": tr("Precious Metals"),
		"currency_cache": tr("Currency Cache"),
	}

	var title = asset_names.get(asset_type, tr("Unknown Asset"))
	var msg = "%s\n\n%s\n\n" % [title, description]
	msg += tr("Estimated value: %s") % Helpers.fmt_money(value) + "\n\n"
	msg += tr("Take these assets?")

	var dialog = AcceptDialog.new()
	dialog.title = tr("Assets Found")
	dialog.dialog_text = msg
	dialog.min_size = Vector2i(450, 250)
	dialog.confirmed.connect(func():
		EconomySystem.add_funds(value, "Assets recovered: " + title)
		detail_label.text = "[b]" + tr("Assets Recovered:") + "[/b]\n" + title + "\n" + tr("Value: %s") % Helpers.fmt_money(value)
		selected_hex.objective_completed = true
		_save_map_state()
		_update_progress()
	)
	dialog.canceled.connect(func():
		detail_label.text = "[b]" + tr("Assets Left Behind") + "[/b]\n" + title
		selected_hex.objective_completed = true
		_save_map_state()
		_update_progress()
	)
	var cancel_btn = dialog.get_cancel_button()
	if cancel_btn:
		cancel_btn.text = tr("Leave Them")
	dialog.ok_button_text = tr("Take Assets")
	add_child(dialog)
	dialog.popup_centered()


func _primary_objectives_done() -> bool:
	if not hex_map:
		return true
	for h in hex_map.get_all_hexes():
		if h.objective == HexMap.ObjectiveType.PRIMARY and not h.objective_completed:
			return false
	return true


func _on_close() -> void:
	_save_map_state()
	var dialog := AcceptDialog.new()
	dialog.title = tr("Abandon Contract")
	dialog.dialog_text = tr("Abandon %s on %s? The contract will not be fulfilled.") % [contract.activity_type, contract.planet]
	dialog.min_size = Vector2i(400, 120)
	dialog.ok_button_text = tr("Abandon")
	dialog.confirmed.connect(func():
		if GameState:
			GameState.remove_active_contract(contract)
		hide()
		closed.emit()
	)
	add_child(dialog)
	dialog.popup_centered()
