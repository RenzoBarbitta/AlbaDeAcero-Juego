extends Node
const MAIN := preload("res://scenes/main/Main.tscn")
var checks := 0
var failures := 0
var lengths: Array = []

func _ready() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: "+label)

func run() -> void:
	GameManager.campaign_path = "res://tests/temporary_campaign.cfg"
	GameManager.acquired_powers.clear()
	GameManager.cleared.clear()
	GameManager.campaign_score = 0
	for id in GameManager.BOSS_ORDER:
		GameManager.selected_boss = id
		GameManager.skip_menu = true
		GameManager.coop = false
		var game := MAIN.instantiate()
		add_child(game)
		await get_tree().process_frame
		var stage: Node2D = game.level
		var player: Player = game.players[0]
		player._invuln = 100
		lengths.append(GameManager.level_length)
		check(GameManager.level_length > 6000,id+" extended length")
		check(stage.puzzles.size() == 3,id+" three exploration rooms")
		check(GameManager.checkpoints.size() >= 5,id+" checkpoints")
		check(stage.camera_rect.position.y <= -200,id+" vertical camera")
		check(get_tree().get_nodes_in_group("enemy").size() >= 20,id+" enemy density")
		for puzzle in stage.puzzles:
			check(preload("res://tests/puzzle_solver.gd").complete(puzzle,player),id+" themed puzzle solvable")
		await get_tree().process_frame
		for puzzle in stage.puzzles:
			check(not is_instance_valid(puzzle.door),id+" puzzle opens route")
		player.position = Vector2(stage.arena_x+100,145)
		stage._on_arena_trigger(player)
		await get_tree().create_timer(0.15).timeout
		check(stage._arena_locked,id+" arena locks")
		stage.boss.take_damage(10000,player.global_position)
		check(stage._boss_down,id+" actual boss kill")
		check(GameManager.acquired_powers.has(id),id+" acquired immediately")
		check(player.weapon == id,id+" power auto equipped")
		check(stage.goal.visible,id+" exit revealed")
		player._fire_power()
		await get_tree().create_timer(0.2).timeout
		check(GameManager.current_weapon == id,id+" HUD weapon")
		player._cycle_weapon()
		check(player.weapon != id,id+" Q cycles")
		if GameManager.coop:
			check(game.players[1].weapon == id,"P2 receives boss power")
			game.players[1]._cycle_weapon()
			check(game.players[1].weapon != id,"P2 cycles independently")
		stage._on_goal_reached()
		check(GameManager.cleared.has(id),id+" stage marked cleared")
		get_tree().paused = false
		game.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	GameManager.acquired_powers.clear()
	GameManager.cleared.clear()
	GameManager.load_campaign()
	check(GameManager.acquired_powers.size() == 8,"all powers reload from disk")
	check(GameManager.cleared.size() == 8,"all cleared stages reload from disk")
	GameManager.new_game()
	for id in GameManager.BOSS_ORDER:
		check(GameManager.unlocked.has(id),id+" power survives stage reset")
	# Exercise every specialist AI and every power against live targets.
	GameManager.coop = true
	GameManager.skip_menu = true
	var game := MAIN.instantiate()
	add_child(game)
	var player: Player = game.players[0]
	player._invuln = 100
	for p in game.players:
		p.set_physics_process(false)
	var roles := ["sentinel","sniper","stalker","medic","orbiter","mortar"]
	for i in roles.size():
		game.level._spawn_enemy(roles[i],100+i*20,145 if i != 3 and i != 4 else 90)
	await get_tree().create_timer(3.2).timeout
	for id in GameManager.BOSS_ORDER:
		player.equip_power(id)
		player._fire_power()
		await get_tree().create_timer(0.9).timeout
	for n in game.world.get_children():
		if n is Bullet:
			n.queue_free()
	await get_tree().process_frame
	var old_hp: int = GameManager.p_health[1]
	GameManager.damage_player(1,10)
	var pickup = preload("res://scripts/pickups/pickup.gd").create("health",Vector2.ZERO)
	game.world.add_child(pickup)
	pickup._apply(game.players[1])
	check(GameManager.p_health[1] == old_hp-2,"coop pickup heals correct player")
	# Pilot reconstruction must stay visible after respawn without old sprites.
	player.respawn_at(Vector2(40,146))
	check(not player._sprite.visible and not player._arm.visible,"respawn retains new art")
	game.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameManager.campaign_path))
	print("RECONSTRUCTION: %d checks, %d failures; lengths=%s" % [checks,failures,str(lengths)])
	get_tree().quit(0 if failures == 0 else 1)
