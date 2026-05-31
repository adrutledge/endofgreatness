class_name UnitRoster
extends Panel

signal closed()

enum SelectionType { NONE, STRATEGIC, ORGANIZATIONAL, OPERATIONAL, TACTICAL }

var selection_type: int = SelectionType.NONE
var selected_org_unit: OrganizationalUnit
var selected_op_unit: OperationalUnit
var selected_tactical_unit: TacticalUnit

@onready var tree: Tree = %Tree
@onready var detail_title: Label = %DetailTitle
@onready var detail_info: Label = %DetailInfo
@onready var detail_list: RichTextLabel = %DetailList
@onready var repair_section: VBoxContainer = %RepairSection
@onready var repair_label: RichTextLabel = %RepairLabel
@onready var assign_tech_button: Button = %AssignTechButton
@onready var unassign_tech_button: Button = %UnassignTechButton
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	Helpers.debug_print("UnitRoster", "_ready start")
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	add_theme_stylebox_override("panel", bg_style)

	var detail_style = StyleBoxFlat.new()
	detail_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	%DetailPanel.add_theme_stylebox_override("panel", detail_style)

	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	detail_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

	Helpers.validate_nodes("UnitRoster", [
		["tree", tree], ["detail_title", detail_title], ["detail_info", detail_info],
		["detail_list", detail_list], ["repair_section", repair_section], ["repair_label", repair_label],
		["assign_tech_button", assign_tech_button], ["unassign_tech_button", unassign_tech_button],
		["close_button", close_button],
	])

	close_button.pressed.connect(_on_close)
	tree.item_selected.connect(_on_tree_selected)
	assign_tech_button.pressed.connect(_on_assign_tech)
	unassign_tech_button.pressed.connect(_on_unassign_tech)

	Helpers.debug_print("UnitRoster", "_ready done")

func populate_tree() -> void:
	Helpers.debug_print("UnitRoster", "populate_tree org_units=" + str(GameState.player.organizational_units.size()))
	tree.clear()
	var root = tree.create_item()
	root.set_text(0, GameState.player.unit_name)
	root.set_metadata(0, {"type": SelectionType.STRATEGIC})

	for ou in GameState.player.organizational_units:
		var ou_item = tree.create_item(root)
		ou_item.set_text(0, ou.unit_name)
		ou_item.set_metadata(0, {"type": SelectionType.ORGANIZATIONAL, "ref": ou})
		ou_item.collapsed = false

		for opu in ou.sub_units:
			_opu_to_tree(ou_item, opu)

	tree.ensure_cursor_is_visible()
	_clear_details()
	repair_section.hide()

func _opu_to_tree(parent_item: TreeItem, opu: OperationalUnit) -> void:
	var item = tree.create_item(parent_item)
	var label = opu.unit_name
	if opu.is_deployed:
		label += " [Deployed]"
	item.set_text(0, label)
	item.set_metadata(0, {"type": SelectionType.OPERATIONAL, "ref": opu})
	item.collapsed = false

	for tu in opu.tactical_units:
		var tu_item = tree.create_item(item)
		var unit_type_str = Enums.UnitType.keys()[tu.unit_type]
		var status = ""
		var damaged = tu.get_damaged_components().size()
		if damaged > 0:
			status = " [Dmg: " + str(damaged) + "]"
		tu_item.set_text(0, tu.unit_name + " (" + unit_type_str + ", " + str(tu.tonnage) + "t)" + status)
		tu_item.set_metadata(0, {"type": SelectionType.TACTICAL, "ref": tu})

	for sub in opu.sub_units:
		_opu_to_tree(item, sub)

