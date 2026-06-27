class_name TacticalUnit
extends Resource

@export var unit_id: String = ""

static var _uid_counter: int = 0

func _init() -> void:
	if unit_id.is_empty():
		_uid_counter += 1
		unit_id = "tu_%08x" % _uid_counter

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
@export var motion_type: String = ""
@export var abstract_crew_count: int = 0
@export var rules_level: int = 1
@export var era: int = 3025
@export var customization_history: Array[Dictionary] = []

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
	return TacticalUnitValidator.validate(self)


func calculate_tm_cost() -> int:
	return TacticalUnitValidator.calculate_tm_cost(self)
