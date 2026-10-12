class_name EnemyBase
extends CharacterBody2D
## Clase base de enemigos: vida, daño por contacto, muerte y botín.

const FxScript := preload("res://scripts/fx/fx.gd")
const PickupScript := preload("res://scripts/pickups/pickup.gd")

var max_health := 4
var contact_damage := 4
var score_value := 100
var use_gravity := true
var drop_health_chance := 0.2
var tint := Color(1, 1, 1)

var health := 4
var facing := -1
var dead := false
var _sprite: AnimatedSprite2D
var _flash := 0.0
## Élite: versión grande y valiosa de un enemigo normal (corona + mejor botín).
var is_elite := false
var elite_name := ""

## Marca este enemigo como élite: más vida/puntos, corona visual y botín raro.
func make_elite(elite_id: String, hp_mul: float = 2.6, score_mul: float = 3.0) -> void:
	is_elite = true
	elite_name = elite_id
	max_health = int(round(float(max_health) * hp_mul))
	health = max_health
	contact_damage += 2
	score_value = int(round(float(score_value) * score_mul))
	drop_health_chance = 1.0
	if _sprite:
		_sprite.scale *= 1.35

## Botín extra de élites: vida + pickup raro. Las subclases pueden extender.
func on_elite_drop() -> void:
	if not is_elite:
		return
	get_parent().call_deferred("add_child", PickupScript.create("rare", global_position + Vector2(0, -16)))

func setup_base() -> void:
	health = max_health
	add_to_group("enemy")
	collision_layer = 4          # capa 3: enemigo
	collision_mask = 1           # colisiona con el mundo
	if _sprite and tint != Color(1, 1, 1):
		_sprite.modulate = tint

func make_sprite(textures: Array, fps: float = 6.0) -> AnimatedSprite2D:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("move")
	sf.set_animation_speed("move", fps)
	sf.set_animation_loop("move", true)
	for t in textures:
		sf.add_frame("move", t)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = sf
	_sprite.play("move")
	if tint != Color(1, 1, 1):
		_sprite.modulate = tint
	return _sprite

func add_body_shape(w: float, h: float, oy: float = 0.0) -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, h)
	cs.shape = r
	cs.position = Vector2(0, oy)
	add_child(cs)

const WAKE_DIST := 260.0

## Los enemigos solo actúan cuando algún jugador está cerca (evita enjambres
## de todo el mapa persiguiéndote desde el inicio).
func is_awake() -> bool:
	if GameManager.horde_mode: return true
	for q in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(q) and absf(q.global_position.x - global_position.x) < WAKE_DIST:
			return true
	return false

func apply_gravity(delta: float) -> void:
	if use_gravity and not is_on_floor():
		velocity.y = minf(velocity.y + 900.0 * delta, 400.0)

func take_damage(amount: int, _from_pos: Vector2) -> void:
	if dead:
		return
	health -= amount
	if _sprite:
		_sprite.modulate = Color(4, 4, 4) if tint == Color(1, 1, 1) else Color(tint.r * 4, tint.g * 4, tint.b * 4)
		_flash = 0.09
	AudioManager.play("hit", -16.0)
	if health <= 0:
		die()

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0 and _sprite:
			_sprite.modulate = tint
	if is_elite:
		queue_redraw()

func _draw() -> void:
	# Corona de élite: 3 picos dorados flotando sobre la cabeza (12 px arriba).
	if not is_elite or _sprite == null:
		return
	var top_y: float = _sprite.position.y - 22.0
	var w := 3.0
	var bob := sin(Time.get_ticks_msec() / 280.0) * 1.0
	for i in 3:
		var x := (float(i) - 1.0) * 5.0
		draw_rect(Rect2(x - w * 0.5, top_y + bob, w, 5.0), Color("0a0a14"))
		draw_rect(Rect2(x - w * 0.5, top_y + bob, w, 4.0), Color("ffd45a"))
	draw_rect(Rect2(-8.0, top_y + 5.0 + bob, 16.0, 2.0), Color("0a0a14"))
	draw_rect(Rect2(-8.0, top_y + 5.0 + bob, 16.0, 1.0), Color("ffd45a"))

func die() -> void:
	if dead:
		return
	dead = true
	# Destrucción en capas: explosion + anillo + chispas + piezas volando.
	var boom_col := tint.lightened(0.35) if tint != Color(1, 1, 1) else Color(1, 0.7, 0.3)
	FxScript.kill_burst(get_parent(), global_position + Vector2(0, -10), boom_col, is_elite)
	AudioManager.play("explode", -8.0 if not is_elite else -4.0, 0.8 if is_elite else 1.0)
	if is_elite:
		GameManager.shake(2.5)
		GameManager.toast("¡ÉLITE ELIMINADO! +%d" % score_value, Color("c07dff"))
	GameManager.add_score(score_value)
	FxScript.score_popup(get_parent(), global_position, score_value, is_elite)
	GameManager.register_kill()
	if randf() < 0.3:
		get_parent().call_deferred("add_child", PickupScript.create("chip", global_position + Vector2(0, -12)))
	if randf() < drop_health_chance:
		var p := PickupScript.create("health", global_position + Vector2(0, -8))
		get_parent().call_deferred("add_child", p)
	on_elite_drop()
	queue_free()
