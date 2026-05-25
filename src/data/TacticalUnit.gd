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
@export var motion_type: String = ""

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
	if engine_rating <= 0 and unit_type != Enums.UnitType.INFANTRY:
		errors.append("Missing engine")
	if components.is_empty():
		errors.append("No components")

	# --- Critical slot limits per location (Mech) ---
	if unit_type == Enums.UnitType.MECH:
		var slot_limits := {
			"Head": 6, "Center Torso": 12, "Left Torso": 12, "Right Torso": 12,
			"Left Arm": 12, "Right Arm": 12, "Left Leg": 6, "Right Leg": 6,
		}
		var used: Dictionary = {}
		for c in components:
			var loc_name = "Unknown"
			if c.location:
				loc_name = c.location.location_name
			var key = loc_name
			var n = c.component_name.to_lower()
			var slots = c.critical_slots
			# Life Support and Sensors in the head have front/rear entries
			# but functionally occupy 1 slot each
			if loc_name == "Head" and (n == "life support" or n == "sensors"):
				slots = 1
			var was: int = used.get(key, 0)
			used[key] = was + slots

		for loc in slot_limits:
			var max_slots = slot_limits[loc]
			var used_slots = used.get(loc, 0)
			if used_slots > max_slots:
				errors.append("Slot overflow in %s: %d used / %d max" % [loc, used_slots, max_slots])

	# --- Engine rating sanity ---
	if unit_type == Enums.UnitType.MECH and movement_mp > 0 and tonnage > 0:
		var expected_rating = int(movement_mp * tonnage)
		if engine_rating != expected_rating:
			errors.append("Engine rating mismatch: %d expected from walk %d × %dt, got %d" % [expected_rating, movement_mp, int(tonnage), engine_rating])

	# --- Max armor per location ---
	if unit_type == Enums.UnitType.MECH:
		var is_map := {
			"Head": 3,
			"Center Torso": int(round(tonnage / 3.2)),
			"Left Torso": int(round(tonnage / 3.2)),
			"Right Torso": int(round(tonnage / 3.2)),
			"Left Arm": max(3, int(ceil(tonnage / 10.0)) + 4),
			"Right Arm": max(3, int(ceil(tonnage / 10.0)) + 4),
			"Left Leg": max(3, int(ceil(tonnage / 10.0)) + 8),
			"Right Leg": max(3, int(ceil(tonnage / 10.0)) + 8),
		}
		var seen: Dictionary = {}
		for c in components:
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

	# --- Vehicle validation ---
	if unit_type == Enums.UnitType.VEHICLE:
		if engine_rating <= 0:
			errors.append("Missing engine")

		if not motion_type:
			errors.append("Missing motion type")

		if movement_mp > 0 and tonnage > 0:
			var sf = _vehicle_suspension_factor(motion_type, tonnage)
			var base = int(tonnage * movement_mp) - sf
			if base % 5 != 0:
				base = base + (5 - base % 5)
			var expected = max(0, base)
			if engine_rating != expected:
				errors.append("Engine rating mismatch: got %d, expected %d (cruise %d × %dt − SF %d)" % [engine_rating, expected, movement_mp, int(tonnage), sf])

		# No gyro on vehicles
		for c in components:
			if c.component_name == "Gyroscope" or c.component_name == "Gyro":
				errors.append("Vehicle should not have gyroscope")
				break

		# Max armor per location (vehicle IS × 2)
		var veh_is := {}
		var veh_armor_order := ["Front", "Left Side", "Right Side", "Rear"]
		if motion_type.to_lower() == "vtol":
			veh_armor_order.append("Rotor")
		else:
			veh_armor_order.append("Turret")

		for loc_name in veh_armor_order:
			var is_pts := 1
			match loc_name:
				"Front":
					is_pts = max(2, int(ceil(tonnage / 10.0)) + 2)
				"Left Side", "Right Side":
					is_pts = max(1, int(ceil(tonnage / 10.0)) + 1)
				"Rear":
					is_pts = max(1, int(ceil(tonnage / 10.0)))
				"Turret":
					is_pts = max(1, int(ceil(tonnage / 10.0)) + 1)
				"Rotor":
					is_pts = max(1, int(ceil(tonnage / 10.0)) + 2)
			veh_is[loc_name] = is_pts

		var seen_veh: Dictionary = {}
		for c in components:
			if not c.location or seen_veh.has(c.location.location_name):
				continue
			var loc = c.location.location_name
			seen_veh[loc] = true
			var is_pts = veh_is.get(loc, 0)
			if is_pts <= 0:
				continue
			var max_armor = is_pts * 2
			var total = c.location.armor + c.location.rear_armor
			if total > max_armor:
				errors.append("Armor over max in %s: %d / %d" % [loc, total, max_armor])

		# Vehicle slot limits
		var veh_slots := {
			"Front": 10, "Left Side": 6, "Right Side": 6, "Rear": 6,
		}
		if motion_type.to_lower() == "vtol":
			veh_slots["Rotor"] = 4
		else:
			veh_slots["Turret"] = 8
		var used_veh: Dictionary = {}
		for c in components:
			var loc_name = "Unknown"
			if c.location:
				loc_name = c.location.location_name
			var was = used_veh.get(loc_name, 0)
			used_veh[loc_name] = was + c.critical_slots
		for loc in veh_slots:
			var used_slots = used_veh.get(loc, 0)
			if used_slots > veh_slots[loc]:
				errors.append("Slot overflow in %s: %d used / %d max" % [loc, used_slots, veh_slots[loc]])

	# --- Ammo validation (all unit types) ---
	var ammo_names: Array[String] = []
	var weapon_names: Array[String] = []
	for c in components:
		var n = c.component_name
		if _is_ammo(n):
			ammo_names.append(_ammo_base_weapon(n))
		elif _is_ammo_weapon(n):
			weapon_names.append(n)
	for wn in weapon_names:
		var base = _ammo_base_weapon(wn)
		if base != "" and base not in ammo_names:
			errors.append("Missing ammo for %s" % wn)

	# --- Gyro present for mechs ---
	if unit_type == Enums.UnitType.MECH:
		var has_gyro := false
		for c in components:
			if c.component_name == "Gyroscope":
				has_gyro = true
				break
		if not has_gyro:
			errors.append("Missing gyroscope")

	# --- Heat sink adequacy ---
	if unit_type == Enums.UnitType.MECH:
		if heat_sink_count < 10:
			errors.append("Too few heat sinks: %d, minimum 10" % [heat_sink_count])

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


