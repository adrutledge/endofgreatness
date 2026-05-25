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

	Helpers.validate_nodes("MechLab", {
		unit_list = unit_list, variant_list = variant_list, current_info = current_info,
		variant_info = variant_info, diff_info = diff_info, parts_info = parts_info,
		cost_label = cost_label, hours_label = hours_label, start_refit_button = start_refit_button,
		status_label = status_label, close_button = close_button
	})

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
	if tab_index == 1 and selected_unit:
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
	_update_status()

func _on_unit_selected(index: int) -> void:
	if index < 0 or index >= player_mechs.size():
		return
	selected_unit = player_mechs[index]

	var chassis = selected_unit.chassis_name
	variants = DataManager.get_variants_for_chassis(chassis)

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
	for v in variants:
		var label = v.unit_name
		if v.model_name == selected_unit.model_name:
			label += " (current)"
		variant_list.add_item(label)

	variant_info.text = ""
	diff_info.text = ""
	parts_info.text = ""
	cost_label.text = ""
	hours_label.text = ""
	start_refit_button.disabled = true
	pending_changes.clear()
	_update_status()

	if tab_container and tab_container.current_tab == 1:
		_show_customize_view()

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

	current_parts_plan = RefitManager.source_parts(diff)
	var ph = RichTextHelper.new()
	ph.add("[b]Parts Sourcing Plan:[/b]")
	var total_cost = 0
	var max_delivery = 0
	for entry in current_parts_plan:
		var src = "Local" if entry.source == "local" else "Remote (" + entry.get("source_system", "?") + ", " + str(entry.get("travel_days", 0)) + "d)"
		ph.add("  " + entry.component_name + "  —  " + Helpers.fmt_money(entry.cost_per_unit) + "  (" + src + ")")
		total_cost += entry.cost_per_unit
		if entry.source == "remote":
			max_delivery = max(max_delivery, entry.get("travel_days", 0))
	parts_info.text = ph.get_text()

	var hours = RefitManager.calculate_refit_hours(diff)
	var clas_info = RefitManager.classify_refit(diff)
	var clas_name = RefitManager.get_refit_class_name(clas_info.overall_class)
	var clas_hours = RefitManager.CLASS_HOURS[clas_info.overall_class]
	cost_label.text = "Total parts cost: " + Helpers.fmt_money(total_cost) + "  |  Refit Class: " + clas_name
	diff_info.text += "\n\n[b]Refit Class: " + clas_name + "[/b] (" + str(clas_hours) + " hrs/ton per component)"
	hours_label.text = "Labor: " + str(hours) + " technician-hours" + (" | Parts delivery: " + str(max_delivery) + " days" if max_delivery > 0 else " | All parts available locally")
	start_refit_button.disabled = false
	_update_status()

func _on_start_refit() -> void:
	if not selected_unit or not selected_variant or current_parts_plan.is_empty():
		return
	if selected_variant.model_name == selected_unit.model_name:
		status_label.text = "Already the current variant"
		return

	var active = RefitManager.get_unit_refit(selected_unit)
	if active:
		status_label.text = "Unit already has an active refit"
		return

	var result = RefitManager.start_refit(selected_unit, selected_variant, current_parts_plan)
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
	rh.add("[b]Average Target Number:[/b] " + str(_estimate_avg_tn()))
	rh.add("[b]Tech Skill:[/b] " + str(tech_skill) + "  |  [b]Threshold:[/b] " + str(threshold) + "  |  [b]Facility:[/b] Lvl " + str(facility_lvl))
	var avg_tn = _estimate_avg_tn()
	if avg_tn > threshold:
		rh.add("[color=#ff4444]Average TN exceeds threshold — high risk of failure and extended labor[/color]")
	else:
		rh.add("[color=#44ff66]Average TN within threshold — manageable risk[/color]")
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

func _estimate_avg_tn() -> int:
	if pending_changes.is_empty():
		return 0
	var total := 0
	for ch in pending_changes:
		total += RefitManager.calculate_customization_tn(ch, 2, RefitManager.get_facility_level(), 2, true)
	return int(ceil(float(total) / pending_changes.size()))


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

func _on_close() -> void:
	hide()
	closed.emit()

class RichTextHelper:
	var parts: Array[String] = []

	func add(text: String) -> void:
		parts.append(text)

	func get_text() -> String:
		return "\n".join(parts)
