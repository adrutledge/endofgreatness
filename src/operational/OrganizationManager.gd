class_name OrganizationManager
extends Node


static func validate_hierarchy(org_unit: OrganizationalUnit) -> bool:
	var seen: Dictionary = {}
	for ou in org_unit.sub_units:
		if not _validate_unit(ou, seen):
			return false
	return true


static func _validate_unit(unit: OperationalUnit, seen: Dictionary) -> bool:
	var id = unit.get_instance_id()
	if seen.has(id):
		return false
	seen[id] = true
	for sub in unit.sub_units:
		if not _validate_unit(sub, seen):
			return false
	return true


static func deploy_unit(org_unit: OrganizationalUnit, contract: Contract) -> Dictionary:
	var result = {success = false, errors = []}

	if org_unit.contract_id != "":
		result.errors.append("Unit already assigned to contract " + org_unit.contract_id)
		return result

	var shortfalls = get_deployment_shortfalls(org_unit, contract)
	if not shortfalls.is_empty():
		result.errors.append("Minimum unit requirements not met: " + str(shortfalls))
		return result

	for ou in org_unit.sub_units:
		_set_deployed_recursive(ou, contract)

	org_unit.contract_id = contract.resource_path
	result.success = true
	return result


static func _set_deployed_recursive(unit: OperationalUnit, contract: Contract) -> void:
	unit.contract_id = contract.resource_path
	unit.is_deployed = true
	unit.current_planet = contract.planet
	for sub in unit.sub_units:
		_set_deployed_recursive(sub, contract)


static func get_deployment_shortfalls(org_unit: OrganizationalUnit, contract: Contract) -> Dictionary:
	var have = org_unit.get_unit_counts_by_type()
	var need = contract.minimum_tactical_unit_counts
	var shortfalls: Dictionary = {}
	for type_str in need:
		var required: int = need[type_str]
		var available: int = have.get(type_str, 0)
		if available < required:
			shortfalls[type_str] = required - available
	return shortfalls


static func get_units_by_planet(org_units: Array, planet_name: String) -> Array[OrganizationalUnit]:
	var result: Array[OrganizationalUnit] = []
	for ou in org_units:
		if _has_unit_on_planet(ou, planet_name):
			result.append(ou)
	return result


static func _has_unit_on_planet(org_unit: OrganizationalUnit, planet_name: String) -> bool:
	for ou in org_unit.sub_units:
		if _check_planet_recursive(ou, planet_name):
			return true
	return false


static func _check_planet_recursive(unit: OperationalUnit, planet_name: String) -> bool:
	if unit.current_planet == planet_name:
		return true
	for sub in unit.sub_units:
		if _check_planet_recursive(sub, planet_name):
			return true
	return false


static func get_units_in_transit(org_units: Array) -> Array[OrganizationalUnit]:
	var result: Array[OrganizationalUnit] = []
	for ou in org_units:
		if ou.contract_id != "" and not _is_any_deployed(ou):
			result.append(ou)
	return result


static func _is_any_deployed(org_unit: OrganizationalUnit) -> bool:
	for ou in org_unit.sub_units:
		if _check_deployed_recursive(ou):
			return true
	return false


static func _check_deployed_recursive(unit: OperationalUnit) -> bool:
	if unit.is_deployed:
		return true
	for sub in unit.sub_units:
		if _check_deployed_recursive(sub):
			return true
	return false


static func reassign_unit(parent: OrganizationalUnit, unit: OperationalUnit, new_parent: OrganizationalUnit) -> bool:
	var removed = false
	for i in range(parent.sub_units.size()):
		if parent.sub_units[i] == unit:
			parent.sub_units.remove_at(i)
			removed = true
			break
	if not removed:
		return false
	new_parent.sub_units.append(unit)
	return true


