extends Node

## Generates a HexMap for a planetary operation.
## Priority: canonical map → generic region → procedural from biome data.
## All terrain/biome/region definitions are data-driven from JSON files.

const HexMap = preload("res://src/data/HexMap.gd")

const MIN_RIOT_POPULATION: int = 10000
const BIOMES_DIR: String = "res://data/planetary/biomes/"
const CANONICAL_DIR: String = "res://data/maps/canonical/planetary/"
const REGIONS_DIR: String = "res://data/planetary/regions/"
const OBJECTIVES_DIR: String = "res://data/planetary/objectives/"
const OPFOR_DIR: String = "res://data/planetary/opfor/"

const _terrain_map: Dictionary = {
	"PLAINS": HexMap.Terrain.PLAINS,
	"FOREST": HexMap.Terrain.FOREST,
	"MOUNTAIN": HexMap.Terrain.MOUNTAIN,
	"WATER": HexMap.Terrain.WATER,
	"URBAN": HexMap.Terrain.URBAN,
	"DESERT": HexMap.Terrain.DESERT,
	"ROUGH": HexMap.Terrain.ROUGH,
}

static var _biome_cache: Dictionary = {}
static var _canonical_cache: Dictionary = {}
static var _region_cache = []  # Array[Dictionary] — untyped to avoid assign-type mismatch from merged.get()
static var _objective_cache: Dictionary = {}
static var _objective_cache_loaded: bool = false
static var _opfor_cache: Array = []
static var _opfor_cache_loaded: bool = false


static func _load_biome_data() -> Dictionary:
	if not _biome_cache.is_empty():
		return _biome_cache
	var merged: Dictionary = {"biomes": {}, "conditions": [], "map_sizes": {}}
	_merge_json_dir(BIOMES_DIR, merged)
	_biome_cache = merged
	return merged


static func _load_canonical_map(map_name: String) -> Dictionary:
	if _canonical_cache.has(map_name):
		return _canonical_cache[map_name]
	var path = CANONICAL_DIR + map_name + ".json"
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		_canonical_cache[map_name] = {}
		return {}
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK:
		_canonical_cache[map_name] = {}
		return {}
	_canonical_cache[map_name] = j.data
	return j.data


static func _load_regions() -> Array:
	if not _region_cache.is_empty():
		return _region_cache
	var merged: Dictionary = {"regions": []}
	_merge_json_dir(REGIONS_DIR, merged)
	_region_cache = merged.get("regions", [])
	return _region_cache


static func _merge_json_dir(dir_path: String, merged: Dictionary) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var file = FileAccess.open(dir_path + fname, FileAccess.READ)
			if file:
				var j = JSON.new()
				if j.parse(file.get_as_text()) == OK:
					var data = j.data
					for key in data:
						var val = data[key]
						if val is Array:
							merged[key] = merged.get(key, []) + val
						elif val is Dictionary:
							if not merged.has(key):
								merged[key] = {}
							for k in val:
								merged[key][k] = val[k]
		fname = dir.get_next()


static func load_objectives() -> Dictionary:
	if _objective_cache_loaded:
		return _objective_cache
	var merged: Dictionary = {"objectives": [], "events": []}
	_merge_json_dir(OBJECTIVES_DIR, merged)
	_objective_cache = merged
	_objective_cache_loaded = true
	return merged


static func check_event(obj_data: Dictionary, explored_count: int, biome_name: String) -> Dictionary:
	var all_data = load_objectives()
	var events: Array = all_data.get("events", [])
	for ev in events:
		var conds = ev.get("conditions", {})
		if conds.get("hex_not_objective", false) and obj_data.get("has_objective", false):
			continue
		var biomes: Array = conds.get("hex_biomes", [])
		if not biomes.is_empty() and biome_name not in biomes:
			continue
		var min_exp = conds.get("min_explored", 0)
		if explored_count < min_exp:
			continue
		var chance = conds.get("chance", 1.0)
		if randf() > chance:
			continue
		return ev
	return {}


