class_name Hud
extends Control
## HUD con maquetación fija (todo medido con la fuente pixel, nada se pisa):
##  - arriba-izquierda: panel de jugador (retrato, vida, vidas, arma)
##  - arriba-centro: barra del jefe
##  - arriba-derecha: puntos y combo
##  - abajo: avisos, banner de etapa/jefe y barra de progreso del nivel

const PT := preload("res://scripts/ui/pixel_text.gd")
const PilotVisual := preload("res://scripts/player/pilot_visual.gd")

const HEAD := {
	"orange": preload("res://assets/sprites/ui/head_orange.png"),
	"red": preload("res://assets/sprites/ui/head_red.png"),
	"black": preload("res://assets/sprites/ui/head_black.png"),
	"violet": preload("res://assets/sprites/ui/head_violet.png"),
}
const PANEL_W := 104.0
const PANEL_H := 25.0

var _max_health := 28
var _hp := [28, 28, 28, 28]
var _lives := [3, 3, 3, 3]
var _weapon := "buster"
var _score := 0
var _score_display := 0.0
var _score_pop := 0.0
var _combo := 0
var _combo_mult := 1.0
var _combo_pop := 0.0
var _flash := [0.0, 0.0, 0.0, 0.0]
var _boss_hp := 0
var _boss_max := 1
var _boss_active := false
var _boss_name := ""
var _t := 0.0

# Avisos
var _toasts: Array = []        # cada uno: {text, color, t}
var _banner := {}              # {title, sub, color, t}
var _crosshair: Sprite2D
var _portraits: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(320, 180)
	_max_health = GameManager.MAX_HEALTH
	_hp = [_max_health, _max_health, _max_health, _max_health]
	_lives = [GameManager.lives, GameManager.STARTING_LIVES, GameManager.STARTING_LIVES, GameManager.STARTING_LIVES]
	for i in (0 if GameManager.coop else 1):
		var art := PilotVisual.new()
		art.pilot = GameManager.character if i == 0 else GameManager.character2
		art.position = Vector2(15,25+i*28)
		art.scale = Vector2.ONE*0.55
		add_child(art)
		_portraits.append(art)

	_crosshair = Sprite2D.new()
	_crosshair.texture = load("res://assets/sprites/fx/crosshair.png")
	_crosshair.z_index = 20
	add_child(_crosshair)

	GameManager.score_changed.connect(_on_score)
	GameManager.lives_changed.connect(func(v): _lives[0] = v)
	GameManager.weapon_changed.connect(func(id): _weapon = id)
	GameManager.health_changed.connect(_on_health)
	GameManager.player_health_changed.connect(_on_player_health)
	GameManager.player_lives_changed.connect(func(i, v): _lives[i] = v)
	GameManager.boss_health_changed.connect(_on_boss_health)
	GameManager.boss_activated.connect(func(_id, label): _boss_name = label)
	GameManager.combo_changed.connect(_on_combo)
	GameManager.toast_requested.connect(_on_toast)
	GameManager.banner_requested.connect(_on_banner)
	_on_score(GameManager.score)
	_weapon = GameManager.current_weapon

func _process(delta: float) -> void:
	_t += delta
	_score_display = move_toward(_score_display, float(_score), maxf(60.0, absf(_score - _score_display) * 6.0) * delta)
	_score_pop = maxf(0.0, _score_pop - delta * 3.0)
	_combo_pop = maxf(0.0, _combo_pop - delta * 3.0)
	_flash[0] = maxf(0.0, _flash[0] - delta)
	_flash[1] = maxf(0.0, _flash[1] - delta)
	for tt in _toasts:
		tt["t"] = float(tt["t"]) + delta
	while _toasts.size() > 0 and float(_toasts[0]["t"]) > 4.0:
		_toasts.remove_at(0)
	if not _banner.is_empty():
		_banner["t"] = float(_banner["t"]) + delta
		if float(_banner["t"]) > 2.8:
			_banner = {}
	_crosshair.visible = GameManager.state == GameManager.State.PLAYING and not NetSession.local_shop_open
	for art in _portraits:
		art.visible = GameManager.state in [GameManager.State.PLAYING,GameManager.State.PAUSED]
	if _crosshair.visible:
		_crosshair.position = get_viewport().get_mouse_position()
	queue_redraw()

