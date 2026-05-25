extends SceneTree

var _passed := 0
var _failed := 0
var _Parser: GDScript
var _defs: Dictionary


func _init() -> void:
	_Parser = load("res://src/tactical/MegaMekParser.gd")
	_defs = _load_component_defs()

	_print_sep()
	print("MTF Parser — Tech Level 1 Unit Tests")
	_print_sep()

	# === Assault mechs (3025 / Tech 1) ===
	_test("MAD-3R", "res://data/units/meks/3039u/Marauder MAD-3R.mtf", 75, 16, 4)
	_test("GOL-1M", "res://data/units/meks/3025 CCE/Assault/Goliath GOL-1M.mtf", 80, 13, 1)
	_test("BNC-3S-X", "res://data/units/meks/3025 CCE/Assault/Banshee BNC-3S-X.mtf", 95, 22, 11)

	# === Heavy mechs (3025 / Tech 1) ===
	_test("GHR-5S", "res://data/units/meks/3025 CCE/Heavy/Grasshopper GHR-5S.mtf", 70, 22, 11)
	_test("WHM-6J", "res://data/units/meks/3025 CCE/Heavy/Warhammer WHM-6J.mtf", 70, 18, 7)
	_test("WHM-6B", "res://data/units/meks/3025 CCE/Heavy/Warhammer WHM-6B.mtf", 70, 20, 12)
	_test("MAD-3J", "res://data/units/meks/3025 CCE/Heavy/Marauder MAD-3J.mtf", 75, 14, 2)
	_test("ARC-2D", "res://data/units/meks/3025 CCE/Heavy/Archer ARC-2D.mtf", 70, 10, 0)
	_test("ARC-2L", "res://data/units/meks/3025 CCE/Heavy/Archer ARC-2L.mtf", 70, 10, 0)

	# === Medium mechs (3025 / Tech 1) ===
	_test("ASN-22", "res://data/units/meks/3025 CCE/Medium/Assassin ASN-22.mtf", 40, 11, 0)
	_test("GRF-1M", "res://data/units/meks/3025 CCE/Medium/Griffin GRF-1M.mtf", 55, 12, 1)
	_test("CDA-2C", "res://data/units/meks/3025 CCE/Medium/Cicada CDA-2C.mtf", 40, 10, 0)
	_test("SCP-1A", "res://data/units/meks/3025 CCE/Medium/Scorpion SCP-1A.mtf", 55, 10, 0)

	# === Summary ===
	_print_sep()
	print("Results: %d passed, %d failed, %d total" % [_passed, _failed, _passed + _failed])
	_print_sep()
	quit(0 if _failed == 0 else 1)


func _test(name: String, path: String, expected_t: int, expected_hs: int, expected_slots: int) -> void:
	var unit = _Parser.parse_mtf(path, _defs)

	if unit == null:
		_fail(name, "parse failed")
		return

	if abs(unit.tonnage - float(expected_t)) > 0.01:
		_fail(name, "tonnage: got %.1f, expected %d" % [unit.tonnage, expected_t])
		return

	if unit.heat_sink_count != expected_hs:
		_fail(name, "HS count: got %d, expected %d" % [unit.heat_sink_count, expected_hs])
		return

	var hs_slots := 0.0
	for c in unit.components:
		var n = c.component_name.to_lower()
		if n == "heat sink" or n == "double heat sink":
			hs_slots += c.tonnage
	if abs(hs_slots - float(expected_slots)) > 0.01:
		_fail(name, "HS in slots: got %.0ft, expected %dt" % [hs_slots, expected_slots])
		return

	var has_engine := false
	for c in unit.components:
		if "Engine" in c.component_name and c.tonnage > 0:
			has_engine = true
			break
	if not has_engine:
		_fail(name, "no engine weight")
		return

	var has_gyro := false
	for c in unit.components:
		if c.component_name == "Gyroscope" and c.tonnage > 0:
			has_gyro = true
			break
	if not has_gyro:
		_fail(name, "gyro weight is 0")
		return

	var r = unit.validate_tm()
	if not r.valid:
		_fail(name, r.errors[0])
		return

	_pass(name)


func _pass(n: String) -> void:
	_passed += 1
	print("  PASS  %s" % n)


func _fail(n: String, m: String) -> void:
	_failed += 1
	print("  FAIL  %s  %s" % [n, m])


func _load_component_defs() -> Dictionary:
	var defs := {}
	var dir = DirAccess.open("res://data/components")
	if not dir:
		return defs
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if f.ends_with(".json"):
			var file = FileAccess.open("res://data/components/" + f, FileAccess.READ)
			if file:
				var j = JSON.new()
				if j.parse(file.get_as_text()) == OK:
					defs[j.data.get("name", "")] = j.data
		f = dir.get_next()
	return defs


func _print_sep() -> void:
	var s := ""
	for i in range(60):
		s += "="
	print(s)
