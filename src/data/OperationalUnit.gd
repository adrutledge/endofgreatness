class_name OperationalUnit
extends Resource

@export var unit_name: String
@export var commander: Personnel
@export var tactical_units: Array[TacticalUnit] = []
@export var sub_units: Array[OperationalUnit] = []
@export var role: String
@export var current_planet: String = ""
@export var contract_id: String = ""
@export var is_deployed: bool = false
@export var hex_position: Vector2i

func get_all_tactical_units() -> Array[TacticalUnit]:
	var result: Array[TacticalUnit] = []
	result.append_array(tactical_units)
	for sub in sub_units:
		result.append_array(sub.get_all_tactical_units())
	return result

func get_unit_counts_by_type() -> Dictionary:
	var counts: Dictionary = {}
	for tu in get_all_tactical_units():
		var key = Enums.UnitType.keys()[tu.unit_type]
		counts[key] = counts.get(key, 0) + 1
	return counts
