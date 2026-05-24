class_name TacticalUnit
extends Resource

@export var unit_name: String
@export var unit_type: Enums.UnitType
@export var quality: Enums.Quality
@export var components: Array[Component]
@export var crew: Array[Personnel]
@export var ammo: Dictionary
@export var tonnage: float
@export var movement_mp: int
@export var run_mp: int
@export var jump_mp: int

func get_damaged_components() -> Array[Component]:
	var result: Array[Component] = []
	for c in components:
		if c.status != Enums.ComponentStatus.UNDAMAGED:
			result.append(c)
	return result

func get_destroyed_components() -> Array[Component]:
	var result: Array[Component] = []
	for c in components:
		if c.status == Enums.ComponentStatus.DESTROYED:
			result.append(c)
	return result
