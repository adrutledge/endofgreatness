class_name TacticalUnitValidator
extends RefCounted

## Advanced tech preparation — component JSON fields (optional, all default to standard values):
##
##   "weight_multiplier": 0.5           # Endo Steel: internal structure weight × 0.5
##   "armor_multiplier": 1.12           # Ferro-Fibrous: armor points per ton × 1.12
##   "slot_flexible": true              # Endo Steel, Ferro-Fibrous: slots are a tax on total capacity,
##                                      # not tied to any specific location. Validator must check:
##                                      #   sum(flexible slots) <= sum(free slots across all locations)
##                                      #   AND no single location exceeds its limit from fixed components alone.
##   "engine_weight_multiplier": 0.5    # XL engine: engine weight × 0.5 (XXL=0.25, Light=0.75, Compact=1.5)
##   "engine_slot_locations": ["Left Torso", "Right Torso"]  # XL: engine slots in side torsos
##   "engine_slots_per_location": 3     # XL: 3 slots per side torso (total 6 outside center)
##   "gyro_slots": 6                    # XL gyro: 6 slots (Compact=2, Heavy=3)
##   "gyro_weight_multiplier": 1.0      # Standard=1.0, XL=0.5, Heavy=1.5, Compact=0.5
##   "heat_sink_capacity": 2.0          # Double heat sink: sinks 2 heat instead of 1
##   "heat_sink_weight": 1.0            # Double heat sink: weighs 1 ton (standard=1, DHS=1, Clan DHS=0.5)
##   "heat_sink_slots": 3               # Double heat sink: takes 3 slots (standard=1, IS DHS=3, Clan DHS=2)
##   "heat_generation": 0               # Extra heat per turn this component produces (XXL engine: +X heat)
##                                      # Negative values represent improved cooling (e.g., improved heat sink)
##   "ammo_type": "SRM"                 # Base weapon this ammo is for (SRM, LRM, AC/5, MG, etc.)
##   "ammo_sub_type": "inferno"         # Variant: standard, inferno, smoke, precision, tracer, etc.
##                                      # Each ammo bin holds one sub_type. Mixing sub_types in one bin is invalid.
##   "shots_per_ton": 100               # Shots per ton of ammo. Defaults per weapon type (SRM-2/4/6 = 50/25/15, etc.).
##   "pool_group": "SRM"                # When set, ammo of the same (pool_group, ammo_sub_type) across all bins is
##                                      # merged into one inventory pool for purchasing and consumption tracking.
##                                      # Built-in: SRM-2/4/6 pool_group="SRM", LRM-5/10/15/20 pool_group="LRM",
##                                      # SRT-2/4/6 pool_group="SRT", LRT-5/10/15/20 pool_group="LRT".
##                                      # Each sub_type is its own separate pool within the group.
##                                      # Different sub_types may have different shots/ton.
##
## When these fields are populated in component JSONs, the validator should:
##   - Read component defs from DataManager for each component on the unit
##   - Apply weight multipliers to the relevant weight category (structure, armor, engine, gyro, HS)
##   - Sum flexible-slot components separately, then check total free slots >= total flexible slots
##   - Validate fixed-slot components individually (e.g., XL engine slots must be in side torsos)
##   - Warn if a component def is expected but not found (e.g., missing gyro entry with custom gyro_slots)
##
## Reference: "Advanced Tech (post-3025/Lostech)" in ai/plan.md

static var _registry: Dictionary = {}
static var _registry_ready: bool = false


static func _ensure_registry() -> void:
	if _registry_ready:
		return
	_registry_ready = true
	_registry[Enums.UnitType.MECH] = MechValidator.new()
	_registry[Enums.UnitType.VEHICLE] = VehicleValidator.new()


static func register_validator(type: int, validator: UnitValidator) -> void:
	_ensure_registry()
	_registry[type] = validator


static func validate(tu: TacticalUnit) -> Dictionary:
	_ensure_registry()
	var result := _run_common_checks(tu)
	var errors: Array = result.get("errors", [])
	var warnings: Array = result.get("warnings", [])

	if tu.unit_type == Enums.UnitType.INFANTRY:
		return {"valid": true, "errors": [], "warnings": [], "used_tonnage": 0.0, "free_tonnage": 0.0}

	var type_result = _run_type_checks(tu)
	if type_result.has("errors"):
		errors.append_array(type_result.errors)
	if type_result.has("warnings"):
		warnings.append_array(type_result.warnings)

	var comp_weight = tu.get_total_component_tonnage()
	var armor_weight = tu.get_armor_weight()
	var structure_weight = tu.get_structure_weight()
	var hs_adj = tu.get_hs_weight_adjustment()
	var total_weight = comp_weight + armor_weight + structure_weight + hs_adj

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"used_tonnage": total_weight,
		"free_tonnage": max(0, tu.tonnage - total_weight),
		"comp_tonnage": comp_weight,
		"armor_tonnage": armor_weight,
		"structure_tonnage": structure_weight,
		"hs_adjustment": hs_adj,
	}


