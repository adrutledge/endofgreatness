class_name ContractBoard
extends Panel

signal closed()

var _generator: ContractGenerator
var _available: Array[Contract] = []
var _selected_contract: Contract
var _selected_is_active: bool = false
var _dirty: bool = true

@onready var available_list: ItemList = %AvailableList
@onready var active_list: ItemList = %ActiveList
@onready var detail_name: Label = %DetailName
@onready var detail_type: Label = %DetailType
@onready var detail_info: Label = %DetailInfo
@onready var detail_panel: Panel = %DetailPanel
@onready var accept_button: Button = %AcceptButton
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	Helpers.debug_print("ContractBoard", "_ready start")
	Helpers.validate_nodes("ContractBoard", [
		["available_list", available_list], ["active_list", active_list],
		["detail_name", detail_name], ["detail_type", detail_type],
		["detail_info", detail_info], ["detail_panel", detail_panel],
		["accept_button", accept_button], ["close_button", close_button],
	])
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	add_theme_stylebox_override("panel", bg)

	var ds = StyleBoxFlat.new()
	ds.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	detail_panel.add_theme_stylebox_override("panel", ds)

	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	%AvailableLabel.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	%ActiveLabel.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	detail_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	detail_type.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))

	accept_button.pressed.connect(_on_accept)
	close_button.pressed.connect(_on_close)
	available_list.item_selected.connect(_on_available_selected)
	active_list.item_selected.connect(_on_active_selected)

	_generator = ContractGenerator.new()
	add_child(_generator)
	EventBus.month_started.connect(_on_month_started)
	Helpers.debug_print("ContractBoard", "_ready done")


func _on_month_started(date: Dictionary) -> void:
	_dirty = true


func populate() -> void:
	Helpers.debug_print("ContractBoard", "populate")
	available_list.clear()
	active_list.clear()
	_clear_details()
	accept_button.disabled = true

	if not TimeManager or not GameState or not GameState.player:
		Helpers.debug_warn("ContractBoard", "populate — TimeManager/GameState/player not ready")
		return

	if _dirty:
		_dirty = false
		var date = TimeManager.current_date
		var location = GameState.player.current_planet if GameState.player.current_planet else ""
		_available = _generator.generate_contracts(date, location, 0, {})

	for c in _available:
		if not c:
			continue
		var label = "%s — %s on %s\n%d days, %d C-Bills" % [c.issuer, c.activity_type, c.planet, c.duration, c.c_bill_payment]
		available_list.add_item(label)

	for c in GameState.active_contracts:
		if not c:
			continue
		var label = "%s — %s on %s" % [c.issuer, c.activity_type, c.planet]
		active_list.add_item(label)


func _on_available_selected(index: int) -> void:
	if index < 0 or index >= _available.size():
		return
	_selected_contract = _available[index]
	_selected_is_active = false
	accept_button.disabled = false
	accept_button.text = tr("Accept Contract")
	_show_contract_details(_selected_contract)


func _on_active_selected(index: int) -> void:
	var active = GameState.active_contracts
	if index < 0 or index >= active.size():
		return
	_selected_contract = active[index]
	_selected_is_active = true
	accept_button.disabled = true
	_show_contract_details(_selected_contract)


func _show_contract_details(c: Contract) -> void:
	detail_name.text = "%s — %s" % [c.issuer, c.activity_type]
	detail_type.text = tr("Location: %s  |  Duration: %d days") % [c.planet, c.duration]

	var info = ""
	info += tr("Payment: %d C-Bills") % c.c_bill_payment + "\n"
	info += tr("Payout per month: %d C-Bills") % c.payout_per_month + "\n"
	info += tr("Salvage rate: %d%% (%s)") % [c.salvage_rate * 100, c.salvage_type] + "\n"
	var rights_keys = Enums.CommandRights.keys()
	var rights_name = rights_keys[c.command_rights] if c.command_rights >= 0 and c.command_rights < rights_keys.size() else tr("Unknown")
	info += tr("Command rights: %s") % rights_name + "\n"
	info += tr("Transport coverage: %d%%") % (c.transport_coverage * 100) + "\n"
	info += tr("Battle loss reimbursement: %d%%") % (c.battle_loss_reimbursement_rate * 100) + "\n"
	info += tr("Minimum tonnage: %.0f tons") % c.minimum_tonnage + "\n"
	info += tr("Minimum tactical units:") + "\n"
	for k in c.minimum_tactical_unit_counts:
		info += "  %s: %d\n" % [k, c.minimum_tactical_unit_counts[k]]

	var status = ""
	if c.is_active:
		status = tr("ACTIVE")
	elif c.is_completed:
		status = tr("COMPLETED")
	else:
		status = tr("Available")
	info += "\n" + tr("Status: %s") % status

	detail_info.text = info


func _on_accept() -> void:
	if not _selected_contract or _selected_is_active:
		return
	GameState.add_active_contract(_selected_contract)
	_available.erase(_selected_contract)
	_selected_contract = null
	_selected_is_active = false
	populate()


func _clear_details() -> void:
	detail_name.text = ""
	detail_type.text = ""
	detail_info.text = ""


func _on_close() -> void:
	hide()
	closed.emit()
