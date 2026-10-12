extends EnemyBase
## Seis siluetas y comportamientos, con avisos antes de atacar.
var role := "sentinel"
var _clock := 0.0
var _cooldown := 1.4
var _warning := 0.0
var _aim := Vector2.LEFT
var _anchor := Vector2.ZERO
var _ledge: RayCast2D
const SHOT := preload("res://scripts/projectiles/bullet.gd")
const TEX := preload("res://assets/sprites/fx/bullet_player.png")
const COLORS := {"sentinel": Color("59d0ff"), "sniper": Color("ff758b"), "stalker": Color("b58aff"), "medic": Color("63ffc3"), "orbiter": Color("ffd45a"), "mortar": Color("ff9b3d")}

func _ready() -> void:
	max_health = 12 if role == "sentinel" else 7
	contact_damage = 5
	score_value = 240
	use_gravity = role not in ["medic", "orbiter"]
	tint = COLORS[role]
	setup_base()
	add_body_shape(18,20,-10)
	_anchor = position
	_ledge = RayCast2D.new()
	_ledge.position = Vector2(0,-2)
	_ledge.target_position = Vector2(-16,20)
	add_child(_ledge)

func nearest() -> Node2D:
	var found: Node2D
	var dist := INF
	for p in get_tree().get_nodes_in_group("player"):
		if not p.is_alive():
			continue
		var d: float = global_position.distance_squared_to(p.global_position)
		if d < dist:
			dist = d
			found = p
	return found

func _physics_process(delta: float) -> void:
	if dead or not is_awake():
		return
	_clock += delta
	_cooldown -= delta
	var p := nearest()
	if p == null:
		return
	var offset := p.global_position + Vector2(0,-14) - (global_position + Vector2(0,-12))
	facing = 1 if offset.x > 0 else -1
	apply_gravity(delta)
	if role in ["medic", "orbiter"]:
		position = _anchor + Vector2(sin(_clock*1.4)*32,cos(_clock*2)*16)
	elif role == "stalker":
		velocity.x = facing * (95.0 if _warning > 0 else 30.0)
		if is_on_floor() and _cooldown <= 0:
			velocity.y = -260
			_cooldown = 2.5
			_warning = 0.7
	elif role == "sentinel":
		velocity.x = facing*22.0
	else:
		velocity.x = 0
	_ledge.target_position.x = facing*16
	_ledge.force_raycast_update()
	if use_gravity and is_on_floor() and not _ledge.is_colliding():
		velocity.x = 0
	if role != "stalker":
		if _cooldown <= 0 and _warning <= 0:
			_aim = offset.normalized()
			_warning = 0.7 if role == "sniper" else 0.45
			_cooldown = 2.7 if role == "mortar" else 2.1
		elif _warning > 0:
			_warning -= delta
			if _warning <= 0:
				attack()
	else:
		_warning = maxf(0,_warning-delta)
	if use_gravity:
		move_and_slide()
	if position.y > 230:
		queue_free()
	queue_redraw()

func attack() -> void:
	if role == "medic":
		for e in get_tree().get_nodes_in_group("enemy"):
			if e != self and not e.dead and global_position.distance_to(e.global_position) < 110:
				e.health = mini(e.health+2,e.max_health)
		FxScript.ring(get_parent(),global_position, tint,4,105,0.4)
		return
	var dirs: Array[Vector2] = [_aim]
	if role == "orbiter":
		dirs.clear()
		for i in 6:
			dirs.append(Vector2.RIGHT.rotated(TAU*float(i)/6.0+_clock))
	for dir in dirs:
		var arc := role == "mortar"
		var b := SHOT.create(TEX,global_position+Vector2(0,-14),Vector2(facing,-1.5) if arc else dir,145 if arc else (310 if role == "sniper" else 135),4,false,1,arc)
		b.color = tint
		b._sprite.modulate = tint
		get_parent().add_child(b)
	AudioManager.play("shoot",-20)

func take_damage(amount: int, from_pos: Vector2) -> void:
	if role == "sentinel" and _warning <= 0 and signf(from_pos.x-global_position.x) == facing:
		FxScript.ring(get_parent(),global_position+Vector2(facing*10,-12),tint,2,12,0.2)
		return
	super.take_damage(amount,from_pos)
	_flash = 0.12

func take_team_damage(amount: int, from_pos: Vector2) -> void:
	super.take_damage(amount,from_pos)
	_flash = 0.12

func _draw() -> void:
	var c := Color.WHITE if _flash > 0 else tint
	var dark := c.darkened(0.65)
	if role in ["medic", "orbiter"]:
		draw_circle(Vector2(0,-10),11,Color("091320"))
		draw_arc(Vector2(0,-10),9,_clock,_clock+TAU-0.4,12,c,2)
		draw_circle(Vector2(0,-10),4,c)
		if role == "medic":
			draw_line(Vector2(-3,-10),Vector2(3,-10),Color.WHITE,2)
			draw_line(Vector2(0,-13),Vector2(0,-7),Color.WHITE,2)
		else:
			for i in 3:
				draw_circle(Vector2(0,-10)+Vector2.RIGHT.rotated(_clock+TAU*i/3)*14,2,c)
	else:
		draw_rect(Rect2(-10,-21,20,21),Color("091320"))
		draw_rect(Rect2(-8,-18,16,12),dark)
		draw_rect(Rect2(-7,-24,14,8),c)
		draw_rect(Rect2(-5,-21,10,2),Color("d5fbff"))
		draw_rect(Rect2(-8,-5,6,5),c)
		draw_rect(Rect2(2,-5,6,5),c)
		if role == "sentinel":
			draw_rect(Rect2(facing*10-2,-22,4,22),c)
		elif role == "sniper":
			draw_line(Vector2(0,-14),Vector2(facing*22,-14),c,3)
		elif role == "mortar":
			draw_line(Vector2(0,-12),Vector2(facing*10,-25),c,5)
		else:
			draw_line(Vector2(-12,-16),Vector2(-16,-6),c,2)
			draw_line(Vector2(12,-16),Vector2(16,-6),c,2)
	if _warning > 0:
		draw_circle(Vector2(0,-30),2,Color("ff5a5a"))
		if role == "sniper":
			draw_line(Vector2(0,-14),Vector2(0,-14)+_aim*260,Color(1,0.3,0.4,0.5),1)
	draw_rect(Rect2(-9,-28,18*clampf(float(health)/max_health,0,1),1),c)
