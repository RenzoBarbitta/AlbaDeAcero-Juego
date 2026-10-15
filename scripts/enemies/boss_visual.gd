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

var motion := 0.0
var motion_state := "idle"
var clock := 0.0
var pose_amount := 0.0
var _animation_state := ""
var _animator: AnimationPlayer
var design := "sierra"
var color := Color.WHITE
var action := ""        # habilidad en curso (para telegrafos)
var phase := 0          # 0 = aviso, 1 = ejecutando
var rage := false
var shielded := false
var t := 0.0

const OUT := Color("101322")
const STEEL := Color("8fa0c2")
const STEEL_D := Color("5a6788")
const STEEL_L := Color("c8d6f0")
const RIVET := Color("39415f")
const GLASS := Color("9fe8ff")
const AMBER := Color("ffd15c")
const FIRE := Color("ff7a1a")

func _ready() -> void:
	_animator = AnimationPlayer.new()
	_animator.name = "RigAnimation"
	add_child(_animator)
	var library := AnimationLibrary.new()
	var clips := {"idle":[1.2,[0.0,0.12,0.0]],"tell":[0.75,[0.0,0.65,1.0]],"act":[0.4,[1.0,-0.35,0.1]],"wait":[0.65,[-0.3,0.08,0.0]]}
	for id in clips:
		var clip := Animation.new()
		clip.length = float(clips[id][0])
		if id=="idle": clip.loop_mode = Animation.LOOP_LINEAR
		var track := clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(track,NodePath(".:pose_amount"))
		for i in 3: clip.track_insert_key(track,clip.length*float(i)/2,float(clips[id][1][i]))
		library.add_animation(id,clip)
	_animator.add_animation_library("",library)

func _process(delta: float) -> void:
	t += delta
	if is_instance_valid(_animator) and _animation_state!=motion_state:
		_animation_state = motion_state
		_animator.play(motion_state if motion_state in ["idle","tell","act","wait"] else "idle",0.08)
	queue_redraw()

func _draw() -> void:
	var grounded := design in ["sierra","estruendo","coloso"]
	var sy := 1.0-pose_amount*0.12 if grounded else 1.0+sin(t*2.0)*0.025
	var bob := 16*(1-sy) if grounded else sin(t*2.2)*1.2
	draw_set_transform(Vector2(0,bob),0,Vector2(1+pose_amount*0.04,sy))
	match design:
		"sierra": _draw_sierra()
		"estruendo": _draw_estruendo()
		"glaciar": _draw_glaciar()
		"incendio": _draw_incendio()
		"voltaje": _draw_voltaje()
		"coloso": _draw_coloso()
		"espectro": _draw_espectro()
		"enjambre": _draw_enjambre()
		"nucleo": _draw_nucleo()
	_fx_common()

## ---------------------------------------------------------------- helpers
func _b(x: float, y: float, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2(snappedf(x, 2.0), snappedf(y, 2.0),
		maxf(2.0, snappedf(w, 2.0)), maxf(2.0, snappedf(h, 2.0))), col)

