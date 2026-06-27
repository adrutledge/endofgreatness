class_name SaveSerializer
extends RefCounted

const _Relation = preload("res://src/data/Relation.gd")


static func capture_state() -> Dictionary:
	return {
		"save_version": 1,
		"date_created": TimeManager.get_date_string() if TimeManager else "",
		"game_date": TimeManager.current_date.duplicate() if TimeManager else {"year": 3025, "month": 1, "day": 1},
		"time_state": _serialize_time_state(),
		"player": _serialize_strategic_unit(GameState.player) if GameState and GameState.player else {},
		"active_contracts": _serialize_contracts(GameState.active_contracts) if GameState else [],
		"event_log": GameState.event_log.duplicate() if GameState else [],
		"player_inventory": (GameState.player_inventory.duplicate() if GameState else {}),
		"proven_custom_variants": (GameState.proven_custom_variants.duplicate() if GameState else {}),
		"reputation": _serialize_reputation(),
		"personnel": _serialize_personnel(),
		"economy": _serialize_economy(),
		"inventory_manager": _serialize_inventory_manager(),
		"refit_manager": _serialize_refit_manager(),
		"mod_versions": ModManager.get_loaded_versions() if ModManager else {},
		"mod_extras": ModManager.get_all_mod_data() if ModManager else {},
	}


static func attach_metadata(data: Dictionary, label: String) -> void:
	var meta := {
		"label": label,
		"date_saved": TimeManager.get_date_string(),
		"planet": GameState.player.current_planet if GameState.player else "",
		"funds": GameState.player.current_balance if GameState.player else 0,
		"unit_count": _count_tactical_units(),
		"personnel_count": PersonnelManager.personnel_roster.size() if PersonnelManager else 0,
		"active_contracts": GameState.active_contracts.size() if GameState else 0,
		"play_time_seconds": TimeManager.total_days * 86400 if TimeManager else 0,
	}
	if not GameState.active_contracts.is_empty():
		meta["current_contract"] = GameState.active_contracts[0].activity_type + " for " + GameState.active_contracts[0].issuer
	data["metadata"] = meta


static func _count_tactical_units() -> int:
	if not GameState or not GameState.player:
		return 0
	var count := 0
	for ou in GameState.player.organizational_units:
		for opu in ou.sub_units:
			count += opu.tactical_units.size()
	return count


static func _serialize_time_state() -> Dictionary:
	if not TimeManager:
		return {}
	return {
		"is_paused": TimeManager.is_paused,
		"total_days": TimeManager.total_days,
		"tick_interval": TimeManager.tick_interval,
		"elapsed_time": TimeManager.elapsed_time,
		"tactical_round": TimeManager.tactical_round,
		"is_tactical_mode": TimeManager.is_tactical_mode,
		"last_autosave_day": -1,
	}


static func _serialize_strategic_unit(unit: StrategicUnit) -> Dictionary:
	if not unit:
		return {}
	return {
		"unit_name": unit.unit_name,
		"current_balance": unit.current_balance,
		"current_planet": unit.current_planet,
		"home_base": unit.home_base,
		"organizational_units": _serialize_org_units(unit.organizational_units),
		"active_contract": _serialize_contract(unit.active_contract) if unit.active_contract else null,
	}


static func _serialize_org_units(units: Array) -> Array:
	var result: Array = []
	for ou in units:
		result.append(_serialize_org_unit(ou))
	return result


static func _serialize_org_unit(ou: OrganizationalUnit) -> Dictionary:
	return {
		"unit_name": ou.unit_name,
		"commander_name": ou.commander.personnel_name if ou.commander else "",
		"sub_units": _serialize_op_units(ou.sub_units),
		"contract_id": ou.contract_id,
	}


static func _serialize_op_units(units: Array) -> Array:
	var result: Array = []
	for opu in units:
		result.append(_serialize_op_unit(opu))
	return result


static func _serialize_op_unit(opu: OperationalUnit) -> Dictionary:
	return {
		"unit_name": opu.unit_name,
		"commander_name": opu.commander.personnel_name if opu.commander else "",
		"tactical_units": _serialize_tactical_units(opu.tactical_units),
		"sub_units": _serialize_op_units(opu.sub_units),
		"role": opu.role,
		"current_planet": opu.current_planet,
		"contract_id": opu.contract_id,
		"is_deployed": opu.is_deployed,
		"hex_position": {"x": opu.hex_position.x, "y": opu.hex_position.y},
		"deployment_cache": opu.deployment_cache.duplicate(),
	}


