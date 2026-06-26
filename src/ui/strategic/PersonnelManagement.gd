class_name PersonnelManagement
extends Panel

signal closed()

var selected_personnel: Personnel = null
var selected_candidate: Personnel = null
var _candidates: Array[Personnel] = []
var _filtered_roster: Array[Personnel] = []
var _role_filter: int = -1
var _assign_targets: Array[TacticalUnit] = []

@onready var roster_list: ItemList = %RosterList
@onready var search_bar: LineEdit = %SearchBar
@onready var role_filter: OptionButton = %RoleFilter
@onready var detail_name: Label = %DetailName
@onready var detail_role: Label = %DetailRole
@onready var detail_info: Label = %DetailInfo
@onready var hire_button: Button = %HireButton
@onready var fire_button: Button = %FireButton
@onready var promote_button: Button = %PromoteButton
@onready var close_button: Button = %CloseButton
@onready var assign_button: Button = %AssignUnitButton
@onready var unassign_button: Button = %UnassignButton
@onready var hire_candidates: ItemList = %HireCandidates
@onready var hire_panel: Panel = %HirePanel
@onready var candidate_detail: Label = %CandidateDetail
@onready var hire_selected_button: Button = %HireSelectedButton

var xp_label: RichTextLabel
var xp_skill_list: VBoxContainer
var xp_btn_bar: HBoxContainer
var xp_apply_btn: Button
var xp_tab_container: VBoxContainer
var edu_label: RichTextLabel
var edu_upgrade_btn: Button
var edu_tab_container: VBoxContainer

func _ready() -> void:
	Helpers.debug_print("PersonnelManagement", "_ready start")
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	add_theme_stylebox_override("panel", bg)

	var vbox = $MarginContainer/VBox
	var title_ref = $MarginContainer/VBox/Title
	var tab_container = TabContainer.new()
	tab_container.name = "MainTabs"
	tab_container.size_flags_vertical = SIZE_EXPAND_FILL

	var personnel_tab = VBoxContainer.new()
	personnel_tab.name = "PersonnelTab"
	personnel_tab.size_flags_vertical = SIZE_EXPAND_FILL
	for c in vbox.get_children():
		vbox.remove_child(c)
		personnel_tab.add_child(c)
	vbox.add_child(tab_container)

	var medbay_tab = VBoxContainer.new()
	medbay_tab.name = "MedbayTab"
	medbay_tab.size_flags_vertical = SIZE_EXPAND_FILL
	tab_container.add_child(personnel_tab)
	tab_container.add_child(medbay_tab)

	var xp_tab = VBoxContainer.new()
	xp_tab.name = "XPTab"
	xp_tab.size_flags_vertical = SIZE_EXPAND_FILL
	tab_container.add_child(xp_tab)

	var edu_tab = VBoxContainer.new()
	edu_tab.name = "EducationTab"
	edu_tab.size_flags_vertical = SIZE_EXPAND_FILL
	tab_container.add_child(edu_tab)

	tab_container.set_tab_title(0, tr("Personnel"))
	tab_container.set_tab_title(1, tr("Medbay"))
	tab_container.set_tab_title(2, tr("XP Spending"))
	tab_container.set_tab_title(3, tr("Education"))

	_build_medbay_tab(medbay_tab)
	_build_xp_tab(xp_tab)
	_build_education_tab(edu_tab)

	title_ref.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	detail_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	detail_role.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	candidate_detail.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))

	Helpers.validate_nodes("PersonnelManagement", [
		["roster_list", roster_list], ["search_bar", search_bar], ["role_filter", role_filter],
		["detail_name", detail_name], ["detail_role", detail_role], ["detail_info", detail_info],
		["hire_button", hire_button], ["fire_button", fire_button], ["promote_button", promote_button],
		["close_button", close_button], ["assign_button", assign_button], ["unassign_button", unassign_button],
		["hire_candidates", hire_candidates], ["hire_panel", hire_panel], ["candidate_detail", candidate_detail],
		["hire_selected_button", hire_selected_button],
	])

	close_button.pressed.connect(_on_close)
	hire_button.pressed.connect(_on_hire)
	hire_selected_button.pressed.connect(_on_hire_selected)
	fire_button.pressed.connect(_on_fire)
	promote_button.pressed.connect(_on_promote)
	assign_button.pressed.connect(_on_assign)
	unassign_button.pressed.connect(_on_unassign)
	roster_list.item_selected.connect(_on_roster_selected)
	hire_candidates.item_selected.connect(_on_candidate_selected)
	search_bar.text_changed.connect(_on_search_changed)
	search_bar.text_submitted.connect(_on_search_changed)
	role_filter.item_selected.connect(_on_role_filter_changed)

	_populate_role_filter()
	populate_roster()
	if PersonnelManager.personnel_roster.size() > 0:
		roster_list.select(0)
		_on_roster_selected(0)

	Helpers.debug_print("PersonnelManagement", "_ready done")

