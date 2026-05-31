class_name ContractGenerator
extends Node

var _config: Dictionary = {}
var _loaded := false


func _ensure_config() -> void:
	if _loaded:
		return
	_loaded = true
	var file = FileAccess.open("res://data/config/contract_generation.json", FileAccess.READ)
	if file:
		var j = JSON.new()
		if j.parse(file.get_as_text()) == OK:
			_config = j.data


func _c(key: String, default):
	return _config.get(key, default)


func generate_contracts(date: Dictionary, location: String, player_reputation: int, faction_reputations: Dictionary) -> Array[Contract]:
	_ensure_config()
	var contracts: Array[Contract] = []
	var mrb_rep = faction_reputations.get("MRB", faction_reputations.get("global", 0))
	var low_rep_threshold = _c("low_rep_threshold", -30)
	var low_rep = mrb_rep < low_rep_threshold
	var max_range = _c("range_raid", 250.0)
	var min_ct = _c("min_contracts", 5)
	var low_chance = _c("low_rep_contract_chance", 0.3)

	var issuers: Array[Faction] = []
	for code in GameState.factions:
		var faction = GameState.factions[code]
		if faction.is_pirate or faction.is_rebel:
			issuers.append(faction)
			continue
		if location.is_empty():
			continue
		var dist = _nearest_faction_system(location, code)
		if dist >= 0 and dist <= max_range:
			issuers.append(faction)

	if issuers.is_empty():
		for code in GameState.factions:
			issuers.append(GameState.factions[code])

	issuers.shuffle()
	var target_count = maxi(min_ct, mini(issuers.size(), randi() % 4 + 3))

	for i in range(target_count):
		var issuer = issuers[i % issuers.size()]
		if low_rep and not (issuer.is_pirate or issuer.is_rebel):
			if randf() >= low_chance:
				continue
		var target = _pick_target(issuer)
		var contract = generate_single_contract(issuer, target, date, player_reputation, location, low_rep)
		if contract:
			contracts.append(contract)

	if contracts.size() < min_ct:
		for code in GameState.factions:
			var f = GameState.factions[code]
			if not (f.is_pirate or f.is_rebel):
				continue
			var c = generate_single_contract(f, _pick_target(f), date, player_reputation, location, true)
			if c:
				contracts.append(c)
				if contracts.size() >= min_ct:
					break

	return contracts


func _nearest_faction_system(location: String, faction_code: String) -> float:
	var loc_data = DataManager.systems_data.get(location)
	if not loc_data:
		return -1.0
	var lx = loc_data.get("coordinates", {}).get("x", 0.0)
	var ly = loc_data.get("coordinates", {}).get("y", 0.0)
	var nearest := -1.0
	for name in DataManager.systems_data:
		var sys = DataManager.systems_data[name]
		if sys.get("owner_faction", "") != faction_code:
			continue
		var cx = sys.get("coordinates", {}).get("x", 0.0)
		var cy = sys.get("coordinates", {}).get("y", 0.0)
		var d = sqrt((cx - lx) * (cx - lx) + (cy - ly) * (cy - ly))
		if nearest < 0 or d < nearest:
			nearest = d
	return nearest


func _contract_type_for_distance(dist: float, is_pirate: bool, is_rebel: bool, low_rep: bool, location_owner: String = "") -> String:
	var g = _c("range_garrison", 30.0)
	var c = _c("range_cadre", 60.0)
	var d = _c("range_defense", 90.0)
	var ph = _c("range_pirate_hunt", 180.0)
	var rc = _c("range_recon", 120.0)
	var ph_chance = _c("periphery_pirate_hunt_chance", 0.35)
	var loc_faction = GameState.factions.get(location_owner) if not location_owner.is_empty() else null

	if low_rep or is_pirate or is_rebel:
		var pool = ["Raid", "Assault"]
		if randi() % 3 == 0:
			return "Recon"
		return pool[randi() % pool.size()]
	if dist <= g:
		return "Garrison" if randi() % 2 == 0 else "Defense"
	if dist <= c:
		return "Cadre" if randi() % 2 == 0 else "Defense"
	if dist <= d:
		return "Defense" if randi() % 2 == 0 else "Assault"
	if dist <= ph:
		if (loc_faction and loc_faction.is_periphery) or randf() < ph_chance:
			var pool = ["Pirate Hunting", "Raid", "Assault"]
			return pool[randi() % pool.size()]
		return "Assault" if randi() % 2 == 0 else "Raid"
	if dist <= rc:
		return "Recon" if randi() % 2 == 0 else "Raid"
	return "Raid"


