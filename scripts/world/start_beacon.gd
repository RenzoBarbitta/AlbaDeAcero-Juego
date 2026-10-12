extends Node2D
var coop := false
var accent := Color("73f7ff")
const PT := preload("res://scripts/ui/pixel_text.gd")

func _ready() -> void:
	z_index = -2

func _draw() -> void:
	draw_rect(Rect2(32,151,160,3),accent.darkened(0.4))
	for x in range(40,190,16):
		draw_rect(Rect2(x,155,5,1),accent.darkened(0.55))
	draw_rect(Rect2(164,85,152,34),Color("091425"))
	draw_rect(Rect2(164,85,152,34),accent.darkened(0.5),false,1)
	draw_set_transform(Vector2(170,88),0,Vector2.ONE*0.5)
	PT.draw_box(self,"INSERCION DUAL" if coop else "ZONA SEGURA",Rect2(0,0,280,14),accent,1,PT.LEFT)
	PT.draw_box(self,"A/D MOVER - ESPACIO SALTAR",Rect2(0,19,280,14),Color("c6d8e8"),1,PT.LEFT)
	PT.draw_box(self,"P2: FLECHAS Y . / AVANCEN JUNTOS" if coop else "CLIC DISPARA - SHIFT DASH",Rect2(0,38,280,14),Color("91a9bf"),1,PT.LEFT)
