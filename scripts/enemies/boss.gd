class_name Boss
extends EnemyBase
## Jefe de etapa: lee GameManager.selected_boss y ejecuta un repertorio propio
## de habilidades (embestidas, salto-choque, anillos, ráfagas, teletransporte,
## invocaciones...). Cada habilidad tiene una fase de aviso con telegrafo visual
## y una fase de ejecución; a la mitad de vida entra la fase final (más rápida).

signal defeated

const Patterns := preload("res://scripts/enemies/boss_patterns.gd")
var attack_target := Vector2.ZERO
var _tell_length := 0.9
var encounter_history: Array = []

const BossVisualScript := preload("res://scripts/enemies/boss_visual.gd")
const BulletScript := preload("res://scripts/projectiles/bullet.gd")
const WalkerScript := preload("res://scripts/enemies/walker.gd")
const FlyerScript := preload("res://scripts/enemies/flyer.gd")
const TEX_BULLET := preload("res://assets/sprites/fx/bullet_enemy.png")
const TEX_BOMB := preload("res://assets/sprites/fx/bullet_bomb.png")

## Tiempo de aviso (telegrafo) por habilidad.
const TELLS := {
	"dash": 0.50, "jump": 0.45, "spread": 0.30, "burst": 0.30,
	"ring": 0.35, "spiral": 0.30, "homing": 0.35, "bomb": 0.40,
	"summon": 0.50, "sweep": 0.35, "teleport": 0.40, "omega": 0.62,
}

var boss_id := ""
var _cfg: Dictionary = {}
var _abilities: Array = []
var _color := Color.WHITE
var _mode := "air"
var _t := 0.0
var _dir := -1
var _base_y := 0.0
var _base_x := 0.0
var _prev_vy := 0.0
var _rage := false
var _visual: BossVisual

# Máquina de habilidades.
var _phase := "idle"        # idle | tell | act | wait
var _phase_t := 0.0
var _act := ""              # habilidad en curso
var _abil_i := 0
var _dash_dir := -1
var _dash_speed := 380.0
var _spiral := 0.0
var _contact_bonus := 0     # daño extra al embestir
var _shock_pending := false
var _burst_left := 0        # balas ráfaga pendientes (spread/burst)
var _burst_cd := 0.0
var _burst_ang := 0.0
var _burst_step := 0.2
var active := false

func _ready() -> void:
	if boss_id=="": boss_id = GameManager.selected_boss
	_cfg = GameManager.BOSSES.get(boss_id, GameManager.BOSSES["sierra"]).duplicate(true)
	_abilities = Patterns.moves(boss_id).duplicate()
	_cfg["tip"] = Patterns.COUNTERS.get(boss_id,"")
	_color = _cfg.get("color", Color.WHITE)
	_mode = _cfg.get("mode", "air")
	max_health = int(_cfg.get("hp", 80))
	contact_damage = int(_cfg.get("contact", 9))
	score_value = int(_cfg.get("score", 3000))
	use_gravity = _mode == "ground"
	drop_health_chance = 0.0
	setup_base()
	_visual = BossVisualScript.new()
	_visual.design = boss_id
	_visual.color = _color
	_visual.position = Vector2(0, -16)
	_visual.z_index = 1
	add_child(_visual)
	add_body_shape(42 if boss_id in ["coloso","estruendo"] else 30,36 if boss_id=="coloso" else 32,-18 if boss_id=="coloso" else -16)
	collision_mask = 1
	_base_y = global_position.y
	_base_x = global_position.x
	_phase_t = 1.2           # pequeño respiro tras aparecer
	GameManager.boss_health_changed.emit(health, max_health, false)

## Lo llama la etapa cuando el jugador entra a la arena.
func activate() -> void:
	if active or dead:
		return
	active = true
	GameManager.boss_health_changed.emit(health, max_health, true)
	GameManager.boss_activated.emit(boss_id, str(_cfg["name"]))
	GameManager.banner("¡PELIGRO!", "%s · %s" % [_cfg.get("name", "JEFE"), _cfg.get("epithet", "")], _color)
	GameManager.toast(str(_cfg["tip"]),_color)
	AudioManager.play("boss_roar", -4.0)
	GameManager.shake(4.0)
	FxScript.ring(get_parent(), global_position + Vector2(0, -16), Color(_color.r, _color.g, _color.b, 0.9), 6.0, 80.0, 0.5)

