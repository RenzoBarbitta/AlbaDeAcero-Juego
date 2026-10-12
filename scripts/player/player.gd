class_name Player
extends CharacterBody2D
## Robot protagonista: corre, salta (altura variable), hace dash y dispara con
## el pulso de energía (carga de 3 niveles) o las armas especiales. Soporta 2
## jugadores locales (coop) mediante un índice de entrada.

signal died(index: int)

const BulletScript := preload("res://scripts/projectiles/bullet.gd")
const FxScript := preload("res://scripts/fx/fx.gd")
const PilotVisual := preload("res://scripts/player/pilot_visual.gd")

# --- Texturas de proyectiles (por arma) ---
const WEAPON_TEX := {
	"buster": preload("res://assets/sprites/fx/bullet_player.png"),
	"charged": preload("res://assets/sprites/fx/bullet_charged.png"),
	"spread": preload("res://assets/sprites/fx/bullet_spread.png"),
	"laser": preload("res://assets/sprites/fx/bullet_laser_player.png"),
	"plasma": preload("res://assets/sprites/fx/bullet_plasma.png"),
}

const CHARGE_COLORS := [Color("ffe14d"), Color("8be9ff"), Color("ff6a5a"), Color("c07dff")]

# --- Física ---
const RUN_SPEED := 112.0
const ACCEL := 950.0
const FRICTION := 1400.0
const AIR_ACCEL := 640.0
const GRAVITY := 900.0
const FALL_MAX := 400.0
const JUMP_VELOCITY := -305.0
const JUMP_CUT := 0.42
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12
const DASH_SPEED := 280.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.5

# --- Disparo ---
const CHARGE_L1 := 0.32
const CHARGE_L2 := 0.82
const CHARGE_L3 := 1.5
const PULSE_COOLDOWN := 0.13
const SPREAD_COOLDOWN := 0.20
const LASER_COOLDOWN := 0.09
const PLASMA_COOLDOWN := 0.40

var index := 0
var facing := 1
var aim := Vector2(1, 0)
var alive := true
var character := "orange"
var weapon := "buster"
var net_on_floor := true
var damage_level := 0
var armor_level := 0
var fire_level := 0
var bonus_mobility: Array = []
var jet_active := false
var jet_fuel := 1.0
var launch_speed := 0.0
var launch_time := 0.0
var air_jumps := 0
var jump_hold := 0.0
var landing_squash := 0.0

func has_mobility(id: String) -> bool:
	return GameManager.mobility.has(id) or bonus_mobility.has(id)

var _remote_previous := {}
var _remote_edges := {}
var _remote_released := {}

func pressed(action: String) -> bool:
	if NetSession.local_shop_open and index==(NetSession.local_index if NetSession.online else 0): return false
	if NetSession.online and NetSession.host and index > 0:
		return bool(NetSession.input_for(index).get(action,false))
	return Input.is_action_pressed(_act(action))

func pressed_once(action: String) -> bool:
	if NetSession.local_shop_open and index==(NetSession.local_index if NetSession.online else 0): return false
	if NetSession.online and NetSession.host and index > 0:
		return bool(_remote_edges.get(action,false))
	return Input.is_action_just_pressed(_act(action))

func released_once(action: String) -> bool:
	if NetSession.local_shop_open and index==(NetSession.local_index if NetSession.online else 0): return false
	if NetSession.online and NetSession.host and index > 0:
		return bool(_remote_released.get(action,false))
	return Input.is_action_just_released(_act(action))

func axis(left: String,right: String) -> float:
	return float(pressed(right))-float(pressed(left))

var _sprite: AnimatedSprite2D
var _arm: Sprite2D
var _camera: Camera2D
var _hurtbox: Area2D
var _color := Color.WHITE

var _coyote := 0.0
var _jump_buffer := 0.0
var _dash_time := 0.0
var _dash_cd := 0.0
var _col_cooldown := 0.0
var _was_on_floor := true
var _air_dash_used := false

var _charging := false
var _charge_t := 0.0
var _charge_fx: Node = null
var _charge_pulse := 0.0
var _shoot_cooldown := 0.0

var _invuln := 0.0
var _spawn_point := Vector2.ZERO
var _knock := Vector2.ZERO

