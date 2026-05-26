extends SceneTree

var _passed := 0
var _failed := 0
var _defs: Dictionary
var _Market: GDScript


func _init() -> void:
	_Market = load("res://src/systems/PlanetaryMarket.gd")
	_defs = _load_component_defs()

	_print_sep()
	print("PlanetaryMarket Population Tests")
	_print_sep()

	_test_scarcity_tiers()
	_test_galatea_market()
	_test_lazy_rebuild()

	_print_sep()
	print("Results: %d passed, %d failed, %d total" % [_passed, _failed, _passed + _failed])
	_print_sep()
	quit(0 if _failed == 0 else 1)


func _load_component_defs() -> Dictionary:
	var defs := {}
	var dir = DirAccess.open("res://data/components")
	if not dir:
		return defs
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if f.ends_with(".json"):
			var file = FileAccess.open("res://data/components/" + f, FileAccess.READ)
			if file:
				var j = JSON.new()
				if j.parse(file.get_as_text()) == OK:
					defs[j.data.get("name", "")] = j.data
		f = dir.get_next()
	return defs


func _check_populated(comp_name: String, inv: Dictionary) -> bool:
	return inv.has(comp_name) and inv[comp_name].get("quantity", 0) > 0


func _test_scarcity_tiers() -> void:
	var market = _Market.new()
	market._test_defs = _defs
	var empty_factions: Array[String] = []
	market.setup(empty_factions, "")
	var components_by_tier := {0: [], 1: [], 2: [], 3: [], 4: []}
	for name in _defs:
		var def = _defs[name]
		var tier = market.scarcity_tier(name, def)
		if components_by_tier.has(tier):
			components_by_tier[tier].append(name)

	var check := func(label: String, t: int, expected: Array[String]) -> void:
		for token in expected:
			var found := false
			for name in components_by_tier[t]:
				if name.to_lower().contains(token):
					found = true
					break
			if found:
				_pass("%s: %s in tier %d" % [label, token, t])
			else:
				_fail("%s: %s NOT in tier %d" % [label, token, t])

	var ammo_armor: Array[String] = ["ammo", "armor"]
	check.call("tier 0", 0, ammo_armor)
	var easy: Array[String] = ["heat sink", "actuator", "jump jet"]
	check.call("tier 1", 1, easy)
	var medium: Array[String] = ["autocannon", "lrm", "srm", "machine gun", "flamer"]
	check.call("tier 2", 2, medium)
	var hard: Array[String] = ["laser", "ppc"]
	check.call("tier 3", 3, hard)
	var vhard: Array[String] = ["engine", "gyro", "cockpit"]
	check.call("tier 4", 4, vhard)

	# Verify no component falls through to no tier (all mapped)
	var unmapped := 0
	for name in _defs:
		var def = _defs[name]
		var tier = market.scarcity_tier(name, def)
		if not components_by_tier.has(tier):
			unmapped += 1
	if unmapped == 0:
		_pass("All components mapped to a tier")
	else:
		_fail("%d components unmapped" % unmapped)


func _test_galatea_market() -> void:
	# Simulate Galatea's faction list (all non-rebel/periphery except MRB/CS)
	var faction_codes: Array[String] = ["CC", "DC", "FS", "FWL", "LC", "MC", "OA", "TC"]
	var market = _Market.new()
	market._test_defs = _defs
	market.setup(faction_codes, "")

	var inv = market.inventory
	if inv.is_empty():
		_fail("Galatea market: inventory is empty")
		return
	_pass("Galatea market: %d unique items" % inv.size())

	# Every item should have quantity > 0
	var zero_qty := 0
	var tier0_low := 0
	var tier4_high := 0
	for name in inv:
		var entry = inv[name]
		if entry.quantity <= 0:
			zero_qty += 1
		var def = _defs.get(name, {})
		var tier = market.scarcity_tier(name, def)
		if tier == 0 and entry.quantity < 10:
			tier0_low += 1
		if tier == 4 and entry.quantity > 10:
			tier4_high += 1

	if zero_qty == 0:
		_pass("All items have positive quantity")
	else:
		_fail("%d items have zero quantity" % zero_qty)

	if tier0_low == 0:
		_pass("Tier 0 (ammo/armor) items have >= 10 stock")
	else:
		_fail("%d tier 0 items have < 10 stock" % tier0_low)

	if tier4_high == 0:
		_pass("Tier 4 (engines/gyros) items have <= 10 stock")
	else:
		_fail("%d tier 4 items have > 10 stock" % tier4_high)


func _test_lazy_rebuild() -> void:
	var market = _Market.new()
	market._test_defs = _defs
	var empty_factions: Array[String] = []
	market.setup(empty_factions, "")

	var before_count = market.inventory.size()
	market.mark_for_rebuild()
	_ensure_fresh(market)
	var after_count = market.inventory.size()
	if after_count == before_count:
		_pass("Lazy rebuild: inventory unchanged")
	else:
		_fail("Lazy rebuild: inventory count changed (%d -> %d)" % [before_count, after_count])

	# Verify lazy: mark_for_rebuild sets flag, get_available_items triggers rebuild
	market.mark_for_rebuild()
	var items = market.get_available_items()
	if items.size() > 0:
		_pass("Lazy rebuild: get_available_items triggers rebuild")
	else:
		_fail("Lazy rebuild: get_available_items returned empty")


func _ensure_fresh(market) -> void:
	market._ensure_fresh()


func _pass(n: String) -> void:
	_passed += 1
	print("  PASS  %s" % n)


func _fail(n: String) -> void:
	_failed += 1
	print("  FAIL  %s" % n)


func _print_sep() -> void:
	var s := ""
	for i in range(60):
		s += "="
	print(s)
