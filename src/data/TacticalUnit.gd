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
@export var slot_free_heat_sinks: int = 10
@export var weight_free_heat_sinks: int = 10

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


func get_armor_weight() -> float:
	match armor_type.to_lower():
		"ferro-fibrous", "ferro":
			return total_armor_points / 14.5
		"light ferro", "light ferro-fibrous":
			return total_armor_points / 16.0
		"heavy ferro", "heavy ferro-fibrous":
			return total_armor_points / 12.5
		_:
			return total_armor_points / 16.0


func get_structure_weight() -> float:
	match internal_structure_type.to_lower():
		"endo steel", "endo":
			return tonnage * 0.05
		"reinforced":
			return tonnage * 0.15
		"composite":
			return tonnage * 0.05
		_:
			return tonnage * 0.10


func get_weight_free_heat_sink_count() -> int:
	return 10


func get_hs_weight_adjustment() -> float:
	if unit_type != Enums.UnitType.MECH:
		return 0.0
	var weight_free := get_weight_free_heat_sink_count()
	var weight_bearing: int = max(0, heat_sink_count - weight_free)
	var in_components := 0.0
	for c in components:
		var n = c.component_name.to_lower()
		if n == "heat sink" or n == "double heat sink" or n == "single heat sink":
			in_components += c.tonnage
	var hs_adj: float = float(weight_bearing) - in_components
	return hs_adj


func validate_tm() -> Dictionary:
	var errors: Array[String] = []
	var comp_weight = get_total_component_tonnage()
	var armor_weight = get_armor_weight()
	var structure_weight = get_structure_weight()
	var hs_adj = get_hs_weight_adjustment()
	var total_weight = comp_weight + armor_weight + structure_weight + hs_adj

	var diff = total_weight - tonnage
	if abs(diff) > 0.05:
		errors.append("Weight mismatch: %.1ft / %dt (%.1f = comp %.1f + armor %.1f + struct %.1f + hs_adj %.1f)" % [total_weight, tonnage, diff, comp_weight, armor_weight, structure_weight, hs_adj])
	if engine_rating <= 0 and unit_type == Enums.UnitType.MECH:
		errors.append("Missing engine")
	if components.is_empty():
		errors.append("No components")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"used_tonnage": total_weight,
		"free_tonnage": max(0, tonnage - total_weight),
		"comp_tonnage": comp_weight,
		"armor_tonnage": armor_weight,
		"structure_tonnage": structure_weight,
		"hs_adjustment": hs_adj,
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
