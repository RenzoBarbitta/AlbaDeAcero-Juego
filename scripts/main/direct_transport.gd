extends RefCounted
## Same authoritative game protocol, direct UDP transport for LAN/Radmin.
var session: Node
var peer: ENetMultiplayerPeer
var members := {}
var started := false
var elapsed := 0.0
var _serial := 0
var _assemblies := {}
const PORT := 27840

func open(create: bool,address: String) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT,3,3) if create else peer.create_client(address,PORT,3)
	if err != OK: return err
	peer.peer_connected.connect(_joined)
	peer.peer_disconnected.connect(_left)
	if create:
		session.receive({"type":"created","code":"DIRECT","slot":0,"slots":[0]})
	return OK

func close() -> void:
	if peer: peer.close()

func _send(packet: Dictionary,target: int) -> void:
	peer.set_target_peer(target)
	var transient: bool = packet.get("type","") in ["snapshot","input"]
	peer.transfer_channel = 1 if packet.get("type","")=="snapshot" else (2 if transient else 0)
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED if transient else MultiplayerPeer.TRANSFER_MODE_RELIABLE
	var payload := JSON.stringify(packet)
	if packet.get("type","")=="snapshot" and payload.length()>1000:
		# Bound datagrams below MTU; obsolete incomplete states expire instead of
		# blocking newer movement behind reliable retransmissions.
		_serial += 1
		peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
		var count := ceili(payload.length()/600.0)
		for part in count:
			peer.put_packet(JSON.stringify({"type":"fragment","id":_serial,"part":part,"count":count,"data":payload.substr(part*600,600)}).to_utf8_buffer())
	else: peer.put_packet(payload.to_utf8_buffer())

func send(packet: Dictionary) -> void:
	if session.host:
		if packet.get("type","")=="start":
			started = true
			peer.refuse_new_connections = true
		elif packet.get("type","")=="lobby":
			started = false
			peer.refuse_new_connections = false
		for id in members: _send(packet,int(id))
	else: _send(packet,1)

func _joined(id: int) -> void:
	if not session.host: return
	if started or members.size()>=3:
		peer.disconnect_peer(id)
		return
	var slot := 1
	while members.values().has(slot): slot += 1
	members[id] = slot
	var roster: Array = [0]
	roster.append_array(members.values())
	roster.sort()
	_send({"type":"joined","code":"DIRECT","slot":slot,"slots":roster},id)
	var notice := {"type":"peer_joined","slot":slot,"slots":roster}
	session.receive(notice)
	send(notice)

func _left(id: int) -> void:
	if not session.host:
		if id==1: session.receive({"type":"host_left","slots":[]})
		return
	if not members.has(id): return
	var slot: int = members[id]
	members.erase(id)
	var roster: Array = [0]
	roster.append_array(members.values())
	var notice := {"type":"peer_left","slot":slot,"slots":roster}
	session.receive(notice)
	send(notice)

func poll(delta: float) -> void:
	if peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED:
		session.receive({"type":"host_left","slots":[]})
		session.disconnect_room()
		return
	peer.poll()
	if peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED: return
	elapsed += delta
	if not session.online and elapsed>12:
		session.status = "NO RESPONDE / REVISA IP RADMIN Y PERMISO DEL FIREWALL"
		session.status_changed.emit()
		session.disconnect_room()
		return
	for key in _assemblies.keys():
		if elapsed-float(_assemblies[key]["time"])>0.2: _assemblies.erase(key)
	var latest := {}
	while peer.get_available_packet_count()>0:
		var sender := peer.get_packet_peer()
		var packet = JSON.parse_string(peer.get_packet().get_string_from_utf8())
		if not packet is Dictionary: continue
		if not session.host and sender==1 and packet.get("type","")=="fragment":
			var id := int(packet.get("id",0))
			var count := int(packet.get("count",0))
			var part := int(packet.get("part",-1))
			if count<1 or count>256 or part<0 or part>=count: continue
			if not _assemblies.has(id):
				if _assemblies.size()>=8: _assemblies.erase(_assemblies.keys()[0])
				_assemblies[id] = {"count":count,"parts":{},"time":elapsed}
			_assemblies[id]["parts"][part] = str(packet.get("data",""))
			if _assemblies[id]["parts"].size()!=count: continue
			var joined := ""
			for i in count: joined += _assemblies[id]["parts"][i]
			_assemblies.erase(id)
			packet = JSON.parse_string(joined)
			if not packet is Dictionary: continue
		if session.host:
			if not members.has(sender) or not packet.get("type","") in ["input","profile","control"]: continue
			packet["sender"] = members[sender]
		elif sender!=1: continue
		if packet.get("type","")=="snapshot":
			if int(packet.get("frame",0))>=int(latest.get("frame",-1)): latest = packet
		else: session.receive(packet)
	if not latest.is_empty(): session.receive(latest)
