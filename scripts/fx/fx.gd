class_name Fx
extends Sprite2D
## Efectos visuales: explosiones animadas, chispas, fogonazos, carga, escombros,
## anillos de impacto y números de daño flotantes.

const FloatTextScript := preload("res://scripts/ui/float_text.gd")

enum Mode { EXPLOSION, SPARK, MUZZLE, CHARGE, DEBRIS }

static var _add_mat: CanvasItemMaterial = null

## Material de mezcla aditiva (brillo) compartido.
static func additive() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat

static func _network(parent: Node,kind: String,data: Dictionary) -> void:
	if parent==null or not parent.is_inside_tree(): return
	var session := parent.get_node_or_null("/root/NetSession")
	if session and session.online and session.host and is_instance_valid(session.world):
		session.world.record_event(kind,data)

static func beam(parent: Node,from: Vector2,to: Vector2,col: Color) -> void:
	_network(parent,"beam",{"x":from.x,"y":from.y,"tx":to.x,"ty":to.y,"color":col.to_html()})
	var line := Line2D.new()
	line.points = PackedVector2Array([from,from.lerp(to,0.5)+Vector2(0,-10),to])
	line.width = 2
	line.default_color = col
	parent.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line,"modulate:a",0.0,0.2)
	tween.tween_callback(line.queue_free)

var _mode: int = Mode.SPARK
var _frames: Array[Texture2D] = []
var _t := 0.0
var _dur := 0.4
var _drift := Vector2.ZERO
var _size := 3.0
var _rot := 0.0

static func _explosion_frames() -> Array[Texture2D]:
	var arr: Array[Texture2D] = []
	for i in 5:
		arr.append(load("res://assets/sprites/fx/explosion_%d.png" % i))
	return arr

static func explosion(parent: Node, pos: Vector2, size_mul: float = 1.0) -> void:
	_network(parent,"explosion",{"x":pos.x,"y":pos.y,"size":size_mul})
	if parent == null:
		return
	var f := Fx.new()
	f._mode = Mode.EXPLOSION
	f._frames = _explosion_frames()
	f._dur = 0.42
	f.scale = Vector2(size_mul, size_mul)
	f.z_index = 4
	f.position = pos
	parent.add_child(f)

static func spark(parent: Node, pos: Vector2, color: Color = Color(1, 1, 1)) -> void:
	if parent == null:
		return
	var f := Fx.new()
	f._mode = Mode.SPARK
	f._frames = [load("res://assets/sprites/fx/spark.png")]
	f._dur = 0.14
	f.material = additive()
	f.position = pos
	f.z_index = 5
	f.modulate = Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, 1.0)
	parent.add_child(f)

static func muzzle(parent: Node, pos: Vector2, flip: bool = false, rot: float = NAN,
		color: Color = Color(1, 1, 1)) -> void:
	_network(parent,"muzzle",{"x":pos.x,"y":pos.y,"angle":0.0 if is_nan(rot) else rot,"color":color.to_html()})
	if parent == null:
		return
	var f := Fx.new()
	f._mode = Mode.MUZZLE
	f._frames = [load("res://assets/sprites/fx/muzzle.png")]
	f._dur = 0.08
	f.material = additive()
	f.position = pos
	if is_nan(rot):
		f.flip_h = flip
	else:
		f.rotation = rot
	f.z_index = 5
	f.modulate = color
	parent.add_child(f)

static func charge(parent: Node, pos: Vector2) -> Fx:
	var f := Fx.new()
	f._mode = Mode.CHARGE
	f._frames = [load("res://assets/sprites/fx/charge.png")]
	f._dur = 999.0
	f.material = additive()
	f.position = pos
	f.z_index = 5
	parent.add_child(f)
	return f

## Trozos sólidos que salen volando (capas de destrucción). Baratos: Node2D dibujado.
static func debris(parent: Node, pos: Vector2, color: Color, count: int = 6, power: float = 90.0) -> void:
	if parent == null:
		return
	for i in count:
		var f := Fx.new()
		f._mode = Mode.DEBRIS
		f.position = pos + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		f.z_index = 5
		f.modulate = color
		f._drift = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(power * 0.4, power)
		f._drift.y -= power * 0.55
		f._dur = randf_range(0.35, 0.6)
		f._size = randf_range(2.0, 4.0)
		parent.add_child(f)

## Destello breve sobre un nodo (reemplazo visual del hitstop, sin tocar tiempo).
static func hit_flash(node: CanvasItem, strength: float = 3.0, dur: float = 0.09) -> void:
	if node == null or not is_instance_valid(node):
		return
	var base := Color.WHITE
	if node is Node2D and (node as Node2D).get("tint") != null:
		var tt: Color = (node as Node2D).get("tint")
		if tt != Color(1, 1, 1):
			base = tt
	node.modulate = Color(base.r * strength, base.g * strength, base.b * strength, 1.0)
	var t := node.create_tween()
	t.tween_property(node, "modulate", base, dur)

## Destrucción en capas para enemigos normales: explosion + anillo + chispas + piezas.
static func kill_burst(parent: Node, pos: Vector2, color: Color = Color(1, 0.7, 0.3), big: bool = false) -> void:
	if parent == null:
		return
	explosion(parent, pos, 1.9 if big else 1.15)
	ring(parent, pos, Color(1, 0.85, 0.4, 0.9), 3.0, 34.0 if big else 20.0, 0.28)
	for i in (10 if big else 6):
		spark(parent, pos + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(2, 9), color)
	debris(parent, pos, color.darkened(0.25), 8 if big else 5, 130.0 if big else 90.0)

