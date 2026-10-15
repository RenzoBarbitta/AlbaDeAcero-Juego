extends Node2D
## Armadura articulada: placas angulares, articulaciones y poses de combate.
var pilot := "orange"
var actor: Node2D
var t := 0.0
var preview_pose := ""
var gait := 0.0
var _step_bucket := 0
const INK := Color("080f20")
const STEEL := Color("91b5c8")
const LIGHT := Color("def7ff")

func _process(delta: float) -> void:
	t += delta
	if is_instance_valid(actor) and NetSession.online and not NetSession.host:
		actor._shot_flash = maxf(0,actor._shot_flash-delta)
	var speed := absf(actor.velocity.x) if is_instance_valid(actor) else (90.0 if preview_pose=="run" else 0.0)
	gait += speed*delta/11.5
	var bucket := floori(gait/PI)
	if bucket!=_step_bucket and is_instance_valid(actor) and actor.alive and (actor.net_on_floor if NetSession.online and not NetSession.host else actor.is_on_floor()) and speed>65:
		preload("res://scripts/fx/fx.gd").spark(actor.get_parent(),actor.global_position+Vector2(-actor.facing*4,-1),Color("89a3ad"))
	_step_bucket = bucket
	queue_redraw()

func plate(points: Array, col: Color) -> void:
	var poly := PackedVector2Array()
	for p in points:
		poly.append(p)
	draw_colored_polygon(poly,col)
	var line := poly.duplicate()
	line.append(poly[0])
	draw_polyline(line,INK,1.1)
	draw_line(poly[0],poly[1],col.lightened(0.35),1)

func box(x: float,y: float,w: float,h: float,col: Color) -> void:
	draw_rect(Rect2(x-0.5,y-0.5,w+1,h+1),INK)
	draw_rect(Rect2(x,y,w,h),col)
	draw_line(Vector2(x,y),Vector2(x+w,y),col.lightened(0.35),1)

func limb(a: Vector2,b: Vector2,c: Color,width: float) -> void:
	draw_line(a,b,INK,width+2)
	draw_line(a,b,c,width)
	draw_circle(a,width*0.42,STEEL.darkened(0.55))

func leg_pose(running: bool,air: bool,dash: bool) -> Dictionary:
	var phase := sin(gait) if running and not air else 0.0
	var lift_a := maxf(0,phase)*5.0
	var lift_b := maxf(0,-phase)*5.0
	# Cada pierna conserva su carril: cadera, rodilla y pie avanzan juntos.
	var a := Vector2(-5+phase*1.8,-1-lift_a)
	var b := Vector2(5-phase*1.8,-1-lift_b)
	if air:
		a = Vector2(-5,-8)
		b = Vector2(5,-4)
		if is_instance_valid(actor) and actor.velocity.y>60:
			a = Vector2(-5,-2)
			b = Vector2(5,0)
	if dash:
		a = Vector2(-7,-4)
		b = Vector2(5,-2)
	return {"knee_a":Vector2(-4+phase*0.45,-7-lift_a*0.5),"foot_a":a,
		"knee_b":Vector2(4-phase*0.45,-7-lift_b*0.5),"foot_b":b}

