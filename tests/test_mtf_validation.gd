extends SceneTree

var _passed := 0
var _failed := 0
var _Parser: GDScript


func _init() -> void:
	_Parser = load("res://src/tactical/MegaMekParser.gd")
	var defs = _load_defs()

	_print_sep()
	print("MTF Validation Tests")
	_print_sep()

	# Test 1: Valid PPC (3 slots, 3 entries)
	var ppc = _Parser.parse_mtf("res://data/units/meks/3039u/Marauder MAD-3R.mtf", defs)
	if ppc:
		_check_component("PPC", ppc.components, 3, "Valid")
	
	# Test 2: Valid AC/20 (splittable, entries across arm+torso)
	
	_print_sep()
	print("Results: %d passed, %d failed, %d total" % [_passed, _failed, _passed + _failed])
	_print_sep()
	quit(0 if _failed == 0 else 1)


func _check_component(name: String, components: Array, expected_slots: int, label: String) -> void:
	for c in components:
		if c.component_name == name:
			if c.critical_slots == expected_slots:
				_pass("%s: %s has %d slots" % [label, name, c.critical_slots])
			else:
				_fail("%s: %s has %d slots, expected %d" % [label, name, c.critical_slots, expected_slots])
			return
	_fail("%s: %s not found" % [label, name])


func _load_defs() -> Dictionary:
	var defs := {}
	var dir = DirAccess.open("res://data/components")
	if dir:
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


func _pass(n: String) -> void:
	_passed += 1
	print("  PASS  %s" % n)


func _fail(n: String) -> void:
	_failed += 1
	print("  FAIL  %s" % n)


func _print_sep() -> void:
	var s := ""
	for i in range(60):
		s += "="
	print(s)
