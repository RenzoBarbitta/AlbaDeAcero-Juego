extends Area2D
## Resorte: lanza al jugador hacia arriba (para llegar a zonas secretas).

const TEX0: Texture2D = preload("res://assets/sprites/world/spring_0.png")
const TEX1: Texture2D = preload("res://assets/sprites/world/spring_1.png")
const FxScript := preload("res://scripts/fx/fx.gd")

@export var power := 470.0
var launch_target := Vector2.ZERO
var guided := false
var skin := ""
var _spr: Sprite2D
var _cd := 0.0
var _anim := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	_spr = Sprite2D.new()
	_spr.texture = TEX0
	_spr.visible = skin==""
	_spr.centered = false
	_spr.position = Vector2(-8, -14)
	_spr.z_index = 1
	add_child(_spr)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 8)
	cs.shape = r
	cs.position = Vector2(0, -4)
	add_child(cs)
	area_entered.connect(_on_area)

func _on_area(area: Area2D) -> void:
	var p := area.get_parent()
	if _cd > 0.0 or p == null or not p.is_in_group("player"):
		return
	if p.velocity.y < -80.0:
		return
	p.velocity.y = -power
	if guided:
		var rise: float = p.global_position.y-launch_target.y
		var flight := (power+sqrt(maxf(1,power*power-1800*rise)))/900
		p.launch_speed = (launch_target.x-p.global_position.x)/flight
		p.launch_time = flight
	_cd = 0.25
	_anim = 0.25
	_spr.texture = TEX1
	AudioManager.play("jump", -6.0, 1.5)
	FxScript.ring(get_parent(), global_position + Vector2(0, -6), Color(1, 0.9, 0.4, 0.9), 3.0, 16.0, 0.25)

func _process(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	if _anim > 0.0:
		_anim -= delta
		if _anim <= 0.0:
			_spr.texture = TEX0

func _draw() -> void:
	if skin=="": return
	var c: Color = preload("res://scripts/world/stage_themes.gd").get_theme(skin)["accent"]
	match skin:
		"volcan":
			draw_arc(Vector2(0,0),14,PI,TAU,12,Color("6c3e38"),5)
			draw_line(Vector2(-5,-3),Vector2(-5,-15),c,2)
			draw_line(Vector2(4,-3),Vector2(4,-20),c,2)
		"biolab":
			draw_colored_polygon(PackedVector2Array([Vector2(-16,-3),Vector2(0,-12),Vector2(16,-3),Vector2(0,2)]),Color("81c885"))
			draw_line(Vector2(0,1),Vector2(0,-10),Color("24573b"),2)
		"glaciar":
			draw_colored_polygon(PackedVector2Array([Vector2(-13,0),Vector2(-5,-14),Vector2(0,-8),Vector2(6,-18),Vector2(14,0)]),Color("a6e6ee"))
		_:
			draw_rect(Rect2(-12,-6,24,6),c.darkened(0.4))
			draw_line(Vector2(-6,-8),Vector2(0,-14),c,2)
			draw_line(Vector2(0,-14),Vector2(6,-8),c,2)
