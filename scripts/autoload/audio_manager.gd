extends Node
## Audio chiptune generado en tiempo de ejecución (sin archivos de audio).
## Sintetiza ondas cuadradas/triangulares para SFX y música de fondo.

const RATE := 22050
const SFX_POOL := 12

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _sfx: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_build_sfx()
	_music = AudioStreamPlayer.new()
	_music.volume_db = -12.0
	add_child(_music)

func play(sound_id: String, volume_db: float = -6.0, pitch: float = 1.0) -> void:
	if not GameManager.settings["sfx"]:
		return
	if not _sfx.has(sound_id):
		return
	var p := _pool[_next]
	_next = (_next + 1) % SFX_POOL
	p.stream = _sfx[sound_id]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

# -------- Generación de sonidos --------
func _build_sfx() -> void:
	_sfx["shoot"] = _tone(880, 0.06, "square", 0.30, 220)
	_sfx["charge"] = _tone(220, 0.35, "triangle", 0.25, 1320)
	_sfx["charged"] = _tone(1200, 0.18, "square", 0.35, 300)
	_sfx["jump"] = _tone(300, 0.12, "square", 0.30, 900)
	_sfx["land"] = _tone(200, 0.05, "square", 0.25, 120)
	_sfx["hurt"] = _tone(400, 0.20, "saw", 0.35, 80)
	_sfx["enemy_shoot"] = _tone(500, 0.08, "square", 0.22, 200)
	_sfx["explode"] = _noise(0.35, 0.40)
	_sfx["hit"] = _noise(0.08, 0.28)
	_sfx["pickup"] = _arp([660, 880, 1320], 0.05, 0.30)
	_sfx["life"] = _arp([523, 659, 784, 1047], 0.06, 0.30)
	_sfx["dash"] = _tone(600, 0.14, "saw", 0.25, 200)
	_sfx["select"] = _tone(1000, 0.05, "square", 0.30, 1000)
	_sfx["gameover"] = _arp([440, 330, 262, 196], 0.16, 0.35)
	_sfx["chargeup"] = _tone(160, 0.4, "triangle", 0.30, 880)
	_sfx["bigshot"] = _noise(0.22, 0.40)
	_sfx["combo"] = _arp([880, 1108, 1318], 0.045, 0.30)
	_sfx["boss_roar"] = _tone(90, 0.5, "saw", 0.40, 45)
	_sfx["bighit"] = _tone(200, 0.14, "square", 0.40, 60)

