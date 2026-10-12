class_name BossVisual
extends Node2D
## Dibuja cada jefe en pixel-art coherente con el resto del juego: rejilla de
## 2 px, contorno oscuro de 2 px, paneles de acero + color del jefe y visor
## luminoso (el mismo "ojo" que los enemigos normales). El origen del nodo es el
## centro del cuerpo y los pies quedan en y = +16, de modo que en el mundo el
## jefe apoya exactamente sobre el suelo (el nodo vive en (0, -16)).
##
## El boss.gd controla `action`/`phase` para telegrafiar cargas, disparos y
## teletransportes, y `rage` para la fase final (visores rojos + aura).

var design := "sierra"
var color := Color.WHITE
var action := ""        # habilidad en curso (para telegrafos)
var phase := 0          # 0 = aviso, 1 = ejecutando
var rage := false
var t := 0.0

const OUT := Color("101322")
const STEEL := Color("8fa0c2")
const STEEL_D := Color("5a6788")
const STEEL_L := Color("c8d6f0")
const RIVET := Color("39415f")
const GLASS := Color("9fe8ff")
const AMBER := Color("ffd15c")
const FIRE := Color("ff7a1a")

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	match design:
		"sierra": _draw_sierra()
		"estruendo": _draw_estruendo()
		"glaciar": _draw_glaciar()
		"incendio": _draw_incendio()
		"voltaje": _draw_voltaje()
		"coloso": _draw_coloso()
		"espectro": _draw_espectro()
		"enjambre": _draw_enjambre()
	_fx_common()

## ---------------------------------------------------------------- helpers
func _b(x: float, y: float, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2(snappedf(x, 2.0), snappedf(y, 2.0),
		maxf(2.0, snappedf(w, 2.0)), maxf(2.0, snappedf(h, 2.0))), col)

## Caja con contorno oscuro de 2 px (estilo sprite con outline).
func _box(x: float, y: float, w: float, h: float, col: Color) -> void:
	_b(x - 2, y - 2, w + 4, h + 4, OUT)
	_b(x, y, w, h, col)

## Disco pixelado a partir de filas de 2 px.
func _disc(cx: float, cy: float, r: float, col: Color) -> void:
	var dy := -r
	while dy < r:
		var hw := floorf(sqrt(maxf(0.0, r * r - dy * dy)) / 2.0) * 2.0
		if hw >= 2.0:
			_b(cx - hw, cy + dy, hw * 2.0, 2.0, col)
		dy += 2.0

func _disc_o(cx: float, cy: float, r: float, col: Color) -> void:
	_disc(cx, cy, r + 2.0, OUT)
	_disc(cx, cy, r, col)

## Visor luminoso tipo "ojo" de los enemigos normales.
func _visor(x: float, y: float, w: float, h: float) -> void:
	var c := Color("ff5a4a") if rage else GLASS
	if phase == 0 and action != "" and int(t * 12.0) % 2 == 0:
		c = Color.WHITE
	_b(x - 2, y - 2, w + 4, h + 4, OUT)
	_b(x, y, w, h, c)
	_b(x + 2, y, maxf(2.0, w * 0.4), 2.0, Color(1, 1, 1, 0.95))

## Destellos comunes: telegrafo (fase 0) y aura de furia.
func _fx_common() -> void:
	if phase == 0 and action != "" and int(t * 12.0) % 2 == 0:
		_b(-24, -12, 2, 4, Color(1, 1, 1, 0.9))
		_b(22, -12, 2, 4, Color(1, 1, 1, 0.9))
	if rage and int(t * 8.0) % 2 == 0:
		_b(-2, 16, 4, 2, Color(1.0, 0.35, 0.25, 0.8))

## Líneas de velocidad tras una embestida.
func _dash_lines(dir: float) -> void:
	for i in 3:
		var lx := -dir * (20.0 + 8.0 * float(i))
		var ly := -14.0 + 10.0 * float(i) + (2.0 if int(t * 20.0) % 2 == 0 else 0.0)
		_b(lx, ly, 10.0, 2.0, Color(1, 1, 1, 0.45))


## ---------------------------------------------------------------- sierra
## Sierra: bipedo con una sierra de disco en el brazo derecho.
func _draw_sierra() -> void:
	var light := color.lightened(0.30)
	var shade := color.darkened(0.35)
	# piernas y pies
	_box(-12, 4, 8, 10, STEEL_D)
	_box(4, 4, 8, 10, STEEL_D)
	_b(-14, 14, 12, 2, OUT)
	_b(2, 14, 12, 2, OUT)
	# torso
	_box(-10, -10, 20, 16, color)
	_b(-6, -6, 12, 4, light)
	_b(-10, 0, 20, 2, shade)
	# cabeza
	_box(-6, -18, 12, 8, STEEL)
	_visor(-4, -16, 8, 3)
	# brazo izquierdo
	_box(-16, -8, 6, 10, STEEL_D)
	# sierra (brazo derecho): disco + dientes cuantizados
	var spin := snappedf(t * (14.0 if phase == 1 else 5.0), TAU / 8.0)
	_disc_o(16, -2, 9, STEEL_L)
	_disc(16, -2, 4, RIVET)
	for i in 4:
		var a := spin + TAU * float(i) / 4.0
		var tx := 16.0 + cos(a) * 11.0
		var ty := -2.0 + sin(a) * 11.0
		_b(tx - 2, ty - 2, 4, 4, AMBER)
	if phase == 1 and action == "dash":
		_dash_lines(float(signf(scale.x)))