## Número de puntos flotante (recompensa visible).
static func score_popup(parent: Node, pos: Vector2, amount: int, rare: bool = false) -> void:
	if parent == null or amount <= 0:
		return
	var col := Color("ffe14d") if not rare else Color("c07dff")
	FloatTextScript.spawn(parent, pos + Vector2(0, -20), "+%d" % amount, col, 2 if rare else 1, 22.0)

## Explosión de impacto escalable y rápida (para balas potentes).
static func impact(parent: Node, pos: Vector2, color: Color = Color(1, 1, 1), size_mul: float = 1.0) -> void:
	if parent == null:
		return
	ring(parent, pos, color, 2.0, 14.0 * size_mul, 0.22)
	for i in 4:
		var off := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(2.0, 7.0)
		spark(parent, pos + off, color)
	var f := Fx.new()
	f._mode = Mode.EXPLOSION
	f._frames = _explosion_frames()
	f._dur = 0.26
	f.scale = Vector2(0.6, 0.6) * size_mul
	f.z_index = 6
	f.position = pos
	f.modulate = color
	parent.add_child(f)

## Anillo expansivo dibujado (ideal para telegraphs y ondas de choque).
static func ring(parent: Node, pos: Vector2, color: Color, start_r: float,
		end_r: float, dur: float) -> void:
	_network(parent,"ring",{"x":pos.x,"y":pos.y,"color":color.to_html(),"start":start_r,"end":end_r,"duration":dur})
	if parent == null:
		return
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = color
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(Vector2.RIGHT.rotated(TAU * float(i) / 24.0) * start_r)
	line.points = pts
	line.position = pos
	line.z_index = 6
	parent.add_child(line)
	var t := line.create_tween()
	t.set_parallel(true)
	t.tween_method(func(s: float):
		var r := lerpf(start_r, end_r, s)
		var p := PackedVector2Array()
		for i in 24:
			p.append(Vector2.RIGHT.rotated(TAU * float(i) / 24.0) * r)
		line.points = p, 0.0, 1.0, dur)
	t.tween_property(line, "modulate:a", 0.0, dur)
	t.chain().tween_callback(line.queue_free)

## Número de daño flotante (fuente pixel, nunca se pisa con otros textos).
static func damage_number(parent: Node, pos: Vector2, amount: int,
		color: Color = Color("ffe14d"), crit: bool = false) -> void:
	_network(parent,"damage",{"x":pos.x,"y":pos.y,"color":color.to_html(),"amount":amount,"crit":crit})
	if parent == null:
		return
	var txt := ("%d" % amount) if not crit else ("%d!" % amount)
	FloatTextScript.spawn(parent, pos + Vector2(randf_range(-4.0, 4.0), -14.0), txt, color, 1 if not crit else 2, 18.0)

func _ready() -> void:
	if _mode == Mode.DEBRIS:
		texture = null
		queue_redraw()
		return
	if not _frames.is_empty():
		texture = _frames[0]
	if _mode == Mode.SPARK or _mode == Mode.MUZZLE:
		scale = Vector2.ONE

func _draw() -> void:
	# Trozo pixelado 2px: cuerpo + borde oscuro + brillo (estilo del juego).
	if _mode != Mode.DEBRIS:
		return
	var a := modulate.a
	var edge := Color(0.06, 0.06, 0.12, a)
	var body := Color(modulate.r, modulate.g, modulate.b, a)
	var lite := Color(minf(body.r + 0.35, 1.0), minf(body.g + 0.35, 1.0), minf(body.b + 0.35, 1.0), a)
	var s := _size
	draw_rect(Rect2(-s * 0.5 - 1, -s * 0.5 - 1, s + 2, s + 2), edge)
	draw_rect(Rect2(-s * 0.5, -s * 0.5, s, s), body)
	draw_rect(Rect2(-s * 0.5, -s * 0.5, s, 1.0), lite)

func _process(delta: float) -> void:
	_t += delta
	if _mode == Mode.EXPLOSION:
		var i := int((_t / _dur) * float(_frames.size()))
		if i >= _frames.size():
			queue_free()
			return
		texture = _frames[i]
		modulate.a = 1.0 - (_t / _dur) * 0.35
	elif _mode == Mode.CHARGE:
		var s := 0.8 + 0.4 * sin(_t * 18.0)
		scale = Vector2(s, s)
		modulate.a = 0.85
		return
	elif _mode == Mode.DEBRIS:
		# Trozo con gravedad: vuela, cae y se desvanece.
		_drift.y = minf(_drift.y + 620.0 * delta, 260.0)
		position += _drift * delta
		_rot += delta * 9.0
		rotation = _rot
		var k := _t / _dur
		if k >= 1.0:
			queue_free()
			return
		modulate.a = 1.0 - k * k
		return
	else:
		var k := _t / _dur
		if k >= 1.0:
			queue_free()
			return
		modulate.a = 1.0 - k
		scale = Vector2.ONE * (1.0 + k * 0.6)
