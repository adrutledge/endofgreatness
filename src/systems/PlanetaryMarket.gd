class_name PlanetaryMarket
extends Resource

var faction_codes: Array[String] = []
var target_faction: String = ""
var inventory: Dictionary = {}
var price_modifiers: Dictionary = {}
var refresh_counter: int = 0
var refresh_interval: int = 7

func setup(factions_on_planet: Array[String], exclude_faction: String = "") -> void:
	faction_codes = factions_on_planet.duplicate()
	target_faction = exclude_faction
	faction_codes.erase(exclude_faction)
	rebuild_inventory()

func rebuild_inventory() -> void:
	inventory.clear()
	price_modifiers.clear()
	var seen: Dictionary = {}

	if faction_codes.is_empty():
		for name in DataManager.component_defs:
			_add_to_inventory(name)
	else:
		for code in faction_codes:
			var items = DataManager.get_faction_market_components(code)
			for name in items:
				if not seen.has(name):
					seen[name] = true
					_add_to_inventory(name)

	_randomize_prices()

func _add_to_inventory(component_name: String) -> void:
	var def = DataManager.component_defs.get(component_name)
	if not def:
		return
	var base_qty = _base_stock(component_name, def)
	inventory[component_name] = {
		"name": component_name,
		"quantity": base_qty,
		"max_quantity": base_qty * 3,
		"cost": def.get("cost", 1000),
		"tech_level": def.get("tech_level", 1),
		"tonnage": def.get("tonnage", 0.0)
	}

func _base_stock(component_name: String, def: Dictionary) -> int:
	var cost = def.get("cost", 1000)
	var qty: int
	if cost <= 5000:
		qty = randi() % 20 + 10
	elif cost <= 50000:
		qty = randi() % 10 + 5
	elif cost <= 200000:
		qty = randi() % 5 + 2
	else:
		qty = randi() % 3 + 1
	if component_name.containsn("Ammo") or component_name == "Armor":
		qty *= 3
	return qty

func refresh() -> void:
	refresh_counter += 1
	if refresh_counter < refresh_interval:
		return
	refresh_counter = 0
	_randomize_quantities()
	_randomize_prices()

func _randomize_quantities() -> void:
	for name in inventory:
		var entry = inventory[name]
		var delta = randi() % 5 - 2
		entry.quantity = clampi(entry.quantity + delta, 0, entry.max_quantity)

func _randomize_prices() -> void:
	for name in inventory:
		var def = DataManager.component_defs.get(name)
		if not def:
			continue
		var base_cost = def.get("cost", 1000)
		var variation = randi() % 31 - 15
		price_modifiers[name] = 1.0 + (variation / 100.0)
		inventory[name].cost = int(base_cost * price_modifiers[name])

func get_available_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for name in inventory:
		if inventory[name].quantity > 0:
			result.append(inventory[name].duplicate())
	return result

func get_item(item_name: String) -> Dictionary:
	return inventory.get(item_name, {})

func buy(item_name: String, quantity: int) -> bool:
	var entry = inventory.get(item_name)
	if not entry or entry.quantity < quantity:
		return false
	entry.quantity -= quantity
	return true

func sell(item_name: String, quantity: int) -> void:
	var entry = inventory.get(item_name)
	if entry:
		entry.quantity += quantity
	else:
		var def = DataManager.component_defs.get(item_name)
		if def:
			inventory[item_name] = {
				"name": item_name,
				"quantity": quantity,
				"max_quantity": _base_stock(item_name, def) * 3,
				"cost": def.get("cost", 1000),
				"tech_level": def.get("tech_level", 1),
				"tonnage": def.get("tonnage", 0.0)
			}

func get_price(item_name: String) -> int:
	var entry = inventory.get(item_name)
	return entry.get("cost", 0) if entry else 0
