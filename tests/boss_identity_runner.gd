extends Node
var checks := 0
var failures := 0
const PATTERNS := preload("res://scripts/enemies/boss_patterns.gd")
const HAZARD := preload("res://scripts/enemies/boss_hazard.gd")
func _ready() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("BOSS IDENTITY: "+label)
func run() -> void:
	GameManager.campaign_path = "res://tests/boss_identity_temp.cfg"
	NetSession.disconnect_room()
	NetSession.online = true
	NetSession.host = true
	NetSession.slots = [0,1]
	NetSession.peer_versions = {"1":1}
	NetSession.start_match()
	check(NetSession.status.contains("ACTUALIZAR"),"old clients cannot start incompatible boss protocol")
	NetSession.receive({"type":"start","config":{"version":1}})
	check(NetSession.status.contains("VERSION"),"old hosts are rejected before loading incompatible state")
	NetSession.disconnect_room()
	GameManager.coop = true
	GameManager.horde_mode = true
	GameManager.party_characters = ["orange"]
	GameManager.skip_menu = true
	var game := preload("res://scenes/main/Main.tscn").instantiate()
	add_child(game)
	game.level.set_physics_process(false)
	var player: Player = game.players[0]
	player.set_physics_process(false)
	player._invuln = 999
	player.position = Vector2(350,150)
	var rage_actions := {}
	var signatures := {}
	for id in PATTERNS.MOVES:
		var b := Boss.new()
		b.boss_id = id
		b.position = Vector2(740,150 if id in ["sierra","estruendo","coloso"] else 60)
		game.level.add_child(b)
		game.level.boss = b
		b.activate()
		var signature: Array = []
		for i in 3:
			b._phase = "idle"
			b._abil_i = i
			b._begin_next()
			check(b._phase=="tell" and b._phase_t>=0.85,id+" fair warning before attack")
			check(b._act==PATTERNS.MOVES[id][i],id+" distinct attack "+b._act)
			for frame in 76: await get_tree().physics_frame
			check(b._visual._animator.has_animation("tell") and b._visual._animator.has_animation("act"),id+" authored rig clips")
			for h in get_tree().get_nodes_in_group("boss_hazard"):
				if h.source and h.source.get_ref()==b: signature.append([h.kind,h.size,h.velocity])
			b._end_act()
			for h in get_tree().get_nodes_in_group("boss_hazard"): h.queue_free()
			await get_tree().process_frame
		signatures[str(signature)] = true
		b._enter_rage()
		rage_actions[b._act] = true
		check(b._phase=="tell" and b._phase_t>=0.75,id+" phase change has no shared instant dash")
		var network := preload("res://scripts/main/net_world.gd").new()
		network.game = game
		var packet: Dictionary = network.snapshot()
		check(packet["entities"].any(func(e): return e["type"]=="enemy" and e.get("boss",false) and e.get("rig_state","")=="tell"),id+" rig state included online")
		if get_tree().get_nodes_in_group("boss_hazard").size()>0:
			check(packet["entities"].any(func(e): return e["type"]=="boss_hazard"),id+" warning hazards included online")
		network.free()
		b.take_damage(10000,player.position)
		await get_tree().physics_frame
		await get_tree().physics_frame
		check(get_tree().get_nodes_in_group("boss_hazard").is_empty(),id+" attacks disappear when boss dies")
		for e in get_tree().get_nodes_in_group("enemy"): e.queue_free()
		await get_tree().process_frame
	check(rage_actions.size()==9,"nine different phase-two openings")
	check(signatures.size()==9,"nine different attack geometries")
	player.position = Vector2(450,150)
	player._invuln = 0
	GameManager.set_player_health(0,28)
	var h := HAZARD.new()
	h.position = Vector2(450,136)
	h.size = Vector2(28,28)
	h.warn = 0.5
	h.duration = 0.5
	game.world.add_child(h)
	for frame in 20: await get_tree().physics_frame
	check(GameManager.p_health[0]==28,"warning cannot deal damage")
	for frame in 16: await get_tree().physics_frame
	check(GameManager.p_health[0]<28,"active attack deals physical damage")
	h.queue_free()
	var pod := HAZARD.new()
	pod.kind = "pod"
	pod.position = Vector2(420,80)
	pod.duration = 5
	game.world.add_child(pod)
	game.world.add_child(Bullet.create(preload("res://assets/sprites/fx/bullet_player.png"),Vector2(375,80),Vector2.RIGHT,450,9,true))
	for frame in 15: await get_tree().physics_frame
	check(not is_instance_valid(pod),"nest can be destroyed with a real projectile")
	game.queue_free()
	await get_tree().process_frame
	print("BOSS IDENTITY: %d checks, %d failures" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)