## Computes one-way transport MP cost to deploy the given org unit to a contract planet.
static func compute_transport_cost(org_unit: OrganizationalUnit, contract: Contract) -> Dictionary:
	if not UnitTransportManager:
		return {"cost": 0, "jumps": 0, "tonnage_total": 0.0}

	var tonnages: Array[float] = []
	for tu in org_unit.get_all_tactical_units():
		tonnages.append(tu.tonnage)
	var total_tonnage: float = 0.0
	for t in tonnages:
		total_tonnage += t

	var player_planet = GameState.player.current_planet if GameState and GameState.player else ""
	var jumps = UnitTransportManager.jumps_between(player_planet, contract.planet)
	var cost = UnitTransportManager.calculate_fleet_transport_cost(tonnages, jumps)
	return {"cost": cost, "jumps": jumps, "tonnage_total": total_tonnage}


## Shows a deploy confirmation dialog and handles the deploy + transport flow.
## caller: the Node to parent the dialog to (must be in scene tree)
## contract: the Contract to deploy to
## on_deployed: Callable(contract) — invoked after successful deploy (e.g. to trigger travel)
static func T(msg: String) -> String:
	return TranslationServer.translate(msg)


static func show_deploy_dialog(caller: Node, contract: Contract, on_deployed: Callable) -> void:
	if GameState.player.organizational_units.is_empty():
		_show_message(caller, T("No organizational units to deploy."))
		return

	var available: Array[OrganizationalUnit] = []
	for ou in GameState.player.organizational_units:
		if ou.contract_id.is_empty():
			available.append(ou)

	if available.is_empty():
		_show_message(caller, T("All organizational units are already assigned to contracts."))
		return

	var dialog := AcceptDialog.new()
	dialog.title = T("Deploy to %s") % contract.planet
	dialog.min_size = Vector2i(420, 280)
	dialog.ok_button_text = T("Deploy & Pay Transport")
	dialog.dialog_text = ""

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var selector_label := Label.new()
	selector_label.text = T("Select Organizational Unit:")
	vbox.add_child(selector_label)

	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for ou in available:
		var label = ou.unit_name
		var tu_count = ou.get_all_tactical_units().size()
		label += T("  (%d tactical units)") % tu_count
		selector.add_item(label)
		selector.set_item_metadata(selector.item_count - 1, ou)
	vbox.add_child(selector)

	var info_label := Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)

	dialog.add_child(vbox)

	var _update_info := func():
		var idx = selector.selected
		if idx < 0 or idx >= available.size():
			return
		var ou = available[idx]
		var cost_info = compute_transport_cost(ou, contract)
		var balance = EconomySystem.get_balance() if EconomySystem else 0
		var text = ""
		text += T("Tonnage: %.0f tons") % cost_info.tonnage_total + "\n"
		text += T("Jumps: %d") % cost_info.jumps + "\n"
		text += T("Transport cost: %s") % Helpers.fmt_money(cost_info.cost) + "\n"
		text += T("Your balance: %s") % Helpers.fmt_money(balance) + "\n"
		if cost_info.cost > balance:
			text += "\n[color=#ff4444]" + T("WARNING: Insufficient funds — will overdraw") + "[/color]"
		info_label.text = text

	selector.item_selected.connect(func(_idx): _update_info.call())
	_update_info.call()

	dialog.confirmed.connect(func():
		var idx = selector.selected
		if idx < 0 or idx >= available.size():
			return
		var ou = available[idx]
		var cost_info = compute_transport_cost(ou, contract)
		if EconomySystem and cost_info.cost > 0:
			EconomySystem.deduct_funds(cost_info.cost, "Transport to " + contract.planet)
		deploy_unit(ou, contract)
		if SaveManager:
			SaveManager._on_deploy()
		dialog.queue_free()
		on_deployed.call(contract)
	)

	dialog.canceled.connect(func():
		dialog.queue_free()
	)

	caller.add_child(dialog)
	dialog.popup_centered()


static func _show_message(caller: Node, msg: String) -> void:
	var d := AcceptDialog.new()
	d.title = T("Deployment")
	d.dialog_text = msg
	d.min_size = Vector2i(300, 120)
	caller.add_child(d)
	d.popup_centered()
