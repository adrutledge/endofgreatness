class_name OrganizationManagement
extends Panel

signal closed()
signal deploy_and_travel_requested(contract: Contract)

var selected_org_unit: OrganizationalUnit
var selected_op_unit: OperationalUnit
var selected_tactical_unit: TacticalUnit

enum SelectionType { NONE, STRATEGIC, ORGANIZATIONAL, OPERATIONAL, TACTICAL }
var selection_type: int = SelectionType.NONE

@onready var tree: Tree = %Tree
@onready var detail_name: Label = %DetailName
@onready var detail_info: Label = %DetailInfo
@onready var detail_type: Label = %DetailType
@onready var deploy_button: Button = %DeployButton
@onready var create_button: Button = %CreateButton
@onready var remove_button: Button = %RemoveButton
@onready var close_button: Button = %CloseButton
@onready var detail_panel: Panel = %DetailPanel

func _ready() -> void:
	Helpers.debug_print("OrgMgmt", "_ready start")
	Helpers.validate_nodes("OrgMgmt", [
		["tree", tree], ["detail_name", detail_name], ["detail_info", detail_info],
		["detail_type", detail_type], ["deploy_button", deploy_button],
		["create_button", create_button], ["remove_button", remove_button],
		["close_button", close_button], ["detail_panel", detail_panel],
	])
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	add_theme_stylebox_override("panel", bg_style)

	var detail_style = StyleBoxFlat.new()
	detail_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	detail_panel.add_theme_stylebox_override("panel", detail_style)

	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	%DetailName.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	%DetailType.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	close_button.pressed.connect(_on_close)
	deploy_button.pressed.connect(_on_deploy)
	create_button.pressed.connect(_on_create)
	remove_button.pressed.connect(_on_remove)
	tree.item_selected.connect(_on_tree_selected)
	populate_tree()
	Helpers.debug_print("OrgMgmt", "_ready done")

func populate_tree() -> void:
	Helpers.debug_print("OrgMgmt", "populate_tree — org_units=%d" % GameState.player.organizational_units.size())
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

func _opu_to_tree(parent_item: TreeItem, opu: OperationalUnit) -> void:
	var item = tree.create_item(parent_item)
	var label = opu.unit_name
	if opu.is_deployed:
		label += " [Deployed: " + opu.current_planet + "]"
	item.set_text(0, label)
	item.set_metadata(0, {"type": SelectionType.OPERATIONAL, "ref": opu})
	item.collapsed = false

	for tu in opu.tactical_units:
		var tu_item = tree.create_item(item)
		var unit_type_str = Enums.UnitType.keys()[tu.unit_type]
		tu_item.set_text(0, tu.unit_name + " (" + unit_type_str + ", " + str(tu.tonnage) + "t)")
		tu_item.set_metadata(0, {"type": SelectionType.TACTICAL, "ref": tu})

	for sub in opu.sub_units:
		_opu_to_tree(item, sub)

func _on_tree_selected() -> void:
	var item = tree.get_selected()
	if not item:
		return

	selection_type = -1
	selected_org_unit = null
	selected_op_unit = null
	selected_tactical_unit = null

	var meta = item.get_metadata(0)
	if typeof(meta) != TYPE_DICTIONARY:
		return

	selection_type = meta.get("type", SelectionType.NONE)
	_clear_details()

	match selection_type:
		SelectionType.STRATEGIC:
			detail_name.text = GameState.player.unit_name
			detail_type.text = tr("Strategic Unit (Player)")
			detail_info.text = tr("Organizational Units: ") + str(GameState.player.organizational_units.size()) + "\n" + tr("Balance: ") + Helpers.fmt_money(GameState.player.current_balance) + "\n" + tr("Location: ") + (GameState.player.current_planet if GameState.player.current_planet else tr("Unknown"))
			deploy_button.disabled = true
			remove_button.disabled = true
			create_button.disabled = false

		SelectionType.ORGANIZATIONAL:
			selected_org_unit = meta.get("ref")
			if not selected_org_unit:
				return
			detail_name.text = selected_org_unit.unit_name
			detail_type.text = tr("Organizational Unit")
			var counts = selected_org_unit.get_unit_counts_by_type()
			var info = "Sub-units: " + str(selected_org_unit.sub_units.size())
			info += "\nTactical units: " + str(selected_org_unit.get_all_tactical_units().size())
			for k in counts:
				info += "\n  " + k + ": " + str(counts[k])
			if selected_org_unit.commander:
				info += "\nCommander: " + selected_org_unit.commander.personnel_name
			if selected_org_unit.contract_id:
				info += "\nContract: " + selected_org_unit.contract_id
			detail_info.text = info
			deploy_button.disabled = false
			remove_button.disabled = false
			create_button.disabled = true

		SelectionType.OPERATIONAL:
			selected_op_unit = meta.get("ref")
			if not selected_op_unit:
				return
			detail_name.text = selected_op_unit.unit_name
			detail_type.text = tr("Operational Unit")
			var info = "Role: " + selected_op_unit.role
			info += "\nTactical units: " + str(selected_op_unit.tactical_units.size())
			info += "\nSub-units: " + str(selected_op_unit.sub_units.size())
			if selected_op_unit.commander:
				info += "\nCommander: " + selected_op_unit.commander.personnel_name
			if selected_op_unit.is_deployed:
				info += "\nDeployed on: " + selected_op_unit.current_planet
			else:
				info += "\nStatus: In reserve"
			detail_info.text = info
			deploy_button.disabled = true
			remove_button.disabled = false
			create_button.disabled = true

		SelectionType.TACTICAL:
			selected_tactical_unit = meta.get("ref")
			if not selected_tactical_unit:
				return
			detail_name.text = selected_tactical_unit.unit_name
			var unit_type_str = Enums.UnitType.keys()[selected_tactical_unit.unit_type]
			detail_type.text = unit_type_str + " (" + str(selected_tactical_unit.tonnage) + " tons)"
			var info = "Quality: " + str(selected_tactical_unit.quality)
			info += "\nComponents: " + str(selected_tactical_unit.components.size())
			info += "\nCrew: " + str(selected_tactical_unit.crew.size())
			info += "\nMovement MP: " + str(selected_tactical_unit.movement_mp)
			info += "\nDamaged components: " + str(selected_tactical_unit.get_damaged_components().size())
			detail_info.text = info
			deploy_button.disabled = true
			remove_button.disabled = true
			create_button.disabled = true

