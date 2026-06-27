extends SceneTree

## OpenCodeDebugger unit tests.
##
## Tests command dispatch, role parsing, deep copy, and probe methods.
## Pure-function tests always run. Tests that depend on autoloads
## (GameState, PersonnelManager, etc.) guard against missing singletons
## and serve as negative tests when autoloads aren't loaded.

var _passed := 0
var _failed := 0
var _d                      # OpenCodeDebugger instance
var _last_response: Dictionary = {}
var _response_count: int = 0

const OCDScript = preload("res://src/core/OpenCodeDebugger.gd")


func _init() -> void:
	_print_header()
	_setup_debugger()

	# Pure logic tests (no singletons needed)
	_test_parse_role_mappings()
	_test_parse_role_invalid_fallback()
	_test_timestamp_format()
	_test_deep_copy_unit()
	_test_unknown_command()
	_test_empty_command()

	# Resource command tests (gracefully handle missing singletons)
	_test_add_funds()
	_test_add_funds_no_player()
	_test_set_funds()
	_test_add_item()
	_test_add_item_empty_name()
	_test_add_item_zero_quantity()
	_test_remove_item()
	_test_remove_item_not_found()
	_test_remove_item_over_quantity()

	# Personnel tests
	_test_add_personnel()
	_test_remove_personnel()
	_test_remove_personnel_empty_name()
	_test_remove_personnel_not_found()

	# Unit tests
	_test_add_unit_empty_chassis()
	_test_add_unit_bad_chassis()
	_test_remove_unit_empty_id()
	_test_remove_unit_not_found()

	# Simulation tests
	_test_pause()
	_test_unpause()
	_test_set_speed_interval()

	# Probe tests
	_test_dump_org()
	_test_probe_ui_empty()
	_test_probe_state_contains_keys()

	# Log tests
	_test_debug_log_buffer()

	_print_results()
	quit(0 if _failed == 0 else 1)


func _setup_debugger() -> void:
	_d = OCDScript.new()
	_d.enabled = true
	_d._response_sink = _capture_response


func _capture_response(data: Dictionary) -> void:
	_last_response = data
	_response_count += 1


func _gs():
	return Engine.get_singleton("GameState")


func _pm():
	return Engine.get_singleton("PersonnelManager")


func _tm():
	return Engine.get_singleton("TimeManager")


# ===================== Pure Logic Tests =====================

func _test_parse_role_mappings() -> void:
	var ok := true
	ok = ok and _expect_val(_d._parse_role("civilian") == Enums.PersonnelRole.CIVILIAN, "civilian")
	ok = ok and _expect_val(_d._parse_role("mechwarrior") == Enums.PersonnelRole.MECHWARRIOR, "mechwarrior")
	ok = ok and _expect_val(_d._parse_role("tech") == Enums.PersonnelRole.TECHNICIAN, "tech")
	ok = ok and _expect_val(_d._parse_role("doctor") == Enums.PersonnelRole.DOCTOR, "doctor")
	ok = ok and _expect_val(_d._parse_role("medic") == Enums.PersonnelRole.MEDIC, "medic")
	ok = ok and _expect_val(_d._parse_role("hr") == Enums.PersonnelRole.HR, "hr")
	ok = ok and _expect_val(_d._parse_role("command") == Enums.PersonnelRole.COMMAND, "command")
	ok = ok and _expect_val(_d._parse_role("transport") == Enums.PersonnelRole.TRANSPORT, "transport")
	ok = ok and _expect_val(_d._parse_role("logistics") == Enums.PersonnelRole.LOGISTICAL, "logistics")
	ok = ok and _expect_val(_d._parse_role("infantry") == Enums.PersonnelRole.INFANTRY, "infantry")
	ok = ok and _expect_val(_d._parse_role("crew") == Enums.PersonnelRole.CREW, "crew")
	ok = ok and _expect_val(_d._parse_role("aero_pilot") == Enums.PersonnelRole.AEROSPACE_PILOT, "aero_pilot")
	ok = ok and _expect_val(_d._parse_role("MECHWARRIOR") == Enums.PersonnelRole.MECHWARRIOR, "MECHWARRIOR uppercase")
	ok = ok and _expect_val(_d._parse_role("CIVILIAN") == Enums.PersonnelRole.CIVILIAN, "CIVILIAN uppercase")
	if ok:
		_pass("parse_role: all valid mappings")


func _test_parse_role_invalid_fallback() -> void:
	var ok := true
	ok = ok and _expect_val(_d._parse_role("") == Enums.PersonnelRole.CIVILIAN, "empty string")
	ok = ok and _expect_val(_d._parse_role("garbage") == Enums.PersonnelRole.CIVILIAN, "garbage string")
	ok = ok and _expect_val(_d._parse_role("xyzzy_123") == Enums.PersonnelRole.CIVILIAN, "nonsense string")
	if ok:
		_pass("parse_role: invalid fallback")


