extends Control
var overlay: Control
var address: LineEdit
var code: LineEdit
var launch: Button
var message: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640,360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	make_button("USAR SERVIDOR PUBLICO",Rect2(36,76,280,26),func():
		NetSession.use_public_server()
		address.text = NetSession.server_url)
	make_button("ENTRENAR SOLO",Rect2(420,76,184,26),func():
		NetSession.disconnect_room()
		GameManager.coop = true
		GameManager.horde_mode = true
		GameManager.party_characters = [GameManager.character]
		GameManager.party_mobility = [GameManager.mobility.duplicate()]
		GameManager.start_stage())
	address = LineEdit.new()
	address.position = Vector2(36,112)
	address.size = Vector2(568,30)
	address.add_theme_font_size_override("font_size",12)
	address.placeholder_text = "Servidor de salas (wss://...)"
	address.text = NetSession.server_url
	add_child(address)
	code = LineEdit.new()
	code.position = Vector2(338,170)
	code.size = Vector2(140,32)
	code.max_length = 6
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
	make_button("COPIAR CODIGO",Rect2(338,218,266,30),func(): DisplayServer.clipboard_set(NetSession.room_code))
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

func connect_to_room(create: bool) -> void:
	NetSession.server_url = address.text.strip_edges()
	if OS.get_environment("ALBA_RELAY_URL")=="":
		var cfg := ConfigFile.new()
		cfg.set_value("online","server",NetSession.server_url)
		cfg.save("user://online.cfg")
	NetSession.connect_room(create,code.text.strip_edges())

func _process(_delta: float) -> void:
	message.text = NetSession.status
	launch.disabled = not NetSession.online or not NetSession.host
	launch.text = "ELEGIR EDIFICIO" if NetSession.host else "ESPERANDO AL ANFITRION"
