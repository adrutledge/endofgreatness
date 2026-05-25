class_name MechLab
extends Panel

signal closed()

var player_mechs: Array[TacticalUnit] = []
var selected_unit: TacticalUnit
var selected_variant: TacticalUnit
var variants: Array[TacticalUnit] = []
var current_parts_plan: Array[Dictionary] = []

var pending_changes: Array[Dictionary] = []
var component_names: Array[String] = []
var location_names: Array[String] = [
	"Head", "Center Torso", "Left Torso", "Right Torso",
	"Left Arm", "Right Arm", "Left Leg", "Right Leg",
]

var customize_tab: VBoxContainer
var component_check_list: VBoxContainer
var action_option: OptionButton
var location_option: OptionButton
var current_comp_option: OptionButton
var new_comp_option: OptionButton
var add_change_btn: Button
var pending_changes_container: VBoxContainer
var summary_label: RichTextLabel
var risk_label: RichTextLabel
var facility_label: RichTextLabel
var apply_customize_btn: Button
var history_label: RichTextLabel
var tab_container: TabContainer

var paper_doll_tab: VBoxContainer
var paper_doll_slot_map: Dictionary = {}
var paper_doll_selected: Dictionary = {}
var paper_doll_reset_btn: Button
var paper_doll_save_btn: Button

var components_tab: VBoxContainer
var component_browser_list: ItemList
var current_components_list: ItemList
var browser_type_filter: OptionButton
var browser_tech_filter: OptionButton
var browser_search: LineEdit
var components_remove_btn: Button
var components_replace_btn: Button
var components_browser_selected: String = ""

var component_type_filters: Array[String] = [
	"All", "Weapon", "Ammo", "Engine", "Gyro",
	"Structure", "Armor", "Electronics", "Jump Jet", "Cockpit", "Other",
]

var paper_doll_slot_counts: Dictionary = {
	"Head": 6, "Center Torso": 12, "Left Torso": 12, "Right Torso": 12,
	"Left Arm": 12, "Right Arm": 12, "Left Leg": 6, "Right Leg": 6,
}

var component_type_color_map: Dictionary = {
	"weapon": Color(0.3, 0.45, 0.3),
	"ammo": Color(0.8, 0.15, 0.15),
	"engine": Color(0.65, 0.5, 0.2),
	"gyro": Color(0.5, 0.3, 0.55),
	"structure": Color(0.45, 0.45, 0.45),
	"armor": Color(0.2, 0.45, 0.85),
	"electronics": Color(0.15, 0.75, 0.75),
	"jump_jet": Color(0.6, 0.3, 0.8),
	"heat_sink": Color(0.2, 0.4, 0.9),
	"cockpit": Color(0.85, 0.2, 0.65),
	"other": Color(0.3, 0.3, 0.3),
}

@onready var unit_list: ItemList = %UnitList
@onready var variant_list: ItemList = %VariantList
@onready var current_info: RichTextLabel = %CurrentInfo
@onready var variant_info: RichTextLabel = %VariantInfo
@onready var diff_info: RichTextLabel = %DiffInfo
@onready var parts_info: RichTextLabel = %PartsInfo
@onready var cost_label: Label = %CostLabel
@onready var hours_label: Label = %HoursLabel
@onready var start_refit_button: Button = %StartRefitButton
@onready var status_label: Label = %StatusLabel
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	Helpers.debug_print("MechLab", "_ready start")
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	add_theme_stylebox_override("panel", bg_style)

	Helpers.validate_nodes("MechLab", [
		["unit_list", unit_list], ["variant_list", variant_list], ["current_info", current_info],
		["variant_info", variant_info], ["diff_info", diff_info], ["parts_info", parts_info],
		["cost_label", cost_label], ["hours_label", hours_label], ["start_refit_button", start_refit_button],
		["status_label", status_label], ["close_button", close_button],
	])

	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	close_button.pressed.connect(_on_close)
	unit_list.item_selected.connect(_on_unit_selected)
	variant_list.item_selected.connect(_on_variant_selected)
	start_refit_button.pressed.connect(_on_start_refit)

	_setup_tabs()

	for name in DataManager.component_defs:
		component_names.append(name)
	component_names.sort()

	Helpers.debug_print("MechLab", "_ready done")

func _setup_tabs() -> void:
	var right_panel = %CurrentInfo.get_parent()

	var refit_nodes: Array[Node] = []
	for c in right_panel.get_children():
		refit_nodes.append(c)
	for c in refit_nodes:
		right_panel.remove_child(c)

	tab_container = TabContainer.new()
	tab_container.name = "MechLabTabs"
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(tab_container)

	paper_doll_tab = VBoxContainer.new()
	paper_doll_tab.name = "Paper Doll"
	paper_doll_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(paper_doll_tab)
	_init_fixed_slots()
	_build_paper_doll_tab()

	components_tab = VBoxContainer.new()
	components_tab.name = "Components"
	components_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(components_tab)
	_build_components_tab()

	var refit_page = VBoxContainer.new()
	refit_page.name = "Refit"
	refit_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(refit_page)
	for c in refit_nodes:
		refit_page.add_child(c)

	customize_tab = VBoxContainer.new()
	customize_tab.name = "Customize"
	customize_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(customize_tab)
	_build_customize_ui()

	tab_container.tab_selected.connect(_on_tab_changed)

