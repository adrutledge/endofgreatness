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
