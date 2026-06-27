extends Control

## Reusable paper doll component for mech/vehicle unit display.
## Shows all locations with slot contents. Emits signals for
## slot interaction (select, remove, place).
##
## Embed in any UI that needs a paper doll. Connect to its signals
## rather than reading slot state directly.

signal slot_selected(location: String, slot_index: int, component_name: String)
signal slot_cleared(location: String, slot_index: int)
signal component_dropped(component_name: String, from_location: String, from_slot: int, to_location: String, to_slot: int)

var unit: TacticalUnit
var mode: String = "view"  # "view" | "remove" | "place"
var show_empty_slots: bool = true

var _slot_buttons: Dictionary = {}  # "loc,idx" -> Button
var _location_columns: Dictionary = {}  # loc -> VBoxContainer


func _ready() -> void:
	_build_layout()


func _build_layout() -> void:
	# Layout configuration per unit type
	var layout = _get_layout()
	for entry in layout:
		var loc_name = entry.location
		var slot_count = entry.slots
		var col = _make_location_column(loc_name, slot_count)
		_location_columns[loc_name] = col

	# Override: use scene children if they exist
	# (the .tscn provides the skeleton; this code populates slots)
	for child in get_children():
		if child is VBoxContainer and child.name.begins_with("Loc_"):
			_location_columns[child.name.trim_prefix("Loc_")] = child


func _get_layout() -> Array:
	match unit.unit_type if unit else Enums.UnitType.MECH:
		Enums.UnitType.MECH:
			return [
				{"location": "Head", "slots": 6},
				{"location": "Center Torso", "slots": 12},
				{"location": "Left Torso", "slots": 12},
				{"location": "Right Torso", "slots": 12},
				{"location": "Left Arm", "slots": 12},
				{"location": "Right Arm", "slots": 12},
				{"location": "Left Leg", "slots": 6},
				{"location": "Right Leg", "slots": 6},
			]
		_:
			return []


func load_unit(new_unit: TacticalUnit) -> void:
	unit = new_unit
	refresh()


func refresh() -> void:
	if not unit:
		return
	var components_by_loc: Dictionary = {}
	for c in unit.components:
		var loc = c.location.location_name if c.location else "Unknown"
		if not components_by_loc.has(loc):
			components_by_loc[loc] = []
		components_by_loc[loc].append(c)

	for loc_name in _location_columns:
		var col = _location_columns[loc_name]
		var comps: Array = components_by_loc.get(loc_name, [])
		var slot_idx = 0
		# Update existing slot buttons or leave empty
		for child in col.get_children():
			if child is Button and child.name.begins_with("Slot_"):
				if slot_idx < comps.size():
					var c = comps[slot_idx]
					_set_slot(child, c.component_name, c.status)
				else:
					_set_slot(child, "")
				slot_idx += 1


func set_mode(new_mode: String) -> void:
	mode = new_mode


func set_show_empty(show: bool) -> void:
	show_empty_slots = show


func _make_location_column(loc_name: String, slot_count: int) -> VBoxContainer:
	var col = VBoxContainer.new()
	col.name = "Loc_" + loc_name.replace(" ", "_")
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)

	var lbl = Label.new()
	lbl.text = loc_name + " (" + str(slot_count) + ")"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lbl)

	for i in range(slot_count):
		var btn = _make_slot_button(loc_name, i)
		col.add_child(btn)

	return col


func _make_slot_button(location: String, slot_index: int) -> Button:
	var btn = Button.new()
	btn.name = "Slot_%d" % slot_index
	btn.text = tr("Empty")
	btn.custom_minimum_size = Vector2(110, 22)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 10)

	var style = StyleBoxFlat.new()
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
	btn.pressed.connect(func(): _on_slot_pressed(loc_copy, idx_copy, btn.text))

	var key = "%s,%d" % [location, slot_index]
	_slot_buttons[key] = btn

	return btn


func _set_slot(btn: Button, component_name: String, status: int = 0) -> void:
	if component_name.is_empty():
		btn.text = tr("Empty")
		var style = btn.get_theme_stylebox("normal")
		if style:
			style.bg_color = Color(0.08, 0.08, 0.08)
		btn.disabled = mode == "view"
		return

	btn.text = component_name
	var style = btn.get_theme_stylebox("normal")
	if style:
		style.bg_color = _component_type_color(component_name)
	if status == 1:  # DAMAGED
		btn.text = "⚠ " + component_name
	elif status == 2:  # DESTROYED
		btn.text = "✗ " + component_name

	btn.disabled = mode == "view"


func _component_type_color(comp_name: String) -> Color:
	var lower = comp_name.to_lower()
	if "life support" in lower or "cockpit" in lower:
		return Color(0.6, 0.25, 0.4)
	if "sensors" in lower:
		return Color(0.25, 0.35, 0.4)
	if "engine" in lower or "fusion" in lower:
		return Color(0.9, 0.55, 0.1)
	if "gyro" in lower:
		return Color(0.6, 0.2, 0.8)
	if "autocannon" in lower:
		return Color(0.8, 0.15, 0.15)
	if "ammo" in lower:
		return Color(0.7, 0.5, 0.1)
	if "heat sink" in lower or "double" in lower:
		return Color(0.3, 0.6, 0.8)
	if "armor" in lower:
		return Color(0.4, 0.4, 0.4)
	if "endo" in lower or "ferro" in lower:
		return Color(0.2, 0.6, 0.3)
	if "jump" in lower:
		return Color(0.2, 0.5, 0.5)
	return Color(0.3, 0.3, 0.3)


func _on_slot_pressed(location: String, slot_index: int, current_text: String) -> void:
	var comp_name = current_text.trim_prefix("⚠ ").trim_prefix("✗ ")
	var is_empty = comp_name == tr("Empty")

	match mode:
		"view":
			if not is_empty:
				slot_selected.emit(location, slot_index, comp_name)
		"remove":
			if not is_empty:
				slot_cleared.emit(location, slot_index)
		"place":
			# In place mode, clicking an empty slot signals readiness
			slot_selected.emit(location, slot_index, "" if is_empty else comp_name)


func highlight_slot(location: String, slot_index: int, highlight: bool = true) -> void:
	var key = "%s,%d" % [location, slot_index]
	if _slot_buttons.has(key):
		var btn = _slot_buttons[key]
		var style = btn.get_theme_stylebox("normal")
		if style:
			style.border_color = Color(1.0, 0.8, 0.0) if highlight else Color(0.2, 0.2, 0.25)
			style.border_width_bottom = 2 if highlight else 1


func clear_highlights() -> void:
	for key in _slot_buttons:
		var btn = _slot_buttons[key]
		var style = btn.get_theme_stylebox("normal")
		if style:
			style.border_color = Color(0.2, 0.2, 0.25)
			style.border_width_bottom = 1
