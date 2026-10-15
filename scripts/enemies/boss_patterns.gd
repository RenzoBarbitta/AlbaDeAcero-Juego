extends RefCounted
## Each boss owns an attack grammar, warning geometry and a distinct rage sequence.
const HAZARD := preload("res://scripts/enemies/boss_hazard.gd")
const MOVES := {
	"sierra":["return_discs","ricochet","cross_cut"],
	"estruendo":["artillery","siege","mortar"],
	"glaciar":["ice_lanes","crystal_fan","whiteout"],
	"incendio":["geysers","fire_dive","flame_lane"],
	"voltaje":["conductors","low_rail","high_rail"],
	"coloso":["quarry_slam","fault_lines","rockfall"],
	"espectro":["shadow_marks","blink_hunt","phantom_lanes"],
	"enjambre":["brood","stingers","nest_guard"],
	"nucleo":["omega_lanes","omega_orbits","omega_cross"]
}
const SOUNDS := {"sierra":["dash",0.85],"estruendo":["bigshot",0.7],"glaciar":["charged",1.4],"incendio":["bigshot",1.15],"voltaje":["charged",0.7],"coloso":["bighit",0.65],"espectro":["dash",0.55],"enjambre":["enemy_shoot",1.7],"nucleo":["boss_roar",1.25]}
const COUNTERS := {
	"sierra":"SALTA LOS DISCOS / CASTIGA SU RECUPERACION",
	"estruendo":"SAL DE LAS MARCAS / ATACA POR LA ESPALDA",
	"glaciar":"MUEVETE ENTRE CARRILES ANTES DE LA LLUVIA",
	"incendio":"SALTA EL FUEGO BAJO / EVITA LOS GEISERES",
	"voltaje":"SALTA EL RIEL BAJO / QUEDATE ABAJO DEL ALTO",
	"coloso":"ALEJATE DEL IMPACTO / ATACA CUANDO DESCANSA",
	"espectro":"LAS SOMBRAS MARCAN EL ATAQUE / CAMBIA DE SITIO",
	"enjambre":"ROMPE LOS NIDOS PARA DEBILITAR SU ESCUDO",
	"nucleo":"BUSCA LOS HUECOS / CAMBIA DE CARRIL"
}
static func moves(id: String) -> Array: return MOVES.get(id,MOVES["sierra"])
static func bounds(b: Node2D) -> Vector2:
	var stage := b.get_parent()
	if stage.has_method("horde_snapshot"): return Vector2(24,936)
	return Vector2(b._base_x-290,b._base_x+60)
static func target(b: Node2D) -> Vector2:
	var p: Node2D = b._nearest_player()
	return p.global_position if is_instance_valid(p) else b.global_position+Vector2(-80,0)
static func hazard(b: Node2D,kind: String,at: Vector2,size: Vector2,warning: float,duration: float,velocity := Vector2.ZERO) -> Node2D:
	var h := HAZARD.new()
	h.kind = kind
	h.position = at
	h.size = size
	h.warn = warning
	h.duration = duration
	h.velocity = velocity
	h.color = b._color
	h.source = weakref(b)
	h.return_to = b.global_position+Vector2(0,-16)
	b.get_parent().add_child(h)
	return h
static func telegraph(b: Node2D) -> void:
	var limits := bounds(b)
	var at: Vector2 = b.attack_target
	var windup: float = b._tell_length
	var width := limits.y-limits.x
	var count := 4 if b._rage else 3
	match b._act:
		"artillery":
			for i in count:
				var x := clampf(at.x+(i-1)*76,limits.x+22,limits.y-22)
				hazard(b,"flame",Vector2(x,126),Vector2(32,48),windup+i*0.28,0.4)
		"rockfall","ice_lanes":
			for i in count:
				var x := clampf(at.x+(i-1)*76,limits.x+22,limits.y-22)
				hazard(b,"rock" if b._act=="rockfall" else "spike",Vector2(x,-8),Vector2(22,32),windup+i*0.25,1.2,Vector2(0,145))
		"geysers","fault_lines":
			for i in 4:
				var x := lerpf(limits.x+24,limits.y-24,float(i)/3)
				hazard(b,"flame" if b.boss_id=="incendio" else "rock",Vector2(x,122),Vector2(30,56),windup+i*0.24,0.48)
		"conductors","omega_lanes":
			for i in 3:
				var x := lerpf(limits.x+30,limits.y-30,float(i)/2)
				hazard(b,"beam",Vector2(x,70),Vector2(14,160),windup+i*0.18,0.5)
		"low_rail","high_rail":
			hazard(b,"beam",Vector2((limits.x+limits.y)*0.5,138 if b._act=="low_rail" else 94),Vector2(width,7),windup,0.48)
		"flame_lane":
			hazard(b,"flame",Vector2(limits.x+20,136),Vector2(44,28),windup,2.5,Vector2(110,0))
		"shadow_marks","phantom_lanes":
			for i in 3:
				var x := clampf(at.x+(i-1)*82,limits.x+20,limits.y-20)
				hazard(b,"ghost",Vector2(x,125),Vector2(30,46),windup+i*0.2,0.65)
		"fire_dive","quarry_slam","blink_hunt":
			hazard(b,"flame" if b.boss_id=="incendio" else ("ghost" if b.boss_id=="espectro" else "rock"),Vector2(at.x,126),Vector2(48,48),windup+0.45,0.45)

