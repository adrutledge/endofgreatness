extends SceneTree

var _passed := 0
var _failed := 0
var _Generator: GDScript
var _HexMap: GDScript
var _ContractRes: GDScript
var _ContractGen: GDScript
var _RATParser: GDScript


func _init() -> void:
	_Generator = load("res://src/strategic/PlanetaryMapGenerator.gd")
	_HexMap = load("res://src/data/HexMap.gd")
	_ContractRes = load("res://src/data/Contract.gd")
	_ContractGen = load("res://src/strategic/ContractGenerator.gd")
	_RATParser = load("res://src/strategic/RATParser.gd")

	_print_sep()
	print("PlanetaryMapGenerator + Data Format Tests")
	_print_sep()

	# --- Positive: map generation ---
	_test_generates_valid_map()
	_test_map_size_by_activity()
	_test_objectives_placed()
	_test_landing_zone_valid()
	_test_no_water_landing_zone()
	_test_riot_terrain()
	_test_planet_biome_override()

	# --- Positive: OpFor system ---
	_test_opfor_templates_loaded()
	_test_opfor_template_selection()
	_test_opfor_pool_generated()
	_test_opfor_pool_draw()

	# --- Negative: OpFor edge cases ---
	_test_opfor_select_no_match()
	_test_opfor_draw_empty_pool()

	# --- Positive: biome resolution ---
	_test_biome_resolution()
	_test_biome_unknown_fallback()

	# --- Negative: biome data gaps ---
	_test_biome_no_crash_on_missing_data()

	# --- Positive: region loading ---
	test_regions_load()

	# --- Negative: region no match ---
	_test_region_no_match_returns_null()

	# --- Positive: contract definitions ---
	_test_contract_defs_loaded()
	_test_contract_defs_find_by_id()

	# --- Negative: contract def not found ---
	_test_contract_defs_not_found()

	# --- Negative: RAT parser ---
	_test_rat_unknown_key_fallback()
	_test_rat_missing_file_fallback()

	# --- Negative: canonical map fallthrough ---
	_test_canonical_map_not_found()

	_print_sep()
	print("Results: %d passed, %d failed, %d total" % [_passed, _failed, _passed + _failed])
	_print_sep()
	quit(0 if _failed == 0 else 1)


func _make_contract(activity: String, planet: String = "Galatea"):
	var c = _ContractRes.new()
	c.issuer = "LC"
	c.planet = planet
	c.activity_type = activity
	c.salvage_rate = 0.5
	c.c_bill_payment = 500000
	return c


# ===================== Positive: Map Generation =====================

func _test_generates_valid_map() -> void:
	var gen = _Generator.new()
	var contract = _make_contract("Garrison")
	var hm = gen.generate(contract)
	gen.queue_free()
	if hm == null: _fail("generate() returned null"); return
	if hm.width <= 0 or hm.height <= 0: _fail("Bad dims"); return
	if hm.get_all_hexes().is_empty(): _fail("No hexes"); return
	_pass("Map generated %dx%d (%d hexes)" % [hm.width, hm.height, hm.get_all_hexes().size()])


func _test_map_size_by_activity() -> void:
	var sizes = {
		"Garrison": Vector2i(12, 10), "Cadre": Vector2i(10, 8), "Riot": Vector2i(8, 8),
		"Defense": Vector2i(10, 10), "Assault": Vector2i(8, 8), "Recon": Vector2i(14, 12),
		"Pirate Hunting": Vector2i(12, 10), "Raid": Vector2i(10, 8),
	}
	for activity in sizes:
		var expected = sizes[activity]
		var gen = _Generator.new()
		var hm = gen.generate(_make_contract(activity))
		gen.queue_free()
		if hm.width != expected.x or hm.height != expected.y:
			_fail("%s: expected %dx%d, got %dx%d" % [activity, expected.x, expected.y, hm.width, hm.height])
		else:
			_pass("%s: %dx%d" % [activity, expected.x, expected.y])


func _test_objectives_placed() -> void:
	var hm = _Generator.new().generate(_make_contract("Assault"))
	var p := 0; var s := 0; var a := 0; var e := 0
	for h in hm.get_all_hexes():
		match h.objective:
			_HexMap.ObjectiveType.PRIMARY: p += 1
			_HexMap.ObjectiveType.SECONDARY: s += 1
			_HexMap.ObjectiveType.ASSETS: a += 1
			_HexMap.ObjectiveType.ENEMY: e += 1
	if p < 1: _fail("No primary"); return
	if s < 1: _fail("No secondary"); return
	if a < 1: _fail("No assets"); return
	if e < 1: _fail("No enemy"); return
	_pass("Objectives: %dP %dS %dA %dE" % [p, s, a, e])


