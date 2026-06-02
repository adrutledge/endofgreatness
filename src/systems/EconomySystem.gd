extends Node

var pending_deliveries: Array[Dictionary] = []
var accumulated_expenses: int = 0
var accumulated_breakdown: Dictionary = {}
var last_bill_month: int = -1
var last_bill_year: int = -1

var contract_battle_losses: Dictionary = {}
var contract_ammo_costs: Dictionary = {}

## Salvage pool per contract: maps contract instance_id → Array[Dictionary]
## Each entry: { component_name, c_bill_value, recovery_hours, quantity, source_unit }
var contract_salvage_pool: Dictionary = {}

## Cumulative tracking per contract for settlement summary.
## Keyed by contract instance_id, values are int totals.
var contract_cumulative_loss_value: Dictionary = {}
var contract_cumulative_reimbursement: Dictionary = {}

var current_market: PlanetaryMarket
var current_planet_factions: Array[String] = []
var interstellar_order_manager: InterstellarOrderManager

var _funds_warning_emitted: bool = false

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.month_started.connect(_on_month_started)
	EventBus.contract_accepted.connect(_on_contract_accepted)
	EventBus.contract_completed.connect(_on_contract_completed)
	last_bill_month = TimeManager.current_date.get("month", 1)
	last_bill_year = TimeManager.current_date.get("year", 3025)
	current_market = PlanetaryMarket.new()
	interstellar_order_manager = InterstellarOrderManager.new()
	add_child(interstellar_order_manager)
	initialize_market("Galatea")

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
	if planet_name == "Galatea":
		for code in GameState.factions:
			var f = GameState.factions[code]
			if code in ["MRB", "CS"]:
				continue
			if not f.is_rebel and not f.is_pirate and not f.is_civilian:
				results.append(code)
		return results
	var sys_data = DataManager.systems_data.get(planet_name)
	var owner = sys_data.get("owner_faction", "") if sys_data else ""
	if owner and GameState.factions.has(owner):
		results.append(owner)
	for code in GameState.factions:
		var f = GameState.factions[code]
		if f.home_worlds.has(planet_name) and code not in results:
			results.append(code)
	if results.is_empty() and sys_data:
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
		"overhead": 0,
		"transport": 0
	}
	for personnel in GameState.player.get_all_personnel():
		if not personnel:
			continue
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
			breakdown.salaries += tu.abstract_crew_count * 60
	breakdown.salaries += PersonnelManager.get_abstract_salary_cost()
	breakdown.overhead = GameState.player.organizational_units.size() * 50
	breakdown.transport = UnitTransportManager.get_daily_transport_cost()
	total = breakdown.salaries + breakdown.maintenance + breakdown.berthing + breakdown.overhead + breakdown.transport
	return {
		"total": total,
		"breakdown": breakdown
	}

## Returns the one-way CO unit transport cost for a single tactical unit
## from the player's current planet to the destination system.
func get_unit_transport_cost(unit: TacticalUnit, dest_system: String) -> int:
	if not GameState.player.current_planet:
		return 0
	return UnitTransportManager.calculate_transport_cost_between(unit.tonnage, GameState.player.current_planet, dest_system)

## Returns the total one-way CO transport cost for all player tactical units
## to the destination system.
func get_fleet_transport_cost(dest_system: String) -> int:
	if not GameState.player.current_planet:
		return 0
	var tonnages: Array[float] = []
	for ou in GameState.player.organizational_units:
		for tu in ou.get_all_tactical_units():
			tonnages.append(tu.tonnage)
	if tonnages.is_empty():
		return 0
	var jumps = UnitTransportManager.jumps_between(GameState.player.current_planet, dest_system)
	return UnitTransportManager.calculate_fleet_transport_cost(tonnages, jumps)

## Returns the player's share of transport cost after contract coverage.
func get_player_transport_share(total_cost: int, contract: Contract) -> int:
	var coverage = contract.transport_coverage / 100.0
	return int(total_cost * (1.0 - coverage))

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

func _on_day_started(date: Dictionary) -> void:
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