static func _serialize_tactical_units(units: Array) -> Array:
	var result: Array = []
	for tu in units:
		result.append(_serialize_tactical_unit(tu))
	return result


static func _serialize_tactical_unit(tu: TacticalUnit) -> Dictionary:
	return {
		"unit_id": tu.unit_id,
		"unit_name": tu.unit_name,
		"chassis_name": tu.chassis_name,
		"model_name": tu.model_name,
		"unit_type": tu.unit_type,
		"engine_rating": tu.engine_rating,
		"engine_type": tu.engine_type,
		"gyro_type": tu.gyro_type,
		"internal_structure_type": tu.internal_structure_type,
		"armor_type": tu.armor_type,
		"total_armor_points": tu.total_armor_points,
		"heat_sink_count": tu.heat_sink_count,
		"quality": tu.quality,
		"components": _serialize_components(tu.components),
		"crew_names": tu.crew.map(func(p): return p.personnel_name if p else ""),
		"ammo": tu.ammo.duplicate(),
		"tonnage": tu.tonnage,
		"movement_mp": tu.movement_mp,
		"run_mp": tu.run_mp,
		"jump_mp": tu.jump_mp,
		"assigned_technician_names": tu.assigned_technicians.map(func(p): return p.personnel_name if p else ""),
		"slot_free_heat_sinks": tu.slot_free_heat_sinks,
		"weight_free_heat_sinks": tu.weight_free_heat_sinks,
		"motion_type": tu.motion_type,
		"abstract_crew_count": tu.abstract_crew_count,
		"rules_level": tu.rules_level,
		"era": tu.era,
		"customization_history": tu.customization_history.duplicate(),
	}


static func _serialize_components(components: Array) -> Array:
	var result: Array = []
	for c in components:
		result.append(_serialize_component(c))
	return result


static func _serialize_component(c: Component) -> Dictionary:
	return {
		"component_name": c.component_name,
		"component_type": c.component_type,
		"tonnage": c.tonnage,
		"critical_slots": c.critical_slots,
		"cost": c.cost,
		"tech_base": c.tech_base,
		"tech_level": c.tech_level,
		"quality_range": {"x": c.quality_range.x, "y": c.quality_range.y},
		"repair_difficulty": c.repair_difficulty,
		"status": c.status,
		"location": _serialize_location(c.location) if c.location else null,
		"rear_facing": c.rear_facing,
	}


static func _serialize_location(loc: ComponentLocation) -> Dictionary:
	return {
		"location_name": loc.location_name,
		"hit_chance": loc.hit_chance,
		"armor": loc.armor,
		"rear_armor": loc.rear_armor,
		"structure": loc.structure,
		"max_armor": loc.max_armor,
		"max_structure": loc.max_structure,
	}


static func _serialize_contracts(contracts: Array) -> Array:
	var result: Array = []
	for c in contracts:
		result.append(_serialize_contract(c))
	return result


static func _serialize_contract(c: Contract) -> Dictionary:
	return {
		"issuer": c.issuer,
		"target": c.target,
		"planet": c.planet,
		"activity_type": c.activity_type,
		"duration": c.duration,
		"salvage_rate": c.salvage_rate,
		"salvage_type": c.salvage_type,
		"c_bill_payment": c.c_bill_payment,
		"transport_coverage": c.transport_coverage,
		"base_coverage": c.base_coverage,
		"command_rights": c.command_rights,
		"battle_loss_reimbursement_rate": c.battle_loss_reimbursement_rate,
		"minimum_tonnage": c.minimum_tonnage,
		"minimum_tactical_unit_counts": c.minimum_tactical_unit_counts.duplicate(),
		"payout_per_month": c.payout_per_month,
		"total_paid": c.total_paid,
		"is_active": c.is_active,
		"is_completed": c.is_completed,
		"salvage_pool": c.salvage_pool.duplicate(),
		"tactical_cache": c.tactical_cache.duplicate(),
		"planetary_map_data": c.planetary_map_data.duplicate(),
		"opfor_pool": c.opfor_pool.duplicate(),
		"opfor_template_id": c.opfor_template_id,
		"salvage_percentage_used": c.salvage_percentage_used,
	}


static func _serialize_reputation() -> Dictionary:
	if not ReputationSystem:
		return {"global": 0, "faction": {}}
	return {
		"global": ReputationSystem.global_reputation,
		"faction": ReputationSystem.faction_reputation.duplicate(),
	}


