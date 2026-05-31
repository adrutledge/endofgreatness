extends Node

## Resolves Control Checks for aerospace fighters, VTOLs, and conventional aircraft.
##
## Unlike ground PSRs, control check failures have varied outcomes:
##   - Stall: aircraft loses altitude but can recover
##   - Spin: uncontrolled descent, possible collision
##   - Collision: aircraft hits terrain or another unit
##
## Triggers include: exceeding max safe thrust, threshold damage, abrupt height changes,
## entering certain atmospheric bands, attempted maneuvers.
##
## Target number = piloting_skill + damage_mod + maneuver_mod + atmospheric_mod.
## The failure effect depends on the margin of failure and the current situation.


## Returns a dict with: passed (bool), effect (String: "stall"/"spin"/"collision"/""),
## altitude_loss (int, in height levels), description (String).
##
## Parameters:
##   piloting_skill: 1-10 (lower is better)
##   threshold_damage: damage taken this phase (triggers check at certain thresholds)
##   height_change: abrupt change in altitude levels attempted
##   maneuver_type: "turn", "loop", "split_s", "vtol_spin", "landing", "" for none
##   atmospheric_mod: modifier for current atmospheric density (0 = standard)
##   is_vtol: true for VTOLs (different failure modes than aerospace)
##   roll: optional pre-rolled 2d6 value
func resolve(piloting_skill: int, threshold_damage: int = 0, height_change: int = 0,
		maneuver_type: String = "", atmospheric_mod: int = 0, is_vtol: bool = false,
		roll: int = -1) -> Dictionary:

	var damage_mod = threshold_damage / 10
	var maneuver_mod = 0
	match maneuver_type:
		"loop": maneuver_mod = 3
		"split_s": maneuver_mod = 4
		"vtol_spin": maneuver_mod = 2
		"landing": maneuver_mod = 1
		"turn": maneuver_mod = max(0, height_change - 1)

	var target = piloting_skill + damage_mod + maneuver_mod + atmospheric_mod

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var r = roll if roll >= 2 else rng.randi_range(2, 12)

	var passed = r >= target
	var effect = ""
	var altitude_loss = 0

	if not passed:
		var margin = target - r
		if is_vtol:
			if margin <= 2:
				effect = "stall"
				altitude_loss = 1
			elif margin <= 4:
				effect = "spin"
				altitude_loss = 2 + (margin - 2)
			else:
				effect = "collision"
				altitude_loss = 999
		else:
			if margin <= 1:
				effect = "stall"
				altitude_loss = 1
			elif margin <= 3:
				effect = "spin"
				altitude_loss = 3 + (margin - 1)
			else:
				effect = "collision"
				altitude_loss = 999

	return {
		"passed": passed,
		"effect": effect,
		"altitude_loss": altitude_loss,
		"roll": r,
		"target": target,
		"description": "Control check %d vs %d: %s" % [r, target, "passed" if passed else effect],
	}