func _draw() -> void:
	var running := false
	var air := false
	var direction := 1
	var dash := false
	var shooting := false
	if is_instance_valid(actor):
		if not actor.alive:
			return
		pilot = actor.character
		direction = actor.facing
		running = absf(actor.velocity.x) > 8
		air = not actor.net_on_floor if NetSession.online and not NetSession.host else not actor.is_on_floor()
		dash = actor._dash_time > 0
		shooting = actor._shot_flash > 0
		modulate.a = 0.3 if actor._invuln > 0 and int(t*20)%2 == 0 else 1.0
	if preview_pose != "":
		running = preview_pose == "run"
		air = preview_pose == "jump"
		dash = preview_pose == "dash"
	var c: Color = GameManager.CHARACTERS[pilot]["color"]
	var heavy := pilot in ["red","white","gold"]
	var w := 7.5 if heavy else (5.0 if pilot == "black" else 6.0)
	var breath := sin(t*3)*0.35
	if running and not air: breath = -absf(sin(gait))*1.1
	if is_instance_valid(actor): breath += actor.landing_squash*2
	var lean := 0.16 if running else -0.025
	if dash:
		lean = 0.4
	draw_set_transform(Vector2.ZERO,0,Vector2(direction,1))
	# Cape and back equipment distinguish the silhouettes.
	if pilot == "black":
		plate([Vector2(-4,-23),Vector2(-10,-18),Vector2(-15-sin(t*8)*2,-5),Vector2(-5,-10)],c.darkened(0.4))
	elif pilot == "orange":
		box(-9,-22,4,11,STEEL.darkened(0.45))
		for i in 3:
			box(-10,-21+i*3,2,1,c.lightened(0.3))
		if dash or air:
			plate([Vector2(-9,-13),Vector2(-17-sin(t*25)*3,-10),Vector2(-9,-18)],Color("73f7ff"))
	elif pilot == "violet":
		draw_arc(Vector2(0,-22),12,t,t+TAU-0.6,16,Color(c,0.7),1)
		for i in 2:
			var at := Vector2(-10 if i == 0 else 10,-18+sin(t*3+i)*2)
			plate([at+Vector2(0,-4),at+Vector2(2,0),at+Vector2(0,4),at+Vector2(-2,0)],c.lightened(0.35))
	if pilot=="mint":
		plate([Vector2(-7,-25),Vector2(-16,-19),Vector2(-12,-8),Vector2(-7,-14)],c.darkened(0.35))
		box(-13,-21,4,10,LIGHT)
		box(-15,-18,8,3,c)
	elif pilot=="white":
		box(-13,-24,8,16,STEEL.darkened(0.65))
		for i in 3:
			draw_circle(Vector2(-10,-21+i*5),2,Color("ffb15c"))
	elif pilot=="gold":
		plate([Vector2(-7,-26),Vector2(-14,-25),Vector2(-16,-14),Vector2(-11,-7),Vector2(-6,-13)],c)
		draw_line(Vector2(-12,-22),Vector2(-12,-12),LIGHT,2)
	elif pilot=="cyan":
		for i in 2:
			var drone := Vector2(-12-i*5,-30+sin(t*4+i*PI)*4)
			plate([drone+Vector2(-4,0),drone+Vector2(0,-3),drone+Vector2(4,0),drone+Vector2(0,3)],LIGHT)
			draw_circle(drone,1.2,c)
	if is_instance_valid(actor) and actor.jet_active:
		for i in 2:
			plate([Vector2(-8+i*5,-12),Vector2(-7+i*5,5+sin(t*45)*3),Vector2(-5+i*5,-12)],Color("73f7ff"))
	if dash:
		for i in 3:
			draw_line(Vector2(-12-i*6,-24+i*5),Vector2(-22-i*6,-24+i*5),Color(c,0.35),2)
	var legs := leg_pose(running,air,dash)
	var knee_a: Vector2 = legs["knee_a"]
	var foot_a: Vector2 = legs["foot_a"]
	var knee_b: Vector2 = legs["knee_b"]
	var foot_b: Vector2 = legs["foot_b"]
	limb(Vector2(-4,-13),knee_a,c.darkened(0.4),3)
	limb(knee_a,foot_a,STEEL.darkened(0.35),3)
	box(foot_a.x-2,foot_a.y-2,6,3,c.darkened(0.35))
	limb(Vector2(4,-13),knee_b,c.darkened(0.15),4 if heavy else 3)
	limb(knee_b,foot_b,c,3)
	box(foot_b.x-2,foot_b.y-2,7,3,c)
	draw_set_transform(Vector2(0,-14+breath),lean*direction,Vector2(direction,1))
	plate([Vector2(-w,-11),Vector2(w,-11),Vector2(w-1,-2),Vector2(3,2),Vector2(-3,2),Vector2(-w+1,-2)],c.darkened(0.15))
	plate([Vector2(-w+1,-10),Vector2(w-1,-10),Vector2(3,-5),Vector2(-3,-5)],STEEL)
	plate([Vector2(-2,-8),Vector2(2,-8),Vector2(1,-4),Vector2(-1,-4)],Color("73f7ff"))
	box(-4,0,8,2,STEEL.darkened(0.6))
	# Shoulder pads and exposed elbow joint.
	plate([Vector2(-w-3,-11),Vector2(-w+1,-12),Vector2(-w+2,-7),Vector2(-w-3,-5)],c.darkened(0.25))
	limb(Vector2(-w-1,-6),Vector2(-w-2,0),STEEL.darkened(0.35),3)
	if heavy:
		plate([Vector2(w-1,-13),Vector2(w+6,-11),Vector2(w+5,-4),Vector2(w,-5)],c)
		box(-w-3,-8,3,3,STEEL)
	# Faceted helmet; smaller head and a long illuminated visor.
	plate([Vector2(-5,-20),Vector2(-3,-23),Vector2(4,-23),Vector2(7,-19),Vector2(6,-13),Vector2(-4,-13),Vector2(-6,-17)],c)
	plate([Vector2(-3,-22),Vector2(3,-22),Vector2(5,-20),Vector2(-4,-20)],c.lightened(0.28))
	plate([Vector2(-4,-18),Vector2(6,-19),Vector2(6,-16),Vector2(-3,-15)],INK)
	draw_line(Vector2(-2,-17),Vector2(5,-18),Color("94faff"),1.6)
	box(-6,-18,2,4,STEEL)
	box(0,-13,4,1,STEEL.darkened(0.2))
	if pilot == "orange":
		plate([Vector2(-2,-24),Vector2(1,-25),Vector2(2,-22),Vector2(-2,-22)],STEEL)
	elif pilot=="mint":
		box(-3,-25,6,3,LIGHT)
		box(-1,-26,2,5,c)
	elif pilot=="white":
		box(-7,-25,14,3,Color("ffb15c"))
		box(-6,-27,10,2,c)
	elif pilot=="gold":
		plate([Vector2(-5,-22),Vector2(-7,-29),Vector2(0,-25),Vector2(5,-29),Vector2(5,-22)],c)
	elif pilot=="cyan":
		draw_arc(Vector2(0,-25),8,PI,TAU,12,Color("73f7ff"),1.5)
	elif heavy:
		box(-7,-22,3,5,c.darkened(0.2))
		box(5,-23,2,3,STEEL)
	elif pilot == "black":
		draw_line(Vector2(-5,-22),Vector2(-8,-27),STEEL,1)
	else:
		plate([Vector2(-2,-23),Vector2(0,-28),Vector2(3,-23)],c.lightened(0.4))
	var angle := -0.1
	if is_instance_valid(actor):
		angle = actor.aim.angle()
	else:
		angle *= direction
	draw_set_transform(Vector2(direction*5,-19+breath),angle)
	limb(Vector2(-3,1),Vector2(4,2),c.darkened(0.1),4)
	var recoil := -1.5 if shooting else 0.0
	plate([Vector2(1+recoil,-3),Vector2(10+recoil,-3),Vector2(13+recoil,-1),Vector2(12+recoil,4),Vector2(2+recoil,4)],c if heavy else STEEL.darkened(0.2))
	box(9+recoil,-2,4,5,STEEL)
	box(12+recoil,-1,2,3,Color("73f7ff"))
	match pilot:
		"black","gold":
			box(8+recoil,-2,12,3,c)
			box(11+recoil,-5,4,2,LIGHT)
		"red":
			box(9+recoil,-5,5,3,c)
			box(9+recoil,3,5,3,c)
		"mint":
			for i in 2: box(10+recoil,-2+i*4,8,1,c)
		"white":
			draw_circle(Vector2(7+recoil,1),5,INK)
			draw_circle(Vector2(7+recoil,1),3,Color("ffb15c"))
		"violet","cyan":
			draw_arc(Vector2(13+recoil,0),5,-PI*0.7,PI*0.7,12,c,2)
	if is_instance_valid(actor) and actor._charging and actor._charge_t>0.32:
		var radius := 3.0+minf(3,actor._charge_t*2)
		draw_arc(Vector2(15,0),radius,t*7,t*7+4.5,12,Color("8be9ff"),1.5)
	if shooting:
		draw_circle(Vector2(15,0),3,Color(0.4,0.9,1,0.45))
