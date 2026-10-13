class_name Overlay
extends Control
const PT := preload("res://scripts/ui/pixel_text.gd")
const PilotVisual := preload("res://scripts/player/pilot_visual.gd")
const BossVisualScript := preload("res://scripts/enemies/boss_visual.gd")
const Themes := preload("res://scripts/world/stage_themes.gd")
const INK := Color("e8f4ff")
const SOFT := Color("91a9bf")
const GOLD := Color("ffd45a")
var _sel := 0
var _boss_sel := 0
var _tab := 3
var _editing_p2 := false
var _online_focus := true
var _t := 0.0
var _boss_vis: Array = []
var _pilots: Array = []
var _hero: Node2D
var _buttons: Array = []
var _online_panel: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(640,360)
	scale = Vector2.ONE*0.5
	_online_panel = preload("res://scripts/ui/online_panel.gd").new()
	_online_panel.overlay = self
	add_child(_online_panel)
	_sel = maxi(0,GameManager.CHARACTER_ORDER.find(GameManager.character))
	_boss_sel = maxi(0,GameManager.BOSS_ORDER.find(GameManager.selected_boss))
	for id in GameManager.CHARACTER_ORDER:
		var art := PilotVisual.new()
		art.pilot = id
		art.scale = Vector2.ONE*0.95
		add_child(art)
		_pilots.append(art)
	_hero = PilotVisual.new()
	_hero.position = Vector2(104,278)
	_hero.scale = Vector2.ONE*2.8
	add_child(_hero)
	for id in GameManager.BOSS_ORDER:
		var art := BossVisualScript.new()
		art.design = id
		art.color = GameManager.BOSSES[id]["color"]
		art.scale = Vector2.ONE*1.3
		add_child(art)
		_boss_vis.append(art)

func _process(delta: float) -> void:
	_t += delta
	var st: int = GameManager.state
	_online_panel.visible = st == GameManager.State.TITLE and _tab == 4
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if st == GameManager.State.PLAYING else Input.MOUSE_MODE_VISIBLE
	_hero.visible = st == GameManager.State.TITLE and _tab == 0
	_hero.pilot = GameManager.CHARACTER_ORDER[_sel]
	for i in _pilots.size():
		_pilots[i].visible = _hero.visible
		_pilots[i].position = _char_rect(i).get_center()+Vector2(0,31)
	for i in _boss_vis.size():
		_boss_vis[i].visible = st == GameManager.State.BOSS_SELECT
		_boss_vis[i].position = _boss_rect(i).get_center()+Vector2(0,-6)
	queue_redraw()

func _char_rect(i: int) -> Rect2:
	return Rect2(252+(i%4)*94,86+floori(float(i)/4)*76,88,68)

func _boss_rect(i: int) -> Rect2:
	return Rect2(16+(i%4)*156,72+floori(float(i)/4.0)*88,144,78)

func panel(rc: Rect2, accent: Color = SOFT) -> void:
	PT.panel(self,rc,Color("0b1828"),accent.darkened(0.5))
	draw_line(rc.position,rc.position+Vector2(24,0),accent,1)

func button(text: String, rc: Rect2, action: String, accent: Color = GOLD) -> void:
	var hover := rc.has_point(get_viewport().get_mouse_position()/scale)
	draw_rect(rc,accent.darkened(0.7 if hover else 0.87))
	draw_rect(rc,accent if hover else accent.darkened(0.45),false,1)
	PT.draw_box(self,text,rc.grow(-5),INK if hover else accent)
	_buttons.append({"rect":rc,"action":action})

func background(title: String, sub: String) -> void:
	draw_rect(Rect2(0,0,640,360),Color("060d19"))
	for i in 16:
		var x := fposmod(i*27-_t*4,340)-10
		draw_line(Vector2(x,60),Vector2(x-160,360),Color(0.1,0.3,0.4,0.12),1)
	draw_circle(Vector2(84,228),48,Color(0.15,0.35,0.5,0.13))
	PT.draw(self,title,Vector2(20,16),INK,2)
	PT.draw(self,sub,Vector2(20,46),SOFT)
	draw_line(Vector2(16,62),Vector2(624,62),Color("294254"),1)

