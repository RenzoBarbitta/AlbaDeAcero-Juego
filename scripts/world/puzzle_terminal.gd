extends "res://scripts/world/relay.gd"
var puzzle: Node2D
var terminal_index := 0
var _activation_cooldown := 0.0
var _response := 0.0
var _accepted := false

func activate_control() -> bool:
	if _activation_cooldown > 0 or puzzle.solved:
		return false
	_activation_cooldown = 0.22
	_accepted = puzzle.activate(terminal_index)
	_response = 0.3
	queue_redraw()
	return _accepted

func status_label() -> String:
	if puzzle.has_method("terminal_label"): return puzzle.terminal_label(terminal_index)
	if puzzle.solved: return "OK"
	if puzzle.zone=="fundicion" and fposmod(puzzle.clock,4.0)<1.4:
		return "ESPERA FRIO"
	if puzzle.zone=="volcan" and int(puzzle.values[terminal_index])==0:
		return "VACIO"
	if puzzle.zone=="biolab" and puzzle.progress>0:
		return "DEFIENDE N3"
	return "E / DISPARA"

func receive_projectile(_amount: int,_at: Vector2,_shooter: int) -> bool:
	return activate_control()

func take_damage(_amount: int,_at: Vector2) -> bool:
	return activate_control()

func _physics_process(delta: float) -> void:
	_activation_cooldown = maxf(0,_activation_cooldown-delta)
	_response = maxf(0,_response-delta)
	if puzzle.solved:
		lit = false
	for p in get_tree().get_nodes_in_group("player"):
		if p.alive and p.global_position.distance_to(global_position+Vector2(0,18)) < 48 and p.pressed_once("interact"):
			activate_control()

func _draw() -> void:
	var label := status_label()
	var col := Color("63ffc3") if label=="OK" else (Color("73f7ff") if label.ends_with("DISPARA") else Color("ffb15c"))
	draw_rect(Rect2(-9,-9,18,18),Color("091425"))
	draw_rect(Rect2(-8,-8,16,16),col,false,1)
	draw_circle(Vector2.ZERO,4,col)
	draw_circle(Vector2.ZERO,1.5,Color.WHITE)
	if _response > 0:
		draw_arc(Vector2.ZERO,11+(0.3-_response)*18,0,TAU,24,Color("63ffc3") if _accepted else Color("ff655c"),2)
	draw_set_transform(Vector2(0,12),0,Vector2.ONE*0.5)
	var width := float(PT.width(label))+8
	draw_rect(Rect2(-width*0.5,0,width,14),Color("091425"))
	PT.draw_box(self,label,Rect2(-width*0.5,0,width,14),col)
	var value := str(int(puzzle.values[terminal_index]))
	if not puzzle.target.is_empty():
		value += " / " + str(int(puzzle.target[terminal_index]))
	elif puzzle.zone in ["ciudad","biolab"]:
		value = "PASO %d" % puzzle.step
	draw_set_transform(Vector2(12,-4),0,Vector2.ONE*0.5)
	var value_width := float(PT.width(value))+8
	draw_rect(Rect2(0,0,value_width,14),Color("091425"))
	PT.draw_box(self,value,Rect2(0,0,value_width,14),col)
