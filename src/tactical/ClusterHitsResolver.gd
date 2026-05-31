extends Node

## Resolves cluster weapon hit counts using the Total Warfare cluster hits table.
## Table: data/rules/cluster_hits.json
##
## Usage:
##   var resolver = ClusterHitsResolver.new()
##   var hits = resolver.resolve(shots_fired)  # returns number of hits (2d6 table lookup)

var _table: Dictionary = {}


func _ready() -> void:
	var file = FileAccess.open("res://data/rules/cluster_hits.json", FileAccess.READ)
	if not file:
		return
	var j = JSON.new()
	if j.parse(file.get_as_text()) != OK:
		return
	_table = j.data.get("table", {})


## Returns the number of missiles/projectiles that hit based on the cluster table.
## shots: total missiles fired (e.g., 20 for LRM-20).
## roll: optional pre-rolled 2d6 value (omit to auto-roll).
func resolve(shots: int, roll: int = -1) -> int:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var r = roll if roll >= 2 else rng.randi_range(2, 12)

	var key = str(shots)
	if _table.has(key):
		return _table_get(key, r)

	var nearest = ""
	for k in _table.keys():
		if int(k) >= shots:
			nearest = k
			break
	if nearest.is_empty():
		for k in _table.keys():
			if nearest.is_empty() or int(k) > int(nearest):
				nearest = k
	if nearest.is_empty():
		return shots

	return mini(_table_get(nearest, r), shots)


func _table_get(key: String, roll: int) -> int:
	var row = _table.get(key, [])
	var idx = roll - 2
	if idx >= 0 and idx < row.size():
		return row[idx]
	return roll
