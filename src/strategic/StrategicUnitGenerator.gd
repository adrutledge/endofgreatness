class_name StrategicUnitGenerator
extends RefCounted

## Configurable defaults (hardcoded for now; can be exposed to settings later)
const DICE_COUNT: int = 20
const FLOOR_CSB: int = 10_000_000
const MECH_COUNT: int = 12

var _RATParser = null
var _GameState = null
var _DataManager = null
var _PersonnelManager = null

func _get_rat_parser():
	if _RATParser == null:
		_RATParser = load("res://src/strategic/RATParser.gd")
	return _RATParser

func _get_gs():
	if _GameState == null:
		var ml = Engine.get_main_loop() as SceneTree
		if ml and ml.root:
			_GameState = ml.root.get_node_or_null("/root/GameState") as Node
	return _GameState


func _get_dm():
	if _DataManager == null:
		var ml = Engine.get_main_loop() as SceneTree
		if ml and ml.root:
			_DataManager = ml.root.get_node_or_null("/root/DataManager") as Node
	return _DataManager


func _get_pm():
	if _PersonnelManager == null:
		var ml = Engine.get_main_loop() as SceneTree
		if ml and ml.root:
			_PersonnelManager = ml.root.get_node_or_null("/root/PersonnelManager") as Node
	return _PersonnelManager

const FIRST_NAMES: Array[String] = [
	"Aaron", "Adelaide", "Alejandro", "Alexei", "Amara", "Andrei", "Anya", "Aria",
	"Bao", "Bianca", "Boris", "Bram", "Brianna", "Callum", "Caoimhe", "Carlos",
	"Catherine", "Chang", "Chloe", "Connor", "Daisy", "Dmitri", "Elena", "Eliza",
	"Emile", "Ethan", "Fatima", "Felix", "Fiona", "Gabriel", "Grace", "Gregor",
	"Haruki", "Hassan", "Helena", "Hiroshi", "Ingrid", "Iris", "Ivan", "Jade",
	"Jasper", "Jian", "Johannes", "Juno", "Kai", "Katarina", "Keiko", "Kenji",
	"Lars", "Leila", "Liam", "Lin", "Lucia", "Luna", "Magnus", "Mai", "Marco",
	"Maren", "Mateo", "Mei", "Mia", "Mikhail", "Ming", "Nadia", "Naomi", "Natalia",
	"Natasha", "Niko", "Noa", "Noor", "Olga", "Omar", "Orion", "Oscar",
	"Priya", "Quinn", "Rafael", "Raina", "Raj", "Ravi", "Ren", "Rico",
	"Rosa", "Rumi", "Sakura", "Sasha", "Sergei", "Shin", "Sofia", "Soren",
	"Takeshi", "Tala", "Tamara", "Tara", "Tomas", "Valentin", "Vasily", "Viktor",
	"Wei", "Xander", "Yuki", "Yusuf", "Zara", "Zoe",
]

const LAST_NAMES: Array[String] = [
	"Adams", "Ahn", "Al-Rashid", "Allard", "Bain", "Banzai", "Bennett", "Bishop",
	"Blake", "Browning", "Cameron", "Campbell", "Carson", "Cheng", "Chou", "Clarke",
	"Cooper", "Cortez", "Davion", "Decker", "DeVries", "Doyle", "Drake", "Dubois",
	"Edwards", "Eriksson", "Falk", "Fischer", "Fletcher", "Foster", "Fujita", "Garcia",
	"Garrett", "Grant", "Grayson", "Guerrero", "Hasek", "Hayes", "Hendricks", "Hernandez",
	"Holt", "Hughes", "Ito", "Ivanova", "Jacobs", "Jansen", "Jenkins", "Jorgensson",
	"Kai", "Kane", "Katz", "Kawasaki", "Khan", "Kim", "Kincaid", "Kobayashi",
	"Kowalski", "Krause", "Kurita", "Lakshmi", "Lancaster", "Larkin", "Liao", "Lopes",
	"Lucas", "Mackenzie", "Maddox", "Mao", "Marik", "Marshall", "Martinez", "Mason",
	"Matsuoka", "McCall", "McKenna", "Mendez", "Meyer", "Mikhailov", "Miller", "Mori",
	"Morrison", "Mueller", "Murphy", "Nakamura", "Nash", "Navarro", "Ngo", "Nguyen",
	"Nikolaev", "Nova", "O'Neal", "O'Sullivan", "Okada", "Okafor", "Ortiz", "Oshiro",
	"Parker", "Patel", "Patterson", "Petrov", "Powell", "Quinn", "Ramos", "Razak",
	"Reed", "Reyes", "Richards", "Riley", "Rodriguez", "Romanov", "Rossi", "Royce",
	"Sakamoto", "Sato", "Schmidt", "Schultz", "Scott", "Sharma", "Sheffield", "Shin",
	"Singh", "Smith", "Sorensen", "Soto", "Steiner", "Sterling", "Stuart", "Suzuki",
	"Tanaka", "Tanner", "Tate", "Taylor", "Thompson", "Torres", "Tremaine", "Turner",
	"Ueda", "Valentine", "Vargas", "Vasquez", "Volkov", "Wagner", "Walker", "Wang",
	"Watanabe", "Watson", "Williams", "Wilson", "Yamada", "Yamamoto", "Yoshida", "Zhang",
	"Zhao", "Zimmerman",
]

