class_name Pickup
extends Area2D
## Objetos recogibles: vida, arma y vida extra.

const TEX := {
	"health": preload("res://assets/sprites/ui/pickup_health.png"),
	"weapon": preload("res://assets/sprites/ui/pickup_weapon.png"),
	"life": preload("res://assets/sprites/ui/pickup_life.png"),
	"chip": preload("res://assets/sprites/ui/pickup_chip.png"),
}

var kind := "health"
var _t := 0.0
var _base_y := 0.0
var _rare_glow: Node2D = null

static func create(kind_: String, pos: Vector2) -> Pickup:
	var p := Pickup.new()
	p.kind = kind_
	p.position = pos
	p.z_index = 1
	if kind_ == "rare":
		# Núcleo raro: dibujado por código (diamante violeta pulsante).
		var glow := _RareDraw.new()
		glow.position = Vector2.ZERO
		p.add_child(glow)
		p._rare_glow = glow
	else:
		var spr := Sprite2D.new()
		spr.texture = TEX[kind_]
		p.add_child(spr)
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 7.0
	cs.shape = c
	p.add_child(cs)
	p.collision_layer = 32
	p.collision_mask = 2
	p.monitoring = true
	p.monitorable = false
	return p

func _ready() -> void:
	add_to_group("net_entity")
	_base_y = position.y
	area_entered.connect(_on_area)

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * 4.0) * 2.0
	modulate = Color(1, 1, 1)
	if fmod(_t, 1.0) > 0.85:
		modulate = Color(2, 2, 2)

func _on_area(area: Area2D) -> void:
	var p := area.get_parent()
	if p and p.is_in_group("player"):
		_apply(p)
		queue_free()

func _apply(player: Player) -> void:
	match kind:
		"health":
			GameManager.heal_player(player.index,8)
			AudioManager.play("pickup", -8.0)
		"weapon":
			var cdata: Dictionary = GameManager.CHARACTERS.get(player.character, {})
			var alt: String = cdata.get("alt", "spread")
			GameManager.unlocked[alt] = true
			if player.index == 0:
				GameManager.current_weapon = alt
				GameManager.weapon_changed.emit(alt)
			player.equip_power(alt)
			GameManager.heal_player(player.index,6)
			AudioManager.play("pickup", -6.0)
			GameManager.toast("ARMA: %s  (Q CAMBIA)" % GameManager.weapon_name(alt), Color("ffd45a"))
		"chip":
			GameManager.add_score(25)
			AudioManager.play("pickup", -16.0, 1.7)
		"life":
			if player.index == 0:
				GameManager.lives += 1
				GameManager.lives_changed.emit(GameManager.lives)
			else:
				GameManager.p_lives[1] += 1
				GameManager.player_lives_changed.emit(1,GameManager.p_lives[1])
			AudioManager.play("life", -8.0)
			GameManager.toast("¡VIDA EXTRA!", Color("57d16a"))
		"rare":
			# Núcleo de élite: puntos + vida completa parcial + combo extra.
			GameManager.add_score(500)
			GameManager.heal_player(player.index,12)
			for i in 3:
				GameManager.register_hit()
			AudioManager.play("life", -6.0, 1.25)
			GameManager.toast("¡NÚCLEO ÉLITE! +500", Color("c07dff"))

## Dibujo del núcleo raro (Pickup._RareDraw): diamante violeta con halo.
class _RareDraw:
	extends Node2D
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		var halo := Color(0.75, 0.49, 1.0, 0.18 + 0.12 * pulse)
		draw_circle(Vector2.ZERO, 9.0 + pulse * 2.0, halo)
		var pts := PackedVector2Array([Vector2(0, -7), Vector2(5, 0), Vector2(0, 7), Vector2(-5, 0)])
		draw_colored_polygon(pts, Color("0a0a14"))
		var inner := PackedVector2Array([Vector2(0, -5), Vector2(3.4, 0), Vector2(0, 5), Vector2(-3.4, 0)])
		draw_colored_polygon(inner, Color("c07dff"))
		draw_line(Vector2(0, -5), Vector2(-1.4, 0), Color(1, 1, 1, 0.9), 1.0)
