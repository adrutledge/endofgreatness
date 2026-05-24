extends Node

var personnel_roster: Array[Personnel] = []
var personnel_relationships: Dictionary = {}
var hiring_halls: Dictionary = {}

const SPECIALIZATIONS: Array[String] = ["Mech", "Vehicle", "Aerospace"]

func _ready() -> void:
	TimeManager.date_changed.connect(_on_date_changed)

func _on_date_changed(date: Dictionary) -> void:
	process_aging()

func assign_technician(personnel: Personnel, unit: TacticalUnit) -> bool:
	if personnel.role != Enums.PersonnelRole.TECHNICIAN:
		return false
	if not unit.requires_technician():
		return false
	if not personnel.matches_specialization(unit.unit_type):
		return false
	if not personnel.is_available():
		return false

	personnel.assigned_unit_id = unit.unit_name
	if not unit.assigned_technicians.has(personnel):
		unit.assigned_technicians.append(personnel)
	return true

func unassign_technician(personnel: Personnel, unit: TacticalUnit) -> void:
	personnel.assigned_unit_id = ""
	unit.assigned_technicians.erase(personnel)

func get_repair_hours(personnel: Personnel) -> int:
	return 8

func get_unit_repair_budget(unit: TacticalUnit) -> int:
	var total: int = 0
	for t in unit.assigned_technicians:
		total += get_repair_hours(t)
	return total

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
	var TraitRes = preload("res://src/data/Trait.gd")
	var p = Personnel.new()
	var first_names = ["Alex", "Jordan", "Sam", "Casey", "Taylor", "Morgan", "Riley", "Quinn", "Avery", "Dakota"]
	var last_names = ["Smith", "Jones", "Lee", "Chen", "Patel", "Khan", "Mueller", "Garcia", "Kim", "Singh"]
	p.personnel_name = first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]
	var roles = [Enums.PersonnelRole.CREW, Enums.PersonnelRole.TECHNICIAN, Enums.PersonnelRole.ASTECH, Enums.PersonnelRole.MEDIC, Enums.PersonnelRole.DOCTOR, Enums.PersonnelRole.HR, Enums.PersonnelRole.LOGISTICAL, Enums.PersonnelRole.TRANSPORT, Enums.PersonnelRole.COMMAND, Enums.PersonnelRole.CIVILIAN]
	p.role = roles[randi() % roles.size()]
	p.body = _rand_atow_attr()
	p.dexterity = _rand_atow_attr()
	p.reflexes = _rand_atow_attr()
	p.strength = _rand_atow_attr()
	p.willpower = _rand_atow_attr()
	p.charisma = _rand_atow_attr()
	p.intelligence = _rand_atow_attr()
	p.edge = randi() % 3 + 1
	p.skills = {}
	for s in Enums.get_all_skills():
		p.skills[s] = 0
	p.skills["perception"] = randi() % 6 + 1
	p.skills["language_english"] = randi() % 3 + 4
	p.experience = randi() % 500

	var birth_year = 3025 - (randi() % 48 + 10)
	var birth_month = randi() % 12 + 1
	var birth_day = randi() % 28 + 1
	p.date_of_birth = str(birth_year) + "-" + str(birth_month) + "-" + str(birth_day)
	if 3025 - birth_year < 16:
		p.role = Enums.PersonnelRole.CHILD

	var hair_colors = ["Brown", "Black", "Blonde", "Red", "Grey", "White", "Auburn"]
	var eye_colors = ["Brown", "Blue", "Green", "Grey", "Hazel"]
	p.hair_color = hair_colors[randi() % hair_colors.size()]
	p.eye_color = eye_colors[randi() % eye_colors.size()]
	p.height_cm = randi() % 40 + 150
	p.weight_kg = randi() % 40 + 55

	var faction_codes = []
	for code in GameState.factions:
		faction_codes.append(code)
	if not faction_codes.is_empty():
		p.prior_affiliation = faction_codes[randi() % faction_codes.size()]

	if randi() % 3 < 2:
		var pool = Enums.get_traits_by_category(Enums.TraitCategory.POSITIVE)
		if not pool.is_empty():
			var t_data = pool[randi() % pool.size()]
			var t_rec = TraitRes.new()
			t_rec.id = t_data.id
			t_rec.name = t_data.name
			t_rec.description = t_data.desc
			t_rec.trait_type = TraitRes.TraitType.POSITIVE
			t_rec.effect_type = t_data.get("effect", "")
			t_rec.effect_value = t_data.get("value", 0)
			t_rec.effect_skill = t_data.get("skill", "")
			p.traits.append(t_rec)
	if randi() % 4 == 0:
		var pool = Enums.get_traits_by_category(Enums.TraitCategory.NEGATIVE)
		if not pool.is_empty():
			var t_data = pool[randi() % pool.size()]
			var t_rec = TraitRes.new()
			t_rec.id = t_data.id
			t_rec.name = t_data.name
			t_rec.description = t_data.desc
			t_rec.trait_type = TraitRes.TraitType.NEGATIVE
			t_rec.effect_type = t_data.get("effect", "")
			t_rec.effect_value = t_data.get("value", 0)
			t_rec.effect_skill = t_data.get("skill", "")
			p.traits.append(t_rec)
	match p.role:
		Enums.PersonnelRole.HR:
			p.skills["administration"] = randi() % 5 + 2
			p.skills["negotiation"] = randi() % 4 + 1
			p.skills["leadership"] = randi() % 3 + 1
		Enums.PersonnelRole.LOGISTICAL:
			p.skills["administration"] = randi() % 4 + 2
			p.skills["negotiation"] = randi() % 3 + 1
			p.skills["computers"] = randi() % 5 + 2
			p.skills["science_mathematics"] = randi() % 4 + 1
		Enums.PersonnelRole.TRANSPORT:
			p.skills["administration"] = randi() % 3 + 1
			p.skills["negotiation"] = randi() % 3 + 1
			p.skills["navigation_ground"] = randi() % 4 + 2
			p.skills["navigation_air"] = randi() % 3 + 1
			p.skills["navigation_space"] = randi() % 3 + 1
			p.skills["communications_conventional"] = randi() % 3 + 1
		Enums.PersonnelRole.COMMAND:
			p.skills["administration"] = randi() % 4 + 2
			p.skills["negotiation"] = randi() % 4 + 1
			p.skills["leadership"] = randi() % 5 + 3
			p.skills["strategy"] = randi() % 4 + 2
			p.skills["tactics_land"] = randi() % 4 + 1
		Enums.PersonnelRole.MEDIC:
			p.skills["medic"] = randi() % 5 + 2
			p.skills["survival"] = randi() % 3 + 1
		Enums.PersonnelRole.DOCTOR:
			p.skills["surgery_general"] = randi() % 5 + 2
			p.skills["administration"] = randi() % 4 + 2
			p.skills["negotiation"] = randi() % 3 + 1
		Enums.PersonnelRole.TECHNICIAN:
			p.specialization = SPECIALIZATIONS[randi() % SPECIALIZATIONS.size()]
			match p.specialization:
				"Mech":
					p.skills["tech_mech"] = randi() % 6 + 1
				"Vehicle":
					p.skills["tech_mechanic"] = randi() % 6 + 1
				"Aerospace":
					p.skills["tech_aerospace"] = randi() % 6 + 1
		Enums.PersonnelRole.ASTECH:
			p.skills["astech"] = randi() % 6 + 1
		Enums.PersonnelRole.CREW:
			p.skills["gunnery_mech"] = randi() % 6 + 1
			p.skills["gunnery_ground_vehicle"] = randi() % 6 + 1
			p.skills["piloting_mech"] = randi() % 4 + 1
			p.skills["piloting_ground_vehicle"] = randi() % 4 + 1
			p.skills["small_arms"] = randi() % 4 + 1
			p.skills["stealth"] = randi() % 3 + 1
		Enums.PersonnelRole.CIVILIAN:
			p.skills["career"] = randi() % 4 + 2
			p.skills["negotiation"] = randi() % 3 + 1
		Enums.PersonnelRole.CHILD:
			p.skills["language_english"] = randi() % 3 + 2
			p.skills["running"] = randi() % 3 + 1
	return p

