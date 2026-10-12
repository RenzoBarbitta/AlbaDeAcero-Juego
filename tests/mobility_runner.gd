extends Node
var failures := 0
var checks := 0
func _ready() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("MOBILITY FAIL: "+label)
func run() -> void:
	GameManager.campaign_path = "res://tests/mobility_temp.cfg"
	GameManager.coop = false
	GameManager.horde_mode = false
	GameManager.mobility = ["double_jump","jetpack"]
	GameManager.skip_menu = true
	var game := preload("res://scenes/main/Main.tscn").instantiate()
	add_child(game)
	var p: Player = game.players[0]
	for e in get_tree().get_nodes_in_group("enemy"): e.set_physics_process(false)
	p._invuln = 999
	for i in 8: await get_tree().physics_frame
	Input.action_press("jump")
	for i in 8: await get_tree().physics_frame
	Input.action_release("jump")
	for i in 3: await get_tree().physics_frame
	var before := p.position.y
	Input.action_press("jump")
	for i in 3: await get_tree().physics_frame
	check(p.air_jumps==1 and p.velocity.y< -200 and p.position.y<before,"second press launches double jump")
	for i in 60: await get_tree().physics_frame
	check(p.jet_fuel<0.95 and p.jet_active,"holding jump consumes fuel and engages jetpack")
	Input.action_release("jump")
	for i in 220:
		await get_tree().physics_frame
		if p.is_on_floor() and p.jet_fuel>=1: break
	check(p.is_on_floor() and p.jet_fuel>=1 and p.air_jumps==0,"landing refills fuel and restores air jump")
	GameManager.mobility.clear()
	p.bonus_mobility.clear()
	check(not p.has_mobility("jetpack") and not p.has_mobility("double_jump"),"locked mobility remains unavailable")
	p.bonus_mobility.append("double_jump")
	check(p.has_mobility("double_jump") and not GameManager.mobility.has("double_jump"),"shop upgrade is temporary and personal")
	print("MOBILITY: %d checks, %d failures" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)
