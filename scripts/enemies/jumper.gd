class_name Jumper
extends EnemyBase
## Robot saltarín: salta repetidamente hacia el jugador.

const TEX := [
	preload("res://assets/sprites/enemies/jumper_0.png"),
	preload("res://assets/sprites/enemies/jumper_1.png"),
]

var speed := 52.0
var _dir := -1
var _jump_cd := 1.0

func _ready() -> void:
	max_health = 3
	contact_damage = 5
	score_value = 120
	use_gravity = true
	drop_health_chance = 0.15
	setup_base()
	add_child(make_sprite(TEX, 6.0))
	_sprite.position = Vector2(0, -8)
	add_body_shape(14, 14, -7)
	collision_mask = 1

func _physics_process(delta: float) -> void:
	if dead or not is_awake():
		return
	apply_gravity(delta)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_dir = signi(int(signf(player.global_position.x - global_position.x)))
		if _dir == 0:
			_dir = 1
	_jump_cd -= delta
	velocity.x = _dir * speed
	if is_on_floor() and _jump_cd <= 0.0:
		velocity.y = -270.0
		_jump_cd = randf_range(0.9, 1.7)
	move_and_slide()
	_sprite.flip_h = _dir > 0
