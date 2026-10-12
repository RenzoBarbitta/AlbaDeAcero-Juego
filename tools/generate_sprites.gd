extends SceneTree
## Generador de sprites retro con degradados estilo 8/16 bits.
## Ejecutar: godot --headless --path . --script res://tools/generate_sprites.gd

const T := Color(0, 0, 0, 0)
const OUT := Color("0a0a14")
const WH := Color("ffffff")
const MET := Color("a8b0c0")
const METL := Color("d7dbe6")
const METD := Color("5a6070")
const YEL := Color("ffd15c")
const RED := Color("e5402f")
const ORG := Color("ff8c42")
const GRN := Color("57d16a")
const GRND := Color("2f8f45")
const CYAN := Color("39d0ff")
const CYANL := Color("8be9ff")

const BASE := "res://assets/sprites/"

# ----- Paletas de personajes jugables -----
# Cada personaje tiene una identidad visual propia (silueta, casco, visor),
# no un simple recolor del mismo molde.
const CHARS := {
	"orange": {
		"style": "classic",
		"epithet": "CAZADOR",
		"main": Color("ff7a1a"), "light": Color("ffc266"), "dark": Color("a83c00"),
		"trim": Color("3a3f5c"), "trimd": Color("20243a"),
		"eye": Color("6ff0ff"), "energy": Color("ffe14d"),
		"face": Color("f6c89c"), "faced": Color("c98d63"),
	},
	"red": {
		"style": "heavy",
		"epithet": "BLINDAJE",
		"main": Color("e5342a"), "light": Color("ff9a7a"), "dark": Color("8a140f"),
		"trim": Color("2a2f4a"), "trimd": Color("171a2c"),
		"eye": Color("ffe14d"), "energy": Color("ffb03a"),
		"face": Color("f6c89c"), "faced": Color("c98d63"),
	},
	"black": {
		"style": "stealth",
		"epithet": "SOMBRA",
		"main": Color("3a4056"), "light": Color("7d86a8"), "dark": Color("12141f"),
		"trim": Color("c02040"), "trimd": Color("5a0f20"),
		"eye": Color("ff3355"), "energy": Color("ff5bc0"),
		"face": Color("c3c9dc"), "faced": Color("828aa6"),
	},
	"violet": {
		"style": "mage",
		"epithet": "ARCANO",
		"main": Color("7a4cff"), "light": Color("c0a8ff"), "dark": Color("40208c"),
		"trim": Color("2f6bff"), "trimd": Color("1b3a99"),
		"eye": Color("4fd0ff"), "energy": Color("5ba8ff"),
		"face": Color("f6c89c"), "faced": Color("c98d63"),
	},
}

func _initialize() -> void:
	_gen_players()
	_gen_enemies()
	_gen_projectiles()
	_gen_tiles()
	_gen_fx()
	_gen_pickups()
	_gen_backgrounds()
	print("SPRITES_DONE")
	quit()

# ============================================================
# Helpers de dibujo
# ============================================================
func _new(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(T)
	return img

func _rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for yy in range(y, y + h):
		if yy < 0 or yy >= img.get_height():
			continue
		for xx in range(x, x + w):
			if xx < 0 or xx >= img.get_width():
				continue
			img.set_pixel(xx, yy, col)

func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, col)

## Relleno con degradado vertical top->bot.
func _vgrad(img: Image, x: int, y: int, w: int, h: int, top: Color, bot: Color) -> void:
	if h <= 1:
		_rect(img, x, y, w, h, top)
		return
	for i in h:
		var c := top.lerp(bot, float(i) / float(h - 1))
		_rect(img, x, y + i, w, 1, c)

## Relleno con degradado horizontal left->right.
func _hgrad(img: Image, x: int, y: int, w: int, h: int, left: Color, right: Color) -> void:
	if w <= 1:
		_rect(img, x, y, w, h, left)
		return
	for i in w:
		var c := left.lerp(right, float(i) / float(w - 1))
		_rect(img, x + i, y, 1, h, c)

## Orbe (cÃ­rculo relleno con degradado radial).
func _orb(img: Image, cx: int, cy: int, r: float, core: Color, mid: Color, edge: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var d := Vector2(x - cx, y - cy).length()
			if d <= r:
				var t := d / r
				var c: Color = core.lerp(mid, clampf(t * 1.6, 0.0, 1.0)) if t < 0.5 else mid.lerp(edge, (t - 0.5) * 2.0)
				img.set_pixel(x, y, c)

func _outline(img: Image, col: Color = OUT) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var pts: Array[Vector2i] = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				continue
			var near := false
			if x > 0 and img.get_pixel(x - 1, y).a > 0.0: near = true
			elif x < w - 1 and img.get_pixel(x + 1, y).a > 0.0: near = true
			elif y > 0 and img.get_pixel(x, y - 1).a > 0.0: near = true
			elif y < h - 1 and img.get_pixel(x, y + 1).a > 0.0: near = true
			if near:
				pts.append(Vector2i(x, y))
	for p in pts:
		img.set_pixel(p.x, p.y, col)

func _save(img: Image, path: String) -> void:
	var abs := ProjectSettings.globalize_path(path)
	var dir := abs.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err := img.save_png(abs)
	if err != OK:
		push_error("save_png failed %s (%s)" % [path, err])

# ============================================================
# ROBOTS JUGABLES (22 x 28, origen en los pies)
# ============================================================
func _robot(ch: Dictionary, opts: Dictionary) -> Image:
	var img := _new(22, 28)
	match String(ch.get("style", "classic")):
		"heavy":
			_draw_heavy(img, ch, opts)
		"stealth":
			_draw_stealth(img, ch, opts)
		"mage":
			_draw_mage(img, ch, opts)
		_:
			_draw_classic(img, ch, opts)
	if opts.get("hurt", false):
		for y in 28:
			for x in 22:
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, Color(4, 4, 4))
	_outline(img)
	return img

func _o(opts: Dictionary) -> Dictionary:
	return {
		"bob": opts.get("bob", 0),
		"hb": opts.get("headbob", 0),
		"legL": opts.get("legL", Vector2i.ZERO),
		"legR": opts.get("legR", Vector2i.ZERO),
		"arm": opts.get("arm", false),
	}

