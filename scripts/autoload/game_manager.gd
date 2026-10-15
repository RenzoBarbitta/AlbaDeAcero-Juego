extends Node
## Estado global: puntaje, vidas, vida, armas, combos, jefes y máquina de
## estados del juego. También centraliza el shake de cámara y el hit-stop.

signal score_changed(value: int)
signal lives_changed(value: int)
signal health_changed(value: int, max_value: int)
signal weapon_changed(id: String)
signal game_over
signal won
signal player_died
signal paused_changed(paused: bool)
signal started
signal character_changed(id: String)
signal level_completed(level_index: int)
signal boss_changed(id: String, name: String)
@warning_ignore("unused_signal") # Emitida por los jefes y consumida por el HUD.
signal boss_health_changed(value: int, max_value: int, active: bool)
signal combo_changed(value: int, mult: float)
signal player_health_changed(index: int, value: int, max_value: int)
signal player_lives_changed(index: int, value: int)
signal toast_requested(text: String, color: Color)
signal banner_requested(title: String, sub: String, color: Color)
@warning_ignore("unused_signal") # Bus de eventos para la activacion externa del jefe.
signal boss_activated(id: String, name: String)
signal combo_tier(tier: String, color: Color)
signal multikill(count: int, label: String)

const Themes := preload("res://scripts/world/stage_themes.gd")

enum State { TITLE, BOSS_SELECT, PLAYING, PAUSED, GAMEOVER, WIN }

const MAX_HEALTH := 28          # Barra de vida de 28 unidades
const STARTING_LIVES := 3

## Personajes jugables: color, arma primaria y arma alternativa.
const Roster := preload("res://scripts/player/roster.gd")
const CHARACTERS := Roster.DATA
const CHARACTER_ORDER := Roster.ORDER
const WEAPON_NAMES := Roster.WEAPONS
var horde_mode := false
var party_characters: Array = []
var party_mobility: Array = []
var profile_bosses: Array = []
var best_wave := 0
var run_wave := 0
var mobility: Array = []

func party_size() -> int:
	return clampi(party_characters.size(),1,4) if coop and not party_characters.is_empty() else (2 if coop else 1)

func pilot_at(index: int) -> String:
	if coop and index < party_characters.size(): return str(party_characters[index])
	return character if index==0 else character2

func pilot_unlocked(id: String) -> bool:
	if id=="gold": return profile_bosses.size()>=4
	if id=="cyan": return best_wave>=10
	return CHARACTERS.has(id)

func unlock_requirement(id: String) -> String:
	if id=="gold": return "VENCE 4 JEFES DISTINTOS (%d/4)" % profile_bosses.size()
	if id=="cyan": return "SUPERA LA OLEADA 10 (%d/10)" % mini(best_wave,10)
	return "DISPONIBLE"

func record_progress(boss_id: String = "",wave: int = 0) -> void:
	var had_aegis := pilot_unlocked("gold")
	var had_nova := pilot_unlocked("cyan")
	if boss_id!="" and not profile_bosses.has(boss_id): profile_bosses.append(boss_id)
	best_wave = maxi(best_wave,wave)
	if not had_aegis and pilot_unlocked("gold"): toast("NUEVO PILOTO: AEGIS",Color("ffd567"))
	if not had_nova and pilot_unlocked("cyan"): toast("NUEVO PILOTO: NOVA",Color("68deff"))
	if (best_wave>=3 or profile_bosses.size()>=2) and not mobility.has("double_jump"):
		mobility.append("double_jump")
		toast("DESBLOQUEADO: DOBLE SALTO",Color("63ffc3"))
	if (best_wave>=6 or profile_bosses.size()>=4) and not mobility.has("jetpack"):
		mobility.append("jetpack")
		toast("DESBLOQUEADO: JETPACK - MANTEN SALTO EN EL AIRE",Color("63ffc3"))
	save_campaign()

