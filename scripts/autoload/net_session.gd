extends Node
signal status_changed
var socket := WebSocketPeer.new()
var online := false
var host := true
var local_index := 0
var local_shop_open := false
var room_code := ""
var peer_ready := false
var status := "SERVIDOR PUBLICO LISTO / CREA O ENTRA A UNA SALA"
var server_url := ""
var remote_input := {}
var remote_profile := "red"
var peer_slot := 0
var slots: Array = [0]
var match_slots: Array = [0]
var profiles := {}
var peer_versions := {}
const NETWORK_VERSION := 2
var profile_mobility := {}
var remote_inputs := {}
var input_sequences := {}
var input_ages := {}
var world: Node
var _pending := {}
var _was_connected := false
var _input_sequence := 0
var _latest_input := -1
var _silence := 0.0
var _connect_elapsed := 0.0
var _input_tick := 0.0
const DEFAULT_URL := "wss://albadeacero-juego.onrender.com"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# La URL publica queda embebida y nunca aparece en la interfaz.
	# ALBA_RELAY_URL permite seguir usando un relay local durante desarrollo/tests.
	server_url = DEFAULT_URL
	var override := OS.get_environment("ALBA_RELAY_URL")
	if override != "":
		server_url = override
	status = "SERVIDOR PUBLICO LISTO / CREA O ENTRA A UNA SALA"

func is_authority() -> bool:
	return not online or host

func use_public_server() -> void:
	disconnect_room()
	server_url = DEFAULT_URL
	var cfg := ConfigFile.new()
	cfg.set_value("online","server",server_url)
	cfg.save("user://online.cfg")
	status = "SERVIDOR PUBLICO SELECCIONADO / CREA O ENTRA A UNA SALA"
	status_changed.emit()

func connect_room(create: bool,code: String = "") -> void:
	disconnect_room()
	server_url = server_url.strip_edges().replace("https://","wss://").replace("http://","ws://")
	if not server_url.begins_with("ws://") and not server_url.begins_with("wss://"):
		status = "INGRESA LA URL WSS DEL SERVIDOR"
		status_changed.emit()
		return
	socket = WebSocketPeer.new()
	var err := socket.connect_to_url(server_url)
	if err != OK:
		status = "NO SE PUDO CONECTAR AL SERVIDOR"
		status_changed.emit()
		return
	host = create
	local_index = 0 if create else 1
	_pending = {"type":"create"} if create else {"type":"join","code":code.to_upper()}
	_connect_elapsed = 0
	status = "CONECTANDO..."
	status_changed.emit()

func disconnect_room() -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		socket.close()
	online = false
	peer_ready = false
	room_code = ""
	_was_connected = false
	remote_input = {}
	remote_inputs.clear()
	input_sequences.clear()
	input_ages.clear()
	profiles.clear()
	peer_versions.clear()
	profile_mobility.clear()
	slots = [0]
	world = null
	_pending = {}
	_connect_elapsed = 0
	_latest_input = -1
	_input_sequence = 0

func send_packet(packet: Dictionary) -> void:
	if packet.get("type","")=="profile": packet["version"] = NETWORK_VERSION
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(packet))

func start_match() -> void:
	if not online or not host:
		status = "ESPERA AL SEGUNDO JUGADOR"
		status_changed.emit()
		return
	match_slots = slots.map(func(value): return int(value))
	match_slots.sort()
	for slot in match_slots:
		if int(slot)!=0 and int(peer_versions.get(str(int(slot)),0))!=NETWORK_VERSION:
			status = "TODOS DEBEN ACTUALIZAR EL JUEGO PARA ESTA PARTIDA"
			status_changed.emit()
			return
	var pilots: Array = []
	for slot in match_slots: pilots.append(GameManager.character if int(slot)==0 else profiles.get(str(int(slot)),"red"))
	GameManager.party_mobility.clear()
	for slot in match_slots: GameManager.party_mobility.append(GameManager.mobility.duplicate() if slot==0 else profile_mobility.get(str(slot),[]))
	GameManager.party_characters = pilots
	GameManager.character2 = pilots[1] if pilots.size()>1 else "red"
	var config := {"version":NETWORK_VERSION,"boss":GameManager.selected_boss,"p1":GameManager.character,"p2":GameManager.character2,"powers":GameManager.acquired_powers,"pilots":pilots,"slots":match_slots,"horde":GameManager.horde_mode,"mobility":GameManager.mobility,"pilot_mobility":GameManager.party_mobility}
	send_packet({"type":"start","config":config})
	GameManager.start_stage()

func input_for(index: int) -> Dictionary:
	var slot: int = int(match_slots[index]) if index<match_slots.size() else index
	return remote_inputs.get(str(slot),{})

func _process(delta: float) -> void:
	socket.poll()
	if not online and not _pending.is_empty():
		_connect_elapsed += delta
		var timeout := 75.0 if server_url.contains("onrender.com") else 15.0
		if _connect_elapsed>15 and status=="CONECTANDO...":
			status = "DESPERTANDO SERVIDOR / ESPERA UN MOMENTO"
			status_changed.emit()
		if _connect_elapsed > timeout:
			_pending = {}
			socket.close()
			status = "SERVIDOR NO DISPONIBLE - REVISA LA URL"
			status_changed.emit()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_connected:
			_was_connected = true
			send_packet(_pending)
		while socket.get_available_packet_count() > 0:
			var packet = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if packet is Dictionary:
				receive(packet)
		_input_tick += delta
		if online and not host and is_instance_valid(world) and GameManager.state == GameManager.State.PLAYING and _input_tick>=1.0/60.0:
			_input_tick = 0
			_input_sequence += 1
			send_packet({"type":"input","seq":_input_sequence,"data":capture_input()})
		_silence += delta
		for key in input_ages.keys():
			input_ages[key] += delta
			if float(input_ages[key])>0.3: remote_inputs[key] = {}
		if _silence > 0.3:
			remote_input = {}
	elif _was_connected:
		disconnect_room()
		status = "CONEXION PERDIDA - REGRESA A LAS SALAS"
		GameManager.set_paused(true)
		status_changed.emit()

