class_name TacticalMap
extends Control

signal closed()

const HexMap = preload("res://src/data/HexMap.gd")

const TERRAIN_COLORS: Dictionary = {
	"clear": Color(0.45, 0.65, 0.3),
	"light_woods": Color(0.2, 0.55, 0.2),
	"heavy_woods": Color(0.15, 0.4, 0.12),
	"water": Color(0.25, 0.45, 0.7),
	"paved": Color(0.55, 0.55, 0.55),
	"rough": Color(0.5, 0.4, 0.25),
	"sand": Color(0.75, 0.7, 0.4),
	"ice": Color(0.75, 0.85, 0.9),
	"heavy_snow": Color(0.85, 0.88, 0.92),
	"swamp": Color(0.35, 0.4, 0.2),
}

const HEX_SIZE: float = 24.0

var contract: Contract
var player_units: Array[TacticalUnit] = []
var enemy_units: Array[TacticalUnit] = []
var deployment: Array[OperationalUnit] = []
var _hex_data: Dictionary = {}
var _tactical_hex_map: HexMap
var _movement_resolver: TacticalMovementResolver
var _current_unit_idx: int = -1
var _selected_hex: Vector2i = Vector2i(-1, -1)
var _mode: String = "walk"
var _reachable_result: Dictionary = {}
var _camera_offset: Vector2 = Vector2(200, 80)
var _camera_zoom: float = 1.0
var _panning: bool = false
var _pan_start: Vector2 = Vector2()

var _unit_positions: Array[Vector2i] = []
var _unit_facings: Array[int] = []
var _unit_heights: Array[int] = []
var _unit_current_mp: Array[int] = []
var _resolved: bool = false
var _result: Dictionary = {}

@onready var hex_draw: Control = %HexDraw
@onready var info_label: RichTextLabel = %InfoLabel
@onready var hex_info_label: Label = %HexInfoLabel
@onready var title_label: Label = %TitleLabel
@onready var unit_selector: OptionButton = %UnitSelector
@onready var move_button: Button = %MoveButton
@onready var resolve_button: Button = %ResolveButton
@onready var return_button: Button = %ReturnButton
@onready var mode_walk: Button = %ModeWalk
@onready var mode_run: Button = %ModeRun
@onready var mode_jump: Button = %ModeJump


func _ready() -> void:
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	add_theme_stylebox_override("panel", bg)

	Helpers.validate_nodes("TacticalMap", [
		["hex_draw", hex_draw], ["info_label", info_label],
		["title_label", title_label], ["unit_selector", unit_selector],
		["move_button", move_button], ["resolve_button", resolve_button],
		["return_button", return_button],
	])

	hex_draw.gui_input.connect(_on_hex_draw_input)
	hex_draw.draw.connect(_on_draw)
	unit_selector.item_selected.connect(_on_unit_selected)
	move_button.pressed.connect(_on_move)
	resolve_button.pressed.connect(_on_resolve)
	return_button.pressed.connect(_on_return)

	mode_walk.toggled.connect(func(t): _on_mode_changed("walk", t))
	mode_run.toggled.connect(func(t): _on_mode_changed("run", t))
	mode_jump.toggled.connect(func(t): _on_mode_changed("jump", t))

	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))

	_movement_resolver = TacticalMovementResolver.new()


func load_engagement(c: Contract, hex_data: Dictionary, deployed: Array[OperationalUnit]) -> void:
	contract = c
	_hex_data = hex_data
	deployment = deployed
	player_units = []
	for opu in deployed:
		player_units.append_array(opu.get_all_tactical_units())

	var q = hex_data.get("q", 0)
	var r = hex_data.get("r", 0)
	var cache_key = "%d,%d" % [q, r]

	if contract.tactical_cache.has(cache_key):
		enemy_units = _deserialize_units(contract.tactical_cache[cache_key])
	else:
		var strength = hex_data.get("objective_data", {}).get("strength", 1)
		enemy_units = _generate_opfor(strength)
		contract.tactical_cache[cache_key] = _serialize_units(enemy_units)

	_build_tactical_hex_map()
	title_label.text = tr("Tactical Engagement — %s") % contract.activity_type

	unit_selector.clear()
	_unit_positions.clear()
	_unit_facings.clear()
	_unit_heights.clear()
	_unit_current_mp.clear()
	for i in range(player_units.size()):
		var u = player_units[i]
		unit_selector.add_item(u.unit_name + " (%dt)" % int(u.tonnage))
		_unit_positions.append(_tactical_hex_map.landing_zone)
		_unit_facings.append(0)
		_unit_heights.append(_tactical_hex_map.get_hex(_tactical_hex_map.landing_zone.x, _tactical_hex_map.landing_zone.y).get("elevation", 0))
		_unit_current_mp.append(u.movement_mp)

	if player_units.size() > 0:
		_current_unit_idx = 0
		unit_selector.select(0)
		_update_reachable()

	_refresh_display()


