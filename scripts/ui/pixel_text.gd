extends RefCounted
## Texto pixel-perfect propio: dibuja glifos de un atlas (sin antialiasing ni
## fuentes borrosas), con contorno de 1 px y alineación calculada con el ancho
## real de cada letra. Así NUNCA se pisan los textos: todo se mide.
##
## Uso:  const PT := preload("res://scripts/ui/pixel_text.gd")
##       PT.draw(self, "HOLA", Vector2(10, 10), Color.WHITE)   # dentro de _draw()
## La coordenada Y es la parte superior de las MAYÚSCULAS (los acentos sobresalen
## 2 px por encima).

const Data := preload("res://scripts/ui/pixel_font_data.gd")
const FILL: Texture2D = preload("res://assets/fonts/font_fill.png")
const OUTL: Texture2D = preload("res://assets/fonts/font_outline.png")
const OUTLINE_COLOR := Color(0.039, 0.039, 0.078, 1.0)

const LEFT := 0
const CENTER := 1
const RIGHT := 2
const SPACE_W := 3
const LINE_H := 9

static func glyph_index(ch: String) -> int:
	var i: int = Data.CHARSET.find(ch)
	if i < 0:
		i = Data.CHARSET.find("?")
	return i

static func glyph_width(ch: String) -> int:
	if ch == " ":
		return SPACE_W
	var i := glyph_index(ch)
	var w: int = Data.WIDTHS[i]
	return w

## Ancho en píxeles de un texto (sin contorno).
static func width(s: String, scale: int = 1) -> int:
	var t := s.to_upper()
	var total := 0
	for k in t.length():
		total += glyph_width(t.substr(k, 1)) + 1
	if total > 0:
		total -= 1
	return total * scale

## Reserva el atlas completo, incluyendo acentos y contorno, dentro de una caja.
static func fit_layout(s: String, r: Rect2, requested_scale: int = 1, align: int = CENTER) -> Dictionary:
	var sc := maxi(1,requested_scale)
	while sc > 1 and (width(s,sc)+3*sc > r.size.x or Data.CELL_H*sc > r.size.y):
		sc -= 1
	var txt := s
	if r.size.y < Data.CELL_H*sc:
		txt = ""
	while not txt.is_empty() and width(txt,sc)+3*sc > r.size.x:
		txt = txt.substr(0,txt.length()-1)
	if txt != s and txt.length() > 3:
		txt = txt.substr(0,txt.length()-3)+"..."
	var x := r.position.x+sc
	if align == CENTER:
		x = r.get_center().x
	elif align == RIGHT:
		x = r.end.x-2*sc
	var y := r.position.y+(r.size.y-Data.CELL_H*sc)*0.5+3*sc
	return {"text":txt,"position":Vector2(x,y),"scale":sc,"align":align}

static func draw_box(ci: CanvasItem,s: String,r: Rect2,color: Color = Color.WHITE,requested_scale: int = 1,align: int = CENTER) -> void:
	var layout := fit_layout(s,r,requested_scale,align)
	draw(ci,layout["text"],layout["position"],color,layout["scale"],align)

static func draw(ci: CanvasItem, s: String, pos: Vector2, color: Color = Color.WHITE,
		scale: int = 1, align: int = 0, outline: bool = true,
		outline_color: Color = OUTLINE_COLOR) -> void:
	var t := s.to_upper()
	var x := pos.x
	var total := width(t, scale)
	if align == CENTER:
		x -= float(total) * 0.5
	elif align == RIGHT:
		x -= float(total)
	x = floorf(x)
	var y := floorf(pos.y)
	var sc := float(scale)
	var oc := outline_color
	oc.a *= color.a
	for k in t.length():
		var ch := t.substr(k, 1)
		if ch == " ":
			x += float(SPACE_W + 1) * sc
			continue
		var i := glyph_index(ch)
		var src := Rect2(float(i * Data.CELL_W), 0.0, float(Data.CELL_W), float(Data.CELL_H))
		var dst := Rect2(x - sc, y - 3.0 * sc, float(Data.CELL_W) * sc, float(Data.CELL_H) * sc)
		if outline:
			ci.draw_texture_rect_region(OUTL, dst, src, oc)
		ci.draw_texture_rect_region(FILL, dst, src, color)
		var gw: int = Data.WIDTHS[i]
		x += float(gw + 1) * sc

## Parte un texto en líneas que caben en max_w píxeles.
static func wrap(s: String, max_w: int, scale: int = 1) -> PackedStringArray:
	var lines := PackedStringArray()
	var cur := ""
	for wd in s.split(" "):
		var cand: String = wd if cur == "" else cur + " " + wd
		if cur == "" or width(cand, scale) <= max_w:
			cur = cand
		else:
			lines.append(cur)
			cur = wd
	if cur != "":
		lines.append(cur)
	return lines

## Dibuja varias líneas apiladas. Devuelve la Y siguiente libre.
static func draw_lines(ci: CanvasItem, lines: PackedStringArray, pos: Vector2, color: Color,
		scale: int = 1, align: int = 0, gap: int = 2) -> float:
	var y := pos.y
	for ln in lines:
		draw(ci, ln, Vector2(pos.x, y), color, scale, align)
		y += float(7 * scale + gap)
	return y

## Panel con borde de 1 px y esquinas recortadas.
static func panel(ci: CanvasItem, r: Rect2, bg: Color = Color(0.03, 0.04, 0.10, 0.88),
		border: Color = Color(0.91, 0.96, 1.0, 1.0)) -> void:
	ci.draw_rect(r, bg)
	ci.draw_rect(Rect2(r.position + Vector2(1, 0), Vector2(r.size.x - 2.0, 1)), border)
	ci.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 1.0), Vector2(r.size.x - 2.0, 1)), border)
	ci.draw_rect(Rect2(r.position + Vector2(0, 1), Vector2(1, r.size.y - 2.0)), border)
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 1.0, 1), Vector2(1, r.size.y - 2.0)), border)

static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d" % [floori(float(s)/60.0), s % 60]