## -------------------------------------------------------------- estruendo
## Estruendo: tanque de orugas con cañón y torreta.
func _draw_estruendo() -> void:
	var light := color.lightened(0.28)
	# orugas
	_box(-20, 4, 40, 10, STEEL_D)
	var step := int(t * 10.0) % 4
	for i in 4:
		_b(-18.0 + float(i) * 9.0 + float(step % 2) * 2.0, 6, 5, 2, RIVET)
		_b(-18.0 + float(i) * 9.0, 11, 5, 2, RIVET)
	# casco
	_box(-16, -10, 32, 14, color)
	_b(-12, -6, 8, 4, light)
	_b(-16, -2, 32, 2, color.darkened(0.35))
	# torreta
	_box(-8, -18, 16, 8, STEEL)
	_visor(-5, -16, 4, 3)
	_visor(2, -16, 4, 3)
	# cañón lateral
	_box(6, -14, 16, 5, STEEL_D)
	_b(20, -15, 4, 7, OUT)
	if phase == 1 and int(t * 14.0) % 2 == 0:
		# fogonazo del cañón tras disparar
		_b(24, -14, 4, 5, Color(1, 0.95, 0.5))
		_b(28, -13, 2, 3, Color.WHITE)

## ---------------------------------------------------------------- glaciar
## Glaciar: mecha de cristal flotante con esquirlas orbitando.
func _draw_glaciar() -> void:
	var light := color.lightened(0.35)
	var deep := color.darkened(0.25)
	# cuerpo en bloques escalonados (rombo)
	_box(-8, -12, 16, 4, deep)
	_box(-12, -8, 24, 12, color)
	_box(-8, 4, 16, 6, deep)
	# núcleo
	_visor(-4, -6, 8, 6)
	# pico inferior (sin tocar el suelo: termina en +12)
	_b(-2, 8, 4, 4, light)
	# crestas
	_b(-6, -18, 4, 6, light)
	_b(2, -18, 4, 6, light)
	_b(-2, -22, 4, 4, GLASS if not rage else Color("ff5a4a"))
	# esquirlas orbitando (paso cuantizado)
	var orb := snappedf(t * 3.0, TAU / 6.0)
	for i in 3:
		var a := orb + TAU * float(i) / 3.0
		var sx := cos(a) * 17.0
		var sy := sin(a) * 7.0 - 2.0
		_b(sx - 2, sy - 3, 4, 6, light)
		_b(sx - 2, sy - 5, 4, 2, GLASS)

## --------------------------------------------------------------- incendio
## Incendio: volador de fusión con chorros de llama.
func _draw_incendio() -> void:
	var light := Color(1.0, 0.82, 0.4)
	# cuerpo redondeado en bloques
	_box(-10, -12, 20, 4, color.darkened(0.3))
	_box(-14, -8, 28, 14, color)
	_box(-10, 6, 20, 4, color.darkened(0.35))
	# núcleo de horno
	_visor(-6, -4, 12, 6)
	# toberas laterales
	_box(-18, -4, 4, 8, STEEL_D)
	_box(14, -4, 4, 8, STEEL_D)
	# llama inferior animada por frames
	var fh := 4.0 + 2.0 * float(int(t * 10.0) % 3)
	_b(-6, 10, 4, fh, FIRE)
	_b(0, 10, 6, fh + 2.0, FIRE)
	_b(6, 10, 4, fh, FIRE)
	_b(0, 10, 4, fh, light)
	# chispas de chorro lateral
	if int(t * 12.0) % 2 == 0:
		_b(-22, -2, 4, 4, FIRE)
		_b(18, -2, 4, 4, FIRE)
	if phase == 1 and action == "dash":
		_dash_lines(float(signf(scale.x)))

## --------------------------------------------------------------- voltaje
## Voltaje: bobina eléctrica con arcos y chispas orbitando.
func _draw_voltaje() -> void:
	var light := color.lightened(0.3)
	# cuerpo
	_box(-10, -6, 20, 16, STEEL)
	_box(-12, -2, 4, 8, STEEL_D)
	_box(8, -2, 4, 8, STEEL_D)
	_b(-8, 2, 16, 4, color)
	# bobina superior
	_box(-6, -14, 12, 8, STEEL_D)
	_b(-4, -18, 8, 4, color)
	_b(-2, -22, 4, 4, light)
	# arco superior (parpadeo cuantizado)
	if int(t * 9.0) % 2 == 0:
		_b(-6, -24, 4, 2, AMBER)
		_b(0, -26, 4, 2, AMBER)
		_b(4, -22, 4, 2, AMBER)
	# ojos
	_visor(-6, -3, 4, 4)
	_visor(2, -3, 4, 4)
	# patas
	_b(-8, 10, 6, 6, STEEL_D)
	_b(2, 10, 6, 6, STEEL_D)
	_b(-10, 14, 8, 2, OUT)
	_b(2, 14, 8, 2, OUT)
	# chispas orbitando
	var orb := snappedf(t * 4.0, TAU / 4.0)
	for i in 2:
		var a := orb + PI * float(i)
		_b(cos(a) * 15.0 - 2, sin(a) * 13.0 - 4, 4, 4, AMBER)