func _build_paper_doll_tab() -> void:
	var header = Label.new()
	header.text = "Paper Doll — Click a slot to select"
	header.add_theme_font_size_override("font_size", 13)
	paper_doll_tab.add_child(header)

	var selected_info = Label.new()
	selected_info.name = "PaperDollSelectedInfo"
	selected_info.text = ""
	selected_info.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	paper_doll_tab.add_child(selected_info)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper_doll_tab.add_child(scroll)

	var wrapper = VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(wrapper)

	var head_row = HBoxContainer.new()
	wrapper.add_child(head_row)
	var hs1 = Control.new()
	hs1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(hs1)
	var hs2 = Control.new()
	hs2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(hs2)
	head_row.add_child(_make_location_column("Head", 6))
	var hs3 = Control.new()
	hs3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(hs3)
	var hs4 = Control.new()
	hs4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(hs4)

	wrapper.add_child(HSeparator.new())

	var mid_row = HBoxContainer.new()
	wrapper.add_child(mid_row)
	mid_row.add_child(_make_location_column("Left Arm", 12))
	mid_row.add_child(_make_location_column("Left Torso", 12))
	mid_row.add_child(_make_location_column("Center Torso", 12))
	mid_row.add_child(_make_location_column("Right Torso", 12))
	mid_row.add_child(_make_location_column("Right Arm", 12))

	wrapper.add_child(HSeparator.new())

	var leg_row = HBoxContainer.new()
	wrapper.add_child(leg_row)
	var lsp1 = Control.new()
	lsp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leg_row.add_child(lsp1)
	leg_row.add_child(_make_location_column("Left Leg", 6))
	var lsp_mid = Control.new()
	lsp_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leg_row.add_child(lsp_mid)
	leg_row.add_child(_make_location_column("Right Leg", 6))
	var lsp2 = Control.new()
	lsp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leg_row.add_child(lsp2)

	var btn_bar = HBoxContainer.new()
	btn_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	paper_doll_tab.add_child(btn_bar)

	paper_doll_reset_btn = Button.new()
	paper_doll_reset_btn.text = "Reset Changes"
	paper_doll_reset_btn.pressed.connect(_on_paper_doll_reset)
	btn_bar.add_child(paper_doll_reset_btn)

	paper_doll_save_btn = Button.new()
	paper_doll_save_btn.text = "Save Changes"
	paper_doll_save_btn.pressed.connect(_on_paper_doll_save_changes)
	btn_bar.add_child(paper_doll_save_btn)

func _component_type_color(comp_name: String) -> Color:
	var lower = comp_name.to_lower()
	if lower in ["life support"]:
		return Color(0.6, 0.25, 0.4)
	if lower in ["sensors"]:
		return Color(0.2, 0.25, 0.3)
	if lower in ["cockpit"]:
		return Color(0.85, 0.2, 0.65)
	if lower in ["engine", "fusion engine"]:
		return component_type_color_map.get("engine", Color(0.9, 0.55, 0.1))
	if lower in ["gyro"]:
		return component_type_color_map.get("gyro", Color(0.6, 0.2, 0.8))
	if "autocannon" in lower:
		return component_type_color_map.get("weapon", Color(0.8, 0.15, 0.15))
	for key in component_type_color_map:
		if key in lower:
			return component_type_color_map[key]
	return component_type_color_map.get("other", Color(0.3, 0.3, 0.3))


func _make_slot_button(location: String, slot_index: int, default_name: String = "") -> Button:
	var btn = Button.new()
	btn.text = default_name if default_name else "Empty"
	btn.custom_minimum_size = Vector2(110, 22)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 10)

	var style = StyleBoxFlat.new()
	if default_name:
		style.bg_color = _component_type_color(default_name)
	else:
		style.bg_color = Color(0.08, 0.08, 0.08)
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.2, 0.25)
	btn.add_theme_stylebox_override("normal", style)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.12, 0.12, 0.14)
	hover.border_width_bottom = 1
	hover.border_color = Color(0.3, 0.3, 0.35)
	btn.add_theme_stylebox_override("hover", hover)

	var loc_copy = location
	var idx_copy = slot_index
	btn.pressed.connect(func(): _on_paper_doll_slot_pressed(loc_copy, idx_copy))

	if not paper_doll_slot_map.has(location):
		paper_doll_slot_map[location] = []
	paper_doll_slot_map[location].append({"component": default_name, "button": btn, "location": location, "index": slot_index})

	return btn


func _make_paper_doll_head() -> VBoxContainer:
	var col = VBoxContainer.new()
	col.name = "Loc_Head"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title = Label.new()
	title.text = "Head"
	title.add_theme_font_size_override("font_size", 11)
	title.alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var slot_names := ["Life Support", "Sensors", "Cockpit", "", "Sensors", "Life Support"]
	for i in range(6):
		var btn = _make_slot_button("Head", i, slot_names[i])
		col.add_child(btn)
	return col


func _make_paper_doll_ct() -> VBoxContainer:
	var col = VBoxContainer.new()
	col.name = "Loc_Center_Torso"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title = Label.new()
	title.text = "Center Torso"
	title.add_theme_font_size_override("font_size", 11)
	title.alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var slot_types := ["Engine", "Engine", "Engine", "Gyro", "Gyro", "Gyro", "Gyro", "Engine", "Engine", "Engine", "", ""]
	for i in range(12):
		var slot_name = slot_types[i] if i < slot_types.size() else ""
		var btn = _make_slot_button("Center Torso", i, slot_name)
		col.add_child(btn)
	return col


func _make_location_column(location: String, slot_count: int) -> VBoxContainer:
	var col = VBoxContainer.new()
	col.name = "Loc_" + location.replace(" ", "_")
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl = Label.new()
	lbl.text = location + " (" + str(slot_count) + ")"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lbl)

	for i in range(slot_count):
		var btn = _make_slot_button(location, i)
		col.add_child(btn)

	return col