const MERC_COMPANY_NAMES: Array[String] = [
	"Acheron Guard", "Anvil Company", "Arclight Lance", "Avalon's Fury",
	"Black Talon Company", "Bloody Hammers", "Bolt Action", "Bone Crushers",
	"Brass Scorpions", "Bronze Dragoons", "Burning Suns", "Cobalt Vanguard",
	"Cold Steel Brigade", "Crimson Guard", "Crimson Howlers", "Dark Horse Company",
	"Death's Head Battalion", "Diamond Edge", "Dragon's Teeth", "Dust Devils",
	"Eagle's Talon", "Ebony Company", "Ember Wolves", "Falcon's Claw",
	"Fire for Effect", "Firestorm Lancers", "Frost Giants", "Ghost Legion",
	"Golden Hawks", "Grave Walkers", "Gray Death Legion", "Griffin's Roar",
	"Hammer Down", "Hammer's Slammers", "Hard Corps", "Hell's Highway",
	"Hired Steel", "Hollow Ground", "Howling Furies", "Ice Storm Company",
	"Iron Blood", "Iron Dwarves", "Iron Golems", "Ivory Lancers",
	"Jade Talon", "Juggernaut Company", "King's Own", "Knight's Errant",
	"Laughing Skulls", "Legion of the Damned", "Lightning Company",
	"Lone Wolves", "Long Knives", "Los Diablos", "Marauders of Death",
	"Midnight Sons", "Misfit Toys", "Moon Stalkers", "Mountain Men",
	"Night Hawks", "Night's Watch", "No Quarter", "Obsidian Company",
	"Old Guard", "Omega Company", "Orion's Belt", "Outlaw Star",
	"Peregrine Company", "Phoenix Guard", "Polar Bear Company", "Raging Bulls",
	"Rapid Fire", "Raven's Claw", "Red Death", "Renegade Legion",
	"Rising Sun", "Road Runners", "Rough Riders", "Royal Guard",
	"Sable Company", "Salamander Company", "Sand Devils", "Screaming Eagles",
	"Shadow Company", "Shield of Terra", "Silver Blades", "Skull Crushers",
	"Sky Lancers", "Snake Eaters", "Solar Guard", "Steel Jaguars",
	"Storm Riders", "Sword of the People", "Talon Company", "The Chosen",
	"The Few", "The Pack", "Thunder Company", "Thunderbolts",
	"Tiger's Claw", "Tin Hats", "Titan Company", "Valiant Guard",
	"Valkyrie Squadron", "Vanguard Company", "Venom Company", "War Pigs",
	"Warrior's Pride", "White Death", "Wild Geese", "Wraith Company",
	"Yellow Jackets", "Zephyr Company", "Zero Company",
]

const PERSONNEL_ROLE_NAMES: Dictionary = {
	Enums.PersonnelRole.CREW: "Crew",
	Enums.PersonnelRole.TECHNICIAN: "Technician",
	Enums.PersonnelRole.DOCTOR: "Doctor",
	Enums.PersonnelRole.HR: "HR",
	Enums.PersonnelRole.LOGISTICAL: "Logistics",
	Enums.PersonnelRole.TRANSPORT: "Transport",
	Enums.PersonnelRole.COMMAND: "Command",
}