# ----- NARANJA - CAZADOR (clÃ¡sico, veloz, visor ancho) -----
func _draw_classic(img: Image, ch: Dictionary, opts: Dictionary) -> void:
	var o := _o(opts)
	var oy: int = o.bob
	var hy: int = oy + o.hb
	var legL: Vector2i = o.legL
	var legR: Vector2i = o.legR
	var arm: bool = o.arm
	var main: Color = ch.main
	var light: Color = ch.light
	var dark: Color = ch.dark
	var trim: Color = ch.trim
	var trimd: Color = ch.trimd
	var eye: Color = ch.eye
	var energy: Color = ch.energy
	# Pierna trasera
	_vgrad(img, 6 + legL.x, 20 + oy + legL.y, 4, 5, dark.lerp(main, 0.3), trimd)
	_rect(img, 5 + legL.x, 25 + oy + legL.y, 5, 3, trimd)
	_rect(img, 6 + legL.x, 26 + oy + legL.y, 3, 1, main)
	_rect(img, 5 + legL.x, 27 + oy + legL.y, 5, 1, trim)
	# Brazo trasero
	_rect(img, 3, 12 + oy, 3, 6, dark)
	_px(img, 3, 12 + oy, main.lerp(WH, 0.45))
	_rect(img, 3, 17 + oy, 3, 1, trimd)
	# Torso
	_vgrad(img, 6, 11 + oy, 10, 9, light, main)
	_rect(img, 6, 11 + oy, 10, 1, main.lerp(WH, 0.5))
	_rect(img, 6, 19 + oy, 10, 1, dark)
	_rect(img, 6, 13 + oy, 2, 6, trim)
	_rect(img, 14, 13 + oy, 2, 6, trim)
	_rect(img, 9, 13 + oy, 3, 4, trim.lerp(dark, 0.2))
	_px(img, 9, 13 + oy, trim)
	_rect(img, 10, 14 + oy, 3, 2, energy)
	_px(img, 11, 14 + oy, WH)
	_px(img, 11, 16 + oy, dark)
	# Cinturon
	_rect(img, 6, 20 + oy, 10, 2, trimd)
	_px(img, 10, 20 + oy, YEL)
	_px(img, 11, 20 + oy, YEL)
	_px(img, 12, 20 + oy, YEL)
	# Pierna delantera
	_vgrad(img, 11 + legR.x, 20 + oy + legR.y, 4, 5, main, dark)
	_rect(img, 11 + legR.x, 24 + oy + legR.y, 5, 4, trim)
	_rect(img, 11 + legR.x, 24 + oy + legR.y, 5, 1, light)
	_rect(img, 12 + legR.x, 26 + oy + legR.y, 3, 2, light.lerp(main, 0.5))
	_rect(img, 11 + legR.x, 27 + oy + legR.y, 5, 1, trimd)
	# Hombro delantero con codo
	_vgrad(img, 15, 12 + oy, 3, 6, main, dark)
	_rect(img, 15, 12 + oy, 3, 1, light)
	_px(img, 15, 16 + oy, trim)
	_px(img, 16, 16 + oy, trim)
	if arm:
		_rect(img, 16, 13 + oy, 5, 4, trim)
		_rect(img, 16, 13 + oy, 5, 1, light)
		_rect(img, 20, 14 + oy, 2, 2, energy)
		_px(img, 21, 14 + oy, WH)
	else:
		_rect(img, 17, 14 + oy, 3, 4, trim)
		_rect(img, 17, 14 + oy, 3, 1, light)
		_rect(img, 19, 15 + oy, 1, 2, energy)
	# Cabeza: casco clasico con aletas y cresta
	_rect(img, 3, 6 + hy, 3, 3, trim)
	_rect(img, 3, 9 + hy, 3, 1, trimd)
	_rect(img, 16, 6 + hy, 3, 3, trim)
	_rect(img, 16, 9 + hy, 3, 1, trimd)
	_vgrad(img, 5, 3 + hy, 12, 7, light, main)
	_rect(img, 5, 3 + hy, 12, 1, main.lerp(WH, 0.5))
	_rect(img, 5, 9 + hy, 12, 1, dark)
	_rect(img, 10, 1 + hy, 2, 3, energy)
	_px(img, 10, 1 + hy, WH)
	_px(img, 11, 2 + hy, WH)
	_rect(img, 7, 6 + hy, 8, 3, dark)
	_rect(img, 8, 6 + hy, 6, 2, eye)
	_px(img, 8, 6 + hy, WH)
	_px(img, 11, 7 + hy, eye.lerp(WH, 0.45))
	_rect(img, 6, 9 + hy, 1, 2, trim)
	_rect(img, 15, 9 + hy, 1, 2, trim)
	# Mejillas y barbilla
	_rect(img, 8, 10 + hy, 5, 2, ch.face)
	_rect(img, 9, 11 + hy, 3, 1, ch.faced)
	_px(img, 8, 10 + hy, ch.faced)

# ----- ROJO - BLINDAJE (pesado, ancho, hombreras y cresta alta) -----
func _draw_heavy(img: Image, ch: Dictionary, opts: Dictionary) -> void:
	var o := _o(opts)
	var oy: int = o.bob
	var hy: int = oy + o.hb
	var legL: Vector2i = o.legL
	var legR: Vector2i = o.legR
	var arm: bool = o.arm
	var main: Color = ch.main
	var light: Color = ch.light
	var dark: Color = ch.dark
	var trim: Color = ch.trim
	var trimd: Color = ch.trimd
	var eye: Color = ch.eye
	var energy: Color = ch.energy
	# Pierna trasera ancha con blindaje
	_vgrad(img, 6 + legL.x, 20 + oy + legL.y, 4, 5, dark.lerp(main, 0.2), trimd)
	_rect(img, 5 + legL.x, 25 + oy + legL.y, 6, 3, trimd)
	_rect(img, 5 + legL.x, 27 + oy + legL.y, 6, 1, trim)
	_rect(img, 6 + legL.x, 25 + oy + legL.y, 4, 1, trimd.lerp(main, 0.3))
	# Hombro trasero con pica y cierres
	_vgrad(img, 1, 10 + oy, 5, 6, dark, trimd)
	_px(img, 1, 10 + oy, YEL)
	_rect(img, 3, 12 + oy, 3, 4, dark)
	_rect(img, 2, 13 + oy, 2, 1, YEL)
	_rect(img, 2, 16 + oy, 2, 1, YEL)
	# Torso ancho con placas laterales
	_vgrad(img, 6, 11 + oy, 12, 9, light, main)
	_rect(img, 6, 11 + oy, 12, 1, main.lerp(WH, 0.5))
	_rect(img, 7, 19 + oy, 11, 1, dark)
	_rect(img, 6, 13 + oy, 2, 6, trim)
	_rect(img, 16, 13 + oy, 2, 6, trim)
	# Caja del nÃºcleo con remaches
	_rect(img, 10, 13 + oy, 4, 4, trim)
	_rect(img, 11, 14 + oy, 2, 2, energy)
	_px(img, 11, 14 + oy, WH)
	_px(img, 11, 15 + oy, energy)
	_px(img, 10, 13 + oy, WH)
	_px(img, 13, 16 + oy, WH)
	# CinturÃ³n pesado con mecha central
	_rect(img, 6, 20 + oy, 12, 2, trimd)
	_rect(img, 7, 21 + oy, 2, 1, YEL)
	_rect(img, 13, 21 + oy, 2, 1, YEL)
	_px(img, 11, 20 + oy, YEL)
	# Pierna delantera ancha con espinillera
	_vgrad(img, 12 + legR.x, 20 + oy + legR.y, 4, 5, main, dark)
	_rect(img, 11 + legR.x, 24 + oy + legR.y, 6, 4, trim)
	_rect(img, 11 + legR.x, 24 + oy + legR.y, 6, 1, light)
	_rect(img, 13 + legR.x, 25 + oy + legR.y, 3, 3, light.lerp(main, 0.35))
	_rect(img, 11 + legR.x, 27 + oy + legR.y, 6, 1, trimd)
	# Hombro delantero + caÃ±Ã³n con doble etapa
	_vgrad(img, 15, 10 + oy, 5, 6, main, dark)
	_rect(img, 15, 10 + oy, 5, 1, light)
	_px(img, 19, 10 + oy, WH)
	if arm:
		_rect(img, 17, 14 + oy, 5, 4, trim)
		_rect(img, 17, 14 + oy, 5, 1, light)
		_rect(img, 17, 15 + oy, 1, 2, trim.lerp(WH, 0.3))
		_rect(img, 19, 15 + oy, 2, 2, energy)
		_px(img, 20, 15 + oy, WH)
	else:
		_rect(img, 17, 14 + oy, 4, 4, trim)
		_rect(img, 17, 14 + oy, 4, 1, light)
		_px(img, 20, 15 + oy, energy)
	# Cabeza / casco boxy con cresta-eje y carrilleras
	_rect(img, 4, 5 + hy, 2, 4, trimd)
	_vgrad(img, 6, 3 + hy, 11, 7, light, main)
	_rect(img, 6, 3 + hy, 11, 1, main.lerp(WH, 0.5))
	_rect(img, 9, 0 + hy, 4, 4, energy)
	_rect(img, 10, 0 + hy, 2, 1, WH)
	_px(img, 8, 2 + hy, WH)
	_px(img, 12, 1 + hy, WH)
	# Visor tipo rendija con doble punto brillante
	_rect(img, 7, 7 + hy, 9, 3, dark)
	_rect(img, 8, 7 + hy, 7, 2, eye)
	_px(img, 8, 7 + hy, WH)
	_px(img, 14, 7 + hy, WH)
	# MandÃ­bula rejilla
	_rect(img, 9, 10 + hy, 5, 2, ch.face)
	_rect(img, 8, 11 + hy, 7, 1, ch.faced)
	_px(img, 9, 10 + hy, ch.faced)
	_rect(img, 6, 6 + hy, 1, 2, trim)
	_rect(img, 17, 6 + hy, 1, 2, trim)

