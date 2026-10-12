extends RefCounted
## Authored traversal rooms. Transport replaces the old interpolated staircases.
const ROUTES := {
	"fundicion":[Vector2(70,150),Vector2(310,150),Vector2(310,-90),Vector2(640,-90),Vector2(640,-330),Vector2(1030,-330),Vector2(1250,-170),Vector2(1550,150)],
	"ruinas":[Vector2(70,150),Vector2(260,-10),Vector2(470,-170),Vector2(280,-330),Vector2(660,-490),Vector2(980,-330),Vector2(1250,-170),Vector2(1550,150)],
	"glaciar":[Vector2(70,150),Vector2(300,30),Vector2(540,-90),Vector2(780,-210),Vector2(1020,-330),Vector2(1240,-210),Vector2(1440,-50),Vector2(1550,150)],
	"volcan":[Vector2(70,150),Vector2(260,-50),Vector2(450,-250),Vector2(270,-450),Vector2(660,-450),Vector2(1030,-250),Vector2(1330,-90),Vector2(1550,150)],
	"central":[Vector2(70,150),Vector2(260,150),Vector2(260,-170),Vector2(620,-170),Vector2(620,-490),Vector2(1050,-490),Vector2(1310,-170),Vector2(1550,150)],
	"cantera":[Vector2(70,150),Vector2(300,-50),Vector2(640,-50),Vector2(640,-330),Vector2(1000,-330),Vector2(1190,-170),Vector2(1410,-10),Vector2(1550,150)],
	"ciudad":[Vector2(70,150),Vector2(300,150),Vector2(300,-170),Vector2(670,-170),Vector2(1050,-170),Vector2(1240,-370),Vector2(1440,-170),Vector2(1550,150)],
	"biolab":[Vector2(70,150),Vector2(280,-10),Vector2(480,-170),Vector2(280,-330),Vector2(670,-490),Vector2(1000,-330),Vector2(1270,-170),Vector2(1550,150)]
}

static func build(stage: Node2D,origin: float,act: int) -> float:
	var anchors: Array = ROUTES[stage.theme_id].duplicate()
	var scenery := preload("res://scripts/world/district_backdrop.gd").new()
	scenery.zone = stage.theme_id
	scenery.anchors = anchors
	scenery.position.x = origin
	scenery.accent = stage.theme["accent"]
	stage.add_child(scenery)
	var room := preload("res://scripts/world/traversal_feature.gd").new()
	room.zone = stage.theme_id
	room.position.x = origin
	room.players = stage._players
	room.anchors = anchors
	stage.add_child(room)
	stage._ground(origin,180)
	stage._ground(origin+1490,110)
	var route: Array = []
	for i in anchors.size():
		var at: Vector2 = anchors[i]+Vector2(origin,0)
		route.append(at)
		if i>0 and i<anchors.size()-1:
			stage._architecture(at.x-65,at.y,130,16)
			if i%2==0: stage._route_checkpoint(at)
			stage._spawn_air(at.x+20,at.y-70)
			stage._pickup("chip",at.x,at.y-20)
		if i==anchors.size()-1: continue
		var next: Vector2 = anchors[i+1]+Vector2(origin,0)
		var rising := next.y<at.y-50
		if stage.theme_id in ["fundicion","central","cantera","ciudad"]:
			# Full-height lifts and long cargo rides; no staircase underneath.
			var dock := at+Vector2(110 if i==0 else 70,0)
			var ferry: MovingPlatform = stage._add_moving(dock.x,dock.y,76,next+Vector2(70,0)-dock,3.5 if rising else 4.5,float(i)*0.3)
			ferry.skin = stage.theme_id
			ferry.set_meta("route_transport",true)
			ferry.set_meta("destination",next)
		elif rising:
			# Launch pads have enough airtime to reach the next island without upgrades.
			var spring := preload("res://scripts/world/spring.gd").new()
			spring.position = at+Vector2(28 if next.x>at.x else -28,0)
			spring.guided = true
			spring.launch_target = next
			spring.power = maxf(650,sqrt(1800*(at.y-next.y+75)))
			stage.add_child(spring)
		else:
			var ferry: MovingPlatform = stage._add_moving(at.x+70,at.y,64,next-at,3.8)
			ferry.skin = stage.theme_id
			ferry.set_meta("route_transport",true)
			ferry.set_meta("destination",next)
		if stage.theme_id=="glaciar" and i in [2,4,5]:
			stage._add_crumble(at.x+90,at.y-30,52)
		if i in [3,5]: stage._pickup("rare",at.x-42,at.y-18)
	stage.districts.append({"zone":stage.theme_id,"act":act,"route":route,"transport":true,"bounds":Rect2(origin,-620,1600,816)})
	return 1600
