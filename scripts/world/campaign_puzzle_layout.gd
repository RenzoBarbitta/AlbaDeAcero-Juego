extends RefCounted
const FERRY_W := 60.0
const DOCK_OVERLAP := 8.0
const NODES := {
	"fundicion":[[[200,110],[420,70],[640,30],[420,-150],[720,-150],[830,70]],[[210,110],[210,-130],[480,-130],[750,-130],[480,70],[820,110]]],
	"ruinas":[[[210,70],[480,70],[210,-170],[510,-170],[750,-50],[820,110]],[[210,110],[430,70],[660,30],[430,-170],[750,-170],[830,70]]],
	"glaciar":[[[200,110],[340,70],[490,30],[650,-10],[790,30],[830,110]],[[200,110],[420,70],[650,30],[820,70],[650,-170],[420,-170]]],
	"volcan":[[[200,70],[380,-130],[200,-330],[610,-330],[800,-130],[810,70]],[[210,110],[430,70],[650,30],[810,70],[650,-170],[430,-170]]],
	"central":[[[200,110],[200,-130],[460,-130],[720,-130],[720,110],[820,110]],[[200,110],[420,70],[650,30],[420,-210],[720,-210],[820,70]]],
	"cantera":[[[210,110],[420,70],[650,30],[420,-210],[730,-210],[820,70]],[[210,110],[210,-130],[470,-130],[740,-130],[740,70],[820,110]]],
	"ciudad":[[[200,110],[400,70],[600,30],[800,-10],[600,-210],[350,-210]],[[200,110],[390,70],[600,30],[800,-10],[800,-210],[460,-210]]],
	"biolab":[[[200,110],[360,70],[520,30],[680,-10],[820,30],[820,110]],[[200,110],[200,-130],[440,-130],[700,-130],[700,70],[820,110]]]
}

static func nodes_for(zone: String,chapter: int) -> Array:
	var result: Array = []
	for p in NODES[zone][chapter-1]: result.append(Vector2(p[0],p[1]))
	return result

static func build(stage: Node2D,puzzle: Node2D,origin: float,chapter: int) -> void:
	var deck_data: Array = [[64,150,128]]
	for p in puzzle.nodes: deck_data.append([p.x,p.y,140])
	deck_data.append([970,150,108])
	for i in puzzle.nodes.size():
		var at: Vector2 = puzzle.nodes[i]+Vector2(origin,0)
		stage._architecture(at.x-70,at.y,140,16)
		if i in [2,4]: stage._spawn_air(at.x,at.y-70)
	var art := preload("res://scripts/world/campaign_room_art.gd").new()
	art.position.x = origin
	art.zone = stage.theme_id
	art.room = {"title":"", "span":1024, "decks":deck_data}
	stage.add_child(art)
	# Looped lifts allow revisiting objectives in any order, including return trips with cargo.
	for i in range(deck_data.size()-1):
		var a: Array = deck_data[i]
		var b: Array = deck_data[i+1]
		var gap := absf(float(b[0])-float(a[0]))-(float(a[2])+float(b[2]))*0.5
		if absf(float(b[1])-float(a[1]))<=40 and gap<=50: continue
		var ax := origin+float(a[0])
		var bx := origin+float(b[0])
		var dx := bx-ax
		var start := Vector2.ZERO
		var end := Vector2.ZERO
		if absf(dx)<1.0:
			start = Vector2(ax+float(a[2])*0.5-DOCK_OVERLAP,float(a[1]))
			end = Vector2(bx+float(b[2])*0.5-DOCK_OVERLAP,float(b[1]))
		elif dx>0:
			start = Vector2(ax+float(a[2])*0.5-DOCK_OVERLAP,float(a[1]))
			end = Vector2(bx-float(b[2])*0.5-FERRY_W+DOCK_OVERLAP,float(b[1]))
		else:
			start = Vector2(ax-float(a[2])*0.5-FERRY_W+DOCK_OVERLAP,float(a[1]))
			end = Vector2(bx+float(b[2])*0.5-DOCK_OVERLAP,float(b[1]))
		var ferry: MovingPlatform = stage._add_moving(start.x,start.y,FERRY_W,end-start,2.5)
		ferry.skin = stage.theme_id
	if puzzle.rule in ["warmth","courier"]:
		var start: Vector2 = puzzle.global_position+puzzle.escort_position()-Vector2(38,8)
		var carrier: MovingPlatform = stage._add_moving(start.x,start.y,76,Vector2.ZERO,1)
		carrier.motion.kill()
		carrier.skin = stage.theme_id
		puzzle.escort_carrier = carrier
	# Reinforce the regional mechanic without putting a timed hazard directly on an objective.
	if stage.theme_id in ["ruinas","cantera"]:
		var rock := preload("res://scripts/world/campaign_mechanism.gd").new()
		rock.kind = "rock"
		rock.zone = stage.theme_id
		rock.position = Vector2(origin+850,90)
		rock.size = Vector2(20,60)
		stage.add_child(rock)
	stage.set_meta("puzzle_layout_%d" % chapter,puzzle.nodes.duplicate())

static func first_nodes(zone: String) -> Array:
	var layouts := {
		"fundicion":[Vector2(190,150),Vector2(390,110),Vector2(570,70)],
		"ruinas":[Vector2(190,110),Vector2(390,70),Vector2(230,-90),Vector2(560,-90)],
		"glaciar":[Vector2(200,110),Vector2(390,70),Vector2(580,110)],
		"volcan":[Vector2(220,110),Vector2(220,-90),Vector2(560,30)],
		"central":[Vector2(180,110),Vector2(360,70),Vector2(560,70),Vector2(560,-130)],
		"cantera":[Vector2(190,110),Vector2(390,-50),Vector2(590,110)],
		"ciudad":[Vector2(200,110),Vector2(400,30),Vector2(590,-50)],
		"biolab":[Vector2(200,110),Vector2(390,70),Vector2(580,30)]
	}
	return layouts[zone]

static func build_first(stage: Node2D,puzzle: Node2D,origin: float) -> void:
	var decks: Array = []
	for at in puzzle.control_positions:
		decks.append([at.x,at.y,140])
		if at.y!=150: stage._architecture(origin+at.x-70,at.y,140,16)
		if at.y<70:
			var lift: MovingPlatform = stage._add_moving(origin+at.x+78,150,48,Vector2(0,at.y-150),2.5)
			lift.skin = stage.theme_id
	var art := preload("res://scripts/world/campaign_room_art.gd").new()
	art.position.x = origin
	art.zone = stage.theme_id
	art.room = {"title":"", "span":768, "decks":decks}
	stage.add_child(art)
