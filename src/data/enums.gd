class_name Enums
extends Resource

enum Quality { F, E, D, C, B, A }
enum ComponentStatus { UNDAMAGED, DAMAGED, DESTROYED }
enum UnitType { INFANTRY, VEHICLE, MECH }
enum PersonnelRole { HR, LOGISTICAL, TRANSPORT, COMMAND, MEDIC, DOCTOR, TECHNICIAN, ASTECH, MECHWARRIOR, VEHICLE_CREW, AEROSPACE_PILOT, VTOL_PILOT, AIRCRAFT_PILOT, INFANTRY, CREW, CIVILIAN, CHILD }
enum CommandRights { INDEPENDENT, LIAISON, HOUSE, INTEGRATED }
enum EducationLevel { EARLY_CHILDHOOD, HIGH_SCHOOL, COLLEGE, POSTGRADUATE, PHD }

enum TraitCategory { POSITIVE, NEGATIVE }

enum RefitClass { B, C, D, E }

enum RelationshipType {
	FRIENDSHIP,
	WINGMAN,
	LOVER,
	MARRIAGE,
	PARENT_CHILD,
	SIBLING,
	DISLIKE,
	RIVAL,
	ACQUAINTANCE,
}

static func get_all_skills() -> Array[String]:
	var skills: Array[String] = []
	var file = FileAccess.open("res://data/skills.json", FileAccess.READ)
	if file:
		var j = JSON.new()
		if j.parse(file.get_as_text()) == OK:
			var data = j.data
			for entry in data.get("skills", []):
				skills.append(entry.get("name", ""))
	if skills.is_empty():
		return skills
	if not GameState:
		return skills
	for code in GameState.factions:
		var f: Faction = GameState.factions[code]
		if f == null:
			continue
		if not f.is_rebel and not f.is_pirate and not f.is_civilian:
			skills.append("protocol_" + code.to_lower())
	return skills

const SKILL_ATTRIBUTE_LINKS: Dictionary = {
	"acrobatics": ["reflexes"],
	"acting": ["charisma"],
	"administration": ["intelligence", "willpower"],
	"animal_handling": ["willpower"],
	"appraisal": ["intelligence"],
	"archery": ["dexterity"],
	"art": ["dexterity", "intelligence"],
	"artillery": ["intelligence", "willpower"],
	"astech": ["intelligence", "dexterity"],
	"career": ["intelligence"],
	"climbing": ["strength"],
	"communications": ["intelligence"],
	"computers": ["dexterity", "intelligence"],
	"cryptography": ["intelligence", "willpower"],
	"demolitions": ["dexterity", "intelligence"],
	"disguise": ["charisma"],
	"driving": ["reflexes", "dexterity"],
	"escape_artist": ["dexterity"],
	"forgery": ["dexterity", "intelligence"],
	"gunnery": ["reflexes", "dexterity"],
	"interest": ["intelligence"],
	"interrogation": ["charisma", "willpower"],
	"investigation": ["intelligence", "willpower"],
	"language": ["intelligence"],
	"leadership": ["charisma", "willpower"],
	"martial_arts": ["strength", "reflexes"],
	"medic": ["intelligence", "willpower"],
	"melee_weapons": ["strength", "dexterity"],
	"navigation": ["intelligence"],
	"negotiation": ["charisma", "willpower"],
	"perception": ["intelligence"],
	"piloting": ["reflexes", "dexterity"],
	"prestidigitation": ["reflexes", "dexterity"],
	"protocol": ["willpower", "charisma"],
	"running": ["reflexes"],
	"science": ["intelligence", "willpower"],
	"security_systems": ["intelligence", "dexterity"],
	"sensor_operations": ["intelligence"],
	"small_arms": ["dexterity"],
	"stealth": ["reflexes", "intelligence"],
	"strategy": ["intelligence", "willpower"],
	"streetwise": ["charisma", "willpower"],
	"subterfuge": ["charisma", "intelligence"],
	"support_weapons": ["strength", "dexterity"],
	"surgery": ["intelligence", "dexterity"],
	"survival": ["willpower"],
	"swimming": ["strength"],
	"tactics": ["intelligence", "willpower"],
	"teaching": ["charisma", "willpower"],
	"tech": ["intelligence", "dexterity"],
	"zero_g_operations": ["reflexes", "dexterity"],
}


static var _skill_attrs_cache: Dictionary = {}


static func _load_skill_attrs() -> void:
	if not _skill_attrs_cache.is_empty():
		return
	var file = FileAccess.open("res://data/skills.json", FileAccess.READ)
	if not file:
		return
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK:
		return
	for entry in j.data.get("skills", []):
		var name = entry.get("name", "")
		var links = entry.get("links", [])
		if not name.is_empty() and not links.is_empty():
			_skill_attrs_cache[name] = links


static func get_skill_attributes(skill: String) -> Array[String]:
	_load_skill_attrs()
	while skill.length() > 0:
		if _skill_attrs_cache.has(skill):
			return _skill_attrs_cache[skill] as Array[String]
		var idx = skill.rfind("_")
		if idx == -1:
			break
		skill = skill.left(idx)
	return []