static func _is_ammo(name: String) -> bool:
	var n = name.to_lower()
	return "ammo" in n


static func _vehicle_suspension_factor(mtype: String, veh_tonnage: float) -> int:
	var data = _load_suspension_factors()
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
static func _load_suspension_factors() -> Dictionary:
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


static func _is_ammo_weapon(name: String) -> bool:
	var n = name.to_lower()
	# Ammo-using weapon types: autocannon, LRM, SRM, LRT, SRT, MG, Flamer (vehicle),
	# plus specific weapon patterns
	var patterns = ["autocannon/", "lrm-", "srm-", "lrt-", "srt-", "machine gun"]
	for p in patterns:
		if n.begins_with(p):
			return true
	# Also check if the component def has ammo_type field (from JSON)
	return false


static func _ammo_base_weapon(name: String) -> String:
	var n = name.to_lower().strip_edges()
	# Strip (R) suffix
	if n.ends_with(" (r)"):
		n = n.substr(0, n.length() - 4).strip_edges()

	# Direct ammo name → base weapon mapping
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

	# For weapon names (not ammo), extract the base weapon name
	# e.g., "Autocannon/5" → "Autocannon/5"
	if _is_ammo_weapon(name):
		# Already a weapon name, extract base
		for prefix in ["autocannon/", "lrm-", "srm-", "lrt-", "srt-"]:
			if n.begins_with(prefix):
				return name  # Return original case
		if n == "machine gun" or n == "machine gun (vehicle)":
			return "Machine Gun"
	return ""

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
