extends Area2D
## Readable, authoritative attacks. Warning time is separate from the damage window.
var kind := "spike"
var size := Vector2(24,48)
var color := Color("ff9c54")
var velocity := Vector2.ZERO
var acceleration := Vector2.ZERO
var warn := 0.85
var duration := 0.5
var age := 0.0
var damage := 5
var health := 9
var dead := false
var replica := false
var source: WeakRef
var return_to := Vector2.ZERO
var _hits := {}

func _ready() -> void:
	add_to_group("boss_hazard")
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	z_index = 3
	if kind=="pod":
		var hurtbox := Area2D.new()
		hurtbox.collision_layer = 4
		hurtbox.collision_mask = 0
		hurtbox.monitoring = false
		add_child(hurtbox)
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 12
		shape.shape = circle
		hurtbox.add_child(shape)

func _physics_process(delta: float) -> void:
	if replica: return
	if source:
		var owner_boss: Node = source.get_ref()
		if not is_instance_valid(owner_boss) or owner_boss.dead:
			queue_free()
			return
	age += delta
	if age>warn+duration+0.25:
		queue_free()
		return
	if age<warn: return
	if kind=="saw" and age-warn>duration*0.5:
		velocity = velocity.move_toward((return_to-global_position).normalized()*180,delta*520)
	velocity += acceleration*delta
	global_position += velocity*delta
	if age>warn+duration: return
	var rect := Rect2(global_position-size*0.5,size)
	for p in get_tree().get_nodes_in_group("player"):
		if not p.alive: continue
		_hits[p.index] = maxf(0,float(_hits.get(p.index,0))-delta)
		if rect.intersects(Rect2(p.global_position-Vector2(6,29),Vector2(12,29))) and float(_hits[p.index])<=0:
			p.take_damage(damage,global_position)
			_hits[p.index] = 0.9

func take_damage(amount: int,_from_pos: Vector2) -> bool:
	if kind!="pod" or dead: return false
	health -= amount
	if health<=0:
		dead = true
		preload("res://scripts/fx/fx.gd").explosion(get_parent(),global_position,0.6)
		queue_free()
	return true

func _process(delta: float) -> void:
	if replica: age += delta
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-size*0.5,size)
	if age<warn:
		var fill := clampf(age/maxf(0.01,warn),0,1)
		draw_rect(rect,Color(color,0.08))
		draw_rect(rect,Color(color,0.75),false,1)
		for x in range(int(rect.position.x),int(rect.end.x),12):
			draw_line(Vector2(x,rect.end.y),Vector2(x+6,rect.end.y-5),Color(color,0.65),1)
		if velocity.y>80:
			var landing_y := 148-global_position.y
			draw_line(Vector2(-12,landing_y),Vector2(12,landing_y),color,3)
			draw_line(Vector2(0,size.y*0.5+4),Vector2(0,landing_y),Color(color,0.2),1)
		draw_arc(Vector2.ZERO,minf(size.x,24)*0.4,-PI*0.5,-PI*0.5+TAU*fill,20,color,2)
		return
	var fade := clampf((warn+duration+0.25-age)*4,0,1)
	var c := Color(color,fade)
	match kind:
		"saw":
			for i in 8:
				var ray := Vector2.RIGHT.rotated(age*16+i*TAU/8)
				draw_line(ray*8,ray*13,Color("dcecf0"),3)
			draw_circle(Vector2.ZERO,9,Color("607e90"))
			draw_circle(Vector2.ZERO,4,c)
		"spike","rock":
			draw_colored_polygon(PackedVector2Array([Vector2(-size.x*0.5,size.y*0.5),Vector2(-size.x*0.25,-size.y*0.2),Vector2(size.x*0.1,-size.y*0.5),Vector2(size.x*0.5,size.y*0.5)]),c)
			draw_line(Vector2(0,-size.y*0.4),Vector2(size.x*0.2,size.y*0.3),Color("e9f6ff"),2)
		"flame":
			for x in range(int(rect.position.x)+3,int(rect.end.x),9):
				var h := size.y*(0.6+0.3*sin(age*24+x))
				draw_colored_polygon(PackedVector2Array([Vector2(x,rect.end.y),Vector2(x+3,rect.end.y-h),Vector2(x+8,rect.end.y)]),c)
		"pod":
			draw_circle(Vector2.ZERO,13,Color("142d29"))
			draw_arc(Vector2.ZERO,11,age,age+TAU*0.85,20,c,3)
			draw_circle(Vector2(0,sin(age*3)*2),5,c)
			if health<9: draw_line(Vector2(-9,17),Vector2(-9+18*maxf(0,health)/9.0,17),c,2)
		"ghost":
			draw_arc(Vector2.ZERO,13,-PI,0,16,c,4)
			for i in 3: draw_line(Vector2(-10+i*8,-2),Vector2(-12+i*8,12+sin(age*9+i)*3),Color(color,fade*0.4),5)
			draw_line(Vector2(-5,-6),Vector2(5,-6),Color.WHITE,2)
		"orb":
			draw_circle(Vector2.ZERO,size.x*0.5,Color(color,fade*0.2))
			draw_circle(Vector2.ZERO,size.x*0.24,c)
		_:
			draw_rect(rect,Color(color,fade*0.25))
			var horizontal := size.x>size.y
			var a := Vector2(-size.x*0.5,0) if horizontal else Vector2(0,-size.y*0.5)
			var b := -a
			draw_line(a,b,c,4)
			draw_line(a,b,Color(1,1,1,fade),1)
