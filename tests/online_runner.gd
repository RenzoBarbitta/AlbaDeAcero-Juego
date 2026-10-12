extends Node
var failures := 0
var checks := 0
var role := ""
var game: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("NETWORK FAIL: "+label)

func run() -> void:
	role = OS.get_environment("ALBA_TEST_ROLE")
	GameManager.campaign_path = "res://tests/network_"+role+".cfg"
	GameManager.coop = true
	GameManager.selected_boss = "voltaje"
	GameManager.character = "orange" if role == "host" else "violet"
	NetSession.server_url = OS.get_environment("ALBA_RELAY_URL")
	if NetSession.server_url == "": NetSession.server_url = "ws://127.0.0.1:8787"
	if role == "host":
		NetSession.connect_room(true)
		for i in 200:
			if NetSession.online: break
			await get_tree().create_timer(0.05).timeout
		check(NetSession.online,"host connects to relay")
		if not NetSession.online:
			print("CONNECT STATUS: "+NetSession.status)
			get_tree().quit(1)
			return
		var file := FileAccess.open("res://tests/network_room.txt",FileAccess.WRITE)
		file.store_string(NetSession.room_code)
		file.close()
	else:
		var code := ""
		for i in 200:
			if FileAccess.file_exists("res://tests/network_room.txt"):
				code = FileAccess.get_file_as_string("res://tests/network_room.txt")
				if code.length()==6: break
			await get_tree().create_timer(0.05).timeout
		NetSession.connect_room(false,code)
	for i in 200:
		if NetSession.peer_ready: break
		await get_tree().create_timer(0.05).timeout
	check(NetSession.online and NetSession.peer_ready,"both PCs in coded room")
	game = preload("res://scenes/main/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await get_tree().create_timer(0.3).timeout
	if role == "host":
		check(NetSession.remote_profile == "violet","remote pilot profile received")
		NetSession.start_match()
	for i in 200:
		if GameManager.state == GameManager.State.PLAYING and is_instance_valid(NetSession.world): break
		await get_tree().create_timer(0.05).timeout
	game = get_tree().current_scene
	check(game.players.size()==2,"online actors spawned on both peers")
	check(game.players[1].character=="violet","guest has chosen pilot")
	check(GameManager.selected_boss=="voltaje","mission selection synchronized")
	if role == "host":
		var initial: float = game.players[1].position.x
		await get_tree().create_timer(1.8).timeout
		check(game.players[1].position.x>initial+35,"host simulates remote movement")
		var puzzle = game.level.puzzles[0]
		for i in [0,1,3]: puzzle.activate(i)
		check(puzzle.solved,"host puzzle completed")
		var old_position: Vector2 = game.players[0].global_position
		check(preload("res://tests/puzzle_solver.gd").complete(game.level.puzzles[1],game.players[0]),"host spatial expedition completed")
		game.players[0].global_position = old_position
		game.players[0].velocity = Vector2.ZERO
		GameManager.damage_player(1,4)
		GameManager.acquire_boss_power("voltaje")
		GameManager.team_energy = 100
		for i in 160:
			if FileAccess.file_exists("res://tests/network_client_done.txt"): break
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(0.2).timeout
		check(GameManager.team_energy < 5,"guest triggers authoritative team fusion")
		check(not NetSession.peer_ready,"guest disconnect reported")
		check(GameManager.state==GameManager.State.PAUSED,"disconnect pauses match")
	else:
		check(not game.players[1].is_physics_processing(),"client does not simulate combat")
		check(game.players[1].get_camera().is_current(),"guest camera follows guest")
		var initial: float = game.players[1].position.x
		Input.action_press("move_right")
		await get_tree().create_timer(0.8).timeout
		Input.action_release("move_right")
		check(game.players[1].position.x>initial+35,"client receives authoritative remote movement")
		Input.action_press("move_right")
		Input.action_press("jump")
		await get_tree().create_timer(0.55).timeout
		Input.action_release("jump")
		Input.action_release("move_right")
		await get_tree().create_timer(0.2).timeout
		check(game.players[1].position.y<=119,"remote jump reaches overlapping platform")
		for i in 160:
			if game.level.puzzles[0].solved and GameManager.acquired_powers.has("voltaje"): break
			await get_tree().create_timer(0.05).timeout
		check(game.level.puzzles[0].solved,"puzzle state replicated")
		await get_tree().process_frame
		check(not is_instance_valid(game.level.puzzles[0].door),"remote door removed")
		check(game.level.puzzles[1].solved,"spatial expedition state replicated")
		check(not is_instance_valid(game.level.puzzles[1].door),"spatial expedition gate removed remotely")
		check(GameManager.p_health[1]==24,"health replicated")
		check(game.players[1].weapon=="voltaje","boss power and equipment replicated")
		Input.action_press("team_attack")
		await get_tree().create_timer(0.1).timeout
		Input.action_release("team_attack")
		await get_tree().create_timer(0.35).timeout
		check(GameManager.team_energy<5,"guest fusion consumes replicated energy")
		check(GameManager.p_health[1]==28,"fusion healing replicated to guest")
		var file := FileAccess.open("res://tests/network_client_done.txt",FileAccess.WRITE)
		file.store_string("done")
		file.close()
		NetSession.disconnect_room()
	print("NETWORK %s: %d checks, %d failures" % [role,checks,failures])
	get_tree().quit(0 if failures==0 else 1)
