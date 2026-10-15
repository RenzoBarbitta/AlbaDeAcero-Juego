extends Control
var game: Node2D
var opened := false
var panel: PanelContainer
var heading: Label
var buttons: Dictionary = {}
const PT := preload("res://scripts/ui/pixel_text.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scale = Vector2.ONE*0.5
	panel = PanelContainer.new()
	panel.position = Vector2(20,24)
	panel.size = Vector2(600,312)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("0b1828")
	frame.border_color = Color("47758a")
	frame.set_border_width_all(2)
	frame.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel",frame)
	add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",4)
	panel.add_child(rows)
	heading = Label.new()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",12)
	rows.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",5)
	rows.add_child(grid)
	for id in game.level.SHOP:
		var button := Button.new()
		button.custom_minimum_size = Vector2(188,32)
		button.add_theme_font_size_override("font_size",8)
		var tile := StyleBoxFlat.new()
		tile.bg_color = Color("163044")
		tile.border_color = Color("47758a")
		tile.set_border_width_all(1)
		button.add_theme_stylebox_override("normal",tile)
		var hover: StyleBoxFlat = tile.duplicate()
		hover.bg_color = Color("28566a")
		button.add_theme_stylebox_override("hover",hover)
		button.pressed.connect(func(): purchase(id))
		grid.add_child(button)
		buttons[id] = button
	var ready_button := Button.new()
	ready_button.text = "LISTO PARA SUBIR / ENTRA A LA CABINA"
	ready_button.custom_minimum_size.y = 27
	ready_button.add_theme_font_size_override("font_size",10)
	ready_button.pressed.connect(func():
		if NetSession.is_authority(): game.level.mark_ready(local_index())
		else: NetSession.send_packet({"type":"control","action":"ready"})
		opened = false)
	rows.add_child(ready_button)
	panel.visible = false

func local_index() -> int:
	return NetSession.local_index if NetSession.online else 0

func purchase(id: String) -> void:
	if NetSession.is_authority(): game.level.buy_upgrade(local_index(),id)
	else: NetSession.send_packet({"type":"control","action":"buy","upgrade":id})

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_B and GameManager.state==GameManager.State.PLAYING:
		opened = not opened
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var stage: Node2D = game.level
	panel.visible = opened and stage.phase in ["shop","preparing"] and GameManager.state==GameManager.State.PLAYING
	if stage.phase not in ["shop","preparing"]: opened = false
	NetSession.local_shop_open = panel.visible
	if panel.visible:
		game.players[local_index()]._end_charge()
		game.get_node("UI").get_child(1)._crosshair.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var index := local_index()
		heading.text = "TALLER ONLINE / %d CREDITOS / %ds" % [stage.wallets[index],ceili(stage.phase_time)]
		var pilot: Player = game.players[index]
		for id in buttons:
			var price: int = stage.price(index,id)
			buttons[id].text = "%s\n%d CR" % [stage.SHOP[id]["name"],price]
			var mobility_owned: bool = id in ["double_jump","jetpack","triple_jump","phase_dash","aero_boost","combat_regen","overclock"] and pilot.has_mobility(id)
			var weapon_owned: bool = GameManager.ONLINE_WEAPONS.has(id) and bool(GameManager.unlocked.get(id,false))
			buttons[id].disabled = stage.wallets[index]<price or mobility_owned or weapon_owned or (id=="heal" and GameManager.p_health[index]>=GameManager.MAX_HEALTH) or (id=="damage" and pilot.damage_level>=5) or (id=="armor" and pilot.armor_level>=5) or (id=="fire" and pilot.fire_level>=5)
	queue_redraw()

func _draw() -> void:
	if GameManager.state!=GameManager.State.PLAYING: return
	var stage: Node2D = game.level
	var living: int = stage.living_count() if NetSession.is_authority() else stage.remote_alive
	var label := "PISO %d / ACTIVOS %d / ENTRANDO %d" % [stage.floor_number,living,stage.remaining]
	if stage.phase=="shop": label = "ASCENSOR %d/%d / E LISTO / B TALLER ONLINE" % [stage.cabin_players.size(),stage.participating().size()]
	elif stage.phase=="preparing": label = "PISO 1 / B TALLER / COMIENZA EN %ds" % ceili(stage.phase_time)
	elif stage.phase in ["departing","transit"]: label = "SUBIENDO AL PISO %d / %d A BORDO" % [stage.floor_number+1,stage.cabin_players.size()]
	PT.draw_box(self,label,Rect2(8,72,480,16),Color("ffd45a"),1,PT.LEFT)
	if stage.phase=="combat" and stage.wave%2==0 and not stage.bonus_done and not stage.is_boss_floor(stage.floor_number) and stage.floor_number!=41:
		PT.draw_box(self,("BONUS: DOS PILOTOS EN LOS AROS / %d%%" if game.players.size()>1 else "BONUS: MANTEN UN ARO / %d%%") % roundi(stage.bonus_progress/6*100),Rect2(8,94,560,14),Color("63ffc3"),1,PT.LEFT)
	PT.draw_box(self,"CR %d" % stage.wallets[local_index()],Rect2(510,56,120,16),Color("63ffc3"),1,PT.RIGHT)
	var progress_text := "JEFES %d/8" % stage.bosses_defeated
	if stage.floor_number==41:
		progress_text += " / FINAL: NUCLEO OMEGA"
	elif stage.bosses_defeated>=8:
		progress_text += " / SIGUIENTE: PISO FINAL 41"
	else:
		var next_boss_floor: int = int(stage.bosses_defeated + 1) * 5
		progress_text += " / PROXIMO JEFE: PISO %d" % next_boss_floor
	PT.draw_box(self,progress_text,Rect2(8,112,360,14),Color("8fe7ff"),1,PT.LEFT)
	_draw_lift_transition(stage)

func _draw_lift_transition(stage: Node2D) -> void:
	if stage.phase not in ["departing","transit"]: return
	var progress: float = float(stage.lift_progress) if stage.phase == "transit" else clampf(1.0 - float(stage.phase_time), 0.0, 1.0) * 0.08
	# Desvanecimiento + lineas descendentes: la cabina queda centrada pero el
	# entorno corre hacia abajo, haciendo inequívoco que el ascensor SUBE.
	var fade := 0.28+sin(clampf(progress,0.0,1.0)*PI)*0.34
	draw_rect(Rect2(0,0,640,360),Color(0.015,0.03,0.055,fade))
	var shift: float = progress * 720.0
	for x in range(24,640,48):
		var y := fposmod(float(x*3)+shift,390.0)-30.0
		draw_line(Vector2(x,y),Vector2(x,y+42),Color(0.45,0.9,1.0,0.26),3)
		draw_line(Vector2(x+14,y-90),Vector2(x+14,y-56),Color(1.0,0.45,0.82,0.16),2)
	PT.draw_box(self,"ASCENSOR EN MOVIMIENTO",Rect2(150,142,340,28),Color("8fe7ff"),2,PT.CENTER)
	PT.draw_box(self,"SUBIENDO AL PISO %d" % (stage.floor_number+1),Rect2(190,178,260,20),Color("ffffff"),1,PT.CENTER)
	draw_rect(Rect2(190,212,260,8),Color("15283b"))
	draw_rect(Rect2(192,214,256*clampf(progress,0.02,1.0),4),Color("63ffc3"))

func _exit_tree() -> void:
	NetSession.local_shop_open = false
