extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	GameManager.campaign_path = "res://tests/design_preview_temp.cfg"
	NetSession.disconnect_room()
	for id in GameManager.BOSS_ORDER:
		GameManager.selected_boss = id
		GameManager.coop = false
		GameManager.skip_menu = true
		var game := preload("res://scenes/main/Main.tscn").instantiate()
		add_child(game)
		for enemy in get_tree().get_nodes_in_group("enemy"): enemy.set_physics_process(false)
		var player: Player = game.players[0]
		player.set_physics_process(false)
		player._invuln = 1000
		player.global_position = Vector2(1184,-250)
		var cam := player.get_camera()
		cam.zoom = Vector2.ONE*0.2
		cam.offset = Vector2.ZERO
		cam.reset_smoothing()
		cam.force_update_scroll()
		await get_tree().create_timer(3.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/previews/district_"+GameManager.theme_id+".png")
		game.queue_free()
		await get_tree().process_frame
	get_tree().quit()
