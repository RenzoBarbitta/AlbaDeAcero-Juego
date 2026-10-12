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
		push_error("FOUR FAIL: "+label)
func run() -> void:
	role = OS.get_environment("ALBA_TEST_ROLE")
	GameManager.campaign_path = "res://tests/four_"+role+".cfg"
	GameManager.coop = true
	GameManager.horde_mode = true
	GameManager.character = {"host":"orange","one":"mint","two":"white","three":"violet"}[role]
	NetSession.server_url = OS.get_environment("ALBA_RELAY_URL")
	if role=="host":
		NetSession.connect_room(true)
		for i in 200:
			if NetSession.online: break
			await get_tree().create_timer(0.05).timeout
		var file := FileAccess.open("res://tests/four_room.txt",FileAccess.WRITE)
		file.store_string(NetSession.room_code)
		file.close()
	else:
		var code := ""
		for i in 200:
			if FileAccess.file_exists("res://tests/four_room.txt"):
				code = FileAccess.get_file_as_string("res://tests/four_room.txt")
				if code.length()==6: break
			await get_tree().create_timer(0.05).timeout
		NetSession.connect_room(false,code)
	for i in 240:
		if NetSession.slots.size()==4 and (role!="host" or NetSession.profiles.size()==3): break
		await get_tree().create_timer(0.05).timeout
	check(NetSession.slots.size()==4,"four clients connected")
	game = preload("res://scenes/main/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await get_tree().create_timer(0.3).timeout
	if role=="host": NetSession.start_match()
	for i in 240:
		if GameManager.state==GameManager.State.PLAYING and is_instance_valid(NetSession.world) and NetSession.world.game.players.size()==4: break
		await get_tree().create_timer(0.05).timeout
	game = get_tree().current_scene
	check(game.players.size()==4,"four players in game")
	if game.players.size()!=4:
		get_tree().quit(1)
		return
	check(GameManager.horde_mode,"horde mode synchronized")
	if role=="host":
		game.level.phase_time = 90
		var positions: Array = game.players.map(func(p): return p.position.x)
		await get_tree().create_timer(2.5).timeout
		for i in range(1,4):
			check(game.players[i].position.x>float(positions[i])+15,"remote movement slot %d" % i)
			check(game.players[i].damage_level==1,"remote purchase slot %d" % i)
		game.level.wave = 2
		game.level.start_wave()
		await get_tree().create_timer(1).timeout
		game.level._spawn_wave_boss()
		game.level.boss_pending = false
		for i in 200:
			var done := true
			for guest in ["one","two","three"]: done = done and FileAccess.file_exists("res://tests/four_"+guest+"_done.txt")
			if done: break
			await get_tree().create_timer(0.05).timeout
	else:
		var index := NetSession.local_index
		check(index>0 and index<4,"independent local slot")
		check(game.players[index].get_camera().is_current(),"personal camera")
		NetSession.send_packet({"type":"control","action":"buy","upgrade":"damage"})
		Input.action_press("move_right")
		await get_tree().create_timer(0.5).timeout
		Input.action_release("move_right")
		await get_tree().create_timer(0.4).timeout
		check(game.players[index].damage_level==1,"authoritative upgrade replicated")
		check(int(game.level.wallets[index])==30,"personal credits replicated")
		for i in 180:
			if game.level.wave==3 and NetSession.world.proxies.size()>3: break
			await get_tree().create_timer(0.05).timeout
		check(game.level.wave==3 and game.level.phase=="combat","wave and combat phase replicated")
		check(NetSession.world.proxies.size()>3,"horde entities replicated")
		var boss_seen := false
		for i in 160:
			for proxy in NetSession.world.proxies.values():
				if proxy.get_script()==preload("res://scripts/enemies/boss_visual.gd"): boss_seen = true
			if boss_seen: break
			await get_tree().create_timer(0.05).timeout
		check(boss_seen,"boss appears on remote client")
		var file := FileAccess.open("res://tests/four_"+role+"_done.txt",FileAccess.WRITE)
		file.store_string("done")
		file.close()
		await get_tree().create_timer(1).timeout
	print("FOUR %s: %d checks, %d failures" % [role,checks,failures])
	get_tree().quit(0 if failures==0 else 1)
