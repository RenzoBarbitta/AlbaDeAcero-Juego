extends Node
func _ready() -> void: call_deferred("run")
func run() -> void:
	GameManager.campaign_path = "res://tests/identity_showcase_temp.cfg"
	for id in GameManager.BOSS_ORDER:
		GameManager.coop = false
		GameManager.horde_mode = false
		GameManager.selected_boss = id
		GameManager.skip_menu = true
		var game := preload("res://scenes/main/Main.tscn").instantiate()
		add_child(game)
		game.set_process(false)
		var player: Player = game.players[0]
		player.position = Vector2(game.level.arena_x+80,150)
		player.set_physics_process(false)
		player._invuln = 999
		var b: Boss = game.level.boss
		b.position = Vector2(game.level.arena_x+245,148 if b.use_gravity else 90)
		b.active = true
		b._begin_next()
		b.set_physics_process(false)
		b._visual.motion_state = "tell"
		game.level._arena_locked = true
		GameManager.boss_health_changed.emit(b.health,b.max_health,true)
		game.get_node("UI").get_child(1)._banner.clear()
		var camera := player.get_camera()
		camera.position_smoothing_enabled = false
		camera.global_position = Vector2(game.level.arena_x+200,70)
		camera.zoom = Vector2.ONE*0.85
		camera.force_update_scroll()
		await get_tree().create_timer(0.45).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/previews/identity_arena_"+GameManager.theme_id+".png")
		game.queue_free()
		await get_tree().process_frame
	get_tree().quit()
