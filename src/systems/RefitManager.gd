extends Node

var active_refits: Array[Dictionary] = []

var facility_level: int = 2

const CLASS_HOURS: Dictionary = {
	Enums.RefitClass.B: 1.0,
	Enums.RefitClass.C: 2.0,
	Enums.RefitClass.D: 5.0,
	Enums.RefitClass.E: 50.0
}

const CLASS_COST_PCT: Dictionary = {
	Enums.RefitClass.B: 0.05,
	Enums.RefitClass.C: 0.10,
	Enums.RefitClass.D: 0.20,
	Enums.RefitClass.E: 0.30
}

func _ready() -> void:
	TimeManager.date_changed.connect(_on_date_changed)

func _on_date_changed(_date: Dictionary) -> void:
	_process_refits()

func determine_refit_class(current_component_name: String, current_location: String,
		target_component_name: String, target_location: String,
		current_tonnage: float, target_tonnage: float) -> Enums.RefitClass:
	var c_def = _component_def(current_component_name)
	var t_def = _component_def(target_component_name)

	if current_location == target_location and c_def.get("tech_base", "") == t_def.get("tech_base", ""):
		if abs(current_tonnage - target_tonnage) < 0.5:
			return Enums.RefitClass.B
		return Enums.RefitClass.C

	if current_location != target_location and c_def.get("tech_base", "") == t_def.get("tech_base", ""):
		return Enums.RefitClass.C

	if c_def.get("tech_base", "") != t_def.get("tech_base", ""):
		return Enums.RefitClass.D

	return Enums.RefitClass.C

func _component_def(name: String) -> Dictionary:
	return DataManager.component_defs.get(name, {})

func classify_refit(diff: Dictionary) -> Dictionary:
	var class_counts: Dictionary = {}
	var detail: Array[Dictionary] = []

	for name in diff.components_to_add:
		var cl = Enums.RefitClass.B
		var def = _component_def(name)
		var tonnage = def.get("tonnage", 0.0)
		detail.append({"component": name, "class": cl, "tonnage": tonnage, "action": "add"})
		class_counts[cl] = class_counts.get(cl, 0) + 1

	for name in diff.components_to_remove:
		var cl = Enums.RefitClass.B
		var def = _component_def(name)
		var tonnage = def.get("tonnage", 0.0)
		detail.append({"component": name, "class": cl, "tonnage": tonnage, "action": "remove"})
		class_counts[cl] = class_counts.get(cl, 0) + 1

	var overall: Enums.RefitClass = Enums.RefitClass.B
	for cl in class_counts:
		if cl > overall:
			overall = cl

	return {"overall_class": overall, "detail": detail, "class_counts": class_counts}

func calculate_refit_hours(diff: Dictionary) -> int:
	var class_info = classify_refit(diff)
	var total = 0.0
	var def = DataManager.component_defs
	for entry in class_info.detail:
		var hours_per_ton = CLASS_HOURS[entry.class]
		total += entry.tonnage * hours_per_ton
	for name in diff.components_to_remove:
		var comp_def = _component_def(name)
		total += comp_def.get("tonnage", 0.0) * 0.5
	return max(int(ceil(total)), 4)

func calculate_refit_cost(diff: Dictionary) -> int:
	var class_info = classify_refit(diff)
	var total = 0.0
	for entry in class_info.detail:
		if entry.action != "add":
			continue
		var comp_def = _component_def(entry.component)
		var base_cost = comp_def.get("cost", 1000)
		var cost_pct = CLASS_COST_PCT.get(entry.class, 0.10)
		total += base_cost * cost_pct
	return int(ceil(total))