func _draw() -> void:
	_buttons.clear()
	match GameManager.state:
		GameManager.State.TITLE:
			if _tab == 3: _draw_modes()
			elif _tab == 4: background("SALAS ONLINE","1 A 4 PILOTOS / SALAS CON CODIGO")
			elif _tab == 1: _draw_archive()
			elif _tab == 2: _draw_settings()
			else: _draw_title()
		GameManager.State.BOSS_SELECT: _draw_stages()
		GameManager.State.PAUSED: _draw_pause()
		GameManager.State.GAMEOVER: _draw_result(false)
		GameManager.State.WIN: _draw_result(true)

func _draw_modes() -> void:
	background("ALBA DE ACERO","COOPERATIVO ONLINE / 1 A 4 PILOTOS")
	button("ARSENAL",Rect2(392,12,114,32),"archive",Color("59d0ff"))
	button("AJUSTES",Rect2(518,12,106,32),"settings",SOFT)
	panel(Rect2(20,82,372,234),Color("73f7ff"))
	PT.draw(self,"MODO PRINCIPAL",Vector2(40,102),Color("73f7ff"))
	PT.draw(self,"HORDAS ONLINE",Vector2(40,130),INK,2)
	var rows := ["SALAS CON CODIGO / HASTA 4 JUGADORES","SUBE POR PISOS / JEFE CADA 3 RONDAS","ASCENSOR DE 4 PUESTOS / MEJORAS","RESCATES / FUSION / DIFICULTAD ADAPTABLE"]
	for i in rows.size(): PT.draw(self,rows[i],Vector2(40,172+i*20),SOFT)
	button("ENTRAR A SALAS"+(" / ENTER" if _online_focus else ""),Rect2(40,274,332,28),"duo",Color("73f7ff"))
	panel(Rect2(412,82,208,234),Color("ffb15c"))
	PT.draw(self,"CAMPAÑA SOLO",Vector2(430,102),Color("ffb15c"))
	PT.draw(self,"EXPEDICION",Vector2(430,130),INK)
	PT.draw_lines(self,["8 ZONAS Y 8 JEFES","RUTAS Y SECRETOS","DESAFIOS PROPIOS","PODERES PERMANENTES"],Vector2(430,172),SOFT)
	button("EXPLORAR"+(" / ENTER" if not _online_focus else ""),Rect2(430,274,172,28),"solo",Color("ffb15c"))
	PT.draw(self,"A/D CAMBIA MODO - ENTER ELIGE",Vector2(320,334),SOFT,1,PT.CENTER)

func _draw_title() -> void:
	background("PILOTOS", "HORDAS ONLINE / ELIGE LOS DOS PILOTOS" if GameManager.coop else "EXPEDICION / ELIGE TU PILOTO")
	button("PODERES",Rect2(392,12,114,32),"archive",Color("59d0ff"))
	button("AJUSTES",Rect2(518,12,106,32),"settings",SOFT)
	var c: Dictionary = GameManager.CHARACTERS[GameManager.CHARACTER_ORDER[_sel]]
	var col: Color = c["color"]
	panel(Rect2(16,78,220,208),col)
	draw_arc(Vector2(104,224),39,0,TAU,32,col.darkened(0.7),1)
	draw_line(Vector2(44,280),Vector2(194,280),col,1)
	PT.draw(self,"UNIDAD / %02d" % (_sel+1),Vector2(34,92),col)
	PT.draw(self,String(c["epithet"]),Vector2(34,116),SOFT)
	PT.draw(self,"6 PILOTOS + 2 DESBLOQUEABLES",Vector2(252,72),SOFT)
	for i in 8:
		var id: String = GameManager.CHARACTER_ORDER[i]
		var pc: Color = GameManager.CHARACTERS[id]["color"]
		panel(_char_rect(i),pc if i == _sel else SOFT.darkened(0.6))
		PT.draw_box(self,GameManager.CHARACTERS[id]["name"]+(" *" if not GameManager.pilot_unlocked(id) else ""),Rect2(_char_rect(i).position+Vector2(4,4),Vector2(80,14)),pc)
		if i == _sel:
			draw_rect(Rect2(_char_rect(i).position+Vector2(2,62),Vector2(84,4)),pc)
	panel(Rect2(252,242,372,46),col)
	PT.draw(self,String(c["name"])+" / "+String(c["epithet"]),Vector2(266,248),col)
	PT.draw(self,"ARMA: "+GameManager.weapon_name(c["primary"]),Vector2(266,264),INK)
	PT.draw_lines(self,PT.wrap(GameManager.unlock_requirement(GameManager.CHARACTER_ORDER[_sel]) if not GameManager.pilot_unlocked(GameManager.CHARACTER_ORDER[_sel]) else c["desc"],196),Vector2(28,134),SOFT)
	button("DESPLEGAR >",Rect2(440,296,184,28),"deploy",col)
	button("CAMBIAR MODO",Rect2(16,296,220,28),"modes",Color("63ffc3"))
	if GameManager.coop:
		button("P1 / P2 - TAB",Rect2(252,292,180,28),"edit_player",Color("59d0ff"))
	PT.draw_box(self,"A/D PILOTO - ENTER CONTINUAR",Rect2(252,328,372,16),SOFT,1,PT.LEFT)
	PT.draw_box(self,"GUARDADO %d/8" % GameManager.mode_progress().size(),Rect2(16,328,220,16),SOFT,1,PT.LEFT)

