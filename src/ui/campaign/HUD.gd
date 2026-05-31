extends CanvasLayer

var balance_label: Label
var bills_label: Label
var contracts_label: Label
var date_label: Label
var time_label: Label
var badges_container: HBoxContainer
var funds_badge: Label
var injured_badge: Label
var reorder_badge: Label
var org_mgmt_btn: Button
var personnel_btn: Button
var logistics_btn: Button
var contract_board_btn: Button
var event_log_btn: Button
var menu_btn: MenuButton


func _ready() -> void:
	_ensure_nodes()
	org_mgmt_btn.pressed.connect(_on_org_mgmt)
	personnel_btn.pressed.connect(_on_personnel)
	logistics_btn.pressed.connect(_on_logistics)
	contract_board_btn.pressed.connect(_on_contract_board)
	event_log_btn.pressed.connect(_on_event_log)

	menu_btn.get_popup().add_item(tr("Save Game"))
	menu_btn.get_popup().add_item(tr("Load Game"))
	menu_btn.get_popup().add_separator()
	menu_btn.get_popup().add_item(tr("Quit to Main Menu"))
	menu_btn.get_popup().id_pressed.connect(_on_menu_selected)

	EventBus.month_started.connect(_refresh)
	EventBus.contract_accepted.connect(_refresh)
	EventBus.contract_completed.connect(_refresh)
	EventBus.bills_paid.connect(_refresh)
	EventBus.funds_depleted.connect(_refresh)
	TimeManager.date_changed.connect(_refresh)
	_refresh()


func _ensure_nodes() -> void:
	if balance_label:
		return
	var topbar = find_child("TopBar", true, false)
	if not topbar:
		printerr("HUD: TopBar not found")
		return
	balance_label = _find_in(topbar, "Finances/BalanceLabel")
	bills_label = _find_in(topbar, "Finances/BillsLabel")
	contracts_label = _find_in(topbar, "Contracts/ContractsLabel")
	date_label = _find_in(topbar, "DateTime/DateLabel")
	time_label = _find_in(topbar, "DateTime/TimeLabel")
	badges_container = _find_in(topbar, "BadgesContainer")
	funds_badge = _find_in(topbar, "BadgesContainer/FundsBadge")
	injured_badge = _find_in(topbar, "BadgesContainer/InjuredBadge")
	reorder_badge = _find_in(topbar, "BadgesContainer/ReorderBadge")
	org_mgmt_btn = _find_in(topbar, "QuickAccess/OrgMgmtButton")
	personnel_btn = _find_in(topbar, "QuickAccess/PersonnelButton")
	logistics_btn = _find_in(topbar, "QuickAccess/LogisticsButton")
	contract_board_btn = _find_in(topbar, "QuickAccess/ContractBoardButton")
	event_log_btn = _find_in(topbar, "QuickAccess/EventLogButton")
	menu_btn = _find_in(topbar, "MenuButton")


func _find_in(parent: Node, path: String) -> Node:
	var parts = path.split("/")
	var current = parent
	for part in parts:
		current = current.get_node_or_null(part)
		if not current:
			printerr("HUD: node %s not found in %s" % [part, parent.name])
			return null
	return current