func start_refit(tactical_unit: TacticalUnit, target_variant: TacticalUnit, parts_plan: Array[Dictionary] = []) -> Dictionary:
	if get_unit_refit(tactical_unit):
		return {"success": false, "reason": "Unit already has an active refit"}
	var diff = calculate_refit_diff(tactical_unit, target_variant)
	if diff.components_to_add.is_empty() and diff.components_to_remove.is_empty():
		return {"success": false, "reason": "No changes needed"}

	var kit_info = calculate_refit_kit(diff)
	var total_cost = kit_info.cost
	var max_delivery_days = kit_info.delivery_days

	if EconomySystem.get_balance() < total_cost:
		return {"success": false, "reason": "Insufficient funds — need " + str(total_cost) + " CB"}

	if max_delivery_days > 0:
		EconomySystem.deduct_funds(total_cost, "Refit kit: " + target_variant.unit_name)
	else:
		EconomySystem.deduct_funds(total_cost, "Refit kit: " + target_variant.unit_name)

	var class_info = classify_refit(diff)
	var total_hours = calculate_refit_hours(diff)
	var gate = check_facility_gating(class_info.overall_class)
	var refit = {
		"tactical_unit": tactical_unit,
		"target_variant": target_variant,
		"target_unit_name": target_variant.unit_name,
		"components_to_add": diff.components_to_add,
		"components_to_remove": diff.components_to_remove,
		"overall_class": class_info.overall_class,
		"total_hours": total_hours,
		"hours_remaining": total_hours,
		"cost": total_cost,
		"parts_delivery_eta": max_delivery_days,
		"parts_delivered": max_delivery_days <= 0,
		"facility_penalty": gate.penalty,
	}
	active_refits.append(refit)
	var refit_class_name = Enums.RefitClass.keys()[class_info.overall_class]
	GameState.log_event("refit_started", {
		"unit": tactical_unit.unit_name,
		"target": target_variant.unit_name,
		"class": refit_class_name,
		"cost": total_cost,
		"hours": total_hours,
		"delivery_days": max_delivery_days,
		"kit": true,
	})
	return {"success": true, "refit": refit}


func calculate_refit_kit(diff: Dictionary) -> Dictionary:
	var total_cost := 0
	var max_delivery := 0
	var discount := 0.9
	var f = FileAccess.open("res://data/config/spares_config.json", FileAccess.READ)
	if f:
		var j = JSON.new()
		if j.parse(f.get_as_text()) == OK:
			discount = j.data.get("refit_kit_discount", 0.9)

	for name in diff.get("components_to_add", []):
		var def = _component_def(name)
		var base_cost = def.get("cost", 1000)
		total_cost += int(ceil(base_cost * discount))

		var remote = EconomySystem.search_remote_sources(name)
		if remote.size() > 0:
			var eta = remote[0].travel_days
			if eta > max_delivery:
				max_delivery = eta

	return {"cost": max(total_cost, 1), "delivery_days": max_delivery}

func source_parts(diff: Dictionary) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	EconomySystem.initialize_market(GameState.player.current_planet)

	for name in diff.components_to_add:
		var market = EconomySystem.current_market
		var local_item = market.get_item(name)
		if local_item and local_item.quantity > 0:
			plan.append({
				"component_name": name,
				"source": "local",
				"cost_per_unit": local_item.cost,
				"quantity": 1
			})
		else:
			var remote_sources = EconomySystem.search_remote_sources(name)
			if remote_sources.size() > 0:
				var best = remote_sources[0]
				plan.append({
					"component_name": name,
					"source": "remote",
					"source_system": best.source_system,
					"cost_per_unit": best.cost_per_unit,
					"travel_days": best.travel_days
				})
			else:
				var def = _component_def(name)
				var base_cost = def.get("cost", 1000)
				plan.append({
					"component_name": name,
					"source": "remote",
					"source_system": "Unknown",
					"cost_per_unit": int(base_cost * 1.5),
					"travel_days": 30
				})
	return plan

func _process_refits() -> void:
	for refit in active_refits:
		if not refit.parts_delivered:
			refit.parts_delivery_eta -= 1
			if refit.parts_delivery_eta <= 0:
				refit.parts_delivered = true
				var log_name = "customization_parts_arrived" if refit.has("changes") else "refit_parts_arrived"
				GameState.log_event(log_name, {
					"unit": refit.tactical_unit.unit_name,
				})
			continue

		var tu = refit.tactical_unit
		var budget = PersonnelManager.get_unit_repair_budget(tu)
		if budget <= 0:
			continue
		var hours_this_tick = min(budget, refit.hours_remaining)
		refit.hours_remaining -= hours_this_tick

	var completed: Array[int] = []
	for i in range(active_refits.size()):
		if active_refits[i].hours_remaining <= 0 and active_refits[i].parts_delivered:
			if active_refits[i].has("changes"):
				_apply_customization(active_refits[i])
			else:
				_apply_refit(active_refits[i])
			completed.append(i)

	for i in range(completed.size() - 1, -1, -1):
		active_refits.remove_at(completed[i])

