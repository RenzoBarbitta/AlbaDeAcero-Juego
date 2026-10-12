extends Node2D
## Tres distritos verticales por zona, balcones opcionales y objetivos espaciales.
## Los puntos de control conservan la altura de la ruta y la cámara sigue la subida.

signal goal_reached
signal boss_defeated
signal arena_locked(rect: Rect2)

const Themes := preload("res://scripts/world/stage_themes.gd")
const MovingScript := preload("res://scripts/world/moving_platform.gd")
const CrumbleScript := preload("res://scripts/world/crumble_platform.gd")
const SpikeScript := preload("res://scripts/hazards/spike.gd")
const JetScript := preload("res://scripts/hazards/flame_jet.gd")
const SpringScript := preload("res://scripts/world/spring.gd")
const CheckpointScript := preload("res://scripts/world/checkpoint.gd")
const DecorScript := preload("res://scripts/world/decor.gd")
const PitFillScript := preload("res://scripts/world/pit_fill.gd")
const BossScript := preload("res://scripts/enemies/boss.gd")
const PickupScript := preload("res://scripts/pickups/pickup.gd")
const GoalScript := preload("res://scripts/world/goal.gd")
const RelayScript := preload("res://scripts/world/relay.gd")
const SectorArt := preload("res://scripts/world/sector_art.gd")

const GY := 150.0               # altura del suelo
const FLOOR_BOTTOM := 196.0
const FALL_Y := 220.0
const BODY_CHUNKS := 21
const ARENA_W := 400.0

var theme_id := "ciudad"
var theme: Dictionary = {}
var player_spawn := Vector2(96, 150)
var camera_rect := Rect2(0, -40, 2800, 236)
var boss = null
var goal = null
var arena_x := 0.0

var _players: Array = []
var _boss_down := false
var _rng := RandomNumberGenerator.new()
var _cursor := 0.0
var _checkpoint := Vector2(40, 146)
var _pits: Array = []
var _chunk_index := 0
var _arena_locked := false
var _gate_shape: CollisionShape2D
var _gate_vis: Array = []
var _life_given := false
var _weapon_given := false
var _art: Node2D
var puzzles: Array = []
var districts: Array = []
var architecture_decks: Array = []

# ---------------------------------------------------------------
func build(players: Array) -> void:
	_players = players
	theme_id = GameManager.theme_id
	theme = Themes.get_theme(theme_id)
	_rng.seed = hash(GameManager.selected_boss) + 7919
	_checkpoint = player_spawn
	GameManager.checkpoints = []
	_cursor = 0.0
	_art = SectorArt.new()
	_art.color = theme["accent"]
	_art.zone = theme_id
	add_child(_art)
	_add_wall(-16.0)
	_build_start()
	_build_body()
	_build_arena()
	_build_pit_fill()
	camera_rect = Rect2(0, -700, _cursor, 896)
	GameManager.level_length = _cursor

func respawn_position() -> Vector2:
	return _checkpoint

# ---------------------------------------------------------------
# Primitivas
# ---------------------------------------------------------------
func _add_platform(x: float, y: float, w: float, h: float, tile: String = "top") -> void:
	var p := Platform.new()
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.tile = tile
	add_child(p)

func _ground(x: float, w: float) -> void:
	_add_platform(x, GY, w, FLOOR_BOTTOM - GY, "top")

func _architecture(x: float,y: float,w: float,h: float,solid: bool = false) -> void:
	if not solid:
		for floor_body in get_children():
			if not floor_body is Platform or floor_body.tile!="top" or absf(floor_body.position.y-y)>0.5: continue
			var left: float = floor_body.position.x
			var right: float = left+floor_body.size.x
			if x>=right or x+w<=left: continue
			if left<=x and right>=x+w: return
			if left>x and right<x+w:
				_architecture(x,y,left-x,h)
				_architecture(right,y,x+w-right,h)
				return
			if left<=x:
				w -= right-x
				x = right
			else: w = left-x
		if w<8: return
	# Merge touching decks on the same level, including objective landing pads.
	if not solid:
		var changed := true
		while changed:
			changed = false
			for old in architecture_decks.duplicate():
				if old.solid or absf(old.position.y-y)>0.5: continue
				if x>old.position.x+old.size.x+2 or x+w<old.position.x-2: continue
				var end := maxf(x+w,old.position.x+old.size.x)
				x = minf(x,old.position.x)
				w = end-x
				architecture_decks.erase(old)
				remove_child(old)
				old.queue_free()
				changed = true
				break
	var deck := preload("res://scripts/world/architectural_deck.gd").new()
	deck.position = Vector2(x,y)
	deck.size = Vector2(w,h)
	deck.solid = solid
	deck.zone = theme_id
	deck.accent = theme["accent"]
	add_child(deck)
	architecture_decks.append(deck)

