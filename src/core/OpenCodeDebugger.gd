extends Node

var enabled: bool = false
var pipe_mode: bool = false
var headless: bool = false
var load_save_path: String = ""
var tcp_port: int = 12075

var log_entries: Array[Dictionary] = []
const MAX_LOG_ENTRIES: int = 1000
const LOG_FILE: String = "user://opencode_debug.jsonl"
const MAX_PROBE_DEPTH: int = 3
const HEADLESS_AUTOSAVE_PREFIX: String = "headless_autosave"

var _output_file: FileAccess = null
var _tcp_server: TCPServer = null
var _tcp_connection: StreamPeerTCP = null
var _tcp_buffer: String = ""

var _response_sink: Callable = Callable()


func _ready() -> void:
	_parse_flags()
	if not enabled:
		return
	_open_output_file()
	_setup_tcp()
	if headless:
		_configure_headless()
	debug_log("INFO", "opencode", "OpenCodeDebugger ready — port=%d pipe=%s headless=%s" % [tcp_port, pipe_mode, headless])


func _exit_tree() -> void:
	_tcp_connection = null
	if _tcp_server:
		_tcp_server.stop()
		_tcp_server = null
	if _output_file:
		_output_file.close()


func _parse_flags() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--opencode-debug":
			enabled = true
		elif arg == "--opencode-pipe":
			enabled = true
			pipe_mode = true
		elif arg == "--opencode-headless":
			enabled = true
			headless = true
		elif arg.begins_with("--opencode-port="):
			tcp_port = clampi(int(arg.trim_prefix("--opencode-port=")), 0, 65535)
		elif arg.begins_with("--load-save="):
			load_save_path = arg.trim_prefix("--load-save=")
	if not enabled:
		var env = OS.get_environment("OPENCODE_DEBUG")
		if env and env.to_lower() in ["1", "true", "yes"]:
			enabled = true


func _open_output_file() -> void:
	_output_file = FileAccess.open(LOG_FILE, FileAccess.WRITE)
	if _output_file:
		_emit({"type": "ready", "version": "1.0.0"})
	else:
		printerr("[OpenCodeDebugger] Failed to open %s" % LOG_FILE)


func _setup_tcp() -> void:
	if tcp_port <= 0:
		return
	_tcp_server = TCPServer.new()
	if _tcp_server.listen(tcp_port) != OK:
		printerr("[OpenCodeDebugger] Failed to listen on port %d" % tcp_port)
		_tcp_server = null
		debug_log("WARN", "opencode", "TCP port %d unavailable" % tcp_port)


func _configure_headless() -> void:
	if DisplayServer and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	if SaveManager:
		SaveManager.AUTOSAVE_PREFIX = HEADLESS_AUTOSAVE_PREFIX



func _process(_delta: float) -> void:
	if not enabled:
		return
	_poll_tcp()


func _poll_tcp() -> void:
	if not _tcp_server:
		return
	if not _tcp_connection and _tcp_server.is_connection_available():
		_tcp_connection = _tcp_server.take_connection()
		if _tcp_connection:
			debug_log("INFO", "opencode", "TCP client connected")
	if _tcp_connection and _tcp_connection.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var result = _tcp_connection.get_partial_data(4096)
		while result[0] == OK and result[1].size() > 0:
			_tcp_buffer += result[1].get_string_from_utf8()
			_process_tcp_lines()
			result = _tcp_connection.get_partial_data(4096)
	if _tcp_connection and _tcp_connection.get_status() == StreamPeerTCP.STATUS_NONE:
		debug_log("INFO", "opencode", "TCP client disconnected")
		_tcp_connection = null


func _process_tcp_lines() -> void:
	while "\n" in _tcp_buffer:
		var idx = _tcp_buffer.find("\n")
		var line = _tcp_buffer.substr(0, idx)
		_tcp_buffer = _tcp_buffer.substr(idx + 1)
		line = line.strip_edges()
		if line.is_empty():
			continue
		_handle_tcp_command(line)


