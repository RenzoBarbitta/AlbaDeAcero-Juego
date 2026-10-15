extends Node
var checks := 0
var failures := 0
func _ready() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("NET REGRESSION: "+label)
func bullets(game: Node) -> int:
	return game.world.get_children().filter(func(n): return n is Bullet).size()
func run() -> void:
	GameManager.campaign_path = "res://tests/network_regression.cfg"
	GameManager.coop = true
	GameManager.horde_mode = true
	GameManager.party_characters = ["orange","mint"]
	GameManager.skip_menu = true
	var game := preload("res://scenes/main/Main.tscn").instantiate()
	add_child(game)
	var p: Player = game.players[1]
	game.level.set_physics_process(false)
	for actor in game.players: actor.set_physics_process(false)
	# Exercise the real shooting path with repeated presses inside one cooldown.
	NetSession.online = true
	NetSession.host = true
	NetSession.remote_inputs["1"] = {"shoot":true}
	p._remote_edges["shoot"] = true
	p.weapon = "buster"
	Input.action_press("shoot")
	var before := bullets(game)
	for i in 15: p._shoot_buster(0.001)
	check(bullets(game)-before==1,"rapid taps cannot bypass buster cooldown")
	Input.action_release("shoot")
	NetSession.remote_inputs.clear()
	NetSession.online = false
	p._end_charge()
	p._shoot_cooldown = 0.8
	p.equip_power("sierra")
	check(p._shoot_cooldown>=0.8,"equip preserves recovery")
	p.fire_level = 5
	p.bonus_mobility = ["overclock"]
	p._shoot_cooldown = 1.0
	p._update_timers(0.1)
	check(p._shoot_cooldown>=0.86,"all cadence upgrades capped at forty percent")
	p.damage_level = 5
	var shot := Bullet.create(Player.WEAPON_TEX.buster,Vector2(500,80),Vector2.RIGHT,300,10,true)
	p._spawn_bullet(shot)
	check(shot.damage==15,"max damage upgrades add fifty percent")
	# Real wall query: chain lightning cannot hit through a solid wall or behind aim.
	p.position = Vector2(480,150)
	p.aim = Vector2.RIGHT
	var enemy := preload("res://scripts/enemies/zone_enemy.gd").new()
	enemy.position = Vector2(550,150)
	game.level.add_child(enemy)
	enemy.set_physics_process(false)
	await get_tree().physics_frame
	check(p._chain_targets([enemy]).size()==1,"chain accepts visible target in cone")
	p.aim = Vector2.LEFT
	check(p._chain_targets([enemy]).is_empty(),"chain rejects target behind aim")
	p.aim = Vector2.RIGHT
	var wall := StaticBody2D.new()
	wall.position = Vector2(528,130)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8,80)
	shape.shape = rect
	wall.add_child(shape)
	game.world.add_child(wall)
	await get_tree().physics_frame
	check(p._chain_targets([enemy]).is_empty(),"chain rejects occluded target")
	p.weapon = "online_nova"
	enemy.max_health = 1000
	enemy.health = 1000
	var previous_bullets: Array = game.world.get_children().filter(func(n): return n is Bullet)
	p._fire_online_weapon()
	var salvo: Array = game.world.get_children().filter(func(n): return n is Bullet and not previous_bullets.has(n))
	for pellet in salvo: pellet._on_body_entered(enemy)
	check(salvo.size()==8 and enemy.health>=988,"radial nova cannot stack all eight pellets on one boss")
	NetSession.online = true
	NetSession.host = true
	NetSession.receive({"type":"input","sender":1,"seq":1,"data":{"jump":true},"presses":{"jump":1}})
	NetSession.receive({"type":"input","sender":1,"seq":2,"data":{"jump":false},"presses":{"jump":1},"releases":{"jump":1}})
	p._physics_process(1.0/60)
	check(p._remote_edges.get("jump",false) and p._remote_released.get("jump",false),"short tap survives multiple packets in one frame")
	p._physics_process(1.0/60)
	check(not p._remote_edges.get("jump",false),"input edge consumed once")
	NetSession.receive({"type":"input","sender":1,"seq":5,"data":{"jump":false},"presses":{"jump":2},"releases":{"jump":2}})
	p._physics_process(1.0/60)
	check(p._remote_edges.get("jump",false),"cumulative edge counter survives a lost input packet")
	# Guest sound honors its own preference; muted hosts still produce events.
	NetSession.online = true
	NetSession.host = true
	var net := preload("res://scripts/main/net_world.gd").new()
	net.game = game
	game.add_child(net)
	GameManager.settings.sfx = false
	AudioManager.play("jump",-10)
	Fx.explosion(game.world,Vector2(500,80),1)
	check(net._events.any(func(e): return e.kind=="sound"),"muted host still sends audio")
	var encoded: Dictionary = NetSession.encode_snapshot(net.snapshot())
	var raw := Marshalls.base64_to_raw(encoded.data).decompress(int(encoded.size),FileAccess.COMPRESSION_ZSTD)
	var decoded = JSON.parse_string(raw.get_string_from_utf8())
	check(decoded is Dictionary and decoded.actors.size()==2,"compressed snapshots roundtrip")
	NetSession.host = false
	var count := AudioManager.remote_playbacks
	net._play_events(decoded.events)
	net._play_events(decoded.events)
	check(AudioManager.remote_playbacks==count+1,"repeated snapshots play a sound once")
	check(net.remote_fx_count==1,"repeated snapshots play an explosion once")
	var hp: int = GameManager.p_health[p.index]
	p._invuln = 0
	p.take_damage(99,Vector2.ZERO)
	check(GameManager.p_health[p.index]==hp,"predicted client cannot apply damage")
	NetSession.disconnect_room()
	Input.action_release("shoot")
	print("NETWORK REGRESSION: %d checks, %d failures" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)
