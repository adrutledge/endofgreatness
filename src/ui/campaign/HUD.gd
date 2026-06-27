extends CanvasLayer

func _ready() -> void:
	var topbar = $TopBar
	topbar.get_node("QuickAccess/OrgMgmtButton").pressed.connect(_on_org_mgmt)
	topbar.get_node("QuickAccess/PersonnelButton").pressed.connect(_on_personnel)
	topbar.get_node("QuickAccess/LogisticsButton").pressed.connect(_on_logistics)
	topbar.get_node("QuickAccess/ContractBoardButton").pressed.connect(_on_contract_board)
	topbar.get_node("QuickAccess/EventLogButton").pressed.connect(_on_event_log)

	var menu_btn = topbar.get_node("MenuButton")
	menu_btn.pressed.connect(_on_menu_button)

	var tc = $TopBar/TimeControls
	tc.get_node("PauseButton").pressed.connect(_on_toggle_pause)
	tc.get_node("Speed1x").toggled.connect(func(t): _on_speed("1x", t))
	tc.get_node("Speed2x").toggled.connect(func(t): _on_speed("2x", t))
	tc.get_node("Speed5x").toggled.connect(func(t): _on_speed("5x", t))

	EventBus.month_started.connect(_refresh)
	EventBus.contract_accepted.connect(_refresh)
	EventBus.contract_completed.connect(_refresh)
	EventBus.bills_paid.connect(func(_a, _b): _refresh())
	EventBus.funds_depleted.connect(_refresh)
	EventBus.day_started.connect(_refresh)
	_refresh()


func _on_toggle_pause() -> void:
	if TimeManager:
		TimeManager.toggle_pause()
		var btn = $TopBar/TimeControls/PauseButton
		btn.text = "▶" if TimeManager.is_paused else "❚❚"


func _on_speed(speed: String, toggled: bool) -> void:
	if not toggled:
		return
	$TopBar/TimeControls/Speed1x.button_pressed = speed == "1x"
	$TopBar/TimeControls/Speed2x.button_pressed = speed == "2x"
	$TopBar/TimeControls/Speed5x.button_pressed = speed == "5x"
	if TimeManager:
		match speed:
			"1x": TimeManager.tick_interval = 1.0
			"2x": TimeManager.tick_interval = 0.5
			"5x": TimeManager.tick_interval = 0.2


func _on_menu_button() -> void:
	var cv = get_tree().current_scene
	if not cv or not cv.has_method("show_modal"):
		printerr("HUD: CampaignView not found")
		return
	var menu = preload("res://src/ui/campaign/GameMenu.tscn").instantiate()
	menu.dismissed.connect(cv.dismiss_modal)
	cv.show_modal(menu)


func _refresh(_dummy = null) -> void:
	_refresh_finances()
	_refresh_contracts()
	_refresh_badges()
	_refresh_date()
	_refresh_time()


func _refresh_finances() -> void:
	var topbar = $TopBar
	var balance_label = topbar.get_node("Finances/BalanceLabel")
	var finances = topbar.get_node("Finances")
	var bills_label = finances.get_node("BillsLabel") if finances and finances.has_node("BillsLabel") else null
	var balance = EconomySystem.get_balance() if EconomySystem else 0
	balance_label.text = tr("C-Bills: %s") % Helpers.fmt_money(balance)
	var burn = EconomySystem.get_daily_burn_rate() if EconomySystem else {}
	var daily = burn.get("total", 0)
	if bills_label:
		bills_label.text = tr("Daily Burn: %s/day") % Helpers.fmt_money(daily)


func _refresh_contracts() -> void:
	var contracts_label = $TopBar/Contracts/ContractsLabel
	var active = GameState.active_contracts.size() if GameState else 0
	if active > 0:
		contracts_label.text = tr("%d contract(s) active") % active
		contracts_label.show()
	else:
		contracts_label.hide()


func _refresh_badges() -> void:
	var topbar = $TopBar
	var funds_badge = topbar.get_node("BadgesContainer/FundsBadge")
	var injured_badge = topbar.get_node("BadgesContainer/InjuredBadge")
	var reorder_badge = topbar.get_node("BadgesContainer/ReorderBadge")
	var balance = EconomySystem.get_balance() if EconomySystem else 0
	var burn = EconomySystem.get_daily_burn_rate() if EconomySystem else {}
	var daily = burn.get("total", 0)
	var days_left := 999
	if daily > 0:
		days_left = int(balance / daily)
	if balance < 0:
		funds_badge.text = " [color=#ff4444]" + tr("⚠ FUNDS DEPLETED") + "[/color] "
		funds_badge.visible = true
	elif days_left <= 7:
		funds_badge.text = " [color=#ffaa44]" + tr("⚠ FUNDS LOW: %d days") % days_left + "[/color] "
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

	# Reorder badge: show if any active contract has no deployed units
	var has_undeployed = false
	if GameState:
		for c in GameState.active_contracts:
			var found_deployed = false
			for ou in GameState.player.organizational_units:
				if ou.contract_id == str(c.get_instance_id()):
					found_deployed = true
					break
			if not found_deployed:
				has_undeployed = true
				break
	if has_undeployed:
		reorder_badge.text = " [color=#ffaa44]" + tr("⚠ DEPLOY PENDING") + "[/color] "
		reorder_badge.visible = true
	else:
		reorder_badge.visible = false


func _refresh_date() -> void:
	var date_label = $TopBar/DateTime/DateLabel
	if TimeManager:
		date_label.text = TimeManager.get_date_string()


func _refresh_time() -> void:
	var time_label = $TopBar/DateTime/TimeLabel
	var t = Time.get_time_dict_from_system()
	time_label.text = "%02d:%02d" % [t.hour, t.minute]


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
