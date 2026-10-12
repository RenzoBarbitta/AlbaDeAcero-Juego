extends StaticBody2D
## Silhouette and support geometry belong to the zone, rather than a repeated tile strip.
var size := Vector2(96,16)
var zone := "ciudad"
var solid := false
var accent := Color("59d0ff")

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = size if solid else Vector2(size.x,4)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = shape.size*0.5
	cs.one_way_collision = not solid
	cs.one_way_collision_margin = 3
	add_child(cs)
	z_index = -1

func _draw() -> void:
	var dark := accent.darkened(0.82)
	var w := size.x
	if solid:
		draw_rect(Rect2(Vector2.ZERO,size),dark)
		for y in range(12,int(size.y),24):
			draw_line(Vector2(4,y),Vector2(w-4,y),accent.darkened(0.7),1)
	match zone:
		"fundicion":
			draw_rect(Rect2(0,0,w,5),Color("bca28b"))
			draw_rect(Rect2(3,5,w-6,11),dark)
			for x in range(8,int(w)-6,18):
				draw_line(Vector2(x,7),Vector2(x+8,14),accent,2)
		"ruinas","cantera":
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO,Vector2(w,0),Vector2(w-minf(7,w*0.15),18),Vector2(minf(8,w*0.15),22)]),dark.lightened(0.15))
			draw_line(Vector2.ZERO,Vector2(w,0),accent.lightened(0.25),3)
			for x in range(18,int(w)-8,30):
				draw_line(Vector2(x,2),Vector2(x-6,15),dark,2)
		"glaciar":
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO,Vector2(w,0),Vector2(w*0.88,12),Vector2(w*0.6,6),Vector2(w*0.4,22),Vector2(w*0.1,9)]),Color("76aabd"))
			draw_line(Vector2.ZERO,Vector2(w,0),Color("e0fcff"),3)
		"volcan":
			draw_rect(Rect2(0,0,w,13),Color("382b39"))
			for x in range(8,int(w)-8,26):
				draw_line(Vector2(x,1),Vector2(x+8,11),accent,2)
		"central":
			draw_rect(Rect2(0,0,w,4),Color("d2e9ef"))
			draw_rect(Rect2(4,4,w-8,10),dark)
			for x in range(10,int(w)-6,16): draw_circle(Vector2(x,9),2,accent)
		"ciudad":
			draw_rect(Rect2(-3,0,w+6,4),Color("9caebc"))
			draw_rect(Rect2(4,4,w-8,12),Color("1e3049"))
			draw_line(Vector2(8,16),Vector2(w-8,16),accent,1)
		"biolab":
			draw_style_box(_membrane(),Rect2(0,0,w,15))
			for x in range(12,int(w)-6,25): draw_circle(Vector2(x,8),3,accent.darkened(0.3))

func _membrane() -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("254b3b")
	skin.border_color = accent
	skin.border_width_top = 2
	skin.corner_radius_top_left = 7
	skin.corner_radius_top_right = 7
	skin.corner_radius_bottom_left = 7
	skin.corner_radius_bottom_right = 7
	return skin