func get_refit_kit_bonus(refit: Dictionary) -> int:
	match refit.get("overall_class", Enums.RefitClass.C):
		Enums.RefitClass.B: return -2
		Enums.RefitClass.C: return -1
		_: return 0


func _apply_refit(refit: Dictionary) -> void:
	var tu = refit.tactical_unit
	var variant = refit.target_variant
	var tech = _get_best_tech(tu)
	var tech_skill = tech.get_tech_skill() if tech else 4

	var changes: Array[Dictionary] = []
	for name in refit.get("components_to_add", []):
		changes.append({"action": "add", "new_component": name, "tonnage": 0.0})
	for name in refit.get("components_to_remove", []):
		changes.append({"action": "remove", "current_component": name, "tonnage": 0.0})

	var tn = 0
	for ch in changes:
		var t = calculate_customization_tn(ch, tech_skill, facility_level)
		if t > tn:
			tn = t

	var kit_bonus = get_refit_kit_bonus(refit)
	tn += kit_bonus
	if refit.get("facility_penalty", 0) > 0:
		tn += refit.facility_penalty

	var roll = randi() % 6 + randi() % 6 + 2
	var success = roll >= tn

	var log_entry = {
		"date": TimeManager.get_date_string(),
		"technician": tech.personnel_name if tech else "Unknown",
		"tech_skill": tech_skill,
		"target_number": tn,
		"roll": roll,
		"result": "success" if success else "failure",
		"changes": changes.size(),
		"kit_bonus": kit_bonus,
		"refit": true,
	}

	if success:
		tu.unit_name = variant.unit_name
		tu.model_name = variant.model_name
		tu.tonnage = variant.tonnage
		tu.movement_mp = variant.movement_mp
		tu.run_mp = variant.run_mp
		tu.jump_mp = variant.jump_mp

		var new_components: Array[Component] = []
		for c in variant.components:
			var new_c = Component.new()
			new_c.component_name = c.component_name
			new_c.component_type = c.component_type
			new_c.tonnage = c.tonnage
			new_c.critical_slots = c.critical_slots
			new_c.cost = c.cost
			new_c.tech_base = c.tech_base
			new_c.tech_level = c.tech_level
			new_c.quality_range = c.quality_range
			new_c.repair_difficulty = c.repair_difficulty
			new_c.status = Enums.ComponentStatus.UNDAMAGED
			new_c.location = c.location
			new_components.append(new_c)
		tu.components = new_components

		log_entry.applied = true
		tu.customization_history.append(log_entry)
		GameState.log_event("refit_completed", {
			"unit": tu.unit_name,
			"target": refit.target_unit_name,
			"kit_bonus": kit_bonus,
		})
		_check_proven_variant(tu)
	else:
		var extra_hours := int(ceil(refit.total_hours * 0.5))
		refit.hours_remaining += extra_hours
		refit.total_hours += extra_hours
		refit.failure_count = refit.get("failure_count", 0) + 1
		log_entry.applied = false
		log_entry.extra_hours = extra_hours
		tu.customization_history.append(log_entry)
		GameState.log_event("refit_retry", {
			"unit": tu.unit_name,
			"target": refit.target_unit_name,
			"retry_count": refit.failure_count,
			"extra_hours": extra_hours,
		})

func calculate_refit_diff(current: TacticalUnit, target: TacticalUnit) -> Dictionary:
	var current_names: Array[String] = []
	for c in current.components:
		current_names.append(c.component_name)

	var target_names: Array[String] = []
	for c in target.components:
		target_names.append(c.component_name)

	var to_remove: Array[String] = []
	var to_add: Array[String] = []

	for name in current_names:
		if name not in target_names:
			to_remove.append(name)
	for name in target_names:
		if name not in current_names:
			to_add.append(name)

	return {
		"components_to_remove": to_remove,
		"components_to_add": to_add
	}

func get_unit_refit(unit: TacticalUnit) -> Dictionary:
	for refit in active_refits:
		if refit.tactical_unit == unit:
			return refit
	return {}

# ----- P3.6.6 Campaign Operations Customization -----

const CUSTOMIZATION_CLASS_HOURS: Dictionary = {
	Enums.RefitClass.B: 1.0,
	Enums.RefitClass.C: 2.0,
	Enums.RefitClass.D: 5.0,
	Enums.RefitClass.E: 50.0
}

