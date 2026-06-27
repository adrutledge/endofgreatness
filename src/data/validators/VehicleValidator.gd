class_name VehicleValidator
extends UnitValidator


func validate(tu: TacticalUnit) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	_validate_engine(tu, errors)
	_validate_motion_type(tu, errors)
	_validate_engine_rating(tu, errors)
	_validate_no_gyro(tu, errors)
	_validate_armor_limits(tu, errors)
	_validate_slot_limits(tu, errors)
	_validate_ammo(tu, warnings)

	return {"valid": errors.is_empty(), "errors": errors, "warnings": warnings}


func _validate_engine(tu: TacticalUnit, errors: Array) -> void:
	if tu.engine_rating <= 0:
		errors.append("Missing engine")


func _validate_motion_type(tu: TacticalUnit, errors: Array) -> void:
	if not tu.motion_type:
		errors.append("Missing motion type")


func _validate_engine_rating(tu: TacticalUnit, errors: Array) -> void:
	if tu.movement_mp > 0 and tu.tonnage > 0:
		var sf = TacticalUnitValidator.get_suspension_factor(tu.motion_type, tu.tonnage)
		var base = int(tu.tonnage * tu.movement_mp) - sf
		if base % 5 != 0:
			base = base + (5 - base % 5)
		var expected = max(0, base)
		if tu.engine_rating != expected:
			errors.append("Engine rating mismatch: got %d, expected %d (cruise %d × %dt − SF %d)" % [tu.engine_rating, expected, tu.movement_mp, int(tu.tonnage), sf])


func _validate_no_gyro(tu: TacticalUnit, errors: Array) -> void:
	for c in tu.components:
		if c.component_name == "Gyroscope" or c.component_name == "Gyro":
			errors.append("Vehicle should not have gyroscope")
			break


func _validate_armor_limits(tu: TacticalUnit, errors: Array) -> void:
	var veh_is := {}
	var armor_order := ["Front", "Left Side", "Right Side", "Rear"]
	if tu.motion_type.to_lower() == "vtol":
		armor_order.append("Rotor")
	else:
		armor_order.append("Turret")

	for loc_name in armor_order:
		var is_pts := 1
		match loc_name:
			"Front":
				is_pts = max(2, int(ceil(tu.tonnage / 10.0)) + 2)
			"Left Side", "Right Side":
				is_pts = max(1, int(ceil(tu.tonnage / 10.0)) + 1)
			"Rear":
				is_pts = max(1, int(ceil(tu.tonnage / 10.0)))
			"Turret":
				is_pts = max(1, int(ceil(tu.tonnage / 10.0)) + 1)
			"Rotor":
				is_pts = max(1, int(ceil(tu.tonnage / 10.0)) + 2)
		veh_is[loc_name] = is_pts

	var seen: Dictionary = {}
	for c in tu.components:
		if not c.location or seen.has(c.location.location_name):
			continue
		var loc = c.location.location_name
		seen[loc] = true
		var is_pts = veh_is.get(loc, 0)
		if is_pts <= 0:
			continue
		var max_armor = is_pts * 2
		var total = c.location.armor + c.location.rear_armor
		if total > max_armor:
			errors.append("Armor over max in %s: %d / %d" % [loc, total, max_armor])


func _validate_slot_limits(tu: TacticalUnit, errors: Array) -> void:
	var veh_slots := {
		"Front": 10, "Left Side": 6, "Right Side": 6, "Rear": 6,
	}
	if tu.motion_type.to_lower() == "vtol":
		veh_slots["Rotor"] = 4
	else:
		veh_slots["Turret"] = 8

	var used: Dictionary = {}
	for c in tu.components:
		var loc_name = "Unknown"
		if c.location:
			loc_name = c.location.location_name
		var was = used.get(loc_name, 0)
		used[loc_name] = was + c.critical_slots

	for loc in veh_slots:
		var used_slots = used.get(loc, 0)
		if used_slots > veh_slots[loc]:
			errors.append("Slot overflow in %s: %d used / %d max" % [loc, used_slots, veh_slots[loc]])


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
