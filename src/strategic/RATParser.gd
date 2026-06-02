class_name RATParser
extends RefCounted

static var _file_map: Dictionary = {
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


static func load_rat(faction_key: String, era: String = "3025") -> Dictionary:
	var key = faction_key.to_lower().strip_edges()
	var filename = _file_map.get(key)
	if filename == null:
		var custom_path = "res://data/rat/" + key + ".json"
		var custom_file = FileAccess.open(custom_path, FileAccess.READ)
		if custom_file:
			filename = key + ".json"
		else:
			push_warning("RATParser: no RAT for '%s', falling back to is_general" % key)
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

	var die_type = rat_data.get("die_type", "d1000")
	var roll = _roll_die(die_type)
	for entry in entries:
		if roll >= entry.get("min", 1) and roll <= entry.get("max", 1000):
			return entry.get("chassis", "")
	return ""


static func _roll_die(die_type: String) -> int:
	match die_type:
		"2d6":
			return (randi() % 6 + 1) + (randi() % 6 + 1)
		"2d10":
			return (randi() % 10 + 1) + (randi() % 10 + 1)
		"3d6":
			return (randi() % 6 + 1) + (randi() % 6 + 1) + (randi() % 6 + 1)
		"1d20":
			return randi() % 20 + 1
		"1d100":
			return randi() % 100 + 1
		_:
			return randi() % 1000 + 1


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
