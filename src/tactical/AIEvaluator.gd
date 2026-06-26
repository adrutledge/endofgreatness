class_name AIEvaluator
extends Node

## Evaluates tactical actions for AI-controlled units.
##
## Per-engagement instance. Uses the full evaluation pipeline:
## threat score, position advantage, heat budget, ammo budget,
## personality weights, and skill-tier depth.
##
## Call evaluate_unit(unit, game_state) each phase to get
## recommended move and fire declarations.

var combat_resolver: CombatResolver
var psr_resolver: PSRResolver
var los_resolver: LOSResolver
var movement_resolver: TacticalMovementResolver
var personalities: Dictionary = {}
var _personalities_loaded: bool = false


func _ready() -> void:
	_load_personalities()
	movement_resolver = TacticalMovementResolver.new()


func _load_personalities() -> void:
	var file = FileAccess.open("res://data/ai/personalities.json", FileAccess.READ)
	if not file:
		return
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK:
		return
	for p in j.data.get("personalities", []):
		personalities[p.get("id", "")] = p
	_personalities_loaded = true


## Gets the personality for a unit, falling back to faction default or balanced_line.
func get_personality(unit) -> Dictionary:
	var pid = unit.get("personality_id", "balanced_line")
	var p = personalities.get(pid, personalities.get("balanced_line", {}))
	return p


## Main evaluation entry point. Returns Dictionary with:
##   move_to: Vector2i recommended destination hex
##   fire_at: Dictionary {target_id, weapon_idx} or null
##   score: float total evaluation score
func evaluate_unit(unit, game_state: Dictionary) -> Dictionary:
	assert(unit != null, "AIEvaluator: unit is null")
	assert(game_state.has("enemies"), "AIEvaluator: game_state missing 'enemies'")
	if unit == null or not game_state.has("enemies"):
		return {"type": "none", "score": 0.0}
	var personality = get_personality(unit)
	var pilot_skill = personality.get("pilot_skill", 3)
	var command_skill = personality.get("command_skill", 3)

	var candidates = _enumerate_candidates(unit, game_state)
	var best: Dictionary = {}
	var best_score = -INF

	for candidate in candidates:
		var score = _score_candidate(unit, candidate, game_state, personality)
		if score > best_score:
			best_score = score
			best = candidate
			best["score"] = score

	return best


## Enumerates all candidate hexes (movement) and target-weapon pairs (fire).
func _enumerate_candidates(unit, game_state: Dictionary) -> Array:
	var candidates: Array = []

	# Movement candidates: reachable hexes within max MP
	var max_mp = unit.get("walk_mp", 4)
	var origin = unit.get("hex_position", Vector2i.ZERO)
	var reachable = _bfs_reachable(origin, max_mp, game_state.get("terrain", {}))
	for hex_pos in reachable:
		candidates.append({
			"type": "move",
			"hex": hex_pos,
			"weapon_idx": -1,
			"target_id": ""
		})

	# Fire candidates: each weapon against each visible enemy
	var enemies = game_state.get("enemies", [])
	for weapon_idx in range(unit.get("weapons", []).size()):
		var weapon = unit.weapons[weapon_idx]
		for enemy in enemies:
			if los_resolver.resolve(origin, 2, enemy.hex_position, 2,
					game_state.get("terrain_heights", {})).get("los") != "blocked":
				candidates.append({
					"type": "fire",
					"hex": origin,
					"weapon_idx": weapon_idx,
					"target_id": enemy.get("id", ""),
					"enemy": enemy,
					"weapon": weapon
				})

	return candidates


## Scores a single candidate action using the full evaluation pipeline.
func _score_candidate(unit, candidate: Dictionary, game_state: Dictionary,
		personality: Dictionary) -> float:
	var score = 0.0

	match candidate.get("type", ""):
		"move":
			score = _score_move(unit, candidate, game_state, personality)
		"fire":
			score = _score_fire(unit, candidate, game_state, personality)

	return score