## ---------------------------------------------------------------- coloso
## Coloso: golem masivo de roca con puños enormes y un solo ojo.
func _draw_coloso() -> void:
	var rock := color
	var rock_d := color.darkened(0.32)
	# piernas cortas y anchas
	_box(-14, 4, 12, 10, rock_d)
	_box(2, 4, 12, 10, rock_d)
	_b(-16, 14, 16, 2, OUT)
	_b(0, 14, 16, 2, OUT)
	# torso masivo
	_box(-14, -14, 28, 18, rock)
	_b(-10, -10, 8, 4, Color("a8906c"))
	_b(-14, -2, 28, 2, rock_d)
	_b(4, -12, 4, 2, rock_d)
	# hombreras y puños
	_box(-22, -12, 8, 12, rock_d)
	_box(14, -12, 8, 12, rock_d)
	_disc_o(-18, 2, 5, STEEL_D)
	_disc_o(18, 2, 5, STEEL_D)
	# cabeza pequeña con visor único
	_box(-5, -22, 10, 8, STEEL_D)
	_visor(-4, -20, 8, 3)
	# grietas
	_b(-6, 0, 2, 6, rock_d)
	_b(8, -8, 2, 6, rock_d)
	if phase == 1 and action == "dash":
		_dash_lines(float(signf(scale.x)))
	if phase == 0 and action == "jump":
		# encogimiento antes del salto
		_b(-16, 16, 32, 2, Color(1, 1, 1, 0.5))

## --------------------------------------------------------------- espectro
## espectro: mecha fantasma con capa ondulante y ojos brillantes.
func _draw_espectro() -> void:
	var shade := color.darkened(0.3)
	var glow := color.lightened(0.25)
	# capa ondulante (3 franjas con desfase cuantizado)
	var w := int(t * 6.0) % 2
	for i in 3:
		var y0 := -2.0 + 6.0 * float(i)
		var off := 2.0 * float((i + w) % 2) * (1 if i % 2 == 0 else -1)
		_b(-12.0 + off, y0, 24.0, 6.0, Color(color.r, color.g, color.b, 0.85 - 0.15 * float(i)))
	# cuerpo
	_box(-8, -14, 16, 12, shade)
	_b(-6, -10, 12, 4, glow)
	# capucha
	_box(-8, -22, 16, 8, OUT)
	_b(-6, -20, 12, 6, shade)
	# ojos
	_b(-5, -18, 4, 3, Color("ff5a4a") if rage else GLASS)
	_b(1, -18, 4, 3, Color("ff5a4a") if rage else GLASS)
	# estela fantasmal
	var st := int(t * 8.0) % 3
	_b(-10.0 + 2.0 * float(st), 12, 6, 2, Color(glow.r, glow.g, glow.b, 0.5))
	_b(4.0 - 2.0 * float(st), 12, 6, 2, Color(glow.r, glow.g, glow.b, 0.5))

## --------------------------------------------------------------- enjambre
## Enjambre: unidad reina con alas y enjambre de miradas orbitando.
func _draw_enjambre() -> void:
	var light := color.lightened(0.3)
	# alas (2 poses alternas)
	var up := int(t * 10.0) % 2 == 0
	var wy := -16.0 if up else -8.0
	_b(-24, wy, 12, 4, Color(0.75, 0.9, 1.0, 0.75))
	_b(12, wy, 12, 4, Color(0.75, 0.9, 1.0, 0.75))
	_b(-24, wy + 4.0, 8, 2, Color(0.55, 0.75, 0.95, 0.6))
	_b(16, wy + 4.0, 8, 2, Color(0.55, 0.75, 0.95, 0.6))
	# cuerpo
	_box(-10, -10, 20, 18, color)
	_box(-7, -16, 14, 6, color.darkened(0.35))
	_b(-6, -4, 12, 6, color.darkened(0.3))
	_visor(-5, -14, 10, 3)
	# aguijón
	_b(-2, 8, 4, 6, STEEL_D)
	_b(-3, 14, 6, 2, OUT)
	# miradas orbitando (enjambre)
	var orb := snappedf(t * 5.0, TAU / 5.0)
	for i in 3:
		var a := orb + TAU * float(i) / 3.0
		_disc(cos(a) * 18.0, sin(a) * 10.0 + 2.0, 2.0, light)
	# larvae cayendo
	if int(t * 4.0) % 4 == 0:
		_b(-14, 12, 2, 4, light)
		_b(12, 10, 2, 4, light)
