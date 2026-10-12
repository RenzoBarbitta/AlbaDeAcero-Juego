extends Node
var checks := 0
var failures := 0
func _ready() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("HORDE FAIL: "+label)
func run() -> void:
	GameManager.campaign_path = "res://tests/horde_temp.cfg"
	GameManager.profile_bosses.clear()
	GameManager.best_wave = 0
	GameManager.mobility.clear()
	check(GameManager.CHARACTER_ORDER.size()==8,"eight pilots")
	check(not GameManager.pilot_unlocked("gold") and not GameManager.pilot_unlocked("cyan"),"two locked pilots")
	GameManager.record_progress("sierra",3)
	check(GameManager.mobility.has("double_jump"),"wave three double jump")
	for id in ["coloso","glaciar","incendio"]: GameManager.record_progress(id)
	check(GameManager.pilot_unlocked("gold") and GameManager.mobility.has("jetpack"),"four distinct bosses unlock Aegis and jetpack")
	GameManager.record_progress("",10)
	check(GameManager.pilot_unlocked("cyan"),"wave ten unlock Nova")
	for zone_boss in GameManager.BOSS_ORDER:
		GameManager.coop = true
		GameManager.horde_mode = true
		GameManager.party_characters = ["orange","mint","white","cyan"]
		GameManager.selected_boss = zone_boss
		GameManager.skip_menu = true
		var game := preload("res://scenes/main/Main.tscn").instantiate()
		add_child(game)
		await get_tree().process_frame
		var stage: Node2D = game.level
		check(game.players.size()==4,zone_boss+" four actors")
		stage.set_physics_process(false)
		for p in game.players: p.set_physics_process(false)
		check(stage.wave_budget(4,1)>stage.wave_budget(2,1) and stage.wave_budget(2,1)>stage.wave_budget(1,1),"party scaling")
		if zone_boss==GameManager.BOSS_ORDER[0]:
			var p: Player = game.players[0]
			for pilot_id in GameManager.CHARACTER_ORDER:
				p.character = pilot_id
				p.weapon = GameManager.CHARACTERS[pilot_id]["primary"]
				var before: int = game.world.get_children().filter(func(n): return n is Bullet and n.from_player).size()
				match p.weapon:
					"buster": p._fire_buster()
					"spread": p._fire_spread()
					"laser": p._fire_laser()
					"plasma": p._fire_plasma()
					_: p._fire_special_primary()
				check(game.world.get_children().filter(func(n): return n is Bullet and n.from_player).size()>before,"primary fires: "+pilot_id)
			p.character = "mint"
			game.players[3].alive = false
			game.players[3].position = p.position+Vector2(20,0)
			var director: Node2D = game.world.get_node("CoopDirector")
			Input.action_press("interact")
			director._physics_process(0.8)
			Input.action_release("interact")
			check(game.players[3].alive and GameManager.p_health[3]==14,"Iris rescues fourth player twice as fast")
			p.character = "orange"
		var money: int = stage.wallets[2]
		check(stage.buy_upgrade(2,"damage"),"purchase personal upgrade")
		check(stage.wallets[2]==money-90 and stage.wallets[1]==120 and game.players[2].damage_level==1,"independent wallet and stats")
		check(not stage.buy_upgrade(-1,"armor") and not stage.buy_upgrade(8,"damage"),"invalid players rejected")
		check(not stage.buy_upgrade(2,"damage"),"insufficient funds rejected")
		stage.start_wave()
		check(not stage.buy_upgrade(1,"armor"),"no purchases during combat")
		for i in 6: stage._spawn_horde_enemy()
		check(stage.living_count()==6,"horde enemies spawn")
		stage.wave = 2
		game.players[0].position = Vector2(210,150)
		game.players[1].position = Vector2(500,150)
		game.players[2].position = Vector2(500,150)
		game.players[3].position = Vector2(500,150)
		stage._update_bonus(3)
		check(stage.bonus_progress==0,"cooperative bonus needs two separate pilots")
		game.players[1].position = Vector2(770,150)
		var credits: int = stage.wallets[0]
		stage._update_bonus(6)
		check(stage.bonus_done and stage.wallets[0]==credits+80,"two-player bonus rewards the whole squad")
		stage.wave = 3
		stage._spawn_wave_boss()
		check(is_instance_valid(stage.boss) and stage.boss.active,"boss arrives during horde")
		for enemy in get_tree().get_nodes_in_group("enemy"): enemy.queue_free()
		await get_tree().process_frame
		stage.finish_wave()
		check(stage.phase=="shop" and stage.wallets[0]>120,"wave reward and workshop")
		var network := preload("res://scripts/main/net_world.gd").new()
		network.game = game
		var packet: Dictionary = network.snapshot()
		check(packet["actors"].size()==4 and packet["horde"]["wave"]==3,"four player horde snapshot")
		network.free()
		game.queue_free()
		await get_tree().process_frame
	print("HORDE: %d checks, %d failures" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)