static func load_opfor_templates() -> Array:
	if _opfor_cache_loaded:
		return _opfor_cache
	var merged: Dictionary = {"opfor": []}
	_merge_json_dir(OPFOR_DIR, merged)
	_opfor_cache = merged.get("opfor", [])
	_opfor_cache_loaded = true
	return _opfor_cache


static func select_opfor_template(activity_type: String, biome_name: String, faction: String = "") -> Dictionary:
	var templates = load_opfor_templates()
	var candidates: Array[Dictionary] = []
	for t in templates:
		var types: Array = t.get("activity_types", ["*"])
		if types[0] != "*" and activity_type not in types:
			continue
		var biomes: Array = t.get("biomes", ["*"])
		if biomes[0] != "*" and biome_name not in biomes:
			continue
		var factions: Array = t.get("factions", ["*"])
		if factions[0] != "*" and faction not in factions and faction != "":
			continue
		candidates.append(t)
	if candidates.is_empty():
		return {}
	var total_weight := 0
	for c in candidates:
		total_weight += c.get("weight", 10)
	if total_weight <= 0:
		return candidates[0]
	var roll = randi() % total_weight
	var cumulative := 0
	for c in candidates:
		cumulative += c.get("weight", 10)
		if roll < cumulative:
			return c
	return candidates[0]


static var _faction_to_rat: Dictionary = {
	"LC": "lyran", "FS": "fed_suns", "DC": "drac_combine",
	"FWL": "fwl", "CC": "capellan", "PIR": "periphery",
	"MRC": "merc", "MOC": "magistracy", "TC": "taurian",
	"OA": "outworlds", "MH": "marian",
}


