extends Node

## Campaign Operations abstract transport costs for tactical units.
##
## Per CO: Dropships and Jumpships can be rented using abstract costs for
## transit if the strategic unit does not own them.
##
## Cost model:
##   DropShip (surface-to-orbit): DROPSHIP_COST_PER_TON per ton (one-way)
##   JumpShip (system-to-system): JUMPSHIP_COST_PER_TON_PER_JUMP per ton per jump
##
## One-way transport cost:
##   cost = tonnage × DROPSHIP_COST_PER_TON + tonnage × JUMPSHIP_COST_PER_TON_PER_JUMP × jumps
##
## Round-trip transport cost (deploy + return):
##   cost = tonnage × DROPSHIP_COST_PER_TON × 2 + tonnage × JUMPSHIP_COST_PER_TON_PER_JUMP × jumps × 2
##
## Configurable via spares_config.json:
##   unit_transport_cost_enabled: bool (default true)
##   dropship_cost_per_ton: int (default 5000)
##   jumpship_cost_per_ton_per_jump: int (default 10000)

var transport_cost_enabled: bool = true
var dropship_cost_per_ton: int = 5000
var jumpship_cost_per_ton_per_jump: int = 10000

func _ready() -> void:
	_load_config()

func _load_config() -> void:
	var f = FileAccess.open("res://data/config/spares_config.json", FileAccess.READ)
	if f:
		var j = JSON.new()
		if j.parse(f.get_as_text()) == OK:
			var data = j.data
			if data.has("unit_transport_cost_enabled"):
				transport_cost_enabled = data["unit_transport_cost_enabled"]
			if data.has("dropship_cost_per_ton"):
				dropship_cost_per_ton = data["dropship_cost_per_ton"]
			if data.has("jumpship_cost_per_ton_per_jump"):
				jumpship_cost_per_ton_per_jump = data["jumpship_cost_per_ton_per_jump"]

## Calculate one-way transport cost for a single unit.
func calculate_unit_transport_cost(tonnage: float, jumps: int) -> int:
	if not transport_cost_enabled:
		return 0
	var t = int(ceil(tonnage))
	return t * dropship_cost_per_ton + t * jumpship_cost_per_ton_per_jump * jumps

## Calculate one-way transport cost for a group of units.
func calculate_fleet_transport_cost(tonnages: Array[float], jumps: int) -> int:
	if not transport_cost_enabled:
		return 0
	var total: int = 0
	for t in tonnages:
		total += calculate_unit_transport_cost(t, jumps)
	return total

## Calculate round-trip transport cost for a single unit.
func calculate_round_trip_unit_cost(tonnage: float, jumps: int) -> int:
	return calculate_unit_transport_cost(tonnage, jumps) * 2

## Calculate round-trip transport cost for a group of units.
func calculate_round_trip_fleet_cost(tonnages: Array[float], jumps: int) -> int:
	return calculate_fleet_transport_cost(tonnages, jumps) * 2

## Returns the number of jumps from the player's current planet to the target.
func jumps_between(origin_system: String, dest_system: String) -> int:
	var origin_data = DataManager.systems_data.get(origin_system)
	var dest_data = DataManager.systems_data.get(dest_system)
	if not origin_data or not dest_data:
		return 0
	var oc = origin_data.get("coordinates", {})
	var dc = dest_data.get("coordinates", {})
	var dist = sqrt(pow(dc.get("x", 0) - oc.get("x", 0), 2) + pow(dc.get("y", 0) - oc.get("y", 0), 2))
	return max(1, int(ceil(dist / 30.0)))

## Calculate one-way transport cost for a unit between two named systems.
func calculate_transport_cost_between(tonnage: float, origin_system: String, dest_system: String) -> int:
	var jumps = jumps_between(origin_system, dest_system)
	return calculate_unit_transport_cost(tonnage, jumps)

## Calculate round-trip transport cost for a unit between two named systems.
func calculate_round_trip_cost_between(tonnage: float, origin_system: String, dest_system: String) -> int:
	return calculate_transport_cost_between(tonnage, origin_system, dest_system) * 2

## Returns the daily transport cost contribution for the burn rate.
## With no Dropship/Jumpship ownership, this is 0.
## Future: if player leases transport, this would reflect ongoing lease costs.
func get_daily_transport_cost() -> int:
	return 0
