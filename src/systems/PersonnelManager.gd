extends Node

const _Relation = preload("res://src/data/Relation.gd")

var personnel_roster: Array[Personnel] = []
var personnel_relationships: Dictionary = {}
var hiring_halls: Dictionary = {}
var abstract_astech_count: int = 0
var abstract_medic_count: int = 0

const SPECIALIZATIONS: Array[String] = ["Mech", "Vehicle", "Aerospace"]

static var _type_data: Dictionary = {}
static var _type_loaded: bool = false

static func _load_type_data() -> Dictionary:
	if _type_loaded:
		return _type_data
	var merged: Dictionary = {"roles": {}}
	var dir = DirAccess.open("res://data/personnel_types/")
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".json"):
				var file = FileAccess.open("res://data/personnel_types/" + fname, FileAccess.READ)
				if file:
					var j = JSON.new()
					if j.parse(file.get_as_text()) == OK:
						var data = j.data
						if data.has("roles"):
							for k in data.roles:
								merged.roles[k] = data.roles[k]
						for field in ["first_names", "last_names", "hair_colors", "eye_colors"]:
							if data.has(field) and not merged.has(field):
								merged[field] = data[field]
			fname = dir.get_next()
	_type_data = merged
	_type_loaded = true
	return merged

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)

func _on_day_started(date: Dictionary) -> void:
	process_aging()
	_process_healing_ticks()
	_refresh_candidates()

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
	var base := 8
	var admin = personnel.skills.get("administration", 0)
	base += admin * 2
	return base

func get_unit_repair_budget(unit: TacticalUnit) -> int:
	var total: int = 0
	for t in unit.assigned_technicians:
		total += get_repair_hours(t)
	return total

func hire_personnel(personnel: Personnel) -> void:
	personnel_roster.append(personnel)
	EventBus.emit_personnel_joined(personnel, "hired", {})

func remove_personnel(personnel: Personnel, reason: String, details: Dictionary = {}) -> void:
	personnel_roster.erase(personnel)
	EventBus.emit_personnel_left(personnel, reason, details)

func promote_personnel(personnel: Personnel, new_rank: String) -> void:
	personnel.rank = new_rank

func demote_personnel(personnel: Personnel, new_rank: String) -> void:
	personnel.rank = new_rank

func assign_to_unit(personnel: Personnel, unit_id: String) -> void:
	personnel.assigned_unit_id = unit_id

func unassign_personnel(personnel: Personnel) -> void:
	personnel.assigned_unit_id = ""

func injure_personnel(personnel: Personnel, severity: int) -> void:
	if personnel.is_injured:
		return
	personnel.is_injured = true
	personnel.injury_severity = severity


func heal_personnel(personnel: Personnel, doctor: Personnel) -> bool:
	if not personnel.is_injured:
		return false
	if doctor.role != Enums.PersonnelRole.DOCTOR:
		return false
	if doctor.patients_assigned.size() >= doctor.patient_capacity:
		return false

	if not doctor.patients_assigned.has(personnel):
		doctor.patients_assigned.append(personnel)
	personnel.is_injured = false
	personnel.injury_severity = 0
	return true


func assign_to_healing(personnel: Personnel, doctor: Personnel) -> bool:
	if not personnel.is_injured:
		return false
	if doctor.role != Enums.PersonnelRole.DOCTOR:
		return false
	if doctor.patients_assigned.size() >= doctor.patient_capacity:
		return false

	if not doctor.patients_assigned.has(personnel):
		doctor.patients_assigned.append(personnel)

	var severity: int = personnel.injury_severity
	var admin: int = doctor.skills.get("administration", 0)
	var base_days: int = severity * 7
	var reduced: int = max(1, base_days - admin * 2)
	personnel.healing_days_total = reduced
	personnel.healing_days_remaining = reduced
	return true


