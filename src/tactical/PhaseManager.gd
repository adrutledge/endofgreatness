class_name PhaseManager
extends Node

## Multi-sided tactical combat phase controller.
##
## Owns the engagement state and cycles through phases: INITIATIVE, MOVEMENT,
## DECLARE_FIRE, RESOLVE_FIRE, DECLARE_PHYSICAL, RESOLVE_PHYSICAL, END.
##
## Activation uses the 2:1 rule: each cycle the side with the fewest remaining
## unactivated units sets the baseline (1 activation per cycle). Any side with
## more than 2× the baseline activates 2 per cycle instead of 1.
##
## AI units are handled automatically. Player units await input via signals.

signal phase_changed(phase: int, round: int)
signal initiative_determined(order: Array)  # Array[String] side IDs in activation order
signal player_input_required(phase: int, unit_id: String, data: Dictionary)
signal movement_declared(unit_id: String, path: Array, mode: String)
signal fire_declared(attacker_id: String, target_id: String, weapon_idx: int)
signal damage_applied(target_id: String, location: String, damage: int, is_destroyed: bool)
signal crit_resolved(target_id: String, location: String, effect: String)
signal engagement_ended(winner: String)  # side ID or "draw"

enum Phase {
	INITIATIVE,
	MOVEMENT,
	DECLARE_FIRE,
	RESOLVE_FIRE,
	DECLARE_PHYSICAL,
	RESOLVE_PHYSICAL,
	END,
}

var current_phase: int = Phase.INITIATIVE
var current_round: int = 0
var is_active: bool = false
var waiting_for_player: bool = false

var initiative_order: Array[String] = []  # side IDs, ascending by initiative roll
var side_queues: Dictionary = {}  # side_id → {units: Array[Dictionary], remaining: int, unacted: Array}
var declarations: Array[Dictionary] = []

var combat_resolver: CombatResolver
var psr_resolver: PSRResolver
var los_resolver: LOSResolver
var ai_evaluator: AIEvaluator

var _side_ids: Array[String] = []
var _unit_map: Dictionary = {}  # unit_id → Dictionary


func _ready() -> void:
	combat_resolver = CombatResolver.new()
	psr_resolver = PSRResolver.new()
	los_resolver = LOSResolver.new()
	ai_evaluator = AIEvaluator.new()
	add_child(combat_resolver)
	add_child(psr_resolver)
	add_child(los_resolver)
	add_child(ai_evaluator)


func start_engagement(sides: Dictionary) -> void:
	## sides: {side_id: {units: [Dictionary]}}
	## Each unit dict: {id, is_player, hex_position, current_facing, current_height,
	##                  walk_mp, run_mp, jump_mp, weapons, gunnery, piloting,
	##                  total_armor, is_active, side, tonnage}
	_side_ids.clear()
	side_queues.clear()
	_unit_map.clear()
	initiative_order.clear()
	declarations.clear()
	current_round = 0
	current_phase = Phase.INITIATIVE

	for side_id in sides:
		_side_ids.append(side_id)
		var unit_list: Array = sides[side_id].get("units", [])
		for u in unit_list:
			u.side = side_id
			_unit_map[u.id] = u
		side_queues[side_id] = {"units": unit_list, "remaining": unit_list.size(), "unacted": unit_list.duplicate()}

	is_active = true
	advance_phase()


func advance_phase() -> void:
	if not is_active:
		return

	match current_phase:
		Phase.INITIATIVE:
			_resolve_initiative()
			current_phase = Phase.MOVEMENT
		Phase.MOVEMENT:
			declarations.clear()
			_reset_unacted()
			await _run_activation_cycle()
			current_phase = Phase.DECLARE_FIRE
		Phase.DECLARE_FIRE:
			declarations.clear()
			_reset_unacted()
			await _run_activation_cycle()
			current_phase = Phase.RESOLVE_FIRE
		Phase.RESOLVE_FIRE:
			_resolve_declarations("fire")
			current_phase = Phase.DECLARE_PHYSICAL
		Phase.DECLARE_PHYSICAL:
			declarations.clear()
			_reset_unacted()
			await _run_activation_cycle()
			current_phase = Phase.RESOLVE_PHYSICAL
		Phase.RESOLVE_PHYSICAL:
			_resolve_declarations("physical")
			current_phase = Phase.END
		Phase.END:
			_end_round()

	phase_changed.emit(current_phase, current_round)