func _on_month_started(date: Dictionary) -> void:
	var month = date.get("month", 1)
	var year = date.get("year", 3025)
	_process_monthly_bills()

	for contract in GameState.active_contracts:
		if contract.is_active and contract.payout_per_month > 0:
			add_funds(contract.payout_per_month, "Contract payout: " + contract.issuer + "/" + contract.activity_type)

	last_bill_month = month
	last_bill_year = year
	if GameState.player.current_planet == "Galatea":
		current_market.mark_for_rebuild()

	# Warn on negative balance (once per negative period)
	if get_balance() < 0:
		if not _funds_warning_emitted:
			_funds_warning_emitted = true
			GameState.log_event("funds_warning", {
				"balance": get_balance(),
				"date": date.duplicate(),
				"daily_burn": get_daily_burn_rate().total
			})
			EventBus.emit_event_triggered({
				"date": "%d-%02d-%02d" % [date.year, date.month, date.day],
				"type": "event",
				"data": {
					"title": "Funds Depleted",
					"description": "Your account is overdrawn! Current balance: " + str(get_balance()) + " CSB. Expenses exceed income."
				}
			})
	else:
		_funds_warning_emitted = false

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

## Called after each tactical engagement.
## Processes salvage recovery and reimburses battle losses immediately.
## Returns a Dictionary with salvage + reimbursement results.
func process_engagement(contract: Contract) -> Dictionary:
	var salvage = process_salvage_after_engagement(contract)
	var reimbursement = reimburse_engagement_losses(contract)
	var result = salvage.duplicate()
	result.reimbursement = reimbursement
	result.total = salvage.get("salvage_bonus", 0) + reimbursement
	return result


## Processes salvage recovery from the engagement's salvage pool.
## Returns a Dictionary describing what was recovered.
func process_salvage_after_engagement(contract: Contract) -> Dictionary:
	var key = contract.get_instance_id()
	var pool: Array = contract_salvage_pool.get(key, [])
	if pool.is_empty():
		pool = contract.salvage_pool

	var result = {
		"salvage_bonus": 0,
		"salvage_items": [],
		"salvage_skipped": [],
		"hours_used": 0,
	}

	if pool.is_empty() or contract.salvage_rate <= 0.0:
		return result

	# Sort by value descending so we take the most valuable items first
	pool.sort_custom(func(a, b): return a.c_bill_value > b.c_bill_value)

	var total_salvage_value := 0
	for entry in pool:
		total_salvage_value += entry.c_bill_value

	var max_salvage_value := int(total_salvage_value * contract.salvage_rate)
	var remaining_value := max_salvage_value
	var available_hours := get_available_recovery_hours()
	var remaining_hours := available_hours

	var recovered: Array[Dictionary] = []
	var skipped: Array[Dictionary] = []
	var kept: Array[Dictionary] = []

	for entry in pool:
		if remaining_value <= 0:
			skipped.append(entry.duplicate())
			continue

		if entry.c_bill_value > remaining_value:
			kept.append(entry.duplicate())
			continue

		# Per CO: roll recovery chance — components that fail the roll are lost
		var recovery_roll := randf()
		var chance = entry.get("recovery_chance", 0.5)
		if recovery_roll > chance:
			skipped.append(entry.duplicate())
			continue

		var hours_needed := int(ceil(entry.recovery_hours))
		if hours_needed > remaining_hours:
			kept.append(entry.duplicate())
			continue

		if contract.salvage_type == "items":
			var inv_name = entry.component_name
			var qty = entry.get("quantity", 1)
			var condition: int = entry.get("condition", Enums.ComponentStatus.UNDAMAGED)
			if condition == Enums.ComponentStatus.DAMAGED:
				inv_name = "Damaged " + inv_name
			GameState.player_inventory[inv_name] = GameState.player_inventory.get(inv_name, 0) + qty

		remaining_value -= entry.c_bill_value
		remaining_hours -= hours_needed
		recovered.append(entry.duplicate())

	if contract.salvage_type == "exchange" and not recovered.is_empty():
		var bonus_value := max_salvage_value - remaining_value
		add_funds(bonus_value, "Salvage conversion: " + contract.issuer)
		result.salvage_bonus = bonus_value

	result.salvage_items = recovered
	result.salvage_skipped = skipped
	result.hours_used = available_hours - remaining_hours

	# Remove recovered items from the pool; keep skipped+kept for future engagements
	var claimed_names: Array[String] = []
	for r in recovered:
		claimed_names.append(r.component_name)

	var new_pool: Array[Dictionary] = []
	for entry in pool:
		if entry.component_name in claimed_names:
			continue
		new_pool.append(entry)
	for k in kept:
		if k.component_name not in claimed_names:
			new_pool.append(k)

	contract_salvage_pool[key] = new_pool
	contract.salvage_pool = new_pool.duplicate()

	if not recovered.is_empty():
		GameState.log_event("salvage_recovered", {
			"contract": contract.issuer + "/" + contract.activity_type,
			"type": contract.salvage_type,
			"items": recovered,
			"total_value": max_salvage_value - remaining_value,
			"hours_used": result.hours_used,
		})

	return result


