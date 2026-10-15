class_name Bullet
extends Area2D
## Proyectil genérico para jugador y enemigos. Detecta cuerpos (mundo/enemigos)
## y áreas (hurtbox del jugador) mediante señales. Incluye estela y FX.

const FxScript := preload("res://scripts/fx/fx.gd")

var velocity := Vector2.ZERO
var damage := 1
var grav_accel := 0.0
var life := 3.0
var pierce := false
var pierce_left := 0
var from_player := true
var color := Color(1, 1, 1)
var heavy := false
var homing_target: Node2D = null
var homing_strength := 0.0
var _dead := false
var _sprite: Sprite2D
var _trail: Line2D
var _trail_pts := PackedVector2Array()
var effect := ""
var origin: Node2D
var _age := 0.0
var _hit_targets: Array[int] = []
var salvo_hits := {}
var salvo_cap := 0
var _ignored_rids: Array[RID] = []
var launch_from := Vector2.ZERO
var sweep_launch := false

static func create(tex: Texture2D, pos: Vector2, dir: Vector2, speed: float,
		damage_: int, from_player_: bool, scale_mul: float = 1.0,
		use_gravity: bool = false) -> Bullet:
	var b := Bullet.new()
	b.position = pos
	b.velocity = dir.normalized() * speed
	b.damage = damage_
	b.from_player = from_player_
	b.grav_accel = 380.0 if use_gravity else 0.0
	b.z_index = 3 if from_player_ else 3
	b.life = 3.0

	var spr := Sprite2D.new()
	spr.texture = tex
	spr.scale = Vector2(scale_mul, scale_mul)
	b._sprite = spr
	b.add_child(spr)

	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = maxf(3.0, tex.get_width() * 0.35 * scale_mul)
	cs.shape = circ
	b.add_child(cs)

	# Capas: jugador=l4, enemigo=l5. Máscaras: bala jugador pega mundo+l3,
	# bala enemiga pega mundo+l2 (jugador). Así nunca se daña a sí mismo.
	spr.material = FxScript.additive()
	if not from_player_:
		b.add_to_group("enemy_bullet")
	b.collision_layer = 8 if from_player_ else 16
	b.collision_mask = 5 if from_player_ else 3
	b.monitoring = true
	b.monitorable = false
	return b

func _ready() -> void:
	add_to_group("net_entity")
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	if from_player and damage >= 6:
		_build_trail()

func _build_trail() -> void:
	_trail = Line2D.new()
	_trail.width = 4.0
	_trail.default_color = Color(color.r, color.g, color.b, 0.5)
	_trail.z_index = 2
	var grad := Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, 0.0))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.7))
	_trail.gradient = grad
	get_parent().call_deferred("add_child", _trail)

func _physics_process(delta: float) -> void:
	_age += delta
	if effect == "sierra":
		_sprite.rotation += delta*22
		if _age > 0.65 and is_instance_valid(origin):
			velocity = (origin.global_position+Vector2(0,-15)-global_position).normalized()*320
			if global_position.distance_to(origin.global_position+Vector2(0,-15)) < 12:
				_cleanup()
				return
	life -= delta
	if life <= 0.0:
		_burst()
		return
	if homing_target and is_instance_valid(homing_target):
		var want := (homing_target.global_position - global_position).normalized() * velocity.length()
		velocity = velocity.lerp(want, clampf(homing_strength * delta, 0.0, 1.0))
	if grav_accel != 0.0 and not homing_target:
		velocity.y += grav_accel * delta
		if _sprite:
			_sprite.rotation = velocity.angle()
	# Barrido continuo: incluye relés y evita saltar objetivos entre dos frames.
	var next := global_position+velocity*delta
	var sweep_start := launch_from if sweep_launch else global_position
	sweep_launch = false
	var query := PhysicsRayQueryParameters2D.create(sweep_start,next,collision_mask,_ignored_rids)
	query.hit_from_inside = true
	query.collide_with_areas = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"]
		var collider: Node = hit["collider"]
		if collider is CollisionObject2D:
			_ignored_rids.append(collider.get_rid())
		if collider is Area2D:
			_on_area_entered(collider)
		else:
			_on_body_entered(collider)
		if _dead:
			return
	global_position = next
	if _sprite and grav_accel == 0.0 and not from_player:
		_sprite.rotation = velocity.angle()
	if _trail:
		_trail_pts.append(global_position)
		if _trail_pts.size() > 10:
			_trail_pts.remove_at(0)
		_trail.points = _trail_pts

func _on_body_entered(body: Node) -> void:
	if _dead or _hit_targets.has(body.get_instance_id()):
		return
	if body.has_method("take_damage") and body.get("dead") != true:
		_damage(body, body.global_position)
		if pierce and _consume_pierce():
			return
		_burst()
	else:
		_burst()

func _on_area_entered(area: Area2D) -> void:
	if _dead:
		return
	var p := area.get_parent()
	if p and _hit_targets.has(p.get_instance_id()):
		return
	if p and p.has_method("take_damage") and p.get("dead") != true:
		_damage(p, area.global_position)
		if pierce and _consume_pierce():
			return
		_burst()
	elif area.is_in_group("shield"):
		_burst()

func _damage(target: Node, at: Vector2) -> void:
	var key := target.get_instance_id()
	if salvo_cap>0:
		if int(salvo_hits.get(key,0))>=salvo_cap: return
		salvo_hits[key] = int(salvo_hits.get(key,0))+1
	_hit_targets.append(target.get_instance_id())
	var prior_health: int = target.health if target is EnemyBase else -1
	if target.has_method("receive_projectile"):
		if not from_player:
			return
		if not target.receive_projectile(damage,global_position,origin.index if is_instance_valid(origin) else -1):
			return
	else:
		var accepted = target.take_damage(damage,global_position)
		if accepted is bool and not accepted:
			return
	if prior_health >= 0 and target.health == prior_health:
		return
	if effect == "glaciar" and target is CharacterBody2D and not target.get("active"):
		target.set_physics_process(false)
		var thaw := get_tree().create_timer(0.65)
		var frozen: WeakRef = weakref(target)
		thaw.timeout.connect(func():
			var enemy = frozen.get_ref()
			if is_instance_valid(enemy):
				enemy.set_physics_process(true))
	if from_player and target.is_in_group("enemy"):
		GameManager.register_hit()
		var crit := damage >= 6
		FxScript.damage_number(get_parent(), at + Vector2(0, -6), damage,
			Color("ffe14d") if not crit else Color("ff6a5a"), crit)
		if heavy:
			GameManager.hitstop(0.05 if not crit else 0.09)

func _consume_pierce() -> bool:
	pierce_left -= 1
	if pierce_left < 0:
		return false
	FxScript.impact(get_parent(), global_position, color, 0.7)
	return true

func _burst() -> void:
	if _dead:
		return
	if effect == "estruendo":
		FxScript.explosion(get_parent(),global_position,1.5)
		FxScript.ring(get_parent(),global_position,color,4,48,0.3)
		for e in get_tree().get_nodes_in_group("enemy"):
			if not e.dead and global_position.distance_to(e.global_position) < 48 and not _hit_targets.has(e.get_instance_id()):
				e.take_damage(8,global_position)
		GameManager.shake(2)
	_cleanup()

func _cleanup() -> void:
	if _dead:
		return
	_dead = true
	if from_player:
		FxScript.impact(get_parent(), global_position, color, 0.55 if not heavy else 1.1)
	if _trail and is_instance_valid(_trail):
		_trail.queue_free()
	queue_free()