func _build_tactical_hex_map() -> void:
	var map_w = _hex_data.get("map_width", 16)
	var map_h = _hex_data.get("map_height", 16)
	_tactical_hex_map = HexMap.new(map_w, map_h)

	var terrain_ids = _hex_data.get("terrain_grid", [])
	for row in range(_tactical_hex_map.hexes.size()):
		var hex_row = _tactical_hex_map.hexes[row]
		for col in range(hex_row.size()):
			var h = hex_row[col]
			var t_key = "%d,%d" % [h.q, h.r]
			var cell_data: Dictionary = {}
			if row < terrain_ids.size() and col < terrain_ids[row].size():
				cell_data = terrain_ids[row][col] if terrain_ids[row][col] is Dictionary else {"terrain": terrain_ids[row][col]}
			h.terrain = cell_data.get("terrain", HexMap.Terrain.PLAINS)
			h.elevation = cell_data.get("elevation", 0)
			h.water_depth = cell_data.get("water_depth", 0)
			h.structures = cell_data.get("structures", [])
			h.has_road = cell_data.get("has_road", false)


func _get_terrain_id_from_hex(hex_dict: Dictionary) -> String:
	var e = hex_dict.get("terrain", HexMap.Terrain.PLAINS)
	match e:
		HexMap.Terrain.PLAINS: return "clear"
		HexMap.Terrain.FOREST: return "light_woods"
		HexMap.Terrain.MOUNTAIN: return "rough"
		HexMap.Terrain.WATER: return "water"
		HexMap.Terrain.URBAN: return "paved"
		HexMap.Terrain.DESERT: return "sand"
		HexMap.Terrain.ROUGH: return "rough"
	return "clear"


# --- Reachable / Movement ---

func _update_reachable() -> void:
	if _current_unit_idx < 0 or _current_unit_idx >= player_units.size():
		_reachable_result = {}
		hex_draw.queue_redraw()
		return

	var start_pos = _unit_positions[_current_unit_idx] if _current_unit_idx < _unit_positions.size() else _tactical_hex_map.landing_zone
	var start_facing = _unit_facings[_current_unit_idx] if _current_unit_idx < _unit_facings.size() else 0
	var start_height = _unit_heights[_current_unit_idx] if _current_unit_idx < _unit_heights.size() else _tactical_hex_map.get_hex(start_pos.x, start_pos.y).get("elevation", 0)
	var pu = player_units[_current_unit_idx]

	var max_mp = pu.movement_mp
	if _mode == "run":
		max_mp = pu.run_mp
	elif _mode == "jump":
		max_mp = pu.jump_mp
	if max_mp <= 0:
		_reachable_result = {}
		hex_draw.queue_redraw()
		return

	_reachable_result = _movement_resolver.find_reachable(
		_tactical_hex_map, start_pos.x, start_pos.y, start_facing, start_height,
		max_mp, _mode, pu.tonnage)

	hex_draw.queue_redraw()


func _on_mode_changed(mode: String, toggled: bool) -> void:
	if not toggled:
		return
	_mode = mode
	mode_walk.button_pressed = mode == "walk"
	mode_run.button_pressed = mode == "run"
	mode_jump.button_pressed = mode == "jump"
	_selected_hex = Vector2i(-1, -1)
	move_button.disabled = true
	_update_reachable()


func _on_unit_selected(index: int) -> void:
	_current_unit_idx = index
	_selected_hex = Vector2i(-1, -1)
	move_button.disabled = true
	_update_reachable()


# --- Hex draw / input ---

func _on_hex_draw_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos = event.position - hex_draw.size / 2 - _camera_offset
			var hex_coord = _pixel_to_hex(local_pos)
			if hex_coord.x >= 0:
				_selected_hex = hex_coord
				_update_hex_info()
				hex_draw.queue_redraw()

		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			_panning = true
			_pan_start = event.position

		if event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
			_panning = false

		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_camera_zoom = clamp(_camera_zoom * 1.1, 0.4, 2.5)
			hex_draw.queue_redraw()

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_camera_zoom = clamp(_camera_zoom / 1.1, 0.4, 2.5)
			hex_draw.queue_redraw()

	if event is InputEventMouseMotion and _panning:
		_camera_offset += event.relative
		hex_draw.queue_redraw()


