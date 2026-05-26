class_name LogisticsPanel
extends Panel

signal closed()

# Market state
var current_items: Array[Dictionary] = []
var remote_results: Array[Dictionary] = []
var selected_item_name: String = ""
var selected_remote_idx: int = -1
var remote_item_name: String = ""
var _selected_market_planet: String = ""
var _planet_selector: OptionButton

# Delivery state
var _delivery_list_shown: Array = []

# Config cache
var _spares_config: Dictionary = {}

# Unit purchase state
var available_units: Array[TacticalUnit] = []
var selected_unit_index: int = -1
var selected_unit_cost: int = 0

@onready var title_label: Label = %Title
@onready var balance_label: Label = %BalanceLabel
@onready var content: VBoxContainer = %Content
@onready var close_button: Button = %CloseButton

# TabContainer — built programmatically in _build_ui()
var tabs: TabContainer
var market_tabs: TabContainer

# Delivery tab
var delivery_list: ItemList
var delivery_detail_title: Label
var delivery_detail_info: Label

# Market — local tab
var local_list: ItemList
var local_search: LineEdit
var local_count_label: Label
var local_name: Label
var local_cost: Label
var local_tech: Label
var local_tonnage: Label
var local_qty: Label
var local_qty_spin: SpinBox
var buy_button: Button

# Market — remote tab
var remote_list: ItemList
var remote_search: LineEdit
var remote_status: Label
var order_qty_spin: SpinBox
var order_cost_label: Label
var order_travel_label: Label
var order_button: Button

# Market — units tab
var unit_search: LineEdit
var unit_type_filter: OptionButton
var unit_weight_filter: OptionButton
var unit_list: ItemList
var unit_detail_name: Label
var unit_detail_specs: RichTextLabel
var unit_price: Label
var unit_status: Label
var buy_unit_button: Button

# Inventory tab
var inv_list: ItemList
var inv_filter_only_unit: CheckButton
var inv_filter_below_min: CheckButton
var inv_detail_name: Label
var inv_detail_qty: Label
var inv_detail_cost: Label
var reorder_min_button: Button
var dispatch_unit_dropdown: OptionButton
var dispatch_qty_spin: SpinBox
var dispatch_button: Button
var dispatch_separator: HSeparator
var dispatch_unit_label: Label


func _ready() -> void:
	Helpers.debug_print("LogisticsPanel", "_ready start")
	_load_config()

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	add_theme_stylebox_override("panel", bg_style)

	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	balance_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

	_build_ui()
	close_button.pressed.connect(_on_close)


func _build_ui() -> void:
	tabs = TabContainer.new()
	tabs.name = "Tabs"
	tabs.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_child(tabs)

	_build_deliveries_tab()
	_build_market_tab()
	_build_inventory_tab()

	tabs.set_tab_title(0, "Deliveries")
	tabs.set_tab_title(1, "Market")
	tabs.set_tab_title(2, "Inventory")
	tabs.tab_changed.connect(_on_tab_changed)
	tabs.current_tab = 0
	Helpers.debug_print("LogisticsPanel", "_build_ui done")


func _build_deliveries_tab() -> void:
	var margin = MarginContainer.new()
	margin.name = "DeliveriesMargin"
	margin.size_flags_vertical = SIZE_EXPAND_FILL
	tabs.add_child(margin)

	var hsplit = HSplitContainer.new()
	hsplit.name = "HSplit"
	hsplit.size_flags_vertical = SIZE_EXPAND_FILL
	margin.add_child(hsplit)

	delivery_list = ItemList.new()
	delivery_list.name = "DeliveryList"
	delivery_list.size_flags_horizontal = SIZE_EXPAND_FILL * 2
	delivery_list.size_flags_vertical = SIZE_EXPAND_FILL
	delivery_list.add_theme_color_override("font_color", Color(1, 1, 1))
	delivery_list.add_theme_color_override("font_selected_color", Color(0, 0, 0))
	delivery_list.select_mode = ItemList.SELECT_SINGLE
	hsplit.add_child(delivery_list)

	var detail_panel = Panel.new()
	detail_panel.name = "DeliveryDetailPanel"
	detail_panel.size_flags_horizontal = SIZE_EXPAND_FILL * 3
	hsplit.add_child(detail_panel)

	var dm = MarginContainer.new()
	dm.name = "DeliveryDetailMargin"
	detail_panel.add_child(dm)

	var dv = VBoxContainer.new()
	dv.name = "DetailVBox"
	dv.size_flags_vertical = SIZE_EXPAND_FILL
	dm.add_child(dv)

	delivery_detail_title = Label.new()
	delivery_detail_title.name = "DeliveryDetailTitle"
	delivery_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(delivery_detail_title)

	delivery_detail_info = Label.new()
	delivery_detail_info.name = "DeliveryDetailInfo"
	delivery_detail_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delivery_detail_info.size_flags_vertical = SIZE_EXPAND_FILL
	dv.add_child(delivery_detail_info)

	delivery_list.item_selected.connect(_on_delivery_selected)
	EventBus.delivery_arrived.connect(_on_delivery_arrived)


func _build_market_tab() -> void:
	var vb = VBoxContainer.new()
	vb.name = "MarketVBox"
	vb.size_flags_vertical = SIZE_EXPAND_FILL
	tabs.add_child(vb)

	_planet_selector = OptionButton.new()
	_planet_selector.name = "PlanetSelector"
	_planet_selector.size_flags_vertical = SIZE_SHRINK_CENTER
	vb.add_child(_planet_selector)
	_planet_selector.item_selected.connect(_on_market_planet_selected)

	market_tabs = TabContainer.new()
	market_tabs.name = "MarketTabs"
	market_tabs.size_flags_vertical = SIZE_EXPAND_FILL
	vb.add_child(market_tabs)

	_build_local_tab()
	_build_units_tab()
	_build_remote_tab()

	market_tabs.set_tab_title(0, "Local")
	market_tabs.set_tab_title(1, "Units")
	market_tabs.set_tab_title(2, "Remote")
	market_tabs.tab_changed.connect(_on_market_tab_changed)
	market_tabs.current_tab = 0