func _build_components_tab() -> void:
	var filter_hb = HBoxContainer.new()
	filter_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	components_tab.add_child(filter_hb)

	var type_lbl = Label.new()
	type_lbl.text = "Type:"
	type_lbl.add_theme_font_size_override("font_size", 11)
	filter_hb.add_child(type_lbl)

	browser_type_filter = OptionButton.new()
	browser_type_filter.name = "BrowserTypeFilter"
	for t in component_type_filters:
		browser_type_filter.add_item(t)
	browser_type_filter.selected = 0
	browser_type_filter.item_selected.connect(_on_browser_filter_changed)
	filter_hb.add_child(browser_type_filter)

	var tech_lbl = Label.new()
	tech_lbl.text = "Tech:"
	tech_lbl.add_theme_font_size_override("font_size", 11)
	filter_hb.add_child(tech_lbl)

	browser_tech_filter = OptionButton.new()
	browser_tech_filter.name = "BrowserTechFilter"
	browser_tech_filter.add_item("All")
	browser_tech_filter.add_item("1")
	browser_tech_filter.add_item("2")
	browser_tech_filter.add_item("3")
	browser_tech_filter.add_item("4")
	browser_tech_filter.add_item("5")
	browser_tech_filter.selected = 0
	browser_tech_filter.item_selected.connect(_on_browser_filter_changed)
	filter_hb.add_child(browser_tech_filter)

	var search_lbl = Label.new()
	search_lbl.text = "Search:"
	search_lbl.add_theme_font_size_override("font_size", 11)
	filter_hb.add_child(search_lbl)

	browser_search = LineEdit.new()
	browser_search.name = "BrowserSearch"
	browser_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browser_search.placeholder_text = "filter..."
	browser_search.text_changed.connect(_on_browser_filter_changed)
	filter_hb.add_child(browser_search)

	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	components_tab.add_child(split)

	var browser_vb = VBoxContainer.new()
	browser_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(browser_vb)

	var browser_title = Label.new()
	browser_title.text = "All Components"
	browser_title.add_theme_font_size_override("font_size", 13)
	browser_vb.add_child(browser_title)

	component_browser_list = ItemList.new()
	component_browser_list.name = "ComponentBrowserList"
	component_browser_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	component_browser_list.item_selected.connect(_on_browser_selected)
	browser_vb.add_child(component_browser_list)

	var current_vb = VBoxContainer.new()
	current_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(current_vb)

	var current_title = Label.new()
	current_title.text = "Current Mech Components"
	current_title.add_theme_font_size_override("font_size", 13)
	current_vb.add_child(current_title)

	current_components_list = ItemList.new()
	current_components_list.name = "CurrentComponentsList"
	current_components_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	current_components_list.item_selected.connect(_on_current_comp_selected)
	current_vb.add_child(current_components_list)

	var action_bar = HBoxContainer.new()
	action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	components_tab.add_child(action_bar)

	components_remove_btn = Button.new()
	components_remove_btn.text = "Remove Selected"
	components_remove_btn.disabled = true
	components_remove_btn.pressed.connect(_on_components_remove)
	action_bar.add_child(components_remove_btn)

	components_replace_btn = Button.new()
	components_replace_btn.text = "Replace Selected"
	components_replace_btn.disabled = true
	components_replace_btn.pressed.connect(_on_components_replace)
	action_bar.add_child(components_replace_btn)

func _build_customize_ui() -> void:
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	customize_tab.add_child(scroll)

	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)

	var comp_title = Label.new()
	comp_title.text = "Current Components"
	comp_title.add_theme_font_size_override("font_size", 14)
	vb.add_child(comp_title)

	component_check_list = VBoxContainer.new()
	component_check_list.name = "ComponentCheckList"
	vb.add_child(component_check_list)

	var sep1 = HSeparator.new()
	vb.add_child(sep1)

	var chg_title = Label.new()
	chg_title.text = "Add Change"
	chg_title.add_theme_font_size_override("font_size", 14)
	vb.add_child(chg_title)

	var change_hb = HBoxContainer.new()
	change_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(change_hb)

	action_option = OptionButton.new()
	action_option.name = "ActionOption"
	for a in ["Add", "Remove", "Replace"]:
		action_option.add_item(a)
	change_hb.add_child(action_option)

	location_option = OptionButton.new()
	location_option.name = "LocationOption"
	for loc in location_names:
		location_option.add_item(loc)
	change_hb.add_child(location_option)

	current_comp_option = OptionButton.new()
	current_comp_option.name = "CurrentCompOption"
	current_comp_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	change_hb.add_child(current_comp_option)

	new_comp_option = OptionButton.new()
	new_comp_option.name = "NewCompOption"
	new_comp_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	change_hb.add_child(new_comp_option)

	add_change_btn = Button.new()
	add_change_btn.text = "Add"
	add_change_btn.pressed.connect(_on_add_change)
	change_hb.add_child(add_change_btn)

	var sep2 = HSeparator.new()
	vb.add_child(sep2)

	var pend_title = Label.new()
	pend_title.text = "Pending Changes"
	pend_title.add_theme_font_size_override("font_size", 14)
	vb.add_child(pend_title)

	pending_changes_container = VBoxContainer.new()
	pending_changes_container.name = "PendingChangesContainer"
	vb.add_child(pending_changes_container)

	var sep3 = HSeparator.new()
	vb.add_child(sep3)

	var sum_title = Label.new()
	sum_title.text = "Customization Summary"
	sum_title.add_theme_font_size_override("font_size", 14)
	vb.add_child(sum_title)

	summary_label = RichTextLabel.new()
	summary_label.name = "SummaryLabel"
	summary_label.bbcode_enabled = true
	summary_label.fit_content = true
	vb.add_child(summary_label)

	var sep4 = HSeparator.new()
	vb.add_child(sep4)

	var risk_title = Label.new()
	risk_title.text = "Risk Assessment"
	risk_title.add_theme_font_size_override("font_size", 14)
	vb.add_child(risk_title)

	risk_label = RichTextLabel.new()
	risk_label.name = "RiskLabel"
	risk_label.bbcode_enabled = true
	risk_label.fit_content = true
	vb.add_child(risk_label)

	var sep5 = HSeparator.new()
	vb.add_child(sep5)

	var fac_title = Label.new()
	fac_title.text = "Facility Gating"
	fac_title.add_theme_font_size_override("font_size", 14)
	vb.add_child(fac_title)

	facility_label = RichTextLabel.new()
	facility_label.name = "FacilityLabel"
	facility_label.bbcode_enabled = true
	facility_label.fit_content = true
	vb.add_child(facility_label)

	apply_customize_btn = Button.new()
	apply_customize_btn.text = "Apply Customization"
	apply_customize_btn.disabled = true
	apply_customize_btn.pressed.connect(_on_apply_customization)
	vb.add_child(apply_customize_btn)

	var sep6 = HSeparator.new()
	vb.add_child(sep6)

	var hist_title = Label.new()
	hist_title.text = "Customization History"
	hist_title.add_theme_font_size_override("font_size", 14)
	vb.add_child(hist_title)

	history_label = RichTextLabel.new()
	history_label.bbcode_enabled = true
	history_label.fit_content = true
	vb.add_child(history_label)

