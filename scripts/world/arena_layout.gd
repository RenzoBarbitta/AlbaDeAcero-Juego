extends RefCounted
static func build(stage: Node2D,x: float,width: float) -> void:
	stage._ground(x,width)
	var detail := preload("res://scripts/world/scene_landmarks.gd").new()
	detail.position.x = x
	detail.zone = stage.theme_id
	detail.span = width
	detail.act = 3
	stage.add_child(detail)
	var ratio := width/400.0
	var layouts := {
		"fundicion":[Vector2(55,110),Vector2(170,70),Vector2(290,110)],
		"ruinas":[Vector2(40,106),Vector2(130,62),Vector2(245,62),Vector2(320,106)],
		"glaciar":[Vector2(65,110),Vector2(175,70),Vector2(285,110)],
		"volcan":[Vector2(30,110),Vector2(120,70),Vector2(220,30),Vector2(300,70)],
		"central":[Vector2(50,110),Vector2(160,30),Vector2(280,110)],
		"cantera":[Vector2(30,110),Vector2(105,70),Vector2(210,110),Vector2(295,70)],
		"ciudad":[Vector2(35,110),Vector2(105,70),Vector2(180,30),Vector2(290,70)],
		"biolab":[Vector2(40,110),Vector2(125,70),Vector2(230,70),Vector2(300,110)]
	}
	for i in layouts[stage.theme_id].size():
		var at: Vector2 = layouts[stage.theme_id][i]
		if stage.theme_id=="glaciar" and i!=1:
			stage._add_crumble(x+at.x*ratio,at.y,52*ratio)
		elif stage.theme_id=="central" and i==1:
			stage._add_moving(x+at.x*ratio,at.y,56*ratio,Vector2(0,60),2.8)
		else: stage._architecture(x+at.x*ratio,at.y,48*ratio,16)
	var art := preload("res://scripts/world/arena_feature.gd").new()
	art.position = Vector2(x,0)
	art.zone = stage.theme_id
	art.width = width
	art.players = stage._players
	stage.add_child(art)