const CUSTOMIZATION_CLASS_COST_PCT: Dictionary = {
	Enums.RefitClass.B: 0.05,
	Enums.RefitClass.C: 0.10,
	Enums.RefitClass.D: 0.20,
	Enums.RefitClass.E: 0.30
}

const TN_BY_DIFFICULTY: Dictionary = {
	0: 2,
	1: 4,
	2: 6,
	3: 8,
	4: 10,
	5: 12
}


func classify_customization_change(current_name: String, new_name: String,
		current_location: String, new_location: String) -> Dictionary:
	var c_def = _component_def(current_name) if not current_name.is_empty() else {}
	var n_def = _component_def(new_name) if not new_name.is_empty() else {}
	var c_ton = c_def.get("tonnage", 0.0) if not c_def.is_empty() else 0.0
	var n_ton = n_def.get("tonnage", 0.0) if not n_def.is_empty() else 0.0
	var c_tech = c_def.get("tech_base", "") if not c_def.is_empty() else ""
	var n_tech = n_def.get("tech_base", "") if not n_def.is_empty() else ""

	var action: String = "replace"
	if current_name.is_empty():
		action = "add"
	elif new_name.is_empty():
		action = "remove"

	if action == "remove":
		return {"class": Enums.RefitClass.B, "action": action, "tonnage": c_ton}

	var refit_class: Enums.RefitClass = Enums.RefitClass.C
	if current_location == new_location and c_tech == n_tech:
		if abs(c_ton - n_ton) < 0.5:
			refit_class = Enums.RefitClass.B
	if c_tech != n_tech:
		refit_class = Enums.RefitClass.D
	if n_def.get("engine_rating", 0) > 0 or n_def.get("gyro_compatible", false):
		refit_class = Enums.RefitClass.E

	return {"class": refit_class, "action": action, "tonnage": max(c_ton, n_ton)}


func calculate_customization_time(change: Dictionary) -> int:
	var cl = change.get("class", Enums.RefitClass.B)
	var tonnage = change.get("tonnage", 1.0)
	var hours_per_ton = CUSTOMIZATION_CLASS_HOURS.get(cl, 1.0)
	var total = tonnage * hours_per_ton
	if change.get("action") == "remove":
		total = tonnage * 0.5
	return max(int(ceil(total)), 4)


func calculate_customization_cost(change: Dictionary) -> int:
	var cl = change.get("class", Enums.RefitClass.B)
	var tonnage = change.get("tonnage", 1.0)
	var pct = CUSTOMIZATION_CLASS_COST_PCT.get(cl, 0.10)
	var comp_def = _component_def(change.get("new_component", ""))
	var base_cost = comp_def.get("cost", 1000) if not comp_def.is_empty() else 0
	return int(ceil(base_cost * pct))


func calculate_customization_tn(change: Dictionary, part_quality: int = 2,
		part_facility: int = 2, original_quality: int = 2, parts_in_stock: bool = true) -> int:
	var comp_def = _component_def(change.get("new_component", change.get("current_component", "")))
	var difficulty = comp_def.get("repair_difficulty", 2) if not comp_def.is_empty() else 2
	var base_tn = TN_BY_DIFFICULTY.get(difficulty, 6)

	var quality_mod := 0
	match part_quality:
		Enums.Quality.A: quality_mod = -2
		Enums.Quality.B: quality_mod = -1
		Enums.Quality.C: quality_mod = 0
		Enums.Quality.D: quality_mod = 1
		Enums.Quality.E: quality_mod = 2
		Enums.Quality.F: quality_mod = 4

	var fac_mod := 0
	match part_facility:
		0: fac_mod = 2
		1: fac_mod = 0
		2: fac_mod = -1
		_: fac_mod = -2

	var stock_mod := 0 if parts_in_stock else 1

	var quality_mismatch := 0
	if original_quality > part_quality:
		quality_mismatch = original_quality - part_quality

	return base_tn + quality_mod + fac_mod + stock_mod + quality_mismatch


