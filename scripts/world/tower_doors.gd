extends Node2D
var stage: Node2D
func _ready() -> void: z_index = 20
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	var closing := 0.0
	if stage.phase=="departing": closing = clampf(1-stage.phase_time,0,1)
	elif stage.phase=="transit": closing = 1
	if closing<=0: return
	var w := 76*closing
	for rect in [Rect2(404,43,w,105),Rect2(556-w,43,w,105)]:
		draw_rect(rect,Color("40596b"))
		draw_rect(rect.grow(-3),Color("243c50"),false,1)
		draw_line(rect.position+Vector2(4,48),rect.position+Vector2(rect.size.x-4,48),Color("6996a1"),2)
