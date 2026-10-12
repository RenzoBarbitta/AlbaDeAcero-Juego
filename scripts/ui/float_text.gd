extends Node2D
## Texto flotante (números de daño, avisos) dibujado con la fuente pixel.

const PT := preload("res://scripts/ui/pixel_text.gd")

var text := ""
var color := Color.WHITE
var px_scale := 1

static func spawn(parent: Node, pos: Vector2, txt: String, col: Color, sc: int = 1, rise: float = 16.0) -> void:
	if parent == null:
		return
	var f = load("res://scripts/ui/float_text.gd").new()
	f.text = txt
	f.color = col
	f.px_scale = sc
	f.position = pos
	f.z_index = 40
	parent.add_child(f)
	var t: Tween = f.create_tween()
	t.set_parallel(true)
	t.tween_property(f, "position", pos + Vector2(randf_range(-4.0, 4.0), -rise), 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(f, "modulate:a", 0.0, 0.5).set_delay(0.15)
	t.chain().tween_callback(f.queue_free)

func _draw() -> void:
	PT.draw(self, text, Vector2.ZERO, color, px_scale, PT.CENTER)