# ----- NEGRO - SOMBRA (sigiloso, delgado, antena, mÃ¡scara) -----
func _draw_stealth(img: Image, ch: Dictionary, opts: Dictionary) -> void:
	var o := _o(opts)
	var oy: int = o.bob
	var hy: int = oy + o.hb
	var legL: Vector2i = o.legL
	var legR: Vector2i = o.legR
	var arm: bool = o.arm
	var main: Color = ch.main
	var light: Color = ch.light
	var dark: Color = ch.dark
	var trim: Color = ch.trim
	var trimd: Color = ch.trimd
	var eye: Color = ch.eye
	var energy: Color = ch.energy
	# Pierna trasera delgada con cuchilla de bota
	_vgrad(img, 7 + legL.x, 20 + oy + legL.y, 3, 5, dark, trimd)
	_rect(img, 6 + legL.x, 24 + oy + legL.y, 4, 4, trimd)
	_px(img, 5 + legL.x, 27 + oy + legL.y, trimd)
	_px(img, 5 + legL.x, 26 + oy + legL.y, trimd)
	_rect(img, 6 + legL.x, 25 + oy + legL.y, 3, 1, trimd.lerp(main, 0.25))
	# Cola / faldÃ³n detrÃ¡s con filo de luz
	_rect(img, 3, 12 + oy, 3, 5, dark)
	_px(img, 4, 12 + oy, trim)
	_px(img, 4, 17 + oy, trim)
	_px(img, 4, 14 + oy, eye)
	# Torso esbelto con correas diagonales
	_vgrad(img, 7, 11 + oy, 8, 9, light, main)
	_rect(img, 7, 11 + oy, 8, 1, main.lerp(WH, 0.45))
	_rect(img, 7, 19 + oy, 8, 1, dark)
	_rect(img, 7, 13 + oy, 1, 5, trim)
	_rect(img, 14, 13 + oy, 1, 5, trim)
	_rect(img, 8, 14 + oy, 1, 4, dark)
	_rect(img, 13, 14 + oy, 1, 4, dark)
	_rect(img, 10, 14 + oy, 2, 3, energy)
	_px(img, 11, 14 + oy, WH)
	_rect(img, 7, 20 + oy, 8, 2, trimd)
	_px(img, 9, 20 + oy, eye)
	_px(img, 13, 20 + oy, eye)
	# Pierna delantera delgada con rodillera
	_vgrad(img, 12 + legR.x, 20 + oy + legR.y, 4, 5, main, dark)
	_rect(img, 12 + legR.x, 24 + oy + legR.y, 5, 4, trim)
	_rect(img, 12 + legR.x, 26 + oy + legR.y, 5, 1, light)
	_px(img, 16 + legR.x, 27 + oy + legR.y, trim)
	_px(img, 13 + legR.x, 25 + oy + legR.y, WH)
	# Hombro + brazo delantero
	_rect(img, 5, 12 + oy, 2, 3, dark)
	if arm:
		_rect(img, 15, 13 + oy, 6, 3, trim)
		_rect(img, 15, 13 + oy, 6, 1, light)
		_rect(img, 20, 14 + oy, 2, 2, energy)
		_px(img, 21, 14 + oy, WH)
	else:
		_rect(img, 15, 13 + oy, 4, 4, trim)
		_rect(img, 15, 13 + oy, 4, 1, light)
		_px(img, 19, 15 + oy, energy)
	# Cabeza / casco angosto con antena y visor de banda
	_rect(img, 10, 0 + hy, 1, 2, METL)
	_px(img, 10, 0 + hy, trim)
	_px(img, 9, 1 + hy, eye)
	_vgrad(img, 8, 2 + hy, 6, 7, light, main)
	_rect(img, 8, 2 + hy, 6, 1, main.lerp(WH, 0.45))
	_rect(img, 9, 9 + hy, 4, 1, dark)
	_rect(img, 7, 3 + hy, 1, 2, trim)
	_rect(img, 14, 3 + hy, 1, 2, trim)
	# Visor completo con ojo refulgente y segmento
	_rect(img, 6, 6 + hy, 10, 3, Color("0a0a14"))
	_rect(img, 8, 6 + hy, 6, 2, eye)
	_px(img, 8, 6 + hy, WH)
	_px(img, 13, 6 + hy, WH)
	_px(img, 12, 7 + hy, WH)
	# Mascarilla (sin cara) con ventilaciÃ³n
	_rect(img, 8, 9 + hy, 6, 2, Color("1b1e30"))
	_px(img, 10, 10 + hy, eye)
	_px(img, 12, 10 + hy, eye)

