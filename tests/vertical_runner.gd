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
	GameManager.campaign_path = "res://tests/vertical_temp.cfg"
	NetSession.disconnect_room()
	var silhouettes := {}
	var rules := {}
	for id in GameManager.BOSS_ORDER:
		GameManager.selected_boss = id
		GameManager.coop = false
		GameManager.horde_mode = false
		GameManager.mobility.clear()
		GameManager.skip_menu = true
		var game := preload("res://scenes/main/Main.tscn").instantiate()
		add_child(game)
		for enemy in get_tree().get_nodes_in_group("enemy"): enemy.set_physics_process(false)
		var stage: Node2D = game.level
		var player: Player = game.players[0]
		player._invuln = 1000
		check(stage.districts.size()==3,id+" three full vertical districts")
		for district in stage.districts:
			var points: Array = district["route"]
			var relative: Array = points.map(func(at): return at-Vector2(district["bounds"].position.x,0))
			silhouettes[str(relative)] = true
			check(district.get("authored",false),id+" complete authored room: "+district["title"])
		check(stage.camera_rect.position.y<=-650,id+" camera includes summit")
		var overlaps := 0
		var crowded := 0
		for i in stage.architecture_decks.size():
			var deck: Node2D = stage.architecture_decks[i]
			if deck.solid: continue
			var rect := Rect2(deck.position,deck.size).grow(-0.5)
			for j in range(i+1,stage.architecture_decks.size()):
				var other: Node2D = stage.architecture_decks[j]
				if other.solid: continue
				if rect.intersects(Rect2(other.position,other.size).grow(-0.5)): overlaps += 1
				if absf(deck.position.y-other.position.y)<36 and deck.position.x<other.position.x+other.size.x and other.position.x<deck.position.x+deck.size.x:
					crowded += 1
			for floor_body in stage.get_children():
				if floor_body is Platform and rect.intersects(Rect2(floor_body.position,floor_body.size).grow(-0.5)): overlaps += 1
		check(overlaps==0,id+" no intersecting or duplicated route platforms (%d)" % overlaps)
		check(crowded==0,id+" route platforms have at least 36 pixels between overlapping levels (%d)" % crowded)
		for puzzle in stage.puzzles:
			if puzzle.has_method("expedition_state"):
				rules[puzzle.rule] = true
				check(preload("res://tests/puzzle_solver.gd").complete(puzzle,player),id+" objective opens route: "+puzzle.rule)
		# Verify normal jumps from the usable departure edge to the landing edge.
		for district in stage.districts:
			var definition: Dictionary = preload("res://scripts/world/campaign_rooms.gd").ROOMS[stage.theme_id][district["act"]]
			var decks: Array = definition["decks"]
			for i in range(decks.size()-1):
				if definition["links"].substr(i,1)!="j": continue
				var a: Array = decks[i]
				var b: Array = decks[i+1]
				var side := 1.0 if float(b[0])>float(a[0]) else -1.0
				var gap := absf(float(b[0])-float(a[0]))-(float(a[2])+float(b[2]))*0.5
				if gap>60: continue # Gaps with regional energy/root bridges are tested as devices.
				player.respawn_at(Vector2(district["bounds"].position.x+float(a[0])+side*(float(a[2])*0.5-10),float(a[1])-2))
				player.velocity = Vector2.ZERO
				player.launch_time = 0
				player._invuln = 1000
				for frame in 8: await get_tree().physics_frame
				var target := Vector2(district["bounds"].position.x+float(b[0])-side*(float(b[2])*0.5-12),float(b[1]))
				var reached: bool = await jump_to(player,target)
				check(reached,id+" room %d normal jump %d" % [district["act"],i])
				if not reached: print("POSITION ",player.position," TARGET ",target)
		for puzzle in stage.puzzles:
			if not puzzle.has_method("escort_position") or not is_instance_valid(puzzle.escort_carrier): continue
			puzzle.solved = false
			puzzle.progress = 0
			puzzle.escort_carrier.global_position = puzzle.global_position+puzzle.escort_position()-Vector2(38,8)
			player.respawn_at(puzzle.escort_carrier.position+Vector2(38,-4))
			player._invuln = 1000
			for frame in 1300:
				await get_tree().physics_frame
				if puzzle.solved: break
			check(puzzle.solved,id+" escort can be followed on physical carrier")
			if not puzzle.solved: print("ESCORT ",puzzle.progress," PLAYER ",player.position," CARRIER ",puzzle.escort_carrier.position)
		game.queue_free()
		await get_tree().process_frame
	check(silhouettes.size()==24,"24 different authored room silhouettes")
	check(rules.size()==16,"sixteen different expedition rules")
	print("VERTICAL: %d checks, %d failures" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func jump_to(player: Player,target: Vector2) -> bool:
	Input.action_press("jump")
	var reached := false
	for frame in 85:
		if frame==42: Input.action_release("jump")
		var dx := target.x-player.global_position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx)>5: Input.action_press("move_right" if dx>0 else "move_left")
		await get_tree().physics_frame
		if player.is_on_floor() and player.global_position.y<=target.y+4 and absf(dx)<8:
			reached = true
			break
	Input.action_release("jump")
	Input.action_release("move_left")
	Input.action_release("move_right")
	return reached
