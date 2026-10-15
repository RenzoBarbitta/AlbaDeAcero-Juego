extends EnemyBase
## Familias exclusivas por bioma; dos variantes y patrones de ataque diferentes.
var zone := "fundicion"
var airborne := false
var small := false
var _time := 0.0
var _cooldown := 1.5
var _tell := 0.0
var _aim := Vector2.LEFT
var _home := Vector2.ZERO
var _ray: RayCast2D
var _splits := 0
const SHOT := preload("res://scripts/projectiles/bullet.gd")
const TEX := preload("res://assets/sprites/fx/bullet_enemy.png")
const FAMILY := {"fundicion":"FORJADOR / ESCORIA","ruinas":"BLINDADO / ARTILLERO","glaciar":"PATINADOR / CRISTAL","volcan":"BASALTO / SALAMANDRA","central":"BOBINA / CENTELLA","cantera":"EXCAVADOR / ROCALLA","ciudad":"ACECHADOR / PRISMA","biolab":"ESPORA / NODRIZA"}
const COLORS := {"fundicion":Color("ff9a42"),"ruinas":Color("e95a64"),"glaciar":Color("98eaff"),"volcan":Color("ff572c"),"central":Color("ffe96b"),"cantera":Color("c8ad7b"),"ciudad":Color("b088ff"),"biolab":Color("72ef97")}

func _ready() -> void:
	max_health = 4 if small else (14 if zone in ["cantera","ruinas"] else 8)
	contact_damage = 4
	score_value = 220
	use_gravity = not airborne
	tint = COLORS[zone]
	setup_base()
	add_body_shape(16,20,-10)
	_home = position
	_ray = RayCast2D.new()
	_ray.position = Vector2(0,-2)
	_ray.target_position = Vector2(-18,20)
	add_child(_ray)
	if small:
		scale = Vector2.ONE*0.65

func nearest() -> Player:
	var found: Player
	var distance := INF
	for p in get_tree().get_nodes_in_group("player"):
		if not p.alive:
			continue
		var d: float = global_position.distance_squared_to(p.global_position)
		if d < distance:
			distance = d
			found = p
	return found

func _process(delta: float) -> void:
	if get_meta("replica",false):
		_time += delta
		queue_redraw()

func _physics_process(delta: float) -> void:
	if dead or not is_awake():
		return
	_time += delta
	_cooldown -= delta
	var p := nearest()
	if not p:
		return
	var offset := p.global_position+Vector2(0,-14)-global_position
	facing = 1 if offset.x > 0 else -1
	if airborne:
		velocity = Vector2(sin(_time*1.3)*25,(_home.y+sin(_time*2)*14-position.y)*3)
		if GameManager.horde_mode:
			velocity = offset.normalized()*(58 if offset.length()>130 else 12)+Vector2(0,sin(_time*3)*15)
	else:
		apply_gravity(delta)
		var speed := 22.0
		match zone:
			"glaciar": speed = 90.0 if fposmod(_time,3.0)>2 else 28.0
			"ciudad": speed = 80.0 if fposmod(_time,4.0)<1 else 34.0
			"volcan":
				speed = 20.0
				if is_on_floor() and _cooldown < 0:
					velocity.y = -250
			"cantera": speed = 48.0 if fposmod(_time,4.0)>2 else 0.0
			"biolab": speed = 38.0
		velocity.x = facing*speed
		_ray.target_position.x = facing*18
		_ray.force_raycast_update()
		if is_on_floor() and not _ray.is_colliding():
			velocity.x = 0
	if _cooldown <= 0 and _tell <= 0:
		_aim = offset.normalized()
		_tell = 0.65
		_cooldown = 3.2
	elif _tell > 0:
		_tell -= delta
		if _tell <= 0:
			attack()
	move_and_slide()
	if position.y > 230:
		queue_free()
	queue_redraw()

func attack() -> void:
	match zone:
		"fundicion": volley(3,0.18,150,airborne)
		"ruinas": volley(1,0,330,airborne)
		"glaciar": volley(5 if airborne else 3,0.16,175,false)
		"volcan": volley(4,0.3,140,true)
		"central":
			if airborne:
				for i in 6:
					bullet(Vector2.RIGHT.rotated(TAU*float(i)/6+_time),145,false)
			else:
				position.x += facing*36
				volley(2,0.09,240,false)
		"cantera": volley(3 if airborne else 1,0.2,125,true)
		"ciudad": volley(3,0.25,260,false)
		"biolab":
			if airborne:
				for e in get_tree().get_nodes_in_group("enemy"):
					if not e.dead and global_position.distance_to(e.global_position)<110:
						e.health = mini(e.max_health,e.health+2)
				FxScript.ring(get_parent(),global_position,tint,6,110,0.4)
			else:
				volley(5,0.24,110,false)

func volley(count: int,spread: float,speed: float,gravity: bool) -> void:
	for i in count:
		bullet(_aim.rotated((float(i)-float(count-1)*0.5)*spread),speed,gravity)

func bullet(direction: Vector2,speed: float,gravity: bool) -> void:
	var b := SHOT.create(TEX,global_position+Vector2(0,-12),direction+Vector2(0,-0.6) if gravity else direction,speed,4,false,1,gravity)
	b.color = tint
	b._sprite.modulate = tint
	get_parent().add_child(b)

func take_damage(amount: int,at: Vector2) -> void:
	if zone == "ruinas" and not airborne and _tell <= 0 and signf(at.x-global_position.x)==facing:
		FxScript.ring(get_parent(),global_position+Vector2(facing*9,-10),tint,2,12,0.2)
		return
	if zone == "cantera" and not airborne and fposmod(_time,4.0)<1.4:
		return
	super.take_damage(amount,at)
	_flash = 0.12