# ----- VIOLETA - ARCANO (mago, tÃºnica, corona, ojos duales) -----
func _draw_mage(img: Image, ch: Dictionary, opts: Dictionary) -> void:
	var o := _o(opts)
	var oy: int = o.bob
	var hy: int = oy + o.hb
	var legL: Vector2i = o.legL
	var legR: Vector2i = o.legR
	var arm: bool = o.arm
	var main: Color = ch.main
	var light: Color = ch.light
	var dark: Color = ch.dark
	var trim: Color = ch.trim
	var trimd: Color = ch.trimd
	var eye: Color = ch.eye
	var energy: Color = ch.energy
	# TÃºnica / faldÃ³n con estola y bordes luminosos
	_vgrad(img, 7, 20 + oy, 8, 5, dark, trimd)
	_rect(img, 6, 24 + oy, 10, 4, trim)
	_rect(img, 7, 24 + oy, 8, 1, light)
	_rect(img, 6, 27 + oy, 10, 1, trimd)
	_px(img, 13, 25 + oy, energy)
	_rect(img, 8, 23 + oy, 6, 1, trim.lerp(dark, 0.2))
	# Drape trasero con filo
	_rect(img, 5, 21 + oy, 2, 4, dark)
	_px(img, 5, 24 + oy, trim.lerp(dark, 0.2))
	# Torso con runas laterales
	_vgrad(img, 7, 11 + oy, 8, 9, light, main)
	_rect(img, 7, 11 + oy, 8, 1, main.lerp(WH, 0.4))
	_rect(img, 7, 19 + oy, 8, 1, dark)
	_rect(img, 7, 13 + oy, 1, 6, trim)
	_rect(img, 14, 13 + oy, 1, 6, trim)
	_px(img, 8, 15 + oy, energy)
	_px(img, 8, 17 + oy, energy)
	_px(img, 13, 15 + oy, energy)
	# Cristal del pecho con halo
	_rect(img, 10, 13 + oy, 3, 4, trim)
	_px(img, 9, 14 + oy, energy)
	_px(img, 13, 14 + oy, energy)
	_rect(img, 11, 14 + oy, 1, 2, WH)
	_px(img, 10, 14 + oy, energy)
	_px(img, 11, 15 + oy, energy)
	# Orbes flotantes en hombros
	_px(img, 5, 11 + oy, energy)
	_px(img, 16, 11 + oy, energy)
	_px(img, 5, 12 + oy, WH)
	_px(img, 16, 12 + oy, WH)
	# Brazo delantero
	if arm:
		_rect(img, 15, 12 + oy, 6, 4, trim)
		_rect(img, 15, 12 + oy, 6, 1, light)
		_rect(img, 20, 14 + oy, 2, 2, energy)
		_px(img, 21, 14 + oy, WH)
	else:
		_rect(img, 15, 12 + oy, 3, 6, main)
		_rect(img, 17, 14 + oy, 4, 3, trim)
		_rect(img, 17, 14 + oy, 4, 1, light)
		_px(img, 19, 15 + oy, energy)
	# Cabeza / casco con corona de tres pÃºas y gemas
	_px(img, 8, 0 + hy, energy)
	_px(img, 12, 0 + hy, energy)
	_px(img, 10, 0 + hy, WH)
	_px(img, 10, 1 + hy, YEL)
	_rect(img, 8, 1 + hy, 6, 1, trim)
	_px(img, 8, 1 + hy, WH)
	_px(img, 12, 1 + hy, WH)
	_vgrad(img, 7, 2 + hy, 8, 7, light, main)
	_rect(img, 7, 2 + hy, 8, 1, main.lerp(WH, 0.4))
	_rect(img, 6, 4 + hy, 1, 4, trim)
	_rect(img, 15, 4 + hy, 1, 4, trim)
	_px(img, 6, 5 + hy, energy)
	_px(img, 15, 5 + hy, energy)
	# Ojos duales mÃ­sticos y visor-lunar
	_rect(img, 8, 6 + hy, 2, 2, dark)
	_px(img, 8, 6 + hy, eye)
	_px(img, 9, 6 + hy, WH)
	_rect(img, 12, 6 + hy, 2, 2, dark)
	_px(img, 13, 6 + hy, eye)
	_px(img, 12, 6 + hy, WH)
	_rect(img, 10, 5 + hy, 2, 1, dark)
	# Boca
	_rect(img, 10, 9 + hy, 2, 1, ch.face)
	_rect(img, 10, 10 + hy, 2, 1, ch.faced)

func _gen_players() -> void:
	for id in CHARS.keys():
		var ch: Dictionary = CHARS[id]
		var dir: String = BASE + "player/" + str(id) + "/"
		_save(_robot(ch, {}), dir + "idle_0.png")
		_save(_robot(ch, {"headbob": 1}), dir + "idle_1.png")
		_save(_robot(ch, {"arm": false, "bob": 0}), dir + "shoot.png")
		_save(_arm(ch), BASE + "ui/arm_" + id + ".png")
		_save(_robot(ch, {"legL": Vector2i(0, 0), "legR": Vector2i(1, 0)}), dir + "run_0.png")
		_save(_robot(ch, {"legL": Vector2i(-1, 0), "legR": Vector2i(1, -1), "bob": -1}), dir + "run_1.png")
		_save(_robot(ch, {"legL": Vector2i(1, 0), "legR": Vector2i(0, 0)}), dir + "run_2.png")
		_save(_robot(ch, {"legL": Vector2i(1, -1), "legR": Vector2i(-1, 0), "bob": -1}), dir + "run_3.png")
		_save(_robot(ch, {"legL": Vector2i(0, -2), "legR": Vector2i(1, -2), "bob": -1}), dir + "jump.png")
		_save(_robot(ch, {"legL": Vector2i(-1, 0), "legR": Vector2i(1, 0)}), dir + "fall.png")
		_save(_robot(ch, {"legL": Vector2i(-2, 0), "legR": Vector2i(2, 0), "arm": true, "bob": 1}), dir + "dash.png")
		_save(_robot(ch, {"hurt": true}), dir + "hurt.png")
		# Retrato para la selecciÃ³n de personaje
		_save(_head(ch), BASE + "ui/head_" + id + ".png")

func _head(ch: Dictionary) -> Image:
	var img := _new(16, 16)
	match String(ch.get("style", "classic")):
		"heavy":
			_draw_head_heavy(img, ch)
		"stealth":
			_draw_head_stealth(img, ch)
		"mage":
			_draw_head_mage(img, ch)
		_:
			_draw_head_classic(img, ch)
	_outline(img)
	return img

# ----- Brazo / cañón rotatorio (apunta hacia el cursor) -----
func _arm(ch: Dictionary) -> Image:
	match String(ch.get("style", "classic")):
		"heavy":
			return _arm_heavy(ch)
		"stealth":
			return _arm_stealth(ch)
		"mage":
			return _arm_mage(ch)
		_:
			return _arm_classic(ch)

func _arm_classic(ch: Dictionary) -> Image:
	var img := _new(8, 5)
	var main: Color = ch.main
	var light: Color = ch.light
	var dark: Color = ch.dark
	var trim: Color = ch.trim
	var trimd: Color = ch.trimd
	var energy: Color = ch.energy
	_rect(img, 0, 1, 3, 3, trim)
	_rect(img, 0, 1, 3, 1, light)
	_vgrad(img, 2, 1, 4, 3, main, dark)
	_rect(img, 2, 1, 4, 1, main.lerp(WH, 0.35))
	_px(img, 3, 3, trimd)
	_px(img, 4, 3, trimd)
	_rect(img, 6, 1, 2, 3, energy)
	_px(img, 6, 2, WH)
	_px(img, 7, 2, WH)
	_outline(img)
	return img

func _arm_heavy(ch: Dictionary) -> Image:
	var img := _new(9, 5)
	var main: Color = ch.main
	var light: Color = ch.light
	var dark: Color = ch.dark
	var trim: Color = ch.trim
	var trimd: Color = ch.trimd
	var energy: Color = ch.energy
	_rect(img, 0, 1, 4, 3, trim)
	_rect(img, 0, 1, 4, 1, light)
	_rect(img, 5, 1, 3, 3, main)
	_rect(img, 5, 1, 3, 1, main.lerp(WH, 0.3))
	_px(img, 1, 2, YEL)
	_px(img, 3, 3, trimd)
	_px(img, 5, 3, trimd)
	_rect(img, 8, 1, 1, 3, energy)
	_px(img, 8, 2, WH)
	_outline(img)
	return img

func _arm_stealth(ch: Dictionary) -> Image:
	var img := _new(8, 4)
	var main: Color = ch.main
	var light: Color = ch.light
	var trim: Color = ch.trim
	var trimd: Color = ch.trimd
	var eye: Color = ch.eye
	_rect(img, 0, 1, 2, 2, trim)
	_rect(img, 0, 1, 2, 1, light)
	_rect(img, 2, 1, 5, 2, main)
	_rect(img, 2, 1, 4, 1, main.lerp(WH, 0.4))
	_rect(img, 7, 1, 1, 2, eye)
	_px(img, 7, 2, WH)
	_px(img, 3, 2, trimd)
	_outline(img)
	return img

