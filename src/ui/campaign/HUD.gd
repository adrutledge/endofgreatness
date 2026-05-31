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
	balance_label = $TopBar/Finances/BalanceLabel
	bills_label = $TopBar/Finances/BillsLabel
	contracts_label = $TopBar/Contracts/ContractsLabel
	date_label = $TopBar/DateTime/DateLabel
	time_label = $TopBar/DateTime/TimeLabel
	badges_container = $TopBar/BadgesContainer
	funds_badge = $TopBar/BadgesContainer/FundsBadge
	injured_badge = $TopBar/BadgesContainer/InjuredBadge
	reorder_badge = $TopBar/BadgesContainer/ReorderBadge
	org_mgmt_btn = $TopBar/QuickAccess/OrgMgmtButton
	personnel_btn = $TopBar/QuickAccess/PersonnelButton
	logistics_btn = $TopBar/QuickAccess/LogisticsButton
	contract_board_btn = $TopBar/QuickAccess/ContractBoardButton
	event_log_btn = $TopBar/QuickAccess/EventLogButton
	menu_btn = $TopBar/MenuButton

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


func _refresh(_dummy = null) -> void:
	_refresh_finances()
	_refresh_contracts()
	_refresh_badges()
	_refresh_date()
	_refresh_time()


func _refresh_finances() -> void:
	if not balance_label or not bills_label:
		return
	var balance = EconomySystem.get_balance() if EconomySystem else 0
	balance_label.text = tr("C-Bills: %s") % Helpers.fmt_money(balance)

	var burn = EconomySystem.get_daily_burn_rate() if EconomySystem else {}
	var daily = burn.get("total", 0)
	bills_label.text = tr("Daily Burn: %s/day") % Helpers.fmt_money(daily)


func _refresh_contracts() -> void:
	if not contracts_label:
		return
	var active = GameState.active_contracts.size() if GameState else 0
	if active > 0:
		contracts_label.text = tr("%d contract(s) active") % active
		contracts_label.show()
	else:
		contracts_label.hide()


func _refresh_badges() -> void:
	if not funds_badge or not injured_badge or not reorder_badge:
		return
	var balance = EconomySystem.get_balance() if EconomySystem else 0
	var next_bills = EconomySystem.accumulated_expenses if EconomySystem else 0

	if balance < 0:
		funds_badge.text = " [color=#ff4444]" + tr("⚠ FUNDS LOW") + "[/color] "
		funds_badge.visible = true
	elif balance < next_bills:
		funds_badge.text = " [color=#ffaa44]" + tr("⚠ FUNDS LOW") + "[/color] "
		funds_badge.visible = true
	else:
		funds_badge.visible = false

	var injured = false
	if PersonnelManager:
		for p in PersonnelManager.personnel_roster:
			if p.is_injured:
				injured = true
				break
	injured_badge.visible = injured

	reorder_badge.visible = false


func _refresh_date() -> void:
	if not date_label:
		return
	if TimeManager:
		date_label.text = TimeManager.get_date_string()


func _refresh_time() -> void:
	var t = Time.get_time_dict_from_system()
	time_label.text = "%02d:%02d" % [t.hour, t.minute]


func _on_menu_selected(id: int) -> void:
	get_viewport().set_input_as_handled()
	match id:
		0:
			pass
		1:
			pass
		2:
			get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")


func _on_personnel() -> void:
	PanelManager.open_panel("personnel")


func _on_event_log() -> void:
	PanelManager.open_panel("event_log")


func _on_logistics() -> void:
	PanelManager.open_panel("logistics")


func _on_contract_board() -> void:
	PanelManager.open_panel("contract_board")


func _on_org_mgmt() -> void:
	PanelManager.open_panel("org_mgmt")