func _draw_stages() -> void:
	background("HORDAS ONLINE" if GameManager.coop else "EXPEDICION","%d/8 ZONAS - %d PODERES" % [GameManager.mode_progress().size(),GameManager.acquired_powers.size()])
	button("SALIR" if NetSession.online and not NetSession.host else "VOLVER",Rect2(520,16,104,30),"leave_room" if NetSession.online and not NetSession.host else "title",SOFT)
	for i in 8:
		var id: String = GameManager.BOSS_ORDER[i]
		var card_cfg: Dictionary = GameManager.BOSSES[id]
		var rc := _boss_rect(i)
		panel(rc,card_cfg["color"] if i == _boss_sel else SOFT.darkened(0.6))
		PT.draw_box(self,card_cfg["name"],Rect2(rc.position.x+6,rc.end.y-22,rc.size.x-12,16),card_cfg["color"])
		if GameManager.mode_progress().has(id):
			PT.draw(self,"OK",rc.position+Vector2(6,6),Color("63ffc3"))
	var cfg: Dictionary = GameManager.BOSSES[GameManager.selected_boss]
	panel(Rect2(16,254,608,64),cfg["color"])
	PT.draw(self,Themes.get_theme(cfg["theme"])["name"],Vector2(28,264),cfg["color"])
	PT.draw(self,"PREMIO: "+GameManager.weapon_name(GameManager.selected_boss),Vector2(612,264),GOLD,1,PT.RIGHT)
	PT.draw_lines(self,PT.wrap("SINCRONIZACION / COBERTURA / DEFENSA EN EQUIPO" if GameManager.coop else GameManager.ROUTE_HINTS[GameManager.selected_boss],576),Vector2(28,290),SOFT)
	button("INICIAR MISION",Rect2(372,326,252,30),"start",cfg["color"])
	PT.draw(self,"FLECHAS / ENTER",Vector2(20,336),SOFT)

func _draw_archive() -> void:
	background("ARSENAL DE JEFES","DERROTA AL JEFE - EQUIPA CON Q")
	for i in 8:
		var id: String = GameManager.BOSS_ORDER[i]
		var has_power := GameManager.acquired_powers.has(id)
		var rc := Rect2(16+(i%2)*312,72+floori(float(i)/2.0)*60,296,52)
		var col: Color = GameManager.BOSSES[id]["color"] if has_power else SOFT.darkened(0.45)
		panel(rc,col)
		PT.draw(self,GameManager.weapon_name(id)+(" / OK" if has_power else " / BLOQUEADO"),rc.position+Vector2(10,8),col)
		PT.draw_lines(self,PT.wrap(GameManager.POWERS[id]["desc"],276),rc.position+Vector2(10,28),SOFT)
	button("VOLVER",Rect2(212,322,216,30),"title",GOLD)

func _draw_settings() -> void:
	background("CONFIGURACION","VIDEO / AUDIO / CONTROLES")
	panel(Rect2(24,72,592,244),Color("59d0ff"))
	PT.draw(self,"PANTALLA",Vector2(44,84),Color("59d0ff"))
	button("<",Rect2(44,102,32,30),"resolution_prev",Color("59d0ff"))
	button(GameManager.resolution_label(),Rect2(82,102,224,30),"resolution_next",Color("59d0ff"))
	button(">",Rect2(312,102,32,30),"resolution_next",Color("59d0ff"))
	button(GameManager.display_mode_label(),Rect2(356,102,236,30),"display_mode",Color("63ffc3"))
	PT.draw(self,"NATIVA: 1920 X 1080 / AJUSTE AUTOMATICO SIN DEFORMAR",Vector2(44,140),SOFT)
	button("MUSICA: "+("SI" if GameManager.settings["music"] else "NO"),Rect2(44,162,264,32),"music")
	button("EFECTOS: "+("SI" if GameManager.settings["sfx"] else "NO"),Rect2(328,162,264,32),"sfx")
	var lines := ["A/D MOVER - ESPACIO SALTAR", "RATON APUNTA - CLIC/J DISPARA", "SHIFT DASH - Q CAMBIA PODER", "ONLINE: E RESCATA - F FUSION - B MEJORAS"]
	for i in lines.size():
		PT.draw(self,lines[i],Vector2(44,214+i*20),SOFT)
	button("VOLVER",Rect2(212,322,216,30),"title")