func _populate_role_filter() -> void:
	role_filter.clear()
	role_filter.add_item(tr("All Roles"), -1)
	for i in Enums.PersonnelRole.size():
		role_filter.add_item(Enums.PersonnelRole.keys()[i], i)
	role_filter.select(0)

func populate_roster() -> void:
	var source = _filtered_roster if not _filtered_roster.is_empty() else PersonnelManager.personnel_roster
	Helpers.debug_print("PersonnelManagement", "populate_roster source_size=" + str(source.size()))
	roster_list.clear()
	for p in source:
		var status = ""
		if p.is_injured:
			status = " [INJURED]"
		elif not p.assigned_unit_id.is_empty():
			status = " [" + p.assigned_unit_id + "]"
		roster_list.add_item(p.personnel_name + " (" + Enums.PersonnelRole.keys()[p.role] + ")" + status)

func _update_filters() -> void:
	var query = search_bar.text.strip_edges()
	var role_idx = role_filter.selected
	var role_val = role_filter.get_item_id(role_idx)
	var all_personnel = PersonnelManager.personnel_roster

	if query.is_empty() and role_val == -1:
		_filtered_roster = []
	else:
		_filtered_roster = []
		for p in all_personnel:
			if role_val != -1 and p.role != role_val:
				continue
			if not query.is_empty() and not p.personnel_name.to_lower().contains(query.to_lower()):
				continue
			_filtered_roster.append(p)

	populate_roster()
	roster_list.deselect_all()
	if _filtered_roster.size() == 1:
		roster_list.select(0)
		_on_roster_selected(0)
	else:
		_clear_details()

func _on_search_changed(_new_text: String) -> void:
	_update_filters()

func _on_role_filter_changed(_index: int) -> void:
	_update_filters()

func _clear_details() -> void:
	selected_personnel = null
	detail_name.text = ""
	detail_role.text = ""
	detail_info.text = ""
	fire_button.disabled = true
	promote_button.disabled = true
	assign_button.disabled = true
	unassign_button.disabled = true

func _on_roster_selected(index: int) -> void:
	if index < 0 or index >= roster_list.get_item_count():
		return
	var source = _filtered_roster if not _filtered_roster.is_empty() else PersonnelManager.personnel_roster
	if index >= source.size():
		return
	selected_personnel = source[index]
	_update_detail_view(selected_personnel)
	_refresh_xp_view()
	_refresh_education_view()

