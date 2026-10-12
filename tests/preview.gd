extends Node
var game: Node
class Sheet:
	extends Control
	const PT := preload("res://scripts/ui/pixel_text.gd")
	func _draw() -> void:
		draw_rect(Rect2(0,0,320,180),Color("060d19"))
		PT.draw(self,"CAMINATA / CICLO COMPLETO",Vector2(8,4),Color("73f7ff"))
		for i in 4:
			draw_line(Vector2(0,57+i*40),Vector2(320,57+i*40),Color("294254"),1)
class EnemySheet:
	extends Control
	const PT := preload("res://scripts/ui/pixel_text.gd")
	const REGIONAL := preload("res://scripts/enemies/zone_enemy.gd")
	func _draw() -> void:
		draw_rect(Rect2(0,0,320,180),Color("060d19"))
		PT.draw(self,"OCHO FAMILIAS / TIERRA Y AIRE",Vector2(8,4),Color("73f7ff"))
		var zones: Array = REGIONAL.FAMILY.keys()
		for i in zones.size():
			var at := Vector2((i%4)*80,20+floori(float(i)/4)*80)
			draw_rect(Rect2(at+Vector2(3,0),Vector2(74,69)),Color("0b1828"))
			PT.draw_box(self,zones[i].to_upper(),Rect2(at+Vector2(5,2),Vector2(70,12)),REGIONAL.COLORS[zones[i]])
			draw_set_transform(at+Vector2(5,18),0,Vector2.ONE*0.5)
			PT.draw_box(self,REGIONAL.FAMILY[zones[i]],Rect2(0,0,140,14),Color("91a9bf"))
			draw_set_transform(Vector2.ZERO)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func capture(label: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tests/previews/"+label+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/previews"))
	GameManager.campaign_path = "res://tests/preview_campaign.cfg"
	GameManager.acquired_powers.clear()
	GameManager.cleared.clear()
	GameManager.character = "orange"
	GameManager.selected_boss = "sierra"
	GameManager.skip_menu = false
	game = preload("res://scenes/main/Main.tscn").instantiate()
	add_child(game)
	await capture("menu")
	var overlay: Overlay = game.get_node("UI").get_child(2)
	overlay._action("duo")
	await capture("online_lobby")
	overlay._action("solo")
	await capture("pilots")
	GameManager.state = GameManager.State.BOSS_SELECT
	await capture("missions")
	GameManager.state = GameManager.State.TITLE
	overlay._tab = 1
	await capture("arsenal")
	overlay._tab = 2
	await capture("settings")
	GameManager.start_game()
	overlay._tab = 0
	await get_tree().create_timer(3.0).timeout
	await capture("solo_start")
	var player: Player = game.players[0]
	player.set_physics_process(false)
	player.position = Vector2(game.level.puzzles[0].position.x+128,150)
	player.get_camera().reset_smoothing()
	GameManager._shake_amount = 0
	GameManager.camera_override.offset = Vector2.ZERO
	await get_tree().create_timer(3.0).timeout
	for e in get_tree().get_nodes_in_group("enemy"):
		e.set_physics_process(false)
	get_tree().call_group("enemy_bullet","queue_free")
	player._invuln = 0
	GameManager.revive_player_full(0)
	get_tree().paused = true
	await capture("foundry")
	get_tree().paused = false
	GameManager.set_paused(true)
	await capture("pause")
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame
	GameManager.coop = true
	GameManager.skip_menu = true
	game = preload("res://scenes/main/Main.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(3.0).timeout
	await capture("duo_start")
	for p in game.players:
		p.set_physics_process(false)
	var station = game.level.stations[1]
	game.players[0].position = station.position+station.pads[0]
	game.players[1].position = station.position+station.pads[1]
	GameManager.team_energy = 74
	game._shared_cam.reset_smoothing()
	await get_tree().create_timer(3).timeout
	await capture("cooperative")
	GameManager.state = GameManager.State.TITLE
	var duo_overlay: Overlay = game.get_node("UI").get_child(2)
	duo_overlay._tab = 0
	duo_overlay._tab = 4
	await capture("online_lobby")
	get_tree().paused = false
	var sheet_layer := CanvasLayer.new()
	sheet_layer.layer = 99
	add_child(sheet_layer)
	sheet_layer.add_child(Sheet.new())
	for i in 4:
		for j in 8:
			var art := preload("res://scripts/player/pilot_visual.gd").new()
			art.pilot = GameManager.CHARACTER_ORDER[i]
			art.preview_pose = "run"
			art.t = float(j)*TAU/14.0/8.0
			art.position = Vector2(20+j*40,56+i*40)
			sheet_layer.add_child(art)
			art.set_process(false)
	await capture("walk_cycle")
	var enemies_layer := CanvasLayer.new()
	enemies_layer.layer = 100
	add_child(enemies_layer)
	enemies_layer.add_child(EnemySheet.new())
	var zones: Array = preload("res://scripts/enemies/zone_enemy.gd").FAMILY.keys()
	for i in zones.size():
		for variant in 2:
			var enemy := preload("res://scripts/enemies/zone_enemy.gd").new()
			enemy.zone = zones[i]
			enemy.airborne = variant == 1
			enemy.position = Vector2((i%4)*80+25+variant*32,82+floori(float(i)/4)*80-variant*7)
			enemies_layer.add_child(enemy)
			enemy.set_physics_process(false)
	await capture("regional_enemies")
	get_tree().quit()
