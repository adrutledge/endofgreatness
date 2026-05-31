extends Node

## Auto-resolves a tactical engagement between player and enemy units.
## All combat rules are data-driven from data/unit_types/ and data/rules/.

var _rng: RandomNumberGenerator
var _cluster_table: Dictionary = {}
var _config: Dictionary = {}
var _unit_types: Dictionary = {}


func _load_config() -> void:
	var file = FileAccess.open("res://data/rules/combat_config.json", FileAccess.READ)
	if not file:
		return
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK:
		return
	_config = j.data


func _load_cluster_table() -> void:
	var file = FileAccess.open("res://data/rules/cluster_hits.json", FileAccess.READ)
	if not file:
		return
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK:
		return
	_cluster_table = j.data.get("table", {})


func _load_unit_types() -> void:
	var dir = DirAccess.open("res://data/unit_types")
	if not dir:
		return
	dir.list_dir_begin()
	var fn = dir.get_next()
	while fn != "":
		if fn.ends_with(".json"):
			var file = FileAccess.open("res://data/unit_types/" + fn, FileAccess.READ)
			if file:
				var j = JSON.new()
				if j.parse(file.get_as_text()) == OK:
					var data = j.data
					_unit_types[data.get("code", "")] = data
		fn = dir.get_next()


func _get_unit_type_code(unit: TacticalUnit) -> String:
	match unit.unit_type:
		Enums.UnitType.MECH:
			return "MECH"
		Enums.UnitType.VEHICLE:
			return "VEHICLE"
		_:
			return "MECH"


func resolve(player_units: Array[TacticalUnit], enemy_units: Array[TacticalUnit], contract: Contract) -> Dictionary:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_load_config()
	_load_cluster_table()
	_load_unit_types()

	var player_alive: Array[TacticalUnit] = player_units.duplicate()
	var enemy_alive: Array[TacticalUnit] = enemy_units.duplicate()
	var enemies_destroyed := 0
	var player_lost := 0
	var total_salvage_value := 0
	var max_turns = _config.get("max_turns", 20)

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


func _resolve_unit_attack(attacker: TacticalUnit, target: TacticalUnit, contract: Contract) -> int:
	var total_salvage_value := 0
	for c in attacker.components:
		if c.component_type != "weapon":
			continue
		if c.status != Enums.ComponentStatus.UNDAMAGED:
			continue
		var def = DataManager.component_defs.get(c.component_name, {})
		if def.is_empty() or def.get("underwater_only", false):
			continue

		var gunnery = _config.get("default_gunnery", 4)
		if not attacker.crew.is_empty():
			var pilot = attacker.crew[0]
			gunnery = pilot.skills.get("gunnery_mech", gunnery)

		var range_mods = _config.get("range_modifiers", {"medium": 2})
		var range_mod = range_mods.get("medium", 2)
		var to_hit = gunnery + range_mod
		var roll = _rng.randi_range(2, 12)
		if roll < to_hit:
			continue

		var is_cluster = def.get("cluster_weapon", false)
		var dmg_per_hit = def.get("damage", 5)
		var shots = def.get("shots_per_volley", 1)

		if is_cluster:
			var dmg_per_shot = def.get("damage_per_shot", dmg_per_hit)
			var cluster_size = def.get("cluster_size", 1)
			var hits = _roll_cluster_hits(shots)
			var remaining = hits
			while remaining > 0:
				var cluster = mini(cluster_size, remaining)
				total_salvage_value += _apply_damage(target, dmg_per_shot * cluster, c.component_name, contract)
				remaining -= cluster
		else:
			total_salvage_value += _apply_damage(target, dmg_per_hit, c.component_name, contract)

	return total_salvage_value


func _apply_damage(target: TacticalUnit, damage: int, source_weapon: String, contract: Contract) -> int:
	var salvage_value := 0
	var target_type = _get_unit_type_code(target)
	var type_def = _unit_types.get(target_type, {})
	var hit_table = type_def.get("hit_locations", {})
	var direction = _roll_hit_direction(target, type_def)
	var locations = hit_table.get(direction, hit_table.get("front", []))
	var loc_roll = _rng.randi_range(2, 12)
	var loc_entry = locations[loc_roll - 2] if loc_roll - 2 < locations.size() else {"location": "Center Torso"}
	var loc_name = loc_entry.get("location", "Center Torso")
	var can_tac = loc_entry.get("tac", false)

	var comp = _find_component_in_location(target, loc_name)
	if not comp:
		return 0
	if comp.status == Enums.ComponentStatus.DESTROYED:
		return 0

	var crit_def = type_def.get("crit", {})
	var confirm_target = crit_def.get("confirmation_target", 8)
	var tac_float = crit_def.get("through_armor_floating", false)
	var destroy_chance = _config.get("component_destroy_chance", 0.3)

	if _rng.randf() < destroy_chance:
		comp.status = Enums.ComponentStatus.DESTROYED
		if comp.component_type == "weapon":
			var def = DataManager.component_defs.get(comp.component_name, {})
			var salvage_mult = _config.get("salvage_value_multiplier", 0.5)
			var value = int(def.get("cost", 1000) * salvage_mult)
			EconomySystem.track_enemy_loss(contract, comp.component_name, value, target.tonnage, 1, Enums.Quality.D, false, source_weapon, false)
			salvage_value = value

		var effects_table = crit_def.get("effects_table", {})
		if not effects_table.is_empty():
			var crit_roll = _rng.randi_range(2, 12)
			if crit_roll >= confirm_target:
				var result = effects_table.get(str(crit_roll), "component_damaged")
				_apply_crit_effect(target, result)
	else:
		comp.status = Enums.ComponentStatus.DAMAGED

	_check_motive_damage(target, target_type, type_def, loc_entry)

	return salvage_value