## Scores a movement candidate based on position advantage and personality weights.
func _score_move(unit, candidate: Dictionary, game_state: Dictionary,
		personality: Dictionary) -> float:
	var hex_pos = candidate.get("hex", Vector2i.ZERO)
	var score = 0.0

	# Position advantage: sum(TN to enemies) - sum(enemy TN from here)
	var enemies = game_state.get("enemies", [])
	var my_tn_sum = 0
	var enemy_tn_sum = 0

	for enemy in enemies:
		var range_hexes = _hex_distance(hex_pos, enemy.get("hex_position", Vector2i.ZERO))
		var los = los_resolver.resolve(hex_pos, 2, enemy.hex_position, 2,
				game_state.get("terrain_heights", {}))
		if los.get("los") == "blocked":
			continue

		var tn_to_enemy = combat_resolver.calculate_tn(
			unit.get("gunnery", 4), 0, 0, 0, _range_mod_for_distance(range_hexes))
		my_tn_sum += max(0, 13 - tn_to_enemy)

		var enemy_tn = combat_resolver.calculate_tn(
			enemy.get("gunnery", 4), enemy.get("amm", 0), unit.get("tmm", 0), 0, 0)
		enemy_tn_sum += max(0, 13 - enemy_tn)

	var advantage = my_tn_sum - enemy_tn_sum
	score += advantage * 10.0

	# Cover preference
	var terrain_h = game_state.get("terrain_heights", {}).get("%d,%d" % [hex_pos.x, hex_pos.y], 0)
	if terrain_h > 0:
		score += personality.get("cover_preference", 0.5) * 20.0

	# Flank preference
	var flank_bonus = _is_flanking(hex_pos, unit, enemies)
	if flank_bonus:
		score += personality.get("flank_preference", 0.5) * 15.0

	# Aggression: prefer forward positions
	var forward_dist = _distance_to_enemy(hex_pos, enemies)
	var aggression = personality.get("aggression", 1)
	score += (10.0 - forward_dist) * aggression * 2.0

	# Terrain affinity
	var terrain_type = _terrain_at(hex_pos, game_state)
	var affinity = personality.get("terrain_affinity", {}).get(terrain_type, 1.0)
	score += (affinity - 1.0) * 10.0

	# Strategic depth (lookahead) — command_skill 4+ enabled
	var cmd_skill = personality.get("command_skill", 3)
	var strategic_depth = 2 if cmd_skill >= 5 else (1 if cmd_skill >= 4 else 0)
	if strategic_depth > 0:
		var future_advantage = _estimate_next_turn_advantage(unit, hex_pos, game_state,
				strategic_depth)
		score += future_advantage * 0.5

	return score


## Scores a fire candidate based on threat assessment and personality weights.
func _score_fire(unit, candidate: Dictionary, game_state: Dictionary,
		personality: Dictionary) -> float:
	var enemy = candidate.get("enemy", {})
	var weapon = candidate.get("weapon", {})
	var hex_pos = candidate.get("hex", Vector2i.ZERO)
	var range_hexes = _hex_distance(hex_pos, enemy.get("hex_position", Vector2i.ZERO))

	var tn = combat_resolver.calculate_tn(
		unit.get("gunnery", 4),
		unit.get("amm", 0),
		enemy.get("tmm", 0),
		enemy.get("other_mods", 0),
		_range_mod_for_distance(range_hexes)
	)

	var hit_prob = max(0.0, float(13 - tn) / 11.0)
	var damage = weapon.get("damage", 0) * hit_prob
	var heat = weapon.get("heat", 0)
	var kill_potential = _kill_potential(enemy, damage)
	var range_factor = _range_factor(weapon, range_hexes)

	# Base threat score
	var threat = damage * kill_potential * range_factor

	# Physical threat: bonus for adjacent melee-capable enemies
	var is_adjacent = _hex_distance(hex_pos, enemy.get("hex_position", Vector2i.ZERO)) == 1
	if is_adjacent and weapon.get("type", "") == "melee":
		threat *= 1.5

	# Focus fire weight
	var focus = personality.get("focus_fire_weight", 1.0)
	if _is_targeted_by_allies(enemy, game_state):
		threat *= focus

	# Heat budget check
	var total_heat = unit.get("current_heat", 0) + heat
	var heat_threshold = personality.get("heat_threshold", 0.6) * 30.0
	if total_heat > heat_threshold:
		# Drop by damage-per-heat ratio
		var dph = (damage / max(heat, 1)) * (13 - tn)
		threat *= min(1.0, dph / 5.0)

	# Weapon affinity
	var wtype = weapon.get("type", "energy")
	var affinity = personality.get("weapon_affinity", {}).get(wtype, 1.0)
	threat *= affinity

	return threat