func _on_draw() -> void:
	if not _tactical_hex_map:
		return

	var draw = hex_draw
	var center = draw.size / 2 + _camera_offset

	for row in _tactical_hex_map.hexes:
		for h in row:
			var pixel = HexMap.axial_to_pixel(h.q, h.r, HEX_SIZE) + center
			var corners = HexMap.hex_corners(pixel, HEX_SIZE * _camera_zoom)

			var terrain_id = _get_terrain_id_from_hex(h)
			var color = TERRAIN_COLORS.get(terrain_id, Color(0.3, 0.3, 0.3))

			# Structure indicator
			var structures: Array = h.get("structures", [])
			if not structures.is_empty():
				color = color.lerp(Color(0.5, 0.4, 0.6), 0.15)

			draw.draw_colored_polygon(corners, color)
			draw.draw_polyline(corners, Color(0.15, 0.15, 0.18), 1.0, true)

	# Draw reachable highlights
	var reachable = _reachable_result.get("reachable_hexes", {})
	for hex_key in reachable:
		var parts = hex_key.split(",")
		var hq = int(parts[0])
		var hr = int(parts[1])
		var info = reachable[hex_key]
		var pixel = HexMap.axial_to_pixel(hq, hr, HEX_SIZE) + center
		var r_corners = HexMap.hex_corners(pixel, HEX_SIZE * _camera_zoom + 3)

		var color := Color(0.2, 0.7, 0.3, 0.25)
		if _selected_hex.x == hq and _selected_hex.y == hr:
			color = Color(1.0, 0.9, 0.3, 0.35)
		draw.draw_colored_polygon(r_corners, color)

	# Draw units
	for i in range(player_units.size()):
		var pos = _unit_positions[i] if i < _unit_positions.size() else _tactical_hex_map.landing_zone
		_draw_unit_marker(draw, center, pos.x, pos.y, Color(0.3, 0.8, 1.0),
			i == _current_unit_idx)

	for i in range(enemy_units.size()):
		var pos = Vector2i(3 + i, 3 + i)
		_draw_unit_marker(draw, center, pos.x, pos.y, Color(0.9, 0.3, 0.3), false)


func _draw_unit_marker(draw: Control, center: Vector2, q: int, r: int, color: Color, selected: bool) -> void:
	var pixel = HexMap.axial_to_pixel(q, r, HEX_SIZE) + center
	var size = HEX_SIZE * _camera_zoom * 0.28
	var top = pixel - Vector2(0, size)
	var bl = pixel + Vector2(-size * 0.7, size * 0.5)
	var br = pixel + Vector2(size * 0.7, size * 0.5)

	if selected:
		var sel_corners = HexMap.hex_corners(pixel, size * 1.5)
		draw.draw_colored_polygon(sel_corners, Color(1, 1, 0.3, 0.12))

	draw.draw_colored_polygon(PackedVector2Array([top, bl, br]), color)
	draw.draw_polyline(PackedVector2Array([top, bl, br, top]), Color(0.1, 0.15, 0.2, 0.8), 1.5, true)


func _pixel_to_hex(pos: Vector2) -> Vector2i:
	var size = HEX_SIZE * _camera_zoom
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


# --- Info / Display ---

func _update_hex_info() -> void:
	if _selected_hex.x < 0:
		hex_info_label.text = ""
		move_button.disabled = true
		return

	var hex_key = "%d,%d" % [_selected_hex.x, _selected_hex.y]
	var reachable = _reachable_result.get("reachable_hexes", {})
	var costs = _reachable_result.get("costs", {})
	var edges = _reachable_result.get("edges", [])

	var text = ""
	if reachable.has(hex_key):
		var info = reachable[hex_key]
		var cost = info.get("min_cost", INF)
		text = tr("Hex (%d, %d) — Reachable\nMP Cost: %d") % [_selected_hex.x, _selected_hex.y, cost]

		var collapse := false
		var psr_triggers: Array = []
		for e in edges:
			var to_key = e.get("to", "")
			if to_key.begins_with(hex_key):
				if e.get("collapse_warning", false):
					collapse = true
				for r in e.get("psr_risks", []):
					if r.get("trigger", "") not in psr_triggers:
						psr_triggers.append(r.trigger)

		if collapse:
			text += "\n[color=#ff4444]" + tr("COLLAPSE RISK") + "[/color]"
		if not psr_triggers.is_empty():
			text += "\n[color=#ffaa44]" + tr("PSR: %s") % ", ".join(psr_triggers) + "[/color]"

		move_button.disabled = false
	else:
		text = tr("Hex (%d, %d) — Not reachable") % [_selected_hex.x, _selected_hex.y]
		move_button.disabled = true

	hex_info_label.text = text


