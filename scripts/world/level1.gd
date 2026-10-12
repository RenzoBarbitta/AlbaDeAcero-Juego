class_name Level1
extends Node2D
## Constructor del nivel: plataformas, peligros, enemigos, objetos, arena del
## jefe seleccionado y meta. Soporta cooperativo (lista de jugadores).

signal goal_reached
signal boss_defeated

const PlatformScript := preload("res://scripts/world/platform.gd")
const MovingScript := preload("res://scripts/world/moving_platform.gd")
const SpikeScript := preload("res://scripts/hazards/spike.gd")
const WalkerScript := preload("res://scripts/enemies/walker.gd")
const FlyerScript := preload("res://scripts/enemies/flyer.gd")
const TurretScript := preload("res://scripts/enemies/turret.gd")
const JumperScript := preload("res://scripts/enemies/jumper.gd")
const BomberScript := preload("res://scripts/enemies/bomber.gd")
const BossScript := preload("res://scripts/enemies/boss.gd")
const PickupScript := preload("res://scripts/pickups/pickup.gd")
const GoalScript := preload("res://scripts/world/goal.gd")

const FALL_Y := 220.0

var player_spawn := Vector2(36, 118)
var camera_rect := Rect2(0, -40, 2400, 236)
var boss = null
var goal = null
var _players: Array = []
var _boss_down := false

func build(players: Array) -> void:
	_players = players
	_build_geometry()
	_build_enemies()
	_build_pickups()
	_build_goal()
	_build_boss()

# ---------------------------------------------------------------
func _add_platform(x: float, y: float, w: float, h: float, tile: String = "top") -> void:
	var p := PlatformScript.new()
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.tile = tile
	add_child(p)

func _add_moving(x: float, y: float, w: float, travel: float, dur: float) -> void:
	var m := MovingScript.new()
	m.position = Vector2(x, y)
	m.size = Vector2(w, 16)
	m.travel = Vector2(travel, 0)
	m.duration = dur
	add_child(m)

func _add_spike(x: float, y: float, w: float, h: float = 16) -> void:
	var s := SpikeScript.create(Vector2(x, y), Vector2(w, h))
	add_child(s)

func _add_walker(x: float, y: float) -> void:
	var e := WalkerScript.new()
	e.position = Vector2(x, y)
	add_child(e)

func _add_flyer(x: float, y: float) -> void:
	var e := FlyerScript.new()
	e.position = Vector2(x, y)
	add_child(e)

func _add_turret(x: float, y: float) -> void:
	var e := TurretScript.new()
	e.position = Vector2(x, y)
	add_child(e)

func _add_jumper(x: float, y: float) -> void:
	var e := JumperScript.new()
	e.position = Vector2(x, y)
	add_child(e)

func _add_bomber(x: float, y: float) -> void:
	var e := BomberScript.new()
	e.position = Vector2(x, y)
	add_child(e)

func _add_pickup(kind: String, x: float, y: float) -> void:
	var p := PickupScript.create(kind, Vector2(x, y))
	add_child(p)

# ---------------------------------------------------------------
func _build_geometry() -> void:
	_add_platform(0, 150, 200, 30)
	_add_spike(160, 134, 40, 16)
	_add_platform(140, 106, 48, 16, "platform")

	_add_moving(200, 150, 56, 60, 2.0)

	_add_platform(260, 150, 180, 30)
	_add_platform(300, 104, 64, 16, "platform")

	_add_platform(440, 150, 60, 30)

	_add_platform(560, 150, 160, 30)
	_add_spike(600, 134, 48, 16)
	_add_platform(560, 108, 48, 16, "platform")

	_add_platform(720, 150, 120, 30)

	_add_moving(840, 150, 56, 80, 2.5)

	_add_platform(920, 150, 180, 30)
	_add_spike(1020, 134, 40, 16)
	_add_platform(940, 104, 64, 16, "platform")

	_add_platform(1100, 150, 60, 30)
	_add_platform(1180, 128, 60, 30)
	_add_platform(1260, 106, 60, 30)
	_add_platform(1160, 150, 160, 30)
	_add_spike(1180, 134, 120, 16)

	_add_platform(1320, 150, 140, 30)

	_add_moving(1460, 150, 56, 60, 2.0)

	_add_platform(1520, 150, 200, 30)
	_add_platform(1560, 104, 64, 16, "platform")

	_add_platform(1720, 150, 180, 30)
	_add_spike(1760, 134, 40, 16)
	_add_platform(1780, 104, 48, 16, "platform")

	_add_moving(1900, 150, 56, 60, 2.0)

	_add_platform(1960, 150, 440, 30)

func _build_enemies() -> void:
	_add_walker(120, 132)
	_add_walker(380, 132)
	_add_turret(300, 150)
	_add_flyer(420, 110)
	_add_flyer(640, 100)
	_add_walker(680, 132)
	_add_turret(960, 150)
	_add_walker(1040, 132)
	_add_flyer(1380, 98)
	_add_walker(1580, 132)
	_add_turret(1660, 150)
	_add_flyer(1860, 108)
	_add_walker(1280, 90)
	_add_jumper(560, 132)
	_add_jumper(1180, 90)
	_add_jumper(1720, 132)
	_add_bomber(920, 66)
	_add_bomber(1500, 66)

func _build_pickups() -> void:
	_add_pickup("health", 150, 92)
	_add_pickup("weapon", 1000, 112)
	_add_pickup("health", 1560, 90)
	_add_pickup("health", 2050, 118)
	_add_pickup("life", 1300, 90)

func _build_goal() -> void:
	goal = GoalScript.create(Vector2(2320, 150))
	goal.reached.connect(_on_goal_reached)
	add_child(goal)

func _build_boss() -> void:
	boss = BossScript.new()
	boss.position = Vector2(2150, 110)
	boss.defeated.connect(_on_boss_defeated)
	add_child(boss)

func _on_boss_defeated() -> void:
	_boss_down = true
	boss_defeated.emit()

func _on_goal_reached() -> void:
	if not _boss_down:
		return
	goal_reached.emit()

# ---------------------------------------------------------------
func _physics_process(_delta: float) -> void:
	for p in _players:
		if is_instance_valid(p) and p.has_method("is_alive") and p.is_alive():
			if p.global_position.y > FALL_Y:
				p.fall_death()