func _arm_mage(ch: Dictionary) -> Image:
	var img := _new(9, 5)
	var main: Color = ch.main
	var light: Color = ch.light
	var trim: Color = ch.trim
	var trimd: Color = ch.trimd
	var energy: Color = ch.energy
	_rect(img, 0, 1, 3, 3, trim)
	_rect(img, 0, 1, 3, 1, light)
	_px(img, 1, 3, energy)
	_rect(img, 3, 2, 3, 1, trim)
	_px(img, 4, 2, main)
	_rect(img, 6, 1, 3, 3, energy)
	_px(img, 6, 1, WH)
	_px(img, 7, 3, WH)
	_px(img, 8, 2, WH)
	_outline(img)
	return img

func _draw_head_classic(img: Image, ch: Dictionary) -> void:
	_rect(img, 0, 6, 3, 4, ch.trim)
	_rect(img, 0, 9, 3, 1, ch.trimd)
	_rect(img, 13, 6, 3, 4, ch.trim)
	_rect(img, 13, 9, 3, 1, ch.trimd)
	_vgrad(img, 2, 2, 12, 10, ch.light, ch.main)
	_rect(img, 2, 2, 12, 1, ch.main.lerp(WH, 0.5))
	_rect(img, 2, 11, 12, 1, ch.dark)
	_rect(img, 7, 0, 2, 3, ch.energy)
	_px(img, 7, 0, WH)
	_px(img, 8, 1, WH)
	_rect(img, 4, 6, 8, 4, ch.dark)
	_rect(img, 5, 6, 6, 3, ch.eye)
	_px(img, 5, 6, WH)
	_px(img, 9, 7, ch.eye.lerp(WH, 0.45))
	_rect(img, 5, 10, 6, 2, ch.face)
	_rect(img, 6, 11, 4, 1, ch.faced)
	_px(img, 5, 10, ch.faced)
	_px(img, 5, 4, ch.main.lerp(WH, 0.35))
	_px(img, 12, 4, ch.main.lerp(WH, 0.35))

func _draw_head_heavy(img: Image, ch: Dictionary) -> void:
	_rect(img, 1, 5, 1, 4, ch.trim)
	_rect(img, 14, 5, 1, 4, ch.trim)
	_vgrad(img, 2, 2, 12, 10, ch.light, ch.main)
	_rect(img, 2, 2, 12, 1, ch.main.lerp(WH, 0.5))
	_rect(img, 2, 11, 12, 1, ch.dark)
	_rect(img, 6, 0, 4, 3, ch.energy)
	_px(img, 6, 0, WH)
	_px(img, 9, 0, WH)
	_px(img, 7, 1, WH)
	_rect(img, 3, 6, 10, 3, ch.dark)
	_rect(img, 4, 6, 8, 2, ch.eye)
	_px(img, 4, 6, WH)
	_px(img, 11, 6, WH)
	_px(img, 8, 7, ch.eye.lerp(WH, 0.4))
	_rect(img, 5, 10, 6, 2, ch.face)
	_px(img, 5, 10, ch.faced)
	_rect(img, 6, 11, 4, 1, ch.faced)
	_rect(img, 3, 4, 1, 1, ch.trim)
	_rect(img, 12, 4, 1, 1, ch.trim)

func _draw_head_stealth(img: Image, ch: Dictionary) -> void:
	_rect(img, 7, 0, 2, 2, METL)
	_px(img, 7, 0, ch.trim)
	_px(img, 8, 1, ch.eye)
	_vgrad(img, 3, 2, 10, 8, ch.light, ch.main)
	_rect(img, 3, 2, 10, 1, ch.main.lerp(WH, 0.45))
	_rect(img, 2, 6, 12, 3, Color("0a0a14"))
	_rect(img, 3, 6, 10, 2, ch.eye)
	_px(img, 3, 6, WH)
	_px(img, 12, 6, WH)
	_px(img, 9, 7, WH)
	_rect(img, 4, 9, 8, 2, Color("1b1e30"))
	_px(img, 7, 10, ch.eye)
	_px(img, 9, 10, ch.eye)
	_px(img, 3, 4, ch.trim)
	_px(img, 12, 4, ch.trim)
	_rect(img, 5, 11, 6, 1, Color("0a0a14"))

func _draw_head_mage(img: Image, ch: Dictionary) -> void:
	_px(img, 5, 0, ch.energy)
	_px(img, 10, 0, ch.energy)
	_px(img, 7, 0, WH)
	_px(img, 8, 1, YEL)
	_rect(img, 5, 1, 6, 1, ch.trim)
	_px(img, 5, 1, WH)
	_px(img, 10, 1, WH)
	_vgrad(img, 3, 2, 10, 8, ch.light, ch.main)
	_rect(img, 3, 2, 10, 1, ch.main.lerp(WH, 0.4))
	_rect(img, 2, 4, 1, 5, ch.trim)
	_rect(img, 13, 4, 1, 5, ch.trim)
	_px(img, 2, 5, ch.energy)
	_px(img, 13, 5, ch.energy)
	_rect(img, 5, 6, 2, 2, ch.dark)
	_px(img, 5, 6, ch.eye)
	_px(img, 6, 6, WH)
	_rect(img, 9, 6, 2, 2, ch.dark)
	_px(img, 10, 6, ch.eye)
	_px(img, 9, 6, WH)
	_rect(img, 7, 5, 2, 1, ch.dark)
	_rect(img, 7, 9, 2, 1, ch.face)
	_rect(img, 7, 10, 2, 1, ch.faced)

# ============================================================
# ENEMIGOS
# ============================================================
func _gen_enemies() -> void:
	_gen_walker()
	_gen_flyer()
	_gen_turret()
	_gen_jumper()
	_gen_bomber()
	_gen_boss()

func _gen_walker() -> void:
	for f in 2:
		var img := _new(16, 16)
		var step := 0 if f == 0 else 1
		# Patas
		_rect(img, 1 + step, 13, 4, 3, METD)
		_rect(img, 11 - step, 13, 4, 3, METD)
		_rect(img, 1 + step, 13, 4, 1, MET)
		_rect(img, 11 - step, 13, 4, 1, MET)
		# Cuerpo
		_vgrad(img, 3, 8, 10, 6, GRN.lerp(WH, 0.3), GRND)
		# Casco
		_vgrad(img, 3, 2, 10, 7, METL, MET)
		_rect(img, 3, 2, 10, 1, WH)
		# Visor
		_rect(img, 5, 5, 6, 2, Color("101528"))
		_rect(img, 6, 5, 4, 2, CYAN)
		_px(img, 6, 5, WH)
		# Hombros con pinchos
		_rect(img, 2, 8, 2, 3, METD)
		_rect(img, 12, 8, 2, 3, METD)
		# Detalle
		_rect(img, 6, 10, 4, 2, GRND)
		_outline(img)
		_save(img, BASE + "enemies/walker_%d.png" % f)

func _gen_flyer() -> void:
	for f in 2:
		var img := _new(16, 10)
		# Alas
		if f == 0:
			_rect(img, 0, 1, 4, 2, Color("4a2f9e"))
			_rect(img, 12, 1, 4, 2, Color("4a2f9e"))
		else:
			_rect(img, 1, 4, 4, 2, Color("4a2f9e"))
			_rect(img, 11, 4, 4, 2, Color("4a2f9e"))
		# Cuerpo
		_vgrad(img, 3, 2, 10, 5, Color("b18cff"), Color("6a3fd0"))
		# Ojo
		_rect(img, 6, 3, 4, 3, Color("101528"))
		_rect(img, 7, 3, 3, 2, RED)
		_px(img, 7, 3, WH)
		_outline(img)
		_save(img, BASE + "enemies/flyer_%d.png" % f)