## Ocho jefes, cada uno con su propia zona (tema), vida, daño y habilidades.
## "mode": "ground" = camina con gravedad; "air" = vuela y flota.
## "abilities": repertorio que el jefe cicla en orden (cada una con telegrafo).
const BOSSES := {
	"sierra":   {"name": "SIERRA",   "epithet": "EL CORTE",     "color": Color("ff8c42"), "hp": 72,  "contact": 9,  "mode": "ground", "abilities": ["dash", "spread", "dash"],      "speed": 30.0, "score": 3000, "theme": "fundicion", "tip": "ESQUIVA LA SIERRA Y CASTIGA AL CAER"},
	"estruendo":{"name": "ESTRUENDO","epithet": "EL ARTILLERO", "color": Color("e5402f"), "hp": 88,  "contact": 10, "mode": "ground", "abilities": ["bomb", "burst", "dash"],       "speed": 22.0, "score": 3400, "theme": "ruinas",    "tip": "SALTA LAS BOMBAS Y ATACA POR LA ESPALDA"},
	"glaciar":  {"name": "GLACIAR",  "epithet": "EL FRÍO",      "color": Color("59d0ff"), "hp": 96,  "contact": 8,  "mode": "air",    "abilities": ["burst", "sweep", "ring"],      "speed": 24.0, "score": 3600, "theme": "glaciar",   "tip": "USA LAS PLATAFORMAS PARA ESQUIVAR RÁFAGAS"},
	"incendio": {"name": "INCENDIO", "epithet": "LA LLAMA",     "color": Color("ff5a2a"), "hp": 84,  "contact": 9,  "mode": "air",    "abilities": ["ring", "sweep", "bomb"],       "speed": 28.0, "score": 3800, "theme": "volcan",    "tip": "ROMPE EL ANILLO POR UN LADO Y CONTRAATACA"},
	"voltaje":  {"name": "VOLTAJE",  "epithet": "LA CHISPA",    "color": Color("ffd15c"), "hp": 78,  "contact": 9,  "mode": "air",    "abilities": ["spiral", "teleport", "burst"], "speed": 34.0, "score": 4000, "theme": "central",   "tip": "ANTICIPA EL TELETRANSPORTE Y DISPARA AL APARECER"},
	"coloso":   {"name": "COLOSO",   "epithet": "LA ROCA",      "color": Color("c8b48c"), "hp": 130, "contact": 12, "mode": "ground", "abilities": ["jump", "dash", "jump"],        "speed": 20.0, "score": 4200, "theme": "cantera",   "tip": "ESQUIVA EL SALTO Y HUYE DE LA ONDA DE CHOQUE"},
	"espectro": {"name": "ESPECTRO", "epithet": "LA SOMBRA",    "color": Color("8a5cff"), "hp": 76,  "contact": 9,  "mode": "air",    "abilities": ["homing", "teleport", "sweep"], "speed": 30.0, "score": 4400, "theme": "ciudad",    "tip": "DISPAROS TELEGUIADOS: MUÉVETE EN LÍNEA RECTA"},
	"enjambre": {"name": "ENJAMBRE", "epithet": "LA LEGIÓN",    "color": Color("57d16a"), "hp": 110, "contact": 10, "mode": "air",    "abilities": ["summon", "sweep", "summon"],   "speed": 20.0, "score": 5000, "theme": "biolab",    "tip": "LIMPIA LOS VOLADORES ANTES DE QUE SE ACERQUEN"},
	# Jefe secreto del piso final de la torre online. No pertenece a BOSS_ORDER,
	# por lo que nunca aparece en la campaña normal.
	"nucleo":   {"name": "NUCLEO OMEGA", "epithet": "EL CORAZON DE LA TORRE", "color": Color("ff4fd8"), "hp": 260, "contact": 13, "mode": "air", "abilities": ["omega", "teleport", "ring", "summon", "spiral", "homing", "omega", "bomb", "burst"], "speed": 36.0, "score": 12000, "theme": "central", "tip": "JEFE EXCLUSIVO ONLINE: CAMBIA DE PATRON SIN DESCANSO"},
}
const BOSS_ORDER := ["sierra", "estruendo", "glaciar", "incendio", "voltaje", "coloso", "espectro", "enjambre"]

