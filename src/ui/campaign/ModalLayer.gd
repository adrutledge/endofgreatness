extends CanvasLayer

## Handles modal dialogs above all other content (layer 4).
## Background dim overlay blocks clicks to everything underneath.
## Dialogs are queued FIFO — if multiple trigger simultaneously, each
## is shown in arrival order. Dismissing one advances to the next.
##
## Each modal has a `pauses_game` flag. When a pausing modal reaches the
## top of the queue, TimeManager pauses. Time stays paused until no
## pausing modals remain in the queue.

var _bg: ColorRect
var _container: CenterContainer
var _queue: Array[Dictionary] = []


func _ready() -> void:
	layer = 4

	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.55)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_resize_bg)
	add_child(_bg)
	_bg.hide()

	_container = CenterContainer.new()
	_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_container)
	_container.hide()


func _resize_bg() -> void:
	_bg.size = get_viewport().get_visible_rect().size


## Queues a modal dialog. If no dialog is currently shown, displays it
## immediately. Otherwise it waits in FIFO order.
## If pauses_game is true, TimeManager pauses while this modal is visible.
func queue_modal(content: Control, pauses_game: bool = false) -> void:
	_queue.append({"content": content, "pauses": pauses_game})
	if _queue.size() == 1:
		_show_current()


## Dismisses the current dialog and shows the next in queue, if any.
func dismiss() -> void:
	if _queue.is_empty():
		return
	var entry = _queue[0]
	var was_pausing = entry.get("pauses", false)
	_hide_current()
	var dismissed = entry.get("content")
	_container.remove_child(dismissed)
	dismissed.queue_free()
	_queue.pop_front()

	if not _queue.is_empty():
		_show_current()
	elif was_pausing:
		TimeManager.unpause()


func _show_current() -> void:
	if _queue.is_empty():
		return
	var entry = _queue[0]
	_container.add_child(entry.content)
	if entry.pauses:
		TimeManager.pause()
	_bg.show()
	_container.show()


func _hide_current() -> void:
	_bg.hide()
	_container.hide()