func setup(idx: int, char_id: String) -> void:
	index = idx
	character = char_id

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 8
	floor_snap_length = 6.0
	add_to_group("player")
	if index == 0 and not GameManager.coop:
		character = GameManager.character
	_color = GameManager.CHARACTERS.get(character, {}).get("color", Color.WHITE)
	_spawn_point = global_position
	weapon = GameManager.CHARACTERS.get(character, {}).get("primary", "buster")
	_build_sprite()
	_build_collision()
	_build_hurtbox()
	_build_camera()
	if index == 0:
		GameManager.character_changed.connect(set_character)

# ------------------------------------------------------------------
# Construcción
# ------------------------------------------------------------------
func _act(action_id: String) -> String:
	return action_id if index == 0 else "p2_%s" % action_id

func _tex_dir() -> String:
	return "res://assets/sprites/player/%s/" % (character if character in ["orange","red","black","violet"] else "orange")

func set_character(id: String) -> void:
	character = id
	_color = GameManager.CHARACTERS.get(id, {}).get("color", Color.WHITE)
	if _sprite:
		_sprite.sprite_frames = _make_frames(_tex_dir())
		_sprite.play("idle")
	if _arm:
		_arm.texture = load("res://assets/sprites/ui/arm_%s.png" % (character if character in ["orange","red","black","violet"] else "orange"))

func _build_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _make_frames(_tex_dir())
	_sprite.position = Vector2(0, -14)
	_sprite.z_index = 2
	add_child(_sprite)
	_sprite.play("idle")
	_build_arm()
	_sprite.visible = false
	_arm.visible = false
	var art := PilotVisual.new()
	art.actor = self
	art.pilot = character
	art.z_index = 3
	add_child(art)

func _build_arm() -> void:
	_arm = Sprite2D.new()
	_arm.texture = load("res://assets/sprites/ui/arm_%s.png" % (character if character in ["orange","red","black","violet"] else "orange"))
	_arm.position = Vector2(facing * 6, -15)
	_arm.z_index = 3
	add_child(_arm)

func _update_arm() -> void:
	if _arm == null:
		return
	_arm.position = Vector2(facing * 6, -15)
	_arm.rotation = aim.angle()

func _make_frames(dir: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	_add_anim(sf, "idle", [load(dir + "idle_0.png"), load(dir + "idle_1.png")], 3.0, true)
	_add_anim(sf, "run", [
		load(dir + "run_0.png"), load(dir + "run_1.png"),
		load(dir + "run_2.png"), load(dir + "run_3.png")], 14.0, true)
	_add_anim(sf, "jump", [load(dir + "jump.png")], 1.0, false)
	_add_anim(sf, "fall", [load(dir + "fall.png")], 1.0, false)
	_add_anim(sf, "dash", [load(dir + "dash.png")], 1.0, false)
	_add_anim(sf, "shoot", [load(dir + "shoot.png")], 1.0, false)
	return sf

func _add_anim(sf: SpriteFrames, animation_id: String, texs: Array, fps: float, loop: bool) -> void:
	sf.add_animation(animation_id)
	sf.set_animation_speed(animation_id, fps)
	sf.set_animation_loop(animation_id, loop)
	for t in texs:
		sf.add_frame(animation_id, t)

func _build_collision() -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 26)
	cs.shape = r
	cs.position = Vector2(0, -13)
	add_child(cs)

func _build_hurtbox() -> void:
	_hurtbox = Area2D.new()
	_hurtbox.collision_layer = 2
	_hurtbox.collision_mask = 4 | 64     # cuerpos enemigos (l3) + peligros (l7)
	_hurtbox.monitoring = true
	_hurtbox.monitorable = true
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 24)
	cs.shape = r
	cs.position = Vector2(0, -13)
	_hurtbox.add_child(cs)
	_hurtbox.area_entered.connect(_on_hurt_area)
	_hurtbox.body_entered.connect(_on_hurt_body)
	add_child(_hurtbox)

func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.position = Vector2(0, -12)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	_camera.zoom = Vector2.ONE
	_camera.limit_smoothed = true
	add_child(_camera)
	if not GameManager.coop:
		_camera.make_current()
	else:
		_camera.enabled = false

func set_camera_limits(rect: Rect2) -> void:
	if _camera == null:
		return
	_camera.limit_left = int(rect.position.x)
	_camera.limit_top = int(rect.position.y)
	_camera.limit_right = int(rect.position.x + rect.size.x)
	_camera.limit_bottom = int(rect.position.y + rect.size.y)