const POWERS := {
	"sierra": {"name": "SIERRA", "desc": "DISCO QUE REGRESA Y ATRAVIESA", "cooldown": 0.65},
	"estruendo": {"name": "BOMBA", "desc": "GRANADA CON EXPLOSION EN AREA", "cooldown": 0.85},
	"glaciar": {"name": "HIELO", "desc": "TRES AGUJAS QUE FRENAN ENEMIGOS", "cooldown": 0.48},
	"incendio": {"name": "LLAMA", "desc": "ANILLO DE FUEGO A TU ALREDEDOR", "cooldown": 0.9},
	"voltaje": {"name": "VOLTAJE", "desc": "RAYO QUE ENCADENA OBJETIVOS", "cooldown": 0.65},
	"coloso": {"name": "SISMO", "desc": "DOS ONDAS DE CHOQUE PERFORANTES", "cooldown": 0.8},
	"espectro": {"name": "ESPECTRO", "desc": "ORBE QUE PERSIGUE AL OBJETIVO", "cooldown": 0.6},
	"enjambre": {"name": "ENJAMBRE", "desc": "TRES DRONES CON GUIADO INDEPENDIENTE", "cooldown": 1.0},
}

# Arsenal que solo puede comprarse dentro de la torre cooperativa/online.
# No se guarda como progreso de campaña y new_game() vuelve a cerrarlo.
const ONLINE_WEAPONS := {
	# Armas online: fuertes y especiales, pero ya no borran oleadas solas.
	"online_arc": {"name":"ARCO TESLA", "desc":"ENCADENA HASTA 3 OBJETIVOS / DAÑO REDUCIDO", "cooldown":0.88, "color":Color("62e8ff")},
	"online_lance": {"name":"LANZA FOTONICA", "desc":"RAYO PESADO / ATRAVIESA HASTA 5 ENEMIGOS", "cooldown":1.15, "color":Color("ffe46b")},
	"online_swarm": {"name":"ENJAMBRE X4", "desc":"CUATRO MISILES CON GUIADO MODERADO", "cooldown":1.30, "color":Color("69ff9f")},
	"online_nova": {"name":"NOVA CIRCULAR", "desc":"DESCARGA RADIAL DE 8 PROYECTILES", "cooldown":1.25, "color":Color("ff73df")},
	"online_saw": {"name":"DOBLE SIERRA", "desc":"DOS DISCOS DE RETORNO / PERFORACION LIMITADA", "cooldown":1.18, "color":Color("ff9b4b")},
	"online_void": {"name":"LANZA VACIO", "desc":"PROYECTIL PESADO / PERFORACION LIMITADA", "cooldown":1.55, "color":Color("9b7cff")},
}

const ONLINE_MOBILITY := {
	"triple_jump": "TRIPLE SALTO",
	"phase_dash": "DASH FASE",
	"aero_boost": "IMPULSO AEREO",
	"combat_regen": "NANORREPARACION",
	"overclock": "OVERCLOCK",
}
const ROUTE_HINTS := {
	"sierra": "ALTOS HORNOS: ESPERA EL CICLO DE FUEGO",
	"estruendo": "ARSENAL: FLANQUEA LOS ESCUDOS POR ARRIBA",
	"glaciar": "PUERTO: NO FRENES SOBRE EL PUENTE FRAGIL",
	"incendio": "CRATER: ESCALA ENTRE LAS TOBERAS",
	"voltaje": "CENTRAL: DISPARA CUANDO EL RELE SE ABRA",
	"coloso": "CANTERA: SUBE POR LOS ASCENSORES",
	"espectro": "AZOTEAS: REGRESA POR LA PASARELA SUPERIOR",
	"enjambre": "LABORATORIO: ELIMINA PRIMERO AL SANADOR",
}
var acquired_powers: Array[String] = []
var coop_cleared := {}
var coop_score := 0
var team_energy := 0.0
var team_retries := 3
var scene_transition_pending := false
var campaign_path := "user://campaign_v2.cfg"

