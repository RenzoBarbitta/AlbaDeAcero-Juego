extends Node2D
var zone := "fundicion"
var players: Array = []
var anchors: Array = []
var clock := 0.0
var cooldown := {}

func _ready() -> void:
	z_index = -3

func _process(_delta: float) -> void:
	clock = GameManager.play_time
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not NetSession.is_authority() or GameManager.state!=GameManager.State.PLAYING: return
	for p in players:
		if not p.alive: continue
		var at: Vector2 = p.global_position-global_position
		if at.x<100 or at.x>1480: continue
		cooldown[p.index] = maxf(0,float(cooldown.get(p.index,0))-delta)
		if zone=="glaciar" and fmod(clock,8)>4:
			p.move_and_collide(Vector2(20*delta,0))
		if zone=="central" and not p.is_on_floor():
			p.velocity.y -= 400*delta
		if zone=="biolab" and at.y>115 and fmod(clock,7)>4 and cooldown[p.index]<=0:
			p.take_damage(3,global_position+at+Vector2(0,30))
			cooldown[p.index] = 1.0
		if zone=="fundicion" and p.is_on_floor():
			p.move_and_collide(Vector2(22*delta,0))
		if zone=="volcan" and at.y>170-sin(clock*0.3)*24 and cooldown[p.index]<=0:
			p.take_damage(4,global_position+at+Vector2(0,30))
			cooldown[p.index] = 1.0

func _draw() -> void:
	var col: Color = preload("res://scripts/world/stage_themes.gd").get_theme(zone)["accent"]
	for i in range(anchors.size()-1):
		var a: Vector2 = anchors[i]
		var b: Vector2 = anchors[i+1]
		match zone:
			"fundicion","cantera":
				draw_line(a+Vector2(64,18),b+Vector2(64,18),col.darkened(0.65),3)
				for joint in [a,b]:
					draw_arc(joint+Vector2(64,18),12,clock,clock+TAU,16,col.darkened(0.35),3)
			"central":
				draw_line(a+Vector2(64,10),b+Vector2(64,10),Color(col,0.25),2)
				for j in 5:
					var particle := a.lerp(b,fposmod(clock*0.15+j*0.2,1))
					draw_circle(particle+Vector2(64,10),2,col)
			"ciudad":
				draw_line(a+Vector2(40,24),b+Vector2(40,24),Color("384c62"),5)
				for j in 10:
					var rail := a.lerp(b,j/10.0)+Vector2(40,24)
					draw_line(rail-Vector2(7,0),rail+Vector2(7,0),col.darkened(0.4),2)
			"biolab":
				draw_arc(a+Vector2(0,14),55,0,PI,20,col.darkened(0.65),10)
				for j in 3:
					draw_circle(a+Vector2(-40+j*35,25),12,Color(col,0.25))
			"ruinas":
				draw_arc(a+Vector2(0,90),65,PI,TAU,20,col.darkened(0.7),16)
				draw_line(a+Vector2(-65,90),a+Vector2(-65,190),col.darkened(0.7),16)
			"glaciar":
				var ice := PackedVector2Array([a+Vector2(-60,12),a+Vector2(60,12),a+Vector2(22,58),a+Vector2(-12,110)])
				draw_colored_polygon(ice,col.darkened(0.5))
			"volcan":
				draw_colored_polygon(PackedVector2Array([a+Vector2(-65,16),a+Vector2(65,16),a+Vector2(30,70),a+Vector2(-20,48)]),col.darkened(0.65))
	if zone in ["volcan","biolab"]:
		var y := 170-sin(clock*0.3)*24 if zone=="volcan" else 182.0
		draw_rect(Rect2(180,y,1310,230-y),Color(col,0.5))
		for i in 24: draw_circle(Vector2(180+i*55,y+sin(clock+i)*3),3,Color(col,0.8))
	if zone=="glaciar" and fmod(clock,8)>4:
		for i in 40:
			var x := fposmod(clock*90+i*79,1600)
			var y := -550+fmod(i*53,720)
			draw_line(Vector2(x,y),Vector2(x+15,y+2),Color(0.7,0.9,1,0.5),1)