func _update_detail_view(p: Personnel) -> void:
	detail_name.text = p.personnel_name
	detail_role.text = Enums.PersonnelRole.keys()[p.role] + " — " + p.rank

	var info = ""
	info += "Age: " + str(p.get_age()) + "  " + str(p.height_cm) + "cm  " + str(p.weight_kg) + "kg"
	info += "\n" + p.hair_color + " hair, " + p.eye_color + " eyes"
	if not p.affiliation.is_empty():
		info += "\nAffiliation: " + p.affiliation
	if not p.prior_affiliation.is_empty():
		info += "  (Prior: " + p.prior_affiliation + ")"
	info += "\nSalary: " + str(PersonnelManager.get_salary(p)) + " C-Bills/month"
	info += "\nEducation: " + Enums.EducationLevel.keys()[p.highest_education].replace("_", " ").capitalize()

	info += "\n\nAttributes:"
	info += "\n  BOD " + str(p.body) + "  DEX " + str(p.dexterity) + "  RFL " + str(p.reflexes)
	info += "  STR " + str(p.strength)
	info += "\n  WIL " + str(p.willpower) + "  CHA " + str(p.charisma) + "  INT " + str(p.intelligence) + "  EDG " + str(p.edge)

	if p.role == Enums.PersonnelRole.TECHNICIAN:
		info += "\nSpecialization: " + p.specialization
		var tech_skill = p.get_tech_skill()
		info += "\nSkill: " + p.get_tech_skill_label() + " (" + str(tech_skill) + ")"
		var repair_tn = p.get_repair_target_modifier()
		info += "\nRepair TN mod: " + ("+" if repair_tn > 0 else "") + str(repair_tn)
	else:
		if p.skills.get("gunnery_mech", 0) > 0:
			info += "\nGunnery/Mech: " + str(p.skills["gunnery_mech"])
			info += "  Effective: " + str(p.get_effective_gunnery())
		if p.skills.get("piloting_mech", 0) > 0:
			info += "\nPiloting/Mech: " + str(p.skills["piloting_mech"])
			info += "  Effective: " + str(p.get_effective_piloting())

	info += "\nExperience: " + str(p.experience) + " XP"
	info += "\nAssigned: " + (p.assigned_unit_id if not p.assigned_unit_id.is_empty() else "None")
	if p.is_injured:
		info += "\nInjured (severity " + str(p.injury_severity) + ")"
		info += "\nHealing: " + str(p.healing_days_remaining) + " days remaining"

	var non_zero_skills = _get_non_zero_skills(p)
	if not non_zero_skills.is_empty():
		info += "\n\nSkills:"
		for entry in non_zero_skills:
			var attrs = Enums.get_skill_attributes(entry[0])
			var attr_str = ""
			if not attrs.is_empty():
				attr_str = "  [" + attrs[0].left(3).capitalize()
				if attrs.size() > 1:
					attr_str += "/" + attrs[1].left(3).capitalize()
				attr_str += "]"
			info += "\n  " + entry[0] + ": " + str(entry[1]) + attr_str

	if not p.traits.is_empty():
		info += "\n\nTraits:"
		for t in p.traits:
			info += "\n  " + t.name + " — " + t.description

	if not p.description.is_empty():
		info += "\n\n" + p.description

	detail_info.text = info
	fire_button.disabled = false
	promote_button.disabled = p.is_injured
	assign_button.disabled = p.is_injured or p.role == Enums.PersonnelRole.CHILD or not p.assigned_unit_id.is_empty()
	unassign_button.disabled = p.assigned_unit_id.is_empty() or p.is_injured

func _get_non_zero_skills(p: Personnel) -> Array:
	var result: Array = []
	for skill in p.skills:
		var val = p.skills[skill]
		if val > 0 and not skill.begins_with("language_") and not skill.begins_with("protocol_"):
			result.append([skill, val])
	var lang_skills = []
	var proto_skills = []
	for skill in p.skills:
		var val = p.skills[skill]
		if val > 0 and skill.begins_with("language_"):
			lang_skills.append([skill.replace("language_", "").capitalize(), val])
		elif val > 0 and skill.begins_with("protocol_"):
			proto_skills.append([skill.replace("protocol_", "").to_upper(), val])
	if not lang_skills.is_empty():
		var parts = []
		for ls in lang_skills:
			parts.append(ls[0] + ": " + str(ls[1]))
		result.append(["language", parts.join(", ")])
	if not proto_skills.is_empty():
		var parts = []
		for ps in proto_skills:
			parts.append(ps[0] + ": " + str(ps[1]))
		result.append(["protocol", parts.join(", ")])
	result.sort_custom(func(a, b): return a[0] < b[0])
	return result

func _on_hire() -> void:
	if hire_panel.visible:
		hire_panel.hide()
		return
	_candidates = PersonnelManager.generate_candidates("", {})
	hire_candidates.clear()
	for c in _candidates:
		var label = c.personnel_name + " (" + Enums.PersonnelRole.keys()[c.role] + ")"
		if c.role == Enums.PersonnelRole.TECHNICIAN:
			label += " — " + c.specialization
		hire_candidates.add_item(label)
	hire_candidates.deselect_all()
	candidate_detail.text = ""
	hire_selected_button.disabled = true
	selected_candidate = null
	hire_panel.show()

func _on_candidate_selected(index: int) -> void:
	if index < 0 or index >= _candidates.size():
		return
	selected_candidate = _candidates[index]
	_update_candidate_detail(selected_candidate)
	hire_selected_button.disabled = false