func calculate_customization_summary(changes: Array[Dictionary]) -> Dictionary:
	var total_time: int = 0
	var total_cost: int = 0
	var highest_class: Enums.RefitClass = Enums.RefitClass.B
	var detail: Array[Dictionary] = []

	for ch in changes:
		var t = calculate_customization_time(ch)
		var c = calculate_customization_cost(ch)
		var cl = ch.get("class", Enums.RefitClass.B)
		total_time += t
		total_cost += c
		if cl > highest_class:
			highest_class = cl
		detail.append({
			"component": ch.get("new_component", ch.get("current_component", "")),
			"class": cl,
			"time": t,
			"cost": c,
			"action": ch.get("action", "replace"),
		})

	return {
		"total_time": total_time,
		"total_cost": total_cost,
		"highest_class": highest_class,
		"detail": detail
	}


func get_facility_level() -> int:
	return facility_level


func set_facility_level(level: int) -> void:
	facility_level = clampi(level, 0, 4)


func get_facility_requirement(refit_class: Enums.RefitClass) -> int:
	match refit_class:
		Enums.RefitClass.B: return 0
		Enums.RefitClass.C: return 1
		Enums.RefitClass.D: return 2
		Enums.RefitClass.E: return 3
	return 0


func check_facility_gating(refit_class: Enums.RefitClass) -> Dictionary:
	var required = get_facility_requirement(refit_class)
	var has = get_facility_level()
	var passes = has >= required
	var penalty = 0 if passes else 4
	return {"passes": passes, "required": required, "has": has, "penalty": penalty}


func start_customization(unit: TacticalUnit, changes: Array[Dictionary],
		parts_plan: Array[Dictionary], facility_lvl: int = -1) -> Dictionary:
	if changes.is_empty():
		return {"success": false, "reason": "No changes specified"}
	if get_unit_refit(unit):
		return {"success": false, "reason": "Unit already has an active refit or customization"}

	if facility_lvl >= 0:
		set_facility_level(facility_lvl)

	var summary = calculate_customization_summary(changes)
	var gate = check_facility_gating(summary.highest_class)

	var total_cost = summary.total_cost
	for entry in parts_plan:
		total_cost += entry.get("cost_per_unit", 0)

	if EconomySystem.get_balance() < total_cost:
		return {"success": false, "reason": "Insufficient funds — need " + str(total_cost) + " CB"}

	for entry in parts_plan:
		if entry.source == "local":
			EconomySystem.buy_item(entry.component_name, 1)
		elif entry.source == "remote":
			EconomySystem.order_item(entry.component_name, 1,
				entry.cost_per_unit, entry.source_system, entry.travel_days)

	var customization = {
		"tactical_unit": unit,
		"changes": changes,
		"total_hours": summary.total_time,
		"hours_remaining": summary.total_time,
		"cost": total_cost,
		"highest_class": summary.highest_class,
		"parts_delivery_eta": 0,
		"parts_delivered": true,
		"facility_penalty": gate.penalty,
		"facility_passes": gate.passes,
	}
	for entry in parts_plan:
		if entry.source == "remote":
			var eta = entry.get("travel_days", 7)
			customization.parts_delivery_eta = max(customization.parts_delivery_eta, eta)
			customization.parts_delivered = false

	active_refits.append(customization)

	GameState.log_event("customization_started", {
		"unit": unit.unit_name,
		"changes": changes.size(),
		"class": Enums.RefitClass.keys()[summary.highest_class],
		"cost": total_cost,
		"hours": summary.total_time,
	})
	return {"success": true, "customization": customization}


func _process_customizations() -> void:
	for refit in active_refits:
		if not refit.has("changes"):
			continue
		if not refit.parts_delivered:
			refit.parts_delivery_eta -= 1
			if refit.parts_delivery_eta <= 0:
				refit.parts_delivered = true
			continue

		var tu = refit.tactical_unit
		var budget = PersonnelManager.get_unit_repair_budget(tu)
		if budget <= 0:
			continue
		var hours_this_tick = min(budget, refit.hours_remaining)
		refit.hours_remaining -= hours_this_tick

	var completed: Array[int] = []
	for i in range(active_refits.size()):
		var r = active_refits[i]
		if not r.has("changes"):
			continue
		if r.hours_remaining <= 0 and r.parts_delivered:
			_apply_customization(r)
			completed.append(i)

	for i in range(completed.size() - 1, -1, -1):
		active_refits.remove_at(completed[i])


