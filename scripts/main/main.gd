extends Node2D
## Punto de entrada: monta fondo, etapa, uno o dos jugadores, HUD y flujo.

const PlayerScript := preload("res://scripts/player/player.gd")
const StageScript := preload("res://scripts/world/stage.gd")
const CoopStage := preload("res://scripts/world/coop_stage.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const OverlayScript := preload("res://scripts/ui/overlay.gd")
const BgScript := preload("res://scripts/world/parallax_25d.gd")
const VignetteShader := preload("res://assets/shaders/vignette.gdshader")

var world: Node2D
var level
var players: Array = []
var bg
var _respawning := {}
var _shared_cam: Camera2D = null

func _ready() -> void:
	# Aplicar siempre la preferencia guardada. El viewport interno sigue siendo
	# 320x180 para que camaras, HUD y pixel-art escalen juntos en cualquier monitor.
	var root_window := get_window()
	root_window.content_scale_size = Vector2i(320, 180)
	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	GameManager.apply_video_settings()
	GameManager.apply_theme_for_boss(GameManager.selected_boss)

	bg = BgScript.new()
	bg.name = "Background"
	add_child(bg)

	world = Node2D.new()
	world.name = "World"
	add_child(world)

	level = preload("res://scripts/world/horde_stage.gd").new() if GameManager.horde_mode and GameManager.coop else (CoopStage.new() if GameManager.coop else StageScript.new())
	level.name = "Stage"
	world.add_child(level)

	for i in GameManager.party_size():
		players.append(_make_player(i,GameManager.pilot_at(i),level.player_spawn+Vector2(i*28,0)))
	for p in players:
		p.set_camera_limits(level.camera_rect)
		if GameManager.horde_mode: p.get_camera().position.y = -52
		if not GameManager.coop:
			GameManager.camera_override = p.get_camera()

	# Cámara compartida para cooperativo
	if GameManager.coop and not NetSession.online:
		_make_shared_camera()
	elif NetSession.online:
		var camera: Camera2D = players[clampi(NetSession.local_index,0,players.size()-1)].get_camera()
		camera.enabled = true
		camera.make_current()
		GameManager.camera_override = camera

	level.build(players)
	if GameManager.coop:
		var director := preload("res://scripts/main/coop_director.gd").new()
		director.name = "CoopDirector"
		director.players = players
		director.game = self
		world.add_child(director)
		if NetSession.online:
			var net := preload("res://scripts/main/net_world.gd").new()
			net.game = self
			add_child(net)
	for p in players:
		p.set_camera_limits(level.camera_rect)
	if _shared_cam:
		_apply_camera_rect(level.camera_rect)

	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 2
	add_child(ui)
	ui.add_child(_make_vignette())
	ui.add_child(HudScript.new())
	ui.add_child(OverlayScript.new())
	if GameManager.horde_mode and GameManager.coop:
		var shop := preload("res://scripts/ui/horde_shop.gd").new()
		shop.game = self
		ui.add_child(shop)

	for p in players:
		p.died.connect(_on_player_died)
	level.goal_reached.connect(_on_goal_reached)
	level.boss_defeated.connect(_on_boss_defeated)
	level.arena_locked.connect(_on_arena_locked)
	GameManager.started.connect(_on_started)
	_reset_spawn_camera()

	# Flujo: empezar directo (reiniciar/continuar) o abrir menús
	if GameManager.skip_menu:
		GameManager.skip_menu = false
		GameManager.begin_title()
		GameManager.start_game()
	elif GameManager.pending_screen == "stages":
		GameManager.pending_screen = ""
		GameManager.begin_title()
		GameManager.state = GameManager.State.BOSS_SELECT
	else:
		GameManager.begin_title()

func _reset_spawn_camera() -> void:
	if _shared_cam:
		_shared_cam.position = level.player_spawn+Vector2(22,-12)
		_shared_cam.reset_smoothing()
		_shared_cam.force_update_scroll()
	else:
		for p in players:
			p.get_camera().reset_smoothing()
			p.get_camera().force_update_scroll()
	if bg:
		bg.update(level.player_spawn.x)

func _on_started() -> void:
	for p in players:
		p._invuln = 1.0
	_reset_spawn_camera()

func _make_vignette() -> Control:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rect.size = Vector2(320, 180)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = VignetteShader
	rect.material = mat
	return rect

func _make_player(idx: int, char_id: String, spawn: Vector2) -> Player:
	var p := PlayerScript.new()
	p.name = "Player%d" % (idx + 1)
	p.setup(idx, char_id)
	if GameManager.coop and idx<GameManager.party_mobility.size(): p.bonus_mobility = GameManager.party_mobility[idx].duplicate()
	p.position = spawn
	world.add_child(p)
	return p

func _make_shared_camera() -> void:
	_shared_cam = Camera2D.new()
	_shared_cam.name = "SharedCamera"
	_shared_cam.position_smoothing_enabled = true
	_shared_cam.position_smoothing_speed = 5.0
	_shared_cam.limit_smoothed = true
	_shared_cam.zoom = Vector2(0.85, 0.85)
	add_child(_shared_cam)
	_shared_cam.make_current()
	GameManager.camera_override = _shared_cam

func _apply_camera_rect(r: Rect2) -> void:
	if _shared_cam == null:
		return
	_shared_cam.limit_left = int(r.position.x)
	_shared_cam.limit_top = int(r.position.y)
	_shared_cam.limit_right = int(r.position.x + r.size.x)
	_shared_cam.limit_bottom = int(r.position.y + r.size.y)

func _process(_delta: float) -> void:
	if bg and players.size() > 0:
		var first: Player = players[0]
		if is_instance_valid(first):
			bg.update(first.global_position.x)
	if _shared_cam and players.size() > 0:
		var mid := Vector2.ZERO
		var alive_n := 0.0
		for p in players:
			if is_instance_valid(p):
				mid += p.global_position
				alive_n += 1.0
		if alive_n > 0.0:
			_shared_cam.position = mid / alive_n + Vector2(0, -52 if GameManager.horde_mode else -8)
			if players.size() == 2:
				var separation: Vector2 = (players[0].global_position-players[1].global_position).abs()
				var target := clampf(minf(320.0/(separation.x+150),180.0/(separation.y+120)),0.48,1.0)
				_shared_cam.zoom = _shared_cam.zoom.lerp(Vector2.ONE*target,1-exp(-_delta*4))

func _on_arena_locked(rect: Rect2) -> void:
	for p in players:
		if is_instance_valid(p):
			p.set_camera_limits(rect)
	_apply_camera_rect(rect)

func _on_player_died(index: int) -> void:
	if GameManager.coop:
		for p in players:
			if p.index == index and p.global_position.y > 208:
				p.global_position = level.respawn_position()+Vector2(index*28,0)
		GameManager.toast("P%d CAIDO - ACERCATE Y MANTEN E O /" % (index+1),Color("59d0ff"))
		return
	if _respawning.get(index,false):
		return
	_respawning[index] = true
	if GameManager.consume_life_player(index):
		await get_tree().create_timer(1.0).timeout
		for p in players:
			if is_instance_valid(p) and p.index == index:
				p.respawn_at(level.respawn_position())
		_respawning[index] = false
	else:
		_respawning[index] = false
		GameManager.trigger_game_over()

func _on_goal_reached() -> void:
	GameManager.add_score(2000)
	GameManager.trigger_win()

func _on_boss_defeated() -> void:
	GameManager.add_score(1000)