func _refresh_display() -> void:
	var text = ""
	text += "[b]" + tr("Player Forces:") + "[/b]\n"
	for i in range(player_units.size()):
		var u = player_units[i]
		var dmg = u.get_damaged_components().size()
		var destroyed = u.get_destroyed_components().size()
		text += "  %s (%dt)" % [u.unit_name, int(u.tonnage)]
		if dmg > 0 or destroyed > 0:
			text += " [color=#ffaa44]Dmg:%d[/color] [color=#ff4444]Des:%d[/color]" % [dmg, destroyed]
		text += "\n"

	text += "\n[b]" + tr("Enemy Forces:") + "[/b]\n"
	if _resolved:
		for u in enemy_units:
			var destroyed = u.get_destroyed_components().size()
			var total = u.components.size()
			var status = "[color=#44ff66]" + tr("Intact") + "[/color]"
			if destroyed >= total:
				status = "[color=#ff4444]" + tr("Destroyed") + "[/color]"
			elif destroyed > 0:
				status = "[color=#ffaa44]" + tr("Damaged") + "[/color]"
			text += "  %s (%dt) — %s\n" % [u.unit_name, int(u.tonnage), status]
	else:
		for u in enemy_units:
			text += "  %s (%dt)\n" % [u.unit_name, int(u.tonnage)]
	text += "\n[b]" + tr("Mode: %s") % _mode.capitalize() + "[/b]\n"

	info_label.text = text


func _on_move() -> void:
	if _current_unit_idx < 0 or _selected_hex.x < 0:
		return
	var unit = player_units[_current_unit_idx]
	var hex_key = "%d,%d" % [_selected_hex.x, _selected_hex.y]
	var reachable = _reachable_result.get("reachable_hexes", {})
	if not reachable.has(hex_key):
		return

	var costs = _reachable_result.get("costs", {})
	var came_from = _reachable_result.get("came_from", {})

	var best_cost := INF
	var best_state := ""
	for f in range(6):
		for h in range(10):
			var key = "%d,%d,%d,%d" % [_selected_hex.x, _selected_hex.y, f, h]
			if costs.has(key) and costs[key] < best_cost:
				best_cost = costs[key]
				best_state = key

	if best_state.is_empty():
		return

	var path = TacticalMovementResolver.reconstruct_path(came_from, best_state)
	if path.is_empty():
		return

	# Move unit to destination
	var last = path[path.size() - 1]
	var parts = last.split(",")
	var dest_q = int(parts[0])
	var dest_r = int(parts[1])
	var dest_f = int(parts[2])
	var dest_h = int(parts[3])

	if _current_unit_idx < _unit_positions.size():
		_unit_positions[_current_unit_idx] = Vector2i(dest_q, dest_r)
		_unit_facings[_current_unit_idx] = dest_f
		_unit_heights[_current_unit_idx] = dest_h
		_unit_current_mp[_current_unit_idx] = max(0, _unit_current_mp[_current_unit_idx] - int(best_cost))

	_selected_hex = Vector2i(-1, -1)
	move_button.disabled = true
	_update_reachable()
	_refresh_display()
	hex_draw.queue_redraw()


func _on_resolve() -> void:
	if _resolved:
		return
	_resolved = true
	resolve_button.disabled = true

	var resolver = load("res://src/tactical/CombatResolver.gd").new()
	add_child(resolver)
	_result = resolver.resolve(player_units, enemy_units, contract)
	resolver.queue_free()

	_refresh_display()

	var result_text = "\n[b]" + tr("Combat Result:") + "[/b]\n"
	if _result.get("player_victory", false):
		result_text += "[color=#44ff66]" + tr("Victory!") + "[/color]\n"
	else:
		result_text += "[color=#ff4444]" + tr("Defeat") + "[/color]\n"
	result_text += tr("Enemies destroyed: %d / %d") % [_result.get("enemies_destroyed", 0), _result.get("total_enemies", 0)] + "\n"
	result_text += tr("Player units lost: %d") % _result.get("player_units_lost", 0) + "\n"
	var salvage_val = _result.get("salvage_value", 0)
	if salvage_val > 0:
		result_text += tr("Salvage recovered: %s") % Helpers.fmt_money(salvage_val) + "\n"
	info_label.text += result_text
	return_button.text = tr("Return to Planetary Map")


