extends Node

var pending_deliveries: Array[Dictionary] = []

func get_balance() -> int:
	return GameState.player.current_balance

func add_funds(amount: int, reason: String = "") -> void:
	GameState.player.current_balance += amount

func deduct_funds(amount: int, reason: String = "") -> bool:
	if GameState.player.current_balance >= amount:
		GameState.player.current_balance -= amount
		return true
	EventBus.emit_funds_depleted(GameState.player.current_balance)
	return false

func buy_item(item_name: String, quantity: int, cost_per_unit: int, faction: String = "") -> bool:
	var total_cost = cost_per_unit * quantity
	if not deduct_funds(total_cost, "Purchase: " + item_name):
		return false
	return true

func sell_item(item_name: String, quantity: int, price_per_unit: int) -> int:
	var total = price_per_unit * quantity
	add_funds(total, "Sale: " + item_name)
	return total

func get_daily_burn_rate() -> Dictionary:
	var total: int = 0
	var breakdown = {
		"salaries": 0,
		"maintenance": 0,
		"berthing": 0,
		"overhead": 0
	}
	for personnel in GameState.get_all_personnel():
		match personnel.role:
			Enums.PersonnelRole.ADMINISTRATOR:
				breakdown.salaries += 100
			Enums.PersonnelRole.MEDIC:
				breakdown.salaries += 80
			Enums.PersonnelRole.TECHNICIAN:
				breakdown.salaries += 90
			Enums.PersonnelRole.CREW:
				breakdown.salaries += 60
	for ou in GameState.player.organizational_units:
		for tu in ou.get_all_tactical_units():
			breakdown.maintenance += tu.components.size() * 5
	breakdown.overhead = GameState.player.organizational_units.size() * 50
	total = breakdown.salaries + breakdown.maintenance + breakdown.berthing + breakdown.overhead
	return {
		"total": total,
		"breakdown": breakdown
	}

func order_item(item_name: String, quantity: int, cost_per_unit: int, source_system: String, travel_ticks: int) -> bool:
	var total_cost = cost_per_unit * quantity
	if not deduct_funds(total_cost, "Order: " + item_name):
		return false
	var delivery = {
		"item": item_name,
		"quantity": quantity,
		"source_system": source_system,
		"eta_tick": travel_ticks,
		"completed": false
	}
	pending_deliveries.append(delivery)
	GameState.add_delivery(item_name, quantity, travel_ticks)
	return true

func process_peacetime_expenses() -> void:
	var burn = get_daily_burn_rate()
	deduct_funds(burn.total, "Daily expenses")

func apply_base_coverage(contract: Contract, burn_total: int) -> int:
	var coverage = contract.base_coverage / 100.0
	return int(burn_total * (1.0 - coverage))

func track_battle_loss(unit: TacticalUnit, component: Component, c_bill_value: int) -> void:
	pass

func track_ammo_expended(ammo_component: Component, shots_fired: int, c_bill_per_shot: int) -> void:
	pass
