extends Node

var global_reputation: int = 0
var faction_reputation: Dictionary = {}

const REPUTATION_TIERS = ["Dirty", "Controversial", "Reliable", "Honored", "Elite"]

func get_reputation_tier(value: int) -> String:
	if value < -50:
		return REPUTATION_TIERS[0]
	elif value < 0:
		return REPUTATION_TIERS[1]
	elif value < 50:
		return REPUTATION_TIERS[2]
	elif value < 100:
		return REPUTATION_TIERS[3]
	else:
		return REPUTATION_TIERS[4]

func modify_reputation(faction: String, delta: int, reason: String = "") -> void:
	var faction_data = GameState.get_faction(faction)
	if faction_data and (faction_data.is_rebel or faction_data.is_pirate or faction_data.is_civilian):
		global_reputation += delta
	else:
		var current = faction_reputation.get(faction, 0)
		current += delta
		faction_reputation[faction] = clamp(current, -100, 100)
		EventBus.emit_reputation_changed(faction, delta, reason)

func get_faction_reputation(faction: String) -> int:
	return faction_reputation.get(faction, 0)

func get_faction_reputation_tier(faction: String) -> String:
	return get_reputation_tier(get_faction_reputation(faction))

func get_global_reputation_tier() -> String:
	return get_reputation_tier(global_reputation)

func meets_threshold(faction: String, required_tier: String) -> bool:
	var tier_value = REPUTATION_TIERS.find(required_tier)
	if tier_value < 0:
		return false
	var current_value: int
	if faction == "Global":
		current_value = global_reputation
	else:
		current_value = get_faction_reputation(faction)
	return current_value >= (tier_value * 25) - 50
