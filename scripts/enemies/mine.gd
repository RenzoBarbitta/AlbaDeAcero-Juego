class_name Mine
extends EnemyBase
## Mina flotante: se arma al acercarte (parpadea) y explota con daño de área.
## Se puede destruir a distancia disparándole.

const TEX := [
	preload("res://assets/sprites/world/mine_0.png"),
	preload("res://assets/sprites/world/mine_1.png"),
]
const FxScript2 := preload("res://scripts/fx/fx.gd")

var _arm_t := -1.0
var _bob := 0.0

func _ready() -> void:
	max_health = 2
	contact_damage = 6
	score_value = 90
	use_gravity = false
	drop_health_chance = 0.1
	setup_base()
	add_child(make_sprite(TEX, 1.2))
	_sprite.position = Vector2(0, -8)
	add_body_shape(12, 12, -8)
	collision_mask = 0

func _physics_process(delta: float) -> void:
	if dead or not is_awake():
		return
	_bob += delta
	_sprite.position.y = -8.0 + sin(_bob * 3.0) * 2.0
	if _arm_t < 0.0:
		for q in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(q) and q.global_position.distance_to(global_position + Vector2(0, -8)) < 40.0:
				_arm_t = 0.55
				_sprite.speed_scale = 14.0
				AudioManager.play("select", -10.0, 1.6)
				break
	else:
		_arm_t -= delta
		if _arm_t <= 0.0:
			_explode()

func _explode() -> void:
	var center := global_position + Vector2(0, -8)
	for q in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(q) and q.has_method("take_damage") and q.global_position.distance_to(center) < 42.0:
			q.take_damage(8, center)
	FxScript2.ring(get_parent(), center, Color(1, 0.55, 0.3, 0.95), 4.0, 42.0, 0.3)
	score_value = 0
	die()