const RANK_TITLES: Dictionary = {
	Enums.PersonnelRole.CREW: ["Private", "Lance Corporal", "Corporal", "Sergeant"],
	Enums.PersonnelRole.TECHNICIAN: ["Tech Apprentice", "Tech", "Senior Tech", "Master Tech"],
	Enums.PersonnelRole.DOCTOR: ["Intern", "Physician", "Senior Physician", "Chief Surgeon"],
	Enums.PersonnelRole.HR: ["Clerk", "Officer", "Senior Officer", "Director"],
	Enums.PersonnelRole.LOGISTICAL: ["Logistics Clerk", "Logistics Officer", "Logistics Chief", "Supply Director"],
	Enums.PersonnelRole.TRANSPORT: ["Transport Clerk", "Transport Officer", "Transport Chief", "Movement Director"],
	Enums.PersonnelRole.COMMAND: ["Aide", "Staff Officer", "Senior Staff", "Chief of Staff"],
}


func generate(faction_code: String, company_name: String = "", mech_count: int = MECH_COUNT) -> Dictionary:
	var rat_data = _get_rat_parser().load_rat(faction_code)
	if rat_data.is_empty():
		return { "success": false, "error": "Failed to load RAT data for %s" % faction_code }

	var starting_float = _roll_starting_float()
	var company = company_name if not company_name.is_empty() else _pick_company_name()

	var mechs = _generate_mechs(rat_data, mech_count)
	if mechs.is_empty():
		return { "success": false, "error": "Failed to generate any mechs" }

	var mech_cost = _sum_mech_cost(mechs)
	var remaining = starting_float - mech_cost

	var pilots = _generate_pilots(mechs)
	_assign_pilot_to_mechs(pilots, mechs)

	_select_command_staff(pilots)
	_assign_lance_commanders(pilots, mechs)

	var technicians = _generate_technicians(mechs)
	var admin_staff = _generate_admin_staff(mechs, pilots, technicians)

	var doctor = _generate_doctor()
	var abstract_medics = 6
	var abstract_astechs = technicians.size() * 2

	var inventory = _calculate_inventory(mechs, faction_code, rat_data)
	var inv_cost = _sum_inventory_cost(inventory)
	remaining -= inv_cost

	if remaining < FLOOR_CSB:
		remaining = FLOOR_CSB

	var strategic = _build_organization(company, mechs, pilots, faction_code)
	strategic.current_balance = max(remaining, 0)

	var home_world = _pick_starting_system(faction_code)

	var gs = _get_gs()
	if gs:
		gs.player = strategic
		gs.player_inventory = inventory
		gs.player.current_planet = "Galatea"

	var all_personnel: Array[Personnel] = []
	all_personnel.append_array(pilots)
	all_personnel.append_array(technicians)
	all_personnel.append_array(admin_staff)
	all_personnel.append(doctor)

	var pm = _get_pm()
	for p in all_personnel:
		p.is_founder = true
		p.originating_faction = faction_code
		p.home_system = home_world
		p.home_planet = home_world
		if pm:
			pm.personnel_roster.append(p)

	if pm:
		pm.abstract_astech_count += abstract_astechs
		pm.abstract_medic_count += abstract_medics

		var lance_size = 4
		for lance_start in range(0, mechs.size(), lance_size):
			var lance_end = min(lance_start + lance_size, mechs.size())
			var lance_pilots: Array[Personnel] = []
			for i in range(lance_start, lance_end):
				if i < pilots.size():
					lance_pilots.append(pilots[i])
			for i in range(lance_pilots.size()):
				for j in range(i + 1, lance_pilots.size()):
					if randi() % 100 < 40:
						pm.add_relationship(lance_pilots[i].personnel_name, lance_pilots[j].personnel_name, Enums.RelationshipType.FRIENDSHIP, 1, randi() % 3 + 1)
						pm.add_relationship(lance_pilots[j].personnel_name, lance_pilots[i].personnel_name, Enums.RelationshipType.FRIENDSHIP, 1, randi() % 3 + 1)
					if randi() % 100 < 15:
						pm.add_relationship(lance_pilots[i].personnel_name, lance_pilots[j].personnel_name, Enums.RelationshipType.WINGMAN, 1, randi() % 3 + 1)
						pm.add_relationship(lance_pilots[j].personnel_name, lance_pilots[i].personnel_name, Enums.RelationshipType.WINGMAN, 1, randi() % 3 + 1)

		for p in pilots:
			if p.is_commander:
				for q in pilots:
					if q.is_xo:
						pm.add_relationship(p.personnel_name, q.personnel_name, Enums.RelationshipType.FRIENDSHIP, 1, randi() % 3 + 2)
						pm.add_relationship(q.personnel_name, p.personnel_name, Enums.RelationshipType.FRIENDSHIP, 1, randi() % 3 + 2)
						break

		for i in range(all_personnel.size()):
			for j in range(i + 1, all_personnel.size()):
				if randi() % 100 < 5:
					pm.add_relationship(all_personnel[i].personnel_name, all_personnel[j].personnel_name, Enums.RelationshipType.LOVER, 1, randi() % 3 + 1)
					pm.add_relationship(all_personnel[j].personnel_name, all_personnel[i].personnel_name, Enums.RelationshipType.LOVER, 1, randi() % 3 + 1)

		for i in range(all_personnel.size()):
			for j in range(i + 1, all_personnel.size()):
				if randi() % 100 < 8:
					pm.add_relationship(all_personnel[i].personnel_name, all_personnel[j].personnel_name, Enums.RelationshipType.DISLIKE, -1, randi() % 3 + 1)
					pm.add_relationship(all_personnel[j].personnel_name, all_personnel[i].personnel_name, Enums.RelationshipType.DISLIKE, -1, randi() % 3 + 1)
				if randi() % 100 < 5:
					pm.add_relationship(all_personnel[i].personnel_name, all_personnel[j].personnel_name, Enums.RelationshipType.RIVAL, -1, randi() % 3 + 1)
					pm.add_relationship(all_personnel[j].personnel_name, all_personnel[i].personnel_name, Enums.RelationshipType.RIVAL, -1, randi() % 3 + 1)

	if gs:
		gs.log_event("game_started", {
			"company": company,
			"faction": faction_code,
			"mech_count": mechs.size(),
			"personnel_count": all_personnel.size(),
			"starting_float": starting_float,
			"remaining": remaining,
			"planet": home_world,
		})

	return {
		"success": true,
		"company": company,
		"mech_count": mechs.size(),
		"personnel_count": all_personnel.size(),
		"starting_float": starting_float,
		"remaining_balance": remaining,
		"starting_planet": home_world,
	}