func _gen_turret() -> void:
	for f in 2:
		var img := _new(16, 16)
		var bl := 0 if f == 0 else 1
		# Base
		_hgrad(img, 2, 9, 12, 6, MET, METD)
		_rect(img, 3, 9, 10, 1, METL)
		# CÃºpula
		_vgrad(img, 5, 5, 6, 5, METL, MET)
		_rect(img, 6, 6, 4, 2, Color("101528"))
		_px(img, 6, 6, RED)
		_px(img, 9, 6, RED)
		# CaÃ±Ã³n
		_rect(img, 7, 1 + bl, 2, 5, MET)
		_rect(img, 7, 1 + bl, 1, 5, METL)
		_px(img, 7, 1 + bl, RED)
		_outline(img)
		_save(img, BASE + "enemies/turret_%d.png" % f)

func _gen_jumper() -> void:
	# Robot saltarÃ­n con resorte
	for f in 2:
		var img := _new(16, 16)
		var squash := 0 if f == 0 else 2
		# Resorte / patas
		_rect(img, 5, 12 - squash, 2, 4 + squash, METD)
		_rect(img, 9, 12 - squash, 2, 4 + squash, METD)
		_rect(img, 4, 15, 8, 1, MET)
		# Cuerpo
		_vgrad(img, 3, 5 + squash, 10, 8 - squash, Color("ff9a3a"), Color("9a4a00"))
		# Casco
		_vgrad(img, 3, 1, 10, 6, METL, MET)
		_rect(img, 3, 1, 10, 1, WH)
		# Ojos
		_rect(img, 5, 4, 2, 2, Color("101528"))
		_rect(img, 9, 4, 2, 2, Color("101528"))
		_px(img, 5, 4, YEL)
		_px(img, 9, 4, YEL)
		# Detalle cuerpo
		_rect(img, 6, 8 + squash, 4, 2, Color("7a3800"))
		_outline(img)
		_save(img, BASE + "enemies/jumper_%d.png" % f)

func _gen_bomber() -> void:
	# Nave bombardera
	for f in 2:
		var img := _new(18, 12)
		# Propulsores
		_rect(img, 0, 4, 3, 3, METD)
		_rect(img, 15, 4, 3, 3, METD)
		if f == 0:
			_rect(img, 0, 5, 2, 1, YEL)
			_rect(img, 16, 5, 2, 1, YEL)
		else:
			_rect(img, 0, 6, 3, 1, ORG)
			_rect(img, 15, 6, 3, 1, ORG)
		# Cuerpo
		_vgrad(img, 3, 2, 12, 8, Color("8a93b8"), Color("3a4056"))
		_hgrad(img, 3, 2, 12, 1, METL, METL)
		# Cabina
		_rect(img, 7, 3, 4, 3, Color("101528"))
		_rect(img, 8, 3, 2, 2, CYAN)
		# Compuerta de bombas
		_rect(img, 7, 9, 4, 2, Color("12141f"))
		_rect(img, 8, 9, 2, 2, RED)
		_outline(img)
		_save(img, BASE + "enemies/bomber_%d.png" % f)

func _gen_boss() -> void:
	for f in 2:
		var img := _new(32, 32)
		# Piernas
		_vgrad(img, 6, 22, 6, 8, MET, METD)
		_vgrad(img, 20, 22, 6, 8, MET, METD)
		_rect(img, 4, 28, 9, 3, METD)
		_rect(img, 19, 28, 9, 3, METD)
		_rect(img, 4, 28, 9, 1, MET)
		_rect(img, 19, 28, 9, 1, MET)
		# Torso
		_vgrad(img, 8, 8, 16, 15, Color("5a6070"), Color("2a2f4a"))
		_rect(img, 9, 9, 14, 2, MET)
		_rect(img, 8, 8, 16, 1, METL)
		# NÃºcleo
		var c: Color = RED if f == 0 else ORG
		_orb(img, 16, 17, 5.0, WH, c, Color("5a0f00"))
		# Hombros con caÃ±ones
		_vgrad(img, 2, 10, 6, 9, MET, METD)
		_vgrad(img, 24, 10, 6, 9, MET, METD)
		_rect(img, 1, 12, 2, 4, Color("101528"))
		_rect(img, 29, 12, 2, 4, Color("101528"))
		_px(img, 1, 12 + f, RED)
		_px(img, 30, 12 + f, RED)
		# Cabeza
		_vgrad(img, 11, 2, 10, 6, METL, MET)
		_rect(img, 12, 3, 8, 1, WH)
		_rect(img, 12, 5, 3, 2, CYAN)
		_rect(img, 17, 5, 3, 2, CYAN)
		_px(img, 12, 5, WH)
		_px(img, 17, 5, WH)
		_outline(img)
		_save(img, BASE + "enemies/boss_%d.png" % f)

# ============================================================
# PROYECTILES
# ============================================================
func _gen_projectiles() -> void:
	# Bala del jugador (buster) - plasma azul
	var p := _new(10, 8)
	_orb(p, 4, 4, 3.5, WH, CYAN, Color("1b3a99"))
	_rect(p, 6, 3, 4, 2, CYAN)
	_rect(p, 8, 3, 2, 2, WH)
	_outline(p)
	_save(p, BASE + "fx/bullet_player.png")

	# Disparo cargado (16x16)
	var ch := _new(16, 16)
	_orb(ch, 8, 8, 7.5, WH, CYAN, Color("1b3a99"))
	_orb(ch, 8, 8, 4.0, WH, Color("bff0ff"), CYAN)
	_outline(ch)
	_save(ch, BASE + "fx/bullet_charged.png")

	# Disparo spread (8x8) - naranja
	var sp := _new(8, 8)
	_orb(sp, 4, 4, 3.2, WH, YEL, ORG)
	_outline(sp)
	_save(sp, BASE + "fx/bullet_spread.png")

	# LÃ¡ser del jugador (14x5) - rojo/blanco
	var lz := _new(14, 5)
	_rect(lz, 0, 1, 14, 3, RED)
	_rect(lz, 0, 2, 14, 1, WH)
	_rect(lz, 10, 0, 4, 5, RED)
	_px(lz, 12, 2, WH)
	_save(lz, BASE + "fx/bullet_laser_player.png")

	# Plasma violeta (12x12, grande y lento)
	var pl := _new(12, 12)
	_orb(pl, 6, 6, 5.5, WH, Color("c0a8ff"), Color("40208c"))
	_orb(pl, 6, 6, 2.5, WH, Color("e0d0ff"), Color("8a5cff"))
	_outline(pl)
	_save(pl, BASE + "fx/bullet_plasma.png")

	# Bala enemiga (8x8)
	var e := _new(8, 8)
	_orb(e, 4, 4, 3.4, WH, ORG, RED)
	_outline(e)
	_save(e, BASE + "fx/bullet_enemy.png")

	# Bala lÃ¡ser enemiga (10x4)
	var l := _new(10, 4)
	_rect(l, 0, 1, 10, 2, RED)
	_rect(l, 1, 1, 8, 1, YEL)
	_rect(l, 8, 1, 2, 2, WH)
	_save(l, BASE + "fx/bullet_laser.png")

	# Bomba (10x10) - la suelta el bombardero
	var bm := _new(10, 10)
	_orb(bm, 5, 5, 4.2, WH, GRAY_RED(), Color("3a0a0a"))
	_rect(bm, 4, 0, 2, 2, METD)
	_outline(bm)
	_save(bm, BASE + "fx/bullet_bomb.png")

func GRAY_RED() -> Color:
	return Color("d84a4a")

