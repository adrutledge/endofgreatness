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
var _phase_manager: PhaseManager
var _current_unit_idx: int = -1
var _selected_hex: Vector2i = Vector2i(-1, -1)
var _selected_target: String = ""
var _mode: String = "walk"
var _reachable_result: Dictionary = {}
var _camera_offset: Vector2 = Vector2(200, 80)
var _camera_zoom: float = 1.0
var _panning: bool = false
var _pan_start: Vector2 = Vector2()
var _current_actor_unit_id: String = ""
var _pending_target_hex: Vector2i = Vector2i(-1, -1)

var _unit_positions: Array[Vector2i] = []
var _unit_facings: Array[int] = []
var _unit_heights: Array[int] = []
var _unit_current_mp: Array[int] = []

var _resolved: bool = false
var _result: Dictionary = {}
var _movement_resolver: TacticalMovementResolver

@onready var hex_draw: Control = %HexDraw
@onready var info_label: RichTextLabel = %InfoLabel
@onready var hex_info_label: Label = %HexInfoLabel
@onready var title_label: Label = %TitleLabel
@onready var unit_selector: OptionButton = %UnitSelector
@onready var move_button: Button = %MoveButton
@onready var skip_button: Button = %SkipButton
@onready var resolve_button: Button = %ResolveButton
@onready var return_button: Button = %ReturnButton
@onready var mode_walk: Button = %ModeWalk
@onready var mode_run: Button = %ModeRun
@onready var mode_jump: Button = %ModeJump
@onready var phase_label: Label = %PhaseLabel
@onready var initiative_label: Label = %InitiativeLabel
@onready var end_phase_button: Button = %EndPhaseButton
@onready var weapon_panel: VBoxContainer = %WeaponPanel
@onready var weapon_selector: OptionButton = %WeaponSelector
@onready var fire_button: Button = %FireButton


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
	move_button.pressed.connect(_on_move_confirm)
	skip_button.pressed.connect(_on_skip)
	resolve_button.pressed.connect(_on_resolve)
	return_button.pressed.connect(_on_return)
	end_phase_button.pressed.connect(_on_end_phase)
	fire_button.pressed.connect(_on_fire_confirm)

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

	_start_phase_engagement()


func _start_phase_engagement() -> void:
	_phase_manager = PhaseManager.new()
	add_child(_phase_manager)

	_phase_manager.phase_changed.connect(_on_phase_changed)
	_phase_manager.initiative_determined.connect(_on_initiative_determined)
	_phase_manager.player_input_required.connect(_on_player_input_required)
	_phase_manager.movement_declared.connect(_on_movement_declared)
	_phase_manager.fire_declared.connect(_on_fire_declared)
	_phase_manager.damage_applied.connect(_on_damage_applied)
	_phase_manager.engagement_ended.connect(_on_engagement_ended)

	_phase_manager.start_engagement(_build_sides_dict())
	_refresh_display()


func _build_sides_dict() -> Dictionary:
	var player_side = {"units": []}
	for i in range(player_units.size()):
		var u = player_units[i]
		var pos = _unit_positions[i] if i < _unit_positions.size() else _tactical_hex_map.landing_zone
		player_side.units.append({
			"id": "player_%d" % i,
			"is_player": true,
			"hex_position": pos,
			"current_facing": _unit_facings[i] if i < _unit_facings.size() else 0,
			"current_height": _unit_heights[i] if i < _unit_heights.size() else 0,
			"walk_mp": u.movement_mp,
			"run_mp": u.run_mp,
			"jump_mp": u.jump_mp,
			"current_mp": u.movement_mp,
			"weapons": [{"name": "Medium Laser", "damage": 5, "heat": 3, "range_brackets": {"short": 3, "medium": 6, "long": 9}}],
			"gunnery": 4,
			"piloting": 5,
			"total_armor": u.total_armor_points,
			"is_active": true,
			"tonnage": u.tonnage,
			"unit_name": u.unit_name,
		})

	var enemy_side = {"units": []}
	for i in range(enemy_units.size()):
		var u = enemy_units[i]
		var pos = Vector2i(3 + i, 3 + i)
		enemy_side.units.append({
			"id": "enemy_%d" % i,
			"is_player": false,
			"hex_position": pos,
			"current_facing": 0,
			"current_height": 0,
			"walk_mp": u.movement_mp,
			"run_mp": u.run_mp,
			"jump_mp": u.jump_mp,
			"current_mp": u.movement_mp,
			"weapons": [{"name": "Medium Laser", "damage": 5, "heat": 3, "range_brackets": {"short": 3, "medium": 6, "long": 9}}],
			"gunnery": 4,
			"piloting": 5,
			"total_armor": u.total_armor_points,
			"is_active": true,
			"tonnage": u.tonnage,
			"unit_name": u.unit_name,
		})

	return {"player": player_side, "enemy": enemy_side}


