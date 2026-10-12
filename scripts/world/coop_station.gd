extends Node2D
signal completed
var kind := 0
var players: Array = []
var stage: Node2D
var plate_owner := -1
var solved := false
var progress := 0.0
var wave := 0
var enemies: Array = []
var pads := [Vector2(120,150),Vector2(390,86)]
var gate: StaticBody2D
var t := 0.0
var _intro_shown := false
const PT := preload("res://scripts/ui/pixel_text.gd")
const COLORS := [Color("59d0ff"),Color("ffb15c")]

func _ready() -> void:
	gate = StaticBody2D.new()
	gate.position = Vector2(650,-700)
	gate.collision_layer = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12,896)
	cs.shape = shape
	cs.position = Vector2(6,448)
	gate.add_child(cs)
	add_child(gate)
	if kind == 1:
		var relay := preload("res://scripts/world/coop_switch.gd").new()
		relay.station = self
		relay.position = pads[1]+Vector2(36,-18)
		relay.disabled.connect(finish)
		add_child(relay)

func occupants(pad: Vector2) -> Array[int]:
	var ids: Array[int] = []
	for p in players:
		if is_instance_valid(p) and p.alive and absf(p.global_position.x-global_position.x-pad.x) < 24 and absf(p.global_position.y-global_position.y-pad.y) < 10:
			ids.append(p.index)
	return ids

func pair_present() -> bool:
	for a in occupants(pads[0]):
		for b in occupants(pads[1]):
			if a != b:
				return true
	return false

func _physics_process(delta: float) -> void:
	t += delta
	if not _intro_shown:
		for p in players:
			if p.alive and absf(p.global_position.x-global_position.x-330) < 300:
				_intro_shown = true
				var hints := ["DOS JUGADORES EN DOS PLACAS","UNO SOSTIENE LA PLACA, EL OTRO DISPARA AL RELE","CARGUEN LAS PLACAS Y ELIMINEN TRES OLEADAS"]
				GameManager.toast(hints[kind],Color("73f7ff"))
				break
	var ids := occupants(pads[0])
	plate_owner = -1 if ids.is_empty() else ids[0]
	if not solved:
		if kind == 0:
			progress = minf(1.0,progress+delta/1.2) if pair_present() else maxf(0,progress-delta)
			if progress >= 1:
				finish()
		elif kind == 2:
			if pair_present():
				progress = minf(1.0,progress+delta/3.0)
			if progress >= 1 and wave < 3 and living_enemies() == 0:
				spawn_wave()
				progress = 0
			elif wave == 3 and living_enemies() == 0 and pair_present():
				finish()
	queue_redraw()

func living_enemies() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			n += 1
	return n

func spawn_wave() -> void:
	wave += 1
	GameManager.toast("DEFENSA EN EQUIPO - OLEADA %d/3" % wave,Color("59d0ff"))
	for i in 3:
		var spawn: Vector2 = pads[i%2]+Vector2(0,-50 if i==0 else 0)
		stage._spawn_enemy("orbiter" if i == 0 else ("stalker" if wave > 1 else "walker"),global_position.x+spawn.x,spawn.y)
		enemies.append(stage.get_child(stage.get_child_count()-1))

func finish() -> void:
	if solved:
		return
	solved = true
	progress = 1
	gate.queue_free()
	GameManager.team_energy = minf(100,GameManager.team_energy+25)
	GameManager.toast("OBJETIVO EN EQUIPO COMPLETADO",Color("63ffc3"))
	GameManager.add_score(600)
	AudioManager.play("life",-10)
	completed.emit()

func _draw() -> void:
	for i in (1 if kind == 1 else 2):
		var active := not occupants(pads[i]).is_empty()
		var col: Color = COLORS[i]
		draw_rect(Rect2(pads[i]-Vector2(24,3),Vector2(48,3)),col if active or solved else col.darkened(0.6))
		draw_arc(pads[i]-Vector2(0,12),26,PI,TAU,16,Color(col,0.4 if active else 0.12),1)
		PT.draw(self,"PLACA %d" % (i+1),pads[i]-Vector2(18,-8),col)
	if not solved:
		draw_rect(Rect2(650,-700,12,896),Color(0.3,0.8,1,0.4))
	draw_rect(Rect2(40,65,120,3),Color("152d40"))
	draw_rect(Rect2(40,65,120*progress,3),Color("63ffc3"))
	if kind == 2:
		PT.draw(self,"OLEADAS %d/3" % wave,Vector2(168,65),Color("ffd45a"))