static func _serialize_personnel() -> Dictionary:
	if not PersonnelManager:
		return {"roster": [], "relationships": {}, "abstract_astech_count": 0, "abstract_medic_count": 0}
	var roster_data: Array = []
	for p in PersonnelManager.personnel_roster:
		roster_data.append(_serialize_personnel_entry(p))
	var rels: Dictionary = {}
	for from_name in PersonnelManager.personnel_relationships:
		var rel_list: Array = PersonnelManager.personnel_relationships[from_name]
		var rd: Array = []
		for r in rel_list:
			rd.append({"type": r.type, "target_name": r.target_name, "valence": r.valence, "strength": r.strength})
		rels[from_name] = rd
	return {
		"roster": roster_data,
		"relationships": rels,
		"abstract_astech_count": PersonnelManager.abstract_astech_count,
		"abstract_medic_count": PersonnelManager.abstract_medic_count,
	}


static func _serialize_personnel_entry(p: Personnel) -> Dictionary:
	var trait_data: Array = []
	for t in p.traits:
		trait_data.append({
			"id": t.id if t.has_method("get_id") else (t.get("id", "") if t is Dictionary else ""),
			"name": t.name if t.has_method("get_name") else (t.get("name", "") if t is Dictionary else ""),
			"description": t.description if t.has_method("get_description") else (t.get("description", "") if t is Dictionary else ""),
			"trait_type": t.trait_type if t.has_method("get_trait_type") else (t.get("trait_type", 0) if t is Dictionary else 0),
			"effect_type": t.effect_type if t.has_method("get_effect_type") else (t.get("effect_type", "") if t is Dictionary else ""),
			"effect_value": t.effect_value if t.has_method("get_effect_value") else (t.get("effect_value", 0) if t is Dictionary else 0),
			"effect_skill": t.effect_skill if t.has_method("get_effect_skill") else (t.get("effect_skill", "") if t is Dictionary else ""),
		})
	var patient_names: Array = []
	for pat in p.patients_assigned:
		if pat:
			patient_names.append(pat.personnel_name if pat is Personnel else str(pat))
	return {
		"personnel_name": p.personnel_name, "rank": p.rank, "role": p.role,
		"body": p.body, "dexterity": p.dexterity, "reflexes": p.reflexes,
		"strength": p.strength, "willpower": p.willpower, "charisma": p.charisma,
		"intelligence": p.intelligence, "edge": p.edge, "traits": trait_data,
		"wealth": p.wealth, "highest_education": p.highest_education,
		"reputation": p.reputation, "skills": p.skills.duplicate(),
		"experience": p.experience, "is_injured": p.is_injured,
		"injury_severity": p.injury_severity, "date_of_birth": p.date_of_birth,
		"assigned_unit_id": p.assigned_unit_id, "patient_capacity": p.patient_capacity,
		"patient_names": patient_names, "affiliation": p.affiliation,
		"prior_affiliation": p.prior_affiliation, "height_cm": p.height_cm,
		"weight_kg": p.weight_kg, "hair_color": p.hair_color, "eye_color": p.eye_color,
		"description": p.description, "specialization": p.specialization,
		"originating_faction": p.originating_faction, "home_system": p.home_system,
		"home_planet": p.home_planet, "secondary_role": p.secondary_role,
		"interested_in_relationship": p.interested_in_relationship,
		"interested_in_children": p.interested_in_children,
		"biological_role": p.biological_role,
		"healing_days_remaining": p.healing_days_remaining,
		"healing_days_total": p.healing_days_total,
		"is_founder": p.is_founder, "is_commander": p.is_commander,
		"is_xo": p.is_xo, "is_lance_commander": p.is_lance_commander,
	}


static func _serialize_economy() -> Dictionary:
	if not EconomySystem:
		return {}
	return {
		"pending_deliveries": EconomySystem.pending_deliveries.duplicate(),
		"accumulated_expenses": EconomySystem.accumulated_expenses,
		"accumulated_breakdown": EconomySystem.accumulated_breakdown.duplicate(),
		"last_bill_month": EconomySystem.last_bill_month,
		"last_bill_year": EconomySystem.last_bill_year,
		"contract_battle_losses": _deep_duplicate(EconomySystem.contract_battle_losses),
		"contract_ammo_costs": _deep_duplicate(EconomySystem.contract_ammo_costs),
		"contract_salvage_pool": _deep_duplicate(EconomySystem.contract_salvage_pool),
		"contract_cumulative_loss_value": _deep_duplicate(EconomySystem.contract_cumulative_loss_value),
		"contract_cumulative_reimbursement": _deep_duplicate(EconomySystem.contract_cumulative_reimbursement),
		"current_planet_factions": EconomySystem.current_planet_factions.duplicate(),
		"funds_warning_emitted": EconomySystem._funds_warning_emitted,
	}