## Strategy depth: estimate advantage from a candidate hex one or two turns ahead.
func _estimate_next_turn_advantage(unit, candidate_hex: Vector2i,
		game_state: Dictionary, depth: int) -> float:
	var advantage: float = 0.0

	# Simplified: evaluate position advantage from candidate hex
	var enemies = game_state.get("enemies", [])
	var my_tn = 0
	var enemy_tn = 0

	for enemy in enemies:
		var range_h = _hex_distance(candidate_hex, enemy.get("hex_position", Vector2i.ZERO))
		var los = los_resolver.resolve(candidate_hex, 2, enemy.hex_position, 2,
				game_state.get("terrain_heights", {}))
		if los.get("los") == "blocked":
			continue
		my_tn += max(0, 13 - _range_mod_for_distance(range_h))
		enemy_tn += max(0, 13 - combat_resolver.calculate_tn(
			enemy.get("gunnery", 4), 0, 0, 0, 0))

	advantage = (my_tn - enemy_tn) * 5.0

	# Check for flank setup (candidate places unit adjacent to enemy rear arc)
	for enemy in enemies:
		if _is_rear_arc(candidate_hex, enemy):
			advantage += 20.0

	return advantage


func _bfs_reachable(origin: Vector2i, max_mp: int, terrain: Dictionary) -> Array:
	var hex_map = terrain.get("hex_map", null)
	if hex_map == null:
		return []
	var result = movement_resolver.find_reachable(
		hex_map, origin.x, origin.y, 0, 0, max_mp, "walk", 0.0)
	var reachable: Array = []
	for hex_key in result.get("reachable_hexes", {}):
		var parts = hex_key.split(",")
		reachable.append(Vector2i(int(parts[0]), int(parts[1])))
	return reachable


func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y), abs(-a.x - a.y + b.x + b.y))


func _range_mod_for_distance(hexes: int) -> int:
	if hexes <= 3: return 0
	if hexes <= 6: return 2
	if hexes <= 9: return 4
	return 6


func _range_factor(weapon: Dictionary, distance: int) -> float:
	var bracket = weapon.get("range_brackets", {})
	if distance <= bracket.get("short", 3): return 1.0
	if distance <= bracket.get("medium", 6): return 0.8
	if distance <= bracket.get("long", 9): return 0.5
	return 0.2


func _kill_potential(enemy, damage: float) -> float:
	var armor = enemy.get("total_armor", 100)
	if armor <= 0:
		return 2.0
	return min(2.0, damage / armor)


func _is_flanking(hex: Vector2i, unit, enemies: Array) -> bool:
	for enemy in enemies:
		if _is_rear_arc(hex, enemy):
			return true
	return false


func _is_rear_arc(hex: Vector2i, enemy) -> bool:
	return false  # stub: facing calculation pending


func _distance_to_enemy(hex: Vector2i, enemies: Array) -> float:
	var min_dist = INF
	for enemy in enemies:
		var d = _hex_distance(hex, enemy.get("hex_position", Vector2i.ZERO))
		if d < min_dist:
			min_dist = d
	return min_dist


func _terrain_at(hex: Vector2i, game_state: Dictionary) -> String:
	var key = "%d,%d" % [hex.x, hex.y]
	return game_state.get("terrain_types", {}).get(key, "open")


func _is_targeted_by_allies(enemy, game_state: Dictionary) -> bool:
	return false  # stub: would check declared fire declarations
