class_name Personnel
extends Resource

@export var personnel_name: String
@export var rank: String
@export var role: Enums.PersonnelRole
@export var body: int = 5
@export var mind: int = 5
@export var reflexes: int = 5
@export var traits: Array[String]
@export var skills: Dictionary
@export var experience: int = 0
@export var is_injured: bool = false
@export var injury_severity: int = 0
@export var date_of_birth: String
@export var assigned_unit_id: String = ""

func is_available() -> bool:
	return not is_injured and assigned_unit_id.is_empty()
