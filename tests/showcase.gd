extends Node
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")
func shot(label: String) -> void:
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/previews/"+label+".png")
func run() -> void:
	GameManager.campaign_path = "res://tests/showcase_temp.cfg"
	for id in GameManager.BOSS_ORDER:
		GameManager.coop = true
		GameManager.horde_mode = true
		GameManager.party_characters = ["orange","mint","white","cyan"]
		GameManager.selected_boss = id
		GameManager.skip_menu = true
		var game := preload("res://scenes/main/Main.tscn").instantiate()
		add_child(game)
		game.level.set_physics_process(false)
		for p in game.players: p.set_physics_process(false)
		game.set_process(false)
		game._shared_cam.position = Vector2(480,-50)
		game._shared_cam.zoom = Vector2.ONE*0.3
		game._shared_cam.reset_smoothing()
		game.level.wave = 3
		game.level._spawn_wave_boss()
		game.level.boss.set_physics_process(false)
		game.level.phase = "combat"
		GameManager.play_time = 5.7
		game.get_node("UI").get_child(1)._banner.clear()
		await shot("arena_"+GameManager.theme_id)
		game.level.phase = "shop"
		game.get_node("UI").get_child(3).opened = true
		if id==GameManager.BOSS_ORDER[0]: await shot("horde_shop")
		game.queue_free()
		await get_tree().process_frame
		GameManager.coop = false
		GameManager.horde_mode = false
		GameManager.skip_menu = true
		game = preload("res://scenes/main/Main.tscn").instantiate()
		add_child(game)
		var district: Dictionary = game.level.districts[1]
		var p: Player = game.players[0]
		p.set_physics_process(false)
		p.position = district["route"][2]
		game.set_process(false)
		var camera := p.get_camera()
		camera.position_smoothing_enabled = false
		camera.global_position = Vector2(district["bounds"].position.x+800,-210)
		camera.zoom = Vector2.ONE*0.2
		camera.force_update_scroll()
		game.get_node("UI").visible = false
		await shot("signature_"+GameManager.theme_id)
		game.queue_free()
		await get_tree().process_frame
	get_tree().quit()