func _on_tab_changed(tab_index: int) -> void:
	match tab_index:
		0:
			if selected_unit:
				_refresh_paper_doll()
		1:
			if selected_unit:
				_populate_component_browser()
				_populate_current_components_list()
		3:
			if selected_unit:
				_show_customize_view()

func populate() -> void:
	player_mechs.clear()
	Helpers.debug_print("MechLab", "populate start org_units=" + str(GameState.player.organizational_units.size()))
	for ou in GameState.player.organizational_units:
		for tu in ou.get_all_tactical_units():
			if tu.unit_type == Enums.UnitType.MECH:
				player_mechs.append(tu)

	unit_list.clear()
	for tu in player_mechs:
		var status = ""
		var refit = RefitManager.get_unit_refit(tu)
		if refit:
			if not refit.parts_delivered:
				status = " [PARTS: " + str(refit.parts_delivery_eta) + "d]"
			else:
				status = " [REFIT: " + str(refit.hours_remaining) + "h]"
		unit_list.add_item(tu.unit_name + status)

	_clear_detail()

func _clear_detail() -> void:
	selected_unit = null
	selected_variant = null
	variants.clear()
	variant_list.clear()
	current_info.text = ""
	variant_info.text = ""
	diff_info.text = ""
	parts_info.text = ""
	cost_label.text = ""
	hours_label.text = ""
	start_refit_button.disabled = true
	current_parts_plan.clear()
	pending_changes.clear()
	paper_doll_selected = {}
	components_browser_selected = ""
	_update_status()

func _on_unit_selected(index: int) -> void:
	if index < 0 or index >= player_mechs.size():
		return
	selected_unit = player_mechs[index]

	var chassis = selected_unit.chassis_name
	var canon_only = _get_refit_canon_only() == 1
	variants = DataManager.get_variants_for_chassis(chassis, canon_only)

	var ch = RichTextHelper.new()
	ch.add("[b]" + selected_unit.unit_name + "[/b]")
	ch.add("Chassis: " + chassis)
	ch.add("Tonnage: " + str(selected_unit.tonnage) + "t")
	ch.add("Movement: " + str(selected_unit.movement_mp) + "/" + str(selected_unit.run_mp) + "/" + str(selected_unit.jump_mp))
	ch.add("")
	ch.add("[b]Current Components:[/b]")
	for c in selected_unit.components:
		ch.add("  " + c.component_name)
	current_info.text = ch.get_text()

	variant_list.clear()
	var rule = _get_refit_canon_only()
	for v in variants:
		var label = v.unit_name
		if v.model_name == selected_unit.model_name:
			label += " (current)"
		elif not DataManager.is_canon_unit(v.unit_name):
			if rule == -1 and not GameState.proven_custom_variants.has(v.unit_name):
				label += " [customize first]"
			elif rule == 1:
				continue
		variant_list.add_item(label)

	variant_info.text = ""
	diff_info.text = ""
	parts_info.text = ""
	cost_label.text = ""
	hours_label.text = ""
	start_refit_button.disabled = true
	pending_changes.clear()
	paper_doll_selected = {}
	components_browser_selected = ""
	_update_status()

	_refresh_paper_doll()
	_populate_component_browser()
	_populate_current_components_list()

	if tab_container:
		match tab_container.current_tab:
			1: _populate_current_components_list()
			3: _show_customize_view()

func _on_variant_selected(index: int) -> void:
	if index < 0 or index >= variants.size() or not selected_unit:
		return
	selected_variant = variants[index]

	if selected_variant.model_name == selected_unit.model_name:
		variant_info.text = "[color=#888888]This is the current variant — no refit needed[/color]"
		diff_info.text = ""
		parts_info.text = ""
		cost_label.text = ""
		hours_label.text = ""
		start_refit_button.disabled = true
		return

	var active = RefitManager.get_unit_refit(selected_unit)
	if active:
		status_label.text = "Unit already has an active refit"
		start_refit_button.disabled = true
		_update_status()
		return

	var vh = RichTextHelper.new()
	vh.add("[b]" + selected_variant.unit_name + "[/b]")
	vh.add("Chassis: " + selected_variant.chassis_name)
	vh.add("Tonnage: " + str(selected_variant.tonnage) + "t")
	vh.add("Movement: " + str(selected_variant.movement_mp) + "/" + str(selected_variant.run_mp) + "/" + str(selected_variant.jump_mp))
	vh.add("")
	vh.add("[b]Target Components:[/b]")
	for c in selected_variant.components:
		vh.add("  " + c.component_name)
	variant_info.text = vh.get_text()

	var diff = RefitManager.calculate_refit_diff(selected_unit, selected_variant)
	var dh = RichTextHelper.new()
	dh.add("[b]Components to Remove:[/b]")
	if diff.components_to_remove.is_empty():
		dh.add("  None")
	else:
		for name in diff.components_to_remove:
			dh.add("  [color=#ff6644]" + name + "[/color]")
	dh.add("")
	dh.add("[b]Components to Add:[/b]")
	if diff.components_to_add.is_empty():
		dh.add("  None")
	else:
		for name in diff.components_to_add:
			dh.add("  [color=#44ff66]" + name + "[/color]")
	diff_info.text = dh.get_text()

	current_parts_plan.clear()
	var kit_info = RefitManager.calculate_refit_kit(diff)
	var total_cost = kit_info.cost
	var max_delivery = kit_info.delivery_days

	var ph = RichTextHelper.new()
	ph.add("[b]Refit Kit (single purchase):[/b]")
	ph.add("  Kit cost: " + Helpers.fmt_money(total_cost))
	if max_delivery > 0:
		ph.add("  Delivery: " + str(max_delivery) + " days")
	else:
		ph.add("  Available locally — no delivery wait")
	parts_info.text = ph.get_text()

	var hours = RefitManager.calculate_refit_hours(diff)
	var clas_info = RefitManager.classify_refit(diff)
	var clas_name = RefitManager.get_refit_class_name(clas_info.overall_class)
	var clas_hours = RefitManager.CLASS_HOURS[clas_info.overall_class]
	var kit_bonus = RefitManager.get_refit_kit_bonus({"overall_class": clas_info.overall_class})
	cost_label.text = "Refit kit: " + Helpers.fmt_money(total_cost) + "  |  Class: " + clas_name
	diff_info.text += "\n\n[b]Refit Class: " + clas_name + "[/b] (" + str(clas_hours) + " hrs/ton per component)"
	var kit_text = ""
	if kit_bonus < 0:
		kit_text = " | TN bonus: " + str(kit_bonus)
	var delivery_text = "" if max_delivery <= 0 else " | Kit delivery: " + str(max_delivery) + " days"
	hours_label.text = "Labor: " + str(hours) + " technician-hours" + delivery_text + kit_text
	start_refit_button.disabled = false
	_update_status()

