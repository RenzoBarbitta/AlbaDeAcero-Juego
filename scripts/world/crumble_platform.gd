extends StaticBody2D
## Plataforma que se desmorona: tiembla al pisarla, cae y reaparece más tarde.

@export var size := Vector2(32, 16)
@export var fall_delay := 0.45
@export var respawn_delay := 2.4

var _sprite: Sprite2D
var _shape: CollisionShape2D
var _state := 0      # 0 estable, 1 temblando, 2 oculta
var _t := 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_sprite = Sprite2D.new()
	_sprite.texture = Platform.theme_tex("tile_crumble")
	_sprite.centered = false
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(Vector2.ZERO, size)
	_sprite.z_index = -1
	add_child(_sprite)
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(size.x,4)
	_shape.shape = r
	_shape.position = r.size * 0.5
	_shape.one_way_collision = true
	_shape.one_way_collision_margin = 3.0
	add_child(_shape)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	var ac := CollisionShape2D.new()
	var ar := RectangleShape2D.new()
	ar.size = Vector2(size.x - 4.0, 6.0)
	ac.shape = ar
	ac.position = Vector2(size.x * 0.5, -3.0)
	area.add_child(ac)
	area.body_entered.connect(_on_body)
	add_child(area)

func _on_body(body: Node) -> void:
	if _state == 0 and body.is_in_group("player"):
		_state = 1
		_t = fall_delay
		AudioManager.play("hit", -14.0, 0.7)

func _process(delta: float) -> void:
	if _state == 1:
		_t -= delta
		_sprite.position = Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5))
		if _t <= 0.0:
			_state = 2
			_t = respawn_delay
			_shape.set_deferred("disabled", true)
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(_sprite, "position", Vector2(0, 36), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(_sprite, "modulate:a", 0.0, 0.4)
	elif _state == 2:
		_t -= delta
		if _t <= 0.0:
			_state = 0
			_sprite.position = Vector2.ZERO
			_sprite.modulate.a = 1.0
			_shape.set_deferred("disabled", false)
