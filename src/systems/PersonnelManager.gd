extends Node

var personnel_roster: Array[Personnel] = []
var personnel_relationships: Dictionary = {}
var hiring_halls: Dictionary = {}

func hire_personnel(personnel: Personnel) -> void:
	personnel_roster.append(personnel)
	EventBus.emit_personnel_hired(personnel)

func fire_personnel(personnel: Personnel) -> void:
	personnel_roster.erase(personnel)

func promote_personnel(personnel: Personnel, new_rank: String) -> void:
	personnel.rank = new_rank

func demote_personnel(personnel: Personnel, new_rank: String) -> void:
	personnel.rank = new_rank

func assign_to_unit(personnel: Personnel, unit_id: String) -> void:
	personnel.assigned_unit_id = unit_id

func unassign_personnel(personnel: Personnel) -> void:
	personnel.assigned_unit_id = ""

func injure_personnel(personnel: Personnel, severity: int) -> void:
	personnel.is_injured = true
	personnel.injury_severity = severity

func heal_personnel(personnel: Personnel, medic: Personnel) -> void:
	personnel.is_injured = false
	personnel.injury_severity = 0

func generate_candidates(planet: String, planet_data: Dictionary, has_hiring_hall: bool = false, hall_tier: String = "") -> Array[Personnel]:
	var candidates: Array[Personnel] = []
	var base_count = randi() % 3 + 1
	for i in base_count:
		var p = generate_random_personnel(planet_data)
		candidates.append(p)
	if has_hiring_hall:
		var bonus = 0
		match hall_tier:
			"local":
				bonus = 2
			"regional":
				bonus = 4
			"imperial":
				bonus = 8
		for i in bonus:
			var p = generate_random_personnel(planet_data)
			p.skills["gunnery"] = max(p.skills.get("gunnery", 4) - 1, 0)
			p.skills["piloting"] = max(p.skills.get("piloting", 4) - 1, 0)
			candidates.append(p)
	return candidates

func generate_random_personnel(planet_data: Dictionary) -> Personnel:
	var p = Personnel.new()
	var first_names = ["Alex", "Jordan", "Sam", "Casey", "Taylor", "Morgan", "Riley", "Quinn", "Avery", "Dakota"]
	var last_names = ["Smith", "Jones", "Lee", "Chen", "Patel", "Khan", "Mueller", "Garcia", "Kim", "Singh"]
	p.personnel_name = first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]
	var roles = [Enums.PersonnelRole.CREW, Enums.PersonnelRole.TECHNICIAN, Enums.PersonnelRole.MEDIC, Enums.PersonnelRole.ADMINISTRATOR]
	p.role = roles[randi() % roles.size()]
	p.body = randi() % 6 + 3
	p.mind = randi() % 6 + 3
	p.reflexes = randi() % 6 + 3
	p.skills = {
		"gunnery": randi() % 7,
		"piloting": randi() % 7
	}
	p.experience = randi() % 500
	return p

func process_aging() -> void:
	for p in personnel_roster:
		pass