func _roll_starting_float() -> int:
	var total = 0
	for i in range(DICE_COUNT):
		total += randi() % 6 + 1
	var amount = total * 1_000_000
	if amount < FLOOR_CSB:
		amount = FLOOR_CSB
	return amount


func _generate_mechs(rat_data: Dictionary, count: int) -> Array[TacticalUnit]:
	var result: Array[TacticalUnit] = []
	var weight_classes = ["Light", "Medium", "Heavy", "Assault"]

	for i in range(count):
		var wc = weight_classes[randi() % weight_classes.size()]
		var chassis_name = _get_rat_parser().roll_on_table(rat_data, wc)
		if chassis_name.is_empty():
			continue

		var dm = _get_dm()
		var template = dm.unit_templates.get(chassis_name) if dm else null
		if template == null:
			continue

		var unit = _deep_copy_unit(template)
		unit.quality = _random_quality()

		if randi() % 3 == 0:
			_randomize_component_condition(unit)

		result.append(unit)

	return result


func _deep_copy_unit(source: TacticalUnit) -> TacticalUnit:
	var unit = TacticalUnit.new()
	unit.unit_name = source.unit_name
	unit.chassis_name = source.chassis_name
	unit.model_name = source.model_name
	unit.unit_type = source.unit_type
	unit.engine_rating = source.engine_rating
	unit.engine_type = source.engine_type
	unit.gyro_type = source.gyro_type
	unit.internal_structure_type = source.internal_structure_type
	unit.armor_type = source.armor_type
	unit.total_armor_points = source.total_armor_points
	unit.heat_sink_count = source.heat_sink_count
	unit.tonnage = source.tonnage
	unit.movement_mp = source.movement_mp
	unit.run_mp = source.run_mp
	unit.jump_mp = source.jump_mp
	unit.motion_type = source.motion_type
	unit.abstract_crew_count = source.abstract_crew_count

	for c in source.components:
		var copy = Component.new()
		copy.component_name = c.component_name
		copy.component_type = c.component_type
		copy.tonnage = c.tonnage
		copy.critical_slots = c.critical_slots
		copy.cost = c.cost
		copy.tech_base = c.tech_base
		copy.tech_level = c.tech_level
		copy.quality_range = c.quality_range
		copy.repair_difficulty = c.repair_difficulty
		copy.status = Enums.ComponentStatus.UNDAMAGED
		if c.location:
			var loc_copy = ComponentLocation.new()
			loc_copy.location_name = c.location.location_name
			loc_copy.hit_chance = c.location.hit_chance
			loc_copy.armor = c.location.armor
			loc_copy.rear_armor = c.location.rear_armor
			loc_copy.structure = c.location.structure
			loc_copy.max_armor = c.location.max_armor
			loc_copy.max_structure = c.location.max_structure
			copy.location = loc_copy
		unit.components.append(copy)

	return unit


