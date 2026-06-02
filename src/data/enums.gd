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
			var typed: Array[String] = []
			for item in links:
				typed.append(str(item))
			_skill_attrs_cache[name] = typed


static func get_skill_attributes(skill: String) -> Array[String]:
	_load_skill_attrs()
	while skill.length() > 0:
		if _skill_attrs_cache.has(skill):
			var raw = _skill_attrs_cache[skill]
			var result: Array[String] = []
			for item in raw:
				result.append(str(item))
			return result
		var idx = skill.rfind("_")
		if idx == -1:
			break
		skill = skill.left(idx)
	return []

static var _trait_cache: Array = []
static var _trait_cache_loaded: bool = false

static func _ensure_traits() -> void:
	if _trait_cache_loaded:
		return
	_trait_cache_loaded = true
	var merged: Dictionary = {"positive": [], "negative": []}
	var dir = DirAccess.open("res://data/traits/")
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".json"):
				var file = FileAccess.open("res://data/traits/" + fname, FileAccess.READ)
				if file:
					var j = JSON.new()
					if j.parse(file.get_as_text()) == OK:
						var data = j.data
						for cat in ["positive", "negative"]:
							var entries: Array = data.get(cat, [])
							for e in entries:
								e.category = TraitCategory.POSITIVE if cat == "positive" else TraitCategory.NEGATIVE
								_trait_cache.append(e)
			fname = dir.get_next()

static func get_trait_def(trait_id: String) -> Dictionary:
	_ensure_traits()
	for t in _trait_cache:
		if t.get("id") == trait_id:
			return t
	return {}

static func get_traits_by_category(category: TraitCategory) -> Array:
	_ensure_traits()
	var result: Array = []
	for t in _trait_cache:
		if t.get("category", -1) == category:
			result.append(t)
	return result