func _send_response(data: Dictionary) -> void:
	if _response_sink.is_valid():
		_response_sink.call(data)
		return
	if not _tcp_connection:
		return
	if _tcp_connection.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var json_str = JSON.stringify(data) + "\n"
	_tcp_connection.put_data(json_str.to_utf8_buffer())


func _handle_tcp_command(json_str: String) -> void:
	var j = JSON.new()
	if j.parse(json_str) != OK:
		_send_response({"ok": false, "error": "parse error: " + j.get_error_message()})
		return
	var data = j.data
	if typeof(data) != TYPE_DICTIONARY:
		_send_response({"ok": false, "error": "expected object"})
		return
	var cmd = data.get("cmd", "")
	match cmd:
		"probe":
			_handle_probe()
		"get_log":
			_handle_get_log(data.get("count", 50))
		"get_state":
			_send_response({"ok": true, "state": _probe_state()})
		"get_ui":
			_send_response({"ok": true, "ui": _probe_ui()})
		"dump_org":
			_handle_dump_org()
		"advance":
			_handle_advance(data.get("days", 1))
		"pause":
			_handle_pause()
		"unpause":
			_handle_unpause()
		"set_speed":
			_handle_set_speed(data)
		"save":
			_handle_save(data.get("name", "opencode_checkpoint"))
		"load":
			_handle_load(data.get("path", ""))
		"add_funds":
			_handle_add_funds(data.get("amount", 0))
		"set_funds":
			_handle_set_funds(data.get("amount", 0))
		"add_item":
			_handle_add_item(data.get("name", ""), data.get("quantity", 1))
		"remove_item":
			_handle_remove_item(data.get("name", ""), data.get("quantity", 1))
		"add_personnel":
			_handle_add_personnel(data)
		"remove_personnel":
			_handle_remove_personnel(data.get("name", ""))
		"add_unit":
			_handle_add_unit(data)
		"remove_unit":
			_handle_remove_unit(data.get("id", ""))
		"quit":
			_handle_quit()
		_:
			_send_response({"ok": false, "error": "unknown command: " + cmd})


func _handle_probe() -> void:
	_send_response({
		"ok": true,
		"snapshot": {
			"ui": _probe_ui(),
			"state": _probe_state(),
		}
	})


func _handle_get_log(count: int) -> void:
	var entries = log_entries.slice(-clampi(count, 1, MAX_LOG_ENTRIES))
	_send_response({"ok": true, "entries": entries})


func _handle_dump_org() -> void:
	if not is_instance_valid(GameState.player):
		_send_response({"ok": false, "error": "no player state"})
		return
	var tree := []
	for ou in GameState.player.organizational_units:
		tree.append(_dump_org_unit(ou))
	_send_response({"ok": true, "org_tree": tree})


func _dump_org_unit(ou) -> Dictionary:
	var d: Dictionary = {
		"name": ou.unit_name,
		"type": "OrganizationalUnit",
		"sub_units": [],
	}
	for opu in ou.sub_units:
		d.sub_units.append(_dump_op_unit(opu))
	return d


func _dump_op_unit(opu) -> Dictionary:
	var d: Dictionary = {
		"name": opu.unit_name,
		"type": "OperationalUnit",
		"tactical_units": [],
	}
	if opu.commander:
		d["commander"] = opu.commander.personnel_name
	for tu in opu.tactical_units:
		d.tactical_units.append({
			"id": tu.unit_id,
			"name": tu.unit_name,
			"chassis": tu.chassis_name,
			"model": tu.model_name,
			"tonnage": tu.tonnage,
			"type": Enums.UnitType.keys()[tu.unit_type] if tu.unit_type != null else "",
		})
	return d


func _handle_advance(days: int) -> void:
	var tm = TimeManager
	if not tm:
		_send_response({"ok": false, "error": "TimeManager not available"})
		return
	days = clampi(days, 1, 365)
	var advanced = 0
	for i in range(days):
		tm.advance_day()
		advanced += 1
	var date = _game_time()
	_send_response({"ok": true, "days_advanced": advanced, "current_date": date})


