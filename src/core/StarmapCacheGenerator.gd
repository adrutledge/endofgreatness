extends Node

## Generates a hex-grid territory cache for the starmap.
##
## Divides the Inner Sphere into 20 LY diameter flat-top hexes.
## Each hex is colored by the faction(s) with systems within 60 LY.
## Multi-faction hexes get striped (contested) rendering.
## This replaces the old Voronoi-pass grid with a coarser hex grid
## that is faster to compute and render, with no territory holes.

const CACHE_PATH = "user://cache/starmap_territory.json"

const HEX_DIAMETER: float = 20.0
const HEX_RADIUS: float = HEX_DIAMETER / 2.0  # 10 LY
const HEX_SIDE: float = HEX_RADIUS  # 10 LY (flat-top: side = radius)
const HEX_HEIGHT: float = HEX_SIDE * sqrt(3.0)  # ~17.32 LY
const HEX_WIDTH: float = HEX_DIAMETER  # 20 LY
const AUTHORITY_RADIUS: float = 60.0  # LY
const AUTHORITY_RADIUS_SQ: float = AUTHORITY_RADIUS * AUTHORITY_RADIUS
const EXTENT: float = 800.0

var _generating: bool = false


func _ready() -> void:
	if _cache_fresh():
		return
	if _generating:
		return
	_generating = true
	call_deferred("_generate")


func _cache_fresh() -> bool:
	var source_mtime = FileAccess.get_modified_time("res://data/systems_index.json")
	if source_mtime < 0:
		return true
	var cache_file = FileAccess.open(CACHE_PATH, FileAccess.READ)
	if not cache_file:
		return false
	var parser = JSON.new()
	if parser.parse(cache_file.get_as_text()) != OK:
		return false
	var data = parser.data
	if data.get("source_mtime", 0) != source_mtime:
		return false
	if data.get("format_version") != 2:
		return false
	return true


func _get_system_positions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DataManager or DataManager.systems_data.is_empty():
		return result
	for name in DataManager.systems_data:
		var sys = DataManager.systems_data[name]
		var owner = sys.get("owner_faction", "")
		if owner.is_empty():
			continue
		var coords = sys.get("coordinates", {})
		var pos = Vector2(coords.get("x", 0.0), -coords.get("y", 0.0))
		var dist = pos.length()
		if dist > 720.0:
			continue
		result.append({"name": name, "pos": pos, "owner": owner})
	return result


func _generate() -> void:
	Helpers.debug_print("StarmapCache", "generating hex territory cache")
	var systems = _get_system_positions()
	var hexes: Array[Dictionary] = []

	# Pre-build spatial index: system positions by 120 LY grid cell for fast lookup
	var spatial_idx: Dictionary = {}
	var cell_size := AUTHORITY_RADIUS * 2.0  # 120 LY
	for s in systems:
		var pos = s["pos"]
		var cell_key = "%d,%d" % [int(floor(pos.x / cell_size)), int(floor(pos.y / cell_size))]
		if not spatial_idx.has(cell_key):
			spatial_idx[cell_key] = []
		spatial_idx[cell_key].append(s)

	var y_start = int(-EXTENT)
	var y_end = int(EXTENT)
	var x_start = int(-EXTENT)
	var x_end = int(EXTENT)

	for row in range(y_start, y_end, int(HEX_HEIGHT)):
		var offset = (abs(row) / int(HEX_HEIGHT)) % 2  # row parity for hex stagger
		for col in range(x_start, x_end, int(HEX_WIDTH * 0.75)):
			var cx = col + offset * (HEX_WIDTH * 0.375)
			var cy = row

			# Skip hexes too far from origin
			if sqrt(cx * cx + cy * cy) > 720.0 + AUTHORITY_RADIUS:
				continue

			# Count systems within AUTHORITY_RADIUS
			var faction_counts: Dictionary = {}
			var cell_cx = int(floor(cx / cell_size))
			var cell_cy = int(floor(cy / cell_size))

			# Check 3x3 neighborhood of spatial grid cells
			for dcx in range(-1, 2):
				for dcy in range(-1, 2):
					var ck = "%d,%d" % [cell_cx + dcx, cell_cy + dcy]
					var cell_systems = spatial_idx.get(ck, [])
					for s in cell_systems:
						var d = cx - s["pos"].x
						if abs(d) > AUTHORITY_RADIUS:
							continue
						var dy = cy - s["pos"].y
						if abs(dy) > AUTHORITY_RADIUS:
							continue
						if d * d + dy * dy <= AUTHORITY_RADIUS_SQ:
							var owner = s["owner"]
							if owner in ["I", "X", "U", "A"]:
								continue
							faction_counts[owner] = faction_counts.get(owner, 0) + 1

			if faction_counts.is_empty():
				continue

			hexes.append({
				"cx": cx,
				"cy": cy,
				"factions": faction_counts,
			})

	_save_cache(hexes)
	_generating = false
	Helpers.debug_print("StarmapCache", "hex territory cache saved (%d hexes)" % hexes.size())


func _save_cache(hexes: Array) -> void:
	var data = {
		"format_version": 2,
		"source_mtime": FileAccess.get_modified_time("res://data/systems_index.json"),
		"hex_metadata": {
			"diameter": HEX_DIAMETER,
			"radius": HEX_RADIUS,
			"authority_radius": AUTHORITY_RADIUS,
			"extent": EXTENT,
		},
		"hexes": [],
	}

	for h in hexes:
		var factions_list: Array[Dictionary] = []
		for f in h["factions"]:
			factions_list.append({"id": f, "count": h["factions"][f]})
		data["hexes"].append({
			"cx": h["cx"],
			"cy": h["cy"],
			"factions": factions_list,
		})

	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("user://cache"):
		dir.make_dir("user://cache")
	var file = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.new().stringify(data))