# ---- Phase manager callbacks ----

func _on_phase_changed(phase: int, round: int) -> void:
	var phase_names = ["INITIATIVE", "MOVEMENT", "DECLARE FIRE", "RESOLVE FIRE", "DECLARE PHYSICAL", "RESOLVE PHYSICAL", "END"]
	var name = phase_names[phase] if phase >= 0 and phase < phase_names.size() else "?"
	phase_label.text = "Round %d — %s" % [round, name]

	move_button.hide()
	skip_button.hide()
	weapon_panel.hide()
	end_phase_button.disabled = phase != PhaseManager.Phase.MOVEMENT and phase != PhaseManager.Phase.DECLARE_FIRE and phase != PhaseManager.Phase.DECLARE_PHYSICAL
	_resolved = false


func _on_initiative_determined(order: Array) -> void:
	initiative_label.text = "Order: " + ", ".join(order)
	_refresh_display()


func _on_player_input_required(phase: int, unit_id: String, data: Dictionary) -> void:
	_current_actor_unit_id = unit_id
	var unit = _phase_manager.get_unit(unit_id)

	match phase:
		PhaseManager.Phase.MOVEMENT:
			# Find which player unit index this corresponds to
			var idx = _unit_idx_from_id(unit_id)
			if idx >= 0:
				_current_unit_idx = idx
				unit_selector.select(idx)
			_update_reachable_for_unit(unit)
			move_button.show()
			move_button.text = "Move Here"
			move_button.disabled = true
			skip_button.show()
			hex_info_label.text = tr("Select destination hex for %s") % unit.get("unit_name", unit_id)

		PhaseManager.Phase.DECLARE_FIRE, PhaseManager.Phase.DECLARE_PHYSICAL:
			var targets: Array = data.get("eligible_targets", [])
			weapon_panel.show()
			weapon_selector.clear()
			var weapons = unit.get("weapons", [])
			for wi in range(weapons.size()):
				var w = weapons[wi]
				weapon_selector.add_item(w.get("name", "Weapon %d" % wi))
			fire_button.disabled = true
			skip_button.show()
			hex_info_label.text = tr("Select target for %s") % unit.get("unit_name", unit_id)
			# Store eligible targets for click detection
			_eligible_targets = targets


var _eligible_targets: Array = []


func _on_movement_declared(unit_id: String, path: Array, mode: String) -> void:
	# Update position tracking for player units
	for i in range(player_units.size()):
		if "player_%d" % i == unit_id:
			if path.size() > 0:
				_unit_positions[i] = path[path.size() - 1] if path[path.size() - 1] is Vector2i else path[0]
			break
	hex_draw.queue_redraw()


func _on_fire_declared(attacker_id: String, target_id: String, weapon_idx: int) -> void:
	_refresh_display()
	hex_draw.queue_redraw()


func _on_damage_applied(target_id: String, location: String, damage: int, is_destroyed: bool) -> void:
	info_label.text = tr("[color=#ff4444]%s hit for %d damage to %s%s") % [target_id, damage, location, (" — DESTROYED" if is_destroyed else "")]
	hex_draw.queue_redraw()


func _on_engagement_ended(winner: String) -> void:
	_resolved = true
	resolve_button.hide()
	return_button.text = tr("Return to Planetary Map")
	phase_label.text = tr("Engagement Over — %s wins") % winner
	_refresh_display()


# ---- Player input handlers ----

