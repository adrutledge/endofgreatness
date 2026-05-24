class_name Personnel
extends Resource

@export var personnel_name: String
@export var rank: String
@export var role: Enums.PersonnelRole

# A Time of War attributes (2–10)
@export var body: int = 5
@export var dexterity: int = 5
@export var reflexes: int = 5
@export var strength: int = 5
@export var willpower: int = 5
@export var charisma: int = 5
@export var intelligence: int = 5
@export var edge: int = 1

@export var traits: Array
@export var wealth: int = 0
@export var highest_education: Enums.EducationLevel = Enums.EducationLevel.EARLY_CHILDHOOD
@export var reputation: int = 0
@export var skills: Dictionary = {}
@export var experience: int = 0
@export var is_injured: bool = false
@export var injury_severity: int = 0
@export var date_of_birth: String
@export var assigned_unit_id: String = ""

@export var affiliation: String = ""
@export var prior_affiliation: String = ""
@export var height_cm: int = 170
@export var weight_kg: int = 70
@export var hair_color: String = ""
@export var eye_color: String = ""
@export var description: String = ""

## Technician-only: "Mech", "Vehicle", "Aerospace"
@export var specialization: String = ""

func get_age() -> int:
	if not date_of_birth or not TimeManager:
		return 25
	var parts = date_of_birth.split("-")
	if parts.size() != 3:
		return 25
	var birth_year = int(parts[0])
	var birth_month = int(parts[1])
	var birth_day = int(parts[2])
	var date = TimeManager.current_date
	var age = date.year - birth_year
	if date.month < birth_month or (date.month == birth_month and date.day < birth_day):
		age -= 1
	return max(age, 0)

func has_trait(trait_id: String) -> bool:
	for t in traits:
		if t.id == trait_id:
			return true
	return false

func is_available() -> bool:
	return not is_injured and assigned_unit_id.is_empty()

func matches_specialization(unit_type: Enums.UnitType) -> bool:
	match unit_type:
		Enums.UnitType.MECH:
			return specialization == "Mech"
		Enums.UnitType.VEHICLE:
			return specialization == "Vehicle"
		_:
			return false

func get_tech_skill() -> int:
	match specialization:
		"Mech":
			return skills.get("tech_mech", 0)
		"Vehicle":
			return skills.get("tech_mechanic", 0)
		"Aerospace":
			return skills.get("tech_aerospace", 0)
	return 0

func get_repair_target_modifier() -> int:
	var skill = get_tech_skill()
	if skill <= 0:
		return 5
	elif skill <= 2:
		return 2
	elif skill <= 5:
		return 0
	elif skill <= 7:
		return -2
	return -3

func get_tech_skill_label() -> String:
	var skill = get_tech_skill()
	if skill <= 0:
		return "Untrained"
	elif skill <= 2:
		return "Green"
	elif skill <= 5:
		return "Regular"
	elif skill <= 7:
		return "Veteran"
	return "Elite"

func get_effective_gunnery(subskill: String = "mech") -> int:
	var base = skills.get("gunnery_" + subskill, 5)
	var ref_mod = (reflexes - 5) * -1
	return clampi(base + ref_mod, 1, 10)

func get_effective_piloting(subskill: String = "mech") -> int:
	var base = skills.get("piloting_" + subskill, 5)
	var ref_mod = (reflexes - 5) * -1
	return clampi(base + ref_mod, 1, 10)