func _handle_pause() -> void:
	var tm = TimeManager
	if tm:
		tm.is_paused = true
	_send_response({"ok": true, "paused": true})


func _handle_unpause() -> void:
	var tm = TimeManager
	if tm:
		tm.is_paused = false
	_send_response({"ok": true, "paused": false})


func _handle_set_speed(data: Dictionary) -> void:
	var tm = TimeManager
	if tm:
		if data.has("interval"):
			tm.tick_interval = maxf(0.01, float(data.interval))
		if data.has("paused"):
			tm.is_paused = bool(data.paused)
	_send_response({"ok": true,
		"interval": tm.tick_interval if tm else null,
		"paused": tm.is_paused if tm else null,
	})


func _handle_save(name: String) -> void:
	var sm = SaveManager
	if not sm:
		_send_response({"ok": false, "error": "SaveManager not available"})
		return
	var result = sm.manual_save(name)
	_send_response({"ok": result.success == true, "path": result.get("path", ""), "filename": result.get("filename", "")})


func _handle_load(path: String) -> void:
	var sm = SaveManager
	if not sm:
		_send_response({"ok": false, "error": "SaveManager not available"})
		return
	var result = sm.load_game(path)
	var date = _game_time()
	_send_response({"ok": result.success == true, "date": date, "error": result.get("reason", "")})


func _handle_add_funds(amount: int) -> void:
	var gs = GameState
	if not gs or not is_instance_valid(gs.player):
		_send_response({"ok": false, "error": "no player state"})
		return
	gs.player.current_balance += amount
	_send_response({"ok": true, "new_balance": gs.player.current_balance})


func _handle_set_funds(amount: int) -> void:
	var gs = GameState
	if not gs or not is_instance_valid(gs.player):
		_send_response({"ok": false, "error": "no player state"})
		return
	gs.player.current_balance = amount
	_send_response({"ok": true, "new_balance": gs.player.current_balance})


func _handle_add_item(name: String, quantity: int) -> void:
	if name.is_empty() or quantity <= 0:
		_send_response({"ok": false, "error": "invalid item name or quantity"})
		return
	var gs = GameState
	if not gs:
		_send_response({"ok": false, "error": "no game state"})
		return
	var cur = gs.player_inventory.get(name, 0)
	gs.player_inventory[name] = cur + quantity
	var eb = EventBus
	if eb:
		eb.emit_inventory_changed(name, quantity, "opencode_debug")
	_send_response({"ok": true, "new_total": gs.player_inventory[name]})


func _handle_remove_item(name: String, quantity: int) -> void:
	if name.is_empty() or quantity <= 0:
		_send_response({"ok": false, "error": "invalid item name or quantity"})
		return
	var gs = GameState
	if not gs:
		_send_response({"ok": false, "error": "no game state"})
		return
	if not gs.player_inventory.has(name):
		_send_response({"ok": false, "error": "item not found"})
		return
	var cur = gs.player_inventory[name]
	var removed = mini(cur, quantity)
	gs.player_inventory[name] = cur - removed
	if gs.player_inventory[name] <= 0:
		gs.player_inventory.erase(name)
	var eb = EventBus
	if eb:
		eb.emit_inventory_changed(name, -removed, "opencode_debug")
	_send_response({"ok": true, "new_total": gs.player_inventory.get(name, 0)})


func _handle_add_personnel(data: Dictionary) -> void:
	var pm = PersonnelManager
	if not pm:
		_send_response({"ok": false, "error": "PersonnelManager not available"})
		return
	var role = _parse_role(data.get("role", "civilian"))
	var pname = data.get("name", "")
	var p = pm.create_personnel(role, pname)
	if data.has("skills") and typeof(data.skills) == TYPE_DICTIONARY:
		for sk in data.skills:
			p.skills[sk] = data.skills[sk]
	pm.hire_personnel(p)
	_send_response({"ok": true, "personnel_name": p.personnel_name})


