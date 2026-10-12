extends Node2D
## Relleno animado de los fosos (lava, ácido, agua, niebla). Solo decorativo:
## caer sigue siendo mortal (lo gestiona el constructor de etapa).

var rects: Array = []        # cada uno: Rect2(x, 0, ancho, 0)
var kind := "mist"
var fill_color := Color(0.4, 0.3, 0.8, 0.6)
var bottom_y := 196.0
var _t := 0.0

func _ready() -> void:
	z_index = -2

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var base_h := 16.0
	var dark := fill_color.darkened(0.35)
	var bright := fill_color.lightened(0.45)
	for r in rects:
		var rr: Rect2 = r
		var x0 := rr.position.x
		var x1 := rr.position.x + rr.size.x
		var x := x0
		while x < x1:
			var w := minf(2.0, x1 - x)
			var wave := 2.0 * sin((x + _t * 38.0) / 7.0) + 1.0 * sin((x - _t * 23.0) / 3.0)
			var h := base_h + wave
			draw_rect(Rect2(x, bottom_y - h, w, h), fill_color)
			draw_rect(Rect2(x, bottom_y - h, w, 1.0), bright)
			draw_rect(Rect2(x, bottom_y - h + 4.0, w, bottom_y - (bottom_y - h + 4.0)), dark if int(x / 2.0) % 3 == 0 else fill_color)
			x += 2.0
		# resplandor sobre la superficie
		if kind == "lava" or kind == "acid":
			for k in 4:
				var gx := x0 + fposmod(float(k) * (rr.size.x / 4.0) + _t * 6.0, rr.size.x)
				draw_circle(Vector2(gx, bottom_y - base_h - 3.0 - 2.0 * sin(_t * 3.0 + float(k))), 2.0, Color(bright.r, bright.g, bright.b, 0.5))
			draw_rect(Rect2(x0, bottom_y - base_h - 12.0, rr.size.x, 10.0), Color(fill_color.r, fill_color.g, fill_color.b, 0.10))
