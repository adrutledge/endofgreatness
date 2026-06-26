class_name CombatResolver
extends Node

## Resolves weapon attacks: GATOR to-hit calculation, hit/miss determination,
## damage application, and location allocation.
##
## Per-engagement instance. Callers pass weapon + attacker + target state,
## receive hit/miss, damage, and location results.

var hit_locations: Dictionary = {}
var heat_table: Dictionary = {}
var cluster_hits: Dictionary = {}


func _ready() -> void:
	_load_data()


func _load_data() -> void:
	var hl = FileAccess.open("res://data/rules/hit_locations.json", FileAccess.READ)
	if hl:
		var j = JSON.new()
		if j.parse(hl.get_as_text()) == OK:
			hit_locations = j.data.get("tables", {})

	var ht = FileAccess.open("res://data/rules/heat_table.json", FileAccess.READ)
	if ht:
		var j = JSON.new()
		if j.parse(ht.get_as_text()) == OK:
			heat_table = j.data

	var ch = FileAccess.open("res://data/rules/cluster_hits.json", FileAccess.READ)
	if ch:
		var j = JSON.new()
		if j.parse(ch.get_as_text()) == OK:
			cluster_hits = j.data.get("table", {})


## Computes the target number using GATOR.
## Returns int TN. Roll 2d6 >= TN to hit.
##
## GATOR:
##   G = attacker gunnery skill  (passed in)
##   A = attacker movement mod    (walk=1, run=2, jump=3, stationary=0)
##   T = target movement mod      (hexes moved + jump_bonus)
##   O = other modifiers          (terrain, cover, prone, pulse, etc.)
##   R = range bracket mod        (short=0, medium=2, long=4, extreme=6, +min_range)
func calculate_tn(gunnery: int, attacker_amm: int, target_tmm: int,
		other_mods: int, range_mod: int) -> int:
	var tn = gunnery + attacker_amm + target_tmm + other_mods + range_mod
	return clampi(tn, 2, 13)


## Rolls to hit. Returns true if hit, false if miss.
func roll_to_hit(tn: int) -> bool:
	if tn > 12:
		return false
	if tn <= 2:
		return true
	var roll = randi() % 6 + randi() % 6 + 2
	return roll >= tn


## Determines hit location for a given unit type and arc.
## Returns location string key (e.g., "ct", "ra", "rl", "head").
func roll_hit_location(unit_type: String, arc: String) -> String:
	var table_key = unit_type + "_" + arc
	var table = hit_locations.get(table_key, hit_locations.get("biped_front", {}))
	var roll = randi() % 6 + randi() % 6 + 2
	return table.get(str(roll), "ct")


## Resolves cluster hits for a weapon with the given number of sub-munitions.
## Returns int: number of munitions that hit.
func resolve_cluster(munitions: int) -> int:
	var col = cluster_hits.get("column_labels", [])
	var col_idx = col.find(str(munitions))
	if col_idx < 0:
		return munitions
	var roll = randi() % 6 + randi() % 6 + 2
	var row = cluster_hits.get(str(roll), [])
	return row[col_idx] if col_idx < row.size() else munitions


## Full attack resolution. Returns Dictionary with hit, location, damage, cluster_results.
func resolve_attack(attacker, target, weapon: Dictionary, range_hexes: int,
		attacker_amm: int, target_tmm: int, other_mods: int) -> Dictionary:
	var range_mod = _get_range_mod(weapon, range_hexes)
	var min_range_penalty = _get_min_range_penalty(weapon, range_hexes)
	var tn = calculate_tn(
		attacker.gunnery,
		attacker_amm,
		target_tmm,
		other_mods + min_range_penalty,
		range_mod
	)

	var _emit_rules := func(result: Dictionary):
		if Helpers.debug:
			var eb = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() else null
			if eb:
				eb.emit_rules_check("to_hit", {
					"gunnery": attacker.gunnery,
					"attacker_movement_mod": attacker_amm,
					"target_movement_mod": target_tmm,
					"other_mods": other_mods + min_range_penalty,
					"range_mod": range_mod,
				}, result)

	if tn > 12:
		var res = {"hit": false, "tn": tn, "roll": 0, "reason": "impossible"}
		_emit_rules.call(res)
		return res

	var roll = randi() % 6 + randi() % 6 + 2
	var hit = roll >= tn

	if not hit:
		var res = {"hit": false, "tn": tn, "roll": roll}
		_emit_rules.call(res)
		return res

	var location = roll_hit_location(target.unit_type, target.arc_to(attacker))
	var damage = weapon.get("damage", 0)
	var cluster = weapon.get("cluster_size", 0)
	var cluster_results = {}
	if cluster > 0:
		var hits = resolve_cluster(cluster)
		cluster_results = {"total_munitions": cluster, "hits": hits, "damage_per_hit": damage}
		damage = hits * damage

	var res = {
		"hit": true,
		"tn": tn,
		"roll": roll,
		"location": location,
		"damage": damage,
		"cluster": cluster_results
	}
	_emit_rules.call(res)
	return res


func _get_range_mod(weapon: Dictionary, range_hexes: int) -> int:
	var brackets = weapon.get("range_brackets", {})
	if range_hexes <= brackets.get("short", 0):
		return 0
	if range_hexes <= brackets.get("medium", 0):
		return 2
	if range_hexes <= brackets.get("long", 0):
		return 4
	return 6


func _get_min_range_penalty(weapon: Dictionary, range_hexes: int) -> int:
	var min_range = weapon.get("minimum_range", 0)
	if min_range <= 0 or range_hexes >= min_range:
		return 0
	var penalty = 1 + (min_range - range_hexes - 1)
	return max(0, penalty)
