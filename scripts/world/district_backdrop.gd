extends Node2D
var zone := "ciudad"
var anchors: Array = []
var accent := Color("59d0ff")

func _ready() -> void:
	z_index = -5

func _draw() -> void:
	var dark := accent.darkened(0.91)
	var edge := accent.darkened(0.73)
	for i in range(1,anchors.size()-1,2):
		var at: Vector2 = anchors[i]
		var h := 190-at.y
		match zone:
			"fundicion":
				draw_rect(Rect2(at.x-22,at.y-30,44,h+30),dark)
				for y in range(int(at.y),180,32):
					draw_rect(Rect2(at.x-26,y,52,5),edge)
					draw_line(Vector2(at.x-18,y+6),Vector2(at.x+18,y+28),edge,2)
				for x in [-12,12]: draw_line(Vector2(at.x+x,at.y-24),Vector2(at.x+x,180),edge,3)
			"ruinas":
				draw_rect(Rect2(at.x-34,at.y+20,22,h-20),dark)
				draw_rect(Rect2(at.x+24,at.y+20,22,h-20),dark)
				draw_arc(at+Vector2(6,24),40,PI,TAU,24,edge,12)
				for y in range(int(at.y+55),180,40): draw_line(Vector2(at.x-34,y),Vector2(at.x-12,y),edge,2)
			"glaciar":
				draw_colored_polygon(PackedVector2Array([Vector2(at.x-68,196),at+Vector2(-26,30),at+Vector2(6,-48),at+Vector2(36,32),Vector2(at.x+80,196)]),dark.lightened(0.035))
				draw_line(at+Vector2(6,-48),Vector2(at.x+24,170),edge,2)
			"volcan":
				draw_colored_polygon(PackedVector2Array([Vector2(at.x-80,196),at+Vector2(-30,36),at+Vector2(12,10),Vector2(at.x+80,196)]),dark)
				for y in range(int(at.y+40),160,50): draw_line(Vector2(at.x-8,y),Vector2(at.x+15,y+28),edge,2)
			"central":
				draw_rect(Rect2(at.x-30,at.y+16,60,h-16),dark)
				for y in range(int(at.y+28),180,26):
					draw_line(Vector2(at.x-20,y),Vector2(at.x+20,y),edge,1)
					draw_circle(Vector2(at.x+20,y),3,edge)
			"cantera":
				draw_colored_polygon(PackedVector2Array([Vector2(at.x-90,196),at+Vector2(-55,40),at+Vector2(12,28),at+Vector2(60,60),Vector2(at.x+95,196)]),dark)
				for y in range(int(at.y+65),196,30): draw_line(Vector2(at.x-40,y),Vector2(at.x+50,y-8),edge,2)
			"ciudad":
				draw_rect(Rect2(at.x-38,at.y+18,76,h-18),dark)
				for y in range(int(at.y+40),175,24):
					for x in [-22,0,22]: draw_rect(Rect2(at.x+x,y,8,10),edge)
				draw_line(at+Vector2(-46,18),at+Vector2(46,18),edge,3)
			"biolab":
				draw_line(at+Vector2(0,18),Vector2(at.x,196),dark,28)
				for y in range(int(at.y+32),170,38):
					draw_arc(Vector2(at.x,y),24,0,PI,16,edge,4)
					draw_circle(Vector2(at.x-18,y),5,edge)
