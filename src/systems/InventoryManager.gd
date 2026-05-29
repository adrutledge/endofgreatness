extends Node

var _spares_config: Dictionary = {}
var _config_path: String = "res://data/config/spares_config.json"

var in_transit: Dictionary = {}
var _last_auto_reorder_day: int = -1


func _ready() -> void:
	_load_config()
	TimeManager.date_changed.connect(_on_date_changed)


func _load_config() -> void:
	var file = FileAccess.open(_config_path, FileAccess.READ)
	if not file:
		return
	var j = JSON.new()
	if j.parse(file.get_as_text()) == OK:
		_spares_config = j.data


func get_config(key: String, default = null):
	return _spares_config.get(key, default)


func _on_date_changed(date: Dictionary) -> void:
	if not _spares_config.get("auto_reorder_enabled", false):
		return

	var today = TimeManager.total_days
	if today - _last_auto_reorder_day < 7:
		return
	_last_auto_reorder_day = today

	_process_auto_reorder()


func get_deployed_opus() -> Array[OperationalUnit]:
	var result: Array[OperationalUnit] = []
	for ou in GameState.player.organizational_units:
		for opu in ou.sub_units:
			if opu.is_deployed:
				result.append(opu)
	return result


func dispatch_to_unit(comp_name: String, qty: int, opu: OperationalUnit) -> bool:
	var current = GameState.player_inventory.get(comp_name, 0)
	if qty <= 0 or qty > current:
		return false

	GameState.player_inventory[comp_name] = current - qty
	if GameState.player_inventory[comp_name] <= 0:
		GameState.player_inventory.erase(comp_name)

	opu.deployment_cache[comp_name] = opu.deployment_cache.get(comp_name, 0) + qty
	EventBus.emit_dispatch_completed(comp_name, qty, opu.unit_name)
	EventBus.emit_inventory_changed(comp_name, -qty, "dispatch_to:" + opu.unit_name)
	return true


func recover_from_unit(comp_name: String, qty: int, opu: OperationalUnit) -> bool:
	var current = opu.deployment_cache.get(comp_name, 0)
	if qty <= 0 or qty > current:
		return false

	opu.deployment_cache[comp_name] = current - qty
	if opu.deployment_cache[comp_name] <= 0:
		opu.deployment_cache.erase(comp_name)

	GameState.player_inventory[comp_name] = GameState.player_inventory.get(comp_name, 0) + qty
	EventBus.emit_inventory_changed(comp_name, qty, "recover_from:" + opu.unit_name)
	return true


func recover_all_from_unit(opu: OperationalUnit) -> int:
	var total := 0
	for comp_name in opu.deployment_cache.keys():
		var qty = opu.deployment_cache[comp_name]
		GameState.player_inventory[comp_name] = GameState.player_inventory.get(comp_name, 0) + qty
		total += qty
	opu.deployment_cache.clear()
	if total > 0:
		EventBus.emit_inventory_changed("", total, "recover_all_from:" + opu.unit_name)
	return total


func track_in_transit(comp_name: String, qty: int, eta_day: int, target_opu: OperationalUnit) -> void:
	var key = comp_name + "|" + target_opu.unit_name
	in_transit[key] = {
		"item": comp_name,
		"quantity": qty,
		"eta_day": eta_day,
		"opu": target_opu,
	}


func _process_in_transit() -> void:
	var today = TimeManager.total_days
	var arrived: Array[String] = []
	for key in in_transit:
		var entry = in_transit[key]
		if today >= entry.eta_day:
			entry.opu.deployment_cache[entry.item] = entry.opu.deployment_cache.get(entry.item, 0) + entry.quantity
			EventBus.emit_inventory_changed(entry.item, entry.quantity, "in_transit_arrived:" + entry.opu.unit_name)
			arrived.append(key)
	for key in arrived:
		in_transit.erase(key)