func _clear_details() -> void:
	detail_name.text = ""
	detail_info.text = ""
	detail_type.text = ""

func _on_deploy() -> void:
	Helpers.debug_print("OrgMgmt", "_on_deploy")
	if GameState.active_contracts.is_empty():
		detail_info.text = tr("No active contracts available for deployment.")
		return

	var contract: Contract
	if GameState.active_contracts.size() == 1:
		contract = GameState.active_contracts[0]
	else:
		contract = await _pick_contract()
	if contract == null:
		return

	var on_deployed := func(c: Contract):
		populate_tree()
		deploy_and_travel_requested.emit(c)

	OrganizationManager.show_deploy_dialog(self, contract, on_deployed)


func _pick_contract() -> Contract:
	var dialog := AcceptDialog.new()
	dialog.title = tr("Select Contract")
	dialog.min_size = Vector2i(400, 180)
	dialog.ok_button_text = tr("Select")
	dialog.dialog_text = ""

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = tr("Multiple active contracts found. Select one to deploy to:")
	vbox.add_child(label)
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for c in GameState.active_contracts:
		var text = "%s — %s on %s" % [c.issuer, c.activity_type, c.planet]
		selector.add_item(text)
		selector.set_item_metadata(selector.item_count - 1, c)
	vbox.add_child(selector)
	dialog.add_child(vbox)

	var result: Contract = null
	dialog.confirmed.connect(func():
		var idx = selector.selected
		if idx >= 0 and idx < GameState.active_contracts.size():
			result = GameState.active_contracts[idx]
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()
	await dialog.tree_exited
	return result

func _get_deployment_shortfalls(org_unit: OrganizationalUnit, contract: Contract) -> Dictionary:
	var have = org_unit.get_unit_counts_by_type()
	var need = contract.minimum_tactical_unit_counts
	var shortfalls: Dictionary = {}
	for type_str in need:
		var required: int = need[type_str]
		var available: int = have.get(type_str, 0)
		if available < required:
			shortfalls[type_str] = required - available
	return shortfalls

func _set_deployed_recursive(unit: OperationalUnit, contract: Contract) -> void:
	unit.contract_id = contract.resource_path
	unit.is_deployed = true
	unit.current_planet = contract.planet
	for sub in unit.sub_units:
		_set_deployed_recursive(sub, contract)

func _on_create() -> void:
	Helpers.debug_print("OrgMgmt", "_on_create")
	var dialog := AcceptDialog.new()
	dialog.title = tr("Create Organizational Unit")
	dialog.dialog_text = ""
	dialog.min_size = Vector2i(400, 160)

	var vbox := VBoxContainer.new()
	var label := Label.new()
	label.text = tr("Enter a name for the new Organizational Unit:")
	vbox.add_child(label)
	var line_edit := LineEdit.new()
	line_edit.placeholder_text = tr("Unit name")
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(line_edit)
	dialog.add_child(vbox)

	var name_result := ""
	dialog.confirmed.connect(func():
		name_result = line_edit.text
	)
	add_child(dialog)
	dialog.popup_centered()
	await dialog.confirmed

	dialog.queue_free()
	if name_result.is_empty():
		name_result = "New Unit " + str(GameState.player.organizational_units.size() + 1)
	var ou := OrganizationalUnit.new()
	ou.unit_name = name_result
	GameState.player.organizational_units.append(ou)
	populate_tree()

func _on_remove() -> void:
	Helpers.debug_print("OrgMgmt", "_on_remove selection_type=%d" % selection_type)
	match selection_type:
		SelectionType.ORGANIZATIONAL:
			if selected_org_unit:
				GameState.player.organizational_units.erase(selected_org_unit)
				_clear_details()
				populate_tree()
		SelectionType.OPERATIONAL:
			if selected_op_unit:
				for ou in GameState.player.organizational_units:
					if ou.sub_units.has(selected_op_unit):
						ou.sub_units.erase(selected_op_unit)
						_clear_details()
						populate_tree()
						return
					_remove_opu_recursive(ou, selected_op_unit)

func _remove_opu_recursive(parent: OrganizationalUnit, target: OperationalUnit) -> bool:
	for sub in parent.sub_units:
		if sub == target:
			parent.sub_units.erase(target)
			return true
		if _remove_opu_recursive_from_opu(sub, target):
			return true
	return false

func _remove_opu_recursive_from_opu(parent: OperationalUnit, target: OperationalUnit) -> bool:
	if parent.sub_units.has(target):
		parent.sub_units.erase(target)
		return true
	for sub in parent.sub_units:
		if _remove_opu_recursive_from_opu(sub, target):
			return true
	return false

func _on_close() -> void:
	hide()
	closed.emit()