func _route_checkpoint(at: Vector2) -> void:
	var cp := CheckpointScript.new()
	cp.position = at
	cp.activated.connect(_on_checkpoint)
	add_child(cp)
	GameManager.checkpoints.append(at.x)

func _block(x: float, top_y: float, w: float) -> void:
	_add_platform(x, top_y, w, FLOOR_BOTTOM - top_y, "top")

func _float_plat(x: float, y: float, w: float) -> void:
	_add_platform(x, y, w, 16.0, "platform")

func _add_wall(x: float) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	b.position = Vector2(x + 8.0, 78.0)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 300)
	cs.shape = r
	b.add_child(cs)
	add_child(b)

func _add_moving(x: float, y: float, w: float, travel: Vector2, dur: float, delay: float = 0.0) -> MovingPlatform:
	var m = MovingScript.new()
	m.position = Vector2(x, y)
	m.size = Vector2(w, 16)
	m.travel = travel
	m.duration = dur
	m.start_delay = delay
	add_child(m)
	return m

func _add_crumble(x: float, y: float, w: float) -> void:
	var c = CrumbleScript.new()
	c.position = Vector2(x, y)
	c.size = Vector2(w, 16)
	add_child(c)

func _spike(x: float, w: float) -> void:
	add_child(SpikeScript.create(Vector2(x, GY - 16.0), Vector2(w, 16)))

func _jet(x: float, phase: float) -> void:
	var j = JetScript.new()
	j.position = Vector2(x, GY)
	j.phase = phase
	var hc: Color = theme["hazard_color"]
	j.flame_color = hc
	j.core_color = hc.lightened(0.7)
	add_child(j)

func _spring(x: float) -> void:
	var s = SpringScript.new()
	s.position = Vector2(x, GY)
	add_child(s)

func _pickup(kind: String, x: float, y: float) -> void:
	add_child(PickupScript.create(kind, Vector2(x, y)))

func _chips_arc(center: Vector2, n: int) -> void:
	for i in n:
		var t := 0.0 if n <= 1 else float(i) / float(n - 1)
		_pickup("chip", center.x + (t - 0.5) * 12.0 * float(n), center.y - sin(t * PI) * 12.0)

func _decor(x: float) -> void:
	var list: Array = theme["decor"]
	var kind: String = list[_rng.randi_range(0, list.size() - 1)]
	var col: Color = theme["accent"]
	add_child(DecorScript.create(kind, Vector2(x, GY), col, _rng.randi_range(0, 5)))

func _spawn_enemy(kind: String, x: float, y: float) -> void:
	var enemy := preload("res://scripts/enemies/zone_enemy.gd").new()
	enemy.zone = theme_id
	enemy.airborne = kind in ["flyer","bomber","mine","orbiter","medic"]
	enemy.position = Vector2(x,y)
	add_child(enemy)

func _spawn_ground(x: float, y: float) -> void:
	var list: Array = theme["ground"]
	_spawn_enemy(list[_rng.randi_range(0, list.size() - 1)], x, y)

func _spawn_air(x: float, y: float) -> void:
	var list: Array = theme["air"]
	_spawn_enemy(list[_rng.randi_range(0, list.size() - 1)], x, y)

func _diff() -> float:
	return float(_chunk_index) / float(maxi(BODY_CHUNKS - 1, 1))

