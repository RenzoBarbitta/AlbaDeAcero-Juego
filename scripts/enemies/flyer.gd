class_name Flyer
extends EnemyBase
## Nave voladora: se mueve en zigzag hacia el jugador y dispara.

const TEX := [
	preload("res://assets/sprites/enemies/flyer_0.png"),
	preload("res://assets/sprites/enemies/flyer_1.png"),
]
const BulletScript := preload("res://scripts/projectiles/bullet.gd")
const TEX_BULLET := preload("res://assets/sprites/fx/bullet_enemy.png")

var speed := 42.0
var amp := 20.0
var _t := 0.0
var _shoot_t := 1.2

func _ready() -> void:
	max_health = 2
	contact_damage = 4
	score_value = 150
	use_gravity = false
	drop_health_chance = 0.15
	setup_base()
	add_child(make_sprite(TEX, 8.0))
	_sprite.position = Vector2(0, -5)
	add_body_shape(14, 8, -5)
	collision_mask = 1

func _physics_process(delta: float) -> void:
	if dead or not is_awake():
		return
	_t += delta
	var player := get_tree().get_first_node_in_group("player")
	var dx := 0.0
	if player:
		dx = signf(player.global_position.x - global_position.x)
	velocity.x = dx * speed
	velocity.y = sin(_t * 3.0) * amp
	move_and_slide()
	_sprite.flip_h = dx > 0
	_shoot_t -= delta
	if _shoot_t <= 0.0 and player:
		_shoot(player)
		_shoot_t = 2.0

func _shoot(player: Node2D) -> void:
	var target := player.global_position + Vector2(0, -12)
	var dir := (target - global_position).normalized()
	var b := BulletScript.create(TEX_BULLET, global_position, dir, 150.0, 4, false, 1.0)
	get_parent().add_child(b)
	AudioManager.play("enemy_shoot", -14.0)
