extends Node

var player: StrategicUnit
var factions: Dictionary = {}
var known_systems: Dictionary = {}
var active_contracts: Array[Contract] = []
var pending_deliveries: Array[Dictionary] = []
var event_log: Array[Dictionary] = []

## Player's physical inventory of spare parts, ammo, armor, etc.
## Key = component name (String), value = { "quantity": int, "component_name": String }
var player_inventory: Dictionary = {}

func _ready() -> void:
	player = StrategicUnit.new()

func register_faction(faction: Faction) -> void:
	factions[faction.short_code] = faction

func get_faction(code: String) -> Faction:
	return factions.get(code)

func add_active_contract(contract: Contract) -> void:
	contract.is_active = true
	active_contracts.append(contract)
	EventBus.emit_contract_accepted(contract)

func complete_contract(contract: Contract) -> void:
	contract.is_active = false
	contract.is_completed = true
	active_contracts.erase(contract)
	EventBus.emit_contract_completed(contract)

func add_delivery(item_name: String, quantity: int, eta_tick: int) -> void:
	pending_deliveries.append({
		"item": item_name,
		"quantity": quantity,
		"eta_tick": eta_tick,
		"completed": false
	})

func process_deliveries(current_tick: int) -> void:
	for delivery in pending_deliveries:
		if not delivery.completed and current_tick >= delivery.eta_tick:
			delivery.completed = true
			EventBus.emit_delivery_arrived(delivery.item, delivery.quantity)
	pending_deliveries = pending_deliveries.filter(func(d): return not d.completed)

func log_event(event_type: String, data: Dictionary) -> void:
	event_log.append({
		"type": event_type,
		"data": data,
		"date": TimeManager.get_date_string()
	})
	if event_log.size() > 500:
		event_log.pop_front()
