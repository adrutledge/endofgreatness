class_name TacticalUnit
extends Resource

@export var unit_name: String
@export var chassis_name: String = ""
@export var model_name: String = ""
@export var unit_type: Enums.UnitType
@export var engine_rating: int = 0
@export var engine_type: String = "Standard"
@export var gyro_type: String = "Standard"
@export var internal_structure_type: String = "Standard"
@export var armor_type: String = "Standard"
@export var total_armor_points: int = 0
@export var heat_sink_count: int = 10
@export var quality: Enums.Quality
@export var components: Array[Component] = []
@export var crew: Array[Personnel] = []
@export var ammo: Dictionary = {}
@export var tonnage: float
@export var movement_mp: int
@export var run_mp: int
@export var jump_mp: int
@export var assigned_technicians: Array[Personnel] = []

func requires_technician() -> bool:
	return unit_type != Enums.UnitType.INFANTRY

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

func get_total_component_tonnage() -> float:
	var total = 0.0
	for c in components:
		total += c.tonnage
	return total

func validate_tm() -> Dictionary:
	var errors: Array[String] = []
	var total_weight = get_total_component_tonnage()
	if total_weight > tonnage + 0.5:
		errors.append("Overweight: " + str(total_weight) + "t / " + str(tonnage) + "t")
	if engine_rating <= 0 and unit_type == Enums.UnitType.MECH:
		errors.append("Missing engine")
	if components.is_empty():
		errors.append("No components")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"used_tonnage": total_weight,
		"free_tonnage": max(0, tonnage - total_weight)
	}

func calculate_tm_cost() -> int:
	var component_total = 0
	for c in components:
		component_total += c.cost

	var chassis_cost = int(tonnage * 1600)
	match internal_structure_type.to_lower():
		"standard":
			chassis_cost = int(tonnage * 400)
		"endo steel", "endo":
			chassis_cost = int(tonnage * 1600)
		"reinforced":
			chassis_cost = int(tonnage * 2500)
		"composite":
			chassis_cost = int(tonnage * 3200)

	var total = component_total + chassis_cost
	total = int(total * 1.05)
	return max(total, 50000)
