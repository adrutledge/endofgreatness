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

func start_refit(tactical_unit: TacticalUnit, target_variant: TacticalUnit, parts_plan: Array[Dictionary]) -> Dictionary:
	var diff = calculate_refit_diff(tactical_unit, target_variant)
	if diff.components_to_add.is_empty() and diff.components_to_remove.is_empty():
		return {"success": false, "reason": "No changes needed"}

	var total_cost = 0
	var max_delivery_days = 0
	for entry in parts_plan:
		total_cost += entry.cost_per_unit
		if entry.source == "remote":
			var eta = entry.get("travel_days", 7)
			max_delivery_days = max(max_delivery_days, eta)

	if EconomySystem.get_balance() < total_cost:
		return {"success": false, "reason": "Insufficient funds — need " + str(total_cost) + " CB"}

	for entry in parts_plan:
		if entry.source == "local":
			EconomySystem.buy_item(entry.component_name, 1)
		elif entry.source == "remote":
			EconomySystem.order_item(entry.component_name, 1, entry.cost_per_unit, entry.source_system, entry.travel_days)

	var class_info = classify_refit(diff)
	var total_hours = calculate_refit_hours(diff)
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
		"parts_delivered": max_delivery_days <= 0
	}
	active_refits.append(refit)
	var refit_class_name = Enums.RefitClass.keys()[class_info.overall_class]
	GameState.log_event("refit_started", {
		"unit": tactical_unit.unit_name,
		"target": target_variant.unit_name,
		"class": refit_class_name,
		"cost": total_cost,
		"hours": total_hours,
		"delivery_days": max_delivery_days
	})
	return {"success": true, "refit": refit}

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
				GameState.log_event("refit_parts_arrived", {
					"unit": refit.tactical_unit.unit_name,
					"target": refit.target_unit_name
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
			_apply_refit(active_refits[i])
			completed.append(i)

	for i in range(completed.size() - 1, -1, -1):
		active_refits.remove_at(completed[i])

func _apply_refit(refit: Dictionary) -> void:
	var tu = refit.tactical_unit
	var variant = refit.target_variant

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

	GameState.log_event("refit_completed", {
		"unit": tu.unit_name,
		"target": refit.target_unit_name
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
