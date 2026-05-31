extends CanvasLayer

@onready var balance_label = $Margin/TopBar/Finances/BalanceLabel
@onready var bills_label = $Margin/TopBar/Finances/BillsLabel
@onready var contracts_label = $Margin/TopBar/Contracts/ContractsLabel
@onready var date_label = $Margin/TopBar/DateLabel
@onready var badges_container = $Margin/TopBar/BadgesContainer
@onready var funds_badge = $Margin/TopBar/BadgesContainer/FundsBadge
@onready var injured_badge = $Margin/TopBar/BadgesContainer/InjuredBadge
@onready var reorder_badge = $Margin/TopBar/BadgesContainer/ReorderBadge

@onready var org_mgmt_btn = $Margin/TopBar/QuickAccess/OrgMgmtButton
@onready var personnel_btn = $Margin/TopBar/QuickAccess/PersonnelButton
@onready var logistics_btn = $Margin/TopBar/QuickAccess/LogisticsButton
@onready var contract_board_btn = $Margin/TopBar/QuickAccess/ContractBoardButton
@onready var event_log_btn = $Margin/TopBar/QuickAccess/EventLogButton

func _ready() -> void:
	org_mgmt_btn.pressed.connect(_on_org_mgmt)
	personnel_btn.pressed.connect(_on_personnel)
	logistics_btn.pressed.connect(_on_logistics)
	contract_board_btn.pressed.connect(_on_contract_board)
	event_log_btn.pressed.connect(_on_event_log)

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


func _refresh_finances() -> void:
	var balance = EconomySystem.get_balance() if EconomySystem else 0
	balance_label.text = tr("C-Bills: %s") % Helpers.fmt_money(balance)

	var burn = EconomySystem.get_daily_burn_rate() if EconomySystem else {}
	var daily = burn.get("total", 0)
	bills_label.text = tr("Daily Burn: %s/day") % Helpers.fmt_money(daily)


func _refresh_contracts() -> void:
	var active = GameState.active_contracts.size() if GameState else 0
	if active > 0:
		contracts_label.text = tr("%d contract(s) active") % active
		contracts_label.show()
	else:
		contracts_label.hide()


func _refresh_badges() -> void:
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
	if TimeManager:
		date_label.text = TimeManager.get_date_string()


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