func _make_hsplits(min_size: int = 3) -> HSplitContainer:
	var s = HSplitContainer.new()
	s.size_flags_vertical = SIZE_EXPAND_FILL
	return s


func _build_local_tab() -> void:
	var margin = MarginContainer.new()
	margin.name = "LocalMargin"
	margin.size_flags_vertical = SIZE_EXPAND_FILL
	market_tabs.add_child(margin)

	local_search = LineEdit.new()
	local_search.name = "LocalSearch"
	local_search.placeholder_text = tr("Search local market...")
	local_search.size_flags_vertical = SIZE_SHRINK_CENTER
	margin.add_child(local_search)

	local_count_label = Label.new()
	local_count_label.name = "LocalCount"
	local_count_label.text = ""
	margin.add_child(local_count_label)

	var hsplit = _make_hsplits()
	margin.add_child(hsplit)

	local_list = ItemList.new()
	local_list.name = "LocalList"
	local_list.size_flags_horizontal = SIZE_EXPAND_FILL * 2
	local_list.size_flags_vertical = SIZE_EXPAND_FILL
	local_list.custom_minimum_size = Vector2(100, 100)
	local_list.select_mode = ItemList.SELECT_SINGLE
	local_list.add_theme_color_override("font_color", Color(1, 1, 1))
	local_list.add_theme_color_override("font_selected_color", Color(0, 0, 0))
	var list_bg = StyleBoxFlat.new()
	list_bg.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	local_list.add_theme_stylebox_override("panel", list_bg)
	hsplit.add_child(local_list)

	var detail_panel = Panel.new()
	detail_panel.name = "LocalDetail"
	detail_panel.size_flags_horizontal = SIZE_EXPAND_FILL * 3
	hsplit.add_child(detail_panel)

	var dm = MarginContainer.new()
	dm.name = "LD Margin"
	detail_panel.add_child(dm)

	var dv = VBoxContainer.new()
	dv.name = "DetailVBox"
	dv.size_flags_vertical = SIZE_EXPAND_FILL
	dm.add_child(dv)

	local_name = Label.new()
	local_name.name = "LocalName"
	local_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(local_name)

	local_cost = Label.new()
	local_cost.name = "LocalCost"
	local_cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(local_cost)

	local_tech = Label.new()
	local_tech.name = "LocalTech"
	local_tech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(local_tech)

	local_tonnage = Label.new()
	local_tonnage.name = "LocalTonnage"
	local_tonnage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(local_tonnage)

	local_qty = Label.new()
	local_qty.name = "LocalQty"
	local_qty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(local_qty)

	var bh = HBoxContainer.new()
	bh.name = "BuyHBox"
	dv.add_child(bh)

	var ql = Label.new()
	ql.text = tr("Qty:")
	bh.add_child(ql)

	local_qty_spin = SpinBox.new()
	local_qty_spin.name = "LocalQtySpin"
	local_qty_spin.min_value = 1
	local_qty_spin.max_value = 999
	local_qty_spin.step = 1
	local_qty_spin.value = 1
	bh.add_child(local_qty_spin)

	buy_button = Button.new()
	buy_button.name = "BuyButton"
	buy_button.text = tr("Buy")
	buy_button.disabled = true
	bh.add_child(buy_button)

	local_search.text_changed.connect(_on_local_search)
	local_list.item_selected.connect(_on_local_item_selected)
	buy_button.pressed.connect(_on_buy)


func _build_units_tab() -> void:
	var margin = MarginContainer.new()
	margin.name = "UnitsMargin"
	margin.size_flags_vertical = SIZE_EXPAND_FILL
	market_tabs.add_child(margin)

	var vb = VBoxContainer.new()
	vb.name = "VBox"
	vb.size_flags_vertical = SIZE_EXPAND_FILL
	margin.add_child(vb)

	var fb = HBoxContainer.new()
	fb.name = "FilterBar"
	vb.add_child(fb)

	unit_search = LineEdit.new()
	unit_search.name = "UnitSearch"
	unit_search.placeholder_text = tr("Search units...")
	unit_search.size_flags_horizontal = SIZE_EXPAND_FILL * 3
	fb.add_child(unit_search)

	unit_type_filter = OptionButton.new()
	unit_type_filter.name = "UnitTypeFilter"
	unit_type_filter.size_flags_horizontal = SIZE_EXPAND_FILL
	unit_type_filter.text = tr("All Types")
	for t in ["All Types", "Mechs", "Vehicles"]:
		unit_type_filter.add_item(t)
	unit_type_filter.selected = 0
	fb.add_child(unit_type_filter)

	unit_weight_filter = OptionButton.new()
	unit_weight_filter.name = "UnitWeightFilter"
	unit_weight_filter.size_flags_horizontal = SIZE_EXPAND_FILL
	unit_weight_filter.text = tr("All Weights")
	for t in ["All Weights", "Light", "Medium", "Heavy", "Assault"]:
		unit_weight_filter.add_item(t)
	unit_weight_filter.selected = 0
	fb.add_child(unit_weight_filter)

	var hsplit = _make_hsplits()
	vb.add_child(hsplit)

	unit_list = ItemList.new()
	unit_list.name = "UnitList"
	unit_list.size_flags_horizontal = SIZE_EXPAND_FILL * 2
	unit_list.size_flags_vertical = SIZE_EXPAND_FILL
	unit_list.select_mode = ItemList.SELECT_SINGLE
	unit_list.add_theme_color_override("font_color", Color(1, 1, 1))
	unit_list.add_theme_color_override("font_selected_color", Color(0, 0, 0))
	hsplit.add_child(unit_list)

	var detail_panel = Panel.new()
	detail_panel.name = "UnitDetail"
	detail_panel.size_flags_horizontal = SIZE_EXPAND_FILL * 3
	hsplit.add_child(detail_panel)

	var dm = MarginContainer.new()
	dm.name = "UnitDetailMargin"
	detail_panel.add_child(dm)

	var dv = VBoxContainer.new()
	dv.name = "DetailVBox"
	dv.size_flags_vertical = SIZE_EXPAND_FILL
	dm.add_child(dv)

	unit_detail_name = Label.new()
	unit_detail_name.name = "UnitDetailName"
	unit_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(unit_detail_name)

	unit_detail_specs = RichTextLabel.new()
	unit_detail_specs.name = "UnitDetailSpecs"
	unit_detail_specs.bbcode_enabled = true
	unit_detail_specs.size_flags_vertical = SIZE_EXPAND_FILL
	dv.add_child(unit_detail_specs)

	unit_price = Label.new()
	unit_price.name = "UnitPrice"
	dv.add_child(unit_price)

	unit_status = Label.new()
	unit_status.name = "UnitStatus"
	dv.add_child(unit_status)

	var bh = HBoxContainer.new()
	bh.name = "BuyHBox"
	dv.add_child(bh)

	buy_unit_button = Button.new()
	buy_unit_button.name = "BuyUnitButton"
	buy_unit_button.text = tr("Buy")
	buy_unit_button.disabled = true
	bh.add_child(buy_unit_button)

	unit_search.text_changed.connect(_on_unit_search)
	unit_type_filter.item_selected.connect(_on_unit_filter_changed)
	unit_weight_filter.item_selected.connect(_on_unit_filter_changed)
	unit_list.item_selected.connect(_on_unit_selected)
	buy_unit_button.pressed.connect(_on_buy_unit)


