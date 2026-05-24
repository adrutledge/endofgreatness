class_name StrategicEventGenerator
extends Node

var event_pool: Array[Dictionary] = []
var cooldown_ticks: int = 3
var ticks_since_last_event: int = 0

func _ready() -> void:
	_build_event_pool()


func generate_event(context: Dictionary) -> Dictionary:
	if ticks_since_last_event < cooldown_ticks:
		ticks_since_last_event += 1
		return {}

	if randf() > 0.15:
		ticks_since_last_event += 1
		return {}

	var eligible: Array[Dictionary] = []
	var total_weight: int = 0

	for event in event_pool:
		if check_conditions(event.conditions, context):
			var weight = event.weight
			var faction = context.get("faction", "")
			if faction and ReputationSystem.has_method("get_faction_reputation"):
				var rep = ReputationSystem.get_faction_reputation(faction)
				weight += max(rep / 10, 0)
			if context.has("contract_active") and context.contract_active:
				weight = max(weight - 1, 1)
			eligible.append({
				"event": event,
				"weight": weight
			})
			total_weight += weight

	if eligible.is_empty():
		ticks_since_last_event += 1
		return {}

	var roll: int = randi() % total_weight
	var cumulative: int = 0
	var chosen: Dictionary = eligible[0].event

	for entry in eligible:
		cumulative += entry.weight
		if roll < cumulative:
			chosen = entry.event
			break

	var resolved: Dictionary = {
		"id": chosen.id,
		"title": chosen.title,
		"description": chosen.description,
		"choices": chosen.choices,
		"date": TimeManager.current_date.duplicate(),
		"location": context.get("location", "current_system"),
		"context": context
	}

	ticks_since_last_event = 0
	EventBus.emit_event_triggered(resolved)
	return resolved


func _build_event_pool() -> void:
	event_pool = [
		{
			"id": "pirate_raid",
			"title": "Pirate Raid Incoming",
			"description": "Scouts report a pirate raid heading for your position. They outnumber you but their equipment is jury-rigged and poorly maintained.",
			"weight": 10,
			"conditions": {
				"requires_base": true,
				"min_reputation": -100,
				"exclude_factions": ["major_house"]
			},
			"choices": [
				{
					"label": "Fight them off",
					"outcome": {
						"reputation_delta": {},
						"funds_delta": 0,
						"personnel_effect": "minor_injuries",
						"message": "You drive off the pirates after a sharp engagement. Some personnel sustain minor injuries."
					}
				},
				{
					"label": "Pay them off (50,000 C-Bills)",
					"outcome": {
						"reputation_delta": {"locals": -5, "pirates": 10},
						"funds_delta": -50000,
						"personnel_effect": "none",
						"message": "The pirates take your payment and withdraw, though your standing with the locals suffers."
					}
				}
			]
		},
		{
			"id": "supply_delay",
			"title": "Supply Shipment Delayed",
			"description": "Your scheduled supply shipment has been delayed due to 'administrative complications' at the orbital depot. You're running low on critical spare parts.",
			"weight": 12,
			"conditions": {},
			"choices": [
				{
					"label": "Wait for normal processing",
					"outcome": {
						"reputation_delta": {},
						"funds_delta": 0,
						"personnel_effect": "morale_down",
						"message": "The shipment arrives a week late. Your techs grumble about the delay."
					}
				},
				{
					"label": "Pay for expedited handling (25,000 C-Bills)",
					"outcome": {
						"reputation_delta": {},
						"funds_delta": -25000,
						"personnel_effect": "none",
						"message": "A few well-placed C-Bills grease the wheels. Your shipment arrives on schedule."
					}
				}
			]
		},
		{
			"id": "faction_assistance",
			"title": "Faction Requests Assistance",
			"description": "A nearby faction representative contacts you with an urgent request: they need armed support for a 'security situation' at one of their outposts.",
			"weight": 8,
			"conditions": {
				"min_reputation": -20,
				"requires_contract": false
			},
			"choices": [
				{
					"label": "Provide assistance (+Reputation)",
					"outcome": {
						"reputation_delta": {"requesting_faction": 15, "opposing_faction": -5},
						"funds_delta": 0,
						"personnel_effect": "none",
						"message": "Your intervention is a success. The faction praises your professionalism."
					}
				},
				{
					"label": "Decline politely",
					"outcome": {
						"reputation_delta": {"requesting_faction": -10},
						"funds_delta": 0,
						"personnel_effect": "none",
						"message": "The faction representative is disappointed but understands your position."
					}
				}
			]
		},
		{
			"id": "personnel_dispute",
			"title": "Personnel Dispute",
			"description": "A heated argument has broken out between two senior members of your staff. The rest of the crew is taking sides, and morale is suffering.",
			"weight": 10,
			"conditions": {
				"requires_personnel": true
			},
			"choices": [
				{
					"label": "Mediate the dispute",
					"outcome": {
						"reputation_delta": {},
						"funds_delta": 0,
						"personnel_effect": "morale_up",
						"message": "You listen to both sides and broker a compromise. The crew respects your leadership."
					}
				},
				{
					"label": "Reassign personnel to different shifts",
					"outcome": {
						"reputation_delta": {},
						"funds_delta": 0,
						"personnel_effect": "morale_neutral",
						"message": "Separating the involved parties cools tensions, though the underlying issue remains unresolved."
					}
				}
			]
		},
		{
			"id": "lucky_find",
			"title": "Lucky Salvage Find",
			"description": "While reviewing local salvage listings, you spot an underpriced lot that contains valuable Star League-era components. Someone clearly didn't know what they had.",
			"weight": 6,
			"conditions": {},
			"choices": [
				{
					"label": "Snap it up immediately",
					"outcome": {
						"reputation_delta": {},
						"funds_delta": 50000,
						"personnel_effect": "morale_up",
						"message": "You acquire the salvage at a steal. The components are worth a small fortune."
					}
				}
			]
		},
		{
			"id": "mech_breakdown",
			"title": "Mech Component Failure",
			"description": "One of your BattleMechs suffers a critical myomer bundle failure during routine maintenance. The replacement part is expensive and hard to source.",
			"weight": 10,
			"conditions": {
				"requires_mech": true
			},
			"choices": [
				{
					"label": "Order replacement part (30,000 C-Bills)",
					"outcome": {
						"reputation_delta": {},
						"funds_delta": -30000,
						"personnel_effect": "none",
						"message": "The part arrives and your techs get the 'Mech operational again."
					}
				},
				{
					"label": "Cannibalize from another unit",
					"outcome": {
						"reputation_delta": {},
						"funds_delta": 0,
						"personnel_effect": "morale_down",
						"message": "You pull a part from another 'Mech, leaving it inoperative. The crew is unhappy with the makeshift solution."
					}
				}
			]
		},
		{
			"id": "diplomatic_visit",
			"title": "Faction Envoy Arrives",
			"description": "A diplomatic envoy from a major faction arrives unexpectedly, requesting a formal meeting. They seem to be evaluating your company for a potential long-term contract.",
			"weight": 8,
			"conditions": {
				"min_reputation": 10
			},
			"choices": [
				{
					"label": "Host them properly (10,000 C-Bills)",
					"outcome": {
						"reputation_delta": {"envoy_faction": 15},
						"funds_delta": -10000,
						"personnel_effect": "none",
						"message": "The envoy is impressed by your professionalism. Talks of a long-term contract begin."
					}
				},
				{
					"label": "Brief meeting only",
					"outcome": {
						"reputation_delta": {"envoy_faction": 3},
						"funds_delta": 0,
						"personnel_effect": "none",
						"message": "The meeting is cordial but brief. The envoy departs with a neutral impression."
					}
				}
			]
		}
	]


