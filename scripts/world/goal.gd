class_name Goal
extends Area2D
## Meta del nivel. Al tocarla el jugador, completa el nivel.

signal reached

var _done := false

static func create(pos: Vector2) -> Goal:
	var g := Goal.new()
	g.position = pos
	g.collision_layer = 0
	g.collision_mask = 2
	g.monitoring = true
	g.monitorable = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(24, 64)
	cs.shape = r
	cs.position = Vector2(6, -32)
	g.add_child(cs)
	return g

func _ready() -> void:
	area_entered.connect(_on_area)

func _draw() -> void:
	draw_rect(Rect2(-2, -64, 4, 64), Color("c8d0e0"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, -62), Vector2(2, -42), Vector2(28, -52)
	]), Color("57d16a"))
	draw_rect(Rect2(-12, -6, 24, 6), Color("454c73"))

func _on_area(area: Area2D) -> void:
	if _done:
		return
	var p := area.get_parent()
	if p and p.is_in_group("player"):
		_done = true
		reached.emit()