func get_personnel_by_role(role: Enums.PersonnelRole) -> Array[Personnel]:
	var result: Array[Personnel] = []
	for p in personnel_roster:
		if p.role == role:
			result.append(p)
	return result

func get_available_personnel() -> Array[Personnel]:
	var result: Array[Personnel] = []
	for p in personnel_roster:
		if p.is_available():
			result.append(p)
	return result

func search_personnel(query: String) -> Array[Personnel]:
	if query.is_empty():
		return personnel_roster.duplicate()
	var q = query.to_lower()
	var result: Array[Personnel] = []
	for p in personnel_roster:
		if p.personnel_name.to_lower().contains(q):
			result.append(p)
	return result

func get_all_tactical_units() -> Array[TacticalUnit]:
	var units: Array[TacticalUnit] = []
	for ou in GameState.player.organizational_units:
		units.append_array(ou.get_all_tactical_units())
	return units

func assign_personnel_to_unit(personnel: Personnel, unit: TacticalUnit) -> bool:
	if personnel.role == Enums.PersonnelRole.TECHNICIAN:
		return assign_technician(personnel, unit)
	if unit.crew.has(personnel):
		return false
	personnel.assigned_unit_id = unit.unit_name
	unit.crew.append(personnel)
	return true

func unassign_personnel_from_unit(personnel: Personnel, unit: TacticalUnit) -> void:
	if personnel.role == Enums.PersonnelRole.TECHNICIAN:
		unassign_technician(personnel, unit)
		return
	personnel.assigned_unit_id = ""
	unit.crew.erase(personnel)

