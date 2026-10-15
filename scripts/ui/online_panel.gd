extends Control
var overlay: Control
var code: LineEdit
var launch: Button
var message: Label
var server_badge: Label
var mode: OptionButton
var help: Label
var copy_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640,360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# La direccion real del relay nunca se muestra al jugador. La build publica
	# usa NetSession.DEFAULT_URL (o ALBA_RELAY_URL durante desarrollo).
	server_badge = Label.new()
	server_badge.position = Vector2(36,76)
	server_badge.size = Vector2(280,28)
	server_badge.text = "SERVIDOR PUBLICO / LISTO"
	server_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	server_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	server_badge.add_theme_font_size_override("font_size",12)
	add_child(server_badge)

	make_button("ENTRENAR SOLO",Rect2(420,76,184,28),func():
		NetSession.disconnect_room()
		GameManager.coop = true
		GameManager.horde_mode = true
		GameManager.party_characters = [GameManager.character]
		GameManager.party_mobility = [GameManager.mobility.duplicate()]
		GameManager.start_stage())

	server_badge.visible = false
	mode = OptionButton.new()
	mode.position = Vector2(36,76)
	mode.size = Vector2(280,28)
	mode.add_theme_font_size_override("font_size",12)
	mode.add_item("INTERNET / SALAS CON CODIGO")
	mode.add_item("RADMIN / LAN DIRECTA")
	mode.select(1 if NetSession.connection_mode=="direct" else 0)
	mode.item_selected.connect(func(_index: int):
		NetSession.disconnect_room()
		code.text = ""
		_refresh_mode())
	add_child(mode)
	help = Label.new()
	help.position = Vector2(36,112)
	help.size = Vector2(568,38)
	help.text = "CREA UNA SALA Y COMPARTE EL CODIGO / O ESCRIBE EL CODIGO DE TU AMIGO"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size",10)
	add_child(help)

	code = LineEdit.new()
	code.position = Vector2(338,170)
	code.size = Vector2(140,32)
	code.max_length = 45
	code.add_theme_font_size_override("font_size",12)
	code.placeholder_text = "CODIGO"
	code.text_submitted.connect(func(_text: String): connect_to_room(false))
	add_child(code)
	make_button("CREAR SALA",Rect2(36,170,244,32),func(): connect_to_room(true))
	make_button("ENTRAR",Rect2(488,170,116,32),func(): connect_to_room(false))

	var pilot := OptionButton.new()
	pilot.position = Vector2(36,218)
	pilot.size = Vector2(244,30)
	for id in GameManager.CHARACTER_ORDER:
		pilot.add_item(GameManager.CHARACTERS[id]["name"]+(" / BLOQUEADO" if not GameManager.pilot_unlocked(id) else ""))
		pilot.set_item_disabled(pilot.item_count-1,not GameManager.pilot_unlocked(id))
	var own_pilot: String = GameManager.character2 if NetSession.online and not NetSession.host else GameManager.character
	pilot.select(maxi(0,GameManager.CHARACTER_ORDER.find(own_pilot)))
	pilot.item_selected.connect(func(index: int):
		var id: String = GameManager.CHARACTER_ORDER[index]
		GameManager.select_character(id)
		if NetSession.online and not NetSession.host:
			NetSession.send_packet({"type":"profile","pilot":id,"mobility":GameManager.mobility}))
	add_child(pilot)
	copy_button = make_button("COPIAR CODIGO",Rect2(338,218,266,30),func():
		DisplayServer.clipboard_set(_host_ip() if mode.selected==1 else NetSession.room_code))
	_refresh_mode()

	message = Label.new()
	message.position = Vector2(36,258)
	message.size = Vector2(568,36)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size",12)
	add_child(message)
	launch = make_button("ELEGIR EDIFICIO",Rect2(338,306,266,30),func(): GameManager.confirm_character())
	make_button("VOLVER",Rect2(36,306,244,30),func():
		NetSession.disconnect_room()
		overlay._tab = 3)

func make_button(label: String,rect: Rect2,callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size",14)
	button.pressed.connect(callback)
	add_child(button)
	return button

func _host_ip() -> String:
	var addresses := IP.get_local_addresses()
	for ip in addresses:
		if ip.begins_with("26."): return ip
	for ip in addresses:
		if ip.begins_with("192.168.") or ip.begins_with("10."): return ip
	return "127.0.0.1"

func _refresh_mode() -> void:
	var is_direct := mode.selected==1
	code.placeholder_text = "IP DEL ANFITRION" if is_direct else "CODIGO"
	copy_button.text = "COPIAR MI IP" if is_direct else "COPIAR CODIGO"
	help.text = "TODOS EN LA MISMA RED RADMIN / UNO CREA Y LOS DEMAS ENTRAN CON SU IP / UDP 27840" if is_direct else "CREA UNA SALA Y COMPARTE EL CODIGO / O ESCRIBE EL CODIGO DE TU AMIGO"

func connect_to_room(create: bool) -> void:
	if mode.selected==1:
		NetSession.connect_direct(create,code.text.strip_edges())
		return
	if not create and code.text.strip_edges().length()!=6:
		NetSession.status = "EL CODIGO DEBE TENER 6 CARACTERES"
		NetSession.status_changed.emit()
		return
	NetSession.connect_room(create,code.text.strip_edges())

func _process(_delta: float) -> void:
	message.text = NetSession.status+(" / %d ms" % NetSession.ping_ms if NetSession.online and not NetSession.host and NetSession.ping_ms>0 else "")
	mode.disabled = NetSession.online
	server_badge.text = "SERVIDOR PUBLICO / CONECTADO" if NetSession.online else "SERVIDOR PUBLICO / LISTO"
	launch.disabled = not NetSession.online or not NetSession.host
	launch.text = "ELEGIR EDIFICIO" if NetSession.host else "ESPERANDO AL ANFITRION"
