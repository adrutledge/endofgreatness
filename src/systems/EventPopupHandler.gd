extends Node

var generator: StrategicEventGenerator


func _ready() -> void:
	generator = StrategicEventGenerator.new()
	add_child(generator)


func show_event(event_data: Dictionary) -> void:
	if event_data.is_empty():
		return

	GameState.log_event(
		"strategic_event",
		{
			"id": event_data.get("id", ""),
			"title": event_data.get("title", ""),
			"description": event_data.get("description", ""),
			"date": event_data.get("date", {})
		}
	)

	EventBus.emit_event_triggered(event_data)


func process_choice(event_data: Dictionary, choice_index: int) -> void:
	var event_id: String = event_data.get("id", "")
	var context: Dictionary = event_data.get("context", {})

	var outcome: Dictionary = generator.resolve_choice(event_id, choice_index, context)
	if outcome.is_empty():
		return

	var message: String = outcome.get("message", "")
	if message:
		GameState.log_event("event_outcome", {
			"event_id": event_id,
			"choice_index": choice_index,
			"message": message,
			"funds_delta": outcome.get("funds_delta", 0),
			"reputation_delta": outcome.get("reputation_delta", {}),
			"personnel_effect": outcome.get("personnel_effect", "")
		})