func _on_move_confirm() -> void:
	if _pending_target_hex.x < 0:
		return
	if _phase_manager and _phase_manager.waiting_for_player:
		_phase_manager.submit_move(_current_actor_unit_id, _pending_target_hex, _mode)
		_pending_target_hex = Vector2i(-1, -1)
		move_button.hide()
		skip_button.hide()


func _on_fire_confirm() -> void:
	var wi = weapon_selector.selected
	if wi < 0 or _selected_target.is_empty():
		return
	if _phase_manager and _phase_manager.waiting_for_player:
		_phase_manager.submit_fire(_current_actor_unit_id, _selected_target, wi)
		_selected_target = ""
		weapon_panel.hide()
		skip_button.hide()


func _on_skip() -> void:
	if _phase_manager and _phase_manager.waiting_for_player:
		_phase_manager.submit_skip(_current_actor_unit_id)
		move_button.hide()
		skip_button.hide()
		weapon_panel.hide()


func _on_end_phase() -> void:
	if _phase_manager:
		_phase_manager.submit_end_phase()


# ---- Hex draw / input ----

func _on_hex_draw_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos = event.position - hex_draw.size / 2 - _camera_offset
			var hex_coord = _pixel_to_hex(local_pos)
			if hex_coord.x >= 0:
				_selected_hex = hex_coord

				if _phase_manager and _phase_manager.waiting_for_player:
					var phase = _phase_manager.current_phase
					if phase == PhaseManager.Phase.MOVEMENT:
						# Check if hex is reachable
						var hex_key = "%d,%d" % [hex_coord.x, hex_coord.y]
						var reachable = _reachable_result.get("reachable_hexes", {})
						if reachable.has(hex_key):
							_pending_target_hex = hex_coord
							move_button.disabled = false
							hex_info_label.text = tr("Move to (%d, %d) — click Move Here") % [hex_coord.x, hex_coord.y]
						else:
							_pending_target_hex = Vector2i(-1, -1)
							move_button.disabled = true

					elif phase == PhaseManager.Phase.DECLARE_FIRE or phase == PhaseManager.Phase.DECLARE_PHYSICAL:
						# Check if clicked hex contains an eligible target
						_selected_target = ""
						fire_button.disabled = true
						for tid in _eligible_targets:
							var tu = _phase_manager.get_unit(tid)
							if tu and tu.hex_position == hex_coord and tu.get("is_active", true):
								_selected_target = tid
								fire_button.disabled = false
								hex_info_label.text = tr("Target: %s — select weapon and fire") % tu.get("unit_name", tid)
								break
						if _selected_target.is_empty():
							hex_info_label.text = tr("No target at that hex")

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
		var pixel = HexMap.axial_to_pixel(hq, hr, HEX_SIZE) + center
		var r_corners = HexMap.hex_corners(pixel, HEX_SIZE * _camera_zoom + 3)
		var color := Color(0.2, 0.7, 0.3, 0.25)
		if _selected_hex.x == hq and _selected_hex.y == hr:
			color = Color(1.0, 0.9, 0.3, 0.35)
		draw.draw_colored_polygon(r_corners, color)

	# Draw units
	for i in range(player_units.size()):
		var pos = _unit_positions[i] if i < _unit_positions.size() else _tactical_hex_map.landing_zone
		_draw_unit_marker(draw, center, pos.x, pos.y, Color(0.3, 0.8, 1.0), i == _current_unit_idx)

	# Draw enemy units from phase manager if available, else from raw data
	var drawn_enemies: Array = []
	if _phase_manager:
		var e_units = _phase_manager.get_side_units("enemy")
		for u in e_units:
			if not u.get("is_active", true):
				continue
			var pos = u.get("hex_position", Vector2i.ZERO)
			_draw_unit_marker(draw, center, pos.x, pos.y, Color(0.9, 0.3, 0.3), false)
			drawn_enemies.append(u.id)
	for i in range(enemy_units.size()):
		if drawn_enemies.has("enemy_%d" % i):
			continue
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


# ---- Reachable / Movement ----

