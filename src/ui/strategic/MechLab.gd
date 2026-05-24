class_name MechLab
extends Panel

signal closed()

var player_mechs: Array[TacticalUnit] = []
var selected_unit: TacticalUnit
var selected_variant: TacticalUnit
var variants: Array[TacticalUnit] = []
var current_parts_plan: Array[Dictionary] = []

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
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	add_theme_stylebox_override("panel", bg_style)

	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	close_button.pressed.connect(_on_close)
	unit_list.item_selected.connect(_on_unit_selected)
	variant_list.item_selected.connect(_on_variant_selected)
	start_refit_button.pressed.connect(_on_start_refit)

func populate() -> void:
	player_mechs.clear()
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
	_update_status()

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
		ph.add("  " + entry.component_name + "  —  " + _fmt_money(entry.cost_per_unit) + "  (" + src + ")")
		total_cost += entry.cost_per_unit
		if entry.source == "remote":
			max_delivery = max(max_delivery, entry.get("travel_days", 0))
	parts_info.text = ph.get_text()

	var hours = RefitManager.calculate_refit_hours(diff)
	var clas_info = RefitManager.classify_refit(diff)
	var clas_name = RefitManager.get_refit_class_name(clas_info.overall_class)
	var clas_hours = RefitManager.CLASS_HOURS[clas_info.overall_class]
	cost_label.text = "Total parts cost: " + _fmt_money(total_cost) + "  |  Refit Class: " + clas_name
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

func _update_status() -> void:
	var n = RefitManager.active_refits.size()
	status_label.text = ("Active refits: " + str(n)) if n > 0 else ""

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


class RichTextHelper:
	var parts: Array[String] = []

	func add(text: String) -> void:
		parts.append(text)

	func get_text() -> String:
		return "\n".join(parts)