func _resolve_initiative() -> void:
	current_round += 1
	if los_resolver:
		los_resolver.clear_cache()

	var rolls: Dictionary = {}
	for side_id in _side_ids:
		var roll = randi() % 6 + randi() % 6 + 2 + _get_initiative_bonus(side_id)
		rolls[side_id] = roll

	# Sort ascending — lowest roll declares first
	var sorted = _side_ids.duplicate()
	sorted.sort_custom(func(a, b): return rolls[a] < rolls[b])
	initiative_order = sorted

	initiative_determined.emit(initiative_order)
	Helpers.debug_print("PhaseManager",  "Initiative order: %s" % str(initiative_order))


func _get_initiative_bonus(side_id: String) -> int:
	return 0  # Future: commander skill bonuses, force composition bonuses


func _smallest_remaining_count() -> int:
	var smallest := 999999
	for side_id in _side_ids:
		var r = side_queues[side_id].remaining
		if r > 0 and r < smallest:
			smallest = r
	return smallest if smallest < 999999 else 0


func _any_remaining() -> bool:
	for side_id in _side_ids:
		if side_queues[side_id].remaining > 0:
			return true
	return false


func _reset_unacted() -> void:
	for side_id in _side_ids:
		var queue = side_queues[side_id]
		queue.unacted = queue.units.duplicate()
		queue.remaining = queue.units.size()
		# Filter out dead units
		queue.units = queue.units.filter(func(u): return u.get("is_active", true))
		queue.unacted = queue.units.duplicate()
		queue.remaining = queue.units.size()


func _run_activation_cycle() -> void:
	while _any_remaining():
		var baseline = _smallest_remaining_count()
		for side_id in initiative_order:
			if side_queues[side_id].remaining == 0:
				continue
			var count = 2 if side_queues[side_id].remaining > 2 * baseline else 1
			for _i in range(count):
				if side_queues[side_id].remaining == 0:
					break
				await _activate_next(side_id)
	# Wait for any PSR resolution animations, then advance
	await get_tree().process_frame


func _activate_next(side_id: String) -> void:
	var queue = side_queues[side_id]
	if queue.unacted.is_empty():
		return

	var unit = queue.unacted.pop_front()
	queue.remaining -= 1

	if unit.get("is_player", false):
		waiting_for_player = true
		var data := {"unit": unit, "eligible_targets": _get_eligible_targets(side_id)}
		player_input_required.emit(current_phase, unit.id, data)
		await player_input_received
		waiting_for_player = false
	else:
		_run_ai_activation(unit, side_id)


func _run_ai_activation(unit: Dictionary, side_id: String) -> void:
	var game_state = _build_game_state(side_id)
	var result = ai_evaluator.evaluate_unit(unit, game_state)

	match current_phase:
		Phase.MOVEMENT:
			var hex = result.get("hex", unit.hex_position)
			var mode = result.get("movement_mode", "walk")
			_apply_move(unit, hex, mode)
		Phase.DECLARE_FIRE, Phase.DECLARE_PHYSICAL:
			if result.get("type") == "fire":
				var target_id = result.get("target_id", "")
				var weapon_idx = result.get("weapon_idx", -1)
				declarations.append({
					"attacker_id": unit.id,
					"target_id": target_id,
					"weapon_idx": weapon_idx,
					"phase": current_phase,
				})
				fire_declared.emit(unit.id, target_id, weapon_idx)


# ---- Player input handlers ----

signal player_input_received

var _pending_move: Dictionary = {}
var _pending_fire: Dictionary = {}


func submit_move(unit_id: String, target_hex: Vector2i, mode: String) -> void:
	if not waiting_for_player:
		return
	var unit = _unit_map.get(unit_id)
	if not unit:
		return
	_apply_move(unit, target_hex, mode)


func submit_fire(unit_id: String, target_id: String, weapon_idx: int) -> void:
	if not waiting_for_player:
		return
	var unit = _unit_map.get(unit_id)
	if not unit:
		return
	declarations.append({
		"attacker_id": unit_id,
		"target_id": target_id,
		"weapon_idx": weapon_idx,
		"phase": current_phase,
	})
	fire_declared.emit(unit_id, target_id, weapon_idx)
	player_input_received.emit()


func submit_skip(unit_id: String) -> void:
	if not waiting_for_player:
		return
	player_input_received.emit()