func _update_candidate_detail(c: Personnel) -> void:
	var text = "Role: " + Enums.PersonnelRole.keys()[c.role]
	if c.role == Enums.PersonnelRole.TECHNICIAN:
		text += " (" + c.specialization + ")"
	text += "\nAge: " + str(c.get_age())
	text += "\nEducation: " + Enums.EducationLevel.keys()[c.highest_education].replace("_", " ").capitalize()
	text += "\nSalary: " + str(PersonnelManager.get_salary(c)) + " C-Bills/month"
	text += "\n\nAttributes: BOD " + str(c.body) + "  DEX " + str(c.dexterity) + "  RFL " + str(c.reflexes) + "  STR " + str(c.strength)
	text += "\n           WIL " + str(c.willpower) + "  CHA " + str(c.charisma) + "  INT " + str(c.intelligence) + "  EDG " + str(c.edge)

	var non_zero = _get_non_zero_skills(c)
	if not non_zero.is_empty():
		text += "\n\nKey Skills:"
		var count = 0
		for entry in non_zero:
			if count >= 6:
				text += "\n  (+ " + str(non_zero.size() - 6) + " more)"
				break
			text += "\n  " + entry[0] + ": " + str(entry[1])
			count += 1

	if not c.traits.is_empty():
		var names = []
		for t in c.traits:
			names.append(t.name)
		text += "\n\nTraits: " + ", ".join(names)

	text += "\n\nCost: 5,000 C-Bills (one-time)"
	candidate_detail.text = text

func _on_hire_selected() -> void:
	if not selected_candidate:
		return
	var cost = 5000
	if GameState.player.current_balance >= cost:
		GameState.player.current_balance -= cost
		PersonnelManager.hire_personnel(selected_candidate)
		_candidates.erase(selected_candidate)
		selected_candidate = null
		hire_candidates.clear()
		for c in _candidates:
			var label = c.personnel_name + " (" + Enums.PersonnelRole.keys()[c.role] + ")"
			if c.role == Enums.PersonnelRole.TECHNICIAN:
				label += " — " + c.specialization
			hire_candidates.add_item(label)
		hire_selected_button.disabled = true
		candidate_detail.text = ""
		populate_roster()
	else:
		candidate_detail.text = tr("Insufficient funds! Need 5,000 C-Bills.")

func _on_fire() -> void:
	if selected_personnel:
		PersonnelManager.remove_personnel(selected_personnel, "fired", {})
		_clear_details()
		populate_roster()

func _on_promote() -> void:
	if not selected_personnel:
		return
	var ranks = ["Private", "Corporal", "Sergeant", "Lieutenant", "Captain", "Major", "Colonel"]
	var idx = ranks.find(selected_personnel.rank)
	if idx < ranks.size() - 1:
		PersonnelManager.promote_personnel(selected_personnel, ranks[idx + 1])
	else:
		PersonnelManager.promote_personnel(selected_personnel, ranks[idx])
	populate_roster()
	var sel = roster_list.get_selected_items()
	if sel.size() > 0:
		_on_roster_selected(sel[0])

func _on_assign() -> void:
	if not selected_personnel:
		return
	_assign_targets = PersonnelManager.get_all_tactical_units()
	if _assign_targets.is_empty():
		detail_info.text = tr("No tactical units available. Create units in Organization Management first.")
		return

	var valid_units: Array[TacticalUnit] = []
	for u in _assign_targets:
		if selected_personnel.role == Enums.PersonnelRole.TECHNICIAN:
			if not selected_personnel.matches_specialization(u.unit_type):
				continue
		if not u.requires_technician() and selected_personnel.role == Enums.PersonnelRole.TECHNICIAN:
			continue
		valid_units.append(u)

	if valid_units.is_empty():
		detail_info.text = tr("No suitable units available for this personnel.")
		return

	var dialog = AcceptDialog.new()
	dialog.title = tr("Assign ") + selected_personnel.personnel_name
	dialog.min_size = Vector2i(400, 300)

	var unit_list = ItemList.new()
	for u in valid_units:
		var type_str = Enums.UnitType.keys()[u.unit_type]
		var crew_str = " (crew: " + str(u.crew.size()) + ")"
		unit_list.add_item(u.unit_name + " [" + type_str + ", " + str(u.tonnage) + "t]" + crew_str)

	unit_list.select_mode = 0
	unit_list.size_flags_vertical = 3
	unit_list.size_flags_horizontal = 3
	dialog.add_child(unit_list)

	var confirm = func():
		var sel = unit_list.get_selected_items()
		if sel.size() > 0:
			var target = valid_units[sel[0]]
			if PersonnelManager.assign_personnel_to_unit(selected_personnel, target):
				detail_info.text = selected_personnel.personnel_name + " assigned to " + target.unit_name
				populate_roster()
				_update_detail_view(selected_personnel)
			else:
				detail_info.text = tr("Failed to assign ") + selected_personnel.personnel_name

	dialog.confirmed.connect(confirm)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _on_unassign() -> void:
	if not selected_personnel or selected_personnel.assigned_unit_id.is_empty():
		return
	var target_unit: TacticalUnit = null
	for u in PersonnelManager.get_all_tactical_units():
		if u.unit_name == selected_personnel.assigned_unit_id:
			target_unit = u
			break
	if target_unit:
		PersonnelManager.unassign_personnel_from_unit(selected_personnel, target_unit)
		detail_info.text = selected_personnel.personnel_name + " unassigned from " + target_unit.unit_name
	else:
		selected_personnel.assigned_unit_id = ""
	populate_roster()
	_update_detail_view(selected_personnel)

