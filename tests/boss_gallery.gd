extends Node2D
const ART := preload("res://scripts/enemies/boss_visual.gd")
const PT := preload("res://scripts/ui/pixel_text.gd")
const IDS := ["sierra","estruendo","glaciar","incendio","voltaje","coloso","espectro","enjambre","nucleo"]
var rigs: Array = []
func _ready() -> void:
	get_window().content_scale_size = Vector2i(384,324)
	for i in IDS.size():
		var rig := ART.new()
		rig.design = IDS[i]
		rig.color = GameManager.BOSSES[IDS[i]]["color"]
		rig.position = Vector2(64+(i%3)*128,70+floori(float(i)/3)*108)
		rig.scale = Vector2.ONE*1.5
		rig.action = preload("res://scripts/enemies/boss_patterns.gd").MOVES[IDS[i]][0]
		add_child(rig)
		rigs.append(rig)
	call_deferred("run")
func _draw() -> void:
	draw_rect(Rect2(0,0,384,324),Color("0b1422"))
	for i in IDS.size():
		var at := Vector2((i%3)*128,floori(float(i)/3)*108)
		draw_rect(Rect2(at+Vector2(3,3),Vector2(122,102)),Color("1d3040"),false,1)
		PT.draw_box(self,IDS[i].to_upper(),Rect2(at+Vector2(5,6),Vector2(118,14)),GameManager.BOSSES[IDS[i]]["color"])
func run() -> void:
	for state in ["idle","tell","act","wait"]:
		for rig in rigs:
			rig.motion_state = state
			rig.phase = 0 if state=="tell" else 1
		await get_tree().create_timer(0.2 if state=="act" else 0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/previews/boss_family_"+state+".png")
	get_tree().quit()