func submit_end_phase() -> void:
	if waiting_for_player or not _any_remaining():
		return
	# Forfeit all remaining unacted units — skip to next phase
	for side_id in _side_ids:
		side_queues[side_id].unacted.clear()
		side_queues[side_id].remaining = 0
	advance_phase()


# ---- Move application ----

func _apply_move(unit: Dictionary, target_hex: Vector2i, mode: String) -> void:
	var path: Array = [target_hex]
	var old_hex = unit.hex_position
	unit.hex_position = target_hex

	# Deduct MP (simplified: cost = hex distance for now)
	var cost = max(1, old_hex.distance_to(target_hex))
	unit.current_mp = max(0, unit.get("current_mp", unit.walk_mp) - int(cost))

	movement_declared.emit(unit.id, path, mode)
	player_input_received.emit()


# ---- Fire resolution ----

func _resolve_declarations(phase_type: String) -> void:
	for dec in declarations:
		if dec.get("phase_owner", current_phase) != current_phase:
			continue
		var attacker = _unit_map.get(dec.attacker_id)
		var target = _unit_map.get(dec.target_id)
		if not attacker or not target or not target.get("is_active", true):
			continue
		if not attacker.get("is_active", true):
			continue

		var weapon_idx = dec.weapon_idx
		var weapons = attacker.get("weapons", [])
		if weapon_idx < 0 or weapon_idx >= weapons.size():
			continue
		var weapon = weapons[weapon_idx]

		var range_hexes = attacker.hex_position.distance_to(target.hex_position)
		var result = combat_resolver.resolve_attack(
			attacker, target, weapon, int(range_hexes),
			attacker.get("last_tmm", 0), target.get("last_tmm", 0), 0
		)

		if result.get("hit", false):
			var dmg = result.get("damage", 0)
			var location = result.get("location", "ct")
			var is_destroyed = _apply_damage(target, location, dmg)
			damage_applied.emit(target.id, location, dmg, is_destroyed)
			if is_destroyed:
				_remove_unit(target.side, target.id)

	await get_tree().process_frame


func _apply_damage(unit: Dictionary, location: String, damage: int) -> bool:
	unit.total_armor = max(0, unit.get("total_armor", 0) - damage)
	if unit.total_armor <= 0:
		unit.is_active = false
		return true
	return false


func _remove_unit(side_id: String, unit_id: String) -> void:
	var queue = side_queues[side_id]
	queue.units = queue.units.filter(func(u): return u.id != unit_id)
	queue.unacted = queue.unacted.filter(func(u): return u.id != unit_id)
	queue.remaining = queue.units.size()


# ---- End round ----

func _end_round() -> void:
	current_phase = Phase.INITIATIVE
	var active_side_count := 0
	var last_active_side := ""
	for side_id in _side_ids:
		var alive = false
		for u in side_queues[side_id].units:
			if u.get("is_active", true):
				alive = true
				break
		if alive:
			active_side_count += 1
			last_active_side = side_id

	if active_side_count <= 1:
		engagement_ended.emit(last_active_side if active_side_count == 1 else "draw")
		is_active = false
	else:
		advance_phase()


# ---- Helpers ----

func _get_eligible_targets(side_id: String) -> Array[String]:
	var targets: Array[String] = []
	for other in _side_ids:
		if other == side_id:
			continue
		var queue = side_queues[other]
		for u in queue.units:
			if u.get("is_active", true):
				targets.append(u.id)
	return targets


func _build_game_state(side_id: String) -> Dictionary:
	return {
		"enemies": _get_enemies_for(side_id),
		"terrain": {},
		"terrain_heights": {},
		"terrain_types": {},
		"hex_map": null,
	}


func _get_enemies_for(side_id: String) -> Array:
	var enemies: Array = []
	for other in _side_ids:
		if other == side_id:
			continue
		for u in side_queues[other].units:
			if u.get("is_active", true):
				enemies.append(u)
	return enemies


func get_unit(unit_id: String) -> Dictionary:
	return _unit_map.get(unit_id, {})


func get_side_units(side_id: String) -> Array:
	return side_queues.get(side_id, {}).get("units", [])


func get_active_sides() -> Array[String]:
	var result: Array[String] = []
	for side_id in _side_ids:
		for u in side_queues[side_id].units:
			if u.get("is_active", true):
				result.append(side_id)
				break
	return result