## Caja con contorno oscuro de 2 px (estilo sprite con outline).
func _box(x: float, y: float, w: float, h: float, col: Color) -> void:
	_b(x - 2, y - 2, w + 4, h + 4, OUT)
	_b(x, y, w, h, col)
	if w>=10 and h>=8:
		_b(x+2,y,w-4,2,col.lightened(0.25))
		_b(x+w-2,y+2,2,h-2,col.darkened(0.25))
		_b(x,y+h-2,w,2,col.darkened(0.4))
		_b(x,y,2,2,OUT)
		_b(x+w-2,y,2,2,OUT)
	if w>=24 and h>=14:
		for rx in [x+3,x+w-5]: _b(rx,y+h-5,2,2,STEEL_D)

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
	if shielded: draw_arc(Vector2(0,-3),24,-PI*0.1,PI*1.1,24,Color(color,0.65),2)
	if motion_state=="wait" and design in ["sierra","coloso"]:
		draw_arc(Vector2(0,-3),7,t*3,t*3+PI*1.5,12,Color("ffe0a1"),1)
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
	var step := sin(t*10)*minf(1,absf(motion)/30)
	for side in [-1,1]:
		var x: float = side*8
		_box(x-4,4,8,10,color.darkened(0.45))
		_box(x-5,10-maxf(0,step*side)*4,12,6,STEEL_D)
	_box(-13,-13,26,18,color)
	_b(-8,-10,16,4,color.lightened(0.35))
	_box(-9,-25,19,11,STEEL_D)
	_visor(-6,-22,12,4)
	_b(-12,-28,25,4,color)
	for y in [-17,-9,0]: _b(-18,y,5,4,STEEL_D)
	_box(-19,-9,7,16,STEEL_D)
	var arm := Vector2(21+pose_amount*4,-5-pose_amount*9)
	draw_line(Vector2(10,-9),arm,OUT,10)
	draw_line(Vector2(10,-9),arm,STEEL_D,6)
	_disc_o(arm.x,arm.y,14,STEEL_L)
	_disc(arm.x,arm.y,8,STEEL_D)
	_disc(arm.x,arm.y,4,color)
	for i in 8:
		var ray := Vector2.RIGHT.rotated(t*(18 if phase==1 else 6)+i*TAU/8)
		_b(arm.x+ray.x*16-2,arm.y+ray.y*16-2,4,4,AMBER)
	for x in [-7,3]: _b(x,-2,3,4,OUT)
	if motion_state=="act": _dash_lines(1)

func _draw_estruendo() -> void:
	_box(-26,6,52,10,STEEL_D)
	for i in 7:
		_disc(-22+i*7,11,3,RIVET)
		_b(-24+fposmod(i*8+t*absf(motion)*0.3,48),6,4,2,STEEL_L)
	_box(-22,-5,44,12,color.darkened(0.2))
	_box(-16,-16,32,12,color)
	_b(-12,-14,24,3,color.lightened(0.3))
	_box(-7,-27,18,10,STEEL_D)
	_visor(-3,-24,12,4)
	var recoil := 5.0*maxf(0,-pose_amount)
	_box(9-recoil,-18,25,8,STEEL_D)
	_box(30-recoil,-20,7,12,STEEL_L)
	_b(34-recoil,-17,3,6,OUT)
	for x in [-23,-15,-7]:
		_box(x,-18-pose_amount*4,6,9,color.darkened(0.4))
		_b(x+1,-17-pose_amount*4,4,3,AMBER)
	for x in [-18,-6,6,18]: _b(x,1,3,2,RIVET)
	if motion_state=="act": _b(38,-18,7,8,Color("ffe6a8"))

func _draw_glaciar() -> void:
	for i in 5:
		var a := -PI+PI*float(i)/4
		var tip := Vector2(cos(a)*25,sin(a)*25-5)
		draw_colored_polygon(PackedVector2Array([Vector2(-3,0),tip,tip+Vector2(5,7),Vector2(4,4)]),color.darkened(0.35))
		draw_line(tip,tip+Vector2(2,5),GLASS,2)
	_box(-12,-14,24,20,color)
	_box(-8,-19,16,7,color.lightened(0.25))
	_visor(-5,-10,10,8)
	for side in [-1,1]:
		var at := Vector2(side*(22+pose_amount*6),3+sin(t*3+side)*3)
		draw_colored_polygon(PackedVector2Array([at+Vector2(-5,0),at+Vector2(0,-12),at+Vector2(6,0),at+Vector2(0,10)]),color.lightened(0.35))
		_b(at.x-1,at.y-7,2,12,GLASS)
	_b(-4,8,8,7,STEEL_D)
	_b(-2,15,4,7,GLASS)
	for i in 4:
		var a := t*1.8+i*TAU/4
		_disc(cos(a)*28,sin(a)*8-4,2,GLASS)