func _on_start_refit() -> void:
	if not selected_unit or not selected_variant:
		return
	if selected_variant.model_name == selected_unit.model_name:
		status_label.text = "Already the current variant"
		return

	var active = RefitManager.get_unit_refit(selected_unit)
	if active:
		status_label.text = "Unit already has an active refit"
		return

	var result = RefitManager.start_refit(selected_unit, selected_variant)
	if result.success:
		var r = result.refit
		var rclas_name = RefitManager.get_refit_class_name(r.overall_class)
		var msg = "Refit started! Class " + rclas_name
		if r.parts_delivery_eta > 0:
			msg += " — parts arriving in " + str(r.parts_delivery_eta) + " days, then "
		msg += " — " + str(r.hours_remaining) + " hours of labor remaining"
		status_label.text = msg
		start_refit_button.disabled = true
		populate()
	else:
		status_label.text = "Refit failed: " + result.reason

func _show_customize_view() -> void:
	if not selected_unit:
		return

	for c in component_check_list.get_children():
		c.queue_free()

	for c in selected_unit.components:
		var cb = CheckBox.new()
		var loc_name = c.location.location_name if c.location else "?"
		cb.text = c.component_name + "  [" + loc_name + "]"
		component_check_list.add_child(cb)

	current_comp_option.clear()
	current_comp_option.add_item("(select current)")
	for c in selected_unit.components:
		var loc_name = c.location.location_name if c.location else "?"
		current_comp_option.add_item(c.component_name + " [" + loc_name + "]")
	current_comp_option.selected = 0

	new_comp_option.clear()
	new_comp_option.add_item("(select new)")
	for name in component_names:
		new_comp_option.add_item(name)
	new_comp_option.selected = 0

	_refresh_pending_changes()
	_update_customization_summary()
	_show_customization_history()

func _refresh_pending_changes() -> void:
	for c in pending_changes_container.get_children():
		c.queue_free()

	if pending_changes.is_empty():
		var lbl = Label.new()
		lbl.text = "  No pending changes"
		pending_changes_container.add_child(lbl)
		return

	for i in range(pending_changes.size()):
		var ch = pending_changes[i]
		var hb = HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var action_text = ch.get("action", "?")
		var comp_text = ""
		match action_text:
			"add":
				comp_text = "Add " + ch.get("new_component", "?") + " [" + ch.get("location", "?") + "]"
			"remove":
				comp_text = "Remove " + ch.get("current_component", "?")
			"replace":
				comp_text = "Replace " + ch.get("current_component", "?") + " with " + ch.get("new_component", "?") + " [" + ch.get("location", "?") + "]"
		var lbl = Label.new()
		lbl.text = "  " + comp_text
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lbl)
		var rmv = Button.new()
		rmv.text = "X"
		var idx = i
		rmv.pressed.connect(func(): _remove_pending_change(idx))
		hb.add_child(rmv)
		pending_changes_container.add_child(hb)

func _on_add_change() -> void:
	if not selected_unit:
		return

	var action: String
	match action_option.selected:
		0: action = "add"
		1: action = "remove"
		2: action = "replace"
		_: return

	var location = location_names[location_option.selected]
	var current_idx = current_comp_option.selected - 1
	var new_idx = new_comp_option.selected - 1

	var current_comp = ""
	var current_loc = ""
	if action == "remove" or action == "replace":
		if current_idx < 0 or current_idx >= selected_unit.components.size():
			return
		var comp = selected_unit.components[current_idx]
		current_comp = comp.component_name
		current_loc = comp.location.location_name if comp.location else ""

	var new_comp = ""
	if action == "add" or action == "replace":
		if new_idx < 0 or new_idx >= component_names.size():
			return
		new_comp = component_names[new_idx]

	var class_info = RefitManager.classify_customization_change(
		current_comp, new_comp, current_loc, location)

	var change = {
		"action": action,
		"current_component": current_comp,
		"new_component": new_comp,
		"location": location,
		"class": class_info.class,
		"tonnage": class_info.tonnage,
	}

	pending_changes.append(change)
	_refresh_pending_changes()
	_update_customization_summary()

func _remove_pending_change(index: int) -> void:
	if index >= 0 and index < pending_changes.size():
		pending_changes.remove_at(index)
		_refresh_pending_changes()
		_update_customization_summary()