func _on_return() -> void:
	if contract and _result.get("salvage_value", 0) > 0:
		EconomySystem.process_engagement(contract)
	ReputationSystem.modify_reputation(contract.issuer, 2, "Tactical engagement completed")
	closed.emit()


# Legacy serialization (kept from existing code)
func _serialize_units(units: Array[TacticalUnit]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for u in units:
		var comps: Array[Dictionary] = []
		for c in u.components:
			comps.append({
				"name": c.component_name,
				"type": c.component_type,
				"tonnage": c.tonnage,
				"slots": c.critical_slots,
				"status": c.status,
			})
		result.append({
			"name": u.unit_name,
			"chassis": u.chassis_name,
			"tonnage": u.tonnage,
			"move": u.movement_mp,
			"run": u.run_mp,
			"armor": u.total_armor_points,
			"components": comps,
		})
	return result


func _deserialize_units(data: Array[Dictionary]) -> Array[TacticalUnit]:
	var result: Array[TacticalUnit] = []
	for entry in data:
		var unit = TacticalUnit.new()
		unit.unit_name = entry.get("name", "Enemy")
		unit.chassis_name = entry.get("chassis", "")
		unit.unit_type = Enums.UnitType.MECH
		unit.tonnage = entry.get("tonnage", 20)
		unit.movement_mp = entry.get("move", 4)
		unit.run_mp = entry.get("run", 6)
		unit.total_armor_points = entry.get("armor", 50)
		unit.quality = Enums.Quality.D

		var loc = ComponentLocation.new()
		loc.location_name = "Center Torso"
		loc.armor = unit.total_armor_points
		loc.structure = int(unit.tonnage / 5)

		for cd in entry.get("components", []):
			var comp = Component.new()
			comp.component_name = cd.get("name", "")
			comp.component_type = cd.get("type", "other")
			comp.tonnage = cd.get("tonnage", 1.0)
			comp.critical_slots = cd.get("slots", 1)
			comp.location = loc
			comp.status = cd.get("status", Enums.ComponentStatus.UNDAMAGED)
			unit.components.append(comp)

		result.append(unit)
	return result


func _generate_opfor(strength: int) -> Array[TacticalUnit]:
	var result: Array[TacticalUnit] = []
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var count = strength + rng.randi_range(0, 1)
	var chassis_pool = ["Commando", "Locust", "Stinger", "Wasp", "Panther", "Assassin", "Hermes", "Vulcan"]
	var tonnage_pool = [25, 20, 20, 20, 35, 40, 30, 40]

	for i in range(count):
		var idx = rng.randi_range(0, chassis_pool.size() - 1)
		var unit = TacticalUnit.new()
		unit.unit_name = chassis_pool[idx] + " (" + tr("Enemy") + " " + str(i + 1) + ")"
		unit.chassis_name = chassis_pool[idx]
		unit.unit_type = Enums.UnitType.MECH
		unit.tonnage = tonnage_pool[idx]
		unit.movement_mp = rng.randi_range(3, 6)
		unit.run_mp = unit.movement_mp * 3 / 2
		unit.jump_mp = 0
		unit.total_armor_points = int(unit.tonnage * 3.0)
		unit.quality = Enums.Quality.D
		unit.components = _generate_opfor_components(unit.tonnage, rng)
		result.append(unit)

	return result


func _generate_opfor_components(tonnage: float, rng: RandomNumberGenerator) -> Array:
	var result: Array = []
	var loc = ComponentLocation.new()
	loc.location_name = "Center Torso"
	loc.armor = int(tonnage * 1.5)
	loc.structure = int(tonnage / 5)

	var weapons = ["Medium Laser", "Small Laser", "SRM-4", "LRM-5", "Machine Gun"]
	var weapon_count = rng.randi_range(1, 3)
	for i in range(weapon_count):
		var w_name = weapons[rng.randi_range(0, weapons.size() - 1)]
		var comp = Component.new()
		comp.component_name = w_name
		comp.component_type = "weapon"
		comp.tonnage = 1.0
		comp.critical_slots = 1
		comp.location = loc
		comp.status = Enums.ComponentStatus.UNDAMAGED
		result.append(comp)

	var engine = Component.new()
	engine.component_name = "Fusion Engine"
	engine.component_type = "engine"
	engine.tonnage = tonnage * 0.1
	engine.critical_slots = 6
	engine.location = loc
	result.append(engine)

	return result