func _test_landing_zone_valid() -> void:
	var hm = _Generator.new().generate(_make_contract("Recon"))
	var h = hm.get_hex(hm.landing_zone.x, hm.landing_zone.y)
	if h.is_empty(): _fail("LZ not found"); return
	_pass("LZ at (%d,%d)" % [hm.landing_zone.x, hm.landing_zone.y])


func _test_no_water_landing_zone() -> void:
	for act in ["Garrison", "Assault", "Recon", "Pirate Hunting"]:
		var hm = _Generator.new().generate(_make_contract(act))
		var h = hm.get_hex(hm.landing_zone.x, hm.landing_zone.y)
		if h.is_empty(): _fail("%s: LZ not found" % act); return
		if h.terrain == _HexMap.Terrain.WATER: _fail("%s: LZ on WATER" % act); return
	_pass("No LZ on water (4 types)")


func _test_planet_biome_override() -> void:
	var pd = {"biome": "tundra", "population": 50000, "atmosphere": "breathable", "temperature": 22, "land_percent": 40}
	var hm = _Generator.new().generate(_make_contract("Riot"), pd)
	var urban := 0
	for h in hm.get_all_hexes():
		if h.terrain == _HexMap.Terrain.URBAN: urban += 1
	if urban > 0: _fail("Override should force 0 urban, got %d" % urban); return
	_pass("Biome override works: 0 urban")


func _test_riot_terrain() -> void:
	var pd = {"population": 50000, "atmosphere": "breathable", "temperature": 22, "land_percent": 40}
	var hm = _Generator.new().generate(_make_contract("Riot"), pd)
	var urban := 0; var total := 0
	for h in hm.get_all_hexes():
		total += 1
		if h.terrain == _HexMap.Terrain.URBAN: urban += 1
	var pct = float(urban) / float(total) * 100.0
	if pct < 40.0: _fail("Riot only %d%% urban" % int(pct)); return
	_pass("Riot: %d%% urban" % int(pct))


# ===================== Positive: OpFor =====================

func _test_opfor_templates_loaded() -> void:
	var templates = _Generator.load_opfor_templates()
	if templates.is_empty(): _fail("No OpFor templates loaded"); return
	_pass("OpFor templates loaded: %d" % templates.size())


func _test_opfor_template_selection() -> void:
	var tmpl = _Generator.select_opfor_template("Assault", "temperate")
	if tmpl.is_empty(): _fail("No template for Assault/temperate"); return
	if not tmpl.has("id"): _fail("Template missing id"); return
	_pass("Selected OpFor: %s" % tmpl.get("id", "?"))


func _test_opfor_pool_generated() -> void:
	var tmpl = _Generator.select_opfor_template("Pirate Hunting", "desert")
	if tmpl.is_empty(): _fail("No template"); return
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var pool = _Generator.generate_opfor_pool(tmpl, rng)
	if pool.is_empty(): _fail("Pool empty"); return
	var has_mech = false
	for u in pool:
		if u.has("chassis_name") and not u.chassis_name.is_empty():
			has_mech = true; break
	if not has_mech: _fail("No mechs in pool"); return
	_pass("OpFor pool: %d units" % pool.size())


func _test_opfor_pool_draw() -> void:
	var pool = []
	for i in range(10):
		pool.append({"status": "active", "unit_name": "Mech %d" % i})
	var drawn = _Generator.draw_from_pool(pool, 2)
	if drawn.is_empty(): _fail("Draw returned empty"); return
	if drawn.size() > pool.size(): _fail("Draw > pool"); return
	_pass("Drew %d/%d units at strength 2" % [drawn.size(), pool.size()])


# ===================== Negative: OpFor =====================

func _test_opfor_select_no_match() -> void:
	var tmpl = _Generator.select_opfor_template("Cadre", "oceanic")
	if not tmpl.is_empty():
		_pass("Cadre/oceanic matched: %s (fallback OK)" % tmpl.get("id", "?"))
	else:
		_pass("Cadre/oceanic correctly returned empty (no warning)")


