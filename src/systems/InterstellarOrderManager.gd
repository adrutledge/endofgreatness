class_name InterstellarOrderManager
extends Node

const MAX_JUMP_RANGE: float = 30.0
const TRANSIT_DAYS: int = 7

## Flat per-jump cargo shipping cost. Small items ride commercial shipping
## (DropShip cargo manifest on scheduled runs), not a dedicated vessel.
## Orders of magnitude cheaper than unit transport (no dedicated JumpShip).
const TRANSPORT_COST_PER_JUMP: int = 5000

const SPECTRAL_RECHARGE_HOURS: Dictionary = {
	"O": 75, "B": 85, "A": 110, "F": 130,
	"G": 175, "K": 210, "M": 270
}

## Search nearby systems for a complete tactical unit (chassis name).
## Returns results with unit transport cost (CO abstract) instead of
## component shipping cost.
func search_nearby_unit_sources(origin_system: String, chassis_name: String, max_jumps: int = 2) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var origin_data = DataManager.systems_data.get(origin_system)
	if not origin_data:
		return results

	var origin_coords = origin_data.get("coordinates", {})
	var ox: float = origin_coords.get("x", 0)
	var oy: float = origin_coords.get("y", 0)

	var candidates: Array[Dictionary] = []
	for sys_name in DataManager.systems_data:
		if sys_name == origin_system:
			continue
		var sys_data = DataManager.systems_data[sys_name]
		var coords = sys_data.get("coordinates", {})
		var dist = sqrt(pow(coords.get("x", 0) - ox, 2) + pow(coords.get("y", 0) - oy, 2))
		if dist <= MAX_JUMP_RANGE * max_jumps:
			var factions = _derive_factions_for_system(sys_name, sys_data)
			for code in factions:
				var units = DataManager.get_faction_market_units(code)
				for tu in units:
					if tu.chassis_name == chassis_name:
						var jumps = max(1, int(ceil(dist / MAX_JUMP_RANGE)))
						var travel_days = _calculate_travel_days(origin_data, sys_data, dist)
						var unit_cost = tu.calculate_tm_cost()
						var transport = UnitTransportManager.calculate_unit_transport_cost(tu.tonnage, jumps)
						results.append({
							"source_system": sys_name,
							"unit": tu,
							"cost_per_unit": unit_cost,
							"transport_cost": transport,
							"total_cost": unit_cost + transport,
							"travel_days": travel_days,
							"jumps": jumps,
							"distance_ly": dist
						})
						break
	return results

func search_nearby_systems(origin_system: String, item_name: String, max_jumps: int = 2) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var origin_data = DataManager.systems_data.get(origin_system)
	if not origin_data:
		return results

	var transport_enabled := true
	var cfg_file = FileAccess.open("res://data/config/spares_config.json", FileAccess.READ)
	if cfg_file:
		var j = JSON.new()
		if j.parse(cfg_file.get_as_text()) == OK:
			transport_enabled = j.data.get("remote_transport_cost_enabled", true)

	var origin_coords = origin_data.get("coordinates", {})
	var ox: float = origin_coords.get("x", 0)
	var oy: float = origin_coords.get("y", 0)

	var systems_within_1_jump: Array[Dictionary] = []
	var systems_within_2_jumps: Array[Dictionary] = []

	for sys_name in DataManager.systems_data:
		if sys_name == origin_system:
			continue
		var sys_data = DataManager.systems_data[sys_name]
		var coords = sys_data.get("coordinates", {})
		var sx: float = coords.get("x", 0)
		var sy: float = coords.get("y", 0)
		var dist = sqrt(pow(sx - ox, 2) + pow(sy - oy, 2))

		if dist <= MAX_JUMP_RANGE:
			systems_within_1_jump.append({"name": sys_name, "data": sys_data, "distance": dist})
		elif max_jumps >= 2 and dist <= MAX_JUMP_RANGE * 2:
			systems_within_2_jumps.append({"name": sys_name, "data": sys_data, "distance": dist})

	for entry in systems_within_1_jump:
		var available = _is_item_available_at(item_name, entry.name, entry.data)
		if available:
			var travel_days = _calculate_travel_days(origin_data, entry.data, entry.distance)
			var def = DataManager.component_defs.get(item_name)
			var base_cost = def.get("cost", 1000) if def else 1000
			var transport_cost = TRANSPORT_COST_PER_JUMP if transport_enabled else 0
			var cost = base_cost + transport_cost
			results.append({
				"source_system": entry.name,
				"quantity": available.quantity,
				"cost_per_unit": cost,
				"travel_days": travel_days,
				"jumps": 1,
				"distance_ly": entry.distance
			})

	for entry in systems_within_2_jumps:
		var available = _is_item_available_at(item_name, entry.name, entry.data)
		if available:
			var travel_days = _calculate_travel_days(origin_data, entry.data, entry.distance)
			var def = DataManager.component_defs.get(item_name)
			var base_cost = def.get("cost", 1000) if def else 1000
			var transport_cost = TRANSPORT_COST_PER_JUMP * 2 if transport_enabled else 0
			var cost = base_cost + transport_cost
			results.append({
				"source_system": entry.name,
				"quantity": available.quantity,
				"cost_per_unit": cost,
				"travel_days": travel_days,
				"jumps": 2,
				"distance_ly": entry.distance
			})

	results.sort_custom(func(a, b): return a.jumps < b.jumps or (a.jumps == b.jumps and a.distance_ly < b.distance_ly))
	return results

func _is_item_available_at(item_name: String, system_name: String, system_data: Dictionary) -> Dictionary:
	if not DataManager.component_defs.has(item_name):
		return {}

	var factions_present = _derive_factions_for_system(system_name, system_data)
	var def = DataManager.component_defs[item_name]
	var tech_lvl = def.get("tech_level", 1)

	var total_qty: int = 0
	for code in factions_present:
		if tech_lvl <= 1:
			total_qty += randi() % 5 + 3
		else:
			var faction = GameState.factions.get(code)
			if faction and faction.unique_components.has(item_name):
				total_qty += randi() % 5 + 3

	if total_qty <= 0:
		return {}

	var component_cost = def.get("cost", 1000)
	var qty = max(1, total_qty / max(1, factions_present.size()))
	return {"quantity": qty, "cost": component_cost}

func _derive_factions_for_system(system_name: String, system_data: Dictionary) -> Array[String]:
	var results: Array[String] = []
	var owner = system_data.get("owner_faction", "")
	if owner and GameState.factions.has(owner):
		results.append(owner)
	else:
		for code in GameState.factions:
			var f = GameState.factions[code]
			if f.home_worlds.has(system_name):
				results.append(code)
	if results.is_empty():
		results.append("PIR")
	return results

func _calculate_travel_days(origin_data: Dictionary, dest_data: Dictionary, distance_ly: float) -> int:
	var jumps_needed = max(1, int(ceil(distance_ly / MAX_JUMP_RANGE)))
	var origin_spec = origin_data.get("spectral_class", "G")
	var dest_spec = dest_data.get("spectral_class", "G")

	var origin_recharge_h = SPECTRAL_RECHARGE_HOURS.get(origin_spec, 175)
	var dest_recharge_h = SPECTRAL_RECHARGE_HOURS.get(dest_spec, 175)
	var recharge_per_jump = max(origin_recharge_h, dest_recharge_h)
	var recharge_days = int(ceil(recharge_per_jump / 24.0))

	var total_days = (recharge_days + TRANSIT_DAYS) * jumps_needed
	return total_days