func take_team_damage(amount: int,at: Vector2) -> void:
	super.take_damage(amount,at)

func die() -> void:
	if zone == "biolab" and not airborne and not small and _splits == 0:
		_splits = 1
		for i in 2:
			var child = load("res://scripts/enemies/zone_enemy.gd").new()
			child.zone = zone
			child.small = true
			child.position = position+Vector2(-12 if i == 0 else 12,0)
			get_parent().call_deferred("add_child",child)
	super.die()

func _draw() -> void:
	var c := Color.WHITE if _flash > 0 else tint
	var ink := Color("091425")
	match zone:
		"fundicion":
			draw_rect(Rect2(-10,-21,20,21),ink)
			draw_rect(Rect2(-8,-19,16,14),c.darkened(0.5))
			for i in 3: draw_rect(Rect2(-6+i*5,-17,3,10),c)
			draw_line(Vector2(-8,-19),Vector2(8,-19),c.lightened(0.35),1)
			for x in [-7,7]: draw_circle(Vector2(x,-5),1,Color("a6c5d9"))
			draw_rect(Rect2(-9,-3,6,3),c.darkened(0.2))
			draw_rect(Rect2(3,-3,6,3),c.darkened(0.2))
			draw_line(Vector2(10,-10),Vector2(16,-20),c,4)
		"ruinas":
			draw_rect(Rect2(-9,-22,18,20),c.darkened(0.45))
			draw_rect(Rect2(facing*11-2,-22,4,21),c)
			draw_line(Vector2(0,-15),Vector2(facing*21,-15),c,3)
			draw_rect(Rect2(-6,-16,12,6),c.darkened(0.6))
			draw_line(Vector2(-8,-22),Vector2(8,-22),c.lightened(0.4),1)
			for i in 3: draw_rect(Rect2(-6+i*5,-4,3,4),Color("a6c5d9"))
		"glaciar":
			draw_colored_polygon(PackedVector2Array([Vector2(0,-27),Vector2(11,-14),Vector2(6,-3),Vector2(-7,-3),Vector2(-11,-14)]),c.darkened(0.3))
			draw_line(Vector2(-12,0),Vector2(12,0),c,2)
			draw_colored_polygon(PackedVector2Array([Vector2(0,-24),Vector2(7,-14),Vector2(1,-5)]),c.lightened(0.25))
			draw_line(Vector2(-7,-13),Vector2(-1,-20),Color("def7ff"),1)
		"volcan":
			for i in 3: draw_circle(Vector2((i-1)*7,-10-abs(i-1)*3),7,ink)
			draw_circle(Vector2(0,-13),8,c.darkened(0.55))
			draw_line(Vector2(-5,-18),Vector2(4,-8),c,2)
			draw_line(Vector2(4,-8),Vector2(8,-14),c.lightened(0.5),1)
			draw_line(Vector2(-8,-6),Vector2(-3,-11),c,1)
			draw_circle(Vector2(1,-14),2,c.lightened(0.4))
		"central":
			for i in 4: draw_arc(Vector2(0,-11),4+i*2,0,TAU,12,c,1)
			draw_line(Vector2(-14,-23),Vector2(-7,-15),c,2)
			draw_line(Vector2(14,-23),Vector2(7,-15),c,2)
		"cantera":
			draw_colored_polygon(PackedVector2Array([Vector2(-12,0),Vector2(-10,-17),Vector2(0,-24),Vector2(12,-16),Vector2(14,0)]),c.darkened(0.4))
			draw_line(Vector2(0,-18),Vector2(14,-8),c,4)
			draw_line(Vector2(-9,-15),Vector2(-2,-20),c.lightened(0.3),1)
			draw_rect(Rect2(-11,-3,23,3),c.darkened(0.6))
			for i in 4: draw_rect(Rect2(-8+i*5,-2,2,2),c)
			if not airborne and fposmod(_time,4)<1.4: draw_rect(Rect2(-14,-8,28,9),ink)
		"ciudad":
			draw_colored_polygon(PackedVector2Array([Vector2(-12,0),Vector2(-5,-23),Vector2(5,-23),Vector2(11,0),Vector2(0,-7)]),c.darkened(0.45))
			draw_line(Vector2(-13,-14),Vector2(-17,-5),c,2)
			draw_line(Vector2(4,-18),Vector2(9,-5),c.darkened(0.15),1)
			draw_rect(Rect2(-2,-14,4,5),c)
			draw_line(Vector2(9,-12),Vector2(18,-16),c,2)
			modulate.a = 0.25 if _tell <= 0 and fposmod(_time,4)<1 else 1.0
		"biolab":
			for i in 4: draw_circle(Vector2((i%2)*10-5,-9-floori(float(i)/2)*10),6,c.darkened(0.35))
			draw_circle(Vector2(0,-13),3,c)
			for x in [-5,5]:
				draw_circle(Vector2(x,-19),1,c.lightened(0.5))
			draw_line(Vector2(-6,-4),Vector2(-9,1),c.darkened(0.2),2)
			draw_line(Vector2(6,-4),Vector2(9,1),c.darkened(0.2),2)
			if airborne: draw_arc(Vector2(0,-13),17,_time,_time+TAU-0.2,16,c,1)
	draw_rect(Rect2(-4,-20,8,2),Color("def7ff"))
	if airborne:
		draw_line(Vector2(-12,-12),Vector2(-20,-16+sin(_time*12)*4),c,2)
		draw_line(Vector2(12,-12),Vector2(20,-16-sin(_time*12)*4),c,2)
	if _tell > 0:
		draw_circle(Vector2(0,-31),2,Color("ff5a5a"))
	draw_rect(Rect2(-9,-29,18*clampf(float(health)/max_health,0,1),1),c)
