extends Node

## Generates a HexMap for a planetary operation based on contract and planet data.

const MAP_SIZES: Dictionary = {
	"Garrison": Vector2i(12, 10),
	"Cadre": Vector2i(10, 8),
	"Riot": Vector2i(8, 8),
	"Defense": Vector2i(10, 10),
	"Assault": Vector2i(8, 8),
	"Recon": Vector2i(14, 12),
	"Pirate Hunting": Vector2i(12, 10),
	"Raid": Vector2i(10, 8),
}


func generate(contract: Contract) -> HexMap:
	var size = MAP_SIZES.get(contract.activity_type, Vector2i(10, 10))
	var hex_map = HexMap.new(size.x, size.y)

	var planet_data = _get_planet_data(contract.planet)
	var biome = _derive_biome(planet_data)

	_assign_terrain(hex_map, biome)
	_place_objectives(hex_map, contract)

	return hex_map


func _get_planet_data(planet_name: String) -> Dictionary:
	var sys_data = DataManager.get_system_detail(planet_name)
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


func _derive_biome(planet_data: Dictionary) -> String:
	var atmo = planet_data.get("atmosphere", "breathable")
	var temp = planet_data.get("temperature", 22)
	if atmo == "none" or atmo == "trace":
		return "desert"
	if temp > 50:
		return "desert"
	if temp < -20:
		return "tundra"
	if planet_data.get("land_percent", 40) < 20:
		return "oceanic"
	return "temperate"


func _assign_terrain(hex_map: HexMap, biome: String) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var weights: Dictionary = {
		"temperate": {HexMap.Terrain.PLAINS: 50, HexMap.Terrain.FOREST: 20, HexMap.Terrain.MOUNTAIN: 10, HexMap.Terrain.WATER: 10, HexMap.Terrain.ROUGH: 10},
		"desert": {HexMap.Terrain.DESERT: 60, HexMap.Terrain.MOUNTAIN: 15, HexMap.Terrain.PLAINS: 15, HexMap.Terrain.ROUGH: 10},
		"tundra": {HexMap.Terrain.PLAINS: 40, HexMap.Terrain.MOUNTAIN: 20, HexMap.Terrain.WATER: 15, HexMap.Terrain.FOREST: 10, HexMap.Terrain.ROUGH: 15},
		"oceanic": {HexMap.Terrain.WATER: 50, HexMap.Terrain.PLAINS: 25, HexMap.Terrain.FOREST: 15, HexMap.Terrain.ROUGH: 10},
	}

	var biome_weights = weights.get(biome, weights["temperate"])
	for row in hex_map.hexes:
		for h in row:
			var roll = rng.randf() * 100.0
			var cumulative: float = 0.0
			for terrain_type in biome_weights:
				cumulative += biome_weights[terrain_type]
				if roll <= cumulative:
					h.terrain = terrain_type
					break


func _place_objectives(hex_map: HexMap, contract: Contract) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var all_hexes = hex_map.get_all_hexes()
	if all_hexes.is_empty():
		return

	rng.shuffle(all_hexes)

	var primary_count := 1
	var secondary_count := rng.randi_range(1, 2)
	var salvage_count := rng.randi_range(0, 3)
	var enemy_count := rng.randi_range(1, 3)

	var idx := 0
	for i in range(primary_count):
		if idx >= all_hexes.size():
			break
		all_hexes[idx].objective = HexMap.ObjectiveType.PRIMARY
		all_hexes[idx].objective_data = {"type": contract.activity_type}
		idx += 1

	for i in range(secondary_count):
		if idx >= all_hexes.size():
			break
		all_hexes[idx].objective = HexMap.ObjectiveType.SECONDARY
		all_hexes[idx].objective_data = {"type": "supply_cache"}
		idx += 1

	for i in range(salvage_count):
		if idx >= all_hexes.size():
			break
		all_hexes[idx].objective = HexMap.ObjectiveType.SALVAGE
		all_hexes[idx].objective_data = {"value": rng.randi_range(1000, 50000)}
		idx += 1

	for i in range(enemy_count):
		if idx >= all_hexes.size():
			break
		all_hexes[idx].objective = HexMap.ObjectiveType.ENEMY
		all_hexes[idx].objective_data = {"strength": rng.randi_range(1, 3)}
		idx += 1