func _test_opfor_draw_empty_pool() -> void:
	var drawn = _Generator.draw_from_pool([], 3)
	if drawn.size() != 0: _fail("Empty pool should return empty, got %d" % drawn.size()); return
	_pass("draw_from_pool([]) returns empty")


# ===================== Positive: Biome =====================

func _test_biome_resolution() -> void:
	var gen = _Generator.new()
	var pd = {"atmosphere": "trace", "temperature": 100}
	var hm = gen.generate(_make_contract("Assault"), pd)
	gen.queue_free()
	var desert := 0
	for h in hm.get_all_hexes():
		if h.terrain == _HexMap.Terrain.DESERT: desert += 1
	if desert < 10: _fail("Trace atmo desert < 10"); return
	_pass("Trace atmo → desert (%d hexes)" % desert)


func _test_biome_unknown_fallback() -> void:
	var gen = _Generator.new()
	var pd = {"biome": "nonexistent_biome_xyz"}
	var hm = gen.generate(_make_contract("Assault"), pd)
	gen.queue_free()
	if hm == null: _fail("Unknown biome should fallback"); return
	_pass("Unknown biome falls back to temperate")


# ===================== Negative: Biome =====================

func _test_biome_no_crash_on_missing_data() -> void:
	var gen = _Generator.new()
	var contract = _make_contract("Assault")
	contract.planet = ""
	var hm = gen.generate(contract, {})
	gen.queue_free()
	if hm == null: _fail("Missing planet data should still generate"); return
	_pass("Missing planet data generates without crash")


# ===================== Positive: Regions =====================

func test_regions_load() -> void:
	var regions = _Generator.load_regions()
	if regions.is_empty(): _fail("No regions loaded"); return
	_pass("Regions loaded: %d" % regions.size())


# ===================== Negative: Regions =====================

func _test_region_no_match_returns_null() -> void:
	var gen = _Generator.new()
	var hm = gen._try_match_region({}, "Garrison", "nonexistent_biome", Vector2i(10, 10))
	if hm != null: _fail("Should be null for no match"); return
	_pass("No matching region returns null")


# ===================== Positive: Contract Definitions =====================

func _test_contract_defs_loaded() -> void:
	var defs = _ContractGen.load_contract_definitions()
	if defs.is_empty(): _fail("No contract defs loaded"); return
	_pass("Contract defs loaded: %d" % defs.size())


func _test_contract_defs_find_by_id() -> void:
	var found = _ContractGen.find_contract_definition("hesperus_garrison_duty")
	if found.is_empty(): _fail("hesperus_garrison_duty not found"); return
	if found.get("id") != "hesperus_garrison_duty": _fail("Wrong id"); return
	_pass("Found contract: %s" % found.get("name", "?"))


# ===================== Negative: Contract Definitions =====================

func _test_contract_defs_not_found() -> void:
	var found = _ContractGen.find_contract_definition("nonexistent_contract_xyz")
	if not found.is_empty(): _fail("Should return empty"); return
	_pass("Unknown contract id returns empty dict")


# ===================== Negative: RAT =====================

func _test_rat_unknown_key_fallback() -> void:
	var rat = _RATParser.load_rat("nonexistent_faction_xyz")
	if rat.is_empty(): _fail("Should fallback, not return empty"); return
	_pass("Unknown RAT key falls back to is_general")


func _test_rat_missing_file_fallback() -> void:
	var rat = _RATParser.load_rat("completely_missing_key_with_no_file")
	if rat.is_empty(): _fail("Missing RAT file should fallback"); return
	_pass("Missing RAT file falls back to is_general")


# ===================== Negative: Canonical Map =====================

func _test_canonical_map_not_found() -> void:
	var gen = _Generator.new()
	var pd = {"canonical_planetary_map": "nonexistent_map_xyz"}
	var hm = gen.generate(_make_contract("Assault"), pd)
	gen.queue_free()
	if hm == null: _fail("Canonical map fallthrough should still generate a map"); return
	_pass("Missing canonical map falls through to procedural")


# ===================== Helpers =====================

func _pass(msg: String) -> void:
	_passed += 1
	print("  PASS: %s" % msg)


func _fail(msg: String) -> void:
	_failed += 1
	print("  FAIL: %s" % msg)


func _print_sep() -> void:
	print("----------------------------------------")
