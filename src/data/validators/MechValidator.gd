class_name MechValidator
extends UnitValidator


func validate(tu: TacticalUnit) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	_validate_engine_rating(tu, errors)
	_validate_slot_limits(tu, errors)
	_validate_armor_limits(tu, errors)
	_validate_ammo(tu, warnings)
	_validate_gyro(tu, errors)
	_validate_heat_sinks(tu, errors)

	return {"valid": errors.is_empty(), "errors": errors, "warnings": warnings}


func _validate_engine_rating(tu: TacticalUnit, errors: Array) -> void:
	if tu.movement_mp > 0 and tu.tonnage > 0:
		var expected = int(tu.movement_mp * tu.tonnage)
		if tu.engine_rating != expected:
			errors.append("Engine rating mismatch: %d expected from walk %d × %dt, got %d" % [expected, tu.movement_mp, int(tu.tonnage), tu.engine_rating])


func _validate_slot_limits(tu: TacticalUnit, errors: Array) -> void:
	var slot_limits := {
		"Head": 6, "Center Torso": 12, "Left Torso": 12, "Right Torso": 12,
		"Left Arm": 12, "Right Arm": 12, "Left Leg": 6, "Right Leg": 6,
	}
	var used: Dictionary = {}
	for c in tu.components:
		var loc_name = "Unknown"
		if c.location:
			loc_name = c.location.location_name
		var n = c.component_name.to_lower()
		var slots = c.critical_slots
		if loc_name == "Head" and (n == "life support" or n == "sensors"):
			slots = 1
		var was: int = used.get(loc_name, 0)
		used[loc_name] = was + slots

	for loc in slot_limits:
		var used_slots = used.get(loc, 0)
		if used_slots > slot_limits[loc]:
			errors.append("Slot overflow in %s: %d used / %d max" % [loc, used_slots, slot_limits[loc]])


func _validate_armor_limits(tu: TacticalUnit, errors: Array) -> void:
	var is_map := {
		"Head": 3,
		"Center Torso": int(round(tu.tonnage / 3.2)),
		"Left Torso": int(round(tu.tonnage / 3.2)),
		"Right Torso": int(round(tu.tonnage / 3.2)),
		"Left Arm": max(3, int(ceil(tu.tonnage / 10.0)) + 4),
		"Right Arm": max(3, int(ceil(tu.tonnage / 10.0)) + 4),
		"Left Leg": max(3, int(ceil(tu.tonnage / 10.0)) + 8),
		"Right Leg": max(3, int(ceil(tu.tonnage / 10.0)) + 8),
	}
	var seen: Dictionary = {}
	for c in tu.components:
		if not c.location or seen.has(c.location.location_name):
			continue
		var loc = c.location.location_name
		seen[loc] = true
		var is_pts = is_map.get(loc, 0)
		if is_pts <= 0:
			continue
		var max_armor = is_pts * 2
		if loc == "Head":
			max_armor = 9
		var total = c.location.armor + c.location.rear_armor
		if total > max_armor:
			errors.append("Armor over max in %s: %d / %d" % [loc, total, max_armor])


func _validate_ammo(tu: TacticalUnit, warnings: Array) -> void:
	var ammo_base_names: Array[String] = []
	var weapon_names: Array[String] = []
	for c in tu.components:
		var n = c.component_name
		if TacticalUnitValidator._is_ammo(n):
			var base = TacticalUnitValidator._ammo_base_weapon(n)
			if not base.is_empty() and base not in ammo_base_names:
				ammo_base_names.append(base)
		elif TacticalUnitValidator._is_ammo_weapon(n):
			weapon_names.append(n)

	for wn in weapon_names:
		var base = TacticalUnitValidator._ammo_base_weapon(wn)
		if base != "" and base not in ammo_base_names:
			warnings.append("No ammo for %s — weapon will be unusable" % wn)

	for an in ammo_base_names:
		if an not in weapon_names:
			warnings.append("Ammo for %s found but no matching weapon equipped — wasted tonnage" % an)


func _validate_gyro(tu: TacticalUnit, errors: Array) -> void:
	var has_gyro := false
	for c in tu.components:
		if c.component_name == "Gyroscope":
			has_gyro = true
			break
	if not has_gyro:
		errors.append("Missing gyroscope")


func _validate_heat_sinks(tu: TacticalUnit, errors: Array) -> void:
	if tu.heat_sink_count < 10:
		errors.append("Too few heat sinks: %d, minimum 10" % [tu.heat_sink_count])
