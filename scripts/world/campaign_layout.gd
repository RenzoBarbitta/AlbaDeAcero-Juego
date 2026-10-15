extends RefCounted
const DATA := preload("res://scripts/world/campaign_rooms.gd")
const FERRY_W := 76.0
const DOCK_OVERLAP := 8.0

static func build(stage: Node2D,origin: float,act: int) -> float:
	var room: Dictionary = DATA.ROOMS[stage.theme_id][act]
	var route: Array = []
	var decks: Array = room["decks"]
	var art := preload("res://scripts/world/campaign_room_art.gd").new()
	art.position.x = origin
	art.room = room
	art.zone = stage.theme_id
	art.players = stage._players
	stage.add_child(art)
	var detail := preload("res://scripts/world/scene_landmarks.gd").new()
	detail.zone = stage.theme_id
	detail.position.x = origin
	detail.span = float(room["span"])
	detail.act = act
	detail.decks = decks
	stage.add_child(detail)
	for i in decks.size():
		var d: Array = decks[i]
		var at := Vector2(origin+float(d[0]),float(d[1]))
		route.append(at)
		var width := float(d[2])
		if float(d[1])==150:
			stage._ground(at.x-width*0.5,width)
		elif stage.theme_id=="glaciar" and act==2 and i in [2,3,4]:
			stage._add_crumble(at.x-width*0.5,at.y,width)
		else: stage._architecture(at.x-width*0.5,at.y,width,16)
		if i>0 and i<decks.size()-1:
			if i%2==0: stage._route_checkpoint(at)
			stage._spawn_ground(at.x+width*0.3,at.y)
			if i%3==2: stage._spawn_air(at.x-20,at.y-70)
			stage._pickup("chip",at.x,at.y-18)
		if i==decks.size()-1: continue
		var target: Array = decks[i+1]
		var next := Vector2(origin+float(target[0]),float(target[1]))
		var mode: String = room["links"].substr(i,1)
		var gap := absf(next.x-at.x)-(width+float(target[2]))*0.5
		if mode=="s":
			var spring := preload("res://scripts/world/spring.gd").new()
			spring.position = at+Vector2(28 if next.x>at.x else -28,0)
			spring.guided = true
			spring.skin = stage.theme_id
			spring.launch_target = next
			spring.power = maxf(650,sqrt(1800*(at.y-next.y+75)))
			stage.add_child(spring)
		elif mode in ["l","r"] or (mode=="d" and gap>52):
			# El ferry debe atracar por el lado de aproximacion. Antes terminaba
			# al otro lado de la plataforma de destino y atravesaba el deck,
			# dejando al jugador enganchado contra la geometria.
			var dx := next.x-at.x
			var start := Vector2.ZERO
			var end := Vector2.ZERO
			if absf(dx)<1.0:
				# Ascensor vertical: se mantiene junto al mismo lateral de ambos decks.
				start = Vector2(at.x+width*0.5-DOCK_OVERLAP,at.y)
				end = Vector2(next.x+float(target[2])*0.5-DOCK_OVERLAP,next.y)
			elif dx>0:
				start = Vector2(at.x+width*0.5-DOCK_OVERLAP,at.y)
				end = Vector2(next.x-float(target[2])*0.5-FERRY_W+DOCK_OVERLAP,next.y)
			else:
				start = Vector2(at.x-width*0.5-FERRY_W+DOCK_OVERLAP,at.y)
				end = Vector2(next.x+float(target[2])*0.5-DOCK_OVERLAP,next.y)
			var ferry: MovingPlatform = stage._add_moving(start.x,start.y,FERRY_W,end-start,3.4 if mode=="l" else 4.4)
			ferry.skin = stage.theme_id
			ferry.set_meta("route_transport",true)
			ferry.set_meta("destination",next)
			ferry.set_meta("landing_width",float(target[2]))
	for i in room["devices"].size():
		var data: Array = room["devices"][i]
		var device := preload("res://scripts/world/campaign_mechanism.gd").new()
		device.kind = data[0]
		device.position = Vector2(origin+float(data[1]),float(data[2]))
		device.size = Vector2(float(data[3]),float(data[4]))
		device.zone = stage.theme_id
		device.players = stage._players
		device.offset = float(i)*1.3
		stage.add_child(device)
	# A reachable upper alcove is optional; the critical path never needs a mobility unlock.
	var middle: Array = decks[mini(2,decks.size()-2)]
	var secret := Vector2(origin+float(middle[0])-float(middle[2])*0.3,float(middle[1])-40)
	stage._architecture(secret.x-30,secret.y,60,16)
	stage._pickup("rare",secret.x,secret.y-17)
	stage.districts.append({"zone":stage.theme_id,"act":act,"title":room["title"],"route":route,"authored":true,"transport":true,"bounds":Rect2(origin,-650,float(room["span"]),846),"links":room["links"]})
	return float(room["span"])
