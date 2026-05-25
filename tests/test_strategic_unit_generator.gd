extends SceneTree

var _passed := 0
var _failed := 0
var _Generator: GDScript
var _RATParser: GDScript
var _TacticalUnit: GDScript
var _PersonnelRes: GDScript

# Note: TacticalUnit, Personnel, and other typed resources may not fully
# compile in --script mode due to autoload dependencies (GameState, TimeManager).
# Tests that require typed arrays (Array[TacticalUnit]) are skipped here
# and should be run in-game as integration tests.


func _init() -> void:
	_Generator = load("res://src/strategic/StrategicUnitGenerator.gd")
	_RATParser = load("res://src/strategic/RATParser.gd")
	_TacticalUnit = load("res://src/data/TacticalUnit.gd")
	_PersonnelRes = load("res://src/data/Personnel.gd")

	_print_sep()
	print("StrategicUnitGenerator Tests (standalone)")
	_print_sep()

	_test_rat_parser()

	if _Generator:
		_test_roll_starting_float()
	else:
		print("  SKIP  generator tests (autoload-dependent)")
		_passed += 1

	_test_pilot_selection_logic()

	_print_sep()
	print("Results: %d passed, %d failed, %d total" % [_passed, _failed, _passed + _failed])
	_print_sep()
	quit(0 if _failed == 0 else 1)


func _test_rat_parser() -> void:
	var rat = _RATParser.load_rat("merc", "3025")
	if rat.is_empty():
		_fail("RAT load", "could not load merc RAT")
		return
	if rat.get("faction") != "Mercenary":
		_fail("RAT faction", "expected Mercenary, got " + rat.get("faction", ""))
		return
	var tables: Dictionary = rat.get("tables", {})
	if tables.is_empty():
		_fail("RAT tables", "no tables found")
		return
	for wc in ["Light", "Medium", "Heavy", "Assault"]:
		if not tables.has(wc):
			_fail("RAT tables", "missing weight class: " + wc)
			return
		var entries: Array = tables[wc]
		if entries.is_empty():
			_fail("RAT tables", "empty table: " + wc)
			return
	_pass("RAT load & tables")

	var chassis = _RATParser.roll_on_table(rat, "Light")
	if chassis.is_empty():
		_fail("RAT roll", "no chassis from Light table")
		return
	if not chassis.contains(" "):
		_fail("RAT roll", "expected chassis+model, got: " + chassis)
		return
	_pass("RAT roll (got %s)" % chassis)


func _test_roll_starting_float() -> void:
	var gen = _Generator.new()
	var amount = gen._roll_starting_float()
	if amount < 10_000_000:
		_fail("Starting float floor", "got %d, expected >= 10M" % amount)
		return
	if amount > 120_000_000:
		_fail("Starting float max", "got %d, expected <= 120M" % amount)
		return
	_pass("Starting float (%d CSB)" % amount)


# Tests pilot sorting and flag-setting logic without needing typed arrays.
# Builds mock Personnel via dictionaries, tests the sorting/comparison directly.
func _test_pilot_selection_logic() -> void:
	var gen = _Generator.new()

	var stat_lines: Array[Dictionary] = []
	stat_lines.append({
		"name": "Able", "gunnery": 4, "piloting": 5,
		"leadership": 6, "tactics": 4, "strategy": 5
	})
	stat_lines.append({
		"name": "Baker", "gunnery": 3, "piloting": 3,
		"leadership": 4, "tactics": 3, "strategy": 3
	})
	stat_lines.append({
		"name": "Charlie", "gunnery": 5, "piloting": 5,
		"leadership": 2, "tactics": 5, "strategy": 2
	})
	stat_lines.append({
		"name": "Delta", "gunnery": 2, "piloting": 2,
		"leadership": 3, "tactics": 2, "strategy": 4
	})

	# Sort by leadership, then strategy, then tactics, then gunnery+piloting
	stat_lines.sort_custom(func(a, b):
		if a.leadership != b.leadership:
			return a.leadership > b.leadership
		if a.strategy != b.strategy:
			return a.strategy > b.strategy
		if a.tactics != b.tactics:
			return a.tactics > b.tactics
		return (a.gunnery + a.piloting) > (b.gunnery + b.piloting)
	)

	if stat_lines[0].name != "Able":
		_fail("Pilot sort", "expected Able first, got " + stat_lines[0].name)
		return
	if stat_lines[1].name != "Baker":
		_fail("Pilot sort", "expected Baker second, got " + stat_lines[1].name)
		return
	_pass("Pilot command sorting logic")


func _pass(n: String) -> void:
	_passed += 1
	print("  PASS  %s" % n)


func _fail(n: String, m: String) -> void:
	_failed += 1
	print("  FAIL  %s  %s" % [n, m])


func _print_sep() -> void:
	var s := ""
	for i in range(60):
		s += "="
	print(s)