# ------------------------------------------------------------------
func _on_score(v: int) -> void:
	_score = v
	_score_pop = 1.0

func _on_health(v: int, _mx: int) -> void:
	_hp[0] = v
	_flash[0] = 0.28

func _on_player_health(i: int, v: int, _mx: int) -> void:
	_hp[i] = v
	_flash[i] = 0.28

func _on_boss_health(v: int, mx: int, active: bool) -> void:
	_boss_hp = v
	_boss_max = maxi(mx, 1)
	_boss_active = active

func _on_combo(v: int, mult: float) -> void:
	_combo = v
	_combo_mult = mult
	_combo_pop = 1.0

func _on_toast(text: String, color: Color) -> void:
	_toasts.append({"text": text, "color": color, "t": 0.0})
	if _toasts.size() > 3:
		_toasts.remove_at(0)

func _on_banner(title: String, sub: String, color: Color) -> void:
	_banner = {"title": title, "sub": sub, "color": color, "t": 0.0}

# ------------------------------------------------------------------
# Dibujo
# ------------------------------------------------------------------
func _draw() -> void:
	if GameManager.state != GameManager.State.PLAYING and GameManager.state != GameManager.State.PAUSED:
		return
	if GameManager.coop:
		_draw_squad()
	else:
		_draw_player_panel(0,Vector2(3,3))
		_draw_score()
		_draw_combo()
	_draw_boss()
	if not GameManager.horde_mode: _draw_progress()
	var puzzle := _nearby_puzzle()
	if puzzle: _draw_puzzle_hint(puzzle)
	else: _draw_toasts()
	_draw_banner()
	_draw_powers()

func _draw_squad() -> void:
	for i in GameManager.party_size():
		var id := GameManager.pilot_at(i)
		var col: Color = GameManager.CHARACTERS[id]["color"]
		var x := 3+i*79
		PT.panel(self,Rect2(x,3,76,22),Color("0b1828"),col.darkened(0.4))
		PT.draw_box(self,"P%d %s" % [i+1,GameManager.CHARACTERS[id]["name"]],Rect2(x+3,3,70,14),col,1,PT.LEFT)
		draw_rect(Rect2(x+3,17,70,4),Color("263340"))
		draw_rect(Rect2(x+3,17,70*float(_hp[i])/_max_health,4),col)
	draw_rect(Rect2(4,29,60,3),Color("263340"))
	draw_rect(Rect2(4,29,60*GameManager.team_energy/100,3),Color("73f7ff"))
	PT.draw_box(self,"F FUSION / E RESCATE",Rect2(70,25,120,14),Color("91a9bf"),1,PT.LEFT)
	for pilot in get_tree().get_nodes_in_group("player"):
		if pilot.index==(NetSession.local_index if NetSession.online else 0):
			PT.draw_box(self,GameManager.weapon_name(pilot.weapon),Rect2(202,157,114,14),Color("c6d8e8"),1,PT.RIGHT)
			if pilot.has_mobility("jetpack"):
				draw_rect(Rect2(256,173,60,3),Color("203848"))
				draw_rect(Rect2(256,173,60*pilot.jet_fuel,3),Color("68deff"))


func _nearby_puzzle() -> Node2D:
	var local_index := NetSession.local_index if NetSession.online else 0
	for p in get_tree().get_nodes_in_group("player"):
		if p.index != local_index or not p.alive:
			continue
		for puzzle in get_tree().get_nodes_in_group("zone_puzzle"):
			var offset: Vector2 = p.global_position-puzzle.global_position
			if not puzzle.solved and offset.x >= 40 and offset.x <= (972 if puzzle.chapter>0 else 718) and offset.y > -650 and offset.y < 200:
				return puzzle
	return null

