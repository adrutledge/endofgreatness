class_name RATParser
extends RefCounted

static func load_rat(faction_key: String, era: String = "3025") -> Dictionary:
	var file_map := {
		"fed_suns": "fed_suns.json",
		"lyran": "lyran.json",
		"fwl": "fwl.json",
		"drac_combine": "drac_combine.json",
		"capellan": "capellan.json",
		"is_general": "is_general.json",
		"merc": "merc.json",
		"magistracy": "magistracy.json",
		"taurian": "taurian.json",
		"outworlds": "outworlds.json",
		"marian": "marian.json",
		"periphery": "periphery.json",
	}
	var filename = file_map.get(faction_key.to_lower())
	if filename.is_empty():
		push_warning("RATParser: no RAT file for faction '%s', falling back to is_general" % faction_key)
		filename = "is_general.json"

	var path = "res://data/rat/" + filename
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("RATParser: cannot open %s" % path)
		return {}

	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK:
		push_warning("RATParser: JSON parse error in %s" % path)
		return {}

	var data = j.data
	if data.get("era") != era:
		push_warning("RATParser: era mismatch in %s — want %s, got %s" % [path, era, data.get("era")])
	return data


static func roll_on_table(rat_data: Dictionary, weight_class: String) -> String:
	var tables: Dictionary = rat_data.get("tables", {})
	var entries: Array = tables.get(weight_class, [])
	if entries.is_empty():
		return ""

	var roll = randi() % 1000 + 1
	for entry in entries:
		if roll >= entry.get("min", 1) and roll <= entry.get("max", 1000):
			return entry.get("chassis", "")
	return ""


static func pick_weight_class() -> String:
	var roll = randi() % 100
	if roll < 25:
		return "Light"
	elif roll < 60:
		return "Medium"
	elif roll < 85:
		return "Heavy"
	else:
		return "Assault"