# ============================================================
# TILES (16x16)
# ============================================================
func _gen_tiles() -> void:
	# Superficie metÃ¡lica
	var top := _new(16, 16)
	_vgrad(top, 0, 0, 16, 16, Color("5a6070"), Color("2a2f4a"))
	_rect(top, 0, 0, 16, 3, MET)
	_hgrad(top, 0, 0, 16, 1, WH, Color("c8ccda"))
	_rect(top, 0, 3, 16, 1, METD)
	_rect(top, 2, 6, 3, 3, Color("22263c"))
	_rect(top, 11, 6, 3, 3, Color("22263c"))
	_rect(top, 2, 11, 3, 3, Color("22263c"))
	_rect(top, 11, 11, 3, 3, Color("22263c"))
	_px(top, 2, 6, MET)
	_px(top, 11, 6, MET)
	_outline(top)
	_save(top, BASE + "tiles/tile_top.png")

	# Relleno
	var mid := _new(16, 16)
	_vgrad(mid, 0, 0, 16, 16, Color("3a4056"), Color("20243a"))
	_rect(mid, 0, 0, 16, 1, Color("454c73"))
	_rect(mid, 3, 3, 10, 10, Color("2a2f4a"))
	_rect(mid, 4, 4, 8, 8, Color("1b1e30"))
	_rect(mid, 6, 6, 4, 4, Color("33385a"))
	_outline(mid)
	_save(mid, BASE + "tiles/tile_mid.png")

	# Plataforma flotante
	var pf := _new(16, 16)
	_vgrad(pf, 0, 2, 16, 5, MET, METD)
	_rect(pf, 0, 2, 16, 1, WH)
	_rect(pf, 0, 6, 16, 1, Color("2a2f4a"))
	_rect(pf, 1, 9, 4, 4, METD)
	_rect(pf, 11, 9, 4, 4, METD)
	_rect(pf, 2, 10, 2, 2, YEL)
	_rect(pf, 12, 10, 2, 2, YEL)
	_outline(pf)
	_save(pf, BASE + "tiles/tile_platform.png")

	# Pinchos: hojas metálicas afiladas sobre base de peligro con cheurones
	var spk := _new(16, 16)
	# Base de peligro (ménsula) con cheurones rojos
	_rect(spk, 0, 13, 16, 3, Color("12141f"))
	_rect(spk, 0, 12, 16, 1, Color("6a1010"))
	_rect(spk, 0, 13, 16, 1, RED.lerp(Color("8a140f"), 0.4))
	for i in 4:
		var bx := i * 4
		_rect(spk, bx + 1, 14, 6, 2, YEL)
		_rect(spk, bx + 4, 15, 3, 1, Color("12141f"))
	# Hojas de pincho (4, 3px de ancho)
	for i in 4:
		var x := 1 + i * 4
		# Triángulo afilado hacia arriba
		for row in 12:
			var ly := 11 - row
			var half := (row + 1) / 2
			_rect(spk, x + 1 - half, ly, 1 + half * 2, 1, T)
		# Caras con sombreado y brillo
		for row in range(1, 12):
			var ly := 11 - row
			var face := Color("d7dbe6") if row < 6 else Color("a8b0c0")
			_px(spk, x, ly, face)
			if row < 11:
				_px(spk, x + 1, ly, Color("5a6070") if row > 2 else Color("8a93b8"))
			if row % 3 == 0 and row < 9:
				_px(spk, x, ly, RED)
		# Punta iluminada
		_px(spk, x + 1, 0, WH)
		_px(spk, x, 1, WH)
	_outline(spk)
	# Base vuelve a meter el outline de la ménsula encima
	_save(spk, BASE + "tiles/spike.png")

	# Ladrillo de fondo
	var br := _new(16, 16)
	_vgrad(br, 0, 0, 16, 16, Color("262b46"), Color("171a2c"))
	_rect(br, 0, 0, 7, 7, Color("31375a"))
	_rect(br, 9, 0, 7, 7, Color("31375a"))
	_rect(br, 0, 9, 15, 7, Color("31375a"))
	_save(br, BASE + "tiles/brick.png")

# ============================================================
# EFECTOS
# ============================================================
func _gen_fx() -> void:
	for f in 5:
		var img := _new(24, 24)
		var r := 3.0 + f * 3.0
		var core := WH if f == 0 else (YEL if f < 2 else ORG)
		var edge := YEL if f < 2 else (ORG if f < 4 else Color("7a1f1a"))
		_orb(img, 12, 12, r, WH, core, edge)
		_save(img, BASE + "fx/explosion_%d.png" % f)

	var spark := _new(8, 8)
	_rect(spark, 3, 0, 2, 8, WH)
	_rect(spark, 0, 3, 8, 2, WH)
	_rect(spark, 3, 3, 2, 2, CYAN)
	_save(spark, BASE + "fx/spark.png")

	var mz := _new(8, 8)
	_orb(mz, 2, 4, 3.5, WH, CYANL, CYAN)
	_rect(mz, 2, 3, 4, 2, WH)
	_save(mz, BASE + "fx/muzzle.png")

	var cg := _new(8, 8)
	_orb(cg, 4, 4, 3.0, WH, CYANL, CYAN)
	_save(cg, BASE + "fx/charge.png")

	# Mira de puntería (14x14): retícula tipo "crosshair"
	var cr := _new(14, 14)
	_px(cr, 6, 6, CYAN)
	_px(cr, 7, 6, CYAN)
	_px(cr, 6, 7, CYAN)
	_px(cr, 7, 7, WH)
	_rect(cr, 5, 2, 4, 1, WH)
	_rect(cr, 5, 11, 4, 1, WH)
	_rect(cr, 2, 5, 1, 4, WH)
	_rect(cr, 11, 5, 1, 4, WH)
	_px(cr, 3, 3, WH)
	_px(cr, 10, 3, WH)
	_px(cr, 3, 10, WH)
	_px(cr, 10, 10, WH)
	_save(cr, BASE + "fx/crosshair.png")

# ============================================================
# PICKUPS
# ============================================================
func _gen_pickups() -> void:
	var h := _new(12, 12)
	_rect(h, 1, 1, 10, 10, Color("123a12"))
	_vgrad(h, 0, 3, 12, 6, GRN.lerp(WH, 0.3), GRND)
	_rect(h, 3, 0, 6, 12, GRND)
	_rect(h, 4, 4, 4, 4, WH)
	_outline(h)
	_save(h, BASE + "ui/pickup_health.png")

	var w := _new(12, 12)
	_rect(w, 1, 1, 10, 10, Color("5a2f00"))
	_vgrad(w, 0, 3, 12, 6, YEL, ORG)
	_rect(w, 3, 0, 6, 12, ORG)
	_rect(w, 5, 3, 2, 6, WH)
	_rect(w, 3, 5, 6, 2, WH)
	_outline(w)
	_save(w, BASE + "ui/pickup_weapon.png")

	var u := _new(12, 12)
	_rect(u, 1, 1, 10, 10, Color("123a12"))
	_vgrad(u, 0, 1, 12, 10, GRN.lerp(WH, 0.3), GRND)
	_rect(u, 4, 3, 4, 6, WH)
	_rect(u, 3, 4, 6, 4, WH)
	_rect(u, 5, 5, 2, 2, GRN)
	_outline(u)
	_save(u, BASE + "ui/pickup_life.png")