static func _serialize_inventory_manager() -> Dictionary:
	if not InventoryManager:
		return {}
	var its: Dictionary = {}
	for key in InventoryManager.in_transit:
		var entry = InventoryManager.in_transit[key]
		var opu_name = entry.opu.unit_name if entry.opu and entry.opu is OperationalUnit else ""
		its[key] = {"item": entry.get("item", ""), "quantity": entry.get("quantity", 0), "eta_day": entry.get("eta_day", 0), "opu_name": opu_name}
	return {"in_transit": its, "last_auto_reorder_day": InventoryManager._last_auto_reorder_day}


static func _serialize_refit_manager() -> Dictionary:
	if not RefitManager:
		return {}
	return {
		"active_refits": _serialize_refits(RefitManager.active_refits),
		"active_repairs": _serialize_repairs(RefitManager.active_repairs),
		"facility_level": RefitManager.facility_level,
	}


static func _serialize_refits(refits: Array) -> Array:
	var result: Array = []
	for r in refits:
		result.append({
			"tactical_unit_name": r.tactical_unit.unit_name if r.tactical_unit else "",
			"target_unit_name": r.get("target_unit_name", ""),
			"components_to_add": r.get("components_to_add", []).duplicate(),
			"components_to_remove": r.get("components_to_remove", []).duplicate(),
			"overall_class": r.get("overall_class", 0), "total_hours": r.get("total_hours", 0),
			"hours_remaining": r.get("hours_remaining", 0), "cost": r.get("cost", 0),
			"parts_delivery_eta": r.get("parts_delivery_eta", 0),
			"parts_delivered": r.get("parts_delivered", false),
			"facility_penalty": r.get("facility_penalty", 0),
			"failure_count": r.get("failure_count", 0),
			"changes": r.get("changes", []).duplicate(),
			"highest_class": r.get("highest_class", 0),
			"facility_passes": r.get("facility_passes", true),
		})
	return result


static func _serialize_repairs(repairs: Array) -> Array:
	var result: Array = []
	for r in repairs:
		result.append({
			"tactical_unit_name": r.tactical_unit.unit_name if r.tactical_unit else "",
			"component_name": r.get("component_name", ""),
			"current_status": r.get("current_status", 0),
			"hours_remaining": r.get("hours_remaining", 0),
			"total_hours": r.get("total_hours", 0),
			"spare_cost": r.get("spare_cost", 0),
			"parts_consumed": r.get("parts_consumed", false),
			"tech_applied": r.get("tech_applied", false),
			"failure_count": r.get("failure_count", 0),
		})
	return result


static func _deep_duplicate(value) -> Dictionary:
	var j = JSON.new()
	var s = j.stringify(value)
	j.parse(s)
	return j.data if typeof(j.data) == TYPE_DICTIONARY else {}


# ==================== DESERIALIZATION ====================


static func restore_time_state(data: Dictionary) -> void:
	var ts = data.get("time_state", {})
	if TimeManager:
		TimeManager.current_date = data.get("game_date", {"year": 3025, "month": 1, "day": 1}).duplicate()
		TimeManager.is_paused = ts.get("is_paused", true)
		TimeManager.total_days = ts.get("total_days", 0)
		TimeManager.tick_interval = ts.get("tick_interval", 1.0)
		TimeManager.elapsed_time = ts.get("elapsed_time", 0.0)
		TimeManager.tactical_round = ts.get("tactical_round", 0)
		TimeManager.is_tactical_mode = ts.get("is_tactical_mode", false)


static func restore_player(data: Dictionary) -> void:
	var pd = data.get("player", {})
	if not GameState:
		return
	if not GameState.player:
		GameState.player = StrategicUnit.new()
	GameState.player.unit_name = pd.get("unit_name", "Player")
	GameState.player.current_balance = pd.get("current_balance", 1000000)
	GameState.player.current_planet = pd.get("current_planet", "")
	GameState.player.home_base = pd.get("home_base", "Galatea")
	var roster_map = _build_personnel_map(data)
	GameState.player.organizational_units = _deserialize_org_units(pd.get("organizational_units", []), roster_map)
	var ac = pd.get("active_contract")
	GameState.player.active_contract = _deserialize_contract(ac) if ac and not ac.is_empty() else null


static func restore_contracts(data: Dictionary) -> void:
	if not GameState:
		return
	GameState.active_contracts = _deserialize_contracts(data.get("active_contracts", []))
	GameState.event_log = data.get("event_log", [])
	if GameState.event_log.size() > 500:
		GameState.event_log = GameState.event_log.slice(-500)


