class_name StrategicEventGenerator
extends Node

var event_pool: Array[Dictionary] = []
var cooldown_ticks: int = 3
var ticks_since_last_event: int = 0

func _ready() -> void:
	_load_event_pool()


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


func _load_event_pool() -> void:
	event_pool.clear()
	var dir = DirAccess.open("res://data/events/strategic/")
	if not dir:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var file = FileAccess.open("res://data/events/strategic/" + fname, FileAccess.READ)
			if file:
				var j = JSON.new()
				if j.parse(file.get_as_text()) == OK:
					var data = j.data
					var events: Array = data.get("events", [])
					for ev in events:
						if ev.has("id") and ev.has("choices"):
							event_pool.append(ev)
		fname = dir.get_next()


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
