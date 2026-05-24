class_name OrganizationalUnit
extends Resource

@export var unit_name: String
@export var commander: Personnel
@export var sub_units: Array[OperationalUnit]
@export var contract_id: String = ""

func get_all_tactical_units() -> Array[TacticalUnit]:
	var result: Array[TacticalUnit] = []
	for ou in sub_units:
		result.append_array(ou.get_all_tactical_units())
	return result

func get_unit_counts_by_type() -> Dictionary:
	var counts: Dictionary = {}
	for tu in get_all_tactical_units():
		var key = Enums.UnitType.keys()[tu.unit_type]
		counts[key] = counts.get(key, 0) + 1
	return counts
