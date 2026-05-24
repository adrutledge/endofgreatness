class_name ContractGenerator
extends Node

const CONTRACT_TYPE_POOL = ["Garrison", "Cadre", "Raid", "Assault", "Recon", "Defense"]

func generate_contracts(date: Dictionary, location: String, player_reputation: int, faction_reputations: Dictionary) -> Array[Contract]:
	var contracts: Array[Contract] = []
	var issuers: Array[Faction] = []

	for code in GameState.factions:
		var faction: Faction = GameState.factions[code]
		if location in faction.home_worlds or faction.contracts_offered.size() > 0:
			issuers.append(faction)

	if issuers.is_empty():
		return contracts

	issuers.shuffle()
	var count = mini(issuers.size(), randi() % 3 + 2)

	for i in count:
		var issuer = issuers[i % issuers.size()]
		var target = _pick_target(issuer)
		var contract = generate_single_contract(issuer, target, date, player_reputation, location)
		contracts.append(contract)

	return contracts


func generate_single_contract(issuer: Faction, target: Faction, date: Dictionary, player_rep: int, location: String = "") -> Contract:
	var contract = Contract.new()
	contract.issuer = issuer.faction_name
	contract.target = target.faction_name
	contract.planet = location if not location.is_empty() else _pick_planet(issuer, target)

	var is_border = target.short_code in issuer.enemies
	contract.activity_type = _pick_activity_type(is_border)
	contract.duration = randi() % 91 + 30

	var rep_factor = clamp(player_rep, -100.0, 100.0) / 100.0
	var rep_mul = 1.0 + rep_factor * 0.5

	var base_pay = randi() % 500000 + 100000
	contract.c_bill_payment = int(base_pay * rep_mul)

	contract.salvage_rate = _pick_salvage_rate(rep_factor)
	contract.salvage_type = "items" if randi() % 3 == 0 else "exchange"

	contract.command_rights = _determine_command_rights(issuer, rep_factor)

	var combined = float(contract.c_bill_payment) / 1000000.0 + contract.salvage_rate
	contract.battle_loss_reimbursement_rate = clamp(1.0 - combined * 0.8, 0.05, 0.85) + (randi() % 15) / 100.0

	contract.transport_coverage = (randi() % 50 + 50) / 100.0
	contract.base_coverage = (randi() % 40 + 20) / 100.0

	contract.minimum_tonnage = (randi() % 200 + 20) * 1.0
	contract.minimum_tactical_unit_counts = _generate_minimum_units(contract.activity_type)

	var total_ticks = contract.duration
	contract.payout_per_tick = contract.c_bill_payment / total_ticks if total_ticks > 0 else 0

	return contract


func _pick_target(issuer: Faction) -> Faction:
	if not issuer.enemies.is_empty() and randi() % 10 < 7:
		var code = issuer.enemies[randi() % issuer.enemies.size()]
		var t = GameState.get_faction(code)
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


func _pick_activity_type(is_border: bool) -> String:
	if is_border:
		var pool = ["Assault", "Raid", "Recon", "Defense"]
		return pool[randi() % pool.size()]
	else:
		var pool = ["Garrison", "Cadre", "Recon", "Defense"]
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


func _determine_command_rights(issuer: Faction, rep_factor: float) -> Enums.CommandRights:
	var urgent = rep_factor < -0.3

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
