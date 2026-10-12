extends Node2D
var landmarks: Array = []
var color := Color("59d0ff")
var zone := "ciudad"
var t := 0.0

func _ready() -> void:
	z_index = -3

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var cx := cam.global_position.x if cam else 0.0
	for item in landmarks:
		var p: Vector2 = item["pos"]
		if absf(p.x - cx) > 650:
			continue
		var dark := color.darkened(0.8)
		draw_rect(Rect2(p.x,-200,12,350),dark)
		draw_rect(Rect2(p.x+220,-180,10,330),dark)
		for y in range(-160,140,40):
			draw_line(Vector2(p.x+12,y),Vector2(p.x+220,y-40),Color(dark,0.7),3)
		if zone in ["fundicion","volcan"]:
			for k in 4:
				draw_rect(Rect2(p.x+28+k*42,110,22,34),dark)
				draw_rect(Rect2(p.x+30+k*42,112,18,2),color)
		elif zone == "biolab":
			for k in 4:
				draw_rect(Rect2(p.x+30+k*40,70,22,76),dark)
				draw_circle(Vector2(p.x+41+k*40,104+sin(t+k)*8),7,Color(color,0.45))
		elif zone == "glaciar":
			for k in 5:
				draw_colored_polygon(PackedVector2Array([Vector2(p.x+k*44,150),Vector2(p.x+18+k*44,82),Vector2(p.x+32+k*44,150)]),dark.lightened(0.06))
		else:
			for k in 5:
				draw_rect(Rect2(p.x+24+k*38,92,26,54),dark)
				draw_rect(Rect2(p.x+28+k*38,98,18,10),Color(color,0.2+sin(t+k)*0.1))