static func _run_common_checks(tu: TacticalUnit) -> Dictionary:
	var errors: Array[String] = []
	var comp_weight = tu.get_total_component_tonnage()
	var armor_weight = tu.get_armor_weight()
	var structure_weight = tu.get_structure_weight()
	var hs_adj = tu.get_hs_weight_adjustment()
	var total_weight = comp_weight + armor_weight + structure_weight + hs_adj

	var diff = total_weight - tu.tonnage
	if abs(diff) > 0.05:
		errors.append("Weight mismatch: %.1ft / %dt (%.1f = comp %.1f + armor %.1f + struct %.1f + hs_adj %.1f)" % [total_weight, tu.tonnage, diff, comp_weight, armor_weight, structure_weight, hs_adj])

	if tu.engine_rating <= 0 and tu.unit_type != Enums.UnitType.INFANTRY:
		errors.append("Missing engine")

	if tu.components.is_empty():
		errors.append("No components")

	return {"errors": errors}


static func _run_type_checks(tu: TacticalUnit) -> Dictionary:
	if not _registry.has(tu.unit_type):
		return {}
	var validator = _registry[tu.unit_type]
	return validator.validate(tu)


static func calculate_tm_cost(tu: TacticalUnit) -> int:
	var component_total = 0
	for c in tu.components:
		component_total += c.cost

	var chassis_cost = int(tu.tonnage * 1600)
	match tu.internal_structure_type.to_lower():
		"standard":
			chassis_cost = int(tu.tonnage * 400)
		"endo steel", "endo":
			chassis_cost = int(tu.tonnage * 1600)
		"reinforced":
			chassis_cost = int(tu.tonnage * 2500)
		"composite":
			chassis_cost = int(tu.tonnage * 3200)

	var total = component_total + chassis_cost
	total = int(total * 1.05)
	return max(total, 50000)


static func _is_ammo(name: String) -> bool:
	var n = name.to_lower()
	return "ammo" in n


static func _is_ammo_weapon(name: String) -> bool:
	var n = name.to_lower()
	var patterns = ["autocannon/", "lrm-", "srm-", "lrt-", "srt-", "machine gun"]
	for p in patterns:
		if n.begins_with(p):
			return true
	return false


static func _ammo_base_weapon(name: String) -> String:
	var n = name.to_lower().strip_edges()
	if n.ends_with(" (r)"):
		n = n.substr(0, n.length() - 4).strip_edges()

	var ammo_map := {
		"is ammo ac/2": "Autocannon/2",
		"is ammo ac/5": "Autocannon/5",
		"is ammo ac/10": "Autocannon/10",
		"is ammo ac/20": "Autocannon/20",
		"is ammo lrm-5": "LRM-5",
		"is ammo lrm-10": "LRM-10",
		"is ammo lrm-15": "LRM-15",
		"is ammo lrm-20": "LRM-20",
		"is ammo srm-2": "SRM-2",
		"is ammo srm-4": "SRM-4",
		"is ammo srm-6": "SRM-6",
		"machine gun ammo": "Machine Gun",
		"machine gun ammo - half": "Machine Gun",
		"srt-6 ammo": "SRT-6",
		"lrt-5 ammo": "LRT-5",
		"lrt-10 ammo": "LRT-10",
		"lrt-15 ammo": "LRT-15",
		"lrt-20 ammo": "LRT-20",
		"vehicle flamer ammo": "Vehicle Flamer",
	}

	if n in ammo_map:
		return ammo_map[n]

	if _is_ammo_weapon(name):
		for prefix in ["autocannon/", "lrm-", "srm-", "lrt-", "srt-"]:
			if n.begins_with(prefix):
				return name
		if n == "machine gun" or n == "machine gun (vehicle)":
			return "Machine Gun"
	return ""


static func get_suspension_factor(mtype: String, veh_tonnage: float) -> int:
	var data = load_suspension_factors()
	var entry = data.get(mtype)
	if entry == null:
		return 0
	if entry is int:
		return entry
	if entry is Array:
		for bracket in entry:
			if veh_tonnage <= float(bracket.get("max_tonnage", 999)):
				return bracket.get("factor", 0)
	return 0


static var _suspension_cache = null
static func load_suspension_factors() -> Dictionary:
	if _suspension_cache != null:
		return _suspension_cache
	var file = FileAccess.open("res://data/rules/suspension_factors.json", FileAccess.READ)
	if not file:
		_suspension_cache = {}
		return _suspension_cache
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK:
		_suspension_cache = {}
		return _suspension_cache
	_suspension_cache = j.data
	return _suspension_cache