func _parse_role(role_str: String) -> int:
	var normalized = role_str.to_upper().strip_edges()
	var keys = Enums.PersonnelRole.keys()
	for i in range(keys.size()):
		if keys[i] == normalized:
			return i
	match normalized:
		"MECHWARRIOR", "PILOT", "MECH_WARRIOR":
			return Enums.PersonnelRole.MECHWARRIOR
		"VEHICLE_CREW", "CREW":
			return Enums.PersonnelRole.CREW
		"AEROSPACE_PILOT", "AERO_PILOT":
			return Enums.PersonnelRole.AEROSPACE_PILOT
		"VTOL_PILOT":
			return Enums.PersonnelRole.VTOL_PILOT
		"TECH", "TECHNICIAN":
			return Enums.PersonnelRole.TECHNICIAN
		"DOCTOR", "MEDICAL":
			return Enums.PersonnelRole.DOCTOR
		"MEDIC":
			return Enums.PersonnelRole.MEDIC
		"LOGISTICS", "LOGISTICAL":
			return Enums.PersonnelRole.LOGISTICAL
		"TRANSPORT":
			return Enums.PersonnelRole.TRANSPORT
		"COMMAND":
			return Enums.PersonnelRole.COMMAND
		"HR":
			return Enums.PersonnelRole.HR
		"INFANTRY":
			return Enums.PersonnelRole.INFANTRY
		_:
			return Enums.PersonnelRole.CIVILIAN


func _handle_remove_personnel(name: String) -> void:
	if name.is_empty():
		_send_response({"ok": false, "error": "name required"})
		return
	var pm = PersonnelManager
	if not pm:
		_send_response({"ok": false, "error": "PersonnelManager not available"})
		return
	for p in pm.personnel_roster:
		if p.personnel_name == name:
			pm.remove_personnel(p, "debug_removed")
			_send_response({"ok": true})
			return
	_send_response({"ok": false, "error": "personnel not found: " + name})


func _handle_add_unit(data: Dictionary) -> void:
	var chassis = data.get("chassis", "")
	var variant = data.get("variant", "")
	var org_name = data.get("org_unit", "")
	if chassis.is_empty():
		_send_response({"ok": false, "error": "chassis required"})
		return
	var dm = DataManager
	if not dm:
		_send_response({"ok": false, "error": "DataManager not available"})
		return
	var matches: Array[TacticalUnit] = []
	for tu in dm.unit_templates.values():
		if tu.chassis_name.to_lower() == chassis.to_lower():
			if variant.is_empty() or tu.model_name.to_lower() == variant.to_lower():
				matches.append(tu)
	if matches.is_empty():
		_send_response({"ok": false, "error": "no match for chassis '%s'" % chassis})
		return
	var template = matches[randi() % matches.size()]
	var unit = _deep_copy_unit(template)
	if not _place_unit_in_org(unit, org_name):
		_send_response({"ok": false, "error": "failed to place unit in org tree"})
		return
	debug_log("INFO", "opencode", "Unit added: %s (%s)" % [unit.unit_name, unit.unit_id])
	_send_response({"ok": true, "unit_id": unit.unit_id, "unit_name": unit.unit_name})