# Video: el juego mantiene un lienzo logico 16:9 para no deformar el pixel-art.
# 1920x1080 es la salida nativa/preferida, pero el usuario puede elegir una
# ventana mas chica/grande. En relaciones de aspecto distintas se usa letterbox.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(640, 360),
	Vector2i(800, 450),
	Vector2i(800, 600),
	Vector2i(854, 480),
	Vector2i(960, 540),
	Vector2i(1024, 576),
	Vector2i(1024, 768),
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1280, 800),
	Vector2i(1280, 1024),
	Vector2i(1366, 768),
	Vector2i(1440, 810),
	Vector2i(1440, 900),
	Vector2i(1600, 900),
	Vector2i(1680, 1050),
	Vector2i(1920, 1080),
	Vector2i(1920, 1200),
	Vector2i(2048, 1152),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
	Vector2i(2880, 1620),
	Vector2i(3200, 1800),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]
const DISPLAY_MODES := ["windowed", "borderless", "fullscreen"]
var settings := {
	"music": true,
	"sfx": true,
	"resolution": Vector2i(1920, 1080),
	"display_mode": "windowed",
}

func save_campaign() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "powers", acquired_powers)
	cfg.set_value("campaign", "cleared", cleared)
	cfg.set_value("campaign", "score", campaign_score)
	cfg.set_value("duo", "cleared", coop_cleared)
	cfg.set_value("duo", "score", coop_score)
	cfg.set_value("settings", "audio", settings)
	cfg.set_value("profile","bosses",profile_bosses)
	cfg.set_value("profile","wave",best_wave)
	cfg.set_value("profile","mobility",mobility)
	var err := cfg.save(campaign_path)
	if err != OK:
		push_warning("No se pudo guardar la campana: %s" % error_string(err))

func load_campaign() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(campaign_path) != OK:
		return
	for id in cfg.get_value("campaign", "powers", []):
		if POWERS.has(id) and not acquired_powers.has(id):
			acquired_powers.append(id)
	cleared = cfg.get_value("campaign", "cleared", {})
	campaign_score = int(cfg.get_value("campaign", "score", 0))
	coop_cleared = cfg.get_value("duo", "cleared", {})
	coop_score = int(cfg.get_value("duo", "score", 0))
	# Mezclar en lugar de reemplazar: las partidas antiguas solo guardaban audio
	# y deben recibir automaticamente las nuevas opciones de video.
	var stored_settings = cfg.get_value("settings", "audio", {})
	if typeof(stored_settings) == TYPE_DICTIONARY:
		for key in stored_settings:
			settings[key] = stored_settings[key]
	_normalize_video_settings()
	profile_bosses = cfg.get_value("profile","bosses",cleared.keys())
	best_wave = int(cfg.get_value("profile","wave",0))
	mobility = cfg.get_value("profile","mobility",[])

func _normalize_video_settings() -> void:
	if not settings.has("music"):
		settings["music"] = true
	if not settings.has("sfx"):
		settings["sfx"] = true
	if not settings.has("resolution"):
		settings["resolution"] = Vector2i(1920, 1080)
	var r = settings["resolution"]
	if typeof(r) == TYPE_VECTOR2:
		r = Vector2i(roundi(r.x), roundi(r.y))
	if typeof(r) != TYPE_VECTOR2I or int(r.x) < 320 or int(r.y) < 180:
		r = Vector2i(1920, 1080)
	settings["resolution"] = r
	var mode := str(settings.get("display_mode", "windowed"))
	if not DISPLAY_MODES.has(mode):
		mode = "windowed"
	settings["display_mode"] = mode

func resolution_label() -> String:
	_normalize_video_settings()
	var r: Vector2i = settings["resolution"]
	return "%d X %d" % [r.x, r.y]

func display_mode_label() -> String:
	match str(settings.get("display_mode", "windowed")):
		"borderless": return "SIN BORDES"
		"fullscreen": return "PANTALLA COMPLETA"
		_: return "VENTANA"

