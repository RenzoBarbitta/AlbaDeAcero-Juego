extends Node2D
## Decoración de fondo dibujada por código (no colisiona). El origen es el punto
## de apoyo en el suelo. Tipos: lamp, crystal, rock, shroom, pipe, sign, pillar, cactus.

var kind := "rock"
var col := Color("59d0ff")
var variant := 0
var _t := 0.0

static func create(kind_: String, pos: Vector2, col_: Color, variant_: int = 0) -> Node2D:
	var d: Node2D = load("res://scripts/world/decor.gd").new()
	d.kind = kind_
	d.col = col_
	d.variant = variant_
	d.position = pos
	d.z_index = -2
	return d

func _process(delta: float) -> void:
	_t += delta
	if kind == "lamp" or kind == "shroom" or kind == "crystal":
		queue_redraw()

func _draw() -> void:
	var dark := Color("0a0a14")
	var metal := Color("454c73")
	var light := Color("7d86a8")
	match kind:
		"lamp":
			draw_rect(Rect2(-1, -34, 3, 34), dark)
			draw_rect(Rect2(0, -34, 1, 34), metal)
			draw_rect(Rect2(-5, -37, 11, 4), dark)
			draw_rect(Rect2(-4, -36, 9, 2), col)
			var g := 0.16 + 0.05 * sin(_t * 3.0 + float(variant))
			draw_circle(Vector2(0, -33), 14.0, Color(col.r, col.g, col.b, g))
		"crystal":
			var h := 14 + variant % 3 * 6
			draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(-3, -h), Vector2(0, -h - 5), Vector2(3, -h + 2), Vector2(6, 0)]), Color(col.r, col.g, col.b, 0.85))
			draw_colored_polygon(PackedVector2Array([Vector2(0, -h - 5), Vector2(3, -h + 2), Vector2(6, 0), Vector2(1, 0)]), Color(col.r, col.g, col.b, 0.55).darkened(0.2))
			draw_line(Vector2(-2, -h), Vector2(-4, -3), Color(1, 1, 1, 0.55), 1.0)
		"rock":
			var w := 9 + variant % 3 * 3
			draw_colored_polygon(PackedVector2Array([Vector2(-w, 0), Vector2(-w + 3, -7), Vector2(-2, -11), Vector2(w - 3, -8), Vector2(w, 0)]), Color("2a2a3e"))
			draw_line(Vector2(-w + 3, -7), Vector2(-2, -11), Color("5a6070"), 1.0)
		"shroom":
			var sh := 10 + variant % 3 * 4
			draw_rect(Rect2(-1, -sh, 3, sh), Color("1c3a2a"))
			draw_circle(Vector2(0, -sh), 6.0, Color("163a28"))
			draw_circle(Vector2(0, -sh), 6.0, Color(col.r, col.g, col.b, 0.18 + 0.1 * sin(_t * 2.5 + float(variant))))
			draw_rect(Rect2(-6, -sh, 13, 2), Color("0a0a14"))
			draw_rect(Rect2(-2, -sh - 3, 2, 2), col)
		"pipe":
			draw_rect(Rect2(-4, -26, 9, 26), dark)
			draw_rect(Rect2(-3, -26, 7, 26), metal)
			draw_rect(Rect2(-3, -26, 2, 26), light)
			draw_rect(Rect2(-6, -24, 13, 3), dark)
			draw_rect(Rect2(-5, -23, 11, 1), light)
			draw_circle(Vector2(0, -12), 2.0, col)
		"sign":
			draw_rect(Rect2(-1, -22, 3, 22), dark)
			draw_rect(Rect2(-9, -30, 19, 11), dark)
			draw_rect(Rect2(-8, -29, 17, 9), metal)
			draw_colored_polygon(PackedVector2Array([Vector2(-5, -27), Vector2(3, -27), Vector2(3, -30), Vector2(8, -25), Vector2(3, -20), Vector2(3, -23), Vector2(-5, -23)]), col)
		"pillar":
			draw_rect(Rect2(-6, -40, 13, 40), dark)
			draw_rect(Rect2(-5, -40, 11, 40), Color("3a3a56"))
			draw_rect(Rect2(-5, -40, 3, 40), Color("5a6070"))
			draw_rect(Rect2(-8, -43, 17, 4), dark)
			draw_rect(Rect2(-7, -42, 15, 2), light)
		"cactus":
			draw_rect(Rect2(-2, -22, 5, 22), Color("2a3a22"))
			draw_rect(Rect2(-7, -15, 5, 3), Color("2a3a22"))
			draw_rect(Rect2(-7, -19, 3, 6), Color("2a3a22"))
			draw_rect(Rect2(3, -12, 5, 3), Color("2a3a22"))
			draw_rect(Rect2(6, -17, 3, 7), Color("2a3a22"))
			draw_rect(Rect2(-2, -22, 1, 22), Color("4a5e38"))