func generate_single_contract(issuer: Faction, target: Faction, date: Dictionary, player_rep: int, location: String = "", low_rep: bool = false) -> Contract:
	var contract = Contract.new()
	contract.issuer = issuer.faction_name
	contract.target = target.faction_name
	contract.planet = location if not location.is_empty() else _pick_planet(issuer, target)

	var dist = -1.0
	var loc_owner = ""
	if not location.is_empty():
		dist = _nearest_faction_system(location, issuer.short_code)
		var loc_data = DataManager.systems_data.get(location)
		if loc_data:
			loc_owner = loc_data.get("owner_faction", "")
	contract.activity_type = _contract_type_for_distance(dist, issuer.is_pirate, issuer.is_rebel, low_rep, loc_owner)
	contract.duration = randi() % 91 + 30

	var rep_factor = clamp(player_rep, -100.0, 100.0) / 100.0
	var rep_mul = 1.0 + rep_factor * 0.5

	var base_pay = randi() % 500000 + 100000
	contract.c_bill_payment = int(base_pay * rep_mul)

	contract.salvage_rate = _pick_salvage_rate(rep_factor)
	contract.salvage_type = "items" if randi() % 3 == 0 else "exchange"

	contract.command_rights = _determine_command_rights(issuer, rep_factor, low_rep)

	var combined = float(contract.c_bill_payment) / 1000000.0 + contract.salvage_rate
	contract.battle_loss_reimbursement_rate = clamp(1.0 - combined * 0.8, 0.05, 0.85) + (randi() % 15) / 100.0

	contract.transport_coverage = (randi() % 50 + 50) / 100.0
	contract.base_coverage = (randi() % 40 + 20) / 100.0

	contract.minimum_tonnage = (randi() % 200 + 20) * 1.0
	contract.minimum_tactical_unit_counts = _generate_minimum_units(contract.activity_type)

	var total_months = max(1, ceil(float(contract.duration) / 30.0))
	contract.payout_per_month = contract.c_bill_payment / total_months if total_months > 0 else 0

	return contract


func _resolve_faction(lookup: String) -> Faction:
	if not lookup:
		return null
	var f = GameState.get_faction(lookup)
	if f:
		return f
	for code in GameState.factions:
		var candidate = GameState.factions[code]
		if candidate.faction_name.to_lower().replace(" ", "_") == lookup.to_lower().replace(" ", "_"):
			return candidate
		if candidate.short_code.to_lower() == lookup.to_lower():
			return candidate
	return null


func _pick_target(issuer: Faction) -> Faction:
	if not issuer.enemies.is_empty() and randi() % 10 < 7:
		var code = issuer.enemies[randi() % issuer.enemies.size()]
		var t = _resolve_faction(code)
		if t:
			return t

	var candidates: Array[Faction] = []
	for code in GameState.factions:
		var f = GameState.factions[code]
		if f != issuer:
			candidates.append(f)
	if candidates.is_empty():
		return issuer
	return candidates[randi() % candidates.size()]


func _pick_planet(issuer: Faction, target: Faction) -> String:
	var pool: Array[String] = []
	pool.append_array(target.home_worlds)
	pool.append_array(issuer.home_worlds)
	if pool.is_empty():
		return "Unknown"
	return pool[randi() % pool.size()]


func _pick_salvage_rate(rep_factor: float) -> float:
	var base = 0.0
	var roll = randi() % 100
	if roll < 30:
		base = 0.0
	elif roll < 70:
		base = (randi() % 30 + 10) / 100.0
	else:
		base = (randi() % 30 + 40) / 100.0
	return clamp(base + rep_factor * 0.2, 0.0, 0.75)


func _determine_command_rights(issuer: Faction, rep_factor: float, low_rep: bool = false) -> Enums.CommandRights:
	var urgent = rep_factor < -0.3 or low_rep

	if issuer.is_pirate or issuer.is_rebel:
		if urgent or randi() % 100 < 60:
			return Enums.CommandRights.INDEPENDENT
		return Enums.CommandRights.LIAISON

	if not issuer.is_civilian:
		if randi() % 2 == 0:
			return Enums.CommandRights.HOUSE
		return Enums.CommandRights.INTEGRATED

	var roll = randi() % 100
	if roll < 60 or urgent:
		return Enums.CommandRights.LIAISON
	if roll < 85:
		return Enums.CommandRights.INDEPENDENT
	return Enums.CommandRights.HOUSE


func _generate_minimum_units(activity_type: String) -> Dictionary:
	var counts = {}
	match activity_type:
		"Garrison":
			counts["INFANTRY"] = randi() % 3 + 2
			counts["VEHICLE"] = randi() % 2 + 1
			counts["MECH"] = randi() % 2 + 0
		"Cadre":
			counts["INFANTRY"] = randi() % 2 + 1
			counts["VEHICLE"] = randi() % 2 + 1
			counts["MECH"] = randi() % 2 + 1
		"Assault":
			counts["MECH"] = randi() % 3 + 2
			counts["VEHICLE"] = randi() % 2 + 1
			counts["INFANTRY"] = randi() % 2 + 0
		"Raid":
			counts["MECH"] = randi() % 2 + 2
			counts["VEHICLE"] = randi() % 2 + 0
			counts["INFANTRY"] = randi() % 2 + 0
		"Pirate Hunting":
			counts["MECH"] = randi() % 2 + 1
			counts["VEHICLE"] = randi() % 2 + 0
			counts["INFANTRY"] = randi() % 2 + 0
		"Recon":
			counts["VEHICLE"] = randi() % 2 + 1
			counts["MECH"] = randi() % 2 + 1
			counts["INFANTRY"] = randi() % 2 + 0
		"Defense":
			counts["INFANTRY"] = randi() % 3 + 2
			counts["VEHICLE"] = randi() % 2 + 2
			counts["MECH"] = randi() % 2 + 1
		_:
			counts["MECH"] = randi() % 2 + 1
			counts["VEHICLE"] = randi() % 2 + 0
			counts["INFANTRY"] = randi() % 2 + 0
	return counts
