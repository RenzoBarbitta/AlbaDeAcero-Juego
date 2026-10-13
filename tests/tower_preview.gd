extends Node
func _ready() -> void: call_deferred("run")
func shot(label: String) -> void:
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/previews/"+label+".png")
func run() -> void:
	GameManager.campaign_path = "res://tests/tower_preview_temp.cfg"
	GameManager.coop = true
	GameManager.horde_mode = true
	GameManager.party_characters = ["orange","mint","white","violet"]
	GameManager.skip_menu = true
	var game := preload("res://scenes/main/Main.tscn").instantiate()
	add_child(game)
	game.set_process(false)
	game.level.set_physics_process(false)
	for p in game.players:
		p.position = Vector2(426+p.index*36,150)
		p.set_physics_process(false)
	game._shared_cam.position_smoothing_enabled = false
	game._shared_cam.zoom = Vector2.ONE
	game._shared_cam.position = Vector2(480,98)
	game._shared_cam.force_update_scroll()
	game.get_node("UI").get_child(1)._banner.clear()
	game.level.phase = "shop"
	game.level.cabin_players = [0,1,2,3]
	await shot("tower_cabin_four")
	game.level.begin_ascent()
	game.get_node("UI").get_child(1)._banner.clear()
	game.level.phase = "transit"
	game.level.lift_progress = 0.5
	await shot("tower_ascent")
	game.level.configure_floor(3)
	game.level.phase = "combat"
	game.level.wave = 3
	game._shared_cam.zoom = Vector2.ONE*0.34
	game._shared_cam.position = Vector2(480,-40)
	game._shared_cam.force_update_scroll()
	await shot("tower_floor_three")
	get_tree().quit()
