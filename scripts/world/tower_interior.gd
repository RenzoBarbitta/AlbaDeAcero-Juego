extends Node2D
var stage: Node2D
const PT := preload("res://scripts/ui/pixel_text.gd")
func _ready() -> void: z_index = -3
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	var c: Color = stage.theme["accent"]
	draw_rect(Rect2(0,-270,960,466),Color("0b1422"))
	for side in [0,560]:
		draw_rect(Rect2(side,-210,400,358),Color("15283b"))
		for x in range(side+24,side+390,76):
			draw_rect(Rect2(x,-170,52,190),Color("07111e"))
			for y in range(-150,15,28): draw_rect(Rect2(x+6,y,40,12),Color(c,0.12))
		for y in [-220,-10,148]: draw_line(Vector2(side,y),Vector2(side+400,y),Color("426075"),3)
		for x in range(side+8,side+395,110):
			draw_rect(Rect2(x,-240,8,390),Color("243c51"))
		match stage.theme_id:
			"ciudad":
				for x in range(side+40,side+360,96):
					draw_line(Vector2(x,146),Vector2(x,116),Color("45635b"),3)
					draw_circle(Vector2(x,112),13,Color("2c6251"))
			"fundicion","volcan","cantera":
				for x in range(side+32,side+350,112):
					draw_rect(Rect2(x,112,44,36),Color("344450"))
					draw_circle(Vector2(x+22,127),9,c.darkened(0.5))
			"biolab","glaciar":
				for x in range(side+32,side+350,112):
					draw_rect(Rect2(x,92,44,56),c.darkened(0.72))
					draw_arc(Vector2(x+22,115),16,0,TAU,20,c,3)
			"central","ruinas":
				for x in range(side+32,side+350,96):
					draw_rect(Rect2(x,80,42,68),Color("23364e"))
					for y in range(88,145,12): draw_line(Vector2(x+6,y),Vector2(x+34,y),c.darkened(0.2),2)
	# Elevator shaft: moving girders make ascent legible while the camera stays with the cabin.
	draw_rect(Rect2(400,-270,160,420),Color("050b13"))
	var shift: float = stage.lift_progress*980
	for y in range(-350,230,70):
		var at := fposmod(float(y)+shift+350,560)-350
		draw_line(Vector2(404,at),Vector2(556,at),Color("263647"),5)
		# luminarias del hueco bajan rapido durante el trayecto
		draw_rect(Rect2(410,at+10,8,18),Color(c,0.28))
		draw_rect(Rect2(542,at+10,8,18),Color(c,0.28))
	if stage.phase=="transit":
		for y in range(-250,170,46):
			var streak := fposmod(float(y)+shift*1.7+250,460)-250
			draw_line(Vector2(390,streak),Vector2(390,streak+24),Color("8fe7ff",0.35),2)
			draw_line(Vector2(570,streak-18),Vector2(570,streak+8),Color("8fe7ff",0.35),2)
	for x in [403,555]: draw_line(Vector2(x,-270),Vector2(x,150),Color("637481"),3)
	# Cabin with four visibly separate standing places; unused slots remain dark.
	draw_rect(Rect2(400,38,160,112),Color("263b4e"))
	draw_rect(Rect2(408,48,144,95),Color("142536"))
	for i in 4:
		var occupied: bool = stage.cabin_players.has(i)
		var tint := Color("63ffc3") if occupied else Color("526779")
		draw_rect(Rect2(414+i*36,54,24,4),tint)
		PT.draw_box(self,"P%d" % (i+1),Rect2(414+i*36,63,24,14),tint,1,PT.CENTER)
		draw_rect(Rect2(414+i*36,85,24,44),Color("203549"),false,1)
		for y in [93,102]: draw_line(Vector2(418+i*36,y),Vector2(434+i*36,y),Color("416275"),1)
		draw_line(Vector2(414+i*36,146),Vector2(438+i*36,146),tint,2)
	draw_rect(Rect2(397,34,166,8),Color("7c9bac"))
	for x in [397,557]: draw_rect(Rect2(x,42,6,110),Color("7c9bac"))
	draw_line(Vector2(400,150),Vector2(560,150),Color("8fe7db"),3)
