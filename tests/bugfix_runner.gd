extends Node2D
const PT := preload("res://scripts/ui/pixel_text.gd")
const SHOT := preload("res://scripts/projectiles/bullet.gd")
const TEX := preload("res://assets/sprites/fx/bullet_player.png")
var checks := 0
var failures := 0
class Owner:
	extends Node2D
	var index := 0
class Station:
	extends Node2D
	var plate_owner := -1

func _ready() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+label)

func fire(target: Node2D,owner: Node2D) -> void:
	var b := SHOT.create(TEX,target.global_position-Vector2(40,0),Vector2.RIGHT,4000,3,true)
	b.origin = owner
	add_child(b)
	await get_tree().create_timer(0.08).timeout

func run() -> void:
	GameManager.campaign_path = "res://tests/bugfix_temp.cfg"
	GameManager.new_game()
	GameManager.state = GameManager.State.PLAYING
	GameManager.coop = false
	var owner := Owner.new()
	add_child(owner)
	var relay := preload("res://scripts/world/relay.gd").new()
	relay.position = Vector2(140,70)
	add_child(relay)
	await get_tree().physics_frame
	await fire(relay,owner)
	check(not relay.lit,"fast physical projectile activates solo relay")
	relay.queue_free()
	var shield := preload("res://scripts/world/relay.gd").new()
	shield.position = Vector2(140,100)
	shield.pulse_shield = true
	add_child(shield)
	await get_tree().physics_frame
	check(shield.status_label() == "ESPERA","shield never falsely says shoot")
	await fire(shield,owner)
	check(shield.lit and shield._blocked_flash > 0,"blocked shot gives visible feedback")
	shield.t = 1.6
	await fire(shield,owner)
	check(not shield.lit,"shield open accepts actual bullet")
	shield.queue_free()
	var station := Station.new()
	add_child(station)
	var duo := preload("res://scripts/world/coop_switch.gd").new()
	duo.station = station
	duo.position = Vector2(140,130)
	add_child(duo)
	await get_tree().physics_frame
	check(duo.status_label() == "ACTIVA PLACA","duo switch explains its prerequisite")
	await fire(duo,owner)
	check(duo.lit,"unoccupied plate blocks actual shot")
	station.plate_owner = 0
	check(duo.status_label() == "P2 DISPARA","duo switch identifies free shooter")
	await fire(duo,owner)
	check(duo.lit,"plate owner cannot self activate with bullet")
	owner.index = 1
	await fire(duo,owner)
	check(not duo.lit,"teammate bullet activates duo relay")
	duo.queue_free()
	var art := preload("res://scripts/player/pilot_visual.gd").new()
	for i in 120:
		art.t = float(i)*TAU/14.0/120.0
		var pose := art.leg_pose(true,false,false)
		check(pose["knee_a"].x < -3 and pose["knee_b"].x > 3,"knees remain separated")
		var back := Rect2(pose["foot_a"]+Vector2(-2,-2),Vector2(6,3))
		var front := Rect2(pose["foot_b"]+Vector2(-2,-2),Vector2(7,3))
		check(not back.intersects(front),"boots never cross through run cycle")
	art.free()
	for id in GameManager.BOSS_ORDER:
		for rect in [Rect2(0,0,132,16),Rect2(0,0,104,12)]:
			var layout := PT.fit_layout(GameManager.BOSSES[id]["name"],rect)
			var at: Vector2 = layout["position"]
			check(at.y-3 >= rect.position.y and at.y+8 <= rect.end.y,"boss name vertical bounds")
			check(PT.width(layout["text"])+3 <= rect.size.x,"boss name horizontal bounds")
	var game := preload("res://scenes/main/Main.tscn").instantiate()
	add_child(game)
	var overlay: Overlay = game.get_node("UI").get_child(2)
	await get_tree().process_frame
	# Real mouse events exercise menu coordinates, including its half scale.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(200,286)*overlay.scale
	overlay._unhandled_input(click)
	check(GameManager.coop and overlay._tab == 4,"mouse chooses duo card at scaled coordinates")
	await get_tree().process_frame
	check(overlay._online_panel.visible,"online room UI replaces local P2 menu")
	GameManager.coop = false
	GameManager.start_game()
	var player: Player = game.players[0]
	player.set_physics_process(false)
	player.weapon = "buster"
	player.aim = Vector2.RIGHT
	player._shoot_cooldown = 0
	var before := 0
	for child in game.world.get_children():
		if child is Bullet:
			before += 1
	Input.action_press("shoot")
	player._shoot_buster(1.0/60)
	var after := 0
	for child in game.world.get_children():
		if child is Bullet:
			after += 1
	check(after == before+1,"buster fires immediately on press")
	Input.action_release("shoot")
	player._shoot_buster(0)
	var puzzle = game.level.puzzles[0]
	puzzle.clock = 2
	var initial_values: Array = puzzle.values.duplicate()
	await fire(puzzle.terminals[0],owner)
	check(puzzle.values != initial_values,"authored puzzle terminal receives actual projectile")
	puzzle.set_physics_process(false)
	puzzle.clock = 2
	await get_tree().create_timer(0.25).timeout
	var terminal: Node2D = puzzle.terminals[0]
	player.global_position = terminal.global_position+Vector2(-12,18)
	player.facing = 1
	player.aim = Vector2.RIGHT
	player._shoot_cooldown = 0
	var value_before := int(puzzle.values[0])
	player._fire_buster()
	await get_tree().create_timer(0.08).timeout
	check(int(puzzle.values[0])==(value_before+1)%4,"point blank shot sweeps barrel before muzzle")
	check(terminal._response>0 and terminal._accepted,"terminal flashes on accepted shot")
	await get_tree().create_timer(0.25).timeout
	value_before = int(puzzle.values[0])
	player._fire_spread()
	await get_tree().create_timer(0.08).timeout
	check(int(puzzle.values[0])==(value_before+1)%4,"spread pellets change terminal only once")
	await get_tree().create_timer(0.25).timeout
	value_before = int(puzzle.values[0])
	var enemy_shot := SHOT.create(TEX,terminal.global_position-Vector2(40,0),Vector2.RIGHT,4000,3,false)
	add_child(enemy_shot)
	await get_tree().create_timer(0.08).timeout
	check(int(puzzle.values[0])==value_before,"enemy shots cannot alter puzzle controls")
	var other: Node2D = puzzle.terminals[1]
	player.global_position = other.global_position+Vector2(40,18)
	value_before = int(puzzle.values[1])
	Input.action_press("interact")
	other._physics_process(0.01)
	Input.action_release("interact")
	check(int(puzzle.values[1])==(value_before+1)%4,"E works within reachable interaction distance")
	game.queue_free()
	await get_tree().process_frame
	print("BUGFIX: %d checks, %d failures" % [checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