func cycle_resolution(direction: int) -> void:
	_normalize_video_settings()
	var current: Vector2i = settings["resolution"]
	var idx := RESOLUTIONS.find(current)
	if idx < 0:
		# Si viene de una version anterior, partir de la nativa.
		idx = RESOLUTIONS.find(Vector2i(1920, 1080))
	var step := -1 if direction < 0 else 1
	idx = wrapi(idx + step, 0, RESOLUTIONS.size())
	settings["resolution"] = RESOLUTIONS[idx]
	apply_video_settings()
	save_campaign()

func cycle_display_mode() -> void:
	_normalize_video_settings()
	var mode := str(settings["display_mode"])
	var idx := DISPLAY_MODES.find(mode)
	settings["display_mode"] = DISPLAY_MODES[(idx + 1) % DISPLAY_MODES.size()]
	apply_video_settings()
	save_campaign()

func apply_video_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_normalize_video_settings()
	var mode := str(settings["display_mode"])
	var requested: Vector2i = settings["resolution"]
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)

	if mode == "fullscreen":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return

	# Volver a ventana antes de tocar borde/tamano.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var borderless := mode == "borderless"
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, borderless)
	if borderless:
		# Sin bordes ocupa el area util del monitor y el viewport se encarga
		# de conservar 16:9 sin deformar el juego.
		DisplayServer.window_set_position(usable.position)
		DisplayServer.window_set_size(usable.size)
		return

	# En ventana respetar la resolucion elegida, pero no dejarla fuera del monitor.
	var available := Vector2i(maxi(320, usable.size.x - 32), maxi(180, usable.size.y - 48))
	var fitted := requested
	if requested.x > available.x or requested.y > available.y:
		var fit := minf(float(available.x) / requested.x, float(available.y) / requested.y)
		fitted = Vector2i(maxi(320, floori(requested.x * fit)), maxi(180, floori(requested.y * fit)))
	DisplayServer.window_set_size(fitted)
	var centered := Vector2i((usable.size.x - fitted.x) / 2, (usable.size.y - fitted.y) / 2)
	DisplayServer.window_set_position(usable.position + centered)

func acquire_boss_power(id: String) -> void:
	if not POWERS.has(id):
		return
	record_progress(id)
	if not acquired_powers.has(id):
		acquired_powers.append(id)
	unlocked[id] = true
	for p in get_tree().get_nodes_in_group("player"):
		p.equip_power(id)
	current_weapon = id
	weapon_changed.emit(id)
	toast("PODER OBTENIDO: %s - Q PARA CAMBIAR" % POWERS[id]["name"], BOSSES[id]["color"])
	save_campaign()

var score := 0
var lives := STARTING_LIVES
var health := MAX_HEALTH
var character := "orange"
var character2 := "red"
var coop := false
var current_weapon := "buster"
var unlocked := {"buster": true, "spread": false}
var level_index := 0
var selected_boss := "sierra"
var game_running := false
var state: int = State.TITLE
var rng := RandomNumberGenerator.new()

# Campaña, estadísticas y flujo entre pantallas.
var cleared := {}              # jefes derrotados (persisten entre etapas)
var campaign_score := 0
var kills := 0
var deaths := 0
var play_time := 0.0
var skip_menu := false         # al recargar la escena, empezar directamente
var pending_screen := ""       # "stages" = abrir la selección de etapa
var theme_id := "ciudad"
var friction_mul := 1.0
var accel_mul := 1.0
var level_length := 2800.0     # los rellena el constructor de etapa
var player_x := 0.0
var checkpoints: Array = []

# Cámara compartida (coop) y utilidades.
var camera_override: Camera2D = null
var _shake_amount := 0.0