func receive(packet: Dictionary) -> void:
	match packet.get("type",""):
		"created","joined":
			_pending = {}
			online = true
			peer_slot = int(packet.get("slot",0))
			local_index = peer_slot
			slots = packet.get("slots",[0])
			room_code = packet["code"]
			status = "CODIGO: "+room_code+(" / ESPERANDO JUGADOR" if host else " / ESPERANDO AL ANFITRION")
			if not host:
				peer_ready = true
				send_packet({"type":"profile","pilot":GameManager.character,"mobility":GameManager.mobility})
			status_changed.emit()
		"peer_joined":
			slots = packet.get("slots",slots)
			_latest_input = -1
			peer_ready = true
			status = "%d/4 CONECTADOS / CODIGO %s" % [slots.size(),room_code]
			status_changed.emit()
		"profile":
			peer_versions[str(int(packet.get("sender",1)))] = int(packet.get("version",0))
			if GameManager.CHARACTERS.has(packet.get("pilot","")):
				profile_mobility[str(int(packet.get("sender",1)))] = packet.get("mobility",[]).filter(func(id): return id in ["double_jump","jetpack"])
				remote_profile = packet["pilot"]
				profiles[str(int(packet.get("sender",1)))] = packet["pilot"]
				send_packet({"type":"roster","profiles":profiles,"host_pilot":GameManager.character})
		"roster":
			profiles = packet.get("profiles",{})
		"input":
			var key := str(int(packet.get("sender",1)))
			if host and int(packet.get("seq",-1)) > int(input_sequences.get(key,-1)):
				_latest_input = int(packet["seq"])
				remote_input = packet.get("data",{})
				input_sequences[key] = _latest_input
				remote_inputs[key] = remote_input
				input_ages[key] = 0.0
				_silence = 0
		"start":
			if int(packet.get("config",{}).get("version",0))!=NETWORK_VERSION:
				status = "EL ANFITRION USA OTRA VERSION / ACTUALICEN EL JUEGO"
				status_changed.emit()
				return
			var config: Dictionary = packet["config"]
			GameManager.coop = true
			GameManager.selected_boss = config["boss"]
			GameManager.character = config["p1"]
			GameManager.character2 = config["p2"]
			GameManager.party_mobility = config.get("pilot_mobility",[])
			GameManager.party_characters = config.get("pilots",[config["p1"],config["p2"]])
			match_slots = config.get("slots",[0,1]).map(func(value): return int(value))
			local_index = match_slots.find(peer_slot)
			GameManager.horde_mode = config.get("horde",false)
			for ability in config.get("mobility",[]):
				if not GameManager.mobility.has(ability): GameManager.mobility.append(ability)
			GameManager.acquired_powers.assign(config["powers"])
			GameManager.start_stage()
		"snapshot":
			if not host and is_instance_valid(world):
				world.apply_snapshot(packet["data"])
		"control":
			if host:
				if packet.get("action") == "pause":
					GameManager.set_paused(true)
				elif packet.get("action") == "resume":
					GameManager.set_paused(false)
				elif packet.get("action") == "buy" and is_instance_valid(world):
					var buyer := match_slots.find(int(packet.get("sender",-1)))
					if world.game.level.has_method("buy_upgrade"): world.game.level.buy_upgrade(buyer,str(packet.get("upgrade","")))
				elif packet.get("action") == "ready" and is_instance_valid(world):
					if world.game.level.has_method("mark_ready"): world.game.level.mark_ready(match_slots.find(int(packet.get("sender",-1))))
		"lobby":
			GameManager.state = GameManager.State.BOSS_SELECT
			get_tree().paused = true
		"peer_left","host_left":
			slots = packet.get("slots",[])
			var departed := int(packet.get("slot",-1))
			remote_inputs.erase(str(departed))
			peer_ready = slots.size()>1
			remote_input = {}
			if packet["type"]=="peer_left" and GameManager.horde_mode and is_instance_valid(world):
				if host: world.game.level.disconnect_pilot(match_slots.find(departed))
				status = "%d/4 CONECTADOS / LA PARTIDA CONTINUA" % slots.size()
			else:
				status = "EL ANFITRION O COMPANERO SE DESCONECTO"
				GameManager.set_paused(true)
			status_changed.emit()
		"error":
			_pending = {}
			status = str(packet.get("message","ERROR DE SALA")).to_upper()
			status_changed.emit()

func capture_input() -> Dictionary:
	var data := {}
	for action in ["move_left","move_right","aim_up","aim_down","jump","dash","shoot","weapon_switch","interact","team_attack"]:
		data[action] = not local_shop_open and Input.is_action_pressed(action)
	if is_instance_valid(world) and world.game.players.size()>local_index:
		var p: Player = world.game.players[local_index]
		var direction := (p.get_global_mouse_position()-p.global_position-Vector2(0,-19)).normalized()
		data["aim"] = [direction.x,direction.y]
	return data
