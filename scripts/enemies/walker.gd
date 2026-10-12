class_name Walker
extends EnemyBase
## Robot caminante: patrulla la plataforma, gira en paredes y bordes.

const TEX := [
	preload("res://assets/sprites/enemies/walker_0.png"),
	preload("res://assets/sprites/enemies/walker_1.png"),
]

var speed := 34.0
var _dir := -1
var _ledge: RayCast2D

func _ready() -> void:
	max_health = 4
	contact_damage = 4
	score_value = 100
	use_gravity = true
	drop_health_chance = 0.25
	setup_base()
	add_child(make_sprite(TEX, 6.0))
	_sprite.position = Vector2(0, -8)
	add_body_shape(14, 14, -7)
	_ledge = RayCast2D.new()
	_ledge.target_position = Vector2(_dir * 9, 14)
	_ledge.position = Vector2(0, -2)
	_ledge.collide_with_areas = false
	add_child(_ledge)
	collision_mask = 1 | 4

func _physics_process(delta: float) -> void:
	if dead or not is_awake():
		return
	apply_gravity(delta)
	velocity.x = _dir * speed
	move_and_slide()
	if is_on_wall():
		_dir = -_dir
	# Detección de borde
	_ledge.position.x = 0
	_ledge.target_position = Vector2(_dir * 9, 14)
	if is_on_floor() and not _ledge.is_colliding():
		_dir = -_dir
	# Choque contra otro enemigo
	if get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			if c.get_collider() is EnemyBase:
				_dir = -_dir
				break
	facing = _dir
	_sprite.flip_h = _dir > 0
