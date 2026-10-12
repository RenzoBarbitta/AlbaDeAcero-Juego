extends Node2D
var checks := 0
var failures := 0
const REGION := preload("res://scripts/enemies/zone_enemy.gd")
func _ready() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+label)

func solution(puzzle: Node2D) -> Array:
	var queue: Array = [{"values":puzzle.values.duplicate(),"moves":[]}]
	var seen := {}
	while not queue.is_empty():
		var node: Dictionary = queue.pop_front()
		if node["values"] == puzzle.target:
			return node["moves"]
		var key := str(node["values"])
		if seen.has(key): continue
		seen[key] = true
		for i in puzzle.values.size():
			var next: Array = node["values"].duplicate()
			if puzzle.zone == "central":
				for j in [i,(i+1)%4,(i+3)%4]: next[j] = not next[j]
			elif puzzle.zone == "volcan":
				if int(next[i]) <= 0: continue
				next[i] -= 1
				next[(i+1)%3] += 1
			else: next[i] = (int(next[i])+1)%4
			queue.append({"values":next,"moves":node["moves"]+[i]})
	return []

func run() -> void:
	GameManager.campaign_path = "res://tests/zones_temp.cfg"
	NetSession.disconnect_room()
	for boss_id in GameManager.BOSS_ORDER:
		GameManager.selected_boss = boss_id
		GameManager.coop = false
		GameManager.skip_menu = true
		var game := preload("res://scenes/main/Main.tscn").instantiate()
		add_child(game)
		game.players[0].set_physics_process(false)
		check(game.level.puzzles.size()==3,boss_id+" three themed puzzles")
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Boss: continue
			check(e.get_script()==REGION and e.zone==GameManager.theme_id,boss_id+" enemies exclusive to zone")
		for puzzle in game.level.puzzles:
			puzzle.set_physics_process(false)
			if puzzle.has_method("expedition_state"):
				check(preload("res://tests/puzzle_solver.gd").complete(puzzle,game.players[0]),boss_id+" spatial expedition completable: "+puzzle.rule)
				await get_tree().process_frame
				check(not is_instance_valid(puzzle.door),boss_id+" spatial expedition opens gate")
				continue
			if puzzle.zone in ["glaciar","ciudad","biolab"]:
				puzzle.activate((int(puzzle.sequence[0])+1)%3)
				check(puzzle.step==0 and not puzzle.solved,boss_id+" wrong order recovers")
				for item in puzzle.sequence: puzzle.activate(int(item))
				if puzzle.zone=="biolab":
					game.players[0].position = puzzle.position+puzzle.control_position(2)
					puzzle._physics_process(5.1)
			else:
				puzzle.clock = 2
				var moves := solution(puzzle)
				check(not moves.is_empty(),boss_id+" puzzle has a valid solution")
				for index in moves: puzzle.activate(int(index))
			check(puzzle.solved,boss_id+" puzzle completable")
			await get_tree().process_frame
			check(not is_instance_valid(puzzle.door),boss_id+" solved puzzle opens route")
		game.queue_free()
		await get_tree().process_frame
	# Reproduce stacked platforms using the real player and engine collision.
	GameManager.coop = false
	GameManager.theme_id = "central"
	GameManager.new_game()
	GameManager.state = GameManager.State.PLAYING
	get_tree().paused = false
	var floor_piece := Platform.new()
	floor_piece.position = Vector2(0,150)
	floor_piece.size = Vector2(600,46)
	add_child(floor_piece)
	var low := Platform.new()
	low.tile = "platform"
	low.position = Vector2(100,118)
	low.size = Vector2(180,16)
	add_child(low)
	var high := Platform.new()
	high.tile = "platform"
	high.position = Vector2(160,86)
	high.size = Vector2(180,16)
	add_child(high)
	var player := preload("res://scripts/player/player.gd").new()
	player.position = Vector2(130,150)
	add_child(player)
	await get_tree().create_timer(0.1).timeout
	Input.action_press("jump")
	await get_tree().create_timer(0.55).timeout
	Input.action_release("jump")
	await get_tree().create_timer(0.1).timeout
	check(player.position.y<=119 and player.is_on_floor(),"jump through underside lands on first deck")
	Input.action_press("move_right")
	Input.action_press("jump")
	await get_tree().create_timer(0.55).timeout
	Input.action_release("jump")
	Input.action_release("move_right")
	await get_tree().create_timer(0.15).timeout
	check(player.position.y<=87 and player.is_on_floor(),"climb next overlapping deck without ceiling block")
	player.queue_free()
	await get_tree().process_frame
	# Exercise both enemy variants in every zone for their telegraphs and attacks.
	for zone in REGION.FAMILY.keys():
		for airborne in [false,true]:
			var enemy := REGION.new()
			enemy.zone = zone
			enemy.airborne = airborne
			enemy.position = Vector2(400,150 if not airborne else 70)
			add_child(enemy)
			enemy.attack()
			check(enemy.max_health>0 and enemy.FAMILY.has(zone),"regional variant initialized")
			enemy.take_team_damage(10000,Vector2.ZERO)
		await get_tree().process_frame
	print("ZONES: %d checks, %d failures" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)