func _build_remote_tab() -> void:
	var margin = MarginContainer.new()
	margin.name = "RemoteMargin"
	margin.size_flags_vertical = SIZE_EXPAND_FILL
	market_tabs.add_child(margin)

	var vb = VBoxContainer.new()
	vb.name = "VBox"
	vb.size_flags_vertical = SIZE_EXPAND_FILL
	margin.add_child(vb)

	remote_search = LineEdit.new()
	remote_search.name = "RemoteSearch"
	remote_search.placeholder_text = tr("Search surrounding systems...")
	vb.add_child(remote_search)

	remote_status = Label.new()
	remote_status.name = "RemoteStatus"
	remote_status.text = ""
	vb.add_child(remote_status)

	remote_list = ItemList.new()
	remote_list.name = "RemoteList"
	remote_list.size_flags_vertical = SIZE_EXPAND_FILL
	remote_list.select_mode = ItemList.SELECT_SINGLE
	remote_list.add_theme_color_override("font_color", Color(1, 1, 1))
	remote_list.add_theme_color_override("font_selected_color", Color(0, 0, 0))
	vb.add_child(remote_list)

	var order_panel = Panel.new()
	order_panel.name = "RemoteOrderPanel"
	order_panel.size_flags_vertical = SIZE_SHRINK_CENTER
	vb.add_child(order_panel)

	var om = MarginContainer.new()
	om.name = "RemoteOrderMargin"
	order_panel.add_child(om)

	var ov = VBoxContainer.new()
	ov.name = "OrderVBox"
	om.add_child(ov)

	order_cost_label = Label.new()
	order_cost_label.name = "OrderCostLabel"
	ov.add_child(order_cost_label)

	order_travel_label = Label.new()
	order_travel_label.name = "OrderTravelLabel"
	ov.add_child(order_travel_label)

	var oh = HBoxContainer.new()
	oh.name = "OrderHBox"
	ov.add_child(oh)

	var oql = Label.new()
	oql.text = tr("Qty:")
	oh.add_child(oql)

	order_qty_spin = SpinBox.new()
	order_qty_spin.name = "OrderQtySpin"
	order_qty_spin.min_value = 1
	order_qty_spin.max_value = 999
	order_qty_spin.step = 1
	order_qty_spin.value = 1
	oh.add_child(order_qty_spin)

	order_button = Button.new()
	order_button.name = "OrderButton"
	order_button.text = tr("Order")
	order_button.disabled = true
	oh.add_child(order_button)

	remote_search.text_changed.connect(_on_remote_search)
	remote_list.item_selected.connect(_on_remote_item_selected)
	order_button.pressed.connect(_on_order)


