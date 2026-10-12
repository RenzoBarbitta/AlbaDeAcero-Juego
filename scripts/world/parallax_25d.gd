class_name Parallax25D
extends Node
## Fondo por zonas: cielo, skyline 3D renderizado en un SubViewport (paralaje por
## perspectiva), tres capas de parallax 2D y partículas ambientales (lluvia,
## nieve, brasas, polvo, chispas, esporas) según el tema de la etapa.

const Themes := preload("res://scripts/world/stage_themes.gd")

var theme_id := "ciudad"
var theme: Dictionary = {}
var _cam3d: Camera3D
var _biome: Node2D
var _vp: SubViewport

func _ready() -> void:
	theme_id = GameManager.theme_id
	theme = Themes.get_theme(theme_id)
	_build_sky()
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	_biome = preload("res://scripts/world/biome_background.gd").new()
	_biome.zone = theme_id
	layer.add_child(_biome)
	_build_particles()

func _tex(texture_id: String) -> Texture2D:
	return load("res://assets/sprites/themes/%s/%s.png" % [theme_id, texture_id]) as Texture2D

func _build_sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -30
	add_child(layer)
	var sky := Sprite2D.new()
	sky.texture = _tex("bg_sky")
	sky.centered = false
	sky.z_index = -100
	layer.add_child(sky)

func _build_city_3d() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -20
	add_child(layer)

	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.size = Vector2(320, 180)
	layer.add_child(cont)

	_vp = SubViewport.new()
	_vp.size = Vector2i(320, 180)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	cont.add_child(_vp)

	var root3d := Node3D.new()
	_vp.add_child(root3d)

	_cam3d = Camera3D.new()
	_cam3d.position = Vector3(0, 5.0, 14.0)
	_cam3d.rotation = Vector3(-0.12, 0, 0)
	_cam3d.fov = 55.0
	_cam3d.current = true
	root3d.add_child(_cam3d)

	var b3d: Dictionary = theme["b3d"]
	var ground_col: Color = b3d["ground"]
	var ground := _box(Vector3(300, 1, 120), ground_col)
	ground.position = Vector3(60, -0.5, -40)
	root3d.add_child(ground)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260 + theme_id.hash() % 1000
	var palette: Array = b3d["colors"]
	var win_col: Color = b3d["win"]
	var winmat := StandardMaterial3D.new()
	winmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	winmat.albedo_color = win_col
	var count: int = b3d["count"]
	for i in count:
		var w := rng.randf_range(float(b3d["wmin"]), float(b3d["wmax"]))
		var h := rng.randf_range(float(b3d["hmin"]), float(b3d["hmax"]))
		var d := rng.randf_range(2.0, 5.0)
		var bx := rng.randf_range(-70.0, 170.0)
		var bz := rng.randf_range(-10.0, -70.0)
		var col: Color = palette[rng.randi_range(0, palette.size() - 1)]
		var b := _box(Vector3(w, h, d), col)
		b.position = Vector3(bx, h * 0.5, bz)
		root3d.add_child(b)
		if rng.randf() > 0.5:
			var wm := BoxMesh.new()
			wm.size = Vector3(w * 0.7, 0.3, 0.1)
			for r in 4:
				var win := MeshInstance3D.new()
				win.mesh = wm
				win.material_override = winmat
				win.position = Vector3(bx, h * 0.2 + float(r) * (h * 0.18), bz + d * 0.5)
				root3d.add_child(win)

func _box(size: Vector3, col: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	return mi

func _build_parallax() -> void:
	var pb := ParallaxBackground.new()
	pb.layer = -10
	add_child(pb)
	_add_parallax_layer(pb, _tex("bg_far"), 0.12, -6.0)
	_add_parallax_layer(pb, _tex("bg_mid"), 0.30, 6.0)
	_add_parallax_layer(pb, _tex("bg_near"), 0.62, 20.0)

func _add_parallax_layer(pb: ParallaxBackground, tex: Texture2D, scale_x: float, yoff: float) -> void:
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2(scale_x, 1.0)
	pl.motion_mirroring = Vector2(480, 0)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.region_enabled = true
	spr.region_rect = Rect2(0, 0, 480, 180)
	spr.position = Vector2(0, yoff)
	pl.add_child(spr)
	pb.add_child(pl)

# ------------------------------------------------------------------
# Partículas ambientales (en pantalla, por encima del mundo)
# ------------------------------------------------------------------
func _build_particles() -> void:
	var kind: String = theme.get("particles", "")
	if kind == "":
		return
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)

	var p := CPUParticles2D.new()
	p.texture = tex
	p.local_coords = false
	p.emitting = true
	p.one_shot = false
	p.explosiveness = 0.0
	p.randomness = 1.0
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.12, 0.8, 1.0])
	var c := Color.WHITE
	match kind:
		"rain":
			c = Color(0.65, 0.78, 1.0)
			p.amount = 90
			p.lifetime = 1.1
			p.position = Vector2(170, -6)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(210, 2)
			p.direction = Vector2(-0.25, 1.0)
			p.spread = 4.0
			p.initial_velocity_min = 190.0
			p.initial_velocity_max = 240.0
			p.scale_amount_min = 0.5
			p.scale_amount_max = 0.8
		"snow":
			c = Color(1, 1, 1)
			p.amount = 70
			p.lifetime = 6.0
			p.position = Vector2(160, -6)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(190, 2)
			p.direction = Vector2(0.3, 1.0)
			p.spread = 25.0
			p.initial_velocity_min = 14.0
			p.initial_velocity_max = 30.0
			p.scale_amount_min = 0.8
			p.scale_amount_max = 1.6
		"embers":
			c = Color(1.0, 0.6, 0.2)
			p.amount = 46
			p.lifetime = 4.0
			p.position = Vector2(160, 186)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(190, 2)
			p.direction = Vector2(0.2, -1.0)
			p.spread = 30.0
			p.initial_velocity_min = 18.0
			p.initial_velocity_max = 44.0
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.3
		"dust":
			c = Color(0.9, 0.78, 0.6)
			p.amount = 40
			p.lifetime = 5.0
			p.position = Vector2(330, 90)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(2, 100)
			p.direction = Vector2(-1.0, 0.1)
			p.spread = 12.0
			p.initial_velocity_min = 36.0
			p.initial_velocity_max = 80.0
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.2
		"sparks":
			c = Color(0.55, 0.95, 1.0)
			p.amount = 34
			p.lifetime = 1.4
			p.position = Vector2(160, 90)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(170, 80)
			p.direction = Vector2(0.0, -1.0)
			p.spread = 180.0
			p.initial_velocity_min = 6.0
			p.initial_velocity_max = 26.0
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.2
		_:
			c = Color(0.6, 1.0, 0.65)
			p.amount = 40
			p.lifetime = 7.0
			p.position = Vector2(160, 100)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(180, 90)
			p.direction = Vector2(0.0, -1.0)
			p.spread = 180.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 10.0
			p.scale_amount_min = 0.7
			p.scale_amount_max = 1.6
	grad.colors = PackedColorArray([
		Color(c.r, c.g, c.b, 0.0), Color(c.r, c.g, c.b, 0.85),
		Color(c.r, c.g, c.b, 0.85), Color(c.r, c.g, c.b, 0.0)])
	p.color_ramp = grad
	p.preprocess = p.lifetime
	layer.add_child(p)

## Llamado por el juego cada frame con la posición X del jugador.
func update(player_x: float) -> void:
	if _biome: _biome.scroll = player_x*0.1
	if _cam3d:
		_cam3d.position.x = player_x * 0.05