# Combo / dopamina.
var combo := 0
var combo_timer := 0.0
const COMBO_WINDOW := 2.2
## Niveles de combo: [umbral, etiqueta, color]. Se anuncian una vez al cruzar.
const COMBO_TIERS := [
	[3, "RACHA", Color("ffd45a")],
	[5, "IMPARABLE", Color("ff9b3d")],
	[10, "DEVASTADOR", Color("ff5a3c")],
	[15, "FURIA DE ACERO", Color("ff3d6a")],
	[20, "LEYENDA DEL ALBA", Color("c07dff")],
]
var _tier_idx := -1
## Multikill: bajas encadenadas dentro de la ventana de tiempo.
var _mk_count := 0
var _mk_timer := 0.0
const MK_WINDOW := 1.4

# Vida por jugador (coop). Índice 0 / 1.
var p_health := [MAX_HEALTH, MAX_HEALTH, MAX_HEALTH, MAX_HEALTH]
var p_lives := [STARTING_LIVES, STARTING_LIVES, STARTING_LIVES, STARTING_LIVES]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	load_campaign()
	for id in ["interact","p2_interact","team_attack","p2_team_attack"]:
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		var key := InputEventKey.new()
		key.physical_keycode = {"interact":KEY_E,"p2_interact":KEY_SLASH,"team_attack":KEY_F,"p2_team_attack":KEY_ENTER}[id]
		InputMap.action_add_event(id,key)

func mode_progress() -> Dictionary:
	return coop_cleared if coop else cleared

func _process(delta: float) -> void:
	if state == State.PLAYING:
		play_time += delta
	# El tiempo global NUNCA se ralentiza durante el juego (sin cámara lenta).
	if state == State.PLAYING and Engine.time_scale != 1.0:
		Engine.time_scale = 1.0
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0 and combo > 0:
			combo = 0
			_tier_idx = -1
			combo_changed.emit(combo, combo_mult())
	if _mk_timer > 0.0:
		_mk_timer -= delta
		if _mk_timer <= 0.0:
			_mk_count = 0
	if _shake_amount > 0.0:
		_shake_amount = maxf(0.0, _shake_amount - delta * 26.0)

# ----- Estado -----
func begin_title() -> void:
	state = State.TITLE
	get_tree().paused = true

func confirm_character() -> void:
	state = State.BOSS_SELECT
	boss_changed.emit(selected_boss, boss_name())

## Aplica el tema del jefe elegido (física del suelo, arte, música).
func apply_theme_for_boss(boss_id: String) -> void:
	var cfg: Dictionary = BOSSES.get(boss_id, BOSSES["sierra"])
	theme_id = cfg.get("theme", "ciudad")
	var t: Dictionary = Themes.get_theme(theme_id)
	friction_mul = t.get("friction", 1.0)
	accel_mul = t.get("accel", 1.0)

func stage_name() -> String:
	var t: Dictionary = Themes.get_theme(theme_id)
	return t.get("name", "ZONA")

func toast(text: String, color: Color = Color("e8f4ff")) -> void:
	toast_requested.emit(text, color)

func banner(title: String, sub: String = "", color: Color = Color("ffd45a")) -> void:
	banner_requested.emit(title, sub, color)

func register_kill() -> void:
	kills += 1
	# Multikill: contar bajas encadenadas dentro de la ventana.
	if _mk_timer > 0.0:
		_mk_count += 1
	else:
		_mk_count = 1
	_mk_timer = MK_WINDOW
	var label := ""
	if _mk_count == 2:
		label = "DOBLE BAJA"
	elif _mk_count == 3:
		label = "TRIPLE BAJA"
	elif _mk_count == 4:
		label = "CUADRUPLE BAJA"
	elif _mk_count >= 5:
		label = "MASACRE X%d" % _mk_count
	if label != "":
		multikill.emit(_mk_count, label)
		AudioManager.play("combo", -8.0, 1.0 + 0.08 * float(mini(_mk_count, 6)))

func _reload() -> void:
	if scene_transition_pending:
		return
	scene_transition_pending = true
	get_tree().paused = false
	Engine.time_scale = 1.0
	call_deferred("_perform_reload")

func _perform_reload() -> void:
	scene_transition_pending = false
	get_tree().reload_current_scene()

