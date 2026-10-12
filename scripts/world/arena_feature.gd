extends Node2D
var zone := "fundicion"
var width := 400.0
var players: Array = []
var cooldowns := {}
var clock := 0.0

func _ready() -> void:
	z_index = -2

func _process(_delta: float) -> void:
	clock = GameManager.play_time
	queue_redraw()

func live() -> bool:
	if GameManager.state!=GameManager.State.PLAYING: return false
	if get_parent().has_method("horde_snapshot"): return get_parent().phase=="combat"
	return get_parent()._arena_locked and not get_parent()._boss_down

func _physics_process(delta: float) -> void:
	if not NetSession.is_authority() or not live(): return
	var cycle := fposmod(GameManager.play_time,7)
	for p in players:
		if not p.alive: continue
		var at: Vector2 = p.global_position-global_position
		if at.x<0 or at.x>width: continue
		cooldowns[p.index] = maxf(0,float(cooldowns.get(p.index,0))-delta)
		if zone=="glaciar" and cycle>3:
			p.move_and_collide(Vector2((18 if int(GameManager.play_time/7)%2==0 else -18)*delta,0))
		var danger := false
		match zone:
			"fundicion": danger = cycle>5.6 and absf(at.x-width*0.5)<24 and at.y>25
			"ruinas": danger = cycle>5.8 and absf(at.x-width*0.28)<20 and at.y>30
			"volcan": danger = cycle>4.8 and at.y>120 and (absf(at.x-width*0.3)<26 or absf(at.x-width*0.7)<26)
			"central": danger = cycle>4 and at.y>105 and absf(at.x-width*(0.2+0.6*(cycle-4)/3))<12
			"cantera": danger = cycle>4.5 and at.y>130 and absf(absf(at.x-width*0.5)-(cycle-4.5)*width*0.22)<18
			"ciudad": danger = cycle>3 and absf(at.x-(cycle-3)*width/4)<42 and at.y>112
			"biolab": danger = cycle>4 and at.y>112 and absf(at.x-width*0.5)<width*0.16
		if danger and float(cooldowns[p.index])<=0:
			p.take_damage(4,global_position+Vector2(width*0.5,150))
			cooldowns[p.index] = 1.0

func _draw() -> void:
	var w := width
	var cycle := fposmod(clock,7)
	var active := live()
	match zone:
		"fundicion":
			for x in [w*0.18,w*0.5,w*0.82]:
				draw_rect(Rect2(x-15,-180,30,300),Color("2c2830"))
				for y in range(-160,100,30): draw_rect(Rect2(x-19,y,38,5),Color("62534b"))
			var y := 40.0 if cycle<5.6 or not active else 138.0
			draw_rect(Rect2(w*0.5-22,y-90,44,90),Color("805b45"))
			draw_rect(Rect2(w*0.5-27,y-8,54,8),Color("ffb35a"))
			if active and cycle>4.5: draw_rect(Rect2(w*0.5-24,145,48,4),Color("ff655c"))
		"ruinas":
			for x in [w*0.12,w*0.5,w*0.88]:
				draw_rect(Rect2(x-20,-90,40,240),Color("424956"))
				draw_arc(Vector2(x+30,-70),55,PI,TAU,32,Color("657081"),14)
			if active and cycle>4.4:
				draw_line(Vector2(w*0.28,-120),Vector2(w*0.28,150),Color("ffd567"),1 if cycle<5.8 else 12)
		"glaciar":
			for i in 7:
				var x := i*w/6
				draw_colored_polygon(PackedVector2Array([Vector2(x-30,150),Vector2(x,-120-(i%3)*18),Vector2(x+35,150)]),Color("254657"))
			if active and cycle>3:
				for i in 16:
					var x := fposmod(i*67+clock*110,w)
					draw_line(Vector2(x,-40+(i%5)*35),Vector2(x+30,-45+(i%5)*35),Color(0.7,0.95,1,0.4),1)
		"volcan":
			draw_arc(Vector2(w*0.5,160),w*0.3,PI,TAU,40,Color("69392f"),28)
			for x in [w*0.3,w*0.7]:
				draw_rect(Rect2(x-24,145,48,5),Color("ffa54e"))
				if active and cycle>4.8: draw_colored_polygon(PackedVector2Array([Vector2(x-24,150),Vector2(x,70+sin(clock*18)*10),Vector2(x+24,150)]),Color("ff642c"))
		"central":
			for r in [35,55,78]: draw_arc(Vector2(w*0.5,-10),r,clock*0.3,clock*0.3+TAU*0.85,48,Color("507b8c"),3)
			draw_circle(Vector2(w*0.5,-10),24,Color("75efff"))
			if active and cycle>3:
				var x := w*(0.2+0.6*maxf(0,cycle-4)/3)
				draw_line(Vector2(x,108),Vector2(x,150),Color("ff655c") if cycle<4 else Color("75efff"),2 if cycle<4 else 8)
		"cantera":
			draw_colored_polygon(PackedVector2Array([Vector2(0,150),Vector2(w*0.12,-50),Vector2(w*0.5,-150),Vector2(w*0.85,-40),Vector2(w,150)]),Color("413b38"))
			for y in range(-30,150,28): draw_line(Vector2(w*0.2,y),Vector2(w*0.8,y+20),Color("705f4a"),3)
			if active and cycle>4.5:
				for sign_dir in [-1,1]: draw_arc(Vector2(w*0.5+sign_dir*(cycle-4.5)*w*0.22,150),18,PI,TAU,16,Color("ffcb83"),3)
		"ciudad":
			draw_line(Vector2(0,144),Vector2(w,144),Color("79a1bc"),3)
			for x in range(0,int(w),36): draw_rect(Rect2(x,145,16,5),Color("36435f"))
			if active and cycle>3:
				var x := (cycle-3)*w/4
				draw_rect(Rect2(x-40,114,80,28),Color("41687e"))
				for i in 4: draw_rect(Rect2(x-32+i*17,118,12,10),Color("b2f3ff"))
				draw_circle(Vector2(x-25,144),5,Color("c0d5e0"))
				draw_circle(Vector2(x+25,144),5,Color("c0d5e0"))
		"biolab":
			for i in 5:
				var x := w*(i+1)/6
				draw_line(Vector2(x,150),Vector2(x+sin(clock+i)*12,-70),Color("315d4e"),16)
				draw_circle(Vector2(x,-45),20+sin(clock+i)*3,Color("55784e"))
			if active and cycle>4: draw_rect(Rect2(w*0.34,114,w*0.32,36),Color(0.3,0.85,0.45,0.3))