func get_camera() -> Camera2D:
	return _camera

func shake(amount: float) -> void:
	GameManager.shake(amount)

# ------------------------------------------------------------------
# Bucle principal
# ------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if not alive:
		return
	if NetSession.online and NetSession.host and index > 0:
		for action in ["move_left","move_right","aim_up","aim_down","jump","dash","shoot","weapon_switch","interact","team_attack"]:
			_remote_edges[action] = pressed(action) and not bool(_remote_previous.get(action,false))
			_remote_released[action] = not pressed(action) and bool(_remote_previous.get(action,false))

	landing_squash = maxf(0,landing_squash-delta*6)
	_update_timers(delta)

	if _dash_time > 0.0:
		_do_dash(delta)
	else:
		_do_move(delta)
		_do_gravity(delta)
		_do_jump(delta)
		_do_jetpack(delta)

	if launch_time>0:
		launch_time -= delta
		velocity.x = launch_speed
	move_and_slide()
	_landing_check()
	_update_aim()
	_handle_shooting(delta)
	_update_animation()
	_update_invuln(delta)
	if NetSession.online and NetSession.host and index > 0:
		_remote_previous = NetSession.input_for(index).duplicate()

func _update_timers(delta: float) -> void:
	_coyote = maxf(0.0, _coyote - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_col_cooldown = maxf(0.0, _col_cooldown - delta)
	_shoot_cooldown = maxf(0.0, _shoot_cooldown - delta*(1+fire_level*0.15))
	if is_on_floor():
		_coyote = COYOTE_TIME

func _do_move(delta: float) -> void:
	var dir := axis("move_left","move_right")
	if dir != 0.0:
		facing = signi(int(dir))
	var target := dir * RUN_SPEED * float(GameManager.CHARACTERS[character].get("speed",1))
	if GameManager.coop and not NetSession.online:
		for ally in get_tree().get_nodes_in_group("player"):
			if ally != self:
				var separation: float = global_position.x-ally.global_position.x
				if absf(separation) > 430 and signf(dir) == signf(separation):
					target *= clampf((480-absf(separation))/50,0,1)
	var a := (ACCEL * GameManager.accel_mul) if is_on_floor() else AIR_ACCEL
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, target, a * delta)
	else:
		var fr := FRICTION * GameManager.friction_mul if is_on_floor() else FRICTION
		velocity.x = move_toward(velocity.x, 0.0, fr * delta)
	if _knock.length() > 1.0:
		velocity += _knock
		_knock = Vector2.ZERO

func _do_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * (0.72 if absf(velocity.y)<60 and pressed("jump") else 1.0) * delta, FALL_MAX)