func _update_customization_summary() -> void:
	if pending_changes.is_empty():
		summary_label.text = "  No changes specified"
		risk_label.text = ""
		facility_label.text = ""
		apply_customize_btn.disabled = true
		return

	var summary = RefitManager.calculate_customization_summary(pending_changes)

	var sh = RichTextHelper.new()
	sh.add("[b]Total Time:[/b] " + str(summary.total_time) + " hours")
	sh.add("[b]Total Cost:[/b] " + Helpers.fmt_money(summary.total_cost))
	sh.add("[b]Highest Class:[/b] " + _class_badge(summary.highest_class))
	sh.add("")
	sh.add("[b]Per-Component Detail:[/b]")
	for d in summary.detail:
		var c_name = d.get("component", "?")
		var badge = _class_badge(d.get("class", 0))
		sh.add("  " + d.get("action", "?") + " " + c_name + "  —  " + badge + "  —  " + str(d.time) + "h  —  " + Helpers.fmt_money(d.cost))
	summary_label.text = sh.get_text()

	var tech_skill = _get_best_tech_skill(selected_unit)
	var facility_lvl = RefitManager.get_facility_level()
	var threshold = tech_skill + 3

	var rh = RichTextHelper.new()
	var highest_tn = _get_highest_tn()
	rh.add("[b]Highest Component TN:[/b] " + str(highest_tn))
	rh.add("[b]Tech Skill:[/b] " + str(tech_skill) + "  |  [b]Threshold:[/b] " + str(threshold) + "  |  [b]Facility:[/b] Lvl " + str(facility_lvl))
	if highest_tn > threshold:
		rh.add("[color=#ff4444]Highest TN exceeds threshold — high risk of failure and extended labor[/color]")
	else:
		rh.add("[color=#44ff66]Highest TN within threshold — manageable risk[/color]")
	risk_label.text = rh.get_text()

	var fh = RichTextHelper.new()
	fh.add("[b]Facility Gating:[/b]")
	var gate = RefitManager.check_facility_gating(summary.highest_class)
	var req_names = {0: "None (Lvl 0)", 1: "Standard (Lvl 1)", 2: "Advanced (Lvl 2)", 3: "Elite (Lvl 3)"}
	fh.add("  Required: " + req_names.get(gate.required, "?"))
	fh.add("  Current Facility: Level " + str(gate.has))
	if gate.passes:
		fh.add("  [color=#44ff66]Passes — no facility penalty[/color]")
	else:
		fh.add("  [color=#ff4444]FAILS — +" + str(gate.penalty) + " TN penalty[/color]")
	facility_label.text = fh.get_text()

	apply_customize_btn.disabled = false

func _get_best_tech_skill(unit: TacticalUnit) -> int:
	var best_skill = -1
	for t in unit.assigned_technicians:
		var s = t.get_tech_skill()
		if s > best_skill:
			best_skill = s
	return best_skill if best_skill >= 0 else 4

func _get_refit_canon_only() -> int:
	var f = FileAccess.open("res://data/config/spares_config.json", FileAccess.READ)
	if f:
		var j = JSON.new()
		if j.parse(f.get_as_text()) == OK:
			return j.data.get("refit_canon_only", 1)
	return 1


func _get_highest_tn() -> int:
	if pending_changes.is_empty():
		return 0
	var highest := 0
	for ch in pending_changes:
		var tn = RefitManager.calculate_customization_tn(ch, 2, RefitManager.get_facility_level(), 2, true)
		if tn > highest:
			highest = tn
	return highest


func _find_change_for_component(comp_name: String) -> Dictionary:
	for ch in pending_changes:
		if ch.get("new_component", ch.get("current_component", "")) == comp_name:
			return ch
	return {}

func _class_badge(class_val: int) -> String:
	match class_val:
		Enums.RefitClass.B: return "[b]B[/b] (Standard)"
		Enums.RefitClass.C: return "[b]C[/b] (Complex)"
		Enums.RefitClass.D: return "[b]D[/b] (Major)"
		Enums.RefitClass.E: return "[b]E[/b] (Chassis)"
	return "?"

func _on_apply_customization() -> void:
	if not selected_unit or pending_changes.is_empty():
		return

	var active = RefitManager.get_unit_refit(selected_unit)
	if active:
		status_label.text = "Unit already has an active refit or customization"
		return

	var parts_plan: Array[Dictionary] = []
	for ch in pending_changes:
		if ch.get("action") == "add" or ch.get("action") == "replace":
			var def = DataManager.component_defs.get(ch.get("new_component", ""), {})
			parts_plan.append({
				"component_name": ch.get("new_component", ""),
				"source": "local",
				"cost_per_unit": def.get("cost", 1000),
			})

	var result = RefitManager.start_customization(selected_unit, pending_changes, parts_plan)
	if result.success:
		var c = result.customization
		var msg = "Customization started! " + _class_badge(c.highest_class)
		if not c.parts_delivered:
			msg += " — parts in " + str(c.parts_delivery_eta) + "d, then "
		msg += " — " + str(c.total_hours) + " hours"
		status_label.text = msg
		pending_changes.clear()
		_refresh_pending_changes()
		_update_customization_summary()
		populate()
	else:
		status_label.text = "Customization failed: " + result.reason

func _show_customization_history() -> void:
	if not selected_unit:
		history_label.text = ""
		return

	var log = RefitManager.get_customization_log(selected_unit)
	if log.is_empty():
		history_label.text = "  No customization history"
		return

	var hh = RichTextHelper.new()
	for entry in log:
		var date = entry.get("date", "?")
		var tech = entry.get("technician", "?")
		var result = entry.get("result", "?")
		var n_changes = entry.get("changes", 0)
		var color = "#44ff66"
		if result == "failure":
			color = "#ffaa44"
		var extra = entry.get("extra_hours", 0)
		var extra_text = (" +" + str(extra) + "h retry") if extra > 0 else ""
		hh.add("[" + date + "] [color=" + color + "]" + result + "[/color] — " + str(n_changes) + " change(s)" + extra_text + " (tech: " + tech + ")")
	history_label.text = hh.get_text()

func _update_status() -> void:
	var n = RefitManager.active_refits.size()
	status_label.text = ("Active refits: " + str(n)) if n > 0 else ""

# --- Paper Doll Methods ---

var _fixed_slots: Dictionary = {}
var _fixed_slot_owners: Dictionary = {}
var _available_slot_indices: Dictionary = {}

# Maps component name patterns to the fixed slot type they own
var _structural_component_map: Dictionary = {}


func _match_structural_component(cname_lower: String) -> Dictionary:
	for key in _structural_component_map:
		var info = _structural_component_map[key]
		var match_type = info.get("match", "exact")
		if match_type == "contains":
			if key in cname_lower or cname_lower in key:
				return info
		else:
			if cname_lower == key:
				return info
	return {}