func _roll_cluster_hits(shots: int) -> int:
	var roll = _rng.randi_range(2, 12)
	var key = str(shots)
	if _cluster_table.has(key):
		var row = _cluster_table[key]
		var idx = roll - 2
		if idx >= 0 and idx < row.size():
			return row[idx]
	for k in _cluster_table.keys():
		if int(k) >= shots:
			var row = _cluster_table[k]
			var idx = roll - 2
			if idx >= 0 and idx < row.size():
				return mini(row[idx], shots)
			break
	return shots


func _find_component_in_location(unit: TacticalUnit, location_name: String) -> Component:
	for c in unit.components:
		if c.location and c.location.location_name == location_name:
			if c.status != Enums.ComponentStatus.DESTROYED:
				return c
	for c in unit.components:
		if c.location and c.location.location_name == location_name:
			return c
	return null if unit.components.is_empty() else unit.components[_rng.randi_range(0, unit.components.size() - 1)]


func _roll_hit_direction(_unit: TacticalUnit, type_def: Dictionary) -> String:
	var arcs = type_def.get("facing_arcs", {})
	if arcs.is_empty():
		var roll = _rng.randi_range(1, 10)
		if roll <= 7:
			return "front"
		elif roll <= 9:
			return "right_side" if _rng.randi_range(0, 1) == 0 else "left_side"
		return "rear"

	var resolver = FacingResolver.new()
	add_child(resolver)
	var result = resolver.resolve(Vector2i.ZERO, Vector2i.ZERO, 0, arcs)
	resolver.queue_free()
	return result


func _check_motive_damage(unit: TacticalUnit, type_code: String, type_def: Dictionary, loc_entry: Dictionary) -> void:
	if not loc_entry.get("motive", false):
		return
	var motive_def = type_def.get("motive_damage", {})
	if not motive_def.get("enabled", true):
		return
	var target_num = motive_def.get("confirmation_target", 8)
	var mot_bonus = motive_def.get("mobility_bonus", {})
	var bonus = mot_bonus.get(unit.motion_type.to_lower(), 0)
	var roll = _rng.randi_range(2, 12)
	if roll + bonus >= target_num:
		var effects = motive_def.get("effects_table", {})
		var result = effects.get(str(roll), "motive_damaged")
		match result:
			"motive_crippled":
				unit.movement_mp = max(0, unit.movement_mp - 3)
			"motive_damaged":
				unit.movement_mp = max(0, unit.movement_mp - 1)


func _apply_crit_effect(unit: TacticalUnit, effect: String) -> void:
	match effect:
		"weapon_destroyed":
			for c in unit.components:
				if c.component_type == "weapon" and c.status == Enums.ComponentStatus.UNDAMAGED:
					c.status = Enums.ComponentStatus.DESTROYED
					break
		"weapon_damaged":
			for c in unit.components:
				if c.component_type == "weapon" and c.status == Enums.ComponentStatus.UNDAMAGED:
					c.status = Enums.ComponentStatus.DAMAGED
					break
		"component_destroyed":
			for c in unit.components:
				if c.status == Enums.ComponentStatus.UNDAMAGED:
					c.status = Enums.ComponentStatus.DESTROYED
					break
		"component_damaged":
			for c in unit.components:
				if c.status == Enums.ComponentStatus.UNDAMAGED:
					c.status = Enums.ComponentStatus.DAMAGED
					break
		"ammo_explosion":
			for c in unit.components:
				c.status = Enums.ComponentStatus.DESTROYED
		"vehicle_destroyed":
			for c in unit.components:
				c.status = Enums.ComponentStatus.DESTROYED


func _filter_destroyed(units: Array[TacticalUnit]) -> Array[TacticalUnit]:
	var result: Array[TacticalUnit] = []
	for u in units:
		var destroyed = u.get_destroyed_components().size()
		if destroyed < u.components.size():
			result.append(u)
	return result