func _random_quality() -> Enums.Quality:
	var roll = randi() % 100
	if roll < 30:
		return Enums.Quality.F
	elif roll < 55:
		return Enums.Quality.E
	elif roll < 75:
		return Enums.Quality.D
	elif roll < 90:
		return Enums.Quality.C
	elif roll < 97:
		return Enums.Quality.B
	else:
		return Enums.Quality.A


func _randomize_component_condition(unit: TacticalUnit) -> void:
	for c in unit.components:
		if randi() % 10 == 0:
			var status_roll = randi() % 3
			match status_roll:
				0:
					c.status = Enums.ComponentStatus.DAMAGED
				1:
					c.status = Enums.ComponentStatus.DESTROYED


func _sum_mech_cost(mechs: Array[TacticalUnit]) -> int:
	var total = 0
	for m in mechs:
		total += m.calculate_tm_cost()
	return total


func _generate_pilots(mechs: Array[TacticalUnit]) -> Array[Personnel]:
	var count = mechs.size() + max(1, mechs.size() / 4)
	var pilots: Array[Personnel] = []

	for i in range(count):
		var p = _base_personnel(Enums.PersonnelRole.CREW)
		p.rank = RANK_TITLES[Enums.PersonnelRole.CREW][randi() % RANK_TITLES[Enums.PersonnelRole.CREW].size()]

		var gunnery = clampi(randi() % 5 + 1, 1, 10)
		var piloting = clampi(randi() % 5 + 1, 1, 10)
		var leadership = randi() % 5 + 1
		var tactics = randi() % 5 + 1
		var strategy_val = randi() % 5 + 1
		var training = randi() % 5 + 1

		p.skills["gunnery_mech"] = gunnery
		p.skills["gunnery_ground_vehicle"] = gunnery
		p.skills["piloting_mech"] = piloting
		p.skills["piloting_ground_vehicle"] = piloting
		p.skills["small_arms"] = randi() % 4 + 1
		p.skills["leadership"] = leadership
		p.skills["tactics_land"] = tactics
		p.skills["strategy"] = strategy_val
		p.skills["training"] = training

		p.skills["perception"] = randi() % 5 + 2
		p.skills["sensor_operations"] = randi() % 4 + 1

		pilots.append(p)

	_pilot_skill_correlation(pilots)

	return pilots


func _pilot_skill_correlation(pilots: Array[Personnel]) -> void:
	for p in pilots:
		var cmd_score = p.skills.get("leadership", 1) + p.skills.get("tactics_land", 1) + p.skills.get("strategy", 1)
		var combat_sum = p.skills.get("gunnery_mech", 5) + p.skills.get("piloting_mech", 5)
		var target_combat = clampi(int(cmd_score / 4) + 2, 1, 10)

		var gunnery_boost = target_combat - (combat_sum / 2)
		if gunnery_boost > 0:
			p.skills["gunnery_mech"] = clampi(p.skills.get("gunnery_mech", 5) + gunnery_boost, 1, 10)
			p.skills["gunnery_ground_vehicle"] = clampi(p.skills.get("gunnery_ground_vehicle", 5) + gunnery_boost, 1, 10)

		var train_skill = p.skills.get("training", 3)
		var training_boost = max(0, int(cmd_score / 6) - 1)
		if training_boost > 0:
			p.skills["training"] = clampi(train_skill + training_boost, 1, 10)

		p.reflexes = clampi(p.reflexes + max(0, gunnery_boost), 2, 10)


func _select_command_staff(pilots: Array[Personnel]) -> void:
	if pilots.is_empty():
		return

	pilots.sort_custom(func(a, b):
		var a_lead = a.skills.get("leadership", 1)
		var b_lead = b.skills.get("leadership", 1)
		if a_lead != b_lead:
			return a_lead > b_lead
		var a_strat = a.skills.get("strategy", 1)
		var b_strat = b.skills.get("strategy", 1)
		if a_strat != b_strat:
			return a_strat > b_strat
		var a_tac = a.skills.get("tactics_land", 1)
		var b_tac = b.skills.get("tactics_land", 1)
		if a_tac != b_tac:
			return a_tac > b_tac
		return (a.skills.get("gunnery_mech", 5) + a.skills.get("piloting_mech", 5)) > \
		       (b.skills.get("gunnery_mech", 5) + b.skills.get("piloting_mech", 5))
	)

	var commander = pilots[0]
	commander.is_commander = true
	commander.rank = "Commander"

	if pilots.size() > 1:
		var xo = pilots[1]
		xo.is_xo = true
		xo.rank = "Executive Officer"


