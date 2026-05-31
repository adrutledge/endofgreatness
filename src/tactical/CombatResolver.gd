extends Node

## Auto-resolves a tactical engagement between player and enemy units.
## Uses simplified Battletech-like to-hit and damage calculations.

var _rng: RandomNumberGenerator
var _cluster_table: Dictionary = {}


func resolve(player_units: Array[TacticalUnit], enemy_units: Array[TacticalUnit], contract: Contract) -> Dictionary:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_load_cluster_table()

	var player_alive: Array[TacticalUnit] = player_units.duplicate()
	var enemy_alive: Array[TacticalUnit] = enemy_units.duplicate()
	var enemies_destroyed := 0
	var player_lost := 0
	var total_salvage_value := 0
	var max_turns := 20

	for turn in range(max_turns):
		if enemy_alive.is_empty():
			break

		for unit in player_alive:
			if unit.get_destroyed_components().size() >= unit.components.size():
				continue
			if enemy_alive.is_empty():
				break
			var target = enemy_alive[_rng.randi_range(0, enemy_alive.size() - 1)]
			total_salvage_value += _resolve_unit_attack(unit, target, contract)

		enemy_alive = _filter_destroyed(enemy_alive)
		if enemy_alive.is_empty():
			break

		for unit in enemy_alive:
			if unit.get_destroyed_components().size() >= unit.components.size():
				continue
			if player_alive.is_empty():
				break
			var target = player_alive[_rng.randi_range(0, player_alive.size() - 1)]
			_resolve_unit_attack(unit, target, contract)

		player_alive = _filter_destroyed(player_alive)

	enemies_destroyed = enemy_units.size() - enemy_alive.size()
	player_lost = player_units.size() - player_alive.size()

	return {
		"player_victory": enemy_alive.is_empty(),
		"enemies_destroyed": enemies_destroyed,
		"total_enemies": enemy_units.size(),
		"player_units_lost": player_lost,
		"salvage_value": total_salvage_value,
	}


func _load_cluster_table() -> void:
	var file = FileAccess.open("res://data/rules/cluster_hits.json", FileAccess.READ)
	if not file:
		return
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK:
		return
	_cluster_table = j.data.get("table", {})


func _resolve_unit_attack(attacker: TacticalUnit, target: TacticalUnit, contract: Contract) -> int:
	var total_salvage_value := 0
	for c in attacker.components:
		if c.component_type != "weapon":
			continue
		if c.status != Enums.ComponentStatus.UNDAMAGED:
			continue
		var def = DataManager.component_defs.get(c.component_name, {})
		if def.is_empty():
			continue

		var gunnery = 4
		if not attacker.crew.is_empty():
			var pilot = attacker.crew[0]
			gunnery = pilot.skills.get("gunnery_mech", 4)

		var range_mod = 2
		var to_hit = gunnery + range_mod
		var roll = _rng.randi_range(2, 12)
		if roll < to_hit:
			continue

		var is_cluster = def.get("cluster_weapon", false)
		var dmg_per_hit = def.get("damage", 5)
		var shots = def.get("shots_per_volley", 1)

		if is_cluster:
			var hits = _roll_cluster_hits(shots)
			for i in range(hits):
				total_salvage_value += _apply_damage(target, dmg_per_hit, c.component_name, contract)
		else:
			total_salvage_value += _apply_damage(target, dmg_per_hit, c.component_name, contract)

	return total_salvage_value


func _roll_cluster_hits(shots: int) -> int:
	var roll = _rng.randi_range(2, 12)
	var key = str(shots)
	if _cluster_table.has(key):
		var row = _cluster_table[key]
		var idx = roll - 2
		if idx >= 0 and idx < row.size():
			return row[idx]

	var near_key = ""
	for k in _cluster_table.keys():
		if int(k) >= shots:
			near_key = k
			break
	if near_key.is_empty():
		var max_k = ""
		for k in _cluster_table.keys():
			if max_k.is_empty() or int(k) > int(max_k):
				max_k = k
		near_key = max_k
	if near_key.is_empty():
		return shots
	var row = _cluster_table[near_key]
	var idx = roll - 2
	if idx >= 0 and idx < row.size():
		return mini(row[idx], shots)
	return shots


func _apply_damage(target: TacticalUnit, damage: int, source_weapon: String, contract: Contract) -> int:
	var salvage_value := 0
	if target.components.is_empty():
		return 0
	var idx = _rng.randi_range(0, target.components.size() - 1)
	var comp = target.components[idx]

	if comp.status == Enums.ComponentStatus.DESTROYED:
		return 0

	if _rng.randf() < 0.3:
		comp.status = Enums.ComponentStatus.DESTROYED
		if comp.component_type == "weapon":
			var def = DataManager.component_defs.get(comp.component_name, {})
			var value = def.get("cost", 1000) / 2
			EconomySystem.track_enemy_loss(contract, comp.component_name, value, target.tonnage, 1, Enums.Quality.D, false, source_weapon, false)
			salvage_value = value
	else:
		comp.status = Enums.ComponentStatus.DAMAGED

	return salvage_value


func _filter_destroyed(units: Array[TacticalUnit]) -> Array[TacticalUnit]:
	var result: Array[TacticalUnit] = []
	for u in units:
		var destroyed = u.get_destroyed_components().size()
		if destroyed < u.components.size():
			result.append(u)
	return result
