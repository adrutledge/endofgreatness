extends CanvasLayer

## Handles modal dialogs above all other content (layer 4).
## Background dim overlay blocks clicks to everything underneath.
## Dialogs are queued FIFO — if multiple trigger simultaneously, each
## is shown in arrival order. Dismissing one advances to the next.

var _bg: ColorRect
var _container: CenterContainer
var _queue: Array[Control] = []


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
func queue_modal(content: Control) -> void:
	_queue.append(content)
	if _queue.size() == 1:
		_show_current()


## Dismisses the current dialog and shows the next in queue, if any.
func dismiss() -> void:
	if _queue.is_empty():
		return
	_hide_current()
	var dismissed = _queue.pop_front()
	_container.remove_child(dismissed)
	dismissed.queue_free()
	if not _queue.is_empty():
		_show_current()


func _show_current() -> void:
	if _queue.is_empty():
		return
	_container.add_child(_queue[0])
	_bg.show()
	_container.show()


func _hide_current() -> void:
	_bg.hide()
	_container.hide()