static func restore_inventory(data: Dictionary) -> void:
	if not GameState:
		return
	GameState.player_inventory = data.get("player_inventory", {}).duplicate()
	GameState.proven_custom_variants = data.get("proven_custom_variants", {}).duplicate()


static func restore_reputation(data: Dictionary) -> void:
	var rep = data.get("reputation", {})
	if ReputationSystem:
		ReputationSystem.global_reputation = rep.get("global", 0)
		ReputationSystem.faction_reputation = rep.get("faction", {}).duplicate()


static func restore_personnel(data: Dictionary) -> void:
	var pdata = data.get("personnel", {})
	if not PersonnelManager:
		return
	var roster_data: Array = pdata.get("roster", [])
	var roster_map: Dictionary = {}
	PersonnelManager.personnel_roster.clear()
	for pd_entry in roster_data:
		var p := _deserialize_personnel(pd_entry)
		PersonnelManager.personnel_roster.append(p)
		roster_map[p.personnel_name] = p
	for p in PersonnelManager.personnel_roster:
		var saved = p.get_meta("saved_patients", [])
		if not saved.is_empty():
			var resolved: Array[Personnel] = []
			for name in saved:
				var found = roster_map.get(name)
				if found:
					resolved.append(found)
			p.patients_assigned = resolved
			p.remove_meta("saved_patients")
	PersonnelManager.personnel_relationships.clear()
	var rels = pdata.get("relationships", {})
	for from_name in rels:
		var rl: Array = rels[from_name]
		var resolved: Array = []
		for rd in rl:
			var r = _Relation.new()
			r.type = rd.get("type", 0)
			r.target_name = rd.get("target_name", "")
			r.valence = rd.get("valence", 1)
			r.strength = rd.get("strength", 1)
			resolved.append(r)
		PersonnelManager.personnel_relationships[from_name] = resolved
	PersonnelManager.abstract_astech_count = pdata.get("abstract_astech_count", 0)
	PersonnelManager.abstract_medic_count = pdata.get("abstract_medic_count", 0)
	PersonnelManager._last_candidate_refresh_day = -1
	PersonnelManager._candidate_pool.clear()


static func restore_economy(data: Dictionary) -> void:
	var ed = data.get("economy", {})
	if not EconomySystem:
		return
	EconomySystem.pending_deliveries = ed.get("pending_deliveries", []).duplicate()
	EconomySystem.accumulated_expenses = ed.get("accumulated_expenses", 0)
	EconomySystem.accumulated_breakdown = ed.get("accumulated_breakdown", {}).duplicate()
	EconomySystem.last_bill_month = ed.get("last_bill_month", 1)
	EconomySystem.last_bill_year = ed.get("last_bill_year", 3025)
	EconomySystem.contract_battle_losses = _deep_duplicate(ed.get("contract_battle_losses", {}))
	EconomySystem.contract_ammo_costs = _deep_duplicate(ed.get("contract_ammo_costs", {}))
	EconomySystem.contract_salvage_pool = _deep_duplicate(ed.get("contract_salvage_pool", {}))
	EconomySystem.contract_cumulative_loss_value = _deep_duplicate(ed.get("contract_cumulative_loss_value", {}))
	EconomySystem.contract_cumulative_reimbursement = _deep_duplicate(ed.get("contract_cumulative_reimbursement", {}))
	EconomySystem.current_planet_factions = ed.get("current_planet_factions", []).duplicate()
	EconomySystem._funds_warning_emitted = ed.get("funds_warning_emitted", false)
	EconomySystem.initialize_market(GameState.player.current_planet if GameState and GameState.player else "Galatea")


static func restore_inventory_manager(data: Dictionary) -> void:
	var imd = data.get("inventory_manager", {})
	if not InventoryManager:
		return
	var raw: Dictionary = _deep_duplicate(imd.get("in_transit", {}))
	InventoryManager.in_transit.clear()
	for key in raw:
		var entry = raw[key]
		if entry is Dictionary:
			var opu_name = entry.get("opu_name", "")
			var opu = _find_opu_by_name(opu_name)
			InventoryManager.in_transit[key] = {"item": entry.get("item", ""), "quantity": entry.get("quantity", 0), "eta_day": entry.get("eta_day", 0), "opu": opu}
	InventoryManager._last_auto_reorder_day = imd.get("last_auto_reorder_day", -1)


static func _find_opu_by_name(name: String):
	if not GameState or not GameState.player:
		return null
	for ou in GameState.player.organizational_units:
		for opu in ou.sub_units:
			if opu.unit_name == name:
				return opu
	return null


