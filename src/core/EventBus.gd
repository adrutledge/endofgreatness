extends Node

signal contract_accepted(contract: Contract)
signal combat_started(contract_id: String, hex_position: Vector2i)
signal tactical_engagement_started(contract: Contract, hex_data: Dictionary)
signal tactical_engagement_resolved(result: Dictionary)
signal time_tick(date: Dictionary)
signal unit_damaged(unit: TacticalUnit, component: Component)
signal reputation_changed(faction: String, new_value: int, reason: String)
signal personnel_joined(personnel: Personnel, reason: String, details: Dictionary)
signal personnel_left(personnel: Personnel, reason: String, details: Dictionary)
signal parse_error(resource_path: String, message: String)
signal rules_check(rule_id: String, parameters: Dictionary, result: Variant)
signal jump_completed(from_system: String, to_system: String, jumps_remaining: int)
signal contract_arrived(contract: Contract)
signal theme_changed(theme_name: String)
signal funds_depleted(balance: int)
signal delivery_arrived(item_name: String, quantity: int)
signal contract_completed(contract: Contract)
signal event_triggered(event_data: Dictionary)
signal bills_paid(amount: int, breakdown: Dictionary)
signal contract_settled(contract: Contract, settlement: Dictionary)
signal salvage_processed(contract: Contract, salvage_result: Dictionary)
signal day_started(date: Dictionary)
signal week_started(date: Dictionary)
signal month_started(date: Dictionary)
signal inventory_changed(item_name: String, quantity: int, source: String)
signal dispatch_completed(item_name: String, quantity: int, unit_name: String)
signal auto_reorder_triggered(orders_placed: int, total_cost: int)
signal funds_low_for_reorder(balance: int, required: int)

signal save_started()
signal save_completed(success: bool)
signal load_started()
signal load_completed(success: bool)

func emit_contract_accepted(contract: Contract) -> void:
	contract_accepted.emit(contract)

func emit_combat_started(contract_id: String, hex_position: Vector2i) -> void:
	combat_started.emit(contract_id, hex_position)

func emit_tactical_engagement_started(contract: Contract, hex_data: Dictionary) -> void:
	tactical_engagement_started.emit(contract, hex_data)

func emit_tactical_engagement_resolved(result: Dictionary) -> void:
	tactical_engagement_resolved.emit(result)

func emit_time_tick(date: Dictionary) -> void:
	time_tick.emit(date)

func emit_unit_damaged(unit: TacticalUnit, component: Component) -> void:
	unit_damaged.emit(unit, component)

func emit_reputation_changed(faction: String, new_value: int, reason: String) -> void:
	reputation_changed.emit(faction, new_value, reason)

func emit_personnel_joined(personnel: Personnel, reason: String, details: Dictionary = {}) -> void:
	personnel_joined.emit(personnel, reason, details)

func emit_personnel_left(personnel: Personnel, reason: String, details: Dictionary = {}) -> void:
	personnel_left.emit(personnel, reason, details)

func emit_parse_error(resource_path: String, message: String) -> void:
	parse_error.emit(resource_path, message)

func emit_rules_check(rule_id: String, parameters: Dictionary, result = null) -> void:
	rules_check.emit(rule_id, parameters, result)

func emit_jump_completed(from_system: String, to_system: String, jumps_remaining: int) -> void:
	jump_completed.emit(from_system, to_system, jumps_remaining)

func emit_contract_arrived(contract: Contract) -> void:
	contract_arrived.emit(contract)

func emit_theme_changed(theme_name: String) -> void:
	theme_changed.emit(theme_name)

func emit_funds_depleted(balance: int) -> void:
	funds_depleted.emit(balance)

func emit_delivery_arrived(item_name: String, quantity: int) -> void:
	delivery_arrived.emit(item_name, quantity)

func emit_contract_completed(contract: Contract) -> void:
	contract_completed.emit(contract)

func emit_event_triggered(event_data: Dictionary) -> void:
	event_triggered.emit(event_data)

func emit_bills_paid(amount: int, breakdown: Dictionary) -> void:
	bills_paid.emit(amount, breakdown)

func emit_contract_settled(contract: Contract, settlement: Dictionary) -> void:
	contract_settled.emit(contract, settlement)

func emit_day_started(date: Dictionary) -> void:
	day_started.emit(date)

func emit_week_started(date: Dictionary) -> void:
	week_started.emit(date)

func emit_month_started(date: Dictionary) -> void:
	month_started.emit(date)

func emit_inventory_changed(item_name: String, quantity: int, source: String) -> void:
	inventory_changed.emit(item_name, quantity, source)

func emit_dispatch_completed(item_name: String, quantity: int, unit_name: String) -> void:
	dispatch_completed.emit(item_name, quantity, unit_name)

func emit_auto_reorder_triggered(orders_placed: int, total_cost: int) -> void:
	auto_reorder_triggered.emit(orders_placed, total_cost)

func emit_funds_low_for_reorder(balance: int, required: int) -> void:
	funds_low_for_reorder.emit(balance, required)

func emit_save_started() -> void:
	save_started.emit()

func emit_save_completed(success: bool) -> void:
	save_completed.emit(success)

func emit_load_started() -> void:
	load_started.emit()

func emit_load_completed(success: bool) -> void:
	load_completed.emit(success)
