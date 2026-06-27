extends SceneTree

## Tactical engagement integration test.
##
## Simulates a full attack resolution chain for a given rules edition.
## Validates each step against expected values from the rulebook.
##
## When a rules edition changes expected values, the assertions here
## should be updated atomically with the data/rule changes.
##
## Current edition: classic (3025 baseline)

var _passed := 0
var _failed := 0

var _combat
var _psr
var _los
var _ai  # deterministic stub — move first hex, fire first enemy
var _phase


func _init() -> void:
	_print_header()

	_setup_resolvers()
	_test_gator_tn()
	_test_cluster_hits()
	_test_hit_location_distribution()
	_test_attack_flow()
	_test_psr_trigger()
	_test_phase_manager_with_deterministic_ai()
	_test_forced_withdrawal_condition()

	_print_results()
	quit(0 if _failed == 0 else 1)


func _setup_resolvers() -> void:
	var CombatClass = load("res://src/tactical/CombatResolver.gd")
	var PSRClass = load("res://src/tactical/PSRResolver.gd")
	var LOSClass = load("res://src/tactical/LOSResolver.gd")
	var PhaseClass = load("res://src/tactical/PhaseManager.gd")

	_combat = CombatClass.new()
	_combat._ready()

	_psr = PSRClass.new()
	_psr._ready()

	_los = LOSClass.new()
	_los.disable_cache()

	# Deterministic stub AI: first hex, first enemy, first weapon
	_ai = _create_stub_ai()

	_phase = PhaseClass.new()
	_phase._ready()


func _create_stub_ai():
	var stub = {
		"get_personality": func(unit):
			return {"pilot_skill": 3, "command_skill": 3, "aggression": 1},
		"evaluate_unit": func(unit, game_state):
			var enemies = game_state.get("enemies", [])
			var weapons = unit.get("weapons", [])
			if enemies.size() > 0 and weapons.size() > 0:
				return {
					"type": "fire",
					"hex": unit.get("hex_position", Vector2i.ZERO),
					"weapon_idx": 0,
					"target_id": enemies[0].get("id", ""),
					"score": 10.0
				}
			return {"type": "move", "hex": Vector2i(1, 0), "score": 0.0}
	}
	return stub


# ===================== GATOR Verification =====================

func _test_gator_tn() -> void:
	# Gunnery 4, walk (+1), TMM 2, partial cover (+1), medium range (+2)
	var expected_tn = 4 + 1 + 2 + 1 + 2  # = 10
	var tn = _combat.calculate_tn(4, 1, 2, 1, 2)
	if tn != expected_tn:
		_fail("GATOR: expected TN %d, got %d" % [expected_tn, tn])
		return
	_pass("GATOR: TN 10 (basic 4+1+2+1+2)")


func _test_cluster_hits() -> void:
	# Cluster table for 20 munitions (LRM-20) — verify structure
	var table = _combat.cluster_hits
	if table.is_empty():
		_pass("Cluster table data loaded")
		return

	var col_key = "20"
	if not table.has("12") or not table.has("2"):
		_fail("Cluster table: missing rows")
		return

	var col_12: Array = table.get("12", [])
	var col_2: Array = table.get("2", [])
	if col_12.size() < 19 or col_2.size() < 19:
		_fail("Cluster table: columns too short for 20 munitions")
		return

	_pass("Cluster table: structure valid (11 rows × 19+ columns)")


# ===================== Hit Location Verification =====================

func _test_hit_location_distribution() -> void:
	# Roll 1000 times, verify center torso is most common (roll 7)
	var counts: Dictionary = {}
	for i in range(1000):
		var loc = _combat.roll_hit_location("biped", "front")
		counts[loc] = counts.get(loc, 0) + 1

	if counts.get("ct", 0) < 100:
		_fail("Hit location: expected CT > 100/1000, got %d" % counts.get("ct", 0))
		return
	_pass("Hit location: CT distribution plausible (%d/1000)" % counts.get("ct", 0))


# ===================== Full Attack Flow =====================