# ---------------------------------------------------------------
# Construcción general
# ---------------------------------------------------------------
func _build_start() -> void:
	_ground(0,384)
	var intro := preload("res://scripts/world/start_beacon.gd").new()
	intro.coop = GameManager.coop
	intro.accent = theme["accent"]
	add_child(intro)
	_decor(48.0)
	_architecture(256,GY-32,80,16)
	var arrival := preload("res://scripts/world/campaign_room_art.gd").new()
	arrival.zone = theme_id
	arrival.room = {"title":"ACCESO", "span":384, "decks":[[160,150,300],[296,118,80]]}
	arrival.players = []
	add_child(arrival)
	_chips_arc(Vector2(296,GY-48),3)
	var cp = CheckpointScript.new()
	cp.position = Vector2(216,GY)
	cp.activated.connect(_on_checkpoint)
	add_child(cp)
	GameManager.checkpoints.append(216.0)
	_checkpoint = player_spawn
	_cursor = 384.0

const ZONE_ROUTES := {
	"fundicion":["flat","stairs","flames","elevator","crumble","flames","moving","pillars","chargers","elevator","flames","crumble","stairs","moving","turrets","flames","elevator","pillars","crumble","flames","flat"],
	"ruinas":["stairs","pillars","turrets","pit","stairs","mines","elevator","turrets","pillars","ambush","stairs","pit","turrets","mines","pillars","elevator","stairs","turrets","ambush","pit","flat"],
	"glaciar":["pit","float","crumble","moving","spikes","float","pit","crumble","spring","moving","float","spikes","crumble","pit","moving","spring","float","crumble","spikes","moving","flat"],
	"volcan":["stairs","flames","crumble","pillars","moving","flames","spring","crumble","chargers","flames","moving","crumble","pillars","spring","flames","crumble","elevator","flames","chargers","moving","flat"],
	"central":["pillars","moving","mines","elevator","turrets","moving","float","elevator","mines","pillars","moving","ambush","elevator","float","turrets","moving","mines","elevator","pillars","ambush","flat"],
	"cantera":["stairs","elevator","pillars","pit","elevator","stairs","crumble","pillars","chargers","elevator","pit","stairs","pillars","elevator","crumble","chargers","stairs","elevator","pillars","pit","flat"],
	"ciudad":["float","pit","moving","spring","ambush","float","pit","turrets","moving","spring","float","ambush","pit","moving","turrets","spring","float","ambush","pit","moving","flat"],
	"biolab":["flat","ambush","mines","float","pillars","ambush","spring","mines","crumble","float","ambush","pillars","mines","moving","spring","ambush","crumble","float","mines","pillars","flat"]
}

func _pick_sequence(n: int) -> Array:
	return ZONE_ROUTES[theme_id].slice(0,n)

func _build_body() -> void:
	for act in 3:
		_chunk_index = act*7
		_cursor += preload("res://scripts/world/campaign_layout.gd").build(self,_cursor,act)
		_cursor += _ck_checkpoint(_cursor)
		_cursor += _ck_sector(_cursor,act)
		_cursor += _ck_checkpoint(_cursor)

