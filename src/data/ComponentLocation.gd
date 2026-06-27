class_name ComponentLocation
extends Resource

@export var location_name: String
@export var hit_chance: float
@export var armor: int
@export var rear_armor: int = 0
@export var structure: int
@export var max_armor: int
@export var max_structure: int
# TODO: save migration — when blown_off and hex_position fields are added for
# the crit system's blown-off location mechanic, add serialization in
# SaveSerializer and a migration in SaveManager._migrate_vN()
