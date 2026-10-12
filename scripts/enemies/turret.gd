class_name Turret
extends EnemyBase
## Torreta fija: apunta al jugador y dispara ráfagas.

const TEX := [
	preload("res://assets/sprites/enemies/turret_0.png"),
	preload("res://assets/sprites/enemies/turret_1.png"),
]
const BulletScript := preload("res://scripts/projectiles/bullet.gd")
const TEX_BULLET := preload("res://assets/sprites/fx/bullet_enemy.png")

var range_px := 190.0
var _shoot_t := 1.0
var _aim := 0.0

func _ready() -> void:
	max_health = 6
	contact_damage = 6
	score_value = 150
	use_gravity = false
	drop_health_chance = 0.2
	setup_base()
	add_child(make_sprite(TEX, 3.0))
	_sprite.position = Vector2(0, -8)
	add_body_shape(14, 14, -8)
	collision_mask = 0

func _physics_process(delta: float) -> void:
	if dead or not is_awake():
		return
	velocity = Vector2.ZERO
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var to: Vector2 = (player.global_position + Vector2(0, -12)) - global_position
		_aim = to.angle()
		# El sprite de la torreta apunta hacia arriba por defecto
		_sprite.rotation = _aim + PI / 2.0
		_shoot_t -= delta
		if _shoot_t <= 0.0 and to.length() < range_px:
			_shoot()
			_shoot_t = 1.5

func _shoot() -> void:
	var dir := Vector2.RIGHT.rotated(_aim)
	for spread in [-0.08, 0.08]:
		var d := Vector2.RIGHT.rotated(_aim + spread)
		var b := BulletScript.create(TEX_BULLET, global_position + dir * 10.0, d, 190.0, 4, false, 1.0)
		get_parent().add_child(b)
	AudioManager.play("enemy_shoot", -12.0)