static func execute(b: Node2D) -> float:
	var at: Vector2 = b.attack_target
	var limits := bounds(b)
	match b._act:
		"return_discs":
			for i in (3 if b._rage else 2):
				var dir := (at-b.global_position-Vector2(0,14)).normalized().rotated((i-0.5)*0.22)
				hazard(b,"saw",b.global_position+Vector2(0,-16),Vector2(22,22),0,2.4,dir*165)
			return 1.1
		"cross_cut":
			for side in [-1,1]:
				hazard(b,"saw",Vector2(limits.x if side==1 else limits.y,132),Vector2(22,22),0.3,2.2,Vector2(side*150,0))
			return 1.1
		"ricochet":
			b._dash_dir = b._dir
			b._dash_speed = 230 if b._rage else 190
			b._contact_bonus = 2
			return 1.2
		"mortar":
			for i in 3:
				var speed_x := (at.x-b.position.x)/1.2+(i-1)*28
				var bomb := hazard(b,"orb",b.global_position+Vector2(0,-25),Vector2(15,15),0.1,2.0,Vector2(speed_x,-240))
				bomb.acceleration = Vector2(0,420)
			return 1.2
		"whiteout":
			for row in [70,144]:
				var x: float = limits.y if b._dir<0 else limits.x
				hazard(b,"spike",Vector2(x,row),Vector2(18,12),0.35,3.0,Vector2(b._dir*115,0))
			return 1.0
		"siege":
			for i in 3:
				var dir := (at-b.global_position).normalized().rotated(-0.25+i*0.25)
				hazard(b,"orb",b.global_position+Vector2(0,-20),Vector2(13,13),0,2.3,dir*155)
			return 0.7
		"crystal_fan":
			for i in 5:
				var dir := Vector2.DOWN.rotated(-0.9+i*0.45)
				hazard(b,"spike",b.global_position+Vector2(0,-14),Vector2(10,20),0,2.0,dir*105)
			return 0.9
		"fire_dive","quarry_slam":
			b.velocity = Vector2((at.x-b.global_position.x)*1.7,-260 if b.boss_id=="coloso" else 0)
			return 0.8 if b.boss_id=="incendio" else 1.8
		"blink_hunt":
			b.global_position = Vector2(clampf(at.x-b._dir*70,limits.x+20,limits.y-20),b._base_y)
			return 0.65
		"brood","nest_guard":
			var pods := b.get_tree().get_nodes_in_group("boss_hazard").filter(func(h): return h.kind=="pod" and h.source and h.source.get_ref()==b)
			if pods.size()<3:
				for i in 2:
					hazard(b,"pod",Vector2(clampf(b.position.x-90+i*180,limits.x+25,limits.y-25),126),Vector2(24,24),0.45,7)
			if b._act=="brood": b._summon()
			else:
				for pod in b.get_tree().get_nodes_in_group("boss_hazard"):
					if pod.kind=="pod" and pod.source and pod.source.get_ref()==b:
						hazard(b,"orb",pod.position,Vector2(12,12),0.45,2.4,pod.position.direction_to(at)*105)
			return 0.8
		"omega_cross":
			hazard(b,"beam",Vector2((limits.x+limits.y)*0.5,136),Vector2(limits.y-limits.x,7),0.7,0.4)
			for part in [0.25,0.75]: hazard(b,"beam",Vector2(lerpf(limits.x,limits.y,part),65),Vector2(12,170),1.2,0.45)
			return 1.5
		"stingers","omega_orbits":
			var n := 7 if b.boss_id=="nucleo" else 5
			for i in n:
				var dir := Vector2.RIGHT.rotated(TAU*i/float(n)+b._spiral)
				hazard(b,"orb",b.global_position+Vector2(0,-16),Vector2(14,14),0.15,2.4,dir*(120 if b._rage else 90))
			b._spiral += 0.45
			return 1.0
	return 0.8

static func tick(b: Node2D,delta: float) -> void:
	match b._act:
		"ricochet":
			b.velocity.x = b._dash_dir*b._dash_speed
			if b.is_on_wall(): b._dash_dir *= -1
		"fire_dive": b.velocity = b.global_position.direction_to(b.attack_target-Vector2(0,12))*180
		"quarry_slam": pass
		_: b.velocity.x = move_toward(b.velocity.x,0,delta*400)