func _draw_incendio() -> void:
	var flap := sin(t*7)*4-pose_amount*9
	for side in [-1,1]:
		var wing := PackedVector2Array([Vector2(side*8,-8),Vector2(side*30,-21+flap),Vector2(side*42,-7+flap),Vector2(side*22,1),Vector2(side*12,5)])
		draw_colored_polygon(wing,color.darkened(0.4))
		draw_polyline(PackedVector2Array([wing[0],wing[1],wing[2]]),STEEL_D,3)
		_b(side*25-3,-6+flap,6,8,STEEL_D)
		var flame := 8+sin(t*24+side)*4+(10 if motion_state=="act" else 0)
		draw_colored_polygon(PackedVector2Array([Vector2(side*25-3,0+flap),Vector2(side*25+2,flame+flap),Vector2(side*25+5,0+flap)]),FIRE)
	_box(-13,-11,26,22,color)
	_disc_o(0,-1,8,STEEL_D)
	_disc(0,-1,5,Color("ffbe65"))
	_box(-8,-24,18,12,STEEL_D)
	_visor(-4,-20,12,4)
	_b(-9,-29,4,9,color)
	_b(8,-28,4,8,color)
	_b(-5,12,10,4,color.darkened(0.4))
	for i in 3: _b(-2+sin(t*6-i)*i*2,16+i*4,4,3,FIRE)

func _draw_voltaje() -> void:
	for side in [-1,1]:
		_box(side*20-5,-19,10,28,STEEL_D)
		for y in range(-18,8,6): _b(side*20-7,y,14,2,color)
		_disc_o(side*20,-24,6,color.lightened(0.3))
		var bolt := PackedVector2Array([Vector2(side*20,-29),Vector2(side*10,-35-sin(t*18)*3),Vector2(0,-27)])
		draw_polyline(bolt,Color(color,0.6+0.3*sin(t*20)),2)
	_box(-12,-11,24,23,STEEL_D)
	_disc_o(0,-1,8,color)
	_disc(0,-1,4,GLASS)
	_box(-7,-22,14,10,color.darkened(0.25))
	_visor(-5,-18,10,3)
	for side in [-1,1]:
		_b(side*9-2,10,6,5,STEEL_D)
		var a := t*3+float(side)*PI
		draw_arc(Vector2.ZERO,30,a,a+1.0,10,color,2)

func _draw_coloso() -> void:
	for side in [-1,1]:
		_box(side*10-6,5,12,10,color.darkened(0.45))
		_box(side*12-9,11,18,6,STEEL_D)
	_box(-18,-18,36,25,color.darkened(0.2))
	_box(-12,-23,24,11,color)
	_b(-8,-20,14,4,color.lightened(0.3))
	for side in [-1,1]:
		var fist := Vector2(side*(25+maxf(0,-pose_amount)*5),2-pose_amount*21)
		draw_line(Vector2(side*15,-12),fist,OUT,13)
		draw_line(Vector2(side*15,-12),fist,color.darkened(0.4),9)
		_box(fist.x-7,fist.y-5,14,13,STEEL_D)
		_b(fist.x-5,fist.y-3,10,3,color)
	_box(-7,-32,14,11,STEEL_D)
	_visor(-5,-28,10,4)
	for at in [Vector2(-10,-9),Vector2(4,-4),Vector2(8,-17)]:
		draw_polyline(PackedVector2Array([at,at+Vector2(4,4),at+Vector2(1,8)]),OUT,2)
		_b(at.x+1,at.y+2,2,3,AMBER if rage else color.lightened(0.4))