func _draw_pause() -> void:
	draw_rect(Rect2(0,0,640,360),Color(0.02,0.04,0.08,0.86))
	panel(Rect2(88,44,464,280),Color("59d0ff"))
	PT.draw(self,"MISION EN PAUSA",Vector2(320,66),INK,2,PT.CENTER)
	PT.draw(self,GameManager.stage_name(),Vector2(320,104),SOFT,1,PT.CENTER)
	button("CONTINUAR / ESC",Rect2(132,136,376,40),"resume",Color("63ffc3"))
	button("REINICIAR / R",Rect2(132,188,376,40),"restart")
	button("MAPA DE ZONAS / T",Rect2(132,240,376,40),"map",SOFT)
	if NetSession.online:
		button("SALIR DE SALA",Rect2(132,286,376,28),"leave_room",Color("ff758b"))
	else:
		PT.draw(self,"Q PODER - SHIFT DASH - CLIC DISPARA",Vector2(320,300),SOFT,1,PT.CENTER)

func _draw_result(win: bool) -> void:
	background("MISION COMPLETA" if win else "UNIDAD CAIDA","INFORME DE OPERACION")
	panel(Rect2(40,78,560,210),Color("63ffc3") if win else Color("ff758b"))
	if win:
		PT.draw(self,"PODER: "+GameManager.weapon_name(GameManager.selected_boss),Vector2(320,94),GOLD,2,PT.CENTER)
		PT.draw_lines(self,PT.wrap(GameManager.POWERS[GameManager.selected_boss]["desc"],500),Vector2(64,134),SOFT)
	else:
		PT.draw(self,("OLEADA %d / RECORD %d" % [GameManager.run_wave,GameManager.best_wave]) if GameManager.horde_mode else "RECONSTRUYE TU UNIDAD",Vector2(320,98),GOLD,1,PT.CENTER)
	var rows := [["PUNTOS","%07d" % GameManager.score],["TIEMPO",PT.format_time(GameManager.play_time)],["BAJAS / CAIDAS","%d / %d" % [GameManager.kills,GameManager.deaths]]]
	for i in rows.size():
		PT.draw(self,rows[i][0],Vector2(68,184+i*30),SOFT)
		PT.draw(self,rows[i][1],Vector2(572,184+i*30),INK,1,PT.RIGHT)
	button("MAPA DE ZONAS",Rect2(40,304,272,40),"map",Color("63ffc3"))
	button("REPETIR" if win else "REINTENTAR",Rect2(328,304,272,40),"restart",GOLD)

func _apply_char() -> void:
	if _editing_p2:
		GameManager.character2 = GameManager.CHARACTER_ORDER[_sel]
	else:
		GameManager.select_character(GameManager.CHARACTER_ORDER[_sel])
	AudioManager.play("select",-14)