static func restore_refit_manager(data: Dictionary) -> void:
	var rmd = data.get("refit_manager", {})
	if not RefitManager:
		return
	RefitManager.active_refits = _deserialize_refits(rmd.get("active_refits", []))
	RefitManager.active_repairs = _deserialize_repairs(rmd.get("active_repairs", []))
	RefitManager.facility_level = rmd.get("facility_level", 2)
	_resolve_refit_unit_refs()


static func _resolve_refit_unit_refs() -> void:
	var unit_map: Dictionary = {}
	if GameState and GameState.player:
		for ou in GameState.player.organizational_units:
			for opu in ou.sub_units:
				for tu in opu.tactical_units:
					unit_map[tu.unit_name] = tu
	for refit in RefitManager.active_refits:
		var tu_name = refit.get("tactical_unit_name", "")
		if not tu_name.is_empty() and unit_map.has(tu_name):
			refit["tactical_unit"] = unit_map[tu_name]
		var target_name = refit.get("target_unit_name", "")
		if not target_name.is_empty() and DataManager.unit_templates.has(target_name):
			refit["target_variant"] = DataManager.unit_templates[target_name]
	for repair in RefitManager.active_repairs:
		var tu_name = repair.get("tactical_unit_name", "")
		if not tu_name.is_empty() and unit_map.has(tu_name):
			repair["tactical_unit"] = unit_map[tu_name]


static func _deserialize_org_units(data: Array, roster_map: Dictionary) -> Array:
	var result: Array = []
	for od in data:
		var ou := OrganizationalUnit.new()
		ou.unit_name = od.get("unit_name", "")
		var cn = od.get("commander_name", "")
		if not cn.is_empty() and roster_map.has(cn):
			ou.commander = roster_map[cn]
		ou.contract_id = od.get("contract_id", "")
		ou.sub_units = _deserialize_op_units(od.get("sub_units", []), roster_map)
		result.append(ou)
	return result


static func _deserialize_op_units(data: Array, roster_map: Dictionary) -> Array:
	var result: Array = []
	for od in data:
		var opu := OperationalUnit.new()
		opu.unit_name = od.get("unit_name", "")
		var cn = od.get("commander_name", "")
		if not cn.is_empty() and roster_map.has(cn):
			opu.commander = roster_map[cn]
		opu.tactical_units = _deserialize_tactical_units(od.get("tactical_units", []), roster_map)
		opu.sub_units = _deserialize_op_units(od.get("sub_units", []), roster_map)
		opu.role = od.get("role", "")
		opu.current_planet = od.get("current_planet", "")
		opu.contract_id = od.get("contract_id", "")
		opu.is_deployed = od.get("is_deployed", false)
		var hp = od.get("hex_position", {})
		opu.hex_position = Vector2i(hp.get("x", 0), hp.get("y", 0))
		opu.deployment_cache = od.get("deployment_cache", {}).duplicate()
		result.append(opu)
	return result


static func _deserialize_tactical_units(data: Array, roster_map: Dictionary) -> Array:
	var result: Array = []
	for td in data:
		var tu := TacticalUnit.new()
		tu.unit_id = td.get("unit_id", "")
		tu.unit_name = td.get("unit_name", "")
		tu.chassis_name = td.get("chassis_name", "")
		tu.model_name = td.get("model_name", "")
		tu.unit_type = td.get("unit_type", 0)
		tu.engine_rating = td.get("engine_rating", 0)
		tu.engine_type = td.get("engine_type", "Standard")
		tu.gyro_type = td.get("gyro_type", "Standard")
		tu.internal_structure_type = td.get("internal_structure_type", "Standard")
		tu.armor_type = td.get("armor_type", "Standard")
		tu.total_armor_points = td.get("total_armor_points", 0)
		tu.heat_sink_count = td.get("heat_sink_count", 10)
		tu.quality = td.get("quality", 0)
		tu.components = _deserialize_components(td.get("components", []))
		tu.crew = _resolve_personnel_names(td.get("crew_names", []), roster_map)
		tu.ammo = td.get("ammo", {}).duplicate()
		tu.tonnage = td.get("tonnage", 0.0)
		tu.movement_mp = td.get("movement_mp", 0)
		tu.run_mp = td.get("run_mp", 0)
		tu.jump_mp = td.get("jump_mp", 0)
		tu.assigned_technicians = _resolve_personnel_names(td.get("assigned_technician_names", []), roster_map)
		tu.slot_free_heat_sinks = td.get("slot_free_heat_sinks", 10)
		tu.weight_free_heat_sinks = td.get("weight_free_heat_sinks", 10)
		tu.motion_type = td.get("motion_type", "")
		tu.abstract_crew_count = td.get("abstract_crew_count", 0)
		tu.rules_level = td.get("rules_level", 1)
		tu.era = td.get("era", 3025)
		tu.customization_history = td.get("customization_history", []).duplicate()
		result.append(tu)
	return result