func _build_medbay_tab(tab: VBoxContainer) -> void:
	var header := Label.new()
	header.text = tr("Medbay")
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	tab.add_child(header)

	var injured_list := ItemList.new()
	injured_list.name = "MedbayList"
	injured_list.size_flags_vertical = SIZE_EXPAND_FILL
	injured_list.add_theme_color_override("font_color", Color(1, 1, 1))
	tab.add_child(injured_list)

	var refresh := func():
		injured_list.clear()
		for p in PersonnelManager.personnel_roster:
			if p.is_injured:
				var days = p.healing_days_remaining
				injured_list.add_item("%s — %s (severity %d, %d days)" % [p.personnel_name, Enums.PersonnelRole.keys()[p.role], p.injury_severity, days])

	refresh.call()
	EventBus.month_started.connect(func(d): refresh.call())


func _build_xp_tab(tab: VBoxContainer) -> void:
	xp_tab_container = tab

	var header := Label.new()
	header.text = tr("Experience Spending")
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	tab.add_child(header)

	xp_label = RichTextLabel.new()
	xp_label.bbcode_enabled = true
	xp_label.fit_content = true
	xp_label.size_flags_vertical = SIZE_EXPAND_FILL
	tab.add_child(xp_label)

	var sep = HSeparator.new()
	tab.add_child(sep)

	var skill_header := Label.new()
	skill_header.text = tr("Skills (click + to spend XP)")
	skill_header.add_theme_font_size_override("font_size", 12)
	tab.add_child(skill_header)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	tab.add_child(scroll)

	xp_skill_list = VBoxContainer.new()
	xp_skill_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(xp_skill_list)

	xp_btn_bar = HBoxContainer.new()
	xp_btn_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tab.add_child(xp_btn_bar)

	xp_apply_btn = Button.new()
	xp_apply_btn.text = tr("Apply Changes")
	xp_apply_btn.disabled = true
	xp_apply_btn.pressed.connect(_on_xp_apply)
	xp_btn_bar.add_child(xp_apply_btn)


var _xp_changes: Dictionary = {}

func _refresh_xp_view() -> void:
	if not selected_personnel:
		xp_label.text = tr("Select a personnel to view XP")
		return

	var p = selected_personnel
	xp_label.text = "[b]%s[/b]\nExperience: [color=#44ff66]%d XP[/color]\n\nSelect skills below to spend XP on improvement." % [p.personnel_name, p.experience]

	for c in xp_skill_list.get_children():
		c.queue_free()

	_xp_changes.clear()
	xp_apply_btn.disabled = true

	var skills = _get_non_zero_skills(p)
	if skills.is_empty():
		var lbl = Label.new()
		lbl.text = tr("  No skills to improve")
		xp_skill_list.add_child(lbl)
		return

	for entry in skills:
		var skill_name = entry[0]
		var skill_val = entry[1]
		if skill_val >= 10:
			continue

		var hb = HBoxContainer.new()
		hb.size_flags_horizontal = SIZE_EXPAND_FILL

		var lbl = Label.new()
		var cost = (skill_val + 1) * 100
		lbl.text = "  %s: %d  (next: %d XP)" % [skill_name, skill_val, cost]
		lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		hb.add_child(lbl)

		var plus_btn = Button.new()
		plus_btn.text = "+"
		var sn = skill_name
		plus_btn.pressed.connect(func():
			_xp_changes[sn] = _xp_changes.get(sn, 0) + 1
			xp_apply_btn.disabled = false
			_refresh_xp_changes_display()
		)
		hb.add_child(plus_btn)

		xp_skill_list.add_child(hb)


