class_name StrategicUnit
extends Resource

@export var unit_name: String = "Player"
@export var organizational_units: Array[OrganizationalUnit] = []
@export var current_balance: int = 1000000
@export var current_planet: String = ""
@export var active_contract: Contract = null

func get_all_personnel() -> Array[Personnel]:
	var result: Array[Personnel] = []
	for ou in organizational_units:
		for pu in ou.get_all_tactical_units():
			result.append_array(pu.crew)
		for su in ou.sub_units:
			result.append(su.commander)
	return result