func _update_reachable_for_unit(unit: Dictionary) -> void:
	if not _tactical_hex_map:
		return
	var start_pos = unit.get("hex_position", _tactical_hex_map.landing_zone)
	var start_facing = unit.get("current_facing", 0)
	var start_height = unit.get("current_height", _tactical_hex_map.get_hex(start_pos.x, start_pos.y).get("elevation", 0))

	var max_mp = unit.get("current_mp", unit.get("walk_mp", 4))
	if max_mp <= 0:
		_reachable_result = {}
		hex_draw.queue_redraw()
		return

	_reachable_result = _movement_resolver.find_reachable(
		_tactical_hex_map, start_pos.x, start_pos.y, start_facing, start_height,
		max_mp, _mode, unit.get("tonnage", 0))
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
	if _phase_manager and _phase_manager.waiting_for_player:
		var unit = _phase_manager.get_unit(_current_actor_unit_id)
		if unit:
			_update_reachable_for_unit(unit)


func _on_unit_selected(index: int) -> void:
	_current_unit_idx = index
	_selected_hex = Vector2i(-1, -1)
	move_button.disabled = true


func _unit_idx_from_id(unit_id: String) -> int:
	if unit_id.begins_with("player_"):
		return int(unit_id.trim_prefix("player_"))
	return -1


# ---- Info / Display ----

func _refresh_display() -> void:
	var text = ""
	text += "[b]" + tr("Player Forces:") + "[/b]\n"
	var p_side = _phase_manager.get_side_units("player") if _phase_manager else []
	for u in p_side:
		var name = u.get("unit_name", u.id)
		var hp = u.get("total_armor", 0)
		var active = u.get("is_active", true)
		var status = "" if active else " [color=#ff4444]DESTROYED[/color]"
		text += "  %s (%d HP)%s\n" % [name, hp, status]

	text += "\n[b]" + tr("Enemy Forces:") + "[/b]\n"
	var e_side = _phase_manager.get_side_units("enemy") if _phase_manager else []
	for u in e_side:
		var name = u.get("unit_name", u.id)
		var hp = u.get("total_armor", 0)
		var active = u.get("is_active", true)
		var status = "" if active else " [color=#ff4444]DESTROYED[/color]"
		text += "  %s (%d HP)%s\n" % [name, hp, status]

	info_label.text = text


# ---- Combat resolution (auto-resolve fallback) ----

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

	# Collect destroyed player units
	var destroyed: Array[String] = []
	for u in player_units:
		if u.total_armor_points <= 0:
			destroyed.append(u.unit_name)
	_result["destroyed_player_units"] = destroyed

	info_label.text += "\n[b]" + tr("Combat Results:") + "[/b]\n"
	info_label.text += tr("Enemies destroyed: %d / %d") % [_result.get("enemies_destroyed", 0), _result.get("total_enemies", 0)] + "\n"
	info_label.text += tr("Player units lost: %d") % _result.get("player_units_lost", 0) + "\n"
	var salvage_val = _result.get("salvage_value", 0)
	if salvage_val > 0:
		info_label.text += tr("Salvage recovered: %s") % Helpers.fmt_money(salvage_val) + "\n"
	return_button.text = tr("Return to Planetary Map")


func _on_return() -> void:
	var engagement_value = _result.get("salvage_value", 0)
	if contract and engagement_value > 0:
		EconomySystem.process_engagement(contract, engagement_value)
	ReputationSystem.modify_reputation(contract.issuer, 2, "Tactical engagement completed")
	closed.emit()


func _get_result_copy() -> Dictionary:
	return _result.duplicate()


# ---- Helpers ----

func _build_tactical_hex_map() -> void:
	var map_w = _hex_data.get("map_width", 16)
	var map_h = _hex_data.get("map_height", 16)
	_tactical_hex_map = HexMap.new(map_w, map_h)

	var terrain_ids = _hex_data.get("terrain_grid", [])
	for row in range(_tactical_hex_map.hexes.size()):
		var hex_row = _tactical_hex_map.hexes[row]
		for col in range(hex_row.size()):
			var h = hex_row[col]
			var cell_data: Dictionary = {}
			if row < terrain_ids.size() and col < terrain_ids[row].size():
				var raw = terrain_ids[row][col]
				cell_data = raw if raw is Dictionary else {"terrain": raw}
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