func _deep_copy_unit(source: TacticalUnit) -> TacticalUnit:
	var unit = TacticalUnit.new()
	unit.unit_name = source.unit_name
	unit.chassis_name = source.chassis_name
	unit.model_name = source.model_name
	unit.unit_type = source.unit_type
	unit.engine_rating = source.engine_rating
	unit.engine_type = source.engine_type
	unit.gyro_type = source.gyro_type
	unit.internal_structure_type = source.internal_structure_type
	unit.armor_type = source.armor_type
	unit.total_armor_points = source.total_armor_points
	unit.heat_sink_count = source.heat_sink_count
	unit.tonnage = source.tonnage
	unit.movement_mp = source.movement_mp
	unit.run_mp = source.run_mp
	unit.jump_mp = source.jump_mp
	unit.motion_type = source.motion_type
	unit.abstract_crew_count = source.abstract_crew_count
	unit.rules_level = source.rules_level
	unit.era = source.era
	for c in source.components:
		var copy = Component.new()
		copy.component_name = c.component_name
		copy.component_type = c.component_type
		copy.tonnage = c.tonnage
		copy.critical_slots = c.critical_slots
		copy.cost = c.cost
		copy.tech_base = c.tech_base
		copy.tech_level = c.tech_level
		copy.quality_range = c.quality_range
		copy.repair_difficulty = c.repair_difficulty
		copy.status = Enums.ComponentStatus.UNDAMAGED
		if c.location:
			var loc_copy = ComponentLocation.new()
			loc_copy.location_name = c.location.location_name
			loc_copy.hit_chance = c.location.hit_chance
			loc_copy.armor = c.location.armor
			loc_copy.rear_armor = c.location.rear_armor
			loc_copy.structure = c.location.structure
			loc_copy.max_armor = c.location.max_armor
			loc_copy.max_structure = c.location.max_structure
			copy.location = loc_copy
		unit.components.append(copy)
	return unit


func _place_unit_in_org(unit: TacticalUnit, org_name: String) -> bool:
	var gs = GameState
	if not gs or not is_instance_valid(gs.player):
		return false
	if gs.player.organizational_units.is_empty():
		var batch = OrganizationalUnit.new()
		batch.unit_name = "Debug Battalion"
		gs.player.organizational_units.append(batch)
	if org_name.is_empty():
		var batch = gs.player.organizational_units[0]
		if batch.sub_units.is_empty():
			var lance = OperationalUnit.new()
			lance.unit_name = "Debug Lance"
			lance.role = "Line"
			batch.sub_units.append(lance)
		batch.sub_units[0].tactical_units.append(unit)
		return true
	for ou in gs.player.organizational_units:
		if ou.unit_name == org_name:
			if ou.sub_units.is_empty():
				var lance = OperationalUnit.new()
				lance.unit_name = org_name + " Lance"
				lance.role = "Line"
				ou.sub_units.append(lance)
			ou.sub_units[0].tactical_units.append(unit)
			return true
		for opu in ou.sub_units:
			if opu.unit_name == org_name:
				opu.tactical_units.append(unit)
				return true
	var new_lance = OperationalUnit.new()
	new_lance.unit_name = org_name
	new_lance.role = "Line"
	new_lance.tactical_units.append(unit)
	gs.player.organizational_units[0].sub_units.append(new_lance)
	return true


func _handle_remove_unit(id: String) -> void:
	if id.is_empty():
		_send_response({"ok": false, "error": "unit_id required"})
		return
	var gs = GameState
	if not gs or not is_instance_valid(gs.player):
		_send_response({"ok": false, "error": "no player state"})
		return
	for ou in gs.player.organizational_units:
		for opu in ou.sub_units:
			for i in range(opu.tactical_units.size()):
				if opu.tactical_units[i].unit_id == id:
					var tu = opu.tactical_units[i]
					for crew in tu.crew:
						crew.assigned_unit_id = ""
					tu.crew.clear()
					opu.tactical_units.remove_at(i)
					debug_log("INFO", "opencode", "Unit removed: %s (%s)" % [tu.unit_name, id])
					_send_response({"ok": true})
					return
	_send_response({"ok": false, "error": "unit not found: " + id})


func _handle_quit() -> void:
	_send_response({"ok": true})
	debug_log("INFO", "opencode", "Quit requested")
	get_tree().quit()



func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey and event.keycode == KEY_F6 and event.pressed and not event.echo:
		probe_snapshot("keybind_F6")
		get_viewport().set_input_as_handled()