func _draw_puzzle_hint(puzzle: Node2D) -> void:
	draw_rect(Rect2(16,139,288,18),Color(0.03,0.07,0.12,0.88))
	draw_set_transform(Vector2(20,141),0,Vector2.ONE*0.5)
	PT.draw_box(self,puzzle.hint_text(),Rect2(0,0,560,14),Color("c6d8e8"),1,PT.LEFT)
	PT.draw_box(self,puzzle.status_text(),Rect2(0,16,560,14),puzzle.stage.theme["accent"],1,PT.LEFT)
	draw_set_transform(Vector2.ZERO)

func _draw_player_panel(i: int, o: Vector2) -> void:
	var char_id: String = GameManager.character if i == 0 else GameManager.character2
	var head: Texture2D = HEAD.get(char_id, HEAD["orange"])
	var cdata: Dictionary = GameManager.CHARACTERS.get(char_id, {})
	var acolor: Color = cdata.get("color", Color.WHITE)
	PT.panel(self, Rect2(o, Vector2(PANEL_W, PANEL_H)), Color(0.03, 0.04, 0.10, 0.80),
		Color(acolor.r, acolor.g, acolor.b, 0.85))

	# Retrato (16x16)
	# El retrato utiliza la misma armadura que el personaje en el mundo.

	# Barra de vida: 28 segmentos de 2 px
	var bx := o.x + 24.0
	var by := o.y + 4.0
	var bw := float(_max_health) * 2.0
	draw_rect(Rect2(bx - 1, by - 1, bw + 2, 8), Color("e8f4ff"))
	draw_rect(Rect2(bx, by, bw, 6), Color("0b1226"))
	var hp: int = _hp[i]
	for s in _max_health:
		if s >= hp:
			break
		var frac := float(s + 1) / float(_max_health)
		var c: Color
		if frac > 0.6:
			c = Palette.HP_FULL
		elif frac > 0.32:
			c = Color("ffd45a")
		else:
			c = Color("ff5a5a")
		if hp <= float(_max_health) / 4.0 and int(_t * 8.0) % 2 == 0:
			c = c.lerp(Color.WHITE, 0.45)
		draw_rect(Rect2(bx + float(s) * 2.0, by, 2, 6), c)
		if (s + 1) % 4 == 0 and s + 1 < _max_health:
			draw_rect(Rect2(bx + float(s) * 2.0 + 1.0, by, 1, 6), Color("0b1226"))
	draw_rect(Rect2(bx, by, bw * clampf(float(hp) / float(_max_health), 0.0, 1.0), 1), Color(1, 1, 1, 0.4))
	if float(_flash[i]) > 0.0:
		draw_rect(Rect2(bx - 1, by - 1, bw + 2, 8), Color(1, 1, 1, float(_flash[i]) * 2.5), false, 1.0)

	# Fila inferior: vidas y arma
	var ry := o.y + 14.0
	draw_texture_rect(head, Rect2(bx, ry, 8, 8), false, Color(0.9, 0.95, 1.0))
	PT.draw(self, "X%d" % maxi(GameManager.team_retries if GameManager.coop else int(_lives[i]), 0), Vector2(bx + 10.0, ry + 1.0), Color("e8f4ff"))
	var wid: String = _weapon
	if i == 1 or NetSession.online:
		for p in get_tree().get_nodes_in_group("player"):
			if p.index == i:
				wid = p.weapon
	PT.draw_box(self,GameManager.weapon_name(wid),Rect2(bx+28,ry-1,48,12),Color("9fb2d8"),1,PT.LEFT)

func _draw_score() -> void:
	PT.draw(self, "PUNTOS", Vector2(316, 4), Color("9fb2d8"), 1, PT.RIGHT)
	var col := Color("ffe14d").lerp(Color.WHITE, _score_pop * 0.8)
	PT.draw(self, "%07d" % int(_score_display), Vector2(316, 13), col, 2, PT.RIGHT)

func _draw_combo() -> void:
	if _combo <= 1:
		return
	var col := Color("ff9b3d").lerp(Color("ff3d6a"), clampf(_combo_mult - 1.0, 0.0, 1.5) / 1.5)
	col = col.lerp(Color.WHITE, _combo_pop * 0.6)
	PT.draw(self, "COMBO X%d" % _combo, Vector2(316, 32), col, 1, PT.RIGHT)
	PT.draw(self, "PUNTOS X%.1f" % _combo_mult, Vector2(316, 41), Color("ffd9c0"), 1, PT.RIGHT)