func _action(action: String) -> void:
	match action:
		"title":
			_tab = 4 if GameManager.coop else 0
			GameManager.state = GameManager.State.TITLE
		"leave_room":
			NetSession.disconnect_room()
			GameManager.coop = false
			GameManager.to_title()
		"modes": _tab = 3
		"solo", "duo":
			GameManager.coop = action == "duo"
			GameManager.horde_mode = GameManager.coop
			GameManager.party_characters.clear()
			if action == "duo":
				_tab = 4
				return
			NetSession.disconnect_room()
			_editing_p2 = false
			_sel = GameManager.CHARACTER_ORDER.find(GameManager.character)
			_tab = 0
		"edit_player":
			_editing_p2 = not _editing_p2
			_sel = GameManager.CHARACTER_ORDER.find(GameManager.character2 if _editing_p2 else GameManager.character)
		"archive": _tab = 1
		"settings": _tab = 2
		"deploy":
			if GameManager.pilot_unlocked(GameManager.CHARACTER_ORDER[_sel]): GameManager.confirm_character()
		"start":
			if GameManager.coop: NetSession.start_match()
			else: GameManager.start_stage()
		"resume":
			if NetSession.online and not NetSession.host:
				NetSession.send_packet({"type":"control","action":"resume"})
			else: GameManager.set_paused(false)
		"restart":
			if NetSession.online: NetSession.start_match()
			else: GameManager.restart_stage()
		"map":
			if NetSession.online and not NetSession.host:
				return
			if NetSession.online: NetSession.send_packet({"type":"lobby"})
			GameManager.to_stage_select()
		"coop":
			GameManager.coop = not GameManager.coop
			GameManager.character2 = GameManager.CHARACTER_ORDER[(_sel+1)%4]
		"music", "sfx":
			GameManager.settings[action] = not GameManager.settings[action]
			AudioManager.apply_settings()
			GameManager.save_campaign()
		"resolution_prev": GameManager.cycle_resolution(-1)
		"resolution_next": GameManager.cycle_resolution(1)
		"display_mode": GameManager.cycle_display_mode()
	AudioManager.play("select",-14)

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.scene_transition_pending:
		return
	var st: int = GameManager.state
	if st == GameManager.State.TITLE and _tab == 4:
		return
	if event is InputEventKey and event.echo:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and st != GameManager.State.PLAYING:
		var mp: Vector2 = event.position/scale
		for b in _buttons:
			if b["rect"].has_point(mp):
				get_viewport().set_input_as_handled()
				_action(b["action"])
				return
		if st == GameManager.State.TITLE and _tab == 0:
			for i in 8:
				if _char_rect(i).has_point(mp):
					_sel = i
					_apply_char()
		elif st == GameManager.State.BOSS_SELECT:
			for i in 8:
				if _boss_rect(i).has_point(mp):
					_boss_sel = i
					if not NetSession.online or NetSession.host:
						GameManager.select_boss(GameManager.BOSS_ORDER[i])
		get_viewport().set_input_as_handled()
		return
	var go := event.is_action_pressed("shoot") or event.is_action_pressed("jump")
	var key := 0
	if event is InputEventKey and event.pressed:
		key = event.physical_keycode
		go = go or key == KEY_ENTER
	var dx := int(event.is_action_pressed("move_right") or event.is_action_pressed("p2_move_right"))-int(event.is_action_pressed("move_left") or event.is_action_pressed("p2_move_left"))
	var dy := int(event.is_action_pressed("aim_down") or event.is_action_pressed("p2_aim_down"))-int(event.is_action_pressed("aim_up") or event.is_action_pressed("p2_aim_up"))
	match st:
		GameManager.State.TITLE:
			if event.is_action_pressed("pause"): _tab = 3 if _tab == 0 else 0
			elif _tab == 3:
				if dx != 0 or event.is_action_pressed("coop"):
					_online_focus = not _online_focus
				elif go: _action("duo" if _online_focus else "solo")
			elif key == KEY_TAB and GameManager.coop: _action("edit_player")
			elif key == KEY_I: _tab = 1
			elif key == KEY_O: _tab = 2
			elif _tab == 0:
				if dx != 0 or dy != 0:
					_sel = wrapi(_sel+dx+dy*4,0,8)
					_apply_char()
				elif event.is_action_pressed("coop"): _action("modes")
				elif go: _action("deploy")
		GameManager.State.BOSS_SELECT:
			if NetSession.online and not NetSession.host:
				if event.is_action_pressed("pause"): _action("leave_room")
				return
			if event.is_action_pressed("pause"): _action("title")
			elif dx != 0 or dy != 0:
				_boss_sel = wrapi(_boss_sel+dx+dy*4,0,8)
				GameManager.select_boss(GameManager.BOSS_ORDER[_boss_sel])
				AudioManager.play("select",-14)
			elif go: _action("start")
		GameManager.State.PLAYING:
			if event.is_action_pressed("pause"):
				if NetSession.online and not NetSession.host:
					NetSession.send_packet({"type":"control","action":"pause"})
				else: GameManager.set_paused(true)
		GameManager.State.PAUSED:
			if event.is_action_pressed("pause") or go: _action("resume")
			elif key == KEY_R: _action("restart")
			elif key == KEY_T: _action("map")
		GameManager.State.GAMEOVER, GameManager.State.WIN:
			if key == KEY_T or (go and st == GameManager.State.WIN): _action("map")
			elif go: _action("restart")
