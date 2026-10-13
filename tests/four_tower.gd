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
		push_error("TOWER ONLINE FAIL: "+label)
func run() -> void:
	role = OS.get_environment("ALBA_TEST_ROLE")
	GameManager.campaign_path = "res://tests/tower_"+role+".cfg"
	GameManager.coop = true
	GameManager.horde_mode = true
	GameManager.character = {"host":"orange","one":"mint","two":"white","three":"violet"}[role]
	NetSession.server_url = OS.get_environment("ALBA_RELAY_URL")
	if role=="host":
		NetSession.connect_room(true)
		for i in 600:
			if NetSession.online: break
			await get_tree().create_timer(0.05).timeout
		var file := FileAccess.open("res://tests/tower_room.txt",FileAccess.WRITE)
		file.store_string(NetSession.room_code)
		file.close()
	else:
		var code := ""
		for i in 600:
			if FileAccess.file_exists("res://tests/tower_room.txt"):
				code = FileAccess.get_file_as_string("res://tests/tower_room.txt")
				if code.length()==6: break
			await get_tree().create_timer(0.05).timeout
		NetSession.connect_room(false,code)
	for i in 600:
		if NetSession.slots.size()==4 and (role!="host" or NetSession.profiles.size()==3): break
		await get_tree().create_timer(0.05).timeout
	check(NetSession.slots.size()==4,"four clients connected")
	game = preload("res://scenes/main/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await get_tree().create_timer(0.3).timeout
	if role=="host": NetSession.start_match()
	for i in 600:
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
		game.level.finish_wave()
		for p in game.players: p.position = Vector2(426+p.index*36,150)
		game.level.mark_ready(0)
		for i in 600:
			if game.level.floor_number==2 and game.level.phase=="combat": break
			await get_tree().create_timer(0.05).timeout
		check(game.level.floor_number==2 and game.level.wave==1,"four clients board and arrive together")
		game.level.set_physics_process(false)
		await get_tree().create_timer(0.5).timeout
		for i in 600:
			var done := true
			for guest in ["one","two","three"]: done = done and FileAccess.file_exists("res://tests/tower_"+guest+"_done.txt")
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
		for i in 600:
			if game.level.phase=="shop": break
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(0.4).timeout
		check(game.level.in_cabin(game.players[index]),"remote pilot enters the cabin")
		NetSession.send_packet({"type":"control","action":"ready"})
		var saw_transit := false
		for i in 600:
			if game.level.phase=="transit": saw_transit = true
			if game.level.floor_number==2 and game.level.phase=="combat": break
			await get_tree().create_timer(0.05).timeout
		check(saw_transit,"moving elevator replicated")
		if game.level.floor_number!=2: print("PUBLIC STATE: floor=",game.level.floor_number," phase=",game.level.phase," frame=",NetSession.world._frame," manager=",GameManager.state," pending=",GameManager.scene_transition_pending," status=",NetSession.status)
		check(game.level.floor_number==2 and game.level.phase=="combat","next floor synchronized")
		check(game.level.floor_decks[0].position==Vector2(44,110),"next floor collision layout synchronized")
		check(game.players[index].damage_level==1,"upgrade survives elevator")
		var file := FileAccess.open("res://tests/tower_"+role+"_done.txt",FileAccess.WRITE)
		file.store_string("done")
		file.close()
		await get_tree().create_timer(1).timeout
	print("TOWER ONLINE %s: %d checks, %d failures" % [role,checks,failures])
	get_tree().quit(0 if failures==0 else 1)