func _build_arena() -> void:
	_cursor += _ck_checkpoint(_cursor)
	arena_x = _cursor
	preload("res://scripts/world/arena_layout.gd").build(self,arena_x,ARENA_W)
	add_child(DecorScript.create("pillar", Vector2(arena_x + 14.0, GY), theme["accent"], 0))
	add_child(DecorScript.create("pillar", Vector2(arena_x + ARENA_W - 14.0, GY), theme["accent"], 0))
	_add_wall(arena_x + ARENA_W)

	# Compuerta (se cierra al entrar) y su efecto de energía
	var gate := StaticBody2D.new()
	gate.collision_layer = 1
	gate.collision_mask = 0
	gate.position = Vector2(arena_x - 6.0, 78.0)
	_gate_shape = CollisionShape2D.new()
	var gr := RectangleShape2D.new()
	gr.size = Vector2(12, 300)
	_gate_shape.shape = gr
	_gate_shape.disabled = true
	gate.add_child(_gate_shape)
	add_child(gate)
	var accent: Color = theme["accent"]
	for k in 2:
		var cr := ColorRect.new()
		cr.color = Color(accent.r, accent.g, accent.b, 0.22 if k == 0 else 0.85)
		cr.position = Vector2(arena_x - (8.0 if k == 0 else 4.0), -40.0)
		cr.size = Vector2(8.0 if k == 0 else 2.0, 236.0)
		cr.visible = false
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cr.z_index = 5
		add_child(cr)
		_gate_vis.append(cr)

	# Disparador de la arena
	var trig := Area2D.new()
	trig.collision_layer = 0
	trig.collision_mask = 2
	trig.monitoring = true
	trig.position = Vector2(arena_x + 30.0, 78.0)
	var tcs := CollisionShape2D.new()
	var trigger_rect := RectangleShape2D.new()
	trigger_rect.size = Vector2(8, 300)
	tcs.shape = trigger_rect
	trig.add_child(tcs)
	trig.body_entered.connect(_on_arena_trigger)
	add_child(trig)

	# Jefe
	boss = BossScript.new()
	var grounded: bool = GameManager.BOSSES[GameManager.selected_boss].get("mode", "air") == "ground"
	boss.position = Vector2(arena_x + 320.0, GY - 2.0 if grounded else GY - 40.0)
	boss.defeated.connect(_on_boss_defeated)
	add_child(boss)

	# Baliza de salida (aparece al vencer al jefe)
	goal = GoalScript.create(Vector2(arena_x + 364.0, GY))
	goal.monitoring = false
	goal.visible = false
	goal.reached.connect(_on_goal_reached)
	add_child(goal)

	_cursor = arena_x + ARENA_W

func _build_pit_fill() -> void:
	var f = PitFillScript.new()
	f.rects = _pits
	f.kind = theme["pit_kind"]
	f.fill_color = theme["pit_color"]
	f.bottom_y = FLOOR_BOTTOM
	add_child(f)

# ---------------------------------------------------------------
# Trozos de mapa
# ---------------------------------------------------------------
func _ck_sector(x: float, chapter: int) -> float:
	if chapter > 0:
		return _ck_expedition(x,chapter)
	_ground(x,768)
	var puzzle := preload("res://scripts/world/zone_puzzle.gd").new()
	puzzle.position = Vector2(x,0)
	puzzle.zone = theme_id
	puzzle.chapter = chapter
	puzzle.stage = self
	puzzle.control_positions = preload("res://scripts/world/campaign_puzzle_layout.gd").first_nodes(theme_id)
	add_child(puzzle)
	puzzles.append(puzzle)
	preload("res://scripts/world/campaign_puzzle_layout.gd").build_first(self,puzzle,x)
	_spawn_ground(x+660,GY)
	_spawn_air(x+520,40)
	_pickup("health",x+684,GY-14)
	return 768.0

func _ck_expedition(x: float, chapter: int) -> float:
	var puzzle := preload("res://scripts/world/expedition_puzzle.gd").new()
	puzzle.position = Vector2(x,0)
	puzzle.stage = self
	puzzle.zone = theme_id
	puzzle.chapter = chapter
	puzzle.nodes = preload("res://scripts/world/campaign_puzzle_layout.gd").nodes_for(theme_id,chapter)
	add_child(puzzle)
	puzzles.append(puzzle)
	_ground(x,128)
	_ground(x+920,104)
	preload("res://scripts/world/campaign_puzzle_layout.gd").build(self,puzzle,x,chapter)

	return 1024

func _ck_flat(x: float) -> float:
	var w := float(_rng.randi_range(6, 9) * 32)
	_ground(x, w)
	var n := 1 + int(_diff() * 2.0 + _rng.randf())
	for i in n:
		_spawn_ground(x + 80.0 + float(i) * ((w - 140.0) / float(maxi(n, 1))), GY - 2.0)
	if _rng.randf() < 0.5:
		_spawn_air(x + w * 0.5, GY - 62.0)
	return w

func _ck_pit(x: float) -> float:
	var gap := 48.0 + float(_rng.randi_range(0, 2)) * 4.0
	_ground(x, 56.0)
	_pits.append(Rect2(x + 56.0, 0.0, gap, 0.0))
	_ground(x + 56.0 + gap, 80.0)
	_chips_arc(Vector2(x + 56.0 + gap * 0.5, GY - 34.0), 4)
	if _rng.randf() < 0.5:
		_spawn_air(x + 56.0 + gap * 0.5, GY - 74.0)
	_spawn_ground(x + 56.0 + gap + 54.0, GY - 2.0)
	return 56.0 + gap + 80.0

