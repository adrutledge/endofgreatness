extends Node

var pending_deliveries: Array[Dictionary] = []
var accumulated_expenses: int = 0
var accumulated_breakdown: Dictionary = {}
var last_bill_month: int = -1
var last_bill_year: int = -1

var contract_battle_losses: Dictionary = {}
var contract_ammo_costs: Dictionary = {}

var current_market: PlanetaryMarket
var current_planet_factions: Array[String] = []
var interstellar_order_manager: InterstellarOrderManager

func _ready() -> void:
	TimeManager.date_changed.connect(_on_date_changed)
	EventBus.contract_accepted.connect(_on_contract_accepted)
	EventBus.contract_completed.connect(_on_contract_completed)
	last_bill_month = TimeManager.current_date.get("month", 1)
	last_bill_year = TimeManager.current_date.get("year", 3025)
	current_market = PlanetaryMarket.new()
	interstellar_order_manager = InterstellarOrderManager.new()
	add_child(interstellar_order_manager)

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

func initialize_market(planet_name: String, factions_present: Array[String] = [], exclude_faction: String = "") -> void:
	current_planet_factions = factions_present.duplicate()
	if factions_present.is_empty():
		current_planet_factions = _derive_factions_for_planet(planet_name)
	current_market.setup(current_planet_factions, exclude_faction)

func _derive_factions_for_planet(planet_name: String) -> Array[String]:
	var results: Array[String] = []
	for code in GameState.factions:
		var f = GameState.factions[code]
		if f.home_worlds.has(planet_name):
			results.append(code)
	if results.is_empty() and DataManager.systems_data.has(planet_name):
		results.append("PIR")
	return results

func buy_item(item_name: String, quantity: int) -> bool:
	var price = current_market.get_price(item_name)
	if price <= 0:
		return false
	var total_cost = price * quantity
	if not deduct_funds(total_cost, "Purchase: " + item_name):
		return false
	return current_market.buy(item_name, quantity)

func sell_item(item_name: String, quantity: int) -> int:
	var price = current_market.get_price(item_name)
	if price <= 0:
		var def = DataManager.component_defs.get(item_name)
		price = def.get("cost", 1000) / 2 if def else 500
	var total = price * quantity
	current_market.sell(item_name, quantity)
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
	for personnel in GameState.player.get_all_personnel():
		match personnel.role:
			Enums.PersonnelRole.HR:
				breakdown.salaries += 70
			Enums.PersonnelRole.LOGISTICAL:
				breakdown.salaries += 100
			Enums.PersonnelRole.TRANSPORT:
				breakdown.salaries += 80
			Enums.PersonnelRole.COMMAND:
				breakdown.salaries += 150
			Enums.PersonnelRole.MEDIC:
				breakdown.salaries += 80
			Enums.PersonnelRole.DOCTOR:
				breakdown.salaries += 120
			Enums.PersonnelRole.TECHNICIAN:
				breakdown.salaries += 90
			Enums.PersonnelRole.ASTECH:
				breakdown.salaries += 50
			Enums.PersonnelRole.CREW:
				breakdown.salaries += 60
			Enums.PersonnelRole.CIVILIAN:
				breakdown.salaries += 0
			Enums.PersonnelRole.CHILD:
				breakdown.salaries += 0
	for ou in GameState.player.organizational_units:
		for tu in ou.get_all_tactical_units():
			breakdown.maintenance += tu.components.size() * 5
	breakdown.overhead = GameState.player.organizational_units.size() * 50
	total = breakdown.salaries + breakdown.maintenance + breakdown.berthing + breakdown.overhead
	return {
		"total": total,
		"breakdown": breakdown
	}

func search_remote_sources(item_name: String) -> Array[Dictionary]:
	if not GameState.player.current_planet:
		return []
	return interstellar_order_manager.search_nearby_systems(GameState.player.current_planet, item_name)

func order_item(item_name: String, quantity: int, cost_per_unit: int, source_system: String, travel_days: int) -> bool:
	var total_cost = cost_per_unit * quantity
	if not deduct_funds(total_cost, "Order: " + item_name):
		return false
	var eta_tick = TimeManager.total_days + travel_days
	var delivery = {
		"item": item_name,
		"quantity": quantity,
		"source_system": source_system,
		"eta_tick": eta_tick,
		"completed": false
	}
	pending_deliveries.append(delivery)
	GameState.add_delivery(item_name, quantity, eta_tick)
	return true