func reimburse_engagement_losses(contract: Contract) -> int:
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

	contract_cumulative_loss_value[key] = contract_cumulative_loss_value.get(key, 0) + total_loss
	contract_cumulative_reimbursement[key] = contract_cumulative_reimbursement.get(key, 0) + reimbursement

	contract_battle_losses[key] = []
	contract_ammo_costs[key] = 0

	return reimbursement


func settle_contract(contract: Contract) -> Dictionary:
	var key = contract.get_instance_id()

	var total_loss = contract_cumulative_loss_value.get(key, 0)
	var total_reimbursement = contract_cumulative_reimbursement.get(key, 0)

	# Any remaining salvage pool at contract end — convert exchange salvage,
	# for items salvage these were processed per engagement already
	var leftover_conversion := 0
	var leftover: Array = contract_salvage_pool.get(key, [])
	if not leftover.is_empty() and contract.salvage_type == "exchange":
		var leftover_value := 0
		for entry in leftover:
			leftover_value += entry.c_bill_value
		leftover_conversion = int(leftover_value * contract.salvage_rate)
		if leftover_conversion > 0:
			add_funds(leftover_conversion, "Final salvage conversion: " + contract.issuer)

	var result = {
		"battle_loss_value": total_loss,
		"reimbursement": total_reimbursement,
		"leftover_salvage_conversion": leftover_conversion,
		"total": total_reimbursement + leftover_conversion,
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
	contract_salvage_pool[key] = []
	contract.salvage_pool = []
	contract_cumulative_loss_value[key] = 0
	contract_cumulative_reimbursement[key] = 0

func track_battle_loss(contract: Contract, unit: TacticalUnit, component: Component, c_bill_value: int) -> void:
	var key = contract.get_instance_id()
	if not contract_battle_losses.has(key):
		contract_battle_losses[key] = []
	contract_battle_losses[key].append({
		"unit": unit.unit_name,
		"component": component.component_name,
		"value": c_bill_value
	})

func _on_contract_completed(contract: Contract) -> void:
	settle_contract(contract)

	ReputationSystem.modify_reputation(contract.issuer, 10, "Contract completed: " + contract.activity_type)
	if contract.target:
		ReputationSystem.modify_reputation(contract.target, -5, "Opposed contract: " + contract.activity_type)
	ReputationSystem.modify_reputation("MRB", 5, "Contract completed: " + contract.activity_type)

	var key = contract.get_instance_id()
	contract_battle_losses.erase(key)
	contract_ammo_costs.erase(key)
	contract_cumulative_loss_value.erase(key)
	contract_cumulative_reimbursement.erase(key)

func track_ammo_expended(contract: Contract, ammo_component: Component, shots_fired: int, c_bill_per_shot: int) -> void:
	## Legacy per-shot tracking. Prefer record_ammo_expended() which is
	## called at end of engagement with net ammo usage to avoid double-charging.
	var cost = shots_fired * c_bill_per_shot
	var key = contract.get_instance_id()
	contract_ammo_costs[key] = contract_ammo_costs.get(key, 0) + cost


## Called at end of engagement with net ammo expended per ammo type.
## shots_fired = starting_shots - remaining_shots; destroyed mechs' unspent
## ammo does not count since it was never fired.
func record_ammo_expended(contract_id: String, ammo_type: String, shots_fired: int, c_bill_per_shot: int) -> void:
	var cost = shots_fired * c_bill_per_shot
	var key = contract_id
	contract_ammo_costs[key] = contract_ammo_costs.get(key, 0) + cost


func track_enemy_loss(contract: Contract, component_name: String, c_bill_value: int, tonnage: float,
		difficulty: int, quality: Enums.Quality = Enums.Quality.D,
		is_destroyed: bool = false, source_unit: String = "",
		location_blown_off: bool = false) -> void:
	## Per CO: components from a destroyed location are usually lost.
	## Exception: if a location was blown off by a crit roll (ammo explosion, etc.),
	## its components are scattered on the field and recoverable even if the mech leaves.
	if is_destroyed and not location_blown_off:
		return

	var key = contract.get_instance_id()
	if not contract_salvage_pool.has(key):
		contract_salvage_pool[key] = []

	var condition = Enums.ComponentStatus.DAMAGED if randi() % 3 < 2 else Enums.ComponentStatus.UNDAMAGED
	var recovery_hours = _calculate_recovery_hours(tonnage, difficulty, condition)
	var recovery_chance = _calculate_recovery_chance(difficulty, quality, condition)

	var merged := false
	for entry in contract_salvage_pool[key]:
		if entry.component_name == component_name and entry.source_unit == source_unit \
				and entry.condition == condition:
			entry.quantity += 1
			entry.c_bill_value += c_bill_value
			entry.recovery_hours += recovery_hours
			entry.recovery_chance = min(1.0, entry.recovery_chance + 0.05)
			merged = true
			break

	if not merged:
		contract_salvage_pool[key].append({
			"component_name": component_name,
			"c_bill_value": c_bill_value,
			"recovery_hours": recovery_hours,
			"quantity": 1,
			"source_unit": source_unit,
			"quality": quality,
			"condition": condition,
			"recovery_chance": recovery_chance,
			"tonnage": tonnage,
			"difficulty": difficulty,
		})

	contract.salvage_pool = contract_salvage_pool[key].duplicate()


static func _calculate_recovery_hours(tonnage: float, difficulty: int,
		condition: Enums.ComponentStatus = Enums.ComponentStatus.UNDAMAGED) -> float:
	## Per CO: base = component_tonnage × 0.5 hours; damaged takes 1.5×
	var base = max(0.5, tonnage * 0.5)
	if condition == Enums.ComponentStatus.DAMAGED:
		base *= 1.5
	match difficulty:
		0: return base * 0.8
		1: return base * 1.0
		2: return base * 1.5
		3: return base * 2.0
		4: return base * 3.0
		_: return base


static func _calculate_recovery_chance(difficulty: int, quality: Enums.Quality,
		condition: Enums.ComponentStatus) -> float:
	## Per CO: recovery_chance = tech_skill_factor × difficulty_modifier × quality_factor
	## Using a baseline tech skill of 4 (Regular) for the auto-calculation.
	var base_skill := 4.0
	var tech_factor := base_skill / 10.0

	var diff_mod := 1.0
	match difficulty:
		0: diff_mod = 1.2
		1: diff_mod = 1.0
		2: diff_mod = 0.8
		3: diff_mod = 0.5
		4: diff_mod = 0.3

	var qual_mod := 1.0
	match quality:
		Enums.Quality.A: qual_mod = 1.3
		Enums.Quality.B: qual_mod = 1.15
		Enums.Quality.C: qual_mod = 1.0
		Enums.Quality.D: qual_mod = 0.85
		Enums.Quality.E: qual_mod = 0.7
		Enums.Quality.F: qual_mod = 0.5

	var cond_mod := 1.0
	if condition == Enums.ComponentStatus.DAMAGED:
		cond_mod = 0.6
	elif condition == Enums.ComponentStatus.DESTROYED:
		cond_mod = 0.0

	return clampf(tech_factor * diff_mod * qual_mod * cond_mod, 0.0, 0.95)


func get_available_recovery_hours() -> int:
	var total := 0
	for p in PersonnelManager.get_personnel_by_role(Enums.PersonnelRole.TECHNICIAN):
		if p.is_available():
			total += PersonnelManager.get_repair_hours(p)
	total += PersonnelManager.abstract_astech_count * 4
	return total
