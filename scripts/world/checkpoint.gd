extends Area2D
## Punto de control: al tocarlo se guarda el lugar de reaparición.

signal activated(pos: Vector2)

const OFF: Texture2D = preload("res://assets/sprites/world/checkpoint_off.png")
const ON: Texture2D = preload("res://assets/sprites/world/checkpoint_on.png")
const FxScript := preload("res://scripts/fx/fx.gd")

var _on := false
var _spr: Sprite2D
var _t := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	_spr = Sprite2D.new()
	_spr.texture = OFF
	_spr.centered = false
	_spr.position = Vector2(-8, -32)
	add_child(_spr)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(24, 44)
	cs.shape = r
	cs.position = Vector2(0, -20)
	add_child(cs)
	area_entered.connect(_on_area)

func _on_area(area: Area2D) -> void:
	if _on:
		return
	var p := area.get_parent()
	if p and p.is_in_group("player"):
		activate()

func activate() -> void:
	if _on:
		return
	_on = true
	_spr.texture = ON
	AudioManager.play("life", -8.0)
	GameManager.toast("PUNTO DE CONTROL", Color("59d0ff"))
	FxScript.ring(get_parent(), global_position + Vector2(0, -20), Color(0.35, 0.82, 1.0, 0.9), 4.0, 30.0, 0.4)
	activated.emit(global_position + Vector2(0, -4))

func _process(delta: float) -> void:
	if _on:
		_t += delta
		_spr.modulate = Color(1, 1, 1).lerp(Color(1.5, 1.7, 1.9), 0.5 + 0.5 * sin(_t * 5.0))
