class_name StrategicActions
extends Panel

signal personnel_management_requested()
signal unit_roster_requested()
signal contract_board_requested()
signal organization_tree_requested()
signal event_log_requested()
signal mech_lab_requested()
signal logistics_requested()
signal market_requested()

func _ready() -> void:
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.12, 0.97)
	add_theme_stylebox_override("panel", bg)
	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_connect_signals()

func _connect_signals() -> void:
	%PersonnelButton.pressed.connect(_on_personnel)
	%UnitRosterButton.pressed.connect(_on_unit_roster)
	%ContractBoardButton.pressed.connect(_on_contract_board)
	%OrganizationTreeButton.pressed.connect(_on_organization_tree)
	%EventLogButton.pressed.connect(_on_event_log)
	%MechLabButton.pressed.connect(_on_mech_lab)
	%LogisticsButton.pressed.connect(_on_logistics)

func _on_personnel() -> void:
	personnel_management_requested.emit()

func _on_unit_roster() -> void:
	unit_roster_requested.emit()

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
