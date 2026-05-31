class_name TacticalMap
extends Control

signal closed()

var contract: Contract
var player_units: Array[TacticalUnit] = []
var enemy_units: Array[TacticalUnit] = []
var deployment: Array[OperationalUnit] = []

var _resolved: bool = false
var _result: Dictionary = {}

@onready var title_label: Label = %TitleLabel
@onready var info_label: RichTextLabel = %InfoLabel
@onready var resolve_button: Button = %ResolveButton
@onready var return_button: Button = %ReturnButton


func _ready() -> void:
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	add_theme_stylebox_override("panel", bg)

	Helpers.validate_nodes("TacticalMap", [
		["title_label", title_label], ["info_label", info_label],
		["resolve_button", resolve_button], ["return_button", return_button],
	])

	resolve_button.pressed.connect(_on_resolve)
	return_button.pressed.connect(_on_return)
	%Title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))


func load_engagement(c: Contract, hex_data: Dictionary, deployed: Array[OperationalUnit]) -> void:
	contract = c
	deployment = deployed
	player_units = []
	for opu in deployed:
		player_units.append_array(opu.get_all_tactical_units())

	var strength = hex_data.get("objective_data", {}).get("strength", 1)
	enemy_units = _generate_opfor(strength)

	title_label.text = tr("Tactical Engagement — %s") % contract.activity_type
	_refresh_display()


func _generate_opfor(strength: int) -> Array[TacticalUnit]:
	var result: Array[TacticalUnit] = []
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var count = strength + rng.randi_range(0, 1)
	var chassis_pool = ["Commando", "Locust", "Stinger", "Wasp", "Panther", "Assassin", "Hermes", "Vulcan"]
	var tonnage_pool = [25, 20, 20, 20, 35, 40, 30, 40]

	for i in range(count):
		var idx = rng.randi_range(0, chassis_pool.size() - 1)
		var unit = TacticalUnit.new()
		unit.unit_name = chassis_pool[idx] + " (" + tr("Enemy") + " " + str(i + 1) + ")"
		unit.chassis_name = chassis_pool[idx]
		unit.unit_type = Enums.UnitType.MECH
		unit.tonnage = tonnage_pool[idx]
		unit.movement_mp = rng.randi_range(3, 6)
		unit.run_mp = unit.movement_mp * 3 / 2
		unit.jump_mp = 0
		unit.total_armor_points = int(unit.tonnage * 3.0)
		unit.quality = Enums.Quality.D
		unit.components = _generate_opfor_components(unit.tonnage, rng)
		result.append(unit)

	return result


func _generate_opfor_components(tonnage: float, rng: RandomNumberGenerator) -> Array:
	var result: Array = []
	var loc = ComponentLocation.new()
	loc.location_name = "Center Torso"
	loc.armor = int(tonnage * 1.5)
	loc.structure = int(tonnage / 5)

	var weapons = ["Medium Laser", "Small Laser", "SRM-4", "LRM-5", "Machine Gun"]
	var weapon_count = rng.randi_range(1, 3)
	for i in range(weapon_count):
		var w_name = weapons[rng.randi_range(0, weapons.size() - 1)]
		var comp = Component.new()
		comp.component_name = w_name
		comp.component_type = "weapon"
		comp.tonnage = 1.0
		comp.critical_slots = 1
		comp.location = loc
		comp.status = Enums.ComponentStatus.UNDAMAGED
		result.append(comp)

	var engine = Component.new()
	engine.component_name = "Fusion Engine"
	engine.component_type = "engine"
	engine.tonnage = tonnage * 0.1
	engine.critical_slots = 6
	engine.location = loc
	result.append(engine)

	return result


func _refresh_display() -> void:
	var text = ""
	text += "[b]" + tr("Player Forces:") + "[/b]\n"
	for u in player_units:
		var dmg = u.get_damaged_components().size()
		var destroyed = u.get_destroyed_components().size()
		text += "  %s (%dt)" % [u.unit_name, int(u.tonnage)]
		if dmg > 0 or destroyed > 0:
			text += " [color=#ffaa44]Dmg:%d[/color] [color=#ff4444]Des:%d[/color]" % [dmg, destroyed]
		text += "\n"

	text += "\n[b]" + tr("Enemy Forces:") + "[/b]\n"
	if _resolved:
		for u in enemy_units:
			var destroyed = u.get_destroyed_components().size()
			var total = u.components.size()
			var status = "[color=#44ff66]" + tr("Intact") + "[/color]"
			if destroyed >= total:
				status = "[color=#ff4444]" + tr("Destroyed") + "[/color]"
			elif destroyed > 0:
				status = "[color=#ffaa44]" + tr("Damaged") + "[/color]"
			text += "  %s (%dt) — %s\n" % [u.unit_name, int(u.tonnage), status]
	else:
		for u in enemy_units:
			text += "  %s (%dt)\n" % [u.unit_name, int(u.tonnage)]

	info_label.text = text


func _on_resolve() -> void:
	if _resolved:
		return
	_resolved = true
	resolve_button.disabled = true

	var resolver = load("res://src/tactical/CombatResolver.gd").new()
	add_child(resolver)
	_result = resolver.resolve(player_units, enemy_units, contract)
	resolver.queue_free()

	_refresh_display()

	var result_text = "\n[b]" + tr("Combat Result:") + "[/b]\n"
	if _result.get("player_victory", false):
		result_text += "[color=#44ff66]" + tr("Victory!") + "[/color]\n"
	else:
		result_text += "[color=#ff4444]" + tr("Defeat") + "[/color]\n"
	result_text += tr("Enemies destroyed: %d / %d") % [_result.get("enemies_destroyed", 0), _result.get("total_enemies", 0)] + "\n"
	result_text += tr("Player units lost: %d") % _result.get("player_units_lost", 0) + "\n"
	var salvage_val = _result.get("salvage_value", 0)
	if salvage_val > 0:
		result_text += tr("Salvage recovered: %s") % Helpers.fmt_money(salvage_val) + "\n"
	info_label.text += result_text

	return_button.text = tr("Return to Planetary Map")


func _on_return() -> void:
	if contract and _result.get("salvage_value", 0) > 0:
		EconomySystem.process_engagement(contract)
	ReputationSystem.modify_reputation(contract.issuer, 2, "Tactical engagement completed")
	closed.emit()
