extends RefCounted
## Each district changes elevation by hundreds of pixels and has its own silhouette.
const PROFILES := {
	"fundicion":[Vector2(60,150),Vector2(230,30),Vector2(350,-170),Vector2(210,-290),Vector2(540,-410),Vector2(780,-410),Vector2(900,-210),Vector2(1100,-330),Vector2(1300,-330),Vector2(1500,-330),Vector2(1570,150)],
	"ruinas":[Vector2(60,150),Vector2(300,30),Vector2(490,-90),Vector2(260,-210),Vector2(490,-330),Vector2(710,-450),Vector2(920,-330),Vector2(760,-210),Vector2(1100,-90),Vector2(1310,-330),Vector2(1500,-330),Vector2(1570,150)],
	"glaciar":[Vector2(60,150),Vector2(250,-10),Vector2(450,-170),Vector2(320,-330),Vector2(570,-450),Vector2(800,-330),Vector2(1010,-450),Vector2(1230,-330),Vector2(1500,-330),Vector2(1570,150)],
	"volcan":[Vector2(60,150),Vector2(230,-10),Vector2(410,-330),Vector2(680,-450),Vector2(880,-210),Vector2(700,-90),Vector2(1070,-170),Vector2(1300,-370),Vector2(1500,-370),Vector2(1570,150)],
	"central":[Vector2(60,150),Vector2(340,30),Vector2(180,-90),Vector2(430,-210),Vector2(220,-330),Vector2(520,-450),Vector2(790,-450),Vector2(1010,-330),Vector2(830,-210),Vector2(1200,-330),Vector2(1500,-330),Vector2(1570,150)],
	"cantera":[Vector2(60,150),Vector2(310,30),Vector2(580,-90),Vector2(380,-210),Vector2(650,-370),Vector2(900,-490),Vector2(720,-330),Vector2(1070,-210),Vector2(1320,-370),Vector2(1500,-370),Vector2(1570,150)],
	"ciudad":[Vector2(60,150),Vector2(250,-10),Vector2(470,-170),Vector2(710,-330),Vector2(510,-450),Vector2(880,-450),Vector2(1060,-330),Vector2(1240,-450),Vector2(1500,-450),Vector2(1570,150)],
	"biolab":[Vector2(60,150),Vector2(250,30),Vector2(460,-130),Vector2(280,-290),Vector2(590,-410),Vector2(820,-290),Vector2(640,-170),Vector2(1080,-290),Vector2(1300,-410),Vector2(1500,-410),Vector2(1570,150)]
}

static func build(stage: Node2D, origin_x: float, act: int) -> float:
	var anchors: Array = PROFILES[stage.theme_id].duplicate()
	# Later districts use different tower heights and return corridors.
	for i in range(1,anchors.size()-1):
		anchors[i] += Vector2(0,-float(act)*40)
	var scenery := preload("res://scripts/world/district_backdrop.gd").new()
	scenery.position = Vector2(origin_x,0)
	scenery.zone = stage.theme_id
	scenery.anchors = anchors
	scenery.accent = stage.theme["accent"]
	stage.add_child(scenery)
	var route := preload("res://scripts/world/route_geometry.gd").points(anchors)
	for i in route.size(): route[i] += Vector2(origin_x,0)
	stage.districts.append({"zone":stage.theme_id,"act":act,"route":route,"bounds":Rect2(origin_x,-600,1600,796)})
	stage._ground(origin_x,140)
	stage._ground(origin_x+1530,70)
	for i in range(1,route.size()-1):
		var at := route[i]
		var widths := [72,96,120,88]
		var width: int = widths[(i+act+stage.theme_id.length())%widths.size()]
		stage._architecture(at.x-width*0.5,at.y,width,16)
		if i%7==3:
			stage._spawn_air(at.x,at.y-45)
			stage._pickup("chip",at.x,at.y-16)
		if i%11==5:
			stage._spawn_ground(at.x,at.y)
		if i%14==8:
			stage._route_checkpoint(at)
	# Roof terraces and galleries span complete horizontal runs rather than repeated steps.
	for i in range(anchors.size()-1):
		var a: Vector2 = anchors[i]
		var b: Vector2 = anchors[i+1]
		if absf(a.y-b.y)<1 and absf(a.x-b.x)>100:
			stage._architecture(origin_x+minf(a.x,b.x)-48,a.y,absf(a.x-b.x)+96,16)
	# This solid buttress makes the climb mandatory; a flat floor cannot bypass it.
	var summit: Vector2 = anchors[anchors.size()-2]
	stage._architecture(origin_x+1438,summit.y+12,24,196-summit.y-12,true)
	# An optional suspended balcony, accessible from the upper route, rewards exploration.
	var branch: Vector2 = Vector2(origin_x,0)+anchors[4]+Vector2(-70,-40)
	stage._architecture(branch.x-42,branch.y,84,16)
	stage._pickup("rare",branch.x,branch.y-15)
	stage._pickup("health",branch.x+22,branch.y-15)
	# Mechanical transport and unstable shortcuts vary by biome.
	if stage.theme_id in ["fundicion","central","cantera"]:
		stage._add_moving(origin_x+600,60,72,Vector2(0,-240-act*40),4.2)
	elif stage.theme_id in ["glaciar","volcan"]:
		stage._add_crumble(origin_x+950,-130-act*40,64)
	else:
		stage._add_moving(origin_x+880,-170,64,Vector2(120,-80),3.2)
	return 1600