# ============================================================
# FONDOS (parallax 2.5D)
# ============================================================
func _gen_backgrounds() -> void:
	var W := 480
	var H := 180
	var rng := RandomNumberGenerator.new()

	# Cielo nocturno con amanecer eléctrico, luna y nubes
	var sky := _new(W, H)
	for y in H:
		var t := float(y) / float(H)
		var col := Color("0a0d26").lerp(Color("2c2252"), pow(t, 1.2))
		if t > 0.68:
			col = col.lerp(Color("5a3a78"), (t - 0.68) / 0.32)
		for x in W:
			sky.set_pixel(x, y, col)
	# Halo de la luna
	for y in range(26, 62):
		for x in range(378, 414):
			var d := Vector2(float(x) - 396.0, float(y) - 44.0).length()
			if d >= 8.0 and d <= 11.0:
				var base: Color = sky.get_pixel(x, y)
				sky.set_pixel(x, y, base.lerp(Color("8a76c8"), 0.35))
	# Luna
	_orb(sky, 396, 44, 7.0, WH, Color("d8dcf0"), Color("8a90b0"))
	_px(sky, 393, 41, Color("6a7090"))
	_px(sky, 398, 47, Color("6a7090"))
	_px(sky, 395, 46, Color("6a7090"))
	# Bancos de nubes bajos
	rng.seed = 3457
	for n in 90:
		var bx := rng.randi_range(0, W - 1)
		var by := rng.randi_range(16, 60) if rng.randf() > 0.4 else rng.randi_range(120, 150)
		var col := Color("8a76c8") if rng.randf() > 0.5 else Color("5a4a8a")
		_px(sky, bx, by, sky.get_pixel(bx, by).lerp(col, 0.35))
	# Estrellas (algunas de 2px)
	rng.seed = 1234
	for i in 90:
		var sx := rng.randi_range(0, W - 1)
		var sy := rng.randi_range(0, 92)
		var c := WH if rng.randf() > 0.5 else CYANL
		sky.set_pixel(sx, sy, c)
	rng.seed = 99
	for i in 14:
		var sx := rng.randi_range(0, W - 1)
		var sy := rng.randi_range(0, 70)
		sky.set_pixel(sx, sy, WH)
		sky.set_pixel(sx + 1, sy + 1, WH)
	_save(sky, BASE + "tiles/bg_sky.png")

	# Sierra lejana: dos crestas + agujas con balizas
	var far := _new(W, H)
	rng.seed = 77
	var base_y := 118
	var heights: Array[int] = []
	for x in W:
		heights.append(base_y + int(4.0 * sin(float(x) * 0.05)))
	for m in 12:
		var cx := rng.randi_range(0, W)
		var peak := rng.randi_range(36, 92)
		var half := rng.randi_range(38, 80)
		for x in W:
			var d := absf(float(x) - float(cx))
			if d < half:
				var hy := base_y - int((1.0 - d / float(half)) * float(base_y - peak))
				if hy < heights[x]:
					heights[x] = hy
	for x in W:
		for y in range(heights[x], H):
			var t := float(y - heights[x]) / float(maxi(H - heights[x], 1))
			far.set_pixel(x, y, Color("241c44").lerp(Color("0e0b20"), t))
	for x in W:
		if heights[x] < base_y:
			far.set_pixel(x, heights[x], Color("5a4a9a"))
	rng.seed = 555
	for m in 7:
		var ax := rng.randi_range(10, W - 10)
		var ah := rng.randi_range(14, 26)
		for y in range(heights[ax] - ah, heights[ax]):
			_px(far, ax, y, Color("1a1638"))
		_px(far, ax, heights[ax] - ah - 1, RED)
		_px(far, ax + 1, heights[ax] - ah - 1, RED)
	_save(far, BASE + "tiles/bg_far.png")

	# Ciudad media: ventanas variadas, antenas y neón en cornisas
	var mid := _new(W, H)
	rng.seed = 909
	for i in 16:
		var bx := rng.randi_range(0, W - 24)
		var bw := rng.randi_range(14, 34)
		var bh := rng.randi_range(28, 96)
		for yy in range(H - bh, H):
			var t := float(yy - (H - bh)) / float(maxi(bh, 1))
			_rect(mid, bx, yy, bw, 1, Color("2a2250").lerp(Color("0c091e"), t))
		# Ventanas: amarillas y algunas cian
		for wy in range(H - bh + 5, H - 6, 5):
			for wx in range(bx + 3, bx + bw - 3, 5):
				if rng.randf() > 0.4:
					var win := CYAN if rng.randf() > 0.85 else YEL
					mid.set_pixel(wx, wy, win)
		# Antena con baliza en el tejado
		if rng.randf() > 0.6:
			var at := bx + rng.randi_range(2, bw - 3)
			_rect(mid, at, H - bh - 4, 1, 4, Color("3a3370"))
			mid.set_pixel(at, H - bh - 5, Color("ff6a5a"))
		# Línea de luz en la cornisa
		if rng.randf() > 0.6:
			_rect(mid, bx + 1, H - bh, bw - 2, 1, Color("8a76c8"))
	# Niebla urbana
	for x in W:
		for yy in range(H - 26, H):
			var t := float(yy - (H - 26)) / 26.0
			var p: Color = mid.get_pixel(x, yy)
			mid.set_pixel(x, yy, p.lerp(Color("1a1740"), t * 0.7))
	_save(mid, BASE + "tiles/bg_mid.png")

	# Primer plano: siluetas, grúas, postes y balizas
	var near := _new(W, H)
	rng.seed = 4242
	for x in W:
		var hh := 24 + int(9.0 * sin(float(x) * 0.07) + 4.0 * sin(float(x) * 0.023))
		for yy in range(H - hh, H):
			var t := float(yy - (H - hh)) / float(maxi(hh, 1))
			_px(near, x, yy, Color("0b0918").lerp(Color("1e1a3a"), t))
			if yy == H - hh + 2 and rng.randf() > 0.55:
				_px(near, x, yy, Color("38346a"))
	# Grúas de construcción
	for gx in [70, 190, 330, 410]:
		var gh: int = 46 + (gx % 3) * 6
		_rect(near, gx, H - gh, 2, gh, Color("0d0b1e"))
		for c in range(4, gh, 6):
			_px(near, gx - 1, H - gh + c, Color("0d0b1e"))
			_px(near, gx + 2, H - gh + c, Color("0d0b1e"))
		_rect(near, gx, H - gh - 2, 24, 2, Color("0d0b1e"))
		_px(near, gx + 24, H - gh - 2, Color("ff6a5a"))
		_px(near, gx + 24, H - gh - 1, Color("ff6a5a"))
		_rect(near, gx - 4, H - gh, 4, 5, Color("161332"))
	# Postes de alta tensión con baliza
	for px2 in [24, 260, 452]:
		_rect(near, px2, 60, 2, H - 62, Color("0d0b1e"))
		_rect(near, px2 - 1, 60, 4, 2, Color("0d0b1e"))
		_px(near, px2, 60, RED)
		_px(near, px2 + 1, 60, RED)
	# Cables combados entre postes
	for pair in [[24, 260], [260, 452]]:
		for i in 16:
			var t := float(i) / 15.0
			var cx2 := int(lerp(float(pair[0]), float(pair[1]), t))
			var cy2 := 60 + int(10.0 * sin(t * PI))
			_px(near, cx2, cy2 + 22, Color("0d0b1e"))
	# Antena grande central con luz verde
	_rect(near, 140, 40, 2, H - 42, Color("0d0b1e"))
	for c in range(8, H - 42, 8):
		_px(near, 139, 40 + c, Color("0d0b1e"))
	_px(near, 141, 38, GRN)
	_save(near, BASE + "tiles/bg_near.png")