func check_conditions(conditions: Dictionary, context: Dictionary) -> bool:
	if conditions.is_empty():
		return true

	if conditions.has("requires_base") and conditions.requires_base:
		if not context.get("has_base", false):
			return false

	if conditions.has("min_reputation"):
		var faction = context.get("faction", "")
		var rep: int = 0
		if faction and ReputationSystem.has_method("get_faction_reputation"):
			rep = ReputationSystem.get_faction_reputation(faction)
		if rep < conditions.min_reputation:
			return false

	if conditions.has("exclude_factions"):
		var faction = context.get("faction", "")
		if faction in conditions.exclude_factions:
			return false

	if conditions.has("requires_contract"):
		if conditions.requires_contract and not context.get("contract_active", false):
			return false
		if not conditions.requires_contract and context.get("contract_active", false):
			return false

	if conditions.has("requires_personnel") and conditions.requires_personnel:
		var personnel = GameState.player.get_all_personnel()
		if personnel.is_empty():
			return false

	if conditions.has("requires_mech") and conditions.requires_mech:
		var has_mech: bool = false
		for ou in GameState.player.organizational_units:
			for tu in ou.get_all_tactical_units():
				if tu.components.size() > 0:
					has_mech = true
					break
			if has_mech:
				break
		if not has_mech:
			return false

	return true


func resolve_choice(event_id: String, choice_index: int, context: Dictionary) -> Dictionary:
	var choice_outcome: Dictionary = {}
	for event in event_pool:
		if event.id == event_id:
			if choice_index >= 0 and choice_index < event.choices.size():
				choice_outcome = event.choices[choice_index].outcome.duplicate(true)
			break

	if choice_outcome.is_empty():
		return {"message": "Invalid choice."}

	var delta_rep: Dictionary = choice_outcome.get("reputation_delta", {})
	for faction_key in delta_rep:
		var actual_faction: String = faction_key
		if faction_key == "requesting_faction":
			actual_faction = context.get("faction", "")
		elif faction_key == "opposing_faction":
			actual_faction = context.get("opposing_faction", "")
		elif faction_key == "envoy_faction":
			actual_faction = context.get("faction", "")

		if actual_faction:
			ReputationSystem.modify_reputation(actual_faction, delta_rep[faction_key], "Event: " + event_id)

	var delta_funds: int = choice_outcome.get("funds_delta", 0)
	if delta_funds != 0:
		if delta_funds > 0:
			EconomySystem.add_funds(delta_funds, "Event: " + event_id)
		else:
			EconomySystem.deduct_funds(-delta_funds, "Event: " + event_id)

	return choice_outcome
