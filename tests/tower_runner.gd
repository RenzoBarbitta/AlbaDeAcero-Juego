extends Node
var failures := 0
var checks := 0
func _ready() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TOWER: "+label)
func run() -> void:
	GameManager.campaign_path = "res://tests/tower_temp.cfg"
	NetSession.disconnect_room()
	for count in range(1,5):
		GameManager.coop = true
		GameManager.horde_mode = true
		GameManager.party_characters = ["orange","mint","white","violet"].slice(0,count)
		GameManager.skip_menu = true
		var game := preload("res://scenes/main/Main.tscn").instantiate()
		add_child(game)
		var stage: Node2D = game.level
		stage.phase_time = 100
		stage.start_wave()
		check(stage.floor_number==1 and stage.wave==1,"first floor begins")
		stage.remaining = 0
		stage.boss_pending = false
		stage.finish_wave()
		stage.set_physics_process(false)
		game.players[0].position = Vector2(300,150)
		stage.mark_ready(0)
		check(not stage.ready_players.has(0) and not stage.begin_ascent(),"cannot leave a teammate outside")
		stage.phase_time = 0
		stage._update_boarding(0.1)
		check(stage.phase=="shop","timer never abandons outside teammate")
		game.players[0].position = Vector2(380,150)
		Input.action_press("move_right")
		for frame in 35: await get_tree().physics_frame
		Input.action_release("move_right")
		check(stage.in_cabin(game.players[0]),"player walks into cabin using real collision")
		stage.phase_time = 20
		for i in count:
			game.players[i].position = Vector2(426+i*36,150)
			stage.mark_ready(i)
		stage._update_boarding(0.1)
		check(stage.phase=="departing" and stage.cabin_players.size()==count,"departs with actual party, no empty-seat requirement")
		var money: Array = stage.wallets.duplicate()
		check(not stage.buy_upgrade(0,"damage"),"shopping blocked in motion")
		stage._update_lift(1.1)
		check(stage.phase=="transit","doors close before ascent")
		stage._update_lift(2)
		check(stage.lift_progress>0.4 and stage.floor_number==1,"ascent progress before arrival")
		stage._update_lift(2.1)
		check(stage.floor_number==2 and stage.wave==2 and stage.phase=="combat","arrives at new floor and starts next wave")
		check(stage.wallets==money,"credits persist through floor change")
		for p in game.players: check(p.is_physics_processing() and stage.in_cabin(p),"arrives alive in assigned slot")
		var layout_keys := {}
		for number in range(1,9):
			stage.configure_floor(number)
			layout_keys[str(stage.floor_decks.map(func(d): return d.position))] = true
		check(layout_keys.size()==8,"eight distinct floor layouts")
		if count==4:
			stage.phase = "shop"
			stage.disconnect_pilot(3)
			for p in stage.participating(): p.position = Vector2(426+p.index*36,150)
			check(stage.participating().size()==3 and stage.begin_ascent(),"departed player does not block remaining team")
			check(not game.players[3].visible and not game.players[3].network_active,"departed slot stays inactive")
		var replica := preload("res://scripts/world/horde_stage.gd").new()
		add_child(replica)
		replica.set_physics_process(false)
		replica.build(game.players)
		replica.set_physics_process(false)
		replica.apply_horde_snapshot(stage.horde_snapshot())
		check(replica.floor_number==stage.floor_number and replica.phase==stage.phase,"remote floor state matches")
		check(replica.floor_decks[0].position==stage.floor_decks[0].position,"remote floor collisions match")
		replica.queue_free()
		game.queue_free()
		await get_tree().process_frame
	print("TOWER: %d checks, %d failures" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)