func _ck_float(x: float) -> float:
	_ground(x, 48.0)
	var xs: Array[float] = [72.0, 152.0, 232.0]
	var ys: Array[float] = [GY - 24.0, GY - 40.0, GY - 24.0]
	for i in 3:
		_float_plat(x + xs[i], ys[i], 40.0)
		_chips_arc(Vector2(x + xs[i] + 20.0, ys[i] - 16.0), 2)
	_pits.append(Rect2(x + 48.0, 0.0, 248.0, 0.0))
	_ground(x + 296.0, 72.0)
	if _diff() > 0.25:
		_spawn_enemy("turret", x + 172.0, GY - 40.0)
	else:
		_spawn_air(x + 172.0, GY - 78.0)
	return 368.0

func _ck_moving(x: float) -> float:
	_ground(x, 40.0)
	_pits.append(Rect2(x + 40.0, 0.0, 96.0, 0.0))
	_add_moving(x + 40.0, GY, 48.0, Vector2(96.0, 0.0), 3.0)
	_ground(x + 136.0, 80.0)
	_chips_arc(Vector2(x + 88.0, GY - 44.0), 4)
	_spawn_air(x + 90.0, GY - 80.0)
	return 216.0

func _ck_elevator(x: float) -> float:
	_ground(x, 232.0)
	_block(x + 108.0, GY - 64.0, 64.0)
	_add_moving(x + 60.0, GY, 48.0, Vector2(0.0, -64.0), 2.4)
	_spawn_enemy("turret", x + 140.0, GY - 64.0)
	_chips_arc(Vector2(x + 140.0, GY - 90.0), 3)
	_spawn_ground(x + 210.0, GY - 2.0)
	return 232.0

func _ck_stairs(x: float) -> float:
	_ground(x, 32.0)
	_block(x + 32.0, GY - 24.0, 48.0)
	_block(x + 80.0, GY - 48.0, 48.0)
	_block(x + 128.0, GY - 24.0, 48.0)
	_ground(x + 176.0, 72.0)
	_spawn_enemy("turret", x + 104.0, GY - 48.0)
	_spawn_ground(x + 210.0, GY - 2.0)
	return 248.0

func _ck_spikes(x: float) -> float:
	_ground(x, 248.0)
	_spike(x + 80.0, 32.0)
	_spike(x + 156.0, 32.0)
	_float_plat(x + 64.0, GY - 40.0, 64.0)
	_chips_arc(Vector2(x + 96.0, GY - 58.0), 3)
	_spawn_air(x + 150.0, GY - 80.0)
	_spawn_ground(x + 222.0, GY - 2.0)
	return 248.0

func _ck_pillars(x: float) -> float:
	_ground(x, 304.0)
	_block(x + 70.0, GY - 24.0, 32.0)
	_block(x + 150.0, GY - 40.0, 32.0)
	_block(x + 230.0, GY - 24.0, 32.0)
	_spawn_enemy("turret", x + 166.0, GY - 40.0)
	_spawn_ground(x + 120.0, GY - 2.0)
	return 304.0

func _ck_turrets(x: float) -> float:
	_ground(x, 288.0)
	_block(x + 70.0, GY - 24.0, 24.0)
	_block(x + 134.0, GY - 40.0, 32.0)
	_spawn_enemy("turret", x + 150.0, GY - 40.0)
	_spawn_enemy("turret", x + 230.0, GY)
	_spawn_ground(x + 190.0, GY - 2.0)
	return 288.0

func _ck_crumble(x: float) -> float:
	_ground(x, 40.0)
	for i in 5:
		_add_crumble(x + 40.0 + float(i) * 56.0, GY, 32.0)
	_pits.append(Rect2(x + 40.0, 0.0, 280.0, 0.0))
	_ground(x + 320.0, 72.0)
	_chips_arc(Vector2(x + 180.0, GY - 30.0), 5)
	_spawn_enemy("bomber", x + 180.0, GY - 84.0)
	return 392.0