func _draw_boss() -> void:
	if not _boss_active:
		return
	var bw := 96.0
	var bx := (320.0 - bw) * 0.5
	var by := 65.0 if GameManager.coop else 6.0
	draw_rect(Rect2(bx - 2, by - 2, bw + 4, 12), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bx - 1, by - 1, bw + 2, 10), Color("e8f4ff"))
	draw_rect(Rect2(bx, by, bw, 8), Color("2a0d17"))
	var frac := clampf(float(_boss_hp) / float(_boss_max), 0.0, 1.0)
	var col := Color("ff5a3c").lerp(Color("ffd45c"), frac)
	draw_rect(Rect2(bx, by, floorf(bw * frac), 8), col)
	draw_rect(Rect2(bx, by, floorf(bw * frac), 2), Color(1, 1, 1, 0.45))
	PT.draw_box(self,(_boss_name if _boss_name!="" else GameManager.boss_name()),Rect2(bx-4,by+10,bw+8,12),Color("ffd9c0"))

func _draw_progress() -> void:
	var w := 120.0
	var x := (320.0 - w) * 0.5
	var y := 173.0
	draw_rect(Rect2(x - 1, y - 1, w + 2, 6), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(x, y, w, 4), Color("141a33"))
	var total := maxf(GameManager.level_length, 1.0)
	draw_rect(Rect2(x, y, w * clampf(GameManager.player_x / total, 0.0, 1.0), 4), Color("59d0ff"))
	for cx in GameManager.checkpoints:
		var mx := x + w * clampf(float(cx) / total, 0.0, 1.0)
		draw_rect(Rect2(mx, y - 2, 1, 8), Color("ffd45a"))
	draw_rect(Rect2(x + w - 2, y - 2, 3, 8), Color("ff5a3c"))
	var px := x + w * clampf(GameManager.player_x / total, 0.0, 1.0)
	draw_rect(Rect2(px - 1, y - 2, 3, 8), Color.WHITE)

func _draw_toasts() -> void:
	if _toasts.is_empty() or not _banner.is_empty():
		return
	var tt: Dictionary = _toasts.back()
	var age: float = tt["t"]
	var a := clampf(minf(age*6,(4.0-age)*3),0,1)
	var lines := PT.wrap(tt["text"],280)
	var h := 9*lines.size()+8
	draw_rect(Rect2(12,157-h,296,h),Color(0.03,0.04,0.10,0.85*a))
	var col: Color = tt["color"]
	PT.draw_lines(self,lines,Vector2(20,161-h),Color(col,a))

func _draw_powers() -> void:
	if GameManager.acquired_powers.is_empty():
		return
	PT.draw(self,"Q",Vector2(6,162),Color("d5fbff"))
	for i in GameManager.acquired_powers.size():
		var id: String = GameManager.acquired_powers[i]
		var c: Color = GameManager.BOSSES[id]["color"]
		var rc := Rect2(16+i*11,160,9,8)
		draw_rect(rc,c if id == _weapon else c.darkened(0.65))
		if id == _weapon:
			draw_rect(rc.grow(1),Color.WHITE,false,1)

func _draw_banner() -> void:
	if _banner.is_empty():
		return
	var age: float = _banner["t"]
	var a := clampf(minf(age * 5.0, (2.8 - age) * 3.0), 0.0, 1.0)
	var col: Color = _banner["color"]
	var title: String = _banner["title"]
	var sub: String = _banner["sub"]
	var band_h := 38.0
	var y0 := 62.0
	draw_rect(Rect2(0, y0, 320, band_h), Color(0.02, 0.03, 0.08, 0.72 * a))
	draw_rect(Rect2(0, y0, 320, 1), Color(col.r, col.g, col.b, a))
	draw_rect(Rect2(0, y0 + band_h - 1.0, 320, 1), Color(col.r, col.g, col.b, a))
	PT.draw_box(self,title,Rect2(8,y0+3,304,21),Color(col.r,col.g,col.b,a),2)
	if sub != "":
		PT.draw_box(self,sub,Rect2(8,y0+24,304,12),Color(0.91,0.96,1,a))
