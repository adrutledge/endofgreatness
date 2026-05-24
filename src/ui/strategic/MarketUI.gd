class_name MarketUI
extends Panel

signal closed()

var current_items: Array[Dictionary] = []
var remote_results: Array[Dictionary] = []

@onready var tabs: TabContainer = %Tabs
@onready var local_list: ItemList = %LocalList
@onready var local_search: LineEdit = %LocalSearch
@onready var detail_name: Label = %DetailName
@onready var detail_cost: Label = %DetailCost
@onready var detail_tech: Label = %DetailTech
@onready var detail_tonnage: Label = %DetailTonnage
@onready var detail_qty: Label = %DetailQty
@onready var quantity_spin: SpinBox = %QuantitySpin
@onready var order_qty_spin: SpinBox = %OrderQtySpin
@onready var buy_button: Button = %BuyButton
@onready var remote_list: ItemList = %RemoteList
@onready var remote_search: LineEdit = %RemoteSearch
@onready var remote_status: Label = %RemoteStatus
@onready var order_button: Button = %OrderButton
@onready var order_cost_label: Label = %OrderCostLabel
@onready var order_travel_label: Label = %OrderTravelLabel
@onready var balance_label: Label = %BalanceLabel
@onready var close_button: Button = %CloseButton

var selected_item_name: String = ""
var selected_remote_idx: int = -1
var remote_item_name: String = ""

func _ready() -> void:
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	add_theme_stylebox_override("panel", bg_style)

	var detail_style = StyleBoxFlat.new()
	detail_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	%DetailPanel.add_theme_stylebox_override("panel", detail_style)

	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	detail_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	balance_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

	close_button.pressed.connect(_on_close)
	buy_button.pressed.connect(_on_buy)
	order_button.pressed.connect(_on_order)
	local_search.text_changed.connect(_on_local_search)
	remote_search.text_changed.connect(_on_remote_search)
	local_list.item_selected.connect(_on_local_item_selected)
	remote_list.item_selected.connect(_on_remote_item_selected)
	tabs.tab_changed.connect(_on_tab_changed)

func populate() -> void:
	if not GameState.player.current_planet:
		balance_label.text = "Balance: " + _fmt_money(EconomySystem.get_balance()) + "  |  No planet selected"
		local_list.clear()
		detail_name.text = "Select a planet on the star map first"
		return

	EconomySystem.initialize_market(GameState.player.current_planet)
	_refresh_local()
	balance_label.text = "Balance: " + _fmt_money(EconomySystem.get_balance())

func _refresh_local() -> void:
	local_list.clear()
	current_items = EconomySystem.current_market.get_available_items()

	var query = local_search.text.strip_edges().to_lower()
	for item in current_items:
		if query and not item.name.to_lower().contains(query):
			continue
		local_list.add_item("%s  x%d  %s" % [item.name, item.quantity, _fmt_money(item.cost)])

func _on_local_search(_new_text: String) -> void:
	_refresh_local()

func _on_local_item_selected(index: int) -> void:
	selected_remote_idx = -1
	remote_list.deselect_all()

	var visible = _get_filtered_local_items()
	if index < 0 or index >= visible.size():
		return
	var item = visible[index]
	selected_item_name = item.name
	detail_name.text = item.name
	detail_cost.text = "Cost: " + _fmt_money(item.cost) + " per unit"
	detail_tech.text = "Tech Level: " + str(item.tech_level)
	detail_tonnage.text = "Tonnage: " + str(item.tonnage) + "t"
	detail_qty.text = "Available: " + str(item.quantity)
	quantity_spin.max_value = max(item.quantity, 1)
	quantity_spin.value = 1
	buy_button.disabled = false

func _get_filtered_local_items() -> Array[Dictionary]:
	var query = local_search.text.strip_edges().to_lower()
	if query.is_empty():
		return current_items
	var result: Array[Dictionary] = []
	for item in current_items:
		if item.name.to_lower().contains(query):
			result.append(item)
	return result

func _on_buy() -> void:
	if not selected_item_name:
		return
	var qty = int(quantity_spin.value)
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
		balance_label.text = "Balance: " + _fmt_money(EconomySystem.get_balance())
		detail_name.text = "Purchased " + str(qty) + "x " + selected_item_name
		detail_qty.text = ""
		buy_button.disabled = true
	else:
		detail_name.text = "Purchase failed — insufficient funds"

func _on_tab_changed(_tab: int) -> void:
	if tabs.current_tab == 0:
		_refresh_local()
	else:
		_clear_remote_detail()
		remote_list.clear()
		remote_status.text = "Enter an item name to search nearby systems"

func _on_remote_search(new_text: String) -> void:
	remote_list.clear()
	_clear_remote_detail()
	remote_item_name = new_text.strip_edges()
	if remote_item_name.length() < 2:
		remote_status.text = "Type at least 2 characters to search"
		return
	if not GameState.player.current_planet:
		remote_status.text = "No planet selected"
		return

	remote_results = EconomySystem.search_remote_sources(remote_item_name)
	remote_list.clear()
	if remote_results.is_empty():
		remote_status.text = "No sources found within 2 jumps"
		return

	for r in remote_results:
		remote_list.add_item("%s — %s  x%d  %s  (%d jumps, %d days)" % [
			r.source_system, remote_item_name, r.quantity,
			_fmt_money(r.cost_per_unit), r.jumps, r.travel_days])
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
	order_cost_label.text = "Cost: " + _fmt_money(r.cost_per_unit) + " per unit"
	order_travel_label.text = "Travel: " + str(r.travel_days) + " days (" + str(r.jumps) + " jump(s))"
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
		balance_label.text = "Balance: " + _fmt_money(EconomySystem.get_balance())
		order_button.disabled = true
		order_cost_label.text = "Order placed — arrives in " + str(r.travel_days) + " days"
	else:
		order_cost_label.text = "Order failed — insufficient funds"

func _on_close() -> void:
	hide()
	closed.emit()

func _fmt_money(amount: int) -> String:
	if amount >= 1000000:
		var m = amount / 1000000
		var frac = (amount % 1000000) / 100000
		return str(m) + "." + str(frac) + "M CB"
	elif amount >= 1000:
		var k = amount / 1000
		var frac = (amount % 1000) / 100
		return str(k) + "." + str(frac) + "K CB"
	return str(amount) + " CB"