func debug_log(level: String, category: String, message: String) -> void:
	if not enabled:
		return
	var entry := {
		"time": _timestamp(),
		"level": level,
		"category": category,
		"message": message,
	}
	log_entries.append(entry)
	if log_entries.size() > MAX_LOG_ENTRIES:
		log_entries.pop_front()
	printerr("[%s][%s] %s" % [level, category, message])
	_emit({"type": "log", "entry": entry})


func _emit(data: Dictionary) -> void:
	var line = JSON.stringify(data)
	if _output_file:
		_output_file.store_line(line)
		_output_file.flush()
	if pipe_mode:
		print(line)



func probe_snapshot(reason: String = "manual") -> void:
	if not enabled:
		return
	var snapshot := {
		"type": "snapshot",
		"reason": reason,
		"timestamp": _timestamp(),
		"game_time": _game_time(),
		"ui": _probe_ui(),
		"state": _probe_state(),
	}
	_emit(snapshot)


func _probe_ui() -> Dictionary:
	var result := {}
	var pm = PanelManager
	if not pm:
		return result
	for name in pm._panels:
		var pd = pm._panels[name] as Dictionary
		var node = pd.get("node", null) as Control
		if node and node.visible:
			result[name] = _dump_control(node, 0)
	return result


func _dump_control(node: Control, depth: int) -> Dictionary:
	var d := {
		"type": node.get_class(),
		"visible": node.visible,
		"rect": [node.position.x, node.position.y, node.size.x, node.size.y],
	}
	var text = node.get("text")
	if text != null:
		d["text"] = str(text)
	var disabled = node.get("disabled")
	if disabled != null:
		d["disabled"] = disabled
	var selected = node.get("selected")
	if selected != null:
		d["selected"] = selected
	var value = node.get("value")
	if value != null:
		d["value"] = value
	var item_count = node.get("item_count")
	if item_count != null:
		d["item_count"] = item_count
	if depth < MAX_PROBE_DEPTH:
		var children := []
		for child in node.get_children():
			if child is Control:
				children.append(_dump_control(child, depth + 1))
		if children:
			d["children"] = children
	return d


func _probe_state() -> Dictionary:
	var s := {}
	var gs = GameState
	if gs:
		s["date"] = _game_time()
		s["active_contracts"] = gs.active_contracts.size()
		s["pending_deliveries_count"] = gs.pending_deliveries.size()
		s["event_log_size"] = gs.event_log.size()
		if is_instance_valid(gs.player):
			s["funds"] = gs.player.current_balance
			s["org_unit_count"] = gs.player.organizational_units.size()
			var tu_count := 0
			for ou in gs.player.organizational_units:
				for opu in ou.sub_units:
					tu_count += opu.tactical_units.size()
			s["tactical_unit_count"] = tu_count
		s["inventory_size"] = gs.player_inventory.size()
	var em = EconomySystem
	if em:
		s["accumulated_expenses"] = em.accumulated_expenses
	var pm = PersonnelManager
	if pm:
		s["personnel_count"] = pm.personnel_roster.size()
		s["astechs"] = pm.abstract_astech_count
		s["medics"] = pm.abstract_medic_count
	var im = InventoryManager
	if im:
		s["in_transit_count"] = im.in_transit.size()
	var tm = TimeManager
	if tm:
		s["is_paused"] = tm.is_paused
		s["total_days"] = tm.total_days
		s["tick_interval"] = tm.tick_interval
	return s


func _game_time() -> Dictionary:
	var tm = TimeManager
	if not tm:
		return {}
	return {
		"year": tm.current_date.get("year", 0),
		"month": tm.current_date.get("month", 0),
		"day": tm.current_date.get("day", 0),
		"total_days": tm.total_days,
		"paused": tm.is_paused,
	}


static func _timestamp() -> String:
	var d = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [d.year, d.month, d.day, d.hour, d.minute, d.second]


static func get_load_save_path() -> String:
	if Engine.has_singleton("OpenCodeDebugger"):
		return Engine.get_singleton("OpenCodeDebugger").load_save_path
	return ""