func _physics_process(delta: float) -> void:
	if dead or not active:
		return
	_t += delta
	_visual.motion = velocity.x
	_visual.motion_state = _phase
	_visual.clock = _phase_t
	_visual.shielded = boss_id=="enjambre" and _live_pods()>0
	contact_damage = int(_cfg.get("contact", 9)) + _contact_bonus
	if use_gravity:
		apply_gravity(delta)
	else:
		_hover(delta)

	var player := _nearest_player()
	if player:
		_dir = signi(int(signf(player.global_position.x - global_position.x)))
		if _dir == 0:
			_dir = 1
		facing = _dir
		_visual.scale.x = -1.0 if _dir < 0 else 1.0

	# Ráfagas pendientes (spread/burst): se resuelven en sub-pasos guiados
	if _burst_left > 0:
		_burst_cd -= delta
		if _burst_cd <= 0.0:
			_burst_left -= 1
			_fire_aimed(player, _burst_ang, 230.0)
			_burst_ang += _burst_step
			_burst_cd = 0.15

	match _phase:
		"idle":
			_move_idle(delta)
			_phase_t -= delta
			if _phase_t <= 0.0 and player:
				_begin_next()
		"tell":
			_dampen(delta)
			_phase_t -= delta
			if _phase_t <= 0.0:
				_execute()
		"act":
			_run_act(delta, player)
		"wait":
			_dampen(delta)
			_phase_t -= delta
			if _phase_t <= 0.0:
				_phase = "idle"
				_visual.phase = 0
				_phase_t = randf_range(0.9, 1.6) * (0.6 if _rage else 1.0)

	_prev_vy = velocity.y
	move_and_slide()
	if _shock_pending:
		_shock_pending = false
		_shockwave()

# ------------------------------------------------------------------ máq. de habilidades
func _begin_next() -> void:
	if _abilities.is_empty():
		_abilities = ["spread"]
	_act = String(_abilities[_abil_i % _abilities.size()])
	_abil_i += 1
	encounter_history.append(_act)
	attack_target = Patterns.target(self)
	var limits := Patterns.bounds(self)
	attack_target.x = clampf(attack_target.x,limits.x+24,limits.y-24)
	_phase = "tell"
	_tell_length = (1.1 if boss_id in ["coloso","estruendo"] else 0.9)*(0.88 if _rage else 1)
	_phase_t = _tell_length
	Patterns.telegraph(self)
	_visual.action = _act
	_visual.phase = 0
	# Aviso: anillo de color + sonido de carga
	FxScript.ring(get_parent(), global_position + Vector2(0, -16),
		Color(_color.r, _color.g, _color.b, 0.85), 6.0, 30.0, 0.3)
	AudioManager.play("chargeup", -14.0)

func _execute() -> void:
	_visual.phase = 1
	_phase = "act"
	_phase_t = Patterns.execute(self)
	var cue: Array = Patterns.SOUNDS.get(boss_id,["enemy_shoot",1.0])
	AudioManager.play(str(cue[0]),-10,float(cue[1]))


func _end_act() -> void:
	_phase = "wait"
	_phase_t = (1.35 if boss_id in ["coloso","estruendo"] else 0.95) * (0.85 if _rage else 1.0)
	_visual.action = ""
	_contact_bonus = 0

## Ejecución continua de las habilidades con duración (dash / jump).
func _run_act(delta: float, _player: Node) -> void:
	_phase_t -= delta
	Patterns.tick(self,delta)
	if _act=="quarry_slam" and is_on_floor() and _was_falling():
		_shock_pending = true
		_end_act()
	elif _phase_t<=0: _end_act()

func _was_falling() -> bool:
	# _prev_vy se guarda justo antes de move_and_slide: positivo = cayendo.
	return _prev_vy > 0.0

func _move_idle(delta: float) -> void:
	var speed: float = float(_cfg.get("speed",26))
	var distance := global_position.distance_to(Patterns.target(self))
	if boss_id=="estruendo":
		velocity.x = move_toward(velocity.x,-_dir*speed if distance<110 else 0,delta*90)
	elif boss_id=="coloso":
		velocity.x = move_toward(velocity.x,_dir*speed*0.65,delta*75)
	elif boss_id=="sierra":
		velocity.x = move_toward(velocity.x,_dir*speed*1.3,delta*350)
	else:
		var desired := -_dir*speed if distance<110 else _dir*speed*0.6
		velocity.x = move_toward(velocity.x,desired,delta*100)

func _hover(_delta: float) -> void:
	if _phase=="act" and _act=="fire_dive": return
	var amplitude := 16.0 if boss_id in ["glaciar","enjambre"] else 6.0
	var target_y := _base_y+sin(_t*(2.4 if boss_id=="enjambre" else 1.3))*amplitude
	velocity.y = (target_y-global_position.y)*3

func _dampen(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 480.0 * delta)

