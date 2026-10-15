extends Node2D
## Authored environmental machinery and animated natural landmarks. No collision or text.
var zone := "fundicion"
var span := 1400.0
var act := 0
var decks: Array = []
var clock := 0.0
var _points: Array[Vector2] = []
func _ready() -> void:
	z_index = -5
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(zone)+act*157
	for i in 14: _points.append(Vector2(rng.randf_range(20,span-20),rng.randf_range(-160,120)))
func _process(delta: float) -> void:
	clock += delta
	var cam := get_viewport().get_camera_2d()
	if cam:
		var range_x := 220.0/maxf(0.15,cam.zoom.x)
		visible = cam.global_position.x>=global_position.x-range_x and cam.global_position.x<=global_position.x+span+range_x
	if visible: queue_redraw()
func gear(at: Vector2,radius: float,speed: float) -> void:
	draw_arc(at,radius,0,TAU,32,Color("3a424b"),6)
	for i in 10:
		var ray := Vector2.RIGHT.rotated(clock*speed+i*TAU/10)
		draw_line(at+ray*(radius-5),at+ray*(radius+5),Color("69706b"),5)
		if i%2==0: draw_line(at+ray*8,at+ray*(radius-7),Color("3b5157"),4)
	draw_circle(at,9,Color("7c715f"))
func _draw() -> void:
	var anchor := Vector2(span*0.5,20)
	if not decks.is_empty(): anchor.y = float(decks[floori(float(decks.size())/2)][1])-35
	match zone:
		"fundicion":
			gear(anchor+Vector2(-45,-12),37,0.28)
			gear(anchor+Vector2(35,24),26,-0.4)
			draw_rect(Rect2(anchor+Vector2(-130,-110),Vector2(260,9)),Color("485058"))
			for x in [-120,-40,40,120]:
				draw_line(anchor+Vector2(x,-102),anchor+Vector2(x+40,-80),Color("6d5847"),2)
			var hook := anchor+Vector2(82+sin(clock*0.2)*28,-35)
			draw_line(Vector2(hook.x,anchor.y-100),hook,Color("8c9695"),2)
			draw_arc(hook+Vector2(0,7),8,0,PI*1.5,12,Color("b79d6d"),3)
			for p in _points:
				draw_rect(Rect2(p,Vector2(17,28)),Color("393939"))
				draw_rect(Rect2(p+Vector2(4,4),Vector2(9,16)),Color("a45830"))
		"ruinas":
			for i in 3:
				var x := anchor.x-95+i*90
				draw_arc(Vector2(x,anchor.y-30),30,PI,TAU,24,Color("65716a"),7)
				draw_rect(Rect2(x-30,anchor.y-28,7,100),Color("3e504d"))
				draw_rect(Rect2(x+24,anchor.y-28,7,100),Color("3e504d"))
				for j in 5:
					draw_line(Vector2(x-18+j*9,anchor.y-42),Vector2(x-20+j*10,anchor.y+25),Color("4b636b"),3)
			for p in _points:
				draw_line(p,p+Vector2(sin(clock*0.6+p.x)*5,20),Color("526752"),2)
				draw_circle(p+Vector2(2,4),3,Color("718261"))
		"glaciar":
			for p in _points:
				var height := 22+fposmod(p.x,25)
				var crystal := PackedVector2Array([p+Vector2(-12,20),p+Vector2(-5,-height),p+Vector2(5,-height-8),p+Vector2(13,16)])
				draw_colored_polygon(crystal,Color("3b697b"))
				draw_line(p+Vector2(-5,-height),p+Vector2(-1,14),Color("86cbd2"),2)
			for i in 3:
				draw_arc(anchor+Vector2(0,i*14),52+i*20,0.1,PI-0.1,24,Color(0.5,0.8,0.9,0.15),2)
		"volcan":
			for p in _points:
				var crack := PackedVector2Array([p,p+Vector2(12,18),p+Vector2(4,34),p+Vector2(17,50)])
				draw_polyline(crack,Color("4f3037"),7)
				draw_polyline(crack,Color(0.85,0.3+sin(clock+p.x)*0.05,0.13,0.55),2)
			for i in 9:
				var p := anchor+Vector2(sin(clock*0.3+i)*75,-fposmod(clock*12+i*23,150))
				draw_circle(p,1+i%2,Color("cb7043",0.55))
		"central":
			for side in [-1,1]:
				var at := anchor+Vector2(side*88,-24)
				draw_rect(Rect2(at-Vector2(16,55),Vector2(32,110)),Color("253f50"))
				for i in 8:
					draw_rect(Rect2(at+Vector2(-19,-48+i*13),Vector2(38,5)),Color("537482"))
				var wire := PackedVector2Array([at,anchor+Vector2(side*44,20),anchor+Vector2(0,-30)])
				draw_polyline(wire,Color("416c78"),3)
				draw_circle(at,7,Color("76c6c4"))
			gear(anchor+Vector2(0,-30),35,-0.2)
		"cantera":
			draw_line(anchor+Vector2(-120,-95),anchor+Vector2(125,-95),Color("6c6264"),4)
			for i in 3:
				var at := anchor+Vector2(-95+i*95,-75)
				gear(at,12,0.4)
				var length := 62+sin(clock*0.35+i)*16
				draw_line(at,at+Vector2(0,length),Color("8f8a78"),2)
				draw_colored_polygon(PackedVector2Array([at+Vector2(-17,length),at+Vector2(17,length),at+Vector2(11,length+18),at+Vector2(-11,length+18)]),Color("69544a"))
			for p in _points: draw_circle(p,3,Color("a083b4"))
		"ciudad":
			for i in 4:
				var at := anchor+Vector2(-130+i*90,-30-i%2*25)
				draw_rect(Rect2(at,Vector2(44,32)),Color("152e42"))
				draw_rect(Rect2(at+Vector2(3,3),Vector2(38,26)),Color("285e71"),false,2)
				draw_line(at+Vector2(7,23),at+Vector2(17,11),Color("5cb2b9"),2)
				draw_line(at+Vector2(17,11),at+Vector2(32,20),Color("5cb2b9"),2)
				draw_line(at+Vector2(22,32),at+Vector2(22,55),Color("354b5e"),4)
			for p in _points:
				var drop := Vector2(p.x,p.y+fposmod(clock*90+p.x,50))
				draw_line(drop,drop+Vector2(-2,7),Color(0.6,0.8,0.9,0.25),1)
		"biolab":
			for p in _points:
				var sway := sin(clock*1.4+p.x)*5
				var stem := PackedVector2Array([p+Vector2(0,40),p+Vector2(-5,10),p+Vector2(sway,-10)])
				draw_polyline(stem,Color("3d6851"),4)
				draw_circle(p+Vector2(sway,-10),8,Color("264940"))
				draw_circle(p+Vector2(sway,-10),4,Color(0.45,0.8,0.58,0.5+sin(clock*2+p.x)*0.2))
				for side in [-1,1]:
					draw_colored_polygon(PackedVector2Array([p+Vector2(0,15),p+Vector2(side*20,3),p+Vector2(side*12,21)]),Color("38604c"))
