class_name PlanetaryMap
extends Panel

signal closed()

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

var reveal_queue: Array[Vector2i] = []

@onready var map_draw: Control = %MapDraw
@onready var detail_label: RichTextLabel = %DetailLabel
@onready var hex_info_label: Label = %HexInfoLabel
@onready var explore_button: Button = %ExploreButton
@onready var close_button: Button = %CloseButton
@onready var contract_label: Label = %ContractLabel


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

	close_button.pressed.connect(_on_close)
	explore_button.pressed.connect(_on_explore)
	map_draw.gui_input.connect(_on_map_input)
	map_draw.draw.connect(_on_map_draw)

	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))


func load_contract(c: Contract) -> void:
	contract = c
	if not contract:
		return
	contract_label.text = "%s — %s" % [contract.activity_type, contract.planet]
	_generate_map()


func _generate_map() -> void:
	if generated or not contract:
		return
	var generator = PlanetaryMapGenerator.new()
	add_child(generator)
	hex_map = generator.generate(contract)
	generator.queue_free()
	generated = true


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


func _update_hex_info() -> void:
	if selected_hex.is_empty():
		hex_info_label.text = ""
		explore_button.disabled = true
		return

	var q = selected_hex.get("q", 0)
	var r = selected_hex.get("r", 0)
	var terrain_names = HexMap.Terrain.keys()
	var terrain_name = terrain_names[selected_hex.get("terrain", 0)].capitalize()

	var info = tr("Hex (%d, %d) — %s") % [q, r, terrain_name]

	if selected_hex.get("revealed", false):
		var obj = selected_hex.get("objective", HexMap.ObjectiveType.NONE)
		if obj != HexMap.ObjectiveType.NONE:
			info += "\n" + objective_labels.get(obj, "")
	else:
		info += "\n" + tr("Unexplored")
		explore_button.disabled = false
		return

	hex_info_label.text = info
	explore_button.disabled = selected_hex.get("revealed", false)


func _on_explore() -> void:
	if selected_hex.is_empty():
		return
	var q = selected_hex.get("q", 0)
	var r = selected_hex.get("r", 0)
	hex_map.reveal_hex(q, r)
	explore_button.disabled = true

	var obj = selected_hex.get("objective", HexMap.ObjectiveType.NONE)
	if obj != HexMap.ObjectiveType.NONE:
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
	else:
		detail_label.text = "[b]" + tr("Exploration Result:") + "[/b]\n" + tr("Nothing of interest in this hex.")

	map_draw.queue_redraw()


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
	)
	dialog.canceled.connect(func():
		detail_label.text = "[b]" + tr("Assets Left Behind") + "[/b]\n" + title
	)
	var cancel_btn = dialog.get_cancel_button()
	if cancel_btn:
		cancel_btn.text = tr("Leave Them")
	dialog.ok_button_text = tr("Take Assets")
	add_child(dialog)
	dialog.popup_centered()


func _on_close() -> void:
	hide()
	closed.emit()