# ------------------------------------------------------------------ ataques
func _fire_aimed(player: Node, offset: float, speed: float) -> void:
	var base := 0.0
	if player:
		base = (player.global_position + Vector2(0, -12) - global_position).angle()
	var dir := Vector2.RIGHT.rotated(base + offset)
	var b := BulletScript.create(TEX_BULLET, global_position + Vector2(0, -14), dir, speed, 6, false, 1.0)
	b.color = _color
	b.rotation = dir.angle()
	get_parent().add_child(b)
	FxScript.muzzle(get_parent(), global_position + Vector2(0, -14), false, dir.angle(), _color)
	AudioManager.play("enemy_shoot", -12.0)

func _fire_ring(n: int) -> void:
	for i in n:
		var a := TAU * float(i) / float(n) + _spiral
		var b := BulletScript.create(TEX_BULLET, global_position + Vector2(0, -14),
			Vector2.RIGHT.rotated(a), 150.0, 5, false, 1.0)
		b.color = _color
		get_parent().add_child(b)
	_spiral += 0.35
	AudioManager.play("enemy_shoot", -10.0)

func _spiral_stream() -> void:
	for i in 4:
		var a := _spiral + TAU * float(i) / 4.0
		var b := BulletScript.create(TEX_BULLET, global_position + Vector2(0, -14),
			Vector2.RIGHT.rotated(a), 170.0, 5, false, 1.0)
		b.color = _color
		get_parent().add_child(b)
	_spiral += 0.5
	AudioManager.play("enemy_shoot", -10.0)

func _fire_homing(n: int) -> void:
	var player := _nearest_player()
	for i in n:
		var a := -0.6 + 0.6 * float(i)
		var dir := Vector2.RIGHT.rotated(a + (0.0 if _dir > 0 else PI))
		var b := BulletScript.create(TEX_BULLET, global_position + Vector2(0, -14), dir, 90.0, 7, false, 1.2)
		b.color = _color
		if player:
			b.homing_target = player
			b.homing_strength = 2.2
		b.life = 4.0
		get_parent().add_child(b)
	AudioManager.play("enemy_shoot", -10.0)

func _omega_barrage() -> void:
	# Ataque exclusivo del Nucleo Omega: dos coronas contrarrotadas y misiles
	# dirigidos a distintos pilotos. Obliga al equipo a separarse y reposicionarse.
	_fire_ring(16 if _rage else 12)
	_spiral += PI/12.0
	_fire_ring(12 if _rage else 8)
	var players: Array = []
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_method("is_alive") and p.is_alive(): players.append(p)
	for i in players.size():
		var target: Node2D = players[i] as Node2D
		if target == null:
			continue
		var spread_angle: float = (float(i) - (float(players.size()) - 1.0) * 0.5) * 0.18
		var dir: Vector2 = (target.global_position - global_position).normalized().rotated(spread_angle)
		var b := BulletScript.create(TEX_BULLET,global_position+Vector2(0,-14),dir,115.0,8,false,1.35)
		b.color = _color
		b.homing_target = target
		b.homing_strength = 2.8 if _rage else 2.1
		b.life = 4.5
		get_parent().add_child(b)
	GameManager.shake(3.5)
	AudioManager.play("boss_roar",-10.0,1.15)

func _drop_bombs() -> void:
	var offs := [-0.5, -0.25, 0.0, 0.25, 0.5] if _rage else [-0.4, 0.0, 0.4]
	for i in offs:
		var dir := Vector2.RIGHT.rotated(-PI * 0.5 + float(i))
		var b := BulletScript.create(TEX_BOMB, global_position + Vector2(0, -6),
			dir, 130.0, 7, false, 1.2)
		b.grav_accel = 420.0
		b.color = _color
		get_parent().add_child(b)
	AudioManager.play("enemy_shoot", -12.0)

## Barrido: abanico rápido alineado con el suelo (para jefes aéreos).
func _sweep() -> void:
	var n := 5 if _rage else 3
	var base := 0.0 if _dir > 0 else PI
	for i in n:
		var a := base + lerpf(-0.35, 0.35, float(i) / float(maxi(n - 1, 1)))
		var b := BulletScript.create(TEX_BULLET, global_position + Vector2(_dir * 10.0, -8.0),
			Vector2.RIGHT.rotated(a), 200.0, 5, false, 1.1)
		b.color = _color
		b.rotation = a
		get_parent().add_child(b)
	AudioManager.play("enemy_shoot", -10.0)

