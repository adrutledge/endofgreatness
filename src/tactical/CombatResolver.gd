extends Node

## Auto-resolves a tactical engagement between player and enemy units.
## Uses simplified Battletech-like to-hit and damage calculations.

var _rng: RandomNumberGenerator


func resolve(player_units: Array[TacticalUnit], enemy_units: Array[TacticalUnit], contract: Contract) -> Dictionary:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

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
			var dmg = _resolve_unit_attack(unit, target, contract)
			if dmg > 0:
				total_salvage_value += _apply_damage(target, dmg, unit.unit_name, contract)

		enemy_alive = _filter_destroyed(enemy_alive)
		if enemy_alive.is_empty():
			break

		for unit in enemy_alive:
			if unit.get_destroyed_components().size() >= unit.components.size():
				continue
			if player_alive.is_empty():
				break
			var target = player_alive[_rng.randi_range(0, player_alive.size() - 1)]
			var dmg = _resolve_unit_attack(unit, target, contract)

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


func _resolve_unit_attack(attacker: TacticalUnit, target: TacticalUnit, contract: Contract) -> int:
	var total_damage := 0
	for c in attacker.components:
		if c.component_type != "weapon":
			continue
		if c.status != Enums.ComponentStatus.UNDAMAGED:
			continue
		var weapon_stats = _get_weapon_stats(c.component_name)
		if weapon_stats.is_empty():
			continue

		var gunnery = 4
		if not attacker.crew.is_empty():
			var pilot = attacker.crew[0]
			gunnery = pilot.skills.get("gunnery_mech", 4)

		var range_mod = 2
		var to_hit = gunnery + range_mod
		var roll = _rng.randi_range(2, 12)
		if roll >= to_hit:
			var dmg = weapon_stats.get("damage", 5)
			var shots = weapon_stats.get("shots_per_volley", 1)
			total_damage += dmg * shots

	return total_damage


func _apply_damage(target: TacticalUnit, damage: int, source_unit: String, contract: Contract) -> int:
	var salvage_value := 0
	var remaining = damage

	while remaining > 0 and target.components.size() > 0:
		var idx = _rng.randi_range(0, target.components.size() - 1)
		var comp = target.components[idx]

		if comp.status == Enums.ComponentStatus.DESTROYED:
			continue

		var comp_damage = mini(remaining, 5)
		remaining -= comp_damage

		if _rng.randf() < 0.3:
			comp.status = Enums.ComponentStatus.DESTROYED
			if comp.component_type == "weapon":
				var stats = _get_weapon_stats(comp.component_name)
				var value = stats.get("damage", 5) * 1000
				EconomySystem.track_enemy_loss(contract, comp.component_name, value, target.tonnage, 1, Enums.Quality.D, false, source_unit, false)
				salvage_value += value
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


func _get_weapon_stats(weapon_name: String) -> Dictionary:
	var file = FileAccess.open("res://data/config/weapon_stats.json", FileAccess.READ)
	if not file:
		return {}
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK:
		return {}
	for w in j.data.get("weapons", []):
		if w.get("name", "") == weapon_name:
			return w
	return {}
