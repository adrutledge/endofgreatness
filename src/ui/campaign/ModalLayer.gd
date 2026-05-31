extends CanvasLayer

## Handles modal dialogs above all other content (layer 4).
## Background dim overlay blocks clicks to everything underneath.
## Content control is centered on screen. Caller connects to the
## content's signals (e.g., confirmed/cancelled) to know when to dismiss.

var _bg: ColorRect
var _container: CenterContainer
var _current: Control


func _ready() -> void:
	layer = 4
	mouse_filter = Control.MOUSE_FILTER_STOP

	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.55)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.size = get_viewport_rect().size
	get_viewport().size_changed.connect(_resize_bg)
	add_child(_bg)
	_bg.hide()

	_container = CenterContainer.new()
	_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_container)
	_container.hide()


func _resize_bg() -> void:
	_bg.size = get_viewport_rect().size


## Shows a modal dialog. The given Control is centered on screen
## above a dimmed background. Replaces any existing modal.
func show(content: Control) -> void:
	_dismiss_current()
	_current = content
	_container.add_child(content)
	_bg.show()
	_container.show()


## Hides and removes the current modal.
func dismiss() -> void:
	_dismiss_current()


func _dismiss_current() -> void:
	_bg.hide()
	_container.hide()
	if _current:
		_container.remove_child(_current)
		_current.queue_free()
		_current = null