func _do_jump(_delta: float) -> void:
	if is_on_floor():
		air_jumps = 0
		jet_fuel = minf(1,jet_fuel+_delta*1.8)
	if pressed_once("jump"):
		_jump_buffer = JUMP_BUFFER
	if is_on_floor():
		_air_dash_used = false
	if pressed_once("dash") and _dash_cd <= 0.0 and (is_on_floor() or not _air_dash_used):
		if not is_on_floor():
			_air_dash_used = true
		_start_dash()
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0
		AudioManager.play("jump", -10.0)
		FxScript.ring(get_parent(), global_position + Vector2(0, 4), Color(_color.r, _color.g, _color.b, 0.8), 2.0, 12.0, 0.2)
	elif pressed_once("jump") and not is_on_floor() and air_jumps==0 and has_mobility("double_jump"):
		velocity.y = -295
		air_jumps = 1
		_jump_buffer = 0
		FxScript.ring(get_parent(),global_position,Color("63ffc3"),4,24,0.25)
	if released_once("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT

func _do_jetpack(delta: float) -> void:
	jump_hold = jump_hold+delta if pressed("jump") else 0.0
	jet_active = has_mobility("jetpack") and not is_on_floor() and pressed("jump") and jump_hold>0.25 and jet_fuel>0 and velocity.y>-160
	if jet_active:
		velocity.y = move_toward(velocity.y,-110,1100*delta)
		jet_fuel = maxf(0,jet_fuel-delta/1.8)

func _start_dash() -> void:
	if GameManager.coop and not NetSession.online:
		for ally in get_tree().get_nodes_in_group("player"):
			if ally != self and absf(global_position.x-ally.global_position.x) > 450 and facing == int(signf(global_position.x-ally.global_position.x)):
				return
	_dash_time = DASH_TIME
	_dash_cd = DASH_COOLDOWN
	velocity.y = 0.0
	AudioManager.play("dash", -10.0)
	FxScript.ring(get_parent(), global_position + Vector2(0, -10), Color(_color.r, _color.g, _color.b, 0.7), 3.0, 16.0, 0.25)

func _do_dash(_delta: float) -> void:
	_dash_time -= _delta
	velocity.x = facing * DASH_SPEED
	velocity.y = 0.0
	if _sprite:
		_sprite.modulate = Color(_color.r, _color.g, _color.b, 1.0)

func _landing_check() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		landing_squash = 1.0
		AudioManager.play("land", -14.0)
		for i in 4:
			FxScript.spark(get_parent(), global_position + Vector2(randf_range(-5, 5), 2), Color(0.8, 0.85, 1.0))
	_was_on_floor = on_floor

# ------------------------------------------------------------------
# Apuntado y disparo
# ------------------------------------------------------------------
func _update_aim() -> void:
	if NetSession.online and NetSession.host and index > 0:
		var data: Array = NetSession.input_for(index).get("aim",[float(facing),0.0])
		aim = Vector2(float(data[0]),float(data[1])).normalized()
		if absf(aim.x)>0.1: facing = int(signf(aim.x))
		_update_arm()
		return
	var up := pressed("aim_up")
	var down := pressed("aim_down")
	if up or down:
		var h := axis("move_left","move_right")
		if h != 0.0:
			facing = signi(int(h))
		var v := -1.0 if up else 1.0
		if h == 0.0:
			aim = Vector2(0, v)
		else:
			aim = Vector2(signf(h), v).normalized()
	else:
		if index == 1:
			aim = Vector2(facing,0)
			_update_arm()
			return
		var pivot := global_position + Vector2(facing * 6, -19)
		var d := get_global_mouse_position() - pivot
		if d.length() < 2.0:
			d = Vector2(facing, 0)
		aim = d.normalized()
		if absf(aim.x) > 0.1:
			facing = int(signf(aim.x))
	if _sprite:
		_sprite.flip_h = facing < 0
	_update_arm()

func _handle_shooting(delta: float) -> void:
	if pressed_once("weapon_switch"):
		_cycle_weapon()
	if GameManager.POWERS.has(weapon):
		_end_charge()
		if pressed("shoot") and _shoot_cooldown <= 0:
			_fire_power()
			_shoot_cooldown = GameManager.POWERS[weapon]["cooldown"]
		return

	match weapon:
		"needles","grenade","rail","drones":
			_end_charge()
			if pressed("shoot") and _shoot_cooldown<=0:
				_fire_special_primary()
		"spread":
			_end_charge()
			if pressed("shoot") and _shoot_cooldown <= 0.0:
				_fire_spread()
				_shoot_cooldown = SPREAD_COOLDOWN
		"laser":
			_end_charge()
			if pressed("shoot") and _shoot_cooldown <= 0.0:
				_fire_laser()
				_shoot_cooldown = LASER_COOLDOWN
		"plasma":
			_end_charge()
			if pressed("shoot") and _shoot_cooldown <= 0.0:
				_fire_plasma()
				_shoot_cooldown = PLASMA_COOLDOWN
		_:
			_shoot_buster(delta)

func _fire_special_primary() -> void:
	var count := 3 if weapon=="drones" else (2 if weapon=="needles" else 1)
	for i in count:
		var direction := aim.rotated((i-(count-1)*0.5)*0.16)
		var speed := 500.0 if weapon in ["needles","rail"] else 220.0
		var shot := BulletScript.create(WEAPON_TEX["laser" if weapon=="rail" else "plasma"],_muzzle_pos(),direction,speed,10 if weapon in ["rail","grenade"] else 3,true,0.65 if weapon=="needles" else 1.0)
		shot.color = _color
		if weapon=="grenade":
			shot.grav_accel = 360
			shot.velocity += Vector2(0,-70)
			shot.effect = "estruendo"
		if weapon=="rail":
			shot.pierce = true
			shot.pierce_left = 7
		if weapon=="drones":
			var closest: Node2D
			var distance := 320.0
			for enemy in get_tree().get_nodes_in_group("enemy"):
				var d := global_position.distance_to(enemy.global_position)
				if not enemy.dead and d<distance:
					distance = d
					closest = enemy
			shot.homing_target = closest
			shot.homing_strength = 5
		_spawn_bullet(shot)
	_shoot_cooldown = {"needles":0.22,"grenade":0.65,"rail":0.55,"drones":0.75}[weapon]
	AudioManager.play("shoot",-12)

func _cycle_weapon() -> void:
	var ids: Array = []
	for id in GameManager.unlocked:
		if GameManager.unlocked[id]: ids.append(id)
	var primary: String = GameManager.CHARACTERS[character]["primary"]
	if not ids.has(primary):
		ids.push_front(primary)
	if ids.size() <= 1:
		return
	var i := ids.find(weapon)
	weapon = ids[(i + 1) % ids.size()]
	_end_charge()
	GameManager.toast("P%d: %s" % [index+1,GameManager.weapon_name(weapon)],_color)
	if index == 0:
		GameManager.current_weapon = weapon
		GameManager.weapon_changed.emit(weapon)
	AudioManager.play("select", -14.0)

func equip_power(id: String) -> void:
	weapon = id
	_end_charge()
	_shoot_cooldown = 0

func _fire_power() -> void:
	var col: Color = GameManager.BOSSES[weapon]["color"]
	var targets: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.dead and global_position.distance_to(e.global_position) < 300:
			targets.append(e)
	targets.sort_custom(func(a,b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	if weapon == "voltaje":
		var last := _muzzle_pos()
		for e in targets.slice(0,3):
			var beam := Line2D.new()
			beam.points = PackedVector2Array([last,last.lerp(e.global_position,0.5)+Vector2(4,-8),e.global_position+Vector2(0,-8)])
			beam.width = 2
			beam.default_color = col
			get_parent().add_child(beam)
			var tween := beam.create_tween()
			tween.tween_property(beam,"modulate:a",0.0,0.22)
			tween.tween_callback(beam.queue_free)
			e.take_damage(6,last)
			last = e.global_position
			GameManager.register_hit()
		if targets.is_empty():
			_power_bullet(aim,500,5,col)
	else:
		var count := 1
		if weapon in ["glaciar","enjambre"]:
			count = 3
		elif weapon == "incendio":
			count = 10
		elif weapon == "coloso":
			count = 2
		for i in count:
			var dir := aim
			if count == 3:
				dir = aim.rotated((i-1)*0.22)
			elif weapon == "incendio":
				dir = Vector2.RIGHT.rotated(TAU*float(i)/count)
			elif weapon == "coloso":
				dir = Vector2(-1 if i == 0 else 1,0)
			var b := _power_bullet(dir,210 if weapon == "estruendo" else 280,8 if weapon in ["coloso","estruendo"] else 4,col)
			b.effect = weapon
			b.origin = self
			if weapon == "sierra":
				b.pierce = true
				b.pierce_left = 5
				b.life = 1.8
			elif weapon == "estruendo":
				b.grav_accel = 330
				b.velocity = (aim+Vector2(0,-0.6)).normalized()*200
				b.life = 1.3
			elif weapon in ["espectro","enjambre"] and not targets.is_empty():
				b.homing_target = targets[i%targets.size()]
				b.homing_strength = 5
			elif weapon == "incendio":
				b.life = 0.55
			elif weapon == "coloso":
				b.global_position = global_position+Vector2(dir.x*14,-6)
				b.pierce = true
				b.pierce_left = 4
	AudioManager.play("charged",-12)
	FxScript.muzzle(get_parent(),_muzzle_pos(),false,aim.angle(),col)

func _power_bullet(dir: Vector2, speed: float, dmg: int, col: Color) -> Bullet:
	var b := BulletScript.create(WEAPON_TEX["plasma"],_muzzle_pos(),dir,speed,dmg,true,0.9)
	b.color = col
	b._sprite.modulate = col
	_spawn_bullet(b)
	return b

# ----- Mega Buster con 3 niveles de carga -----
func _shoot_buster(delta: float) -> void:
	if pressed_once("shoot"):
		_start_charge()
		_fire_buster()
	if _charging:
		_charge_t += delta
		var tier := _charge_tier()
		if tier >= 1 and _charge_fx == null:
			_charge_fx = FxScript.charge(self, _muzzle_pos())
		if _charge_fx and is_instance_valid(_charge_fx):
			_charge_fx.modulate = CHARGE_COLORS[tier]
			_charge_fx.scale = Vector2.ONE * (0.7 + 0.18 * tier)
		_charge_pulse -= delta
		if _charge_pulse <= 0.0 and tier >= 1:
			_charge_pulse = 0.16 - 0.03 * tier
			FxScript.ring(get_parent(), _muzzle_pos(), CHARGE_COLORS[tier], 8.0 + 3.0 * tier, 2.0, 0.2)
	if released_once("shoot"):
		if _charging and _charge_tier() >= 1:
			_fire_buster()
		_end_charge()

func _charge_tier() -> int:
	if _charge_t >= CHARGE_L3:
		return 3
	if _charge_t >= CHARGE_L2:
		return 2
	if _charge_t >= CHARGE_L1:
		return 1
	return 0

func _start_charge() -> void:
	_charging = true
	_charge_t = 0.0
	_charge_pulse = 0.0

func _end_charge() -> void:
	_charging = false
	if _charge_fx and is_instance_valid(_charge_fx):
		_charge_fx.queue_free()
	_charge_fx = null

func _fire_buster() -> void:
	if _shoot_cooldown > 0.0:
		return
	var pos := _muzzle_pos()
	var tier := _charge_tier()
	var b: Bullet
	match tier:
		1:
			b = BulletScript.create(WEAPON_TEX["charged"], pos, aim, 430.0, 6, true, 1.05)
			b.color = CHARGE_COLORS[1]
			AudioManager.play("charged", -8.0)
			GameManager.shake(1.2)
		2:
			b = BulletScript.create(WEAPON_TEX["charged"], pos, aim, 440.0, 12, true, 1.45)
			b.pierce = true
			b.pierce_left = 1
			b.heavy = true
			b.color = CHARGE_COLORS[2]
			AudioManager.play("charged", -6.0)
			GameManager.shake(2.4)
			_recoil()
		3:
			b = BulletScript.create(WEAPON_TEX["charged"], pos, aim, 460.0, 22, true, 2.0)
			b.pierce = true
			b.pierce_left = 3
			b.heavy = true
			b.color = CHARGE_COLORS[3]
			AudioManager.play("charged", -3.0)
			GameManager.shake(4.0)
			GameManager.hitstop(0.06)
			FxScript.ring(get_parent(), pos, CHARGE_COLORS[3], 6.0, 34.0, 0.3)
			_recoil()
		_:
			b = BulletScript.create(WEAPON_TEX["buster"], pos, aim, 370.0, 3, true, 1.0)
			b.color = _color
			AudioManager.play("shoot", -12.0)
	_shoot_cooldown = PULSE_COOLDOWN
	_spawn_bullet(b)
	FxScript.muzzle(get_parent(), pos, false, aim.angle(), CHARGE_COLORS[tier] if tier > 0 else _color)

func _recoil() -> void:
	_knock = -aim * 70.0
	_knock.y = 0.0

func _fire_spread() -> void:
	var pos := _muzzle_pos()
	var base := aim.angle()
	for a in [-0.40, -0.20, 0.0, 0.20, 0.40]:
		var dir := Vector2.RIGHT.rotated(base + a)
		var b := BulletScript.create(WEAPON_TEX["spread"], pos, dir, 330.0, 3, true, 1.0)
		b.color = Color("8be9ff")
		_spawn_bullet(b)
	AudioManager.play("shoot", -10.0, 0.8)
	GameManager.shake(1.0)
	FxScript.muzzle(get_parent(), pos, false, aim.angle(), Color("8be9ff"))

func _fire_laser() -> void:
	var pos := _muzzle_pos()
	var b := BulletScript.create(WEAPON_TEX["laser"], pos, aim, 560.0, 3, true, 1.0)
	b.pierce = true
	b.pierce_left = 2
	b.life = 1.4
	b.color = Color("57d16a")
	_spawn_bullet(b)
	AudioManager.play("shoot", -16.0, 1.5)

func _fire_plasma() -> void:
	var pos := _muzzle_pos()
	var b := BulletScript.create(WEAPON_TEX["plasma"], pos, aim, 240.0, 8, true, 1.5)
	b.pierce = true
	b.pierce_left = 1
	b.heavy = true
	b.color = Color("c07dff")
	_spawn_bullet(b)
	AudioManager.play("charged", -10.0, 0.7)
	GameManager.shake(1.6)
	FxScript.muzzle(get_parent(), pos, false, aim.angle(), Color("c07dff"))

func _spawn_bullet(b: Bullet) -> void:
	var world := get_parent()
	if world == null:
		return
	b.damage = maxi(1,roundi(b.damage*(1+damage_level*0.2)))
	b.origin = self
	# Include the barrel in the first sweep: nearby switches can sit behind the muzzle.
	b.launch_from = global_position + Vector2(facing * 6, -19)
	b.sweep_launch = true
	world.add_child(b)

func _muzzle_pos() -> Vector2:
	var arm_w := 8.0
	if _arm and _arm.texture:
		arm_w = float(_arm.texture.get_width())
	return global_position + Vector2(facing * 6, -19) + aim * (arm_w + 1.0)

# ------------------------------------------------------------------
# Animación
# ------------------------------------------------------------------
func _update_animation() -> void:
	if _sprite == null:
		return
	var anim := "idle"
	if _dash_time > 0.0:
		anim = "dash"
	elif not is_on_floor():
		anim = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 8.0:
		anim = "run"
	elif _charging or pressed("shoot"):
		anim = "shoot"
	if _sprite.animation != anim:
		_sprite.play(anim)

func _update_invuln(delta: float) -> void:
	if _invuln > 0.0:
		_invuln -= delta
		if _sprite:
			_sprite.modulate.a = 0.35 if int(_invuln * 20.0) % 2 == 0 else 1.0
	else:
		if _sprite:
			_sprite.modulate.a = 1.0

# ------------------------------------------------------------------
# Daño y muerte
# ------------------------------------------------------------------
func _on_hurt_area(area: Area2D) -> void:
	if area.is_in_group("hazard"):
		take_damage(6, area.global_position)

func _on_hurt_body(body: Node) -> void:
	if body.has_method("take_damage") and body.get("contact_damage") != null:
		take_damage(body.contact_damage, body.global_position)

func take_damage(amount: int, from_pos: Vector2) -> void:
	amount = maxi(1,amount-armor_level-(1 if character=="red" else 0))
	if not alive or _invuln > 0.0:
		return
	_invuln = 1.1
	GameManager.damage_player(index, amount)
	AudioManager.play("hurt", -6.0)
	GameManager.shake(3.0)
	var dir := signf(global_position.x - from_pos.x)
	if dir == 0.0:
		dir = -facing
	_knock = Vector2(dir * 140.0, -140.0)
	FxScript.spark(get_parent(), global_position + Vector2(0, -14), Color(1, 0.4, 0.4))
	FxScript.ring(get_parent(), global_position + Vector2(0, -12), Color(1, 0.3, 0.3, 0.9), 3.0, 18.0, 0.25)
	if GameManager.p_health[index] <= 0:
		_die()

func fall_death() -> void:
	if not alive:
		return
	GameManager.set_player_health(index, 0)
	_die()

func _die() -> void:
	if not alive:
		return
	alive = false
	_end_charge()
	FxScript.explosion(get_parent(), global_position + Vector2(0, -14), 1.5)
	FxScript.ring(get_parent(), global_position + Vector2(0, -12), Color(1, 0.6, 0.3, 0.95), 4.0, 40.0, 0.4)
	AudioManager.play("explode", -4.0)
	GameManager.shake(5.0)
	if _sprite:
		_sprite.visible = false
	if _arm:
		_arm.visible = false
	set_physics_process(false)
	died.emit(index)

func respawn_at(pos: Vector2) -> void:
	jet_fuel = 1
	launch_time = 0
	air_jumps = 0
	jet_active = false
	alive = true
	global_position = pos
	velocity = Vector2.ZERO
	_knock = Vector2.ZERO
	_dash_time = 0.0
	_dash_cd = 0.0
	_end_charge()
	_invuln = 1.6
	if _sprite:
		_sprite.visible = false
	if _arm:
		_arm.visible = false
	set_physics_process(true)
	GameManager.revive_player_full(index)

func set_spawn_point(pos: Vector2) -> void:
	_spawn_point = pos

func get_spawn_point() -> Vector2:
	return _spawn_point

func is_alive() -> bool:
	return alive
