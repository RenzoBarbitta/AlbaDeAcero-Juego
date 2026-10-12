class_name Bomber
extends EnemyBase
## Nave bombardera: sobrevuela y suelta bombas con gravedad.

const TEX := [
	preload("res://assets/sprites/enemies/bomber_0.png"),
	preload("res://assets/sprites/enemies/bomber_1.png"),
]
const BulletScript := preload("res://scripts/projectiles/bullet.gd")
const TEX_BOMB := preload("res://assets/sprites/fx/bullet_bomb.png")

var speed := 30.0
var _dir := -1
var _drop_t := 1.6
var _t := 0.0

func _ready() -> void:
	max_health = 3
	contact_damage = 4
	score_value = 180
	use_gravity = false
	drop_health_chance = 0.1
	setup_base()
	add_child(make_sprite(TEX, 5.0))
	_sprite.position = Vector2(0, -6)
	add_body_shape(16, 10, -6)
	collision_mask = 0

func _physics_process(delta: float) -> void:
	if dead or not is_awake():
		return
	_t += delta
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_dir = signi(int(signf(player.global_position.x - global_position.x)))
		if _dir == 0:
			_dir = 1
	velocity.x = _dir * speed
	velocity.y = sin(_t * 2.5) * 14.0
	move_and_slide()
	_sprite.flip_h = _dir > 0
	_drop_t -= delta
	if _drop_t <= 0.0:
		_drop_bomb()
		_drop_t = randf_range(1.6, 2.6)

func _drop_bomb() -> void:
	var b := BulletScript.create(TEX_BOMB, global_position + Vector2(0, 4), Vector2(0, 1), 40.0, 5, false, 1.0)
	b.grav_accel = 260.0
	get_parent().add_child(b)
	AudioManager.play("enemy_shoot", -14.0)
