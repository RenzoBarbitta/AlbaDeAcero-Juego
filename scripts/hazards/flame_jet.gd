extends Area2D
## Tobera con ciclo: apagada -> aviso (brilla) -> llama/arco activo.
## Origen = punto de apoyo sobre el suelo. La llama sube desde ahí.

const JET_TEX: Texture2D = preload("res://assets/sprites/world/jet.png")

@export var period := 2.8
@export var on_time := 0.9
@export var warn_time := 0.45
@export var phase := 0.0
@export var flame_h := 36.0
@export var flame_color := Color("ff8c42")
@export var core_color := Color("fff0a8")

var _t := 0.0
var _active := false
var _warn := false

func _ready() -> void:
	add_to_group("hazard")
	collision_layer = 64
	collision_mask = 0
	monitoring = false
	monitorable = false
	_t = phase
	var spr := Sprite2D.new()
	spr.texture = JET_TEX
	spr.centered = false
	spr.position = Vector2(-8, -6)
	spr.z_index = 1
	add_child(spr)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, flame_h)
	cs.shape = r
	cs.position = Vector2(0, -6.0 - flame_h * 0.5)
	add_child(cs)

func _process(delta: float) -> void:
	_t = fposmod(_t + delta, period)
	var on_start := period - on_time
	var now_active := _t >= on_start
	var now_warn := (not now_active) and _t >= on_start - warn_time
	if now_active != _active:
		_active = now_active
		set_deferred("monitorable", _active)
		if _active:
			AudioManager.play("enemy_shoot", -16.0, 0.6)
	_warn = now_warn
	queue_redraw()

func _draw() -> void:
	if _warn:
		var blink := int(_t * 18.0) % 2 == 0
		if blink:
			draw_rect(Rect2(-4, -9, 8, 3), Color(flame_color.r, flame_color.g, flame_color.b, 0.9))
		draw_rect(Rect2(-1, -14, 2, 5), Color(core_color.r, core_color.g, core_color.b, 0.7))
	if _active:
		var k := (_t - (period - on_time)) / on_time
		var grow := clampf(k * 6.0, 0.0, 1.0)
		var h := flame_h * grow
		for i in range(-5, 6, 2):
			var hh := h * (0.72 + 0.28 * sin(_t * 34.0 + float(i) * 1.7))
			draw_rect(Rect2(float(i) - 1.0, -6.0 - hh, 2.0, hh), flame_color)
		for i in range(-2, 3, 2):
			var hc := h * (0.55 + 0.2 * sin(_t * 40.0 + float(i)))
			draw_rect(Rect2(float(i) - 1.0, -6.0 - hc, 2.0, hc), core_color)