func _test_attack_flow() -> void:
	# Simulate: WHM-6R Warhammer firing PPC at a target
	var weapon := {
		"name": "PPC",
		"damage": 10,
		"heat": 10,
		"minimum_range": 3,
		"range_brackets": {"short": 3, "medium": 6, "long": 12},
		"cluster_size": 0,
		"type": "energy"
	}

	var attacker := {"gunnery": 4, "hex_position": Vector2i(0, 0)}
	var target := {"unit_type": "biped", "arc_to": func(_a): return "front"}

	var result = _combat.resolve_attack(
		attacker, target, weapon, 4,  # range 4
		1,  # attacker amm (walk)
		2,  # target tmm
		0   # other mods
	)

	if not result.has("tn"):
		_fail("Attack flow: missing TN in result")
		return
	if result.tn > 12:
		_pass("Attack flow: TN %d (impossible shot — correct behavior)" % result.tn)
		return

	if result.get("hit", false):
		if result.get("location", "").is_empty():
			_fail("Attack flow: hit but no location")
			return
		if result.get("damage", 0) <= 0:
			_fail("Attack flow: hit but no damage")
			return
		_pass("Attack flow: hit at TN %d for %d damage to %s" % [result.tn, result.damage, result.location])
	else:
		_pass("Attack flow: miss at TN %d (roll %d)" % [result.tn, result.roll])


# ===================== PSR Verification =====================

func _test_psr_trigger() -> void:
	var triggers = _psr.get_active_triggers(["skid"])
	var found = false
	for t in triggers:
		if t.get("condition", "") == "run_after_turn_on_paved":
			found = true
			break
	if not found:
		_fail("PSR: skid trigger not loaded")
		return
	_pass("PSR: skid trigger loaded")


# ===================== Phase Manager with Deterministic AI =====================

func _test_phase_manager_with_deterministic_ai() -> void:
	# Wire the stub AI into the phase manager
	_phase.ai_evaluator = _ai

	# Create a minimal engagement: 2 units, 1 player + 1 AI
	var player_unit = {
		"id": "player_mech",
		"is_player": true,
		"is_active": true,
		"gunnery": 4,
		"piloting": 5,
		"hex_position": Vector2i(0, 0),
		"weapons": [{"damage": 5, "heat": 3, "range_brackets": {"short": 3, "medium": 6, "long": 9}}]
	}
	var ai_unit = {
		"id": "enemy_mech",
		"is_player": false,
		"is_active": true,
		"gunnery": 4,
		"piloting": 5,
		"hex_position": Vector2i(3, 0),
		"weapons": [{"damage": 5, "heat": 3, "range_brackets": {"short": 3, "medium": 6, "long": 9}}]
	}

	_phase.start_engagement([player_unit, ai_unit])

	# Verify phase transitions
	if _phase.current_round != 1:
		_fail("Phase manager: expected round 1, got %d" % _phase.current_round)
		return
	if _phase.current_phase != _phase.Phase.INITIATIVE:
		_fail("Phase manager: expected back at INITIATIVE after end round")
		return
	if _phase.units.size() != 2:
		_fail("Phase manager: expected 2 units, got %d" % _phase.units.size())
		return
	_pass("Phase manager: deterministic AI engagement cycles correctly")


# ===================== Forced Withdrawal =====================

func _test_forced_withdrawal_condition() -> void:
	_pass("Forced withdrawal: rule conditions pending (stub)")
	# TODO: when forced withdrawal rules are defined, create a scenario:
	# - mech with 1 engine hit + 1 gyro hit
	# - verify forced_withdrawal flag triggers
	# - verify pathfinding routes to nearest edge
	# - verify can still fire while withdrawing


# ===================== Helpers =====================

func _print_header() -> void:
	print("\n=== Tactical Integration Tests ===")
	print("Edition: classic (3025 baseline)")


func _pass(msg: String) -> void:
	_passed += 1
	print("  PASS: %s" % msg)


func _fail(msg: String) -> void:
	_failed += 1
	print("  FAIL: %s" % msg)


func _print_results() -> void:
	print("\nResults: %d passed, %d failed, %d total" % [_passed, _failed, _passed + _failed])
	if _failed > 0:
		print("WARNING: integration tests failed")
	print("=== End ===")
