extends Node
var failures := 0
var checks := 0
func _ready() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TRANSPORT FAIL: "+label)
func run() -> void:
	GameManager.campaign_path = "res://tests/transport_temp.cfg"
	GameManager.coop = false
	GameManager.horde_mode = false
	GameManager.mobility.clear()
	for id in GameManager.BOSS_ORDER:
		GameManager.selected_boss = id
		GameManager.skip_menu = true
		var game := preload("res://scenes/main/Main.tscn").instantiate()
		add_child(game)
		var p: Player = game.players[0]
		p._invuln = 999
		for enemy in get_tree().get_nodes_in_group("enemy"): enemy.set_physics_process(false)
		var springs: Array = game.level.get_children().filter(func(n): return n.get_script()==preload("res://scripts/world/spring.gd") and n.guided)
		for spring in springs:
			p.respawn_at(spring.global_position+Vector2(0,-10))
			p._invuln = 999
			p.velocity = Vector2.ZERO
			p.launch_time = 0
			var launched := false
			var reached := false
			for frame in 170:
				await get_tree().physics_frame
				if p.launch_time>0: launched = true
				if launched and p.is_on_floor() and p.global_position.distance_to(spring.launch_target)<72:
					reached = true
					break
			check(launched and reached,id+" launch reaches island without unlocked mobility")
			if not reached: print("TRANSPORT POSITION ",p.global_position," TARGET ",spring.launch_target)
		var ferries: Array = game.level.get_children().filter(func(n): return n is MovingPlatform and n.has_meta("route_transport"))
		for ferry in ferries:
			ferry.motion.stop()
			ferry.position = ferry.route_start
			p.respawn_at(ferry.position+Vector2(ferry.size.x*0.5,-8))
			p.velocity = Vector2.ZERO
			p.launch_time = 0
			p._invuln = 999
			for frame in 12: await get_tree().physics_frame
			ferry.motion.play()
			var destination: Vector2 = ferry.get_meta("destination")
			var width: float = ferry.get_meta("landing_width")
			var carried := false
			var docking := false
			for frame in 430:
				await get_tree().physics_frame
				var dock: Vector2 = ferry.route_start+ferry.travel
				if ferry.position.distance_to(dock)<12: docking = true
				if docking:
					var dx: float = destination.x-p.position.x
					Input.action_press("move_right" if dx>0 else "move_left")
				if docking and p.is_on_floor() and absf(p.position.y-destination.y)<5 and absf(p.position.x-destination.x)<width*0.5-4:
					carried = true
					break
			Input.action_release("move_left")
			Input.action_release("move_right")
			check(carried,id+" transport docks onto destination terrace")
			if not carried: print("FERRY POSITION ",p.position," TARGET ",destination," FERRY ",ferry.position)
		game.queue_free()
		await get_tree().process_frame
	print("TRANSPORT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)