func _tone(freq: float, dur: float, wave: String, amp: float, end_freq: float = -1.0) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var f0 := freq
	var f1 := end_freq if end_freq > 0.0 else freq
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := lerpf(f0, f1, t)
		phase += f / float(RATE)
		var s := 0.0
		match wave:
			"square": s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"triangle": s = 4.0 * absf(fmod(phase, 1.0) - 0.5) - 1.0
			"saw": s = 2.0 * fmod(phase, 1.0) - 1.0
		var env := 1.0 - t
		var v := int(clampf(s * amp * env, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	return _make_stream(data)

func _noise(dur: float, amp: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in n:
		var t := float(i) / float(n)
		var s := rng.randf_range(-1.0, 1.0)
		var env := 1.0 - t
		var v := int(clampf(s * amp * env, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	return _make_stream(data)

func _arp(freqs: Array, note_dur: float, amp: float) -> AudioStreamWAV:
	var total := int(RATE * note_dur * freqs.size())
	var data := PackedByteArray()
	data.resize(total * 2)
	var idx := 0
	for f in freqs:
		var n := int(RATE * note_dur)
		var phase := 0.0
		for i in n:
			phase += float(f) / float(RATE)
			var s := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			var t := float(i) / float(n)
			var v := int(clampf(s * amp * (1.0 - t * 0.8), -1.0, 1.0) * 32767.0)
			data.encode_s16(idx * 2, v)
			idx += 1
	return _make_stream(data)

func _make_stream(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s

# -------- Música de fondo: una canción distinta por zona --------
const Themes := preload("res://scripts/world/stage_themes.gd")
const SCALES := {
	"minor": [0, 2, 3, 5, 7, 8, 10],
	"phrygian": [0, 1, 3, 5, 7, 8, 10],
	"dorian": [0, 2, 3, 5, 7, 9, 10],
	"harmonic": [0, 2, 3, 5, 7, 8, 11],
	"pentatonic": [0, 3, 5, 7, 10, 12, 15],
}
const MUSIC_RATE := 11025

var _music_cache: Dictionary = {}
var _music_theme := ""

func start_music(theme_id: String = "ciudad") -> void:
	apply_settings()
	if _music.playing and _music_theme == theme_id:
		return
	if not _music_cache.has(theme_id):
		var cfg: Dictionary = Themes.get_theme(theme_id)["music"]
		_music_cache[theme_id] = _build_music(cfg)
	_music_theme = theme_id
	_music.stream = _music_cache[theme_id]
	_music.play()

func stop_music() -> void:
	_music.stop()
	_music_theme = ""

func apply_settings() -> void:
	if _music:
		_music.volume_db = -12 if GameManager.settings["music"] else -80

func _midi_to_hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)

func _scale_note(scale: Array, root: int, degree: int) -> float:
	var n := scale.size()
	var octave := floori(float(degree) / float(n))
	var idx := posmod(degree, n)
	var semis: int = scale[idx]
	return float(root + octave * 12 + semis)

## Compone ~16 s de chiptune en bucle: bajo, arpegio, melodía y batería.
func _build_music(cfg: Dictionary) -> AudioStreamWAV:
	var root: int = cfg["root"]
	var scale: Array = SCALES[cfg["scale"]]
	var bpm: float = cfg["bpm"]
	var prog: Array = cfg["prog"]
	var duty: float = cfg["duty"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg["seed"])
	var step_dur := 60.0 / bpm / 2.0
	var per_step := int(float(MUSIC_RATE) * step_dur)
	var steps := 64
	var total := per_step * steps
	var buf := PackedFloat32Array()
	buf.resize(total)

	# Melodía: paseo aleatorio por la escala, apoyado en notas del acorde
	var lead_deg: Array = []
	var cur := 7
	for s in steps:
		var chord_root: int = prog[floori(float(s)/16.0) % prog.size()]
		if s % 2 == 0 and rng.randf() < 0.75:
			var tones := [chord_root + 7, chord_root + 9, chord_root + 11, chord_root + 14]
			cur = tones[rng.randi_range(0, tones.size() - 1)]
			if rng.randf() < 0.3:
				cur += rng.randi_range(-1, 1)
			lead_deg.append(cur)
		elif rng.randf() < 0.35:
			cur += rng.randi_range(-2, 2)
			lead_deg.append(cur)
		else:
			lead_deg.append(-999)

	var drum_rng := RandomNumberGenerator.new()
	drum_rng.seed = 5
	for st in steps:
		var chord_root2: int = prog[floori(float(st)/16.0) % prog.size()]
		var base_i := st * per_step
		var bass_hz := _midi_to_hz(_scale_note(scale, root - 12, chord_root2) + (12.0 if st % 4 == 3 else 0.0))
		var arp_off: int = [0, 2, 4, 2][st % 4]
		var arp_deg: int = chord_root2 + arp_off + 7
		var arp_hz := _midi_to_hz(_scale_note(scale, root, arp_deg))
		var ld: int = lead_deg[st]
		var lead_hz := 0.0
		if ld != -999:
			lead_hz = _midi_to_hz(_scale_note(scale, root, ld))
		var pb := 0.0
		var pa := 0.0
		var pl := 0.0
		for j in per_step:
			var t := float(j) / float(per_step)
			var v := 0.0
			# bajo triangular
			pb += bass_hz / float(MUSIC_RATE)
			v += (4.0 * absf(fposmod(pb, 1.0) - 0.5) - 1.0) * 0.26 * (1.0 - t * 0.35)
			# arpegio pulso 12.5 %
			pa += arp_hz / float(MUSIC_RATE)
			v += (1.0 if fposmod(pa, 1.0) < 0.125 else -1.0) * 0.045 * (1.0 - t * 0.7)
			# melodía
			if lead_hz > 0.0:
				pl += lead_hz / float(MUSIC_RATE)
				var env := minf(1.0, t * 12.0) * (1.0 - t * 0.5)
				v += (1.0 if fposmod(pl, 1.0) < duty else -1.0) * 0.12 * env
			# batería
			var sm := st % 8
			if (sm == 0 or sm == 4) and t < 0.5:
				var kf := 110.0 * (1.0 - t * 1.4)
				v += sin(TAU * kf * t * step_dur) * 0.30 * (1.0 - t * 2.0)
			elif (sm == 2 or sm == 6) and t < 0.4:
				v += drum_rng.randf_range(-1.0, 1.0) * 0.12 * (1.0 - t * 2.5)
			elif t < 0.12:
				v += drum_rng.randf_range(-1.0, 1.0) * 0.035
			buf[base_i + j] = v

	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MUSIC_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total
	return stream
