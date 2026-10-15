class_name MovingPlatform
extends AnimatableBody2D
## Plataforma móvil que arrastra al jugador (horizontal o vertical).
## Origen en la esquina superior izquierda.

@export var size := Vector2(48, 16)
@export var travel := Vector2(90, 0)
@export var duration := 2.2
@export var tile := "platform"
@export var start_delay := 0.0
var skin := ""
var _tile_art: Sprite2D
var motion: Tween
var route_start := Vector2.ZERO

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	_build()
	var start := position
	route_start = start
	var t := create_tween()
	motion = t
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.set_loops()
	if start_delay > 0.0:
		t.tween_interval(start_delay)
	t.tween_property(self, "position", start + travel, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_interval(1.0)
	t.tween_property(self, "position", start, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_interval(1.0)

func _build() -> void:
	var tex: Texture2D = Platform.theme_tex("tile_%s" % tile)
	var spr := Sprite2D.new()
	_tile_art = spr
	spr.texture = tex
	spr.centered = false
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.region_enabled = true
	spr.region_rect = Rect2(Vector2.ZERO, size)
	spr.z_index = -1
	add_child(spr)
	# luces de guía en los extremos (indican que se mueve)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(size.x,4)
	cs.shape = r
	cs.position = r.size * 0.5
	cs.one_way_collision = true
	cs.one_way_collision_margin = 3.0
	add_child(cs)

func _process(_delta: float) -> void:
	_tile_art.visible = skin==""
	if skin!="": queue_redraw()

func _draw() -> void:
	if skin=="": return
	var c: Color = preload("res://scripts/world/stage_themes.gd").get_theme(skin)["accent"]
	draw_rect(Rect2(0,0,size.x,3),c.lightened(0.3))
	match skin:
		"ciudad":
			draw_rect(Rect2(0,3,size.x,22),Color("163645"))
			for i in 4: draw_rect(Rect2(5+i*17,7,12,9),c)
			for x in [12,size.x-12]: draw_circle(Vector2(x,27),4,Color("060d19"))
		"fundicion","central":
			draw_rect(Rect2(3,3,size.x-6,12),c.darkened(0.7))
			for x in [8,size.x-8]:
				draw_line(Vector2(x,3),Vector2(x,22),c.darkened(0.4),4)
				draw_circle(Vector2(x,22),4,c)
		"cantera":
			draw_colored_polygon(PackedVector2Array([Vector2(0,3),Vector2(size.x,3),Vector2(size.x-12,20),Vector2(12,20)]),c.darkened(0.5))
			for x in [16,size.x-16]: draw_circle(Vector2(x,22),5,Color("273644"))
		"biolab":
			draw_colored_polygon(PackedVector2Array([Vector2(0,3),Vector2(size.x,3),Vector2(size.x*0.5,22)]),c.darkened(0.3))
			draw_line(Vector2(size.x*0.5,3),Vector2(size.x*0.5,30),c,2)
		"glaciar":
			draw_colored_polygon(PackedVector2Array([Vector2(0,3),Vector2(size.x,3),Vector2(size.x-10,15),Vector2(size.x*0.4,32),Vector2(8,18)]),c.darkened(0.15))
		_:
			draw_colored_polygon(PackedVector2Array([Vector2(0,3),Vector2(size.x,3),Vector2(size.x-12,20),Vector2(10,16)]),c.darkened(0.6))
