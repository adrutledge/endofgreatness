class_name StrategicActions
extends Panel

signal personnel_management_requested()

signal contract_board_requested()
signal organization_tree_requested()
signal event_log_requested()
signal mech_lab_requested()
signal logistics_requested()
signal market_requested()

const POP_MARGIN: int = 30
const SIDEBAR_WIDTH: int = 300

var _slide_tween: Tween
var _is_shown: bool = true
var _locked_open: bool = false


func _ready() -> void:
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.12, 0.97)
	add_theme_stylebox_override("panel", bg)
	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_connect_signals()
	_slide_out(false)


func _input(event: InputEvent) -> void:
	if _locked_open:
		return
	if event is InputEventMouseMotion:
		var vp = get_viewport()
		var mx = vp.get_mouse_position().x
		var vw = vp.get_visible_rect().size.x
		if mx >= vw - POP_MARGIN:
			_slide_in()
		elif not _is_any_button_hovered() and mx < vw - SIDEBAR_WIDTH - POP_MARGIN:
			_slide_out()


func _is_any_button_hovered() -> bool:
	for c in %VBox.get_children():
		if c is Button and c.is_hovered():
			return true
	return false


func lock() -> void:
	_locked_open = true
	_slide_in()


func unlock() -> void:
	_locked_open = false


func show_sidebar() -> void:
	show()
	_slide_in()


func hide_sidebar() -> void:
	lock()
	hide()


func _slide_in(animate: bool = true) -> void:
	if _is_shown:
		return
	_is_shown = true
	if animate and _slide_tween and _slide_tween.is_running():
		_slide_tween.kill()
	if animate:
		_slide_tween = create_tween()
		_slide_tween.tween_property(self, "offset_left", -SIDEBAR_WIDTH, 0.15).set_ease(Tween.EASE_OUT)
	else:
		offset_left = -SIDEBAR_WIDTH


func _slide_out(animate: bool = true) -> void:
	if not _is_shown:
		return
	_is_shown = false
	if animate and _slide_tween and _slide_tween.is_running():
		_slide_tween.kill()
	if animate:
		_slide_tween = create_tween()
		_slide_tween.tween_property(self, "offset_left", 0, 0.15).set_ease(Tween.EASE_OUT)
	else:
		offset_left = 0

func _connect_signals() -> void:
	%PersonnelButton.pressed.connect(_on_personnel)
	%EventLogButton.pressed.connect(_on_event_log)
	%MechLabButton.pressed.connect(_on_mech_lab)
	%LogisticsButton.pressed.connect(_on_logistics)

func _on_personnel() -> void:
	personnel_management_requested.emit()

func _on_market() -> void:
	market_requested.emit()

func _on_contract_board() -> void:
	contract_board_requested.emit()

func _on_organization_tree() -> void:
	organization_tree_requested.emit()

func _on_mech_lab() -> void:
	mech_lab_requested.emit()

func _on_event_log() -> void:
	event_log_requested.emit()

func _on_logistics() -> void:
	logistics_requested.emit()
