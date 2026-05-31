extends Node

## Resolves Piloting Skill Rolls (PSRs) for mechs and ground vehicles.
##
## A PSR is triggered when:
##   - 20+ damage taken in a single phase (cumulative +1 per 20 damage)
##   - Entering certain terrain (depth 1+ water, rubble)
##   - Performing certain maneuvers (DFA, charge, sprint on rough)
##   - Taking leg or gyro damage
##
## Target number = piloting skill + terrain modifier + damage modifier + maneuver modifier.
## Roll 2d6; if result >= target, the PSR is passed. On failure, the unit falls
## (mechs take fall damage per ton; vehicles may be immobilized).


## Returns a dict with: passed (bool), fall_damage (int, 0 if passed),
## fall_direction (String), description (String).
##
## Parameters:
##   piloting_skill: 1-10 (lower is better)
##   damage_this_phase: total damage taken in the current phase
##   terrain_mod: modifier from terrain being entered (0-3)
##   maneuver_mod: modifier from maneuver attempted (0-4)
##   has_leg_damage: true if a leg is damaged/destroyed (+1 penalty)
##   has_gyro_damage: true if gyro is damaged (+2 penalty)
##   tonnage: unit tonnage (for fall damage calculation)
##   roll: optional pre-rolled 2d6 value
func resolve(piloting_skill: int, damage_this_phase: int = 0, terrain_mod: int = 0,
		maneuver_mod: int = 0, has_leg_damage: bool = false, has_gyro_damage: bool = false,
		tonnage: float = 20.0, roll: int = -1) -> Dictionary:

	var damage_penalty = damage_this_phase / 20
	var leg_penalty = 1 if has_leg_damage else 0
	var gyro_penalty = 2 if has_gyro_damage else 0

	var target = piloting_skill + terrain_mod + maneuver_mod + damage_penalty + leg_penalty + gyro_penalty

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var r = roll if roll >= 2 else rng.randi_range(2, 12)

	var passed = r >= target
	var fall_damage = 0
	if not passed:
		fall_damage = int(tonnage / 10) + rng.randi_range(0, 2)

	return {
		"passed": passed,
		"fall_damage": fall_damage if not passed else 0,
		"roll": r,
		"target": target,
		"description": "PSR %d vs %d: %s" % [r, target, "passed" if passed else "failed (fall %d dmg)" % fall_damage],
	}