func _build_inventory_tab() -> void:
	var margin = MarginContainer.new()
	margin.name = "InvMargin"
	margin.size_flags_vertical = SIZE_EXPAND_FILL
	tabs.add_child(margin)

	var vb = VBoxContainer.new()
	vb.name = "VBox"
	vb.size_flags_vertical = SIZE_EXPAND_FILL
	margin.add_child(vb)

	var fb = HBoxContainer.new()
	fb.name = "FilterBar"
	vb.add_child(fb)

	inv_filter_only_unit = CheckButton.new()
	inv_filter_only_unit.name = "InvFilterOnlyUnit"
	inv_filter_only_unit.text = tr("Only unit components")
	inv_filter_only_unit.size_flags_horizontal = SIZE_EXPAND_FILL * 3
	fb.add_child(inv_filter_only_unit)

	inv_filter_below_min = CheckButton.new()
	inv_filter_below_min.name = "InvFilterBelowMin"
	inv_filter_below_min.text = tr("Below minimum only")
	inv_filter_below_min.size_flags_horizontal = SIZE_EXPAND_FILL * 3
	fb.add_child(inv_filter_below_min)

	reorder_min_button = Button.new()
	reorder_min_button.name = "ReorderMinButton"
	reorder_min_button.text = tr("Reorder to Minimum")
	reorder_min_button.size_flags_horizontal = SIZE_EXPAND_FILL * 2
	fb.add_child(reorder_min_button)

	var hsplit = _make_hsplits()
	vb.add_child(hsplit)

	inv_list = ItemList.new()
	inv_list.name = "InvList"
	inv_list.size_flags_horizontal = SIZE_EXPAND_FILL * 2
	inv_list.size_flags_vertical = SIZE_EXPAND_FILL
	inv_list.select_mode = ItemList.SELECT_SINGLE
	inv_list.add_theme_color_override("font_color", Color(1, 1, 1))
	inv_list.add_theme_color_override("font_selected_color", Color(0, 0, 0))
	hsplit.add_child(inv_list)

	var detail_panel = Panel.new()
	detail_panel.name = "InvDetail"
	detail_panel.size_flags_horizontal = SIZE_EXPAND_FILL * 3
	hsplit.add_child(detail_panel)

	var dm = MarginContainer.new()
	dm.name = "InvDetailMargin"
	detail_panel.add_child(dm)

	var dv = VBoxContainer.new()
	dv.name = "DetailVBox"
	dv.size_flags_vertical = SIZE_EXPAND_FILL
	dm.add_child(dv)

	inv_detail_name = Label.new()
	inv_detail_name.name = "InvDetailName"
	inv_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(inv_detail_name)

	inv_detail_qty = Label.new()
	inv_detail_qty.name = "InvDetailQty"
	dv.add_child(inv_detail_qty)

	inv_detail_cost = Label.new()
	inv_detail_cost.name = "InvDetailCost"
	dv.add_child(inv_detail_cost)

	dispatch_separator = HSeparator.new()
	dispatch_separator.name = "DispatchSeparator"
	dv.add_child(dispatch_separator)

	dispatch_unit_label = Label.new()
	dispatch_unit_label.name = "DispatchUnitLabel"
	dispatch_unit_label.text = tr("Dispatch to unit:")
	dv.add_child(dispatch_unit_label)

	dispatch_unit_dropdown = OptionButton.new()
	dispatch_unit_dropdown.name = "DispatchUnitDropdown"
	dispatch_unit_dropdown.text = tr("Select unit...")
	dv.add_child(dispatch_unit_dropdown)

	var dh = HBoxContainer.new()
	dh.name = "DispatchHBox"
	dv.add_child(dh)

	dispatch_qty_spin = SpinBox.new()
	dispatch_qty_spin.name = "DispatchQtySpin"
	dispatch_qty_spin.min_value = 1
	dispatch_qty_spin.max_value = 9999
	dispatch_qty_spin.step = 1
	dispatch_qty_spin.value = 1
	dh.add_child(dispatch_qty_spin)

	dispatch_button = Button.new()
	dispatch_button.name = "DispatchButton"
	dispatch_button.text = tr("Dispatch")
	dh.add_child(dispatch_button)

	inv_filter_only_unit.toggled.connect(_refresh_inventory)
	inv_filter_below_min.toggled.connect(_refresh_inventory)
	inv_list.item_selected.connect(_on_inv_item_selected)
	reorder_min_button.pressed.connect(_on_reorder_to_min)
	dispatch_button.pressed.connect(_on_dispatch)


func _load_config() -> void:
	var f = FileAccess.open("res://data/config/spares_config.json", FileAccess.READ)
	if f:
		var j = JSON.new()
		if j.parse(f.get_as_text()) == OK:
			_spares_config = j.data


func populate() -> void:
	Helpers.debug_print("LogisticsPanel", "populate — current_tab=%d" % tabs.current_tab if tabs else -1)
	print("populate: tabs.current_tab=", tabs.current_tab if tabs else -1)
	balance_label.text = tr("Balance: ") + Helpers.fmt_money(EconomySystem.get_balance())
	refresh_current_tab()


func refresh_current_tab() -> void:
	match tabs.current_tab:
		0: _refresh_deliveries()
		1: _refresh_market_tab()
		2: _refresh_inventory()


# ---- Tab switching ----

func _on_tab_changed(_tab: int) -> void:
	match tabs.current_tab:
		0:
			_refresh_deliveries()
		1:
			balance_label.text = tr("Balance: ") + Helpers.fmt_money(EconomySystem.get_balance())
			_refresh_market_tab()
		2:
			_refresh_inventory()


func _on_market_tab_changed(_idx: int) -> void:
	if tabs.current_tab == 1:
		_refresh_market_tab()


func _populate_planet_selector() -> void:
	var saved = _planet_selector.selected
	_planet_selector.clear()
	_planet_selector.add_item("Galatea (Home Base)", 0)
	_planet_selector.set_item_metadata(0, "Galatea")
	var idx := 1
	var seen: Dictionary = {"Galatea": true}
	for ou in GameState.player.organizational_units:
		for opu in ou.sub_units:
			if opu.is_deployed and opu.current_planet and not seen.has(opu.current_planet):
				seen[opu.current_planet] = true
				_planet_selector.add_item(opu.current_planet + " (Deployed)", idx)
				_planet_selector.set_item_metadata(idx, opu.current_planet)
				idx += 1
	if saved >= 0 and saved < _planet_selector.item_count:
		_planet_selector.select(saved)
	elif _selected_market_planet.is_empty():
		_planet_selector.select(0)
		_selected_market_planet = "Galatea"
	_planet_selector.selected = _planet_selector.selected if _planet_selector.selected >= 0 else 0


func _on_market_planet_selected(idx: int) -> void:
	if idx < 0 or idx >= _planet_selector.item_count:
		return
	_selected_market_planet = _planet_selector.get_item_metadata(idx)
	Helpers.debug_print("LogisticsPanel", "market planet changed to: " + _selected_market_planet)
	EconomySystem.initialize_market(_selected_market_planet)
	match market_tabs.current_tab:
		0: _refresh_local()
		2: _refresh_units()


func _refresh_market_tab() -> void:
	if not GameState.player.current_planet:
		return
	if _selected_market_planet.is_empty():
		_selected_market_planet = "Galatea"
	_populate_planet_selector()
	EconomySystem.initialize_market(_selected_market_planet)
	match market_tabs.current_tab:
		0:
			_refresh_local()
		1:
			pass
		2:
			_refresh_units()


