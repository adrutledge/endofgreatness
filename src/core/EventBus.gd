extends Node

signal contract_accepted(contract: Contract)
signal combat_started(contract_id: String, hex_position: Vector2i)
signal time_tick(date: Dictionary)
signal unit_damaged(unit: TacticalUnit, component: Component)
signal reputation_changed(faction: String, new_value: int, reason: String)
signal personnel_hired(personnel: Personnel)
signal theme_changed(theme_name: String)
signal funds_depleted(balance: int)
signal delivery_arrived(item_name: String, quantity: int)
signal contract_completed(contract: Contract)
signal event_triggered(event_data: Dictionary)
signal bills_paid(amount: int, breakdown: Dictionary)
signal contract_settled(contract: Contract, settlement: Dictionary)

func emit_contract_accepted(contract: Contract) -> void:
	contract_accepted.emit(contract)

func emit_combat_started(contract_id: String, hex_position: Vector2i) -> void:
	combat_started.emit(contract_id, hex_position)

func emit_time_tick(date: Dictionary) -> void:
	time_tick.emit(date)

func emit_unit_damaged(unit: TacticalUnit, component: Component) -> void:
	unit_damaged.emit(unit, component)

func emit_reputation_changed(faction: String, new_value: int, reason: String) -> void:
	reputation_changed.emit(faction, new_value, reason)

func emit_personnel_hired(personnel: Personnel) -> void:
	personnel_hired.emit(personnel)

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