func _init_fixed_slots() -> void:
	_fixed_slots["Head"] = {0: "Life Support", 1: "Sensors", 2: "Cockpit", 4: "Sensors", 5: "Life Support"}
	_fixed_slots["Center Torso"] = {}
	for i in range(3):
		_fixed_slots["Center Torso"][i] = "Engine"
	for i in range(3, 7):
		_fixed_slots["Center Torso"][i] = "Gyro"
	for i in range(7, 10):
		_fixed_slots["Center Torso"][i] = "Engine"

	_structural_component_map = {
		"engine": { "loc": "Center Torso", "indices": [0, 1, 2, 7, 8, 9], "match": "contains" },
		"gyro": { "loc": "Center Torso", "indices": [3, 4, 5, 6], "match": "contains" },
		"cockpit": { "loc": "Head", "indices": [2], "match": "contains" },
		"sensors": { "loc": "Head", "indices": [1, 4], "match": "exact" },
		"life support": { "loc": "Head", "indices": [0, 5], "match": "contains" },
	}

	_available_slot_indices["Head"] = [3]
	_available_slot_indices["Center Torso"] = [10, 11]
	for loc in ["Left Torso", "Right Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"]:
		_available_slot_indices[loc] = []
		for i in range(paper_doll_slot_counts.get(loc, 12)):
			_available_slot_indices[loc].append(i)


func _apply_fixed_slots() -> void:
	for loc_name in _fixed_slots:
		if not paper_doll_slot_map.has(loc_name):
			continue
		var slots = paper_doll_slot_map[loc_name]
		for idx in _fixed_slots[loc_name]:
			if idx < 0 or idx >= slots.size():
				continue
			var name = _fixed_slots[loc_name][idx]
			slots[idx]["component"] = name
			var btn = slots[idx]["button"]
			btn.text = name
			var c = _component_type_color(name)
			var style = StyleBoxFlat.new()
			style.bg_color = c
			style.border_width_bottom = 1
			style.border_color = Color(0.2, 0.2, 0.25)
			btn.add_theme_stylebox_override("normal", style)
			var hover = StyleBoxFlat.new()
			hover.bg_color = c * 1.3
			hover.border_width_bottom = 1
			hover.border_color = Color(0.4, 0.4, 0.45)
			btn.add_theme_stylebox_override("hover", hover)


func _refresh_paper_doll() -> void:
	paper_doll_selected = {}
	_apply_fixed_slots()

	if not selected_unit:
		for loc_name in paper_doll_slot_map:
			for idx in _available_slot_indices.get(loc_name, []):
				var slots = paper_doll_slot_map[loc_name]
				if idx < 0 or idx >= slots.size():
					continue
				slots[idx]["component"] = ""
				var btn = slots[idx]["button"]
				btn.text = "Empty"
				var style = StyleBoxFlat.new()
				style.bg_color = Color(0.06, 0.06, 0.06)
				style.border_width_bottom = 1
				style.border_color = Color(0.15, 0.15, 0.18)
				btn.add_theme_stylebox_override("normal", style)
		var sel_info = paper_doll_tab.get_node_or_null("PaperDollSelectedInfo")
		if sel_info:
			sel_info.text = ""
		return

	for loc_name in paper_doll_slot_map:
		var slots = paper_doll_slot_map[loc_name]
		var available = _available_slot_indices.get(loc_name, [])
		for idx in available:
			slots[idx]["component"] = ""
			var btn = slots[idx]["button"]
			btn.text = "Empty"
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.06, 0.06, 0.06)
			style.border_width_bottom = 1
			style.border_color = Color(0.15, 0.15, 0.18)
			btn.add_theme_stylebox_override("normal", style)

	for c in selected_unit.components:
		if not c.location:
			continue
		var loc_name = c.location.location_name
		if not paper_doll_slot_map.has(loc_name):
			continue
		var slots = paper_doll_slot_map[loc_name]
		var cname = c.component_name.to_lower()

		var struct_info = _match_structural_component(cname)
		if struct_info and struct_info.loc == loc_name:
			var idxs = struct_info.indices
			var placed := 0
			for idx in idxs:
				if idx < 0 or idx >= slots.size():
					continue
				slots[idx]["component"] = c.component_name
				var btn = slots[idx]["button"]
				btn.text = c.component_name
				var col = _component_type_color(c.component_name)
				var style = StyleBoxFlat.new()
				style.bg_color = col
				style.border_width_bottom = 1
				style.border_color = Color(0.2, 0.2, 0.25)
				btn.add_theme_stylebox_override("normal", style)
				var hover = StyleBoxFlat.new()
				hover.bg_color = col * 1.3
				hover.border_width_bottom = 1
				hover.border_color = Color(0.4, 0.4, 0.45)
				btn.add_theme_stylebox_override("hover", hover)
				placed += 1
			continue

		var available = _available_slot_indices.get(loc_name, [])
		if c.critical_slots <= 0:
			continue
		var placed := 0
		for idx in available:
			if placed >= c.critical_slots:
				break
			if idx < 0 or idx >= slots.size():
				continue
			if slots[idx]["component"] != "":
				continue
			var n = c.critical_slots
			slots[idx]["component"] = c.component_name
			var btn = slots[idx]["button"]
			var comp_type = _classify_component(c.component_name)
			var col = component_type_color_map.get(comp_type, component_type_color_map["other"])
			var style = StyleBoxFlat.new()
			style.bg_color = col
			style.border_width_bottom = 1
			style.border_color = Color(0.2, 0.2, 0.25)
			btn.add_theme_stylebox_override("normal", style)
			var hover = StyleBoxFlat.new()
			hover.bg_color = col * 1.3
			hover.border_width_bottom = 1
			hover.border_color = Color(0.4, 0.4, 0.45)
			btn.add_theme_stylebox_override("hover", hover)
			var disp = c.component_name
			if n > 1:
				disp = c.component_name + " [" + str(placed + 1) + "/" + str(n) + "]"
			btn.text = disp
			placed += 1

	var sel_info = paper_doll_tab.get_node_or_null("PaperDollSelectedInfo")
	if sel_info:
		sel_info.text = ""