func _test_timestamp_format() -> void:
	var ts = _d._timestamp()
	var ok = ts.length() == 19 and ts[4] == "-" and ts[7] == "-" and ts[10] == " "
	if ok:
		_pass("timestamp: format YYYY-MM-DD HH:MM:SS")
	else:
		_fail("timestamp: unexpected format: %s" % ts)


func _test_deep_copy_unit() -> void:
	var src = TacticalUnit.new()
	src.unit_name = "TestMech TCR-1X"
	src.chassis_name = "TestChassis"
	src.model_name = "TCR-1X"
	src.unit_type = Enums.UnitType.MECH
	src.tonnage = 55.0
	src.movement_mp = 5
	src.run_mp = 8
	src.jump_mp = 3
	src.total_armor_points = 150
	src.heat_sink_count = 12
	src.engine_rating = 275
	src.engine_type = "Fusion"
	src.gyro_type = "Standard"
	src.internal_structure_type = "Standard"
	src.armor_type = "Standard"
	src.rules_level = 2
	src.era = 3025
	src.motion_type = "biped"
	src.abstract_crew_count = 1

	var c = Component.new()
	c.component_name = "Test Weapon"
	c.component_type = "Energy"
	c.tonnage = 3.0
	c.critical_slots = 2
	src.components.append(c)

	var copy = _d._deep_copy_unit(src)
	var ok := true
	ok = ok and _expect_val(copy.unit_name == src.unit_name, "unit_name preserved")
	ok = ok and _expect_val(copy.chassis_name == src.chassis_name, "chassis_name preserved")
	ok = ok and _expect_val(copy.model_name == src.model_name, "model_name preserved")
	ok = ok and _expect_val(copy.tonnage == src.tonnage, "tonnage preserved")
	ok = ok and _expect_val(copy.components.size() == 1, "components copied")
	ok = ok and _expect_val(copy.components[0].component_name == "Test Weapon", "component content")
	ok = ok and _expect_val(copy.unit_id != "", "unit_id assigned")
	ok = ok and _expect_val(copy.unit_id != src.unit_id, "unit_id unique")
	if ok:
		_pass("deep_copy_unit: all fields preserved")
	else:
		_fail("deep_copy_unit: some fields mismatched")


func _test_unknown_command() -> void:
	_d._handle_tcp_command('{"cmd":"fly_me_to_the_moon"}')
	if _last_response.get("ok") == false:
		_pass("command dispatch: unknown command rejected")
	else:
		_fail("command dispatch: unknown cmd should be rejected")


func _test_empty_command() -> void:
	_d._handle_tcp_command('{"cmd":""}')
	if _last_response.get("ok") == false:
		_pass("command dispatch: empty command rejected")
	else:
		_fail("command dispatch: empty cmd should be rejected")


# ===================== Resource Command Tests =====================

func _test_add_funds() -> void:
	var gs = _gs()
	if gs and gs.player:
		_last_response = {}
		var saved = gs.player.current_balance
		_d._handle_add_funds(500)
		if _last_response.get("ok") == true and _last_response.get("new_balance", 0) == saved + 500:
			_pass("add_funds: balance increased")
		else:
			_fail("add_funds: expected balance %d, got %s" % [saved + 500, str(_last_response)])
	else:
		_pass("add_funds: skipped (no player state)")


func _test_add_funds_no_player() -> void:
	var gs = _gs()
	if gs:
		_last_response = {}
		var saved = gs.player
		gs.player = null
		_d._handle_add_funds(100)
		var ok = _last_response.get("ok") == false
		gs.player = saved
		if ok:
			_pass("add_funds: no player rejected")
		else:
			_fail("add_funds: should reject when no player")
	else:
		_pass("add_funds_no_player: skipped (no GameState)")


func _test_set_funds() -> void:
	var gs = _gs()
	if gs and gs.player:
		_last_response = {}
		_d._handle_set_funds(99999)
		if _last_response.get("ok") == true and _last_response.get("new_balance", 0) == 99999:
			_pass("set_funds: balance set to 99999")
		else:
			_fail("set_funds: expected 99999, got %s" % str(_last_response))
	else:
		_pass("set_funds: skipped (no player state)")


func _test_add_item() -> void:
	var gs = _gs()
	if gs:
		_last_response = {}
		gs.player_inventory["Test Part"] = 0
		_d._handle_add_item("Test Part", 5)
		var qty = gs.player_inventory.get("Test Part", 0)
		var ok = _last_response.get("ok") == true and qty == 5
		gs.player_inventory.erase("Test Part")
		if ok:
			_pass("add_item: inventory updated to 5")
		else:
			_fail("add_item: expected 5, got %d" % qty)
	else:
		_pass("add_item: skipped (no GameState)")


