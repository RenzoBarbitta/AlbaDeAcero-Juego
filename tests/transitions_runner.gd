extends Node
var failures := 0
var checks := 0
func _ready() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+label)

func click(overlay: Overlay,point: Vector2) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point*overlay.scale
	overlay._unhandled_input(event)

func run() -> void:
	GameManager.campaign_path = "res://tests/transitions_temp.cfg"
	GameManager.coop = false
	var game := preload("res://scenes/main/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	for i in 3:
		GameManager.state = GameManager.State.BOSS_SELECT
		var overlay: Overlay = game.get_node("UI").get_child(2)
		var old: WeakRef = weakref(overlay)
		await click(overlay,Vector2(498,341))
		check(GameManager.scene_transition_pending,"stage reload deferred until input returns")
		await get_tree().process_frame
		await get_tree().process_frame
		check(old.get_ref() == null,"old menu freed after dispatch")
		game = get_tree().current_scene
		check(GameManager.state == GameManager.State.PLAYING,"stage starts after menu click")
		await get_tree().create_timer(0.25).timeout
		var player: Player = game.players[0]
		check(player.is_on_floor(),"spawn grounded on entry")
		check(player.position.x >= 80 and player.position.y <= 151,"spawn away from map border")
		check(GameManager.p_health[0] == GameManager.MAX_HEALTH,"safe entry has no early damage")
		check(game.level.respawn_position().x >= 80,"initial checkpoint does not send player to wall")
		var center := player.get_camera().get_screen_center_position()
		check(absf(center.x-player.position.x) < 161 and absf(center.y-player.position.y) < 90,"camera immediately frames spawn")
		GameManager.set_paused(true)
		await click(game.get_node("UI").get_child(2),Vector2(320,260))
		await get_tree().process_frame
		await get_tree().process_frame
		game = get_tree().current_scene
		check(GameManager.state == GameManager.State.BOSS_SELECT,"pause map button reloads safely")
	game.queue_free()
	await get_tree().process_frame
	GameManager.coop = true
	GameManager.skip_menu = true
	game = preload("res://scenes/main/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await get_tree().create_timer(0.4).timeout
	for player in game.players:
		check(player.is_on_floor(),"duo spawn grounded")
		check(player.position.x >= 80,"duo spawn clear of border")
		check(GameManager.p_health[player.index] == GameManager.MAX_HEALTH,"duo safe entry health")
	check(absf(game.players[0].position.x-game.players[1].position.x) >= 40,"duo entry gives both pilots room")
	print("TRANSITIONS: %d checks, %d failures" % [checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
