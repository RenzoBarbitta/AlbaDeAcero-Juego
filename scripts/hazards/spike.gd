class_name Spike
extends Area2D
## Zona de pinchos: daña al jugador al tocarla (grupo "hazard").

static func create(pos: Vector2, size: Vector2 = Vector2(16, 16)) -> Spike:
	var s := Spike.new()
	s.position = pos
	s.add_to_group("hazard")
	var spr := Sprite2D.new()
	spr.texture = Platform.theme_tex("spike")
	spr.centered = false
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.region_enabled = true
	spr.region_rect = Rect2(0, 0, size.x, size.y)
	s.add_child(spr)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = size * 0.5
	s.add_child(cs)
	s.collision_layer = 7
	s.collision_mask = 0
	s.monitoring = false
	s.monitorable = true
	return s