func _process_healing_ticks() -> void:
	var healed: Array[Personnel] = []
	for p in personnel_roster:
		if p.is_injured and p.healing_days_remaining > 0:
			p.healing_days_remaining -= 1
			if p.healing_days_remaining <= 0:
				p.is_injured = false
				p.injury_severity = 0
				p.healing_days_total = 0
				healed.append(p)
				for doc in personnel_roster:
					if doc.role == Enums.PersonnelRole.DOCTOR and doc.patients_assigned.has(p):
						doc.patients_assigned.erase(p)
						break
	for p in healed:
		EventBus.emit_event_triggered({
			"type": "personnel_healed",
			"name": p.personnel_name,
		})

var _candidate_pool: Array[Personnel] = []
var _last_candidate_refresh_day: int = -1


func get_candidate_pool() -> Array[Personnel]:
	if _candidate_pool.is_empty() or _last_candidate_refresh_day != TimeManager.total_days:
		_refresh_candidates()
	return _candidate_pool


func _refresh_candidates() -> void:
	var today = TimeManager.total_days
	if _last_candidate_refresh_day == today:
		return
	_last_candidate_refresh_day = today
	if not GameState.player or not GameState.player.current_planet:
		return
	var planet_data = DataManager.systems_data.get(GameState.player.current_planet, {})
	_candidate_pool = generate_candidates(GameState.player.current_planet, planet_data, false, "")
	if _candidate_pool.is_empty():
		_candidate_pool = generate_candidates(GameState.player.current_planet, planet_data, true, "local")


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
	var td = _load_type_data()
	var TraitRes = preload("res://src/data/Trait.gd")
	var p = Personnel.new()

	var faction_first: Array = []
	var faction_last: Array = []
	var faction_code = ""
	var fk = []
	for code in GameState.factions:
		fk.append(code)
	if not fk.is_empty():
		faction_code = fk[randi() % fk.size()]
		var fdata = GameState.factions.get(faction_code, {})
		if fdata:
			faction_first = fdata.get("first_names", [])
			faction_last = fdata.get("last_names", [])
	var first_names: Array = faction_first if not faction_first.is_empty() else td.get("first_names", ["Alex", "Jordan"])
	var last_names: Array = faction_last if not faction_last.is_empty() else td.get("last_names", ["Smith", "Jones"])
	p.personnel_name = first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]
	p.prior_affiliation = faction_code
	var roles = [Enums.PersonnelRole.MECHWARRIOR, Enums.PersonnelRole.CREW, Enums.PersonnelRole.TECHNICIAN, Enums.PersonnelRole.ASTECH, Enums.PersonnelRole.MEDIC, Enums.PersonnelRole.DOCTOR, Enums.PersonnelRole.HR, Enums.PersonnelRole.LOGISTICAL, Enums.PersonnelRole.TRANSPORT, Enums.PersonnelRole.COMMAND, Enums.PersonnelRole.CIVILIAN]
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

	var fdata = GameState.factions.get(faction_code, {})
	var hair_src: Array = fdata.get("hair_colors", td.get("hair_colors", ["Brown", "Black"]))
	var eye_src: Array = fdata.get("eye_colors", td.get("eye_colors", ["Brown", "Blue"]))
	p.hair_color = hair_src[randi() % hair_src.size()]
	p.eye_color = eye_src[randi() % eye_src.size()]
	p.height_cm = randi() % 40 + 150
	p.weight_kg = randi() % 40 + 55

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
	var role_key = Enums.PersonnelRole.keys()[p.role]
	var role_def = td.get("roles", {}).get(role_key, {})
	var skills_def: Array = role_def.get("skills", [])
	for s in skills_def:
		var sname = s.get("name", "")
		if sname.is_empty():
			continue
		var smin = s.get("min", 1)
		var smax = s.get("max", 5)
		var weight = s.get("weight", 3)
		if s.has("specialization"):
			var spec_pool: Array = s.get("specialization_pool", SPECIALIZATIONS)
			p.specialization = spec_pool[randi() % spec_pool.size()]
		if s.get("select_one", false):
			var roll = randi() % 100
			if roll < weight * 20:
				p.skills[sname] = randi() % (smax - smin + 1) + smin
		else:
			p.skills[sname] = randi() % (smax - smin + 1) + smin

	var rare: Array = role_def.get("rare_skills", [])
	for rs in rare:
		var chance = rs.get("chance", 0.0)
		if randf() < chance:
			var rname = rs.get("name", "")
			var pname = rs.get("pilot_name", "")
			if rname and pname:
				p.skills[rname] = max(1, randi() % rs.get("max", 4))
				p.skills[pname] = max(1, randi() % rs.get("max", 4))
	return p