# =====================
# TAB 0: DELIVERIES
# =====================

func _refresh_deliveries() -> void:
	delivery_list.clear()
	delivery_detail_title.text = ""
	delivery_detail_info.text = ""
	_delivery_list_shown.clear()

	var deliveries: Array = GameState.pending_deliveries
	if deliveries.is_empty():
		delivery_list.add_item("No pending deliveries")
		return

	for d in deliveries:
		var item = d.get("item", "Unknown")
		var qty = d.get("quantity", 1)
		var eta = d.get("eta_tick", 0)
		var is_auto = d.get("auto_order", false)
		var days_left = max(0, eta - TimeManager.total_days)

		var label = "%s x%d — %d day(s)" % [item, qty, days_left]
		if is_auto:
			label = "[AUTO] " + label

		delivery_list.add_item(label)
		_delivery_list_shown.append({
			"item": item,
			"quantity": qty,
			"eta_tick": eta,
			"days_left": days_left,
			"auto_order": is_auto,
		})


func _on_delivery_selected(index: int) -> void:
	if index < 0 or index >= _delivery_list_shown.size():
		return
	var entry = _delivery_list_shown[index]

	delivery_detail_title.text = entry.item
	var lines: Array[String] = []
	lines.append("Quantity: " + str(entry.quantity))
	lines.append("ETA: " + str(entry.days_left) + " day(s)")
	lines.append("Type: " + ("Auto-order" if entry.auto_order else "Manual"))
	var def = DataManager.component_defs.get(entry.item)
	if def:
		lines.append("Tonnage: " + str(def.get("tonnage", 0)) + "t")
		lines.append("Cost: " + Helpers.fmt_money(def.get("cost", 0)) + " per unit")
	delivery_detail_info.text = tr("\n")


func _on_delivery_arrived(_item_name: String, _quantity: int) -> void:
	if visible and tabs.current_tab == 0:
		_refresh_deliveries()


# =====================
# TAB 1: MARKET
# =====================

func _refresh_local() -> void:
	local_list.clear()
	current_items = EconomySystem.current_market.get_available_items()
	var query = local_search.text.strip_edges().to_lower()
	var added := 0
	for item in current_items:
		if query and not item.name.to_lower().contains(query):
			continue
		local_list.add_item(str(added) + ": " + item.name + "  x" + str(item.quantity) + "  " + Helpers.fmt_money(item.cost))
		added += 1
	local_count_label.text = tr("Items: %d (%d shown)") % [current_items.size(), added]
	if added == 0:
		local_list.add_item("[No items match filter]")


func _on_local_search(_new_text: String) -> void:
	_refresh_local()


func _get_filtered_local_items() -> Array[Dictionary]:
	var query = local_search.text.strip_edges().to_lower()
	if query.is_empty():
		return current_items
	var result: Array[Dictionary] = []
	for item in current_items:
		if item.name.to_lower().contains(query):
			result.append(item)
	return result


func _on_local_item_selected(index: int) -> void:
	selected_remote_idx = -1
	remote_list.deselect_all()
	var visible = _get_filtered_local_items()
	if index < 0 or index >= visible.size():
		return
	var item = visible[index]
	selected_item_name = item.name
	local_name.text = item.name
	local_cost.text = tr("Cost: ") + Helpers.fmt_money(item.cost)
	local_tech.text = tr("Tech Level: ") + str(item.tech_level)
	local_tonnage.text = tr("Tonnage: ") + str(item.tonnage) + "t"
	local_qty.text = tr("In stock: ") + str(item.quantity)
	local_qty_spin.max_value = max(item.quantity, 1)
	local_qty_spin.value = 1
	buy_button.disabled = false


func _on_buy() -> void:
	if not selected_item_name:
		return
	var qty = int(local_qty_spin.value)
	if qty <= 0:
		return
	if EconomySystem.buy_item(selected_item_name, qty):
		GameState.log_event("market_purchase", {
			"item": selected_item_name,
			"quantity": qty,
			"cost": EconomySystem.current_market.get_price(selected_item_name) * qty,
			"location": GameState.player.current_planet
		})
		_refresh_local()
		balance_label.text = tr("Balance: ") + Helpers.fmt_money(EconomySystem.get_balance())
		local_name.text = tr("Purchased ") + str(qty) + "x " + selected_item_name
		local_qty.text = ""
		buy_button.disabled = true
	else:
		local_name.text = tr("Purchase failed — insufficient funds")


func _on_remote_search(new_text: String) -> void:
	remote_list.clear()
	_clear_remote_detail()
	remote_item_name = new_text.strip_edges()
	if remote_item_name.length() < 2:
		remote_status.text = tr("Type at least 2 characters")
		return
	if not GameState.player.current_planet:
		remote_status.text = tr("No planet selected")
		return

	remote_results = EconomySystem.search_remote_sources(remote_item_name)
	if remote_results.is_empty():
		remote_status.text = tr("No sources found within 2 jumps")
		return

	for r in remote_results:
		remote_list.add_item("%s — %s  x%d  %s  (%d jumps, %d days)" % [
			r.source_system, remote_item_name, r.quantity,
			Helpers.fmt_money(r.cost_per_unit), r.jumps, r.travel_days])
	remote_status.text = str(remote_results.size()) + " source(s) found"


func _clear_remote_detail() -> void:
	selected_remote_idx = -1
	order_cost_label.text = ""
	order_travel_label.text = ""
	order_button.disabled = true


func _on_remote_item_selected(index: int) -> void:
	selected_item_name = ""
	local_list.deselect_all()
	buy_button.disabled = true

	if index < 0 or index >= remote_results.size():
		return
	selected_remote_idx = index
	var r = remote_results[index]
	order_cost_label.text = tr("Cost: ") + Helpers.fmt_money(r.cost_per_unit) + " per unit"
	order_travel_label.text = tr("Travel: ") + str(r.travel_days) + " days (" + str(r.jumps) + " jump(s))"
	order_qty_spin.max_value = max(r.quantity, 1)
	order_qty_spin.value = 1
	order_button.disabled = false