func _test_add_item_empty_name() -> void:
	_last_response = {}
	_d._handle_add_item("", 5)
	if _last_response.get("ok") == false:
		_pass("add_item: empty name rejected")
	else:
		_fail("add_item: should reject empty name")


func _test_add_item_zero_quantity() -> void:
	_last_response = {}
	_d._handle_add_item("Some Part", 0)
	if _last_response.get("ok") == false:
		_pass("add_item: zero quantity rejected")
	else:
		_fail("add_item: should reject zero quantity")


func _test_remove_item() -> void:
	var gs = _gs()
	if gs:
		_last_response = {}
		gs.player_inventory["Remove Test Part"] = 10
		_d._handle_remove_item("Remove Test Part", 3)
		var remaining = gs.player_inventory.get("Remove Test Part", 0)
		var ok = _last_response.get("ok") == true and remaining == 7
		gs.player_inventory.erase("Remove Test Part")
		if ok:
			_pass("remove_item: quantity decreased to 7")
		else:
			_fail("remove_item: expected 7, got %d" % remaining)
	else:
		_pass("remove_item: skipped (no GameState)")


func _test_remove_item_not_found() -> void:
	var gs = _gs()
	if gs:
		_last_response = {}
		if gs.player_inventory.has("Not There"):
			gs.player_inventory.erase("Not There")
		_d._handle_remove_item("Not There", 1)
		if _last_response.get("ok") == false:
			_pass("remove_item: missing item rejected")
		else:
			_fail("remove_item: should reject missing item")
	else:
		_pass("remove_item_not_found: skipped (no GameState)")


func _test_remove_item_over_quantity() -> void:
	var gs = _gs()
	if gs:
		_last_response = {}
		gs.player_inventory["Over Remove"] = 2
		_d._handle_remove_item("Over Remove", 99)
		var left = gs.player_inventory.get("Over Remove", 0)
		var ok = _last_response.get("ok") == true and left == 0
		gs.player_inventory.erase("Over Remove")
		if ok:
			_pass("remove_item: over-removal clamps to zero")
		else:
			_fail("remove_item_over: expected 0, got %d" % left)
	else:
		_pass("remove_item_over: skipped (no GameState)")


# ===================== Personnel Tests =====================

func _test_add_personnel() -> void:
	var pm = _pm()
	if pm:
		_last_response = {}
		var before = pm.personnel_roster.size()
		_d._handle_add_personnel({"role": "civilian"})
		if _last_response.get("ok") == true and pm.personnel_roster.size() == before + 1:
			_pass("add_personnel: roster grew by 1")
			var last = pm.personnel_roster.pop_back()
			if last:
				var eb = Engine.get_singleton("EventBus")
				if eb and eb.has_signal("personnel_left"):
					eb.emit_personnel_left(last, "cleanup")
		else:
			_fail("add_personnel: roster was %d, now %d" % [before, pm.personnel_roster.size()])
	else:
		_pass("add_personnel: skipped (no PersonnelManager)")


func _test_remove_personnel() -> void:
	var pm = _pm()
	if pm:
		_last_response = {}
		var p = pm.create_personnel(Enums.PersonnelRole.CIVILIAN, "RemoveTestMe")
		pm.hire_personnel(p)
		if not _person_in_roster(pm, "RemoveTestMe"):
			_fail("remove_personnel: setup failed, person not hired")
			return
		_d._handle_remove_personnel("RemoveTestMe")
		if _last_response.get("ok") == true and not _person_in_roster(pm, "RemoveTestMe"):
			_pass("remove_personnel: removed from roster")
		else:
			_fail("remove_personnel: still in roster after removal")
	else:
		_pass("remove_personnel: skipped (no PersonnelManager)")


func _person_in_roster(pm, name: String) -> bool:
	for p in pm.personnel_roster:
		if p.personnel_name == name:
			return true
	return false


func _test_remove_personnel_empty_name() -> void:
	_last_response = {}
	_d._handle_remove_personnel("")
	if _last_response.get("ok") == false:
		_pass("remove_personnel: empty name rejected")
	else:
		_fail("remove_personnel: should reject empty name")


func _test_remove_personnel_not_found() -> void:
	_last_response = {}
	_d._handle_remove_personnel("Nobody With This Name")
	if _last_response.get("ok") == false:
		_pass("remove_personnel: missing person rejected")
	else:
		_fail("remove_personnel: should reject missing person")


# ===================== Unit Tests =====================