func _apply_customization(customization: Dictionary) -> void:
	var tu = customization.tactical_unit
	var changes = customization.changes
	var tech = _get_best_tech(tu)
	var tech_skill = tech.get_tech_skill() if tech else 4

	var tn = 0
	for change in changes:
		var t = calculate_customization_tn(change, tech_skill, facility_level)
		if t > tn:
			tn = t
	if customization.facility_penalty > 0:
		tn += customization.facility_penalty

	var roll = randi() % 6 + randi() % 6 + 2
	var success = roll >= tn

	var result = "success" if success else "failure"

	var log_entry = {
		"date": TimeManager.get_date_string(),
		"technician": tech.personnel_name if tech else "Unknown",
		"tech_skill": tech_skill,
		"target_number": tn,
		"roll": roll,
		"result": result,
		"changes": changes.size(),
	}

	if success:
		for change in changes:
			_apply_change(tu, change)
		log_entry.applied = true
		tu.customization_history.append(log_entry)
		if tu.customization_history.size() > 100:
			tu.customization_history = tu.customization_history.slice(-100)
		GameState.log_event("customization_completed", {
			"unit": tu.unit_name,
			"changes": changes.size(),
			"success": true,
		})
		_check_proven_variant(tu)
	else:
		var extra_hours := int(ceil(customization.total_hours * 0.5))
		customization.hours_remaining += extra_hours
		customization.total_hours += extra_hours
		customization.failure_count = customization.get("failure_count", 0) + 1
		log_entry.applied = false
		log_entry.extra_hours = extra_hours
		tu.customization_history.append(log_entry)
		GameState.log_event("customization_retry", {
			"unit": tu.unit_name,
			"retry_count": customization.failure_count,
			"extra_hours": extra_hours,
		})


func _get_best_tech(unit: TacticalUnit) -> Personnel:
	var best = null
	var best_skill = -1
	for t in unit.assigned_technicians:
		var s = t.get_tech_skill()
		if s > best_skill:
			best_skill = s
			best = t
	return best


func _apply_change(unit: TacticalUnit, change: Dictionary) -> void:
	var action = change.get("action", "replace")
	if action == "remove" or action == "replace":
		var remove_name = change.get("current_component", "")
		for i in range(unit.components.size() - 1, -1, -1):
			if unit.components[i].component_name == remove_name:
				unit.components.remove_at(i)
				break
	if action == "add" or action == "replace":
		var comp_def = _component_def(change.get("new_component", ""))
		if not comp_def.is_empty():
			var new_c = Component.new()
			new_c.component_name = comp_def.get("name", "")
			new_c.component_type = comp_def.get("component_type", "")
			new_c.tonnage = comp_def.get("tonnage", 0.0)
			new_c.critical_slots = comp_def.get("critical_slots", 0)
			new_c.cost = comp_def.get("cost", 0)
			new_c.tech_base = comp_def.get("tech_base", "Inner Sphere")
			new_c.tech_level = comp_def.get("tech_level", 1)
			new_c.quality_range = comp_def.get("quality_range", [1, 5])
			new_c.repair_difficulty = comp_def.get("repair_difficulty", 2)
			new_c.status = Enums.ComponentStatus.UNDAMAGED
			new_c.location = change.get("location", "")
			unit.components.append(new_c)


func _check_proven_variant(unit: TacticalUnit) -> void:
	var unit_names: Array[String] = []
	for c in unit.components:
		unit_names.append(c.component_name)
	for name in DataManager.unit_templates:
		if DataManager.is_canon_unit(name):
			continue
		var tmpl = DataManager.unit_templates[name]
		if tmpl.chassis_name != unit.chassis_name:
			continue
		var tmpl_names: Array[String] = []
		for c in tmpl.components:
			tmpl_names.append(c.component_name)
		unit_names.sort()
		tmpl_names.sort()
		if unit_names == tmpl_names:
			GameState.proven_custom_variants[name] = true
			return


func get_customization_log(unit: TacticalUnit) -> Array[Dictionary]:
	return unit.customization_history.duplicate()


func get_refit_class_name(cl: Enums.RefitClass) -> String:
	match cl:
		Enums.RefitClass.B:
			return "B (Standard)"
		Enums.RefitClass.C:
			return "C (Complex)"
		Enums.RefitClass.D:
			return "D (Major)"
		Enums.RefitClass.E:
			return "E (Chassis)"
	return "?"
