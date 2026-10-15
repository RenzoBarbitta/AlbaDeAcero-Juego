extends Node
func _ready() -> void: call_deferred("run")
func run() -> void:
	GameManager.campaign_path = "res://tests/network_budget.cfg"
	GameManager.coop = true
	GameManager.horde_mode = true
	GameManager.party_characters = ["orange","red","white","mint"]
	GameManager.skip_menu = true
	NetSession.online = true
	NetSession.host = true
	var game := preload("res://scenes/main/Main.tscn").instantiate()
	add_child(game)
	for i in 60:
		var e := preload("res://scripts/enemies/zone_enemy.gd").new()
		e.position = Vector2(40+i*14,140)
		game.level.add_child(e)
		e.set_physics_process(false)
	for i in 160:
		var b := Bullet.create(preload("res://assets/sprites/fx/bullet_player.png"),Vector2(40+i*5,90),Vector2.RIGHT,300,3,true)
		game.world.add_child(b)
		b.set_physics_process(false)
	var start := Time.get_ticks_usec()
	var data: Dictionary
	for i in 30: data = NetSession.world.snapshot()
	var usec := (Time.get_ticks_usec()-start)/30.0
	var raw := JSON.stringify({"type":"snapshot","data":data}).to_utf8_buffer()
	print("NET BUDGET entities=%d raw_bytes=%d compressed_bytes=%d wire_bytes=%d snapshot_usec=%.0f" % [data.entities.size(),raw.size(),raw.compress(FileAccess.COMPRESSION_ZSTD).size(),JSON.stringify(NetSession.encode_snapshot(data)).to_utf8_buffer().size(),usec])
	get_tree().quit()