func add_relationship(from_name: String, to_name: String, type: int, valence: int = 1, strength: int = 1) -> void:
	if not personnel_relationships.has(from_name):
		personnel_relationships[from_name] = []
	var rel = _Relation.new()
	rel.type = type
	rel.target_name = to_name
	rel.valence = valence
	rel.strength = strength
	personnel_relationships[from_name].append(rel)


func get_relationships(personnel_name: String) -> Array:
	return personnel_relationships.get(personnel_name, [])


func get_relationship_with(personnel_name: String, target_name: String):
	for r in get_relationships(personnel_name):
		if r.target_name == target_name:
			return r
	return null


func has_relationship(personnel_name: String, target_name: String, type: int) -> bool:
	for r in get_relationships(personnel_name):
		if r.target_name == target_name and r.type == type:
			return true
	return false


func remove_relationship(personnel_name: String, target_name: String, type: int) -> void:
	if not personnel_relationships.has(personnel_name):
		return
	personnel_relationships[personnel_name] = personnel_relationships[personnel_name].filter(
		func(r): return not (r.target_name == target_name and r.type == type)
	)


func get_effective_skill(personnel: Personnel, skill_name: String) -> int:
	var base = personnel.skills.get(skill_name, 0)
	if personnel.secondary_role >= 0:
		base = int(ceil(base * 0.5))
	return base


func get_healing_time_modifier(doctor: Personnel) -> float:
	var admin = doctor.skills.get("administration", 0)
	return max(0.3, 1.0 - admin * 0.05)


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

	if unit.unit_type != Enums.UnitType.MECH and unit.crew.size() >= 1:
		unit.abstract_crew_count += 1
		return true

	personnel.assigned_unit_id = unit.unit_name
	unit.crew.append(personnel)
	return true

func unassign_personnel_from_unit(personnel: Personnel, unit: TacticalUnit) -> void:
	if personnel.role == Enums.PersonnelRole.TECHNICIAN:
		unassign_technician(personnel, unit)
		return
	if unit.crew.has(personnel):
		personnel.assigned_unit_id = ""
		unit.crew.erase(personnel)
		return
	if unit.abstract_crew_count > 0:
		unit.abstract_crew_count -= 1

func get_salary(personnel: Personnel) -> int:
	var td = _load_type_data()
	var role_key = Enums.PersonnelRole.keys()[personnel.role]
	var role_def = td.get("roles", {}).get(role_key, {})
	return role_def.get("salary", 0)

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
			remove_personnel(p, "died_old_age", {})


func get_doctor_patient_count(doctor: Personnel) -> int:
	return doctor.patients_assigned.size()


func get_doctor_available_capacity(doctor: Personnel) -> int:
	if doctor.role != Enums.PersonnelRole.DOCTOR:
		return 0
	return max(0, doctor.patient_capacity - doctor.patients_assigned.size())


func get_abstract_salary_cost() -> int:
	# Astechs paid at ASTECH rate, medics at MEDIC rate
	var cost := 0
	cost += abstract_astech_count * get_role_daily_salary(Enums.PersonnelRole.ASTECH)
	cost += abstract_medic_count * get_role_daily_salary(Enums.PersonnelRole.MEDIC)
	return cost


func get_role_daily_salary(role: Enums.PersonnelRole) -> int:
	var td = _load_type_data()
	var role_key = Enums.PersonnelRole.keys()[role]
	var role_def = td.get("roles", {}).get(role_key, {})
	return role_def.get("salary", 0)

