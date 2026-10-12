extends StaticBody2D
## Physical devices shared by the authored rooms; each biome chooses its own combinations.
var kind := "press"
var zone := "fundicion"
var size := Vector2(40,90)
var players: Array = []
var health := 12
var dead := false
var clock := 0.0
var offset := 0.0
var growth := 0.0
var active := false
var _shape: CollisionShape2D
var _cooldowns := {}
var _hinted := false

func _ready() -> void:
	collision_layer = 1 if kind in ["rock","root","pulse"] else 0
	collision_mask = 0
	add_to_group("campaign_device")
	if kind in ["rock","root","pulse"]:
		_shape = CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size if kind=="rock" else Vector2(size.x,4)
		_shape.shape = rect
		_shape.position = rect.size*0.5
		_shape.one_way_collision = kind!="rock"
		_shape.one_way_collision_margin = 3
		_shape.disabled = kind=="root"
		add_child(_shape)
	if kind=="root":
		var bud := Area2D.new()
		bud.collision_layer = 4
		bud.collision_mask = 0
		bud.monitoring = false
		var hit := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 12
		hit.shape = circle
		hit.position = Vector2(-10,-16)
		bud.add_child(hit)
		add_child(bud)

func take_damage(amount: int,_from: Vector2) -> bool:
	if kind=="root":
		growth = 8
		_set_active(true)
		return true
	if kind!="rock" or dead: return false
	health -= amount
	if health<=0:
		dead = true
		_shape.set_deferred("disabled",true)
		preload("res://scripts/fx/fx.gd").explosion(get_parent(),global_position+size*0.5,0.7)
	queue_redraw()
	return true

func _set_active(value: bool) -> void:
	active = value
	if _shape: _shape.set_deferred("disabled",not value)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not NetSession.is_authority() or GameManager.state!=GameManager.State.PLAYING: return
	clock = GameManager.play_time+offset
	var phase := fposmod(clock,6)
	if kind=="root":
		growth = maxf(0,growth-delta)
		_set_active(growth>0)
	elif kind=="pulse": _set_active(phase<4.4)
	else: active = phase>4.5
	for p in players:
		if not p.alive: continue
		var at: Vector2 = p.global_position-global_position
		_cooldowns[p.index] = maxf(0,float(_cooldowns.get(p.index,0))-delta)
		if kind=="root" and at.distance_to(Vector2(-10,0))<85:
			if not _hinted:
				_hinted = true
				GameManager.toast("DISPARA AL BULBO O PULSA E: EL PUENTE CRECE 8 SEGUNDOS",Color("63ffc3"))
			if p.pressed_once("interact"): take_damage(1,p.global_position)
		if kind=="belt" and at.x>=0 and at.x<=size.x and absf(at.y)<12 and p.is_on_floor():
			p.move_and_collide(Vector2((34 if int(offset)%2==0 else -34)*delta,0))
		if kind=="wind" and Rect2(Vector2.ZERO,size).has_point(at):
			p.move_and_collide(Vector2(sin(clock*0.6)*32*delta,0))
		if kind in ["press","laser","vent"] and active and Rect2(Vector2(-5,-4),size+Vector2(10,22)).has_point(at) and float(_cooldowns[p.index])<=0:
			p.take_damage(4,global_position+size*0.5)
			_cooldowns[p.index] = 1.0
	queue_redraw()

func _draw() -> void:
	var c: Color = preload("res://scripts/world/stage_themes.gd").get_theme(zone)["accent"]
	var phase := fposmod(clock,6)
	match kind:
		"rock":
			if dead: return
			draw_rect(Rect2(Vector2.ZERO,size),c.darkened(0.4))
			draw_polyline(PackedVector2Array([Vector2(size.x*0.6,0),Vector2(size.x*0.3,size.y*0.4),Vector2(size.x*0.7,size.y*0.6),Vector2(size.x*0.4,size.y)]),Color("152537"),2)
			draw_line(Vector2(3,3),Vector2(size.x-3,3),c,2)
		"root":
			draw_circle(Vector2(-10,-16),9,Color("234b39"))
			draw_circle(Vector2(-10,-16),5,Color("81efac"))
			if active:
				draw_line(Vector2.ZERO,Vector2(size.x,0),Color("568b50"),5)
				for x in range(8,int(size.x),24):
					draw_colored_polygon(PackedVector2Array([Vector2(x,2),Vector2(x+13,11),Vector2(x+22,1)]),Color("376945"))
			else: draw_line(Vector2.ZERO,Vector2(size.x,0),Color(0.3,0.8,0.5,0.18),1)
		"pulse":
			for x in [0,size.x]: draw_circle(Vector2(x,2),4,c)
			draw_line(Vector2.ZERO,Vector2(size.x,0),Color(c,1 if active else 0.12),4 if active else 1)
			if phase>3.4 and active:
				for x in range(8,int(size.x),20): draw_circle(Vector2(x,-4),1,Color("ff7862"))
		"belt":
			draw_rect(Rect2(0,0,size.x,7),Color("343240"))
			for i in range(0,int(size.x),16):
				var x := fposmod(i+clock*18,size.x)
				draw_line(Vector2(x,1),Vector2(x+5,5),c,1)
		"press":
			var y := size.y-12 if active else 0.0
			draw_line(Vector2(size.x*0.5,-60),Vector2(size.x*0.5,y),Color("69757e"),8)
			draw_rect(Rect2(0,y,size.x,12),Color("7a6958"))
			for x in range(4,int(size.x)-4,10): draw_line(Vector2(x,y+2),Vector2(x+6,y+8),c,2)
			if phase>3.5: draw_line(Vector2(0,size.y),Vector2(size.x,size.y),Color("ff655b"),2)
		"laser":
			draw_rect(Rect2(-5,-5,6,14),c.darkened(0.3))
			draw_rect(Rect2(size.x,-5,6,14),c.darkened(0.3))
			if phase>3.5: draw_line(Vector2(0,2),Vector2(size.x,2),Color(c,1 if active else 0.2),3 if active else 1)
		"vent":
			draw_arc(Vector2(size.x*0.5,size.y),size.x*0.5,PI,TAU,12,c.darkened(0.4),4)
			if phase>3.5:
				for i in 4:
					var y := fposmod(clock*40+i*13,size.y)
					draw_circle(Vector2(size.x*0.5+sin(clock+i)*8,size.y-y),3 if active else 1,Color(c,0.8))
		"wind":
			for i in 12:
				var x := fposmod(clock*32+i*41,size.x)
				var y := fposmod(i*47,size.y)
				draw_line(Vector2(x,y),Vector2(x+12,y-2),Color(0.7,0.9,1,0.3),1)
