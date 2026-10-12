extends Node
var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+label)

func run() -> void:
	GameManager.campaign_path = "res://tests/duo_temporary.cfg"
	GameManager.cleared.clear()
	GameManager.coop_cleared.clear()
	for id in GameManager.BOSS_ORDER:
		GameManager.selected_boss = id
		GameManager.coop = true
		GameManager.skip_menu = true
		var game := preload("res://scenes/main/Main.tscn").instantiate()
		add_child(game)
		var a: Player = game.players[0]
		var b: Player = game.players[1]
		for p in game.players:
			p.set_physics_process(false)
			p._invuln = 100
		check(game.level.get_script() == preload("res://scripts/world/coop_stage.gd"),id+" distinct coop map")
		check(game.level.stations.size() == 6,id+" six team objectives")
		var overlaps := 0
		var decks: Array = game.level.architecture_decks
		for i in decks.size():
			if decks[i].solid: continue
			var rect := Rect2(decks[i].position,decks[i].size).grow(-0.5)
			for j in range(i+1,decks.size()):
				if not decks[j].solid and rect.intersects(Rect2(decks[j].position,decks[j].size).grow(-0.5)): overlaps += 1
		check(overlaps==0,id+" cooperative routes contain no overlapping decks")
		for puzzle in game.level.puzzles:
			check(preload("res://tests/puzzle_solver.gd").complete(puzzle,a),id+" themed online puzzle")
		for station in game.level.stations:
			a.position = station.position+station.pads[0]
			b.position = a.position+Vector2(60,0)
			station._physics_process(1.3)
			check(not station.solved,id+" one player cannot solve objective")
			b.position = station.position+station.pads[1]
			if station.kind == 0:
				station._physics_process(1.3)
				check(station.solved,id+" simultaneous pads open gate")
			elif station.kind == 1:
				station._physics_process(0.01)
				var relay: Node
				for child in station.get_children():
					if child.get_script() == preload("res://scripts/world/coop_switch.gd"):
						relay = child
				relay.receive_projectile(3,Vector2.ZERO,0)
				check(relay.lit,id+" plate owner cannot fire own switch")
				relay.receive_projectile(3,Vector2.ZERO,1)
				check(station.solved,id+" other player activates switch")
			else:
				for i in 3:
					station._physics_process(3.1)
					check(station.wave == i+1,id+" wave %d" % (i+1))
					for e in station.enemies:
						if is_instance_valid(e) and not e.dead:
							e.take_team_damage(10000,Vector2.ZERO)
					await get_tree().process_frame
				station._physics_process(0.01)
				check(station.solved,id+" defense requires all waves")
		a.position = Vector2(40,146)
		b.position = Vector2(300,86)
		await get_tree().create_timer(0.3).timeout
		check(game._shared_cam.zoom.x < 1,"camera fits both players")
		b.position = a.position+Vector2(20,0)
		b._die()
		Input.action_press("interact")
		await get_tree().create_timer(1.7).timeout
		Input.action_release("interact")
		check(b.alive,"hold interact rescues ally")
		check(GameManager.p_health[1] == 14,"revive restores partial health")
		b.set_physics_process(false)
		var retries: int = GameManager.team_retries
		a._die()
		b._die()
		await get_tree().physics_frame
		await get_tree().physics_frame
		check(a.alive and b.alive,"both down regroup together")
		check(GameManager.team_retries == retries-1,"shared retry consumed once")
		a.set_physics_process(false)
		b.set_physics_process(false)
		var director: Node2D = game.world.get_node("CoopDirector")
		b.position = Vector2(100,230)
		b.fall_death()
		check(b.position.y < 208,"fallen teammate remains rescuable")
		b.respawn_at(a.position+Vector2(20,0))
		b.set_physics_process(false)
		GameManager.team_energy = 100
		var foe := preload("res://scripts/enemies/specialist.gd").new()
		foe.role = "sentinel"
		foe.position = a.position+Vector2(50,0)
		game.world.add_child(foe)
		director.team_attack()
		check(foe.dead,"fusion defeats nearby target")
		check(GameManager.team_energy == 0,"fusion consumes energy")
		a.position = Vector2(game.level.arena_x+40,146)
		b.position = Vector2(game.level.arena_x-100,146)
		game.level._on_arena_trigger(a)
		check(b.position.x >= game.level.arena_x,"boss gate gathers both players")
		game.level.boss.take_damage(10000,a.position)
		a.position = game.level.goal.position
		game.level._on_goal_reached()
		check(not GameManager.coop_cleared.has(id),"cannot finish without teammate")
		b.position = game.level.goal.position+Vector2(-20,0)
		game.level._on_goal_reached()
		check(GameManager.coop_cleared.has(id),"duo clear recorded")
		check(not GameManager.cleared.has(id),"solo progress independent")
		get_tree().paused = false
		game.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	GameManager.coop_cleared.clear()
	GameManager.load_campaign()
	check(GameManager.coop_cleared.size() == 8,"duo progress survives reload")
	var menu_game := preload("res://scenes/main/Main.tscn").instantiate()
	add_child(menu_game)
	var overlay: Overlay = menu_game.get_node("UI").get_child(2)
	overlay._action("solo")
	check(not GameManager.coop,"solo mode selector")
	overlay._sel = 2
	overlay._apply_char()
	overlay._action("duo")
	check(overlay._tab == 4,"duo opens online lobby instead of local pilot selection")
	check(overlay.scale == Vector2.ONE*0.5,"smaller menu type canvas")
	menu_game.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameManager.campaign_path))
	print("DUO: %d checks, %d failures" % [checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