func _assign_lance_commanders(pilots: Array[Personnel], mechs: Array[TacticalUnit]) -> void:
	var lance_count = max(1, mechs.size() / 4)
	if lance_count <= 1:
		return

	var commanders = 0
	var sorted = pilots.duplicate()
	sorted.sort_custom(func(a, b):
		var a_tac = a.skills.get("tactics_land", 1)
		var b_tac = b.skills.get("tactics_land", 1)
		if a_tac != b_tac:
			return a_tac > b_tac
		return (a.skills.get("gunnery_mech", 5) + a.skills.get("piloting_mech", 5)) > \
		       (b.skills.get("gunnery_mech", 5) + b.skills.get("piloting_mech", 5))
	)

	for p in sorted:
		if p.is_commander or p.is_xo:
			continue
		if commanders < lance_count - 1:
			p.is_lance_commander = true
			p.rank = "Lance Commander"
			commanders += 1


func _assign_pilot_to_mechs(pilots: Array[Personnel], mechs: Array[TacticalUnit]) -> void:
	for i in range(mechs.size()):
		if i < pilots.size():
			mechs[i].crew.append(pilots[i])
			pilots[i].assigned_unit_id = mechs[i].unit_name


func _generate_technicians(mechs: Array[TacticalUnit]) -> Array[Personnel]:
	var techs: Array[Personnel] = []
	var count = max(1, mechs.size())

	for i in range(count):
		var p = _base_personnel(Enums.PersonnelRole.TECHNICIAN)
		p.specialization = "Mech"
		p.rank = RANK_TITLES[Enums.PersonnelRole.TECHNICIAN][randi() % RANK_TITLES[Enums.PersonnelRole.TECHNICIAN].size()]
		p.skills["tech_mech"] = randi() % 6 + 1
		p.skills["tech_weapons"] = max(1, p.skills["tech_mech"] - randi() % 3)
		p.skills["tech_electronic"] = max(1, p.skills["tech_mech"] - randi() % 2)
		p.skills["perception"] = randi() % 4 + 1

		if i < mechs.size():
			var pm = _get_pm()
			if pm:
				pm.assign_technician(p, mechs[i])

		techs.append(p)

	return techs


func _generate_admin_staff(mechs: Array[TacticalUnit], pilots: Array[Personnel], technicians: Array[Personnel]) -> Array[Personnel]:
	var staff: Array[Personnel] = []

	var tracked_count = pilots.size() + technicians.size() + 1

	var hr = _base_personnel(Enums.PersonnelRole.HR)
	hr.rank = RANK_TITLES[Enums.PersonnelRole.HR][randi() % RANK_TITLES[Enums.PersonnelRole.HR].size()]
	var hr_skill = randi() % 5 + 2
	hr.skills["administration"] = hr_skill
	hr.skills["negotiation"] = randi() % 4 + 1
	hr.skills["computers"] = randi() % 4 + 1
	staff.append(hr)

	var hr_capacity = hr_skill * 10
	if hr_capacity < tracked_count:
		var hr2 = _base_personnel(Enums.PersonnelRole.HR)
		hr2.rank = RANK_TITLES[Enums.PersonnelRole.HR][randi() % RANK_TITLES[Enums.PersonnelRole.HR].size()]
		hr2.skills["administration"] = randi() % 5 + 2
		hr2.skills["negotiation"] = randi() % 4 + 1
		hr2.skills["computers"] = randi() % 4 + 1
		staff.append(hr2)

	var logi = _base_personnel(Enums.PersonnelRole.LOGISTICAL)
	logi.rank = RANK_TITLES[Enums.PersonnelRole.LOGISTICAL][randi() % RANK_TITLES[Enums.PersonnelRole.LOGISTICAL].size()]
	logi.skills["administration"] = randi() % 4 + 2
	logi.skills["negotiation"] = randi() % 3 + 1
	logi.skills["computers"] = randi() % 5 + 2
	logi.skills["science_mathematics"] = randi() % 4 + 1
	staff.append(logi)

	var cmd_admin = _base_personnel(Enums.PersonnelRole.COMMAND)
	cmd_admin.rank = RANK_TITLES[Enums.PersonnelRole.COMMAND][randi() % RANK_TITLES[Enums.PersonnelRole.COMMAND].size()]
	cmd_admin.skills["administration"] = randi() % 4 + 2
	cmd_admin.skills["negotiation"] = randi() % 4 + 1
	cmd_admin.skills["leadership"] = randi() % 5 + 3
	cmd_admin.skills["strategy"] = randi() % 4 + 2
	cmd_admin.skills["tactics_land"] = randi() % 4 + 1
	staff.append(cmd_admin)

	var transport = _base_personnel(Enums.PersonnelRole.TRANSPORT)
	transport.rank = RANK_TITLES[Enums.PersonnelRole.TRANSPORT][randi() % RANK_TITLES[Enums.PersonnelRole.TRANSPORT].size()]
	transport.skills["administration"] = randi() % 3 + 1
	transport.skills["negotiation"] = randi() % 3 + 1
	transport.skills["navigation_ground"] = randi() % 4 + 2
	transport.skills["navigation_air"] = randi() % 3 + 1
	transport.skills["navigation_space"] = randi() % 3 + 1
	transport.skills["communications_conventional"] = randi() % 3 + 1
	staff.append(transport)

	return staff