func _refresh_xp_changes_display() -> void:
	var total_cost := 0
	var parts: Array[String] = []
	parts.push_back("[b]Pending XP Spending:[/b]")
	for sn in _xp_changes:
		var count = _xp_changes[sn]
		var current_val = selected_personnel.skills.get(sn, 0)
		var cost := 0
		for i in range(count):
			cost += (current_val + i + 1) * 100
		total_cost += cost
		parts.push_back("  %s: +%d levels (%d XP)" % [sn, count, cost])
	parts.push_back("")
	parts.push_back("[color=#ffaa44]Total cost: %d XP (available: %d XP)[/color]" % [total_cost, selected_personnel.experience])
	if total_cost > selected_personnel.experience:
		parts.push_back("[color=#ff4444]Not enough XP![/color]")
		xp_apply_btn.disabled = true
	else:
		xp_apply_btn.disabled = false
	xp_label.text = "[b]%s[/b]\nExperience: [color=#44ff66]%d XP[/color]\n\n" % [selected_personnel.personnel_name, selected_personnel.experience] + "\n".join(parts)


func _on_xp_apply() -> void:
	if not selected_personnel or _xp_changes.is_empty():
		return
	var p = selected_personnel
	var total_cost := 0
	for sn in _xp_changes:
		var count = _xp_changes[sn]
		var current_val = p.skills.get(sn, 0)
		for i in range(count):
			total_cost += (current_val + i + 1) * 100
		p.skills[sn] = current_val + count
	if total_cost <= p.experience:
		p.experience -= total_cost
		_xp_changes.clear()
		xp_apply_btn.disabled = true
		_refresh_xp_view()
		_update_detail_view(p)


func _build_education_tab(tab: VBoxContainer) -> void:
	edu_tab_container = tab

	var header := Label.new()
	header.text = tr("Education")
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	tab.add_child(header)

	edu_label = RichTextLabel.new()
	edu_label.bbcode_enabled = true
	edu_label.fit_content = true
	edu_label.size_flags_vertical = SIZE_EXPAND_FILL
	tab.add_child(edu_label)

	var btn_bar = HBoxContainer.new()
	btn_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tab.add_child(btn_bar)

	edu_upgrade_btn = Button.new()
	edu_upgrade_btn.text = tr("Advance Education")
	edu_upgrade_btn.pressed.connect(_on_edu_upgrade)
	btn_bar.add_child(edu_upgrade_btn)


func _refresh_education_view() -> void:
	if not selected_personnel:
		edu_label.text = tr("Select a personnel to view education")
		edu_upgrade_btn.disabled = true
		return

	var p = selected_personnel
	var edu_names = Enums.EducationLevel.keys()
	var current_idx = p.highest_education
	var current_name = edu_names[current_idx].replace("_", " ").capitalize()
	var next_name = edu_names[current_idx + 1].replace("_", " ").capitalize() if current_idx + 1 < edu_names.size() else "MAX"

	var text = "[b]" + p.personnel_name + "[/b]\n"
	text += "Current Education: " + current_name + "\n"
	if current_idx + 1 < edu_names.size():
		text += "Next Level: " + next_name + "\n"
		text += "Cost: 1000 XP + 5000 C-Bills"
		edu_upgrade_btn.disabled = false
	else:
		text += "Maximum education level reached."
		edu_upgrade_btn.disabled = true
	edu_label.text = text


func _on_edu_upgrade() -> void:
	if not selected_personnel:
		return
	var p = selected_personnel
	var edu_names = Enums.EducationLevel.keys()
	var current_idx = p.highest_education
	if current_idx + 1 >= edu_names.size():
		return
	if p.experience < 1000:
		edu_label.text = tr("Not enough XP! Need 1000 XP.")
		return
	if GameState.player.current_balance < 5000:
		edu_label.text = tr("Not enough C-Bills! Need 5000 C-Bills.")
		return
	p.experience -= 1000
	GameState.player.current_balance -= 5000
	p.highest_education = current_idx + 1
	_refresh_education_view()
	_update_detail_view(p)


func _on_close() -> void:
	closed.emit()