static func _resolve_personnel_names(names: Array, roster_map: Dictionary) -> Array:
	var result: Array = []
	for name in names:
		if name is String and roster_map.has(name):
			result.append(roster_map[name])
	return result


static func _deserialize_components(data: Array) -> Array:
	var result: Array = []
	for cd in data:
		var c := Component.new()
		c.component_name = cd.get("component_name", "")
		c.component_type = cd.get("component_type", "")
		c.tonnage = cd.get("tonnage", 0.0)
		c.critical_slots = cd.get("critical_slots", 0)
		c.cost = cd.get("cost", 0)
		c.tech_base = cd.get("tech_base", "Inner Sphere")
		c.tech_level = cd.get("tech_level", 1)
		var qr = cd.get("quality_range", {"x": 0, "y": 0})
		c.quality_range = Vector2(qr.get("x", 0), qr.get("y", 0)) if qr is Dictionary else Vector2(0, 0)
		c.repair_difficulty = cd.get("repair_difficulty", 2)
		c.status = cd.get("status", 0)
		c.location = _deserialize_location(cd.get("location", {}))
		c.rear_facing = cd.get("rear_facing", false)
		result.append(c)
	return result


static func _deserialize_location(ld) -> ComponentLocation:
	if not ld or ld is not Dictionary or ld.is_empty():
		return null
	var loc := ComponentLocation.new()
	loc.location_name = ld.get("location_name", "")
	loc.hit_chance = ld.get("hit_chance", 0.0)
	loc.armor = ld.get("armor", 0)
	loc.rear_armor = ld.get("rear_armor", 0)
	loc.structure = ld.get("structure", 0)
	loc.max_armor = ld.get("max_armor", 0)
	loc.max_structure = ld.get("max_structure", 0)
	return loc


static func _deserialize_contract(data: Dictionary) -> Contract:
	var c := Contract.new()
	c.issuer = data.get("issuer", "")
	c.target = data.get("target", "")
	c.planet = data.get("planet", "")
	c.activity_type = data.get("activity_type", "")
	c.duration = data.get("duration", 0)
	c.salvage_rate = data.get("salvage_rate", 0.0)
	c.salvage_type = data.get("salvage_type", "exchange")
	c.c_bill_payment = data.get("c_bill_payment", 0)
	c.transport_coverage = data.get("transport_coverage", 0.0)
	c.base_coverage = data.get("base_coverage", 0.0)
	c.command_rights = data.get("command_rights", 0)
	c.battle_loss_reimbursement_rate = data.get("battle_loss_reimbursement_rate", 0.0)
	c.minimum_tonnage = data.get("minimum_tonnage", 0.0)
	c.minimum_tactical_unit_counts = data.get("minimum_tactical_unit_counts", {}).duplicate()
	c.payout_per_month = data.get("payout_per_month", 0)
	c.total_paid = data.get("total_paid", 0)
	c.is_active = data.get("is_active", false)
	c.is_completed = data.get("is_completed", false)
	c.salvage_pool = data.get("salvage_pool", []).duplicate()
	c.tactical_cache = data.get("tactical_cache", {}).duplicate()
	c.planetary_map_data = data.get("planetary_map_data", {}).duplicate()
	c.opfor_pool = data.get("opfor_pool", []).duplicate()
	c.opfor_template_id = data.get("opfor_template_id", "")
	c.salvage_percentage_used = data.get("salvage_percentage_used", 0.0)
	return c


static func _deserialize_contracts(data: Array) -> Array:
	var result: Array = []
	for cd in data:
		result.append(_deserialize_contract(cd))
	return result


static func _build_personnel_map(data: Dictionary) -> Dictionary:
	var roster_data: Array = data.get("personnel", {}).get("roster", [])
	var roster_map: Dictionary = {}
	for pd_entry in roster_data:
		var name = pd_entry.get("personnel_name", "")
		if not name.is_empty():
			roster_map[name] = pd_entry
	return roster_map