func _generate_doctor() -> Personnel:
	var p = _base_personnel(Enums.PersonnelRole.DOCTOR)
	p.rank = RANK_TITLES[Enums.PersonnelRole.DOCTOR][randi() % RANK_TITLES[Enums.PersonnelRole.DOCTOR].size()]
	p.skills["surgery_general"] = randi() % 5 + 2
	p.skills["medic"] = randi() % 4 + 2
	p.skills["administration"] = randi() % 4 + 2
	p.patient_capacity = 20
	return p


func _base_personnel(role: Enums.PersonnelRole) -> Personnel:
	var p = Personnel.new()
	p.personnel_name = FIRST_NAMES[randi() % FIRST_NAMES.size()] + " " + LAST_NAMES[randi() % LAST_NAMES.size()]
	p.role = role
	p.body = _rand_atow()
	p.dexterity = _rand_atow()
	p.reflexes = _rand_atow()
	p.strength = _rand_atow()
	p.willpower = _rand_atow()
	p.charisma = _rand_atow()
	p.intelligence = _rand_atow()
	p.edge = randi() % 3 + 1

	var birth_year = 3025 - (randi() % 40 + 18)
	var birth_month = randi() % 12 + 1
	var birth_day = randi() % 28 + 1
	p.date_of_birth = str(birth_year) + "-" + str(birth_month) + "-" + str(birth_day)

	p.hair_color = ["Brown", "Black", "Blonde", "Red", "Grey", "White", "Auburn"][randi() % 7]
	p.eye_color = ["Brown", "Blue", "Green", "Grey", "Hazel"][randi() % 5]
	p.height_cm = randi() % 40 + 150
	p.weight_kg = randi() % 40 + 55

	p.is_founder = true
	return p


func _rand_atow() -> int:
	return randi() % 7 + 2


func _calculate_inventory(mechs: Array[TacticalUnit], faction_code: String, rat_data: Dictionary) -> Dictionary:
	var inventory: Dictionary = {}
	var component_type_counts: Dictionary = {}

	var total_armor_points := 0

	for unit in mechs:
		total_armor_points += unit.total_armor_points

		for c in unit.components:
			var name = c.component_name

			if _is_ammo_weapon(name):
				var ammo_name = _get_ammo_for_weapon(name)
				if not ammo_name.is_empty():
					inventory[ammo_name] = inventory.get(ammo_name, 0) + 2

			var base_type = _get_component_type(name)
			if not base_type.is_empty():
				component_type_counts[base_type] = component_type_counts.get(base_type, {})
				var group = component_type_counts[base_type]
				group[name] = group.get(name, 0) + 1

	var armor_name = "Standard Armor"
	inventory[armor_name] = inventory.get(armor_name, 0) + max(1, int(total_armor_points * 0.1))

	for base_type in component_type_counts:
		var group = component_type_counts[base_type]
		for comp_name in group:
			var count = group[comp_name]
			var spare = max(1, int(count * 0.1))
			inventory[comp_name] = inventory.get(comp_name, 0) + spare

	var gs = _get_gs()
	if gs and gs.factions != null:
		var faction = gs.factions.get(faction_code)
		if faction:
			for uc in faction.unique_components:
				inventory[uc] = inventory.get(uc, 0) + 1

	return inventory