func _on_paper_doll_slot_pressed(location: String, slot_index: int) -> void:
	if not selected_unit:
		return
	if not paper_doll_slot_map.has(location):
		return
	var slots = paper_doll_slot_map[location]
	if slot_index < 0 or slot_index >= slots.size():
		return

	var slot = slots[slot_index]
	var comp_name = slot["component"]

	paper_doll_selected = {"location": location, "index": slot_index}
	_highlight_paper_doll_slot(location, slot_index)

	if comp_name.is_empty():
		if not components_browser_selected.is_empty():
			_paper_doll_add_pending_change("add", "", components_browser_selected, location)
			_refresh_paper_doll()
		else:
			var sel_info = paper_doll_tab.get_node_or_null("PaperDollSelectedInfo")
			if sel_info:
				sel_info.text = "Empty slot selected in " + location + " — ready for placement"
	else:
		var sel_info = paper_doll_tab.get_node_or_null("PaperDollSelectedInfo")
		if sel_info:
			var comp_type = _classify_component(comp_name)
			sel_info.text = "Selected: " + comp_name + " [" + comp_type + "] in " + location

func _highlight_paper_doll_slot(location: String, index: int) -> void:
	for loc_name in location_names:
		if not paper_doll_slot_map.has(loc_name):
			continue
		var slots = paper_doll_slot_map[loc_name]
		for s in slots:
			var btn = s["button"]
			var cname = s["component"]
			var is_selected = (loc_name == location and s["index"] == index)

			var style = StyleBoxFlat.new()
			if cname.is_empty():
				style.bg_color = Color(0.06, 0.06, 0.06) if not is_selected else Color(0.15, 0.12, 0.05)
			else:
				var comp_type = _classify_component(cname)
				var base = component_type_color_map.get(comp_type, component_type_color_map["other"])
				style.bg_color = base if not is_selected else base * 1.4
			style.border_width_bottom = 1
			if is_selected:
				style.border_width_top = 2
				style.border_width_left = 2
				style.border_width_right = 2
				style.border_color = Color(1.0, 0.9, 0.3)
			else:
				style.border_color = Color(0.2, 0.2, 0.25)
			btn.add_theme_stylebox_override("normal", style)

func _on_paper_doll_reset() -> void:
	pending_changes.clear()
	paper_doll_selected = {}
	components_browser_selected = ""
	_refresh_paper_doll()
	_populate_component_browser()
	_populate_current_components_list()

	var sel_info = paper_doll_tab.get_node_or_null("PaperDollSelectedInfo")
	if sel_info:
		sel_info.text = "Changes reset"

func _on_paper_doll_save_changes() -> void:
	if pending_changes.is_empty():
		return
	tab_container.current_tab = 3

# --- Components Tab Methods ---

func _populate_component_browser() -> void:
	component_browser_list.clear()
	if not selected_unit:
		return

	var filter_type = browser_type_filter.get_item_text(browser_type_filter.selected)
	var filter_tech = browser_tech_filter.get_item_text(browser_tech_filter.selected)
	var search_text = browser_search.text.strip_edges().to_lower()

	for name in component_names:
		var def = DataManager.component_defs.get(name, {})
		if not def:
			continue

		var comp_type = _classify_component(name)

		if filter_type != "All" and comp_type != filter_type.to_lower():
			continue

		if filter_tech != "All":
			var tl = def.get("tech_level", 1)
			if str(tl) != filter_tech:
				continue

		if not search_text.is_empty():
			if not search_text in name.to_lower():
				continue

		component_browser_list.add_item(name)

func _populate_current_components_list() -> void:
	current_components_list.clear()
	if not selected_unit:
		components_remove_btn.disabled = true
		return

	for c in selected_unit.components:
		var loc_name = c.location.location_name if c.location else "Unknown"
		var label = c.component_name + " [" + loc_name + "]"
		var idx = current_components_list.add_item(label)
		current_components_list.set_item_metadata(idx, {
			"component_name": c.component_name,
			"location": loc_name,
		})

	components_remove_btn.disabled = current_components_list.get_item_count() <= 0

func _on_browser_filter_changed(_dummy = null) -> void:
	_populate_component_browser()

func _on_browser_selected(index: int) -> void:
	if index < 0 or index >= component_browser_list.get_item_count():
		components_browser_selected = ""
		components_replace_btn.disabled = true
		return
	components_browser_selected = component_browser_list.get_item_text(index)
	components_replace_btn.disabled = paper_doll_selected.is_empty()

func _on_current_comp_selected(index: int) -> void:
	components_remove_btn.disabled = index < 0

func _on_components_remove() -> void:
	if not selected_unit:
		return
	var sel = current_components_list.get_selected_items()
	if sel.is_empty():
		return
	var idx = sel[0]
	var meta = current_components_list.get_item_metadata(idx)
	var comp_name = meta.get("component_name", "")
	var loc = meta.get("location", "")
	if comp_name.is_empty():
		return
	_paper_doll_add_pending_change("remove", comp_name, "", loc)
	_refresh_paper_doll()
	_populate_current_components_list()

func _on_components_replace() -> void:
	if not selected_unit or components_browser_selected.is_empty() or paper_doll_selected.is_empty():
		return
	var location = paper_doll_selected.get("location", "")
	var index = paper_doll_selected.get("index", 0)
	if not paper_doll_slot_map.has(location):
		return
	var slots = paper_doll_slot_map[location]
	if index < 0 or index >= slots.size():
		return
	var current_comp_name = slots[index].get("component", "")
	if current_comp_name.is_empty():
		_paper_doll_add_pending_change("add", "", components_browser_selected, location)
	else:
		_paper_doll_add_pending_change("replace", current_comp_name, components_browser_selected, location)
	_refresh_paper_doll()
	paper_doll_selected = {}

func _paper_doll_add_pending_change(action: String, current: String, new_comp: String, location: String) -> void:
	var cl_info = RefitManager.classify_customization_change(current, new_comp, location, location)
	var change = {
		"action": action,
		"current_component": current,
		"new_component": new_comp,
		"location": location,
		"class": cl_info.class,
		"tonnage": cl_info.tonnage,
	}
	pending_changes.append(change)

# --- Component Type Classification ---

func _classify_component(name: String) -> String:
	var def = DataManager.component_defs.get(name)
	var ct = def.get("component_type", "") if def else ""
	if ct:
		return ct
	return "other"

func _on_close() -> void:
	hide()
	closed.emit()

class RichTextHelper:
	var parts: Array[String] = []

	func add(text: String) -> void:
		parts.append(text)

	func get_text() -> String:
		return "\n".join(parts)