func _on_tree_selected() -> void:
	var item = tree.get_selected()
	if not item:
		return

	selection_type = SelectionType.NONE
	selected_org_unit = null
	selected_op_unit = null
	selected_tactical_unit = null
	repair_section.hide()

	var meta = item.get_metadata(0)
	if typeof(meta) != TYPE_DICTIONARY:
		return

	selection_type = meta.get("type", SelectionType.NONE)
	_clear_details()

	match selection_type:
		SelectionType.STRATEGIC:
			detail_title.text = GameState.player.unit_name
			detail_info.text = tr("Command Unit")
			var total_tus = 0
			for ou in GameState.player.organizational_units:
				total_tus += ou.get_all_tactical_units().size()
			var lines = []
			lines.append("Organizational Units: " + str(GameState.player.organizational_units.size()))
			lines.append("Total Tactical Units: " + str(total_tus))
			lines.append(tr("Balance: ") + Helpers.fmt_money(GameState.player.current_balance))
			lines.append("Location: " + (GameState.player.current_planet if GameState.player.current_planet else "Unknown"))
			_detail_set_text("\n".join(lines))

		SelectionType.ORGANIZATIONAL:
			selected_org_unit = meta.get("ref")
			if not selected_org_unit:
				return
			detail_title.text = selected_org_unit.unit_name
			detail_info.text = tr("Organizational Unit")
			var counts = selected_org_unit.get_unit_counts_by_type()
			var lines = []
			lines.append("Sub-units: " + str(selected_org_unit.sub_units.size()))
			var all_tus = selected_org_unit.get_all_tactical_units()
			lines.append("Tactical Units: " + str(all_tus.size()))
			for k in counts:
				lines.append("  " + k + ": " + str(counts[k]))
			if selected_org_unit.commander:
				lines.append("Commander: " + selected_org_unit.commander.personnel_name)
			if selected_org_unit.contract_id:
				lines.append("Contract: " + selected_org_unit.contract_id)
			_detail_set_text("\n".join(lines))

		SelectionType.OPERATIONAL:
			selected_op_unit = meta.get("ref")
			if not selected_op_unit:
				return
			detail_title.text = selected_op_unit.unit_name
			detail_info.text = tr("Operational Unit")
			var lines = []
			lines.append("Role: " + selected_op_unit.role)
			lines.append("Tactical Units: " + str(selected_op_unit.tactical_units.size()))
			lines.append("Sub-units: " + str(selected_op_unit.sub_units.size()))
			if selected_op_unit.commander:
				lines.append("Commander: " + selected_op_unit.commander.personnel_name)
			if selected_op_unit.is_deployed:
				lines.append("Deployed on: " + selected_op_unit.current_planet)
			else:
				lines.append("Status: In reserve")
			_detail_set_text("\n".join(lines))

		SelectionType.TACTICAL:
			selected_tactical_unit = meta.get("ref")
			if not selected_tactical_unit:
				return
			_show_tactical_detail()