func _on_date_changed(date: Dictionary) -> void:
	var day = date.get("day", 1)
	var month = date.get("month", 1)
	var year = date.get("year", 3025)

	var burn = get_daily_burn_rate()
	var daily_total = burn.total

	for contract in GameState.active_contracts:
		if contract.is_active:
			daily_total = _apply_base_coverage(contract, daily_total)
			break

	accumulated_expenses += daily_total
	for key in burn.breakdown:
		accumulated_breakdown[key] = accumulated_breakdown.get(key, 0) + burn.breakdown[key]

	current_market.refresh()

	GameState.process_deliveries(TimeManager.total_days)

	if day == 1 and not (month == last_bill_month and year == last_bill_year):
		_process_monthly_bills()
		last_bill_month = month
		last_bill_year = year

func _apply_base_coverage(contract: Contract, burn_total: int) -> int:
	var coverage = contract.base_coverage / 100.0
	return int(burn_total * (1.0 - coverage))

func _process_monthly_bills() -> void:
	var amount = accumulated_expenses
	if amount <= 0:
		accumulated_expenses = 0
		accumulated_breakdown = {}
		return

	var breakdown_snapshot = accumulated_breakdown.duplicate()
	deduct_funds(amount, "Monthly bills")
	EventBus.emit_bills_paid(amount, breakdown_snapshot)

	accumulated_expenses = 0
	accumulated_breakdown = {}

func settle_contract(contract: Contract) -> Dictionary:
	var key = contract.get_instance_id()
	var total_loss: int = 0
	var losses: Array = contract_battle_losses.get(key, [])
	for entry in losses:
		total_loss += entry.value
	var ammo_cost: int = contract_ammo_costs.get(key, 0)
	total_loss += ammo_cost
	var reimbursement: int = int(total_loss * contract.battle_loss_reimbursement_rate)
	if reimbursement > 0:
		add_funds(reimbursement, "Battle loss reimbursement: " + contract.issuer)

	var salvage_bonus: int = 0
	if contract.salvage_type == "exchange" and contract.salvage_rate > 0.0:
		salvage_bonus = int(total_loss * contract.salvage_rate)
		if salvage_bonus > 0:
			add_funds(salvage_bonus, "Salvage conversion: " + contract.issuer)

	var result = {
		"battle_loss_value": total_loss,
		"reimbursement": reimbursement,
		"salvage_bonus": salvage_bonus,
		"total": reimbursement + salvage_bonus
	}
	EventBus.emit_contract_settled(contract, result)
	return result

func process_peacetime_expenses() -> void:
	var burn = get_daily_burn_rate()
	deduct_funds(burn.total, "Daily expenses")

func apply_base_coverage(contract: Contract, burn_total: int) -> int:
	return _apply_base_coverage(contract, burn_total)

func _on_contract_accepted(contract: Contract) -> void:
	var key = contract.get_instance_id()
	contract_battle_losses[key] = []
	contract_ammo_costs[key] = 0

func track_battle_loss(unit: TacticalUnit, component: Component, c_bill_value: int) -> void:
	for c in GameState.active_contracts:
		if not c.is_active:
			continue
		var key = c.get_instance_id()
		if not contract_battle_losses.has(key):
			contract_battle_losses[key] = []
		contract_battle_losses[key].append({
			"unit": unit.unit_name,
			"component": component.component_name,
			"value": c_bill_value
		})

func _on_contract_completed(contract: Contract) -> void:
	settle_contract(contract)
	contract_battle_losses.erase(contract.get_instance_id())
	contract_ammo_costs.erase(contract.get_instance_id())

func track_ammo_expended(ammo_component: Component, shots_fired: int, c_bill_per_shot: int) -> void:
	var cost = shots_fired * c_bill_per_shot
	for c in GameState.active_contracts:
		if not c.is_active:
			continue
		var key = c.get_instance_id()
		contract_ammo_costs[key] = contract_ammo_costs.get(key, 0) + cost