static func generate_opfor_pool(template: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var ps = template.get("pool_size", [4, 8])
	var pool_count = rng.randi_range(ps[0], ps[1])
	if pool_count <= 0:
		return pool

	var composition = template.get("composition", {})
	var mech_comp = composition.get("mechs", {}) if composition is Dictionary else {}
	var mech_pct = mech_comp.get("count_pct", 1.0)
	var mech_count = int(ceil(pool_count * mech_pct))

	var quality_range = template.get("quality", [2, 4])
	var morale = template.get("morale", 0.5)
	var faction = "PIR"
	var tf = template.get("factions", ["*"])
	if tf[0] != "*":
		faction = tf[0]

	var commander_cfg = template.get("commander", {})
	var has_commander = rng.randf() < commander_cfg.get("chance", 0.0)

	var rat_key = mech_comp.get("rat_key", "")
	if rat_key.is_empty():
		rat_key = _faction_to_rat.get(faction, "is_general")
	var rat_data = RATParser.load_rat(rat_key)
	if rat_data.is_empty():
		rat_data = RATParser.load_rat("is_general")

	var weight_classes = mech_comp.get("weight_classes", {"Light": 40, "Medium": 35, "Heavy": 20, "Assault": 5})
	var wc_keys: Array = weight_classes.keys()

	for i in range(mech_count):
		var wc_roll = rng.randf() * 100.0
		var chosen_wc = "Light"
		var cumulative_wc := 0.0
		for wc in wc_keys:
			cumulative_wc += weight_classes[wc]
			if wc_roll <= cumulative_wc:
				chosen_wc = wc
				break

		var chassis = RATParser.roll_on_table(rat_data, chosen_wc)
		if chassis.is_empty():
			chassis = "Locust LCT-1V"

		var quality = rng.randi_range(quality_range[0], quality_range[1])
		var gunnery = 4 + quality
		var piloting = 5 + quality
		var is_cmd = has_commander and i == 0

		if is_cmd:
			var gb = commander_cfg.get("gunnery_bonus", 0)
			var pb = commander_cfg.get("piloting_bonus", 0)
			gunnery = max(0, gunnery - gb)
			piloting = max(0, piloting - pb)
		elif has_commander:
			pass

		pool.append({
			"unit_name": chassis,
			"chassis_name": chassis,
			"tonnage": _estimate_tonnage(chosen_wc, rng),
			"quality": quality,
			"gunnery": gunnery,
			"piloting": piloting,
			"is_commander": is_cmd,
			"status": "active",
			"faction": faction,
		})

	return pool


static func _estimate_tonnage(weight_class: String, rng: RandomNumberGenerator) -> int:
	match weight_class:
		"Light": return rng.randi_range(20, 35)
		"Medium": return rng.randi_range(40, 55)
		"Heavy": return rng.randi_range(60, 75)
		"Assault": return rng.randi_range(80, 100)
	return 50


static func draw_from_pool(pool: Array[Dictionary], strength: int) -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for u in pool:
		if u.get("status", "active") == "active":
			active.append(u)
	if active.is_empty():
		return []

	var portion = clamp(float(strength) / 3.0, 0.1, 1.0)
	var count = max(1, int(ceil(active.size() * portion)))
	if count > active.size():
		count = active.size()

	active.shuffle()
	return active.slice(0, count)


func generate(contract: Contract, planet_data_override: Dictionary = {}) -> HexMap:
	var biome_data = _load_biome_data()
	var size = biome_data.map_sizes.get(contract.activity_type, Vector2i(10, 10))
	if size is Array:
		size = Vector2i(size[0], size[1])

	var planet_data = planet_data_override
	if planet_data.is_empty():
		planet_data = _get_planet_data(contract.planet)

	if contract.activity_type == "Riot":
		var pop = planet_data.get("population", 0)
		if pop < MIN_RIOT_POPULATION:
			push_warning("Riot contract on low-population body (%s, pop=%d)" % [contract.planet, pop])

	var hex_map: HexMap = null
	var biome_name = _resolve_biome(planet_data, contract.activity_type, biome_data)

	hex_map = _try_load_canonical(planet_data, contract.activity_type, size)
	if not hex_map:
		hex_map = _try_match_region(planet_data, contract.activity_type, biome_name, size)
	if not hex_map:
		hex_map = _generate_procedural(biome_data, biome_name, size)

	_place_objectives(hex_map, contract)
	_set_landing_zone(hex_map)
	return hex_map


func _resolve_biome(planet_data: Dictionary, activity_type: String, data: Dictionary) -> String:
	if planet_data.has("biome"):
		var override = planet_data.get("biome", "")
		if override and data.biomes.has(override):
			return override

	for condition in data.conditions:
		if condition.has("activity") and condition.activity == activity_type:
			return condition.biome

	var atmo = planet_data.get("atmosphere", "breathable")
	var temp = planet_data.get("temperature", 22)
	var land = planet_data.get("land_percent", 40)

	for condition in data.conditions:
		if condition.has("atmo_in"):
			if atmo in condition.atmo_in:
				return condition.biome
	for condition in data.conditions:
		if condition.has("temp_min") and temp >= float(condition.temp_min):
			return condition.biome
	for condition in data.conditions:
		if condition.has("temp_max") and temp <= float(condition.temp_max):
			return condition.biome
	for condition in data.conditions:
		if condition.has("land_max") and land <= int(condition.land_max):
			return condition.biome

	return "temperate"


func _try_load_canonical(planet_data: Dictionary, activity_type: String, _size: Vector2i) -> HexMap:
	var map_name = planet_data.get("canonical_planetary_map", "")
	if map_name.is_empty():
		return null

	var cmap = _load_canonical_map(map_name)
	if cmap.is_empty():
		return null

	var region = _find_region_for_activity(cmap, activity_type)
	if region.is_empty():
		return null

	return _build_hexmap_from_template(cmap, region)


func _find_region_for_activity(cmap: Dictionary, activity_type: String) -> Dictionary:
	var regions: Array = cmap.get("regions", [])
	if regions.is_empty():
		return {"q_min": 0, "r_min": 0, "q_max": cmap.width - 1, "r_max": cmap.height - 1}
	for r in regions:
		var types: Array = r.get("activity_types", [])
		if activity_type in types:
			return r
	var first = regions[0]
	first = first.duplicate()
	first._no_match = true
	return first


func _try_match_region(planet_data: Dictionary, activity_type: String, biome_name: String, size: Vector2i) -> HexMap:
	var all_regions = _load_regions()
	if all_regions.is_empty():
		return null

	var pop = planet_data.get("population", 0)
	var candidates: Array[Dictionary] = []
	for region in all_regions:
		var constraints = region.get("constraints", {})
		var biomes: Array = constraints.get("biomes", [])
		if not biomes.is_empty() and biome_name not in biomes:
			continue
		var types: Array = constraints.get("activity_types", [])
		if not types.is_empty() and activity_type not in types:
			continue
		var pop_min = constraints.get("population_min", -1)
		if pop_min >= 0 and pop < pop_min:
			continue
		var pop_max = constraints.get("population_max", -1)
		if pop_max >= 0 and pop > pop_max:
			continue
		var rw = region.get("width", 10)
		var rh = region.get("height", 8)
		if rw > size.x or rh > size.y:
			continue
		candidates.append(region)

	if candidates.is_empty():
		return null

	var total_weight := 0
	for c in candidates:
		total_weight += c.get("weight", 10)

	var roll = randi() % total_weight
	var cumulative := 0
	for c in candidates:
		cumulative += c.get("weight", 10)
		if roll < cumulative:
			return _build_hexmap_from_template(c, {})
	return _build_hexmap_from_template(candidates[0], {})


func _build_hexmap_from_template(template: Dictionary, region: Dictionary) -> HexMap:
	var w = template.get("width", 10)
	var h = template.get("height", 8)
	var hm = HexMap.new(w, h)

	var terrain_rows: Array = template.get("terrain", [])
	var q_min = region.get("q_min", 0)
	var r_min = region.get("r_min", 0)
	var q_max = region.get("q_max", w - 1)
	var r_max = region.get("r_max", h - 1)

	for row_idx in range(terrain_rows.size()):
		if row_idx >= h:
			break
		var row_str: String = terrain_rows[row_idx]
		var cells = row_str.split(" ", false)
		var offset = row_idx / 2
		for col_idx in range(cells.size()):
			if col_idx >= w:
				break
			var actual_q = col_idx - offset
			var hd = hm.get_hex(actual_q, row_idx)
			if hd.is_empty():
				continue
			var t_name = cells[col_idx].strip_edges()
			var terrain_val = _terrain_map.get(t_name, HexMap.Terrain.PLAINS)
			hd.terrain = terrain_val
			hd.revealed = false
			hd.explored = false

	var roads: Array = template.get("roads", [])
	for road_str in roads:
		var segments = road_str.split("-", false)
		for seg in segments:
			var parts = seg.split(",", false)
			if parts.size() >= 2:
				var rq = int(parts[0])
				var rr = int(parts[1])
				var hd = hm.get_hex(rq, rr)
				if not hd.is_empty():
					hd.has_road = true

	var rivers: Array = template.get("rivers", [])
	for river_str in rivers:
		var segments = river_str.split("-", false)
		for seg in segments:
			var parts = seg.split(",", false)
			if parts.size() >= 2:
				var rq = int(parts[0])
				var rr = int(parts[1])
				var hd = hm.get_hex(rq, rr)
				if not hd.is_empty():
					hd.has_river = true

	return hm


func _generate_procedural(biome_data: Dictionary, biome_name: String, size: Vector2i) -> HexMap:
	var hm = HexMap.new(size.x, size.y)
	var weights = biome_data.biomes.get(biome_name, biome_data.biomes.get("temperate", {}))
	var resolved = _resolve_terrain_weights(weights)
	_assign_terrain(hm, resolved)
	return hm


static func _resolve_terrain_weights(weight_dict: Dictionary) -> Dictionary:
	var resolved: Dictionary = {}
	for key in weight_dict:
		var enum_val = _terrain_map.get(key, -1)
		if enum_val >= 0:
			resolved[enum_val] = weight_dict[key]
	return resolved


func _get_planet_data(planet_name: String) -> Dictionary:
	var dm = get_node_or_null("/root/DataManager")
	if not dm:
		return {}
	var sys_data = dm.get_system_detail(planet_name)
	if not sys_data or not sys_data.has("planets") or sys_data.planets.is_empty():
		return {}
	var planets = sys_data.planets
	if planet_name.contains(" ") and planet_name.split(" ").size() > 1:
		var parts = planet_name.split(" ")
		var body_name = parts[parts.size() - 1]
		for p in planets:
			if p.name.ends_with(" " + body_name) or p.name == planet_name:
				return p
	return planets[0] if planets.size() > 0 else {}


func _assign_terrain(hex_map: HexMap, weights: Dictionary) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for row in hex_map.hexes:
		for h in row:
			var roll = rng.randf() * 100.0
			var cumulative: float = 0.0
			for terrain_type in weights:
				cumulative += weights[terrain_type]
				if roll <= cumulative:
					h.terrain = terrain_type
					break


func _place_objectives(hex_map: HexMap, contract: Contract) -> void:
	var all_data = load_objectives()
	var templates: Array = all_data.get("objectives", [])
	if templates.is_empty():
		return

	var biome_name = "temperate"
	var planet_data = _get_planet_data(contract.planet)
	if planet_data.has("biome"):
		biome_name = planet_data.biome

	var activity = contract.activity_type
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var all_hexes = hex_map.get_all_hexes()
	if all_hexes.is_empty():
		return

	var candidates: Array[Dictionary] = []
	for h in all_hexes:
		if h.objective == HexMap.ObjectiveType.NONE and h.terrain != HexMap.Terrain.WATER:
			candidates.append(h)
	if candidates.size() < 4:
		candidates = all_hexes.duplicate()
	candidates.shuffle()

	templates.sort_custom(func(a, b): return a.get("priority", 0) > b.get("priority", 0))

	var idx := 0
	for tmpl in templates:
		if idx >= candidates.size():
			break
		var types: Array = tmpl.get("activity_types", ["*"])
		if types[0] != "*" and activity not in types:
			continue
		var biomes: Array = tmpl.get("biomes", ["*"])
		if biomes[0] != "*" and biome_name not in biomes:
			continue
		var count_min = tmpl.get("count", {}).get("min", 1)
		var count_max = tmpl.get("count", {}).get("max", 1)
		var actual_count = rng.randi_range(count_min, count_max)
		if actual_count <= 0:
			continue

		for i in range(actual_count):
			if idx >= candidates.size():
				break
			var hex_data = tmpl.get("data", {}).duplicate(true)
			if hex_data.get("copies_activity", false):
				hex_data["type"] = activity
			if hex_data.has("value_range"):
				var vr = hex_data.value_range
				hex_data.value = rng.randi_range(vr[0], vr[1])
				hex_data.erase("value_range")
			if hex_data.has("strength_range"):
				var sr = hex_data.strength_range
				hex_data.strength = rng.randi_range(sr[0], sr[1])
				hex_data.erase("strength_range")

			var type_name: String = tmpl.get("type", "SECONDARY")
			match type_name:
				"PRIMARY":
					candidates[idx].objective = HexMap.ObjectiveType.PRIMARY
				"SECONDARY":
					candidates[idx].objective = HexMap.ObjectiveType.SECONDARY
				"ASSETS":
					candidates[idx].objective = HexMap.ObjectiveType.ASSETS
				"ENEMY":
					candidates[idx].objective = HexMap.ObjectiveType.ENEMY
			candidates[idx].objective_data = hex_data
			idx += 1


func _set_landing_zone(hex_map: HexMap) -> void:
	var all_hexes = hex_map.get_all_hexes()
	if all_hexes.is_empty():
		return
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	all_hexes.shuffle()
	var candidates: Array[Dictionary] = []
	for h in all_hexes:
		if h.terrain != HexMap.Terrain.WATER and h.objective == HexMap.ObjectiveType.NONE:
			candidates.append(h)
	if candidates.is_empty():
		candidates = all_hexes
	var lz = candidates[0]
	hex_map.landing_zone = Vector2i(lz.q, lz.r)
	lz.revealed = true
	lz.explored = true
	lz.has_road = true
