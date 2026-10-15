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
		push_error("NETWORK ONLINE FAIL: "+label)
func run() -> void:
	role = OS.get_environment("ALBA_TEST_ROLE")
	GameManager.campaign_path = "res://tests/network_online_"+role+".cfg"
	GameManager.coop = true
	GameManager.horde_mode = true
	GameManager.character = {"host":"orange","one":"mint","two":"white","three":"violet"}[role]
	NetSession.server_url = OS.get_environment("ALBA_RELAY_URL")
	if role=="host":
		NetSession.connect_direct(true) if OS.get_environment("ALBA_DIRECT")=="1" else NetSession.connect_room(true)
		for i in 600:
			if NetSession.online: break
			await get_tree().create_timer(0.05).timeout
		var file := FileAccess.open("res://tests/network_room.txt",FileAccess.WRITE)
		file.store_string(NetSession.room_code)
		file.close()
	else:
		var code := ""
		for i in 600:
			if FileAccess.file_exists("res://tests/network_room.txt"):
				code = FileAccess.get_file_as_string("res://tests/network_room.txt")
				if code.length()==6: break
			await get_tree().create_timer(0.05).timeout
		NetSession.connect_direct(false,"127.0.0.1") if OS.get_environment("ALBA_DIRECT")=="1" else NetSession.connect_room(false,code)
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
		game.level.start_wave()
		game.level.set_physics_process(false)
		for p in game.players: p._invuln = 999
		var chief := Boss.new()
		chief.boss_id = "voltaje"
		chief.position = Vector2(740,60)
		game.level.add_child(chief)
		game.level.boss = chief
		chief.activate()
		var shot := Bullet.create(Player.WEAPON_TEX.charged,Vector2(620,80),Vector2.RIGHT,100,12,true,1.45)
		shot.effect = "sierra"
		game.world.add_child(shot)
		shot.set_physics_process(false)
		AudioManager.play("shoot",-12)
		Fx.ring(game.world,Vector2(600,100),Color.CYAN,2,30,0.25)
		Fx.explosion(game.world,Vector2(610,100),1.0)
		Fx.beam(game.world,Vector2(500,100),Vector2(650,80),Color.CYAN)
		for i in 600:
			var done := true
			for guest in ["one","two","three"]: done = done and FileAccess.file_exists("res://tests/network_online_"+guest+"_done.txt")
			if done: break
			await get_tree().create_timer(0.05).timeout
	else:
		var index := NetSession.local_index
		check(index>0 and index<4,"independent local slot")
		check(game.players[index].get_camera().is_current(),"personal camera")
		NetSession.send_packet({"type":"control","action":"buy","upgrade":"damage"})
		var local_start: float = game.players[index].position.x
		Input.action_press("move_right")
		Input.action_press("shoot")
		for frame in 3: await get_tree().physics_frame
		check(game.players[index].position.x>local_start,"local movement predicts before roundtrip")
		await get_tree().create_timer(0.5).timeout
		Input.action_release("move_right")
		Input.action_release("shoot")
		await get_tree().create_timer(0.4).timeout
		check(game.players[index].damage_level==1,"authoritative upgrade replicated")
		check(int(game.level.wallets[index])==30,"personal credits replicated")
		var seen_boss := false
		var seen_warning := false
		var seen_active := false
		for i in 600:
			for proxy in NetSession.world.proxies.values():
				if proxy.get_script()==preload("res://scripts/enemies/boss_visual.gd"):
					seen_boss = proxy.design=="voltaje" and proxy.motion_state in ["tell","act","wait"]
				if proxy.get_script()==preload("res://scripts/enemies/boss_hazard.gd"):
					if proxy.age<proxy.warn: seen_warning = true
					elif proxy.age<proxy.warn+proxy.duration: seen_active = true
			if seen_boss and seen_warning and seen_active: break
			await get_tree().create_timer(0.05).timeout
		check(seen_boss,"boss animation states replicated")
		check(seen_warning,"warning geometry visible remotely before damage")
		check(seen_active,"active attack geometry replicated")
		var replica_shot: Node2D
		for proxy in NetSession.world.proxies.values():
			if proxy is Sprite2D and proxy.get_meta("effect","")=="sierra": replica_shot = proxy
		check(is_instance_valid(replica_shot) and replica_shot.texture.resource_path.ends_with("bullet_charged.png") and absf(replica_shot.scale.x-1.45)<0.01,"guest preserves weapon projectile design")
		if is_instance_valid(replica_shot):
			var rotation_before: float = replica_shot.rotation
			await get_tree().create_timer(0.1).timeout
			check(absf(replica_shot.rotation-rotation_before)>0.1,"guest projectile animation advances between snapshots")
		check(NetSession.world.remote_sound_count>0,"guest receives gameplay sound events")
		check(NetSession.world.remote_fx_count>0,"guest receives transient effects")
		var mark: Node = game.level.get_children().filter(func(n): return n.get_script()==preload("res://scripts/world/scene_landmarks.gd"))[0]
		var before: float = mark.clock
		await get_tree().create_timer(0.2).timeout
		check(mark.clock>before,"guest decorative animations keep running")
		print("GUEST RTT ms=",NetSession.ping_ms," SOUNDS=",NetSession.world.remote_sound_count," FX=",NetSession.world.remote_fx_count)
		var file := FileAccess.open("res://tests/network_online_"+role+"_done.txt",FileAccess.WRITE)
		file.store_string("done")
		file.close()
		await get_tree().create_timer(1).timeout
	print("NETWORK ONLINE %s: %d checks, %d failures" % [role,checks,failures])
	get_tree().quit(0 if failures==0 else 1)