## Empieza (recargando la escena) la etapa del jefe elegido.
func start_stage() -> void:
	skip_menu = true
	pending_screen = ""
	_reload()

func restart_stage() -> void:
	start_stage()

func to_stage_select() -> void:
	skip_menu = false
	pending_screen = "stages"
	AudioManager.stop_music()
	_reload()

func to_title() -> void:
	skip_menu = false
	pending_screen = ""
	AudioManager.stop_music()
	_reload()

func reset_campaign() -> void:
	cleared = {}
	campaign_score = 0
	acquired_powers.clear()
	save_campaign()

func start_game() -> void:
	new_game()
	state = State.PLAYING
	get_tree().paused = false
	Engine.time_scale = 1.0
	AudioManager.start_music(theme_id)
	started.emit()
	banner(stage_name(), ("B MEJORAS / SOBREVIVE A LAS OLEADAS" if horde_mode else "AVANCEN Y RESUELVAN EN EQUIPO") if coop else ROUTE_HINTS[selected_boss], Color(BOSSES[selected_boss]["color"]))

func set_paused(p: bool) -> void:
	if state != State.PLAYING and state != State.PAUSED:
		return
	state = State.PAUSED if p else State.PLAYING
	get_tree().paused = p
	paused_changed.emit(p)

func trigger_game_over() -> void:
	state = State.GAMEOVER
	get_tree().paused = true
	Engine.time_scale = 1.0
	AudioManager.stop_music()
	AudioManager.play("gameover", -6.0)
	game_over.emit()

func trigger_win() -> void:
	if coop:
		coop_cleared[selected_boss] = true
		coop_score += score
	else:
		cleared[selected_boss] = true
		campaign_score += score
	save_campaign()
	state = State.WIN
	get_tree().paused = true
	Engine.time_scale = 1.0
	won.emit()

# ----- Estadísticas -----
func new_game() -> void:
	run_wave = 0
	team_energy = 0
	team_retries = 3
	kills = 0
	deaths = 0
	play_time = 0.0
	apply_theme_for_boss(selected_boss)
	score = 0
	lives = STARTING_LIVES
	health = MAX_HEALTH
	p_health = [MAX_HEALTH, MAX_HEALTH, MAX_HEALTH, MAX_HEALTH]
	p_lives = [STARTING_LIVES, STARTING_LIVES, STARTING_LIVES, STARTING_LIVES]
	combo = 0
	combo_timer = 0.0
	_tier_idx = -1
	_mk_count = 0
	_mk_timer = 0.0
	var c: Dictionary = CHARACTERS.get(character, CHARACTERS["orange"])
	current_weapon = c["primary"]
	unlocked = {c["primary"]: true}
	for id in acquired_powers:
		unlocked[id] = true
	level_index = 0
	game_running = true
	_emit_all()

func select_character(id: String) -> void:
	if not pilot_unlocked(id):
		return
	character = id
	character_changed.emit(id)

func select_boss(id: String) -> void:
	if not BOSSES.has(id):
		return
	selected_boss = id
	boss_changed.emit(id, boss_name())

func boss_name() -> String:
	return BOSSES.get(selected_boss, {}).get("name", "JEFE")

func character_name() -> String:
	return CHARACTERS.get(character, {}).get("name", "NARANJA")

func character_name_of(id: String) -> String:
	return CHARACTERS.get(id, {}).get("name", "?")

func weapon_name(id: String) -> String:
	if POWERS.has(id):
		return POWERS[id]["name"]
	if ONLINE_WEAPONS.has(id):
		return ONLINE_WEAPONS[id]["name"]
	return WEAPON_NAMES.get(id, id.to_upper())

func _emit_all() -> void:
	score_changed.emit(score)
	lives_changed.emit(lives)
	health_changed.emit(health, MAX_HEALTH)
	weapon_changed.emit(current_weapon)

func add_score(amount: int) -> void:
	var gained := int(round(float(amount) * combo_mult()))
	score += gained
	score_changed.emit(score)