const TRAIT_DEFS: Array[Dictionary] = [
	{ "id": "ambidextrous", "name": "Ambidextrous", "category": TraitCategory.POSITIVE, "desc": "No off-hand penalty", "effect": "off_hand_penalty", "value": 0 },
	{ "id": "animal_empathy", "name": "Animal Empathy", "category": TraitCategory.POSITIVE, "desc": "Bonus with animals", "effect": "skill_bonus", "value": 1, "skill": "animal_handling" },
	{ "id": "combat_sense", "name": "Combat Sense", "category": TraitCategory.POSITIVE, "desc": "+1 initiative, +2 surprise", "effect": "initiative_bonus", "value": 1 },
	{ "id": "connections", "name": "Connections", "category": TraitCategory.POSITIVE, "desc": "Favors from an organization", "effect": "", "value": 0 },
	{ "id": "double_jointed", "name": "Double-Jointed", "category": TraitCategory.POSITIVE, "desc": "Bonus to Escape Artist and Climbing", "effect": "skill_bonus", "value": 1, "skill": "escape_artist" },
	{ "id": "eidetic_memory", "name": "Eidetic Memory", "category": TraitCategory.POSITIVE, "desc": "Remember fine details", "effect": "", "value": 0 },
	{ "id": "enchanting", "name": "Enchanting", "category": TraitCategory.POSITIVE, "desc": "Bonus to social skills", "effect": "skill_bonus", "value": 1, "skill": "negotiation" },
	{ "id": "environmental_adaptation", "name": "Environmental Adaptation", "category": TraitCategory.POSITIVE, "desc": "Survive harsh environments", "effect": "survival_bonus", "value": 2 },
	{ "id": "fast_learner", "name": "Fast Learner", "category": TraitCategory.POSITIVE, "desc": "Learn skills faster", "effect": "learning_modifier", "value": -1 },
	{ "id": "fit", "name": "Fit", "category": TraitCategory.POSITIVE, "desc": "Recover from fatigue faster", "effect": "fatigue_recovery", "value": 1 },
	{ "id": "g_tolerance", "name": "G-Tolerance", "category": TraitCategory.POSITIVE, "desc": "Resist high-G effects", "effect": "", "value": 0 },
	{ "id": "iron_will", "name": "Iron Will", "category": TraitCategory.POSITIVE, "desc": "+3 vs fear/intimidation", "effect": "willpower_bonus", "value": 3 },
	{ "id": "land_grants", "name": "Land Grants", "category": TraitCategory.POSITIVE, "desc": "Own land", "effect": "", "value": 0 },
	{ "id": "lightning_calculator", "name": "Lightning Calculator", "category": TraitCategory.POSITIVE, "desc": "Mental math", "effect": "", "value": 0 },
	{ "id": "lucky", "name": "Lucky", "category": TraitCategory.POSITIVE, "desc": "Reroll once per session", "effect": "luck", "value": 1 },
	{ "id": "natural_aptitude", "name": "Natural Aptitude", "category": TraitCategory.POSITIVE, "desc": "-1 TN for linked skill", "effect": "skill_tn_bonus", "value": -1 },
	{ "id": "pain_resistance", "name": "Pain Resistance", "category": TraitCategory.POSITIVE, "desc": "Ignore wound penalties", "effect": "wound_ignore", "value": 1 },
	{ "id": "rank", "name": "Rank", "category": TraitCategory.POSITIVE, "desc": "Military/organization rank", "effect": "", "value": 0 },
	{ "id": "reputation", "name": "Reputation", "category": TraitCategory.POSITIVE, "desc": "Known for something", "effect": "", "value": 0 },
	{ "id": "resources", "name": "Resources", "category": TraitCategory.POSITIVE, "desc": "Wealth/equipment access", "effect": "wealth_bonus", "value": 0 },
	{ "id": "sense_of_direction", "name": "Sense of Direction", "category": TraitCategory.POSITIVE, "desc": "Always know north", "effect": "", "value": 0 },
	{ "id": "sense_of_balance", "name": "Sense of Balance", "category": TraitCategory.POSITIVE, "desc": "Bonus to balance checks", "effect": "skill_bonus", "value": 1, "skill": "acrobatics" },
	{ "id": "title", "name": "Title", "category": TraitCategory.POSITIVE, "desc": "Noble title", "effect": "", "value": 0 },
	{ "id": "toughness", "name": "Toughness", "category": TraitCategory.POSITIVE, "desc": "+1 damage resistance", "effect": "damage_resistance", "value": 1 },
	{ "id": "zero_g_tolerance", "name": "Zero-G Tolerance", "category": TraitCategory.POSITIVE, "desc": "No penalty in zero-G", "effect": "", "value": 0 },
	{ "id": "addiction", "name": "Addiction", "category": TraitCategory.NEGATIVE, "desc": "Substance dependency", "effect": "", "value": 0 },
	{ "id": "amnesia", "name": "Amnesia", "category": TraitCategory.NEGATIVE, "desc": "Memory gaps", "effect": "", "value": 0 },
	{ "id": "bloodmark", "name": "Bloodmark", "category": TraitCategory.NEGATIVE, "desc": "Known criminal mark", "effect": "", "value": 0 },
	{ "id": "combat_paralysis", "name": "Combat Paralysis", "category": TraitCategory.NEGATIVE, "desc": "Freeze in combat", "effect": "initiative_penalty", "value": -2 },
	{ "id": "compulsion", "name": "Compulsion", "category": TraitCategory.NEGATIVE, "desc": "Personality quirk", "effect": "", "value": 0 },
	{ "id": "dependents", "name": "Dependents", "category": TraitCategory.NEGATIVE, "desc": "People relying on you", "effect": "", "value": 0 },
	{ "id": "difficult_circumstances", "name": "Difficult Circumstances", "category": TraitCategory.NEGATIVE, "desc": "Ongoing personal problems", "effect": "", "value": 0 },
	{ "id": "enemy", "name": "Enemy", "category": TraitCategory.NEGATIVE, "desc": "Someone wants to harm you", "effect": "", "value": 0 },
	{ "id": "glass_jaw", "name": "Glass Jaw", "category": TraitCategory.NEGATIVE, "desc": "Easier to crit", "effect": "crit_vulnerability", "value": 1 },
	{ "id": "greedy", "name": "Greedy", "category": TraitCategory.NEGATIVE, "desc": "Must resist greed", "effect": "", "value": 0 },
	{ "id": "handicap", "name": "Handicap", "category": TraitCategory.NEGATIVE, "desc": "Physical/mental impairment", "effect": "", "value": 0 },
	{ "id": "illiterate", "name": "Illiterate", "category": TraitCategory.NEGATIVE, "desc": "Cannot read/write", "effect": "", "value": 0 },
	{ "id": "impulsive", "name": "Impulsive", "category": TraitCategory.NEGATIVE, "desc": "Act before thinking", "effect": "", "value": 0 },
	{ "id": "incompetent", "name": "Incompetent", "category": TraitCategory.NEGATIVE, "desc": "Cannot use a skill", "effect": "", "value": 0 },
	{ "id": "low_pain_threshold", "name": "Low Pain Threshold", "category": TraitCategory.NEGATIVE, "desc": "Worse wound penalties", "effect": "wound_penalty", "value": -1 },
	{ "id": "low_g_tolerance", "name": "Low-G Tolerance", "category": TraitCategory.NEGATIVE, "desc": "Sick in low-G", "effect": "", "value": 0 },
	{ "id": "night_blindness", "name": "Night Blindness", "category": TraitCategory.NEGATIVE, "desc": "Penalties in low light", "effect": "vision_penalty", "value": -2 },
	{ "id": "overconfident", "name": "Overconfident", "category": TraitCategory.NEGATIVE, "desc": "Underestimate danger", "effect": "", "value": 0 },
	{ "id": "phobia", "name": "Phobia", "category": TraitCategory.NEGATIVE, "desc": "Fear of something", "effect": "", "value": 0 },
	{ "id": "poverty", "name": "Poverty", "category": TraitCategory.NEGATIVE, "desc": "Little money", "effect": "wealth_penalty", "value": 0 },
	{ "id": "prejudice", "name": "Prejudice", "category": TraitCategory.NEGATIVE, "desc": "Bias against group", "effect": "", "value": 0 },
	{ "id": "slow_learner", "name": "Slow Learner", "category": TraitCategory.NEGATIVE, "desc": "Learn skills slower", "effect": "learning_modifier", "value": 2 },
	{ "id": "unattractive", "name": "Unattractive", "category": TraitCategory.NEGATIVE, "desc": "Penalty to social skills", "effect": "skill_penalty", "value": -1, "skill": "negotiation" },
	{ "id": "unlucky", "name": "Unlucky", "category": TraitCategory.NEGATIVE, "desc": "GM can force reroll", "effect": "luck", "value": -1 },
	{ "id": "vengeful", "name": "Vengeful", "category": TraitCategory.NEGATIVE, "desc": "Must pursue vengeance", "effect": "", "value": 0 },
	{ "id": "weak_willed", "name": "Weak Willed", "category": TraitCategory.NEGATIVE, "desc": "-3 vs intimidation", "effect": "willpower_penalty", "value": -3 },
	{ "id": "weakness", "name": "Weakness", "category": TraitCategory.NEGATIVE, "desc": "Vulnerability to substance/environment", "effect": "", "value": 0 },
	{ "id": "xenophobia", "name": "Xenophobia", "category": TraitCategory.NEGATIVE, "desc": "Fear/distrust of foreigners", "effect": "", "value": 0 },
]

static func get_trait_def(trait_id: String) -> Dictionary:
	for t in TRAIT_DEFS:
		if t.id == trait_id:
			return t
	return {}

static func get_traits_by_category(category: TraitCategory) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for t in TRAIT_DEFS:
		if t.category == category:
			result.append(t)
	return result
