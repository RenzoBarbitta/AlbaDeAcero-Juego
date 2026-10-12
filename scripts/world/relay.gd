extends StaticBody2D
signal disabled
var lit := true
var color := Color("59d0ff")
var t := 0.0
var pulse_shield := false
var _blocked_flash := 0.0
const PT := preload("res://scripts/ui/pixel_text.gd")

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 9
	cs.shape = shape
	add_child(cs)

func _process(delta: float) -> void:
	t += delta
	_blocked_flash = maxf(0,_blocked_flash-delta)
	queue_redraw()

func take_damage(_amount: int, _from: Vector2) -> bool:
	if not lit:
		return false
	if pulse_shield and fposmod(t,3.0) < 1.5:
		_blocked_flash = 0.3
		GameManager.toast("RELE PROTEGIDO: ESPERA LA LUZ VERDE", color)
		return false
	lit = false
	set_deferred("collision_layer",0)
	disabled.emit()
	GameManager.toast("RELE DESACTIVADO", color)
	AudioManager.play("select", -10)
	return true

func status_label() -> String:
	if not lit:
		return "OK"
	if pulse_shield and fposmod(t,3.0) < 1.5:
		return "ESPERA"
	return "DISPARA"

func _draw() -> void:
	var label := status_label()
	var c := Color("57d16a") if not lit or label == "OK" else (Color("ff5a5a") if label != "DISPARA" and not label.ends_with("DISPARA") else Color("73f7ff"))
	if _blocked_flash > 0:
		c = Color.WHITE
	draw_rect(Rect2(-10,-10,20,20),Color("091425"))
	draw_rect(Rect2(-9,-9,18,18),c,false,1)
	draw_circle(Vector2.ZERO,5,c)
	draw_circle(Vector2.ZERO,2,Color.WHITE)
	if pulse_shield and lit and fposmod(t,3.0) < 1.5:
		draw_arc(Vector2.ZERO,13,0,TAU,16,Color("ff5a5a"),2)
	var w := float(PT.width(label))+8
	draw_rect(Rect2(-w*0.5,-26,w,14),Color(0.03,0.07,0.12,0.92))
	PT.draw_box(self,label,Rect2(-w*0.5,-26,w,14),c)
