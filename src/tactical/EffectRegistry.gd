class_name EffectRegistry
extends RefCounted

## Effect handler registry for terrain-based movement effects.
##
## Handlers are registered by effect tag ID and called by the movement
## resolver to compute per-edge modifiers and risk metadata.
##
## Reference: data/rules/terrain_effects.json for effect tag documentation.
## PSR trigger definitions in data/rules/psr_triggers.json.

## Result dictionary returned by a handler:
## {
##   cost_mod: int,
##   blocked: bool,
##   psr_trigger: String,  # condition string matching psr_triggers.json
##   psr_modifier: int,
##   psr_data: Dictionary, # full trigger entry from psr_triggers.json
##   collapse_warning: bool,
## }

static var _registry: Dictionary = {}
static var _ready: bool = false
static var _trigger_cache: Array = []


static func _ensure_registry() -> void:
	if _ready:
		return
	_ready = true

	register("cover_light", _handler_identity)
	register("cover_heavy", _handler_identity)
	register("water_terrain", _handler_identity)
	register("risk_psr_water", _handler_psr("water_entry", -1))
	register("risk_psr_rough", _handler_psr("rough_terrain", 0))
	register("risk_psr_sand", _handler_psr("sand_entry", 1))
	register("risk_psr_snow", _handler_psr("snow_entry", 1))
	register("risk_psr_swamp", _handler_psr("swamp_entry", 1))
	register("surface_slippery", _handler_slippery)
	register("skid_risk_on_run_turn", _handler_skid)
	register("bog_down_chance", _handler_identity)


static func register(tag: String, handler: Callable) -> void:
	_registry[tag] = handler


## Returns all trigger entries from psr_triggers.json.
static func get_all_triggers() -> Array:
	if _trigger_cache.is_empty():
		var file = FileAccess.open("res://data/rules/psr_triggers.json", FileAccess.READ)
		if file:
			var j = JSON.new()
			if j.parse(file.get_as_text()) == OK:
				_trigger_cache = j.data.get("triggers", [])
	return _trigger_cache


## Looks up the full trigger entry for a condition string.
static func get_trigger_data(condition: String) -> Dictionary:
	for t in get_all_triggers():
		if t.get("condition") == condition:
			return t
	return {}


## Evaluates all handlers for the given effect tags.
## Returns aggregated EdgeResult.
static func evaluate(tags: Array, mode: String, run_data: Dictionary = {}) -> Dictionary:
	_ensure_registry()
	var result := {
		"cost_mod": 0,
		"blocked": false,
		"psr_trigger": "",
		"psr_modifier": 0,
		"psr_data": {},
		"collapse_warning": false,
	}
	for tag in tags:
		if not _registry.has(tag):
			continue
		var handler = _registry[tag]
		var r = handler.call(run_data)
		result.cost_mod += r.get("cost_mod", 0)
		result.blocked = result.blocked or r.get("blocked", false)
		if not r.get("psr_trigger", "").is_empty():
			result.psr_trigger = r.psr_trigger
			result.psr_modifier += r.get("psr_modifier", 0)
			result.psr_data = r.get("psr_data", {})
		result.collapse_warning = result.collapse_warning or r.get("collapse_warning", false)
	return result


static func _handler_identity(_data: Dictionary) -> Dictionary:
	return {}


static func _handler_psr(condition: String, mod: int) -> Callable:
	return func(_data: Dictionary) -> Dictionary:
		var trigger_entry = get_trigger_data(condition)
		return {
			"psr_trigger": condition,
			"psr_modifier": mod,
			"psr_data": trigger_entry,
		}


static func _handler_slippery(_data: Dictionary) -> Dictionary:
	return {"cost_mod": 1}


static func _handler_skid(data: Dictionary) -> Dictionary:
	var mode = data.get("mode", "")
	if mode == "run":
		var trigger_entry = get_trigger_data("run_after_turn_on_paved")
		return {
			"psr_trigger": "run_after_turn_on_paved",
			"psr_modifier": 1,
			"psr_data": trigger_entry,
		}
	return {}
