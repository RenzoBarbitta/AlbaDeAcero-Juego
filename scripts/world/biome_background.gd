extends Node2D
var zone := "ciudad"
var scroll := 0.0
var clock := 0.0

func poly(points: Array,col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),col)

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	match zone:
		"fundicion":
			draw_rect(Rect2(0,0,320,180),Color("201622"))
			for i in 7:
				var x := fposmod(i*65-scroll*0.3,390)-35
				var top := 45.0+(i%3)*16
				draw_rect(Rect2(x,top,26,180-top),Color("39272c"))
				draw_rect(Rect2(x-5,top+40,36,8),Color("654235"))
				for j in 3: draw_rect(Rect2(x+5,top+58+j*20,16,3),Color("bf6336"))
				for j in 4:
					draw_circle(Vector2(x+12+sin(clock+i+j)*5,top-8-j*12),9+j*2,Color("352630"))
			draw_line(Vector2(0,139),Vector2(320,139),Color("805135"),5)
		"ruinas":
			draw_rect(Rect2(0,0,320,180),Color("18263a"))
			draw_circle(Vector2(238,38),26,Color("a09068"))
			poly([Vector2(0,110),Vector2(60,60),Vector2(130,112),Vector2(190,65),Vector2(265,105),Vector2(320,82),Vector2(320,180),Vector2(0,180)],Color("283848"))
			for i in 6:
				var x := fposmod(i*71-scroll*0.2,400)-40
				var top := 54+(i%3)*20
				draw_rect(Rect2(x,top,12,126-top),Color("455055"))
				draw_rect(Rect2(x+40,top,12,126-top),Color("455055"))
				draw_arc(Vector2(x+26,top+4),20,PI,TAU,16,Color("455055"),10)
				draw_rect(Rect2(x-3,top-5,18,5),Color("788273"))
				for j in 3: draw_line(Vector2(x+3,top+15+j*16),Vector2(x+9,top+15+j*16),Color("788273"),1)
		"glaciar":
			draw_rect(Rect2(0,0,320,180),Color("11263e"))
			for i in 4:
				var ribbon := PackedVector2Array()
				for x in range(-10,335,8): ribbon.append(Vector2(x,24+i*9+sin(x*0.018+clock*0.12+i)*14))
				draw_polyline(ribbon,Color(0.25,0.8,0.8,0.18),8)
			for i in 5:
				var x := fposmod(i*94-scroll*0.2,450)-65
				poly([Vector2(x-50,175),Vector2(x+35,40+(i%2)*20),Vector2(x+110,175)],Color("33566a"))
				poly([Vector2(x+11,80+(i%2)*20),Vector2(x+35,40+(i%2)*20),Vector2(x+61,86+(i%2)*20),Vector2(x+35,73+(i%2)*20)],Color("a9d5dc"))
			draw_rect(Rect2(0,154,320,26),Color("477182"))
		"volcan":
			draw_rect(Rect2(0,0,320,180),Color("2b1426"))
			draw_circle(Vector2(227,55),39,Color("683138"))
			poly([Vector2(20,180),Vector2(123,48),Vector2(165,48),Vector2(290,180)],Color("422536"))
			poly([Vector2(119,56),Vector2(132,44),Vector2(155,44),Vector2(172,60),Vector2(150,57),Vector2(143,73),Vector2(133,58)],Color("ee7942"))
			draw_polyline(PackedVector2Array([Vector2(142,64),Vector2(128,91),Vector2(158,116),Vector2(150,180)]),Color("b95039"),6)
			for i in 8:
				var x := fposmod(i*47-scroll*0.4,370)-20
				poly([Vector2(x,180),Vector2(x+12,118+(i%3)*13),Vector2(x+28,180)],Color("201626"))
		"central":
			draw_rect(Rect2(0,0,320,180),Color("111c34"))
			for i in 3:
				var x := fposmod(i*150-scroll*0.25,450)-50
				draw_circle(Vector2(x,92),62,Color("192c45"))
				for radius in [34,48,61]: draw_arc(Vector2(x,92),radius,clock*0.05,clock*0.05+TAU-0.4,48,Color("345576"),2)
				draw_circle(Vector2(x,92),18,Color("467b8b"))
				for j in 8:
					var ray := Vector2.RIGHT.rotated(j*TAU/8+clock*0.08)
					draw_line(Vector2(x,92)+ray*22,Vector2(x,92)+ray*31,Color("79bac0"),3)
		"cantera":
			draw_rect(Rect2(0,0,320,180),Color("211d32"))
			for i in 9:
				var x := fposmod(i*47-scroll*0.25,400)-35
				poly([Vector2(x,0),Vector2(x+45,0),Vector2(x+23,45+(i%3)*15)],Color("3d3349"))
				poly([Vector2(x-10,180),Vector2(x+12,95+(i%2)*20),Vector2(x+40,180)],Color("46364d"))
				if i%2==0:
					poly([Vector2(x+8,150),Vector2(x+14,117),Vector2(x+25,142),Vector2(x+20,156)],Color("8467a0"))
			draw_line(Vector2(0,68),Vector2(320,94),Color("77626a"),2)
		"biolab":
			draw_rect(Rect2(0,0,320,180),Color("102c2d"))
			for i in 7:
				var x := fposmod(i*66-scroll*0.2,400)-30
				draw_line(Vector2(x,180),Vector2(x+15,20),Color("1b4941"),14)
				for j in 3:
					var at := Vector2(x+10,28+j*38)
					poly([at,at+Vector2(-35,-20),at+Vector2(-24,5),at+Vector2(0,13)],Color("286153"))
					poly([at,at+Vector2(34,-12),at+Vector2(24,12)],Color("35705c"))
					draw_circle(at+Vector2(4,18),3,Color("8dbf77"))
		"ciudad":
			draw_rect(Rect2(0,0,320,180),Color("141d37"))
			draw_circle(Vector2(250,40),19,Color("bac9d0"))
			for i in 12:
				var x := fposmod(i*34-scroll*0.3,380)-30
				var top := 56+(i%4)*17
				draw_rect(Rect2(x,top,27,180-top),Color("28334c"))
				for y in range(top+7,180,12):
					for j in 2: draw_rect(Rect2(x+5+j*12,y,5,3),Color("798b9b"))
				draw_line(Vector2(x+13,top),Vector2(x+13,top-12),Color("3d5165"),1)