func _on_order() -> void:
	if selected_remote_idx < 0 or selected_remote_idx >= remote_results.size():
		return
	var r = remote_results[selected_remote_idx]
	var qty = int(order_qty_spin.value)
	if qty <= 0:
		return
	if EconomySystem.order_item(remote_item_name, qty, r.cost_per_unit, r.source_system, r.travel_days):
		GameState.log_event("remote_order", {
			"item": remote_item_name,
			"quantity": qty,
			"cost": r.cost_per_unit * qty,
			"source": r.source_system,
			"eta_days": r.travel_days
		})
		balance_label.text = tr("Balance: ") + Helpers.fmt_money(EconomySystem.get_balance())
		order_button.disabled = true
		order_cost_label.text = tr("Order placed — arrives in ") + str(r.travel_days) + " days"
	else:
		order_cost_label.text = tr("Order failed — insufficient funds")


# =====================
# TAB 2: INVENTORY
# =====================

func _refresh_inventory() -> void:
	inv_list.clear()
	inv_detail_name.text = ""
	inv_detail_qty.text = ""
	inv_detail_cost.text = ""

	var inv: Dictionary = GameState.player_inventory
	var only_unit = inv_filter_only_unit.button_pressed
	var below_min = inv_filter_below_min.button_pressed

	# Collect component names used by player's deployed units
	var unit_components: Dictionary = {}
	for ou in GameState.player.organizational_units:
		for tu in ou.get_all_tactical_units():
			for c in tu.components:
				unit_components[c.component_name] = true

	var min_stock = _spares_config.get("auto_reorder_min_stock", 0)

	var items_shown := 0
	for comp_name in inv:
		var qty = inv[comp_name]
		if qty <= 0:
			continue
		if only_unit and comp_name not in unit_components and \
				not ("Ammo" in comp_name or "ammo" in comp_name):
			continue
		if below_min and qty >= min_stock:
			continue

		var ammo_used = comp_name in unit_components or "Ammo" in comp_name or "ammo" in comp_name
		var label = "%s x%d" % [comp_name, qty]
		if ammo_used and not only_unit:
			label += " [in use]"
		inv_list.add_item(label)
		var idx = inv_list.get_item_count() - 1
		inv_list.set_item_metadata(idx, comp_name)
		items_shown += 1


func _on_inv_item_selected(index: int) -> void:
	if index < 0 or index >= inv_list.get_item_count():
		return
	var meta = inv_list.get_item_metadata(index)
	if meta == null:
		return
	var comp_name = str(meta)
	var inv: Dictionary = GameState.player_inventory

	inv_detail_name.text = comp_name
	inv_detail_qty.text = tr("Quantity: ") + str(inv.get(comp_name, 0))

	var min_s = _spares_config.get("auto_reorder_min_stock", 0)
	var tgt = _spares_config.get("auto_reorder_target_stock", 0)
	if min_s > 0 or tgt > 0:
		inv_detail_qty.text += "  (min: %d, target: %d)" % [min_s, tgt]

	var def = DataManager.component_defs.get(comp_name)
	if def:
		inv_detail_cost.text = tr("Unit cost: ") + Helpers.fmt_money(def.get("cost", 0))
	else:
		inv_detail_cost.text = ""

	_update_dispatch_ui(comp_name)


func _update_dispatch_ui(comp_name: String) -> void:
	var per_unit = _spares_config.get("per_unit_inventory_enabled", false)
	dispatch_separator.visible = per_unit
	dispatch_unit_label.visible = per_unit
	dispatch_unit_dropdown.visible = per_unit
	dispatch_qty_spin.visible = per_unit
	dispatch_button.visible = per_unit

	if not per_unit:
		return

	dispatch_unit_dropdown.clear()
	var idx := 0
	for ou in GameState.player.organizational_units:
		for opu in ou.sub_units:
			if opu.is_deployed or not opu.contract_id.is_empty():
				dispatch_unit_dropdown.add_item("%s — %s" % [ou.unit_name, opu.unit_name])
				dispatch_unit_dropdown.set_item_metadata(idx, {
					"org": ou.unit_name,
					"opu": opu.unit_name,
				})
				idx += 1

	if idx == 0:
		dispatch_unit_dropdown.add_item("No deployed units")
		dispatch_button.disabled = true
	else:
		dispatch_button.disabled = false
		dispatch_qty_spin.max_value = GameState.player_inventory.get(comp_name, 0)


func _on_dispatch() -> void:
	var per_unit = _spares_config.get("per_unit_inventory_enabled", false)
	if not per_unit:
		return

	var meta = dispatch_unit_dropdown.get_selected_metadata()
	if meta == null:
		return

	var comp_name = inv_detail_name.text
	var qty = int(dispatch_qty_spin.value)
	if qty <= 0 or comp_name.is_empty():
		return

	var target = _get_selected_opu()
	if target == null:
		return

	if InventoryManager.dispatch_to_unit(comp_name, qty, target):
		GameState.log_event("dispatch", {
			"item": comp_name,
			"quantity": qty,
			"to_unit": target.unit_name,
		})
		_refresh_inventory()


func _get_selected_opu():
	if _spares_config.get("per_unit_inventory_enabled", false):
		var sel = dispatch_unit_dropdown.selected
		if sel >= 0:
			var meta = dispatch_unit_dropdown.get_item_metadata(sel)
			if meta:
				for ou in GameState.player.organizational_units:
					for opu in ou.sub_units:
						var key = "%s — %s" % [ou.unit_name, opu.unit_name]
						if key == dispatch_unit_dropdown.get_item_text(sel):
							return opu
	return null