func _show_tactical_detail() -> void:
	var tu = selected_tactical_unit
	var unit_type_str = Enums.UnitType.keys()[tu.unit_type]
	detail_title.text = tu.unit_name
	detail_info.text = unit_type_str + " (" + str(tu.tonnage) + " tons)"

	var damaged = tu.get_damaged_components()
	var destroyed = tu.get_destroyed_components()
	var undamaged_count = tu.components.size() - damaged.size()
	var lines = RichTextHelper.new()
	lines.add("Quality: " + str(tu.quality))
	lines.add("Movement MP: " + str(tu.movement_mp) + " / Run: " + str(tu.run_mp) + " / Jump: " + str(tu.jump_mp))
	lines.add("")
	lines.add("[b]Components (Total: " + str(tu.components.size()) + ")[/b]")
	for c in tu.components:
		var status_mark = ""
		var color = ""
		match c.status:
			Enums.ComponentStatus.DESTROYED:
				status_mark = " [DESTROYED]"
				color = "[color=#ff4444]"
			Enums.ComponentStatus.DAMAGED:
				status_mark = " [Damaged]"
				color = "[color=#ffaa44]"
			_:
				color = "[color=#88cc88]"
		lines.add("  " + color + c.component_name + "[/color]" + status_mark)
	lines.add("")
	lines.add("[b]Crew (" + str(tu.crew.size()) + ")[/b]")
	for p in tu.crew:
		var gunnery = p.skills.get("gunnery", "N/A")
		var piloting = p.skills.get("piloting", "N/A")
		lines.add("  " + p.personnel_name + " (Gun: " + str(gunnery) + "/Pil: " + str(piloting) + ")")
	_detail_set_text(lines.get_text())

	repair_section.show()
	var tech_lines = RichTextHelper.new()
	tech_lines.add("[b]Repair Bay[/b]")
	tech_lines.add("Damaged components: " + str(damaged.size()))
	tech_lines.add("Destroyed components: " + str(destroyed.size()))
	tech_lines.add("Repair budget: " + str(PersonnelManager.get_unit_repair_budget(tu)) + " hours/day")
	tech_lines.add("")
	tech_lines.add("[b]Assigned Technicians:[/b]")
	if tu.assigned_technicians.is_empty():
		tech_lines.add("  None")
	else:
		for t in tu.assigned_technicians:
			tech_lines.add("  " + t.personnel_name + " (" + t.specialization + ")")
	repair_label.text = tech_lines.get_text()
	unassign_tech_button.disabled = tu.assigned_technicians.is_empty()

func _on_assign_tech() -> void:
	if not selected_tactical_unit:
		return
	var available: Array[Personnel] = []
	for p in PersonnelManager.personnel_roster:
		if p.role == Enums.PersonnelRole.TECHNICIAN and p.is_available() and p.matches_specialization(selected_tactical_unit.unit_type):
			if not selected_tactical_unit.assigned_technicians.has(p):
				available.append(p)

	if available.is_empty():
		repair_label.text = tr("No available technicians with matching specialization")
		return

	var dialog = AcceptDialog.new()
	dialog.title = tr("Assign Technician")
	dialog.size = Vector2i(500, 400)

	var vbox = VBoxContainer.new()
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = 3
	scroll.scroll_vertical_enabled = true

	var list = VBoxContainer.new()
	list.size_flags_horizontal = 4
	for p in available:
		var btn = Button.new()
		btn.text = p.personnel_name + " — " + p.specialization + " (Skill: " + str(p.skills.get("tech_" + p.specialization.to_lower(), 0)) + ")"
		btn.size_flags_horizontal = 4
		var tech_ref = p
		btn.pressed.connect(func():
			PersonnelManager.assign_technician(tech_ref, selected_tactical_unit)
			dialog.queue_free()
			_show_tactical_detail()
		)
		list.add_child(btn)

	scroll.add_child(list)
	vbox.add_child(scroll)
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()

func _on_unassign_tech() -> void:
	if not selected_tactical_unit or selected_tactical_unit.assigned_technicians.is_empty():
		return
	var dialog = AcceptDialog.new()
	dialog.title = tr("Unassign Technician")
	dialog.size = Vector2i(400, 300)

	var vbox = VBoxContainer.new()
	var list = VBoxContainer.new()
	for t in selected_tactical_unit.assigned_technicians:
		var btn = Button.new()
		btn.text = t.personnel_name + " (" + t.specialization + ")"
		btn.size_flags_horizontal = 4
		var tech_ref = t
		btn.pressed.connect(func():
			PersonnelManager.unassign_technician(tech_ref, selected_tactical_unit)
			dialog.queue_free()
			_show_tactical_detail()
		)
		list.add_child(btn)

	vbox.add_child(list)
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()

func _clear_details() -> void:
	detail_title.text = ""
	detail_info.text = ""
	detail_list.text = ""

func _detail_set_text(text: String) -> void:
	detail_list.text = text

func _on_close() -> void:
	hide()
	closed.emit()


class RichTextHelper:
	var parts: Array[String] = []

	func add(text: String) -> void:
		parts.append(text)

	func get_text() -> String:
		return "\n".join(parts)
