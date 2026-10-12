class_name Platform
extends StaticBody2D
## Plataforma sólida rectangular. El origen es la esquina superior izquierda.
## tile "top": franja de superficie + cuerpo de roca/metal (suelo y bloques).
## tile "platform": plataforma flotante de un solo bloque.

@export var size := Vector2(64, 16)
@export var tile := "top"

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_build()

static func theme_tex(texture_id: String) -> Texture2D:
	var path := "res://assets/sprites/themes/%s/%s.png" % [GameManager.theme_id, texture_id]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return load("res://assets/sprites/tiles/%s.png" % texture_id) as Texture2D

func _add_sprite(tex: Texture2D, pos: Vector2, rect_size: Vector2) -> void:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.position = pos
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.region_enabled = true
	spr.region_rect = Rect2(Vector2.ZERO, rect_size)
	spr.z_index = -1
	add_child(spr)

func _build() -> void:
	if tile == "top" and size.y > 16.0:
		_add_sprite(theme_tex("tile_top"), Vector2.ZERO, Vector2(size.x, 16.0))
		_add_sprite(theme_tex("tile_mid"), Vector2(0, 16), Vector2(size.x, size.y - 16.0))
	else:
		_add_sprite(theme_tex("tile_%s" % tile), Vector2.ZERO, size)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(size.x,4) if tile == "platform" else size
	cs.shape = r
	cs.position = r.size * 0.5
	cs.one_way_collision = tile == "platform"
	cs.one_way_collision_margin = 3.0
	add_child(cs)