func get_salary(personnel: Personnel) -> int:
	match personnel.role:
		Enums.PersonnelRole.COMMAND:
			return 3000
		Enums.PersonnelRole.DOCTOR:
			return 2500
		Enums.PersonnelRole.TECHNICIAN:
			return 2000
		Enums.PersonnelRole.MEDIC:
			return 1800
		Enums.PersonnelRole.HR:
			return 1500
		Enums.PersonnelRole.LOGISTICAL:
			return 1500
		Enums.PersonnelRole.TRANSPORT:
			return 1500
		Enums.PersonnelRole.ASTECH:
			return 1200
		Enums.PersonnelRole.CREW:
			return 1000
		Enums.PersonnelRole.CIVILIAN:
			return 500
		Enums.PersonnelRole.CHILD:
			return 0
		_:
			return 0

func _rand_atow_attr() -> int:
	return randi() % 7 + 2

func process_aging() -> void:
	var to_remove: Array[Personnel] = []
	for p in personnel_roster:
		p.experience += 1
		if not p.date_of_birth:
			continue
		var parts = p.date_of_birth.split("-")
		if parts.size() != 3:
			continue
		var birth_year = int(parts[0])
		var birth_month = int(parts[1])
		var birth_day = int(parts[2])
		var date = TimeManager.current_date
		var age_years = date.year - birth_year
		if date.month < birth_month or (date.month == birth_month and date.day < birth_day):
			age_years -= 1
		if age_years >= 65 and date.month == birth_month and date.day == birth_day:
			if randi() % 100 < age_years - 64:
				to_remove.append(p)
				EventBus.emit_event_triggered({
					"type": "personnel_died",
					"name": p.personnel_name,
					"age": age_years,
					"cause": "old_age"
				})
	for p in to_remove:
		fire_personnel(p)
