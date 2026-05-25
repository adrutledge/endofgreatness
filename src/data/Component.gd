class_name Component
extends Resource

@export var component_name: String
@export var component_type: String
@export var tonnage: float
@export var critical_slots: int
@export var cost: int
@export var tech_base: String
@export var tech_level: int = 1
@export var quality_range: Vector2
@export var repair_difficulty: int
@export var status: Enums.ComponentStatus = Enums.ComponentStatus.UNDAMAGED
@export var location: ComponentLocation
@export var rear_facing: bool = false