# ----- Combo / dopamina -----
func combo_mult() -> float:
	return 1.0 + minf(float(combo) * 0.1, 2.0)

func register_hit() -> void:
	combo += 1
	combo_timer = COMBO_WINDOW
	combo_changed.emit(combo, combo_mult())
	# Anunciar cada nivel de combo una sola vez al cruzarlo.
	for i in range(COMBO_TIERS.size() - 1, -1, -1):
		var tier: Array = COMBO_TIERS[i]
		if combo >= int(tier[0]) and i > _tier_idx:
			_tier_idx = i
			combo_tier.emit(String(tier[1]), tier[2])
			AudioManager.play("combo", -10.0, 1.0 + 0.1 * float(i))
			break

# ----- Impacto (reemplaza al antiguo hit-stop) -----
# SIN cámara lenta: Engine.time_scale permanece siempre en 1.0 durante el
# juego. Se conserva el nombre para no romper llamadas existentes; ahora
# genera feedback (shake leve) sin tocar el tiempo global. El impacto real
# (flash, partículas, knockback, sonido, anillo) ya ocurre en cada llamada.
func hitstop(_seconds: float) -> void:
	if state != State.PLAYING:
		return
	shake(0.5)

# ----- Shake (usa la cámara compartida si existe) -----
func shake(amount: float) -> void:
	_shake_amount = minf(6.0, _shake_amount + amount)
	var cam := camera_override
	if cam == null or not is_instance_valid(cam):
		return
	var t := create_tween()
	for i in 4:
		var a := _shake_amount * (1.0 - float(i) / 4.0)
		t.tween_property(cam, "offset", Vector2(randf_range(-a, a), randf_range(-a, a)), 0.03)
	t.tween_property(cam, "offset", Vector2.ZERO, 0.05)

# ----- Salud global (jugador 1, compatibilidad) -----
func set_health(value: int) -> void:
	if not game_running:
		return
	health = clampi(value, 0, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0:
		player_died.emit()

func damage(amount: int) -> void:
	if not game_running or health <= 0:
		return
	set_health(health - amount)

func heal(amount: int) -> void:
	if not game_running:
		return
	set_health(health + amount)

func revive_full() -> void:
	health = MAX_HEALTH
	health_changed.emit(health, MAX_HEALTH)

## Consume una vida extra. Devuelve true si había una disponible.
func consume_life() -> bool:
	deaths += 1
	if lives <= 0:
		return false
	lives -= 1
	lives_changed.emit(lives)
	return true

# ----- Salud individual (coop) -----
func set_player_health(index: int, value: int) -> void:
	if not game_running:
		return
	value = clampi(value, 0, MAX_HEALTH)
	if index == 0:
		health = value
		health_changed.emit(value, MAX_HEALTH)
	p_health[index] = value
	player_health_changed.emit(index, value, MAX_HEALTH)

func damage_player(index: int, amount: int) -> void:
	if not game_running or p_health[index] <= 0:
		return
	set_player_health(index, p_health[index] - amount)
	if p_health[index] <= 0:
		player_died.emit()

func heal_player(index: int, amount: int) -> void:
	if not game_running:
		return
	set_player_health(index, p_health[index] + amount)

func revive_player_full(index: int) -> void:
	set_player_health(index, MAX_HEALTH)

func consume_life_player(index: int) -> bool:
	if index == 0:
		return consume_life()
	if p_lives[index] <= 0:
		return false
	p_lives[index] -= 1
	player_lives_changed.emit(index, p_lives[index])
	return true

func unlock_weapon(id: String) -> void:
	unlocked[id] = true
	current_weapon = id
	weapon_changed.emit(id)

func cycle_weapon() -> void:
	var ids := unlocked.keys()
	if ids.size() <= 1:
		return
	var i := ids.find(current_weapon)
	current_weapon = ids[(i + 1) % ids.size()]
	weapon_changed.emit(current_weapon)

func complete_level() -> void:
	level_completed.emit(level_index)
