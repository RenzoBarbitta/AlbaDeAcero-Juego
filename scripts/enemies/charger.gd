class_name Charger
extends EnemyBase
## Embestidor: patrulla; si te ve a nivel, se agacha (aviso) y carga en línea
## recta. Tras la embestida queda aturdido y es vulnerable.

const TEX := [
	preload("res://assets/sprites/enemies/walker_0.png"),
	preload("res://assets/sprites/enemies/walker_1.png"),
]

var _dir := -1
var _state := 0        # 0 patrulla, 1 aviso, 2 carga, 3 aturdido
var _t := 0.0
var _ledge: RayCast2D

func _ready() -> void:
	max_health = 7
	contact_damage = 6
	score_value = 170
	use_gravity = true
	drop_health_chance = 0.3
	if tint == Color(1, 1, 1):
		tint = Color(1.0, 0.55, 0.45)
	setup_base()
	add_child(make_sprite(TEX, 8.0))
	_sprite.position = Vector2(0, -10)
	_sprite.scale = Vector2(1.25, 1.25)
	add_body_shape(17, 17, -8.5)
	_ledge = RayCast2D.new()
	_ledge.position = Vector2(0, -2)
	_ledge.target_position = Vector2(_dir * 11, 14)
	_ledge.collide_with_areas = false
	add_child(_ledge)
	collision_mask = 1 | 4

func _physics_process(delta: float) -> void:
	if dead or not is_awake():
		return
	apply_gravity(delta)
	var p := _nearest_player()
	_ledge.target_position = Vector2(_dir * 11, 14)
	match _state:
		0:
			velocity.x = _dir * 26.0
			_sprite.speed_scale = 1.0
			if is_on_wall() or (is_on_floor() and not _ledge.is_colliding()):
				_dir = -_dir
			if p != null:
				var dx: float = p.global_position.x - global_position.x
				var dy: float = p.global_position.y - global_position.y
				if absf(dx) < 130.0 and absf(dy) < 30.0:
					_dir = 1 if dx > 0.0 else -1
					_state = 1
					_t = 0.5
		1:
			velocity.x = 0.0
			_t -= delta
			_sprite.modulate = Color(2.2, 1.2, 1.2) if int(_t * 16.0) % 2 == 0 else tint
			if _t <= 0.0:
				_state = 2
				_t = 0.9
				_sprite.modulate = tint
				AudioManager.play("dash", -12.0, 0.7)
		2:
			velocity.x = _dir * 150.0
			_sprite.speed_scale = 3.0
			_t -= delta
			if _t <= 0.0 or is_on_wall() or (is_on_floor() and not _ledge.is_colliding()):
				_state = 3
				_t = 0.8
				GameManager.shake(1.0)
		3:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			_sprite.speed_scale = 0.3
			_t -= delta
			if _t <= 0.0:
				_state = 0
	move_and_slide()
	facing = _dir
	_sprite.flip_h = _dir > 0

func _nearest_player() -> Node2D:
	var best: Node2D = null
	var bd := INF
	for q in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(q):
			continue
		var d: float = q.global_position.distance_squared_to(global_position)
		if d < bd:
			bd = d
			best = q
	return best