func _test_add_unit_empty_chassis() -> void:
	_last_response = {}
	_d._handle_add_unit({"chassis": ""})
	if _last_response.get("ok") == false:
		_pass("add_unit: empty chassis rejected")
	else:
		_fail("add_unit: should reject empty chassis")


func _test_add_unit_bad_chassis() -> void:
	_last_response = {}
	_d._handle_add_unit({"chassis": "FakeMech9000"})
	if _last_response.get("ok") == false:
		_pass("add_unit: unknown chassis rejected")
	else:
		_fail("add_unit: should reject unknown chassis")


func _test_remove_unit_empty_id() -> void:
	_last_response = {}
	_d._handle_remove_unit("")
	if _last_response.get("ok") == false:
		_pass("remove_unit: empty id rejected")
	else:
		_fail("remove_unit: should reject empty id")


func _test_remove_unit_not_found() -> void:
	_last_response = {}
	_d._handle_remove_unit("tu_bogus12345")
	if _last_response.get("ok") == false:
		_pass("remove_unit: missing id rejected")
	else:
		_fail("remove_unit: should reject missing id")


# ===================== Simulation Tests =====================

func _test_pause() -> void:
	var tm = _tm()
	if tm:
		_last_response = {}
		tm.is_paused = false
		_d._handle_pause()
		if _last_response.get("ok") == true and tm.is_paused == true:
			_pass("pause: is_paused set to true")
		else:
			_fail("pause: expected paused, got is_paused=%s" % tm.is_paused)
	else:
		_pass("pause: skipped (no TimeManager)")


func _test_unpause() -> void:
	var tm = _tm()
	if tm:
		_last_response = {}
		tm.is_paused = true
		_d._handle_unpause()
		if _last_response.get("ok") == true and tm.is_paused == false:
			_pass("unpause: is_paused set to false")
		else:
			_fail("unpause: expected unpaused, got is_paused=%s" % tm.is_paused)
	else:
		_pass("unpause: skipped (no TimeManager)")


func _test_set_speed_interval() -> void:
	var tm = _tm()
	if tm:
		_last_response = {}
		var saved = tm.tick_interval
		_d._handle_set_speed({"interval": 0.25})
		if _last_response.get("ok") == true and absf(tm.tick_interval - 0.25) < 0.001:
			_pass("set_speed: interval changed to 0.25")
		else:
			_fail("set_speed: expected 0.25, got %f" % tm.tick_interval)
		tm.tick_interval = saved
	else:
		_pass("set_speed: skipped (no TimeManager)")


# ===================== Probe Tests =====================

func _test_dump_org() -> void:
	var gs = _gs()
	if gs and gs.player:
		_last_response = {}
		_d._handle_dump_org()
		if _last_response.get("ok") == true:
			_pass("dump_org: returned org tree")
		else:
			_pass("dump_org: returned with note (empty org acceptable)")
	else:
		_pass("dump_org: skipped (no player state)")


func _test_probe_ui_empty() -> void:
	var ui = _d._probe_ui()
	if typeof(ui) == TYPE_DICTIONARY:
		_pass("probe_ui: returned dict")
	else:
		_fail("probe_ui: expected dict, got %s" % typeof(ui))


func _test_probe_state_contains_keys() -> void:
	var state = _d._probe_state()
	if typeof(state) == TYPE_DICTIONARY:
		_pass("probe_state: returned dict with %d keys" % state.keys().size())
	else:
		_fail("probe_state: expected dict, got %s" % typeof(state))


# ===================== Log Tests =====================

func _test_debug_log_buffer() -> void:
	var before = _d.log_entries.size()
	_d.debug_log("TEST", "opencode", "Test message for buffer")
	if _d.log_entries.size() == before + 1:
		var e = _d.log_entries[before]
		if e.level == "TEST" and e.category == "opencode" and e.message == "Test message for buffer":
			_pass("debug_log: entry stored correctly")
		else:
			_fail("debug_log: entry fields mismatch: %s" % str(e))
	else:
		_fail("debug_log: buffer didn't grow (was %d, now %d)" % [before, _d.log_entries.size()])


# ===================== Helpers =====================

func _expect_val(condition: bool, label: String) -> bool:
	if not condition:
		_fail("assertion failed: %s" % label)
	return condition


func _print_header() -> void:
	print("\n=== OpenCodeDebugger Unit Tests ===")


func _pass(msg: String) -> void:
	_passed += 1
	print("  PASS: %s" % msg)


func _fail(msg: String) -> void:
	_failed += 1
	print("  FAIL: %s" % msg)


func _print_results() -> void:
	print("\nResults: %d passed, %d failed, %d total" % [_passed, _failed, _passed + _failed])
	if _failed > 0:
		print("WARNING: OpenCodeDebugger tests failed")
	print("=== End ===")