func _sum_inventory_cost(inventory: Dictionary) -> int:
	var total = 0
	for comp_name in inventory:
		var qty = inventory[comp_name]
		var dm = _get_dm()
		var def = dm.component_defs.get(comp_name) if dm else null
		if def:
			total += def.get("cost", 0) * qty
		else:
			total += 1000 * qty
	return total


func _is_ammo_weapon(name: String) -> bool:
	var n = name.to_lower()
	var patterns = ["autocannon/", "lrm-", "srm-", "lrt-", "srt-", "machine gun", "flamer"]
	for p in patterns:
		if n.begins_with(p):
			return true
	return false


func _get_ammo_for_weapon(weapon_name: String) -> String:
	var n = weapon_name.to_lower().strip_edges()
	var map := {
		"autocannon/2": "IS Ammo AC/2",
		"autocannon/5": "IS Ammo AC/5",
		"autocannon/10": "IS Ammo AC/10",
		"autocannon/20": "IS Ammo AC/20",
		"lrm-5": "IS Ammo LRM-5",
		"lrm-10": "IS Ammo LRM-10",
		"lrm-15": "IS Ammo LRM-15",
		"lrm-20": "IS Ammo LRM-20",
		"srm-2": "IS Ammo SRM-2",
		"srm-4": "IS Ammo SRM-4",
		"srm-6": "IS Ammo SRM-6",
		"srt-2": "SRT-2 Ammo",
		"srt-4": "SRT-4 Ammo",
		"srt-6": "SRT-6 Ammo",
		"lrt-5": "LRT-5 Ammo",
		"lrt-10": "LRT-10 Ammo",
		"lrt-15": "LRT-15 Ammo",
		"lrt-20": "LRT-20 Ammo",
		"machine gun": "Machine Gun Ammo",
		"vehicle flamer": "Vehicle Flamer Ammo",
	}
	for key in map:
		if n.begins_with(key):
			return map[key]
	return ""


func _get_component_type(name: String) -> String:
	var n = name.to_lower()
	if "actuator" in n:
		return "actuator"
	if "heat sink" in n:
		return "heat_sink"
	if n in ["structure", "endo steel", "reinforced", "composite"]:
		return "structure"
	if "engine" in n:
		return "engine"
	if "gyro" in n:
		return "gyro"
	if "armor" in n:
		return "armor"
	if "cockpit" in n or n == "life support" or n == "sensors":
		return "cockpit"
	if "jump jet" in n:
		return "jump_jet"
	if "ammo" in n:
		return "ammo"
	return ""


func _build_organization(company_name: String, mechs: Array[TacticalUnit],
		pilots: Array[Personnel], faction_code: String) -> StrategicUnit:

	var strategic = StrategicUnit.new()
	strategic.unit_name = company_name
	strategic.current_planet = "Galatea"
	strategic.home_base = "Galatea"

	var org_unit = OrganizationalUnit.new()
	org_unit.unit_name = company_name

	var lance_size = 4
	var current_lance = 0
	var ops: Array[OperationalUnit] = []

	for i in range(0, mechs.size(), lance_size):
		var lance_mechs = mechs.slice(i, min(i + lance_size, mechs.size()))
		if lance_mechs.is_empty():
			continue

		var ou = OperationalUnit.new()
		ou.unit_name = "%s Lance %d" % [company_name, current_lance + 1]
		ou.tactical_units = lance_mechs
		ou.role = "Lance"

		for p in pilots:
			if p.is_lance_commander and p.assigned_unit_id.is_empty():
				var assigned_to_lance = false
				for tu in lance_mechs:
					if p in tu.crew:
						assigned_to_lance = true
						break
				if assigned_to_lance:
					ou.commander = p
					break

		ops.append(ou)
		current_lance += 1

	org_unit.sub_units = ops

	var commander = null
	var xo = null
	for p in pilots:
		if p.is_commander:
			commander = p
		if p.is_xo:
			xo = p

	org_unit.commander = commander
	var orgs: Array[OrganizationalUnit] = [org_unit]
	strategic.organizational_units = orgs

	return strategic


func _pick_company_name() -> String:
	return MERC_COMPANY_NAMES[randi() % MERC_COMPANY_NAMES.size()]


func _pick_starting_system(faction_code: String) -> String:
	var gs = _get_gs()
	if gs and gs.factions:
		var faction = gs.factions.get(faction_code)
		if faction and not faction.home_worlds.is_empty():
			return faction.home_worlds[randi() % faction.home_worlds.size()]

	var dm = _get_dm()
	if dm:
		var systems = dm.systems_data.keys()
		if not systems.is_empty():
			return systems[randi() % systems.size()]

	return "Unknown"
