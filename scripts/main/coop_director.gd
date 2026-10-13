extends Node2D
var players: Array = []
var game: Node2D
var rescue := [0.0,0.0,0.0,0.0]
var _all_down := false
var _last_kills := 0
const PT := preload("res://scripts/ui/pixel_text.gd")
const FX := preload("res://scripts/fx/fx.gd")

func _physics_process(delta: float) -> void:
	if players.is_empty() or GameManager.state != GameManager.State.PLAYING: return
	var living: Array = players.filter(func(p): return p.alive and p.network_active)
	if living.is_empty() and not _all_down:
		_all_down = true
		if GameManager.team_retries <= 0:
			GameManager.trigger_game_over()
			return
		GameManager.team_retries -= 1
		for p in players:
			if p.network_active: p.respawn_at(game.level.respawn_position()+Vector2(p.index*28,0))
		_all_down = false
	for i in players.size():
		var down: Player = players[i]
		if not down.network_active: continue
		if down.alive:
			rescue[i] = 0
			continue
		var helper: Player = null
		for ally in living:
			if down.global_position.distance_to(ally.global_position)<44 and ally.pressed("interact"):
				helper = ally
				break
		if helper:
			rescue[i] += delta*(2 if helper.character=="mint" else 1)
			if rescue[i]>=1.5:
				down.respawn_at(helper.global_position+Vector2(-helper.facing*20,0))
				GameManager.set_player_health(i,14)
				rescue[i] = 0
				GameManager.toast("COMPANERO RESCATADO",Color("63ffc3"))
		else: rescue[i] = maxf(0,rescue[i]-delta)
	if living.size()>=2:
		for i in range(1,living.size()):
			if living[0].global_position.distance_to(living[i].global_position)<130:
				GameManager.team_energy = minf(100,GameManager.team_energy+delta*2.5)
				break
	if GameManager.kills>_last_kills:
		GameManager.team_energy = minf(100,GameManager.team_energy+(GameManager.kills-_last_kills)*6)
	_last_kills = GameManager.kills
	for p in living:
		if p.pressed_once("team_attack") and GameManager.team_energy>=100:
			team_attack()
			break
	queue_redraw()

func team_attack() -> void:
	if players.is_empty() or GameManager.team_energy < 100:
		return
	GameManager.team_energy = 0
	var center := Vector2.ZERO
	var count := 0
	for p in players:
		if p.alive:
			center += p.global_position
			count += 1
	center /= maxf(1,count)
	for p in players:
		if not p.alive: continue
		p._invuln = maxf(p._invuln,1.2)
		FX.ring(get_parent(),p.global_position+Vector2(0,-14),Color("73f7ff"),8,160,0.6)
		GameManager.heal_player(p.index,4)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.dead and center.distance_to(e.global_position) < 260:
			if e.has_method("take_team_damage"):
				e.take_team_damage(28,center)
			else:
				e.take_damage(28,center)
	GameManager.shake(5)
	GameManager.banner("FUSION DE EQUIPO","DESCARGA CONJUNTA",Color("73f7ff"))
	AudioManager.play("charged",-6)

func _draw() -> void:
	if players.size() < 2:
		return
	for i in players.size():
		for j in range(i+1,players.size()):
			var a: Player = players[i]
			var b: Player = players[j]
			if a.alive and b.alive and a.global_position.distance_to(b.global_position)<130:
				draw_line(a.global_position+Vector2(0,-12),b.global_position+Vector2(0,-12),Color(0.4,0.9,1,0.15+GameManager.team_energy/300),1)
	for i in players.size():
		var p: Player = players[i]
		if not p.alive:
			var at: Vector2 = p.global_position
			draw_circle(at+Vector2(0,-10),12,Color(0.3,0.8,1,0.16))
			draw_line(at+Vector2(-5,-10),at+Vector2(5,-10),Color("73f7ff"),2)
			draw_line(at+Vector2(0,-15),at+Vector2(0,-5),Color("73f7ff"),2)
			PT.draw(self,"E RESCATA",at+Vector2(-23,-28),Color("73f7ff"))
			draw_rect(Rect2(at+Vector2(-14,5),Vector2(28*rescue[i]/1.5,2)),Color("63ffc3"))
