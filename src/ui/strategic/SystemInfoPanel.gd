class_name SystemInfoPanel
extends VBoxContainer

var system_data: Dictionary = {}

@onready var name_label: Label = %NameLabel
@onready var spectral_label: Label = %SpectralLabel
@onready var factions_label: Label = %FactionsLabel
@onready var player_label: Label = %PlayerLabel
@onready var details_container: VBoxContainer = %DetailsContainer

func _ready() -> void:
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	player_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	add_theme_constant_override("separation", 4)
	hide()

func show_system(data: Dictionary) -> void:
	system_data = data
	name_label.text = data.get("name", "Unknown")
	spectral_label.text = tr("Spectral Class: ") + data.get("spectral_class", "Unknown")

	var owner = data.get("owner_faction", "")
	var owner_name = owner
	var faction = GameState.factions.get(owner) if owner else null
	if faction:
		owner_name = faction.faction_name
	var faction_display = tr("Owner: ") + owner_name if owner else tr("Unowned")
	var factions_present = data.get("factions_present", [])
	if factions_present is Array and factions_present.size() > 0:
		faction_display += "\n" + tr("Present: ") + ", ".join(factions_present)
	factions_label.text = faction_display

	var player_present = GameState.player.current_planet == data.get("name", "")
	player_label.text = tr("Player units present")
	player_label.visible = player_present

	var bodies = data.get("planets", [])
	var subtitle := Label.new()
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	subtitle.text = tr("Inhabited Objects: %d") % bodies.size()
	details_container.add_child(subtitle)
	_populate_planets(bodies)
	show()

func _populate_planets(planets: Array) -> void:
	for child in details_container.get_children():
		child.queue_free()

	if planets.is_empty():
		var lbl := Label.new()
		lbl.text = tr("No planets")
		details_container.add_child(lbl)
		return

	for p in planets:
		var section := VBoxContainer.new()
		var title := Label.new()
		title.text = p.get("name", "Unnamed")
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", Color(1, 1, 0.7))
		section.add_child(title)

		var info := Label.new()
		var lines: Array[String] = []
		var gravity = p.get("gravity")
		if gravity != null:
			lines.append("Gravity: " + str(gravity) + "g")
		var atmo = p.get("atmosphere")
		if atmo:
			lines.append("Atmosphere: " + atmo)
		var temp = p.get("temperature")
		if temp != null:
			lines.append("Temperature: " + str(temp) + "C")
		var pop = p.get("population")
		if pop != null:
			lines.append("Population: " + str(pop))
		var industry = p.get("industry_type")
		if industry:
			lines.append("Industry: " + industry)

		var usilr = p.get("usilr_code", {})
		if usilr is Dictionary and not usilr.is_empty():
			var parts: Array[String] = []
			for key in ["tech_sophistication", "industrial_development", "raw_material_dependence", "industrial_output", "agricultural_dependence"]:
				var val = usilr.get(key)
				if val != null:
					parts.append(key.replace("_", " ").capitalize() + ": " + str(val))
			if parts.size() > 0:
				lines.append("USILR: " + ", ".join(parts))

		info.text = "\n".join(lines) if not lines.is_empty() else ""
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section.add_child(info)

		var hpg = p.get("hpg_class")
		if hpg:
			var hpg_label := Label.new()
			hpg_label.text = tr("HPG: Class ") + str(hpg)
			section.add_child(hpg_label)

		var relay = p.get("relay_station")
		if relay == true:
			var relay_label := Label.new()
			relay_label.text = tr("Relay Station present")
			relay_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
			section.add_child(relay_label)

		var separator := HSeparator.new()
		section.add_child(separator)

		details_container.add_child(section)

func hide_panel() -> void:
	hide()