func _draw_espectro() -> void:
	for i in range(3,0,-1):
		var at := Vector2(-i*5,sin(t*4-i)*2)
		draw_colored_polygon(PackedVector2Array([at+Vector2(-8,-18),at+Vector2(9,-16),at+Vector2(14,13),at+Vector2(-12,9)]),Color(color,0.07*i))
	for i in 4:
		var y := -6+i*6
		var w := 11+i*2
		_b(-w+sin(t*5-i)*2,y,w*2,6,Color(color,1.0-i*0.16))
	_box(-9,-23,18,18,color.darkened(0.5))
	_b(-12,-25,24,5,OUT)
	_b(-5,-17,4,3,GLASS)
	_b(3,-17,4,3,GLASS)
	_b(-2,-10,5,2,STEEL_D)
	var hand := Vector2(23+pose_amount*5,-4-pose_amount*9)
	draw_line(Vector2(8,-8),hand,STEEL_D,4)
	draw_line(hand+Vector2(0,-22),hand+Vector2(0,19),OUT,5)
	draw_arc(hand+Vector2(1,-12),15,-PI*0.7,PI*0.6,16,color.lightened(0.4),4)

func _draw_enjambre() -> void:
	var flap := sin(t*12)*8
	for side in [-1,1]:
		for layer in 2:
			var at := Vector2(side*10,-8+layer*7)
			var tip := Vector2(side*(33-layer*5),-22+flap+layer*12)
			draw_colored_polygon(PackedVector2Array([at,tip,tip+Vector2(side*10,11),at+Vector2(0,7)]),Color("b0d3db",0.45))
			draw_line(at,tip,STEEL_L,1)
		for i in 3:
			var knee := Vector2(side*(20+i*2),2+i*4)
			draw_polyline(PackedVector2Array([Vector2(side*8,i*4),knee,knee+Vector2(side*5,6)]),color.darkened(0.4),3)
	for i in range(3,-1,-1):
		_disc_o(0,i*6,9-i,color.darkened(i*0.1))
		_b(-3,i*6-1,6,2,color.lightened(0.25))
	_box(-10,-17,20,15,color)
	_box(-7,-26,14,9,color.darkened(0.35))
	_visor(-5,-23,10,4)
	for side in [-1,1]: draw_line(Vector2(side*4,-26),Vector2(side*10,-35),STEEL_D,2)
	_b(-2,22,4,5,STEEL_L)
	if action in ["brood","nest_guard"]: _disc(0,2,5,GLASS)

func _draw_nucleo() -> void:
	var hot := color.lightened(0.28)
	var deep := color.darkened(0.45)
	var pulse := 1.0 + 0.12*sin(t*7.0)
	# cuerpo central
	_disc_o(0,-4,13*float(pulse),deep)
	_disc(0,-4,9,color)
	_disc(0,-4,4,Color.WHITE if phase==0 and action!="" else hot)
	# anillos mecanicos contrarrotando
	for ring_i in 3:
		var radius := 18.0+float(ring_i)*6.0
		var spin := t*(2.4+ring_i*0.9)*(1.0 if ring_i%2==0 else -1.0)
		for i in 6:
			var a := spin+TAU*float(i)/6.0
			var at := Vector2(cos(a)*radius,sin(a)*radius*0.48-4)
			_b(at.x-2,at.y-2,4,4,hot if (i+ring_i)%2==0 else STEEL_L)
	# satelites que se abren en fase de ataque
	var orbit := snappedf(t*3.5,TAU/16.0)
	for i in 4:
		var a := orbit+TAU*float(i)/4.0
		var r := 34.0 if phase==1 else 28.0
		var at := Vector2(cos(a)*r,sin(a)*r*0.42-4)
		_disc_o(at.x,at.y,4,STEEL_D)
		_disc(at.x,at.y,2,hot)
	# visor vertical / nucleo de mando
	_box(-5,-22,10,7,STEEL)
	_visor(-3,-20,6,3)
	# energia hacia abajo para dejar claro que flota
	var flame_h := 6.0+float(int(t*12.0)%3)*2.0
	_b(-6,10,4,flame_h,Color("7cf5ff"))
	_b(2,10,4,flame_h+2,Color("ff73df"))
	if rage and int(t*10.0)%2==0:
		_b(-30,-8,6,2,Color.WHITE)
		_b(24,-8,6,2,Color.WHITE)