func _on_reorder_to_min() -> void:
	if not GameState.player.current_planet:
		inv_detail_name.text = tr("Select a planet first")
		return

	var min_stock = _spares_config.get("auto_reorder_min_stock", 0)
	var target_stock = _spares_config.get("auto_reorder_target_stock", 0)
	if min_stock <= 0 or target_stock <= 0:
		inv_detail_name.text = tr("Set min/target stock in spares_config.json first")
		return

	var target_opu = _get_selected_opu()
	var per_unit = target_opu != null

	EconomySystem.initialize_market(GameState.player.current_planet)
	var market = EconomySystem.current_market

	var inv: Dictionary = GameState.player_inventory
	var orders_placed := 0
	var local_bought := 0
	var dispatched := 0
	var total_cost := 0
	var max_cost = _spares_config.get("auto_reorder_max_cost_per_order", 500000)

	# Collect all component names that need checking — unit cache items + global inventory items
	var all_component_names: Dictionary = {}
	if per_unit:
		for cname in target_opu.deployment_cache:
			all_component_names[cname] = true
	for cname in inv:
		all_component_names[cname] = true

	for comp_name in all_component_names:
		if total_cost >= max_cost:
			break

		# Determine current stock level (unit cache for per-unit, global otherwise)
		var current_qty := 0
		if per_unit:
			current_qty = target_opu.deployment_cache.get(comp_name, 0)
		else:
			current_qty = inv.get(comp_name, 0)

		if current_qty >= min_stock:
			continue

		var shortfall = target_stock - current_qty
		if shortfall <= 0:
			continue

		var remaining = shortfall

		# Step 1: if per-unit, dispatch from global before ordering
		if per_unit:
			var global_qty = inv.get(comp_name, 0)
			var dispatch_qty = min(remaining, global_qty)
			if dispatch_qty > 0 and InventoryManager.dispatch_to_unit(comp_name, dispatch_qty, target_opu):
				remaining -= dispatch_qty
				dispatched += dispatch_qty
				if remaining <= 0:
					continue

		# Step 2: buy locally
		var item = market.get_item(comp_name)
		if item and item.quantity > 0:
			var local_qty = min(remaining, item.quantity)
			var local_cost = local_qty * item.cost
			if total_cost + local_cost <= max_cost and EconomySystem.buy_item(comp_name, local_qty):
				remaining -= local_qty
				total_cost += local_cost
				local_bought += local_qty
				# Put into unit cache or global
				if per_unit:
					target_opu.deployment_cache[comp_name] = target_opu.deployment_cache.get(comp_name, 0) + local_qty
				else:
					inv[comp_name] = inv.get(comp_name, 0) + local_qty

		# Step 3: order remotely
		if remaining > 0:
			var sources = EconomySystem.search_remote_sources(comp_name)
			if sources.is_empty():
				continue
			var source = sources[0]
			var order_qty = min(remaining, source.quantity)
			var order_cost = order_qty * source.cost_per_unit
			if total_cost + order_cost > max_cost:
				order_qty = max(1, (max_cost - total_cost) / source.cost_per_unit)
				order_cost = order_qty * source.cost_per_unit
			if order_qty > 0 and EconomySystem.order_item(comp_name, order_qty, source.cost_per_unit, source.source_system, source.travel_days):
				orders_placed += 1
				total_cost += order_cost
				GameState.log_event("auto_reorder", {
					"item": comp_name,
					"quantity": order_qty,
					"cost": order_cost,
					"source": source.source_system,
				})
				if per_unit:
					target_opu.deployment_cache[comp_name] = target_opu.deployment_cache.get(comp_name, 0) + order_qty
				else:
					inv[comp_name] = inv.get(comp_name, 0) + order_qty

	balance_label.text = tr("Balance: ") + Helpers.fmt_money(EconomySystem.get_balance())
	var parts: Array[String] = []
	if dispatched > 0:
		parts.append("dispatched %d from stores" % dispatched)
	if local_bought > 0:
		parts.append("bought %d locally" % local_bought)
	if orders_placed > 0:
		parts.append("%d remote orders" % orders_placed)
	if parts.is_empty():
		parts.append("nothing needed")
	inv_detail_name.text = ", ".join(parts) + tr(" for %s") % Helpers.fmt_money(total_cost)
	_refresh_inventory()


# =====================
# TAB 1c: UNITS (sub-tab of Market)
# =====================

func _refresh_units() -> void:
	unit_list.clear()
	selected_unit_index = -1
	buy_unit_button.disabled = true
	unit_detail_name.text = ""
	unit_detail_specs.text = ""
	unit_price.text = ""
	unit_status.text = ""

	available_units.clear()
	var factions = EconomySystem.current_planet_factions
	if factions.is_empty():
		factions = ["PIR"]
	var seen: Dictionary = {}
	for code in factions:
		var units = DataManager.get_faction_market_units(code)
		for tu in units:
			var key = tu.chassis_name + "|" + tu.model_name
			if seen.has(key):
				continue
			seen[key] = true
			available_units.append(tu)

	var type_filter := unit_type_filter.selected
	var weight_filter := unit_weight_filter.selected
	var query = unit_search.text.strip_edges().to_lower()

	for tu in available_units:
		if type_filter > 0:
			if type_filter == 1 and tu.unit_type != Enums.UnitType.MECH:
				continue
			if type_filter == 2 and tu.unit_type != Enums.UnitType.VEHICLE:
				continue
		if weight_filter > 0:
			var wc = _get_weight_class(tu.tonnage)
			if weight_filter == 1 and wc != "Light":
				continue
			if weight_filter == 2 and wc != "Medium":
				continue
			if weight_filter == 3 and wc != "Heavy":
				continue
			if weight_filter == 4 and wc != "Assault":
				continue
		if query and not tu.unit_name.to_lower().contains(query):
			continue
		var cost = tu.calculate_tm_cost()
		unit_list.add_item("%s  %s" % [tu.unit_name, Helpers.fmt_money(cost)])


