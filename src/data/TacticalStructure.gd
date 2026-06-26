class_name TacticalStructure
extends Resource

## Runtime representation of a structure on the tactical map.
## Tracks mutable state: current CF decreases with damage, collapsed flag.

@export var hex_q: int
@export var hex_r: int
@export var type: String  # "building", "bridge"
@export var height: int
@export var max_cf: int
@export var current_cf: int
@export var collapsed: bool = false

## Minimum mass required to breach walls on walk-through (ground entry).
## Buildings only. Equals current_cf at full health.
func get_walk_through_block() -> bool:
	return type == "building" and current_cf > 0


## Maximum mass the roof/bridge can support before collapse warning.
func get_collapse_threshold() -> int:
	return current_cf


func apply_damage(damage: int) -> void:
	current_cf = max(0, current_cf - damage)
	if current_cf <= 0 and damage > 0:
		collapsed = true
