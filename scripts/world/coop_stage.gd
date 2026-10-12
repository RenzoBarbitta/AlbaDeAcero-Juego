extends "res://scripts/world/stage.gd"
## Campana de dos carriles y objetivos sincronizados, independiente de solo.
var stations: Array = []

func _build_body() -> void:
	for i in 6:
		_chunk_index = i*3
		if i%2==0:
			_cursor += preload("res://scripts/world/district_layout.gd").build(self,_cursor,floori(float(i)/2))
		_cursor += _ck_checkpoint(_cursor)
		if i % 2 == 0:
			_cursor += _ck_sector(_cursor,floori(float(i)/2.0))
		var station := preload("res://scripts/world/coop_station.gd").new()
		var layouts := [
			[Vector2(120,70),Vector2(390,-90)],
			[Vector2(210,-130),Vector2(510,30)],
			[Vector2(160,-50),Vector2(450,-210)],
			[Vector2(340,-170),Vector2(180,30)],
			[Vector2(240,-250),Vector2(500,-90)],
			[Vector2(140,30),Vector2(480,-130)]
		]
		station.pads = layouts[i]
		_ground(_cursor,96)
		_ground(_cursor+624,96)
		var route := [Vector2(32,150),station.pads[0],station.pads[1],Vector2(680,150)]
		for at in preload("res://scripts/world/route_geometry.gd").points(route,64):
			_architecture(_cursor+at.x-48,at.y,96,16)
		station.position = Vector2(_cursor,0)
		station.players = _players
		station.stage = self
		station.kind = (i+GameManager.BOSS_ORDER.find(GameManager.selected_boss))%3
		add_child(station)
		stations.append(station)
		_art.landmarks.append({"pos":Vector2(_cursor+220,0),"title":"OPERACION DUAL / %02d" % (i+1),"sub":"CARRIL SUPERIOR + COBERTURA"})
		if station.kind != 2:
			_spawn_ground(_cursor+station.pads[1].x,station.pads[1].y)
			_spawn_ground(_cursor+station.pads[0].x,station.pads[0].y)
			_spawn_air(_cursor+340,minf(station.pads[0].y,station.pads[1].y)-60)
		_pickup("health",_cursor+675,134)
		_pickup("rare",_cursor+station.pads[1].x,station.pads[1].y-18)
		_cursor += 720
		_cursor += _ck_moving(_cursor) if i%2 == 0 else _ck_stairs(_cursor)

func _on_arena_trigger(body: Node) -> void:
	if _arena_locked or not body.is_in_group("player"):
		return
	# La entrada reúne a ambos: la compuerta nunca abandona al compañero.
	for p in _players:
		if not p.alive:
			GameManager.toast("RESCATA AL COMPANERO ANTES DEL JEFE",Color("59d0ff"))
			return
	for p in _players:
		if p.global_position.x < arena_x+16:
			p.global_position = Vector2(arena_x+44+p.index*28,GY)
			p.velocity = Vector2.ZERO
	super._on_arena_trigger(body)
	if boss:
		boss.max_health = int(boss.max_health*1.65)
		boss.health = boss.max_health
		GameManager.boss_health_changed.emit(boss.health,boss.max_health,true)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _arena_locked:
		for p in _players:
			if p.alive and p.global_position.x >= arena_x+30:
				_on_arena_trigger(p)
				break
	elif _boss_down and goal:
		var both_at_exit := true
		for p in _players:
			if not p.alive or p.global_position.distance_to(goal.global_position) > 64:
				both_at_exit = false
		if both_at_exit:
			_on_goal_reached()

func _on_goal_reached() -> void:
	for p in _players:
		if not p.alive or p.global_position.distance_to(goal.global_position) > 64:
			GameManager.toast("REUNAN A AMBOS PILOTOS EN LA SALIDA",Color("73f7ff"))
			return
	if GameManager.state == GameManager.State.PLAYING:
		super._on_goal_reached()
