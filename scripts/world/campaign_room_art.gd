extends Node2D
var room: Dictionary
var zone := "ciudad"
var players: Array = []
var _announced := false

func _ready() -> void:
	z_index = -4

func _physics_process(_delta: float) -> void:
	if _announced or GameManager.state!=GameManager.State.PLAYING: return
	for p in players:
		if p.alive and p.global_position.x>=global_position.x and p.global_position.x<global_position.x+float(room["span"]):
			_announced = true
			GameManager.toast(room["title"],preload("res://scripts/world/stage_themes.gd").get_theme(zone)["accent"])
			return

func _draw() -> void:
	var accent: Color = preload("res://scripts/world/stage_themes.gd").get_theme(zone)["accent"]
	for d in room["decks"]:
		var x := float(d[0])-float(d[2])*0.5
		var y := float(d[1])+17
		var width := float(d[2])
		var height := maxf(24,196-y)
		match zone:
			"fundicion":
				for bx in [x+12,x+width-18]:
					draw_rect(Rect2(bx,y,8,height),Color("3d3038"))
					for by in range(int(y)+16,190,32): draw_line(Vector2(bx,by),Vector2(bx+28,by+24),Color("6b4940"),2)
				draw_rect(Rect2(x+8,y,width-16,8),Color("654738"))
			"ruinas":
				for bx in range(int(x)+14,int(x+width)-12,70):
					draw_rect(Rect2(bx,y,18,height),Color("3d4651"))
					draw_arc(Vector2(bx+43,y+40),27,PI,TAU,16,Color("59616a"),10)
					for by in range(int(y)+10,190,28): draw_line(Vector2(bx,by),Vector2(bx+18,by),Color("657074"),1)
			"glaciar":
				draw_colored_polygon(PackedVector2Array([Vector2(x,y),Vector2(x+width,y),Vector2(x+width*0.76,y+36),Vector2(x+width*0.5,y+80),Vector2(x+width*0.25,y+28)]),Color("345c71"))
				draw_line(Vector2(x+width*0.5,y),Vector2(x+width*0.5,y+74),Color("5c9bab"),2)
			"volcan":
				draw_colored_polygon(PackedVector2Array([Vector2(x,y),Vector2(x+width,y),Vector2(x+width-18,196),Vector2(x+12,196)]),Color("342634"))
				for bx in range(int(x)+16,int(x+width)-8,34): draw_line(Vector2(bx,y+8),Vector2(bx-8,190),Color("63332e"),2)
			"central":
				draw_rect(Rect2(x+20,y,width-40,22),Color("243b52"))
				for bx in range(int(x)+30,int(x+width)-20,36):
					draw_circle(Vector2(bx,y+11),5,Color("3e6677"))
					draw_line(Vector2(bx,y+24),Vector2(bx,196),Color("1d3045"),3)
			"cantera":
				draw_colored_polygon(PackedVector2Array([Vector2(x,y),Vector2(x+width,y),Vector2(x+width+22,196),Vector2(x-12,196)]),Color("3b3443"))
				for by in range(int(y)+18,196,26): draw_line(Vector2(x+3,by),Vector2(x+width-3,by+8),Color("5c4b57"),3)
			"ciudad":
				draw_rect(Rect2(x+10,y,width-20,height),Color("152b43"))
				for by in range(int(y)+14,190,27):
					for bx in range(int(x)+24,int(x+width)-18,28): draw_rect(Rect2(bx,by,8,11),Color("3d5969"))
				draw_line(Vector2(x+width-16,y),Vector2(x+width-16,196),Color("527384"),2)
			"biolab":
				var mid := x+width*0.5
				draw_line(Vector2(mid,y+10),Vector2(mid+18,196),Color("244c3d"),20)
				draw_arc(Vector2(mid,y-2),width*0.4,0,PI,24,Color("3c6745"),8)
				for by in range(int(y)+34,190,42):
					draw_colored_polygon(PackedVector2Array([Vector2(mid,by),Vector2(mid-34,by-19),Vector2(mid-26,by+6)]),Color("346443"))