static func _deserialize_personnel(pd: Dictionary) -> Personnel:
	var p := Personnel.new()
	p.personnel_name = pd.get("personnel_name", "")
	p.rank = pd.get("rank", "")
	p.role = pd.get("role", 0)
	p.body = pd.get("body", 5)
	p.dexterity = pd.get("dexterity", 5)
	p.reflexes = pd.get("reflexes", 5)
	p.strength = pd.get("strength", 5)
	p.willpower = pd.get("willpower", 5)
	p.charisma = pd.get("charisma", 5)
	p.intelligence = pd.get("intelligence", 5)
	p.edge = pd.get("edge", 1)
	p.wealth = pd.get("wealth", 0)
	p.highest_education = pd.get("highest_education", 0)
	p.reputation = pd.get("reputation", 0)
	p.skills = pd.get("skills", {}).duplicate()
	p.experience = pd.get("experience", 0)
	p.is_injured = pd.get("is_injured", false)
	p.injury_severity = pd.get("injury_severity", 0)
	p.date_of_birth = pd.get("date_of_birth", "3025-01-01")
	p.assigned_unit_id = pd.get("assigned_unit_id", "")
	p.patient_capacity = pd.get("patient_capacity", 20)
	p.affiliation = pd.get("affiliation", "")
	p.prior_affiliation = pd.get("prior_affiliation", "")
	p.height_cm = pd.get("height_cm", 170)
	p.weight_kg = pd.get("weight_kg", 70)
	p.hair_color = pd.get("hair_color", "")
	p.eye_color = pd.get("eye_color", "")
	p.description = pd.get("description", "")
	p.specialization = pd.get("specialization", "")
	p.originating_faction = pd.get("originating_faction", "")
	p.home_system = pd.get("home_system", "")
	p.home_planet = pd.get("home_planet", "")
	p.secondary_role = pd.get("secondary_role", -1)
	p.interested_in_relationship = pd.get("interested_in_relationship", true)
	p.interested_in_children = pd.get("interested_in_children", false)
	p.biological_role = pd.get("biological_role", "")
	p.healing_days_remaining = pd.get("healing_days_remaining", 0)
	p.healing_days_total = pd.get("healing_days_total", 0)
	p.is_founder = pd.get("is_founder", false)
	p.is_commander = pd.get("is_commander", false)
	p.is_xo = pd.get("is_xo", false)
	p.is_lance_commander = pd.get("is_lance_commander", false)
	p.traits = _deserialize_traits(pd.get("traits", []))
	var patient_names: Array = pd.get("patient_names", [])
	if not patient_names.is_empty():
		p.set_meta("saved_patients", patient_names)
	p.patients_assigned = []
	return p


static func _deserialize_traits(trait_data: Array) -> Array:
	var TraitRes = preload("res://src/data/Trait.gd")
	var result: Array = []
	for td in trait_data:
		var t := TraitRes.new()
		if td is Dictionary:
			t.id = td.get("id", "")
			t.name = td.get("name", "")
			t.description = td.get("description", "")
			t.trait_type = td.get("trait_type", 0)
			t.effect_type = td.get("effect_type", "")
			t.effect_value = td.get("effect_value", 0)
			t.effect_skill = td.get("effect_skill", "")
		result.append(t)
	return result


static func _deserialize_refits(data: Array) -> Array:
	var result: Array = []
	for rd in data:
		result.append({
			"tactical_unit_name": rd.get("tactical_unit_name", ""),
			"target_unit_name": rd.get("target_unit_name", ""),
			"components_to_add": rd.get("components_to_add", []).duplicate(),
			"components_to_remove": rd.get("components_to_remove", []).duplicate(),
			"overall_class": rd.get("overall_class", 0), "total_hours": rd.get("total_hours", 0),
			"hours_remaining": rd.get("hours_remaining", 0), "cost": rd.get("cost", 0),
			"parts_delivery_eta": rd.get("parts_delivery_eta", 0),
			"parts_delivered": rd.get("parts_delivered", false),
			"facility_penalty": rd.get("facility_penalty", 0),
			"failure_count": rd.get("failure_count", 0),
			"changes": rd.get("changes", []).duplicate(),
			"highest_class": rd.get("highest_class", 0),
			"facility_passes": rd.get("facility_passes", true),
		})
	return result


static func _deserialize_repairs(data: Array) -> Array:
	var result: Array = []
	for rd in data:
		result.append({
			"tactical_unit_name": rd.get("tactical_unit_name", ""),
			"component_name": rd.get("component_name", ""),
			"current_status": rd.get("current_status", 0),
			"hours_remaining": rd.get("hours_remaining", 0),
			"total_hours": rd.get("total_hours", 0),
			"spare_cost": rd.get("spare_cost", 0),
			"parts_consumed": rd.get("parts_consumed", false),
			"tech_applied": rd.get("tech_applied", false),
			"failure_count": rd.get("failure_count", 0),
		})
	return result
