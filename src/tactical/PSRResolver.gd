class_name PSRResolver
extends Node

## Evaluates and resolves Piloting Skill Rolls.
##
## Per-engagement instance. Loads PSR trigger definitions from data,
## evaluates conditions against the current game state, and resolves
## failures with their defined consequences.

var _triggers: Array = []
var _loaded: bool = false


func _ready() -> void:
	_load_triggers()


func _load_triggers() -> void:
	var file = FileAccess.open("res://data/rules/psr_triggers.json", FileAccess.READ)
	if not file:
		return
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK:
		return
	_triggers = j.data.get("triggers", [])
	_loaded = true


## Returns the active trigger list filtered by enabled tags.
func get_active_triggers(enabled_tags: Array = []) -> Array:
	if not _loaded:
		return []
	if enabled_tags.is_empty():
		return _triggers
	var result: Array = []
	for t in _triggers:
		var tags: Array = t.get("tags", [])
		var keep = false
		for tag in tags:
			if tag in enabled_tags:
				keep = true
				break
		if keep:
			result.append(t)
	return result


## Evaluates whether a PSR is triggered for the given condition key.
## Returns the trigger dict if triggered, null otherwise.
func check_trigger(condition_key: String, context: Dictionary = {}) -> Dictionary:
	for t in _triggers:
		if t.get("condition", "") == condition_key:
			return t.duplicate()
	return {}


## Resolves a PSR. Returns Dictionary with success, roll, modifier, effects.
func resolve_psr(piloting_skill: int, modifier: int = 0) -> Dictionary:
	var tn = piloting_skill + modifier
	var roll = randi() % 6 + randi() % 6 + 2
	var success = roll >= tn
	var result = {
		"success": success,
		"roll": roll,
		"tn": tn,
		"modifier": modifier,
		"pilot_skill": piloting_skill
	}
	if Helpers.debug:
		var eb = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() else null
		if eb:
			eb.emit_rules_check("psr", {
				"pilot_skill": piloting_skill,
				"modifier": modifier,
			}, result)
	return result


## Evaluates all active triggers for a given movement/fire action.
## Returns Array of trigger results including PSR outcomes.
func evaluate_movement(movement_type: String, path: Array, unit_state: Dictionary,
		enabled_tags: Array = []) -> Array:
	var results: Array = []
	var active = get_active_triggers(enabled_tags)
	for trigger in active:
		var condition = trigger.get("condition", "")
		var match = _evaluate_condition(condition, movement_type, path, unit_state)
		if match:
			var psr_result = resolve_psr(
				unit_state.get("piloting_skill", 5),
				trigger.get("modifier", 0)
			)
			results.append({
				"trigger": trigger,
				"psr": psr_result,
				"failure_effects": trigger.get("on_failure", {})
			})
	return results


func _evaluate_condition(condition: String, movement_type: String,
		path: Array, unit_state: Dictionary) -> bool:
	match condition:
		"run_after_turn_on_paved":
			return movement_type == "run" and _path_has_turn_on_paved(path)
		"jump_landing_with_damaged_leg_actuator":
			return movement_type == "jump" and unit_state.get("damaged_leg_actuator", false)
		"movement_exceeds_1g_mp":
			return unit_state.get("gravity_multiplier", 1.0) < 1.0 and \
				unit_state.get("mp_used", 0) > unit_state.get("walk_mp_1g", 0)
		"charge_declared":
			return movement_type == "charge"
		"dfa_landing":
			return movement_type == "dfa"
	return false


func _path_has_turn_on_paved(path: Array) -> bool:
	return false  # stub: path analysis pending