## Teletransporte: desaparece y reaparece al otro lado del jugador con anillo.
func _teleport_burst() -> void:
	var player := _nearest_player()
	FxScript.ring(get_parent(), global_position + Vector2(0, -16),
		Color(_color.r, _color.g, _color.b, 0.9), 8.0, 36.0, 0.3)
	AudioManager.play("dash", -10.0, 0.7)
	if player:
		var side := -1.0 if player.global_position.x > global_position.x else 1.0
		global_position = player.global_position + Vector2(side * randf_range(70.0, 110.0), -10.0)
		global_position.y = _base_y
		# Sin salirse de la arena (spawn = arena_x + 320, ancho 400)
		global_position.x = clampf(global_position.x, _base_x - 290.0, _base_x + 70.0)
	FxScript.ring(get_parent(), global_position + Vector2(0, -16),
		Color(1, 1, 1, 0.9), 4.0, 30.0, 0.3)
	# Contragolpe: anillo de balas al materializarse
	_fire_ring(6 if _rage else 4)

func _summon() -> void:
	var n := 3 if _rage else 2
	for i in n:
		var f := preload("res://scripts/enemies/zone_enemy.gd").new()
		f.zone = "biolab" if boss_id=="enjambre" else "central"
		f.airborne = true
		f.position = global_position + Vector2(randf_range(-40, 40), randf_range(-30, -10))
		get_parent().add_child(f)
	AudioManager.play("enemy_shoot", -8.0)
	FxScript.ring(get_parent(), global_position + Vector2(0, -14), Color(0.4, 1, 0.4, 0.9), 6.0, 30.0, 0.3)

## Onda de choque al caer / chocar: daño cercano + anillo + sacudida.
func _shockwave() -> void:
	FxScript.ring(get_parent(), global_position + Vector2(0, -2),
		Color(_color.r, _color.g, _color.b, 0.9), 6.0, 70.0, 0.35)
	GameManager.shake(4.0)
	AudioManager.play("explode", -10.0)
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_method("take_damage") and absf(p.global_position.x - global_position.x) < 70.0 \
				and absf(p.global_position.y - global_position.y) < 40.0:
			p.take_damage(6, global_position)

func _nearest_player() -> Node2D:
	var best: Node2D = null
	var bd := INF
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p):
			continue
		if p.has_method("is_alive") and not p.is_alive():
			continue
		var d: float = p.global_position.distance_squared_to(global_position)
		if d < bd:
			bd = d
			best = p
	return best


# ------------------------------------------------------------------ daño / muerte
func take_damage(amount: int, from_pos: Vector2) -> void:
	if not active:
		return
	var actual := amount
	if boss_id=="estruendo" and _phase!="wait" and (from_pos.x-global_position.x)*_dir>0:
		actual = maxi(1,roundi(amount*0.65))
	if boss_id=="enjambre" and _live_pods()>0: actual = maxi(1,ceili(actual*0.6))
	if _phase=="wait" and boss_id in ["sierra","coloso"]: actual = ceili(amount*1.3)
	super.take_damage(actual, from_pos)
	_flash = 0.1
	if _visual:
		_visual.modulate = Color(6, 6, 6)
	if not dead:
		GameManager.boss_health_changed.emit(maxi(health, 0), max_health, true)
		if not _rage and health <= float(max_health) / 2.0:
			_enter_rage()

## Fase final: visores rojos, ataque más rápido y contragolpe inicial.
func _enter_rage() -> void:
	_rage = true
	if _visual:
		_visual.rage = true
	GameManager.banner("¡FASE FINAL!", "%s SE ENFURECE" % _cfg.get("name", "EL JEFE"), _color)
	GameManager.shake(4.0)
	AudioManager.play("boss_roar", -6.0)
	FxScript.ring(get_parent(), global_position + Vector2(0, -16), Color(1, 0.3, 0.2, 0.95), 8.0, 90.0, 0.5)
	# Each identity enters its own second-phase opening, with a full readable warning.
	_burst_left = 0
	_abil_i = 2
	_contact_bonus = 0
	_begin_next()

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0 and _visual:
			_visual.modulate = Color.WHITE

func die() -> void:
	if dead:
		return
	GameManager.boss_health_changed.emit(0, max_health, false)
	GameManager.shake(6.0)
	GameManager.hitstop(0.12)
	FxScript.explosion(get_parent(), global_position + Vector2(0, -16), 2.6)
	FxScript.ring(get_parent(), global_position + Vector2(0, -14), Color(1, 0.85, 0.4, 0.95), 6.0, 90.0, 0.6)
	for i in 12:
		FxScript.explosion(get_parent(), global_position + Vector2(randf_range(-24, 24), randf_range(-30, 10)), randf_range(0.8, 1.6))
	defeated.emit()
	super.die()



func _live_pods() -> int:
	var count := 0
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		if h.kind=="pod" and not h.dead and h.source and h.source.get_ref()==self: count += 1
	return count