static func _get_weight_class(tonnage: float) -> String:
	if tonnage <= 35:
		return "Light"
	elif tonnage <= 55:
		return "Medium"
	elif tonnage <= 75:
		return "Heavy"
	else:
		return "Assault"


func _on_unit_search(_new_text: String) -> void:
	_refresh_units()


func _on_unit_filter_changed(_idx: int) -> void:
	_refresh_units()


func _on_unit_selected(index: int) -> void:
	if index < 0 or index >= unit_list.get_item_count():
		return

	var query = unit_search.text.strip_edges().to_lower()
	var visible: Array[TacticalUnit] = []
	for tu in available_units:
		if not _unit_passes_filters(tu, query):
			continue
		visible.append(tu)
	if index >= visible.size():
		return

	var tu = visible[index]
	selected_unit_index = index
	selected_unit_cost = tu.calculate_tm_cost()
	unit_detail_name.text = tu.unit_name

	var validation = tu.validate_tm()
	var lines: Array[String] = []
	lines.append("Chassis: " + tu.chassis_name)
	lines.append("Model: " + tu.model_name)
	lines.append("Engine: " + str(tu.engine_rating) + " " + tu.engine_type)
	lines.append("Structure: " + tu.internal_structure_type + " | Gyro: " + tu.gyro_type)
	lines.append("Armor: " + tu.armor_type + " (" + str(tu.total_armor_points) + " pts)")
	lines.append("Tonnage: " + str(tu.tonnage) + "t (" + str(validation.used_tonnage) + "t used, " + str(validation.free_tonnage) + "t free)")
	lines.append("Movement: " + str(tu.movement_mp) + "/" + str(tu.run_mp) + "/" + str(tu.jump_mp))
	if not validation.valid:
		lines.append("[color=#ff4444]Design issue: " + ", ".join(validation.errors) + "[/color]")
	lines.append("")
	lines.append("[b]Components (" + str(tu.components.size()) + "):[/b]")
	for c in tu.components:
		lines.append("  " + c.component_name)
	unit_detail_specs.text = tr("\n")

	unit_price.text = tr("Price: ") + Helpers.fmt_money(selected_unit_cost)
	unit_status.text = ""
	var transport_cost = UnitTransportManager.get_daily_transport_cost()
	unit_status.text = tr("Transport: 0 CSB (local purchase — on planet)")
	buy_unit_button.disabled = false


func _unit_passes_filters(tu: TacticalUnit, query: String) -> bool:
	var type_filter := unit_type_filter.selected
	var weight_filter := unit_weight_filter.selected

	if type_filter > 0:
		if type_filter == 1 and tu.unit_type != Enums.UnitType.MECH:
			return false
		if type_filter == 2 and tu.unit_type != Enums.UnitType.VEHICLE:
			return false
	if weight_filter > 0:
		var wc = _get_weight_class(tu.tonnage)
		if weight_filter == 1 and wc != "Light":
			return false
		if weight_filter == 2 and wc != "Medium":
			return false
		if weight_filter == 3 and wc != "Heavy":
			return false
		if weight_filter == 4 and wc != "Assault":
			return false
	if query and not tu.unit_name.to_lower().contains(query):
		return false
	return true


func _on_buy_unit() -> void:
	if selected_unit_index < 0:
		return

	var query = unit_search.text.strip_edges().to_lower()
	var visible: Array[TacticalUnit] = []
	for tu in available_units:
		if not _unit_passes_filters(tu, query):
			continue
		visible.append(tu)
	if selected_unit_index >= visible.size():
		return

	var template = visible[selected_unit_index]

	if EconomySystem.get_balance() < selected_unit_cost:
		unit_status.text = tr("Insufficient funds — need ") + Helpers.fmt_money(selected_unit_cost)
		return

	if not EconomySystem.deduct_funds(selected_unit_cost, "Purchase unit: " + template.unit_name):
		unit_status.text = tr("Purchase failed")
		return

	var new_unit = TacticalUnit.new()
	new_unit.unit_name = template.unit_name
	new_unit.chassis_name = template.chassis_name
	new_unit.model_name = template.model_name
	new_unit.unit_type = template.unit_type
	new_unit.tonnage = template.tonnage
	new_unit.movement_mp = template.movement_mp
	new_unit.run_mp = template.run_mp
	new_unit.jump_mp = template.jump_mp
	new_unit.quality = Enums.Quality.D
	for c in template.components:
		var nc = Component.new()
		nc.component_name = c.component_name
		nc.component_type = c.component_type
		nc.tonnage = c.tonnage
		nc.critical_slots = c.critical_slots
		nc.cost = c.cost
		nc.tech_base = c.tech_base
		nc.tech_level = c.tech_level
		nc.quality_range = c.quality_range
		nc.repair_difficulty = c.repair_difficulty
		nc.status = Enums.ComponentStatus.UNDAMAGED
		if c.location:
			nc.location = c.location
		new_unit.components.append(nc)

	if GameState.player.organizational_units.is_empty():
		var ou = OrganizationalUnit.new()
		ou.unit_name = "Purchased Units"
		GameState.player.organizational_units.append(ou)
	var target_ou = GameState.player.organizational_units[0]
	if target_ou.sub_units.is_empty():
		var opu = OperationalUnit.new()
		opu.unit_name = "Reserve"
		opu.role = "Reserve"
		target_ou.sub_units.append(opu)
	target_ou.sub_units[0].tactical_units.append(new_unit)

	balance_label.text = tr("Balance: ") + Helpers.fmt_money(EconomySystem.get_balance())
	GameState.log_event("unit_purchased", {
		"unit": template.unit_name,
		"cost": selected_unit_cost,
		"location": GameState.player.current_planet
	})
	unit_status.text = tr("Purchased! Added to ") + target_ou.unit_name
	buy_unit_button.disabled = true
	_refresh_units()


func _on_close() -> void:
	hide()
	closed.emit()
