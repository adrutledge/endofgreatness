class_name PersonnelManagement
extends Panel

signal closed()

var selected_personnel: Personnel = null

@onready var roster_list: ItemList = %RosterList
@onready var detail_name: Label = %DetailName
@onready var detail_role: Label = %DetailRole
@onready var detail_info: Label = %DetailInfo
@onready var hire_button: Button = %HireButton
@onready var fire_button: Button = %FireButton
@onready var promote_button: Button = %PromoteButton
@onready var close_button: Button = %CloseButton
@onready var hire_candidates: ItemList = %HireCandidates
@onready var hire_panel: Panel = %HirePanel

var _candidates: Array[Personnel] = []

func _ready() -> void:
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	add_theme_stylebox_override("panel", bg)

	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	detail_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	detail_role.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))

	close_button.pressed.connect(_on_close)
	hire_button.pressed.connect(_on_hire)
	fire_button.pressed.connect(_on_fire)
	promote_button.pressed.connect(_on_promote)
	roster_list.item_selected.connect(_on_roster_selected)

	populate_roster()

func populate_roster() -> void:
	roster_list.clear()
	for p in PersonnelManager.personnel_roster:
		var status = ""
		if p.is_injured:
			status = " [INJURED]"
		elif not p.is_available():
			status = " [ASSIGNED]"
		roster_list.add_item(p.personnel_name + " (" + Enums.PersonnelRole.keys()[p.role] + ")" + status)
	roster_list.deselect_all()
	_clear_details()

func _clear_details() -> void:
	selected_personnel = null
	detail_name.text = ""
	detail_role.text = ""
	detail_info.text = ""
	fire_button.disabled = true
	promote_button.disabled = true

func _on_roster_selected(index: int) -> void:
	if index < 0 or index >= PersonnelManager.personnel_roster.size():
		return
	selected_personnel = PersonnelManager.personnel_roster[index]
	var p = selected_personnel
	detail_name.text = p.personnel_name
	detail_role.text = Enums.PersonnelRole.keys()[p.role] + " — " + p.rank
	var info = "Body: " + str(p.body) + "  Mind: " + str(p.mind) + "  Reflexes: " + str(p.reflexes)
	info += "\nGunnery: " + str(p.skills.get("gunnery", "—")) + "  Piloting: " + str(p.skills.get("piloting", "—"))
	info += "\nExperience: " + str(p.experience) + " XP"
	info += "\nAssigned: " + (p.assigned_unit_id if not p.assigned_unit_id.is_empty() else "None")
	if p.is_injured:
		info += "\nInjured (severity " + str(p.injury_severity) + ")"
	detail_info.text = info
	fire_button.disabled = false
	promote_button.disabled = p.is_injured

func _on_hire() -> void:
	if hire_panel.visible:
		hire_panel.hide()
		return
	_candidates = PersonnelManager.generate_candidates("", {})
	hire_candidates.clear()
	for c in _candidates:
		hire_candidates.add_item(c.personnel_name + " (" + Enums.PersonnelRole.keys()[c.role] + ")")
	hire_candidates.deselect_all()
	hire_panel.show()

func _on_hire_candidate_selected(index: int) -> void:
	if index < 0 or index >= _candidates.size():
		return
	var cost = 5000
	if GameState.player.current_balance >= cost:
		GameState.player.current_balance -= cost
		PersonnelManager.hire_personnel(_candidates[index])
		_candidates.remove_at(index)
		hire_candidates.remove_item(index)
		populate_roster()
	else:
		detail_info.text = "Insufficient funds!"

func _on_fire() -> void:
	if selected_personnel:
		PersonnelManager.fire_personnel(selected_personnel)
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
	_on_roster_selected(roster_list.get_selected_items()[0] if roster_list.get_selected_items().size() > 0 else -1)

func _on_close() -> void:
	closed.emit()