func _process_auto_reorder() -> void:
	if not _spares_config.get("auto_reorder_enabled", false):
		return

	var min_stock = _spares_config.get("auto_reorder_min_stock", 0)
	var target_stock = _spares_config.get("auto_reorder_target_stock", 0)
	if min_stock <= 0 or target_stock <= 0:
		return

	var per_unit = _spares_config.get("per_unit_inventory_enabled", false)
	var max_cost = _spares_config.get("auto_reorder_max_cost_per_order", 500000)
	var min_balance = _spares_config.get("auto_reorder_min_balance", 100000)

	var balance = EconomySystem.get_balance()
	if balance < min_balance:
		EventBus.emit_funds_low_for_reorder(balance, min_balance)
		return

	var market = EconomySystem.current_market
	var total_cost := 0
	var orders_placed := 0

	var targets: Array = []
	if per_unit:
		targets = get_deployed_opus()
	else:
		targets.append(null)

	for target_opu in targets:
		if total_cost >= max_cost:
			break

		var inv: Dictionary = GameState.player_inventory if target_opu == null else target_opu.deployment_cache
		var all_component_names: Dictionary = {}
		for cname in inv:
			all_component_names[cname] = true
		for cname in GameState.player_inventory:
			all_component_names[cname] = true

		for comp_name in all_component_names:
			if total_cost >= max_cost:
				break

			var current_qty := 0
			if target_opu != null:
				current_qty = target_opu.deployment_cache.get(comp_name, 0)
			else:
				current_qty = GameState.player_inventory.get(comp_name, 0)

			if current_qty >= min_stock:
				continue

			var shortfall = target_stock - current_qty
			if shortfall <= 0:
				continue

			var remaining = shortfall

			if target_opu != null:
				var global_qty = GameState.player_inventory.get(comp_name, 0)
				var dispatch_qty = min(remaining, global_qty)
				if dispatch_qty > 0:
					dispatch_to_unit(comp_name, dispatch_qty, target_opu)
					remaining -= dispatch_qty
					if remaining <= 0:
						continue

			var item = market.get_item(comp_name)
			if item and item.quantity > 0:
				var local_qty = min(remaining, item.quantity)
				var local_cost = local_qty * item.cost
				if total_cost + local_cost <= max_cost and EconomySystem.buy_item(comp_name, local_qty):
					remaining -= local_qty
					total_cost += local_cost
					if target_opu != null:
						target_opu.deployment_cache[comp_name] = target_opu.deployment_cache.get(comp_name, 0) + local_qty
					else:
						GameState.player_inventory[comp_name] = GameState.player_inventory.get(comp_name, 0) + local_qty

			if remaining > 0:
				var sources = EconomySystem.search_remote_sources(comp_name)
				if sources.is_empty():
					continue
				var source = sources[0]
				var order_qty = min(remaining, source.quantity)
				var order_cost = order_qty * source.cost_per_unit
				if total_cost + order_cost > max_cost:
					order_qty = max(1, (max_cost - total_cost) / source.cost_per_unit)
					order_cost = order_qty * source.cost_per_unit
				if order_qty > 0 and EconomySystem.order_item(comp_name, order_qty, source.cost_per_unit, source.source_system, source.travel_days):
					orders_placed += 1
					total_cost += order_cost
					if target_opu != null:
						target_opu.deployment_cache[comp_name] = target_opu.deployment_cache.get(comp_name, 0) + order_qty
					else:
						GameState.player_inventory[comp_name] = GameState.player_inventory.get(comp_name, 0) + order_qty

	if orders_placed > 0 or total_cost > 0:
		EventBus.emit_auto_reorder_triggered(orders_placed, total_cost)


func has_logistics_difficulty(contract: Contract) -> bool:
	if not _spares_config.get("logistics_difficulty_enabled", false):
		return false
	var hard_types = _spares_config.get("logistics_difficulty_contract_types", ["assault", "raid"])
	return contract.activity_type.to_lower() in hard_types


func has_independent_command_logistics_restriction(contract: Contract) -> bool:
	if not _spares_config.get("independent_command_logistics_enabled", false):
		return false
	return contract.command_rights == Enums.CommandRights.INDEPENDENT


func can_access_employer_market(contract: Contract) -> bool:
	if has_independent_command_logistics_restriction(contract):
		return false
	return true