func _ck_spring(x: float) -> float:
	_ground(x, 288.0)
	_spring(x + 60.0)
	_float_plat(x + 108.0, GY - 108.0, 84.0)
	if not _life_given:
		_life_given = true
		_pickup("life", x + 150.0, GY - 126.0)
	else:
		_pickup("health", x + 150.0, GY - 126.0)
	_chips_arc(Vector2(x + 84.0, GY - 70.0), 3)
	_spawn_ground(x + 220.0, GY - 2.0)
	return 288.0

func _ck_flames(x: float) -> float:
	_ground(x, 308.0)
	_jet(x + 84.0, 0.0)
	_jet(x + 172.0, 1.0)
	_jet(x + 252.0, 1.9)
	_spawn_enemy("turret", x + 292.0, GY)
	return 308.0

func _ck_ambush(x: float) -> float:
	_ground(x, 256.0)
	var n := 2 + int(_diff() * 2.0)
	for i in n:
		_spawn_air(x + 110.0 + float(i) * 44.0, GY - 70.0 - float(i % 2) * 20.0)
	_spawn_ground(x + 200.0, GY - 2.0)
	return 256.0

func _ck_mines(x: float) -> float:
	_ground(x, 272.0)
	_spawn_enemy("mine", x + 80.0, GY - 14.0)
	_spawn_enemy("mine", x + 140.0, GY - 34.0)
	_spawn_enemy("mine", x + 200.0, GY - 14.0)
	_spawn_ground(x + 245.0, GY - 2.0)
	return 272.0

func _ck_chargers(x: float) -> float:
	_ground(x, 272.0)
	_block(x + 50.0, GY - 24.0, 24.0)
	_spawn_enemy("charger", x + 150.0, GY - 2.0)
	_spawn_enemy("charger", x + 220.0, GY - 2.0)
	return 272.0

func _ck_checkpoint(x: float) -> float:
	_ground(x, 112.0)
	var cp = CheckpointScript.new()
	cp.position = Vector2(x + 56.0, GY)
	cp.activated.connect(_on_checkpoint)
	add_child(cp)
	GameManager.checkpoints.append(x + 56.0)
	_pickup("health", x + 90.0, GY - 14.0)
	return 112.0

# ---------------------------------------------------------------
# Eventos
# ---------------------------------------------------------------
func _on_checkpoint(pos: Vector2) -> void:
	_checkpoint = pos
	for p in _players:
		if is_instance_valid(p):
			GameManager.heal_player(p.index, 10)

func _on_arena_trigger(body: Node) -> void:
	if _arena_locked or not body.is_in_group("player"):
		return
	_arena_locked = true
	_gate_shape.set_deferred("disabled", false)
	for v in _gate_vis:
		v.visible = true
	_checkpoint = Vector2(arena_x + 44.0, GY - 4.0)
	arena_locked.emit(Rect2(arena_x, -40.0, ARENA_W, 236.0))
	if boss and is_instance_valid(boss):
		boss.activate()
	GameManager.shake(3.0)

func _on_boss_defeated() -> void:
	_boss_down = true
	GameManager.acquire_boss_power(GameManager.selected_boss)
	get_tree().call_group("enemy_bullet", "queue_free")
	if goal:
		goal.visible = true
		goal.set_deferred("monitoring", true)
	for v in _gate_vis:
		v.visible = false
	_gate_shape.set_deferred("disabled", true)
	GameManager.banner("PODER: " + GameManager.weapon_name(GameManager.selected_boss), "Q CAMBIA PODER - TOCA LA BALIZA", Color("57d16a"))
	boss_defeated.emit()

func _on_goal_reached() -> void:
	if not _boss_down:
		return
	goal_reached.emit()

func _physics_process(_delta: float) -> void:
	var lead := -1.0
	for p in _players:
		if is_instance_valid(p) and p.has_method("is_alive") and p.is_alive():
			lead = maxf(lead, p.global_position.x)
			if p.global_position.y > FALL_Y:
				p.fall_death()
	if lead >= 0.0:
		GameManager.player_x = lead
