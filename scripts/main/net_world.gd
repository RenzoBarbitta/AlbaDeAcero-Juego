extends Node
var game: Node2D
var proxies := {}
var _tick := 0.0
var _frame := 0
var _actor_targets: Array = []
var _entity_targets := {}
var scenery: Array = []
var features: Array = []
var _events: Array = []
var _event_id := 0
var _last_event := 0
var _sound_times := {}
var _entity_velocities := {}
var _snapshot_age := 0.0
var replaying := false
var remote_sound_count := 0
var remote_fx_count := 0

func record_event(kind: String,data: Dictionary) -> void:
	if not NetSession.online or not NetSession.host or GameManager.state!=GameManager.State.PLAYING: return
	_event_id += 1
	_events.append({"id":_event_id,"kind":kind,"data":data,"ms":Time.get_ticks_msec()})
	while _events.size()>128: _events.pop_front()

func _sound(sound_id: String,db: float,pitch: float) -> void:
	if sound_id in ["select","combo","gameover"]: return
	var now := Time.get_ticks_msec()
	if now-int(_sound_times.get(sound_id,-1000))<70: return
	_sound_times[sound_id] = now
	record_event("sound",{"sound":sound_id,"db":db,"pitch":pitch})

func _play_events(events: Array) -> void:
	replaying = true
	for event in events:
		if int(event["id"])<=_last_event: continue
		_last_event = int(event["id"])
		var data: Dictionary = event["data"]
		if event["kind"]=="sound":
			AudioManager.play_remote(data["sound"],float(data["db"]),float(data["pitch"]))
			remote_sound_count += 1
			continue
		var pos := Vector2(data.get("x",0),data.get("y",0))
		var col := Color.html(data.get("color","ffffff"))
		match event["kind"]:
			"explosion": FX.explosion(game.world,pos,float(data["size"]))
			"muzzle": FX.muzzle(game.world,pos,false,float(data["angle"]),col)
			"ring": FX.ring(game.world,pos,col,float(data["start"]),float(data["end"]),float(data["duration"]))
			"beam": FX.beam(game.world,pos,Vector2(data["tx"],data["ty"]),col)
			"damage": FX.damage_number(game.world,pos,int(data["amount"]),col,data["crit"])
		remote_fx_count += 1
	replaying = false
const REGION := preload("res://scripts/enemies/zone_enemy.gd")
const BOSS_ART := preload("res://scripts/enemies/boss_visual.gd")
const PICKUP := preload("res://scripts/pickups/pickup.gd")
const BOSS_HAZARD := preload("res://scripts/enemies/boss_hazard.gd")
const FX := preload("res://scripts/fx/fx.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	NetSession.world = self
	AudioManager.sound_played.connect(_sound)
	for child in descendants(game.level):
		if child is MovingPlatform or child.get_script()==preload("res://scripts/world/crumble_platform.gd"): scenery.append(child)
		if child.get_script() in [preload("res://scripts/world/arena_feature.gd"),preload("res://scripts/world/traversal_feature.gd")]: features.append(child)
	if not NetSession.host:
		game.level.process_mode = Node.PROCESS_MODE_DISABLED
		for p in game.players:
			p.set_physics_process(p.index==NetSession.local_index)
		# Only decorative nodes escape the disabled authoritative level tree.
		for child in descendants(game.level):
			if child.get_script() in [preload("res://scripts/world/scene_landmarks.gd"),preload("res://scripts/world/tower_interior.gd")]:
				child.process_mode = Node.PROCESS_MODE_PAUSABLE
		for e in descendants(game.level):
			if e is EnemyBase or e is Pickup:
				e.visible = false
				e.collision_layer = 0
				e.collision_mask = 0
		var director: Node = game.world.get_node_or_null("CoopDirector")
		if director:
			director.set_physics_process(false)

func descendants(parent: Node) -> Array:
	var out: Array = []
	for child in parent.get_children():
		out.append(child)
		out.append_array(descendants(child))
	return out

func _process(delta: float) -> void:
	if not NetSession.online:
		return
	if NetSession.host:
		_tick += delta
		if _tick >= 0.05:
			_tick = 0
			_frame += 1
			NetSession.send_packet({"type":"snapshot","data":snapshot()})
	else:
		var blend := 1-exp(-delta*35)
		_snapshot_age += delta
		var advance := delta if _snapshot_age<0.1 else 0.0
		for i in mini(_actor_targets.size(),game.players.size()):
			if i==NetSession.local_index: continue
			_actor_targets[i] += game.players[i].velocity*advance
			game.players[i].position = game.players[i].position.lerp(_actor_targets[i],blend)
		for id in _entity_targets.keys():
			if proxies.has(id):
				if proxies[id].get_meta("effect","")=="sierra": proxies[id].rotation += delta*22
				_entity_targets[id] += _entity_velocities.get(id,Vector2.ZERO)*advance
				proxies[id].position = proxies[id].position.lerp(_entity_targets[id],blend)

func visible_to_team(at: Vector2,distance: float) -> bool:
	for p in game.players:
		if absf(p.global_position.x-at.x)<distance:
			return true
	return false

func snapshot() -> Dictionary:
	var moving: Array = []
	for child in scenery:
		moving.append({"x":child.position.x,"y":child.position.y,"visible":child.visible,"crumble":child._state if child.get_script()==preload("res://scripts/world/crumble_platform.gd") else 0})
	var actors: Array = []
	for p in game.players:
		actors.append({"p":[p.position.x,p.position.y],"v":[p.velocity.x,p.velocity.y],"a":[p.aim.x,p.aim.y],"f":p.facing,"alive":p.alive,"connected":p.network_active,"floor":p.is_on_floor(),"weapon":p.weapon,"hurt":p._invuln,"dash":p._dash_time,"shot":p._shoot_cooldown,"flash":p._shot_flash,"upgrades":[p.damage_level,p.armor_level,p.fire_level],"mobility":p.bonus_mobility,"jet":p.jet_active,"fuel":p.jet_fuel,"charge":p._charge_t if p._charging else 0,"landing":p.landing_squash,"ack":p.last_input_seq,"echo":p.last_input_ms})
	var entities: Array = []
	for e in game.get_tree().get_nodes_in_group("enemy")+game.get_tree().get_nodes_in_group("net_entity"):
		if e is Node2D and not visible_to_team(e.global_position,600):
			continue
		if e is EnemyBase and not e.dead:
			var item := {"id":str(e.get_instance_id()),"type":"enemy","p":[e.global_position.x,e.global_position.y],"v":[e.velocity.x,e.velocity.y],"hp":e.health,"max":e.max_health,"boss":e is Boss,"f":e.facing}
			if e is Boss:
				item["design"] = e.boss_id
				item["rage"] = e._rage
				item["shielded"] = e._visual.shielded
				item["action"] = e._visual.action
				item["phase"] = e._visual.phase
				item["motion"] = e.velocity.x
				item["rig_state"] = e._phase
				item["clock"] = e._t
			elif e.get_script() == REGION:
				item["zone"] = e.zone
				item["air"] = e.airborne
				item["small"] = e.small
				item["clock"] = e._time
				item["tell"] = e._tell
			entities.append(item)
		elif e.get_script()==BOSS_HAZARD and not e.dead:
			entities.append({"id":str(e.get_instance_id()),"type":"boss_hazard","p":[e.position.x,e.position.y],"v":[e.velocity.x,e.velocity.y],"kind":e.kind,"size":[e.size.x,e.size.y],"color":e.color.to_html(),"age":e.age,"warn":e.warn,"duration":e.duration,"health":e.health})
		elif e is Bullet and not e._dead:
			entities.append({"id":str(e.get_instance_id()),"type":"bullet","p":[e.global_position.x,e.global_position.y],"v":[e.velocity.x,e.velocity.y],"color":e.color.to_html(),"player":e.from_player,"texture":e._sprite.texture.resource_path,"scale":e._sprite.scale.x,"effect":e.effect,"heavy":e.heavy})
		elif e is Pickup:
			entities.append({"id":str(e.get_instance_id()),"type":"pickup","p":[e.global_position.x,e.global_position.y],"kind":e.kind})
	var puzzle_states: Array = []
	for puzzle in game.level.puzzles:
		puzzle_states.append({"solved":puzzle.solved,"values":puzzle.values,"step":puzzle.step,"clock":puzzle.clock,"progress":puzzle.progress,"expedition":puzzle.expedition_state() if puzzle.has_method("expedition_state") else {}})
	var station_states: Array = []
	for station in game.level.stations:
		station_states.append({"solved":station.solved,"progress":station.progress,"wave":station.wave,"owner":station.plate_owner})
	var cutoff := Time.get_ticks_msec()-800
	_events = _events.filter(func(event): return int(event["ms"])>cutoff)
	return {"events":_events,"rescue":game.world.get_node("CoopDirector").rescue if game.world.has_node("CoopDirector") else [],"scenery":moving,"horde":game.level.horde_snapshot() if game.level.has_method("horde_snapshot") else {},"frame":_frame,"actors":actors,"entities":entities,"puzzles":puzzle_states,"stations":station_states,"state":GameManager.state,"hp":GameManager.p_health,"score":GameManager.score,"kills":GameManager.kills,"time":GameManager.play_time,"energy":GameManager.team_energy,"retries":GameManager.team_retries,"boss_down":game.level._boss_down,"arena":game.level._arena_locked,"boss_hp":game.level.boss.health if is_instance_valid(game.level.boss) else 0,"boss_id":game.level.boss.boss_id if is_instance_valid(game.level.boss) else GameManager.selected_boss,"boss_max":game.level.boss.max_health if is_instance_valid(game.level.boss) else 1,"checkpoint":[game.level._checkpoint.x,game.level._checkpoint.y],"powers":GameManager.acquired_powers}

func apply_snapshot(data: Dictionary) -> void:
	if GameManager.scene_transition_pending or NetSession.local_index<0 or NetSession.local_index>=game.players.size() or data.get("actors",[]).size()!=game.players.size(): return
	if int(data.get("frame",0)) <= _frame:
		return
	_frame = int(data["frame"])
	_snapshot_age = 0.0
	_play_events(data.get("events",[]))
	var director: Node2D = game.world.get_node_or_null("CoopDirector")
	if director:
		director.rescue = data.get("rescue",[0,0,0,0])
		director.queue_redraw()
	for i in mini(scenery.size(),data.get("scenery",[]).size()):
		var item: Dictionary = data["scenery"][i]
		scenery[i].position = Vector2(item["x"],item["y"])
		scenery[i].visible = item["visible"]
		if scenery[i].get_script()==preload("res://scripts/world/crumble_platform.gd"):
			scenery[i]._sprite.modulate.a = 0.0 if int(item.get("crumble",0))==2 else 1.0
			scenery[i]._shape.set_deferred("disabled",int(item.get("crumble",0))==2)
		elif scenery[i] is MovingPlatform:
			scenery[i]._tile_art.visible = scenery[i].skin==""
			scenery[i].queue_redraw()
	for feature in features:
		feature.clock = float(data["time"])
		feature.queue_redraw()
	if not data.get("horde",{}).is_empty() and game.level.has_method("apply_horde_snapshot"):
		game.level.apply_horde_snapshot(data["horde"])
	_actor_targets.clear()
	for i in mini(game.players.size(),data["actors"].size()):
		var p: Player = game.players[i]
		var actor: Dictionary = data["actors"][i]
		var position_target := Vector2(actor["p"][0],actor["p"][1])
		if i==NetSession.local_index:
			p.reconcile(position_target,Vector2(actor["v"][0],actor["v"][1]),int(actor.get("ack",0)),bool(actor["alive"]))
			var echo := int(actor.get("echo",0))
			if echo>NetSession._last_echo:
				NetSession._last_echo = echo
				NetSession.ping_ms = maxi(0,Time.get_ticks_msec()-echo)
		elif p.position.distance_to(position_target)>90:
			p.position = position_target
		_actor_targets.append(position_target)
		if i!=NetSession.local_index: p.velocity = Vector2(actor["v"][0],actor["v"][1])
		p.aim = Vector2(actor["a"][0],actor["a"][1])
		p.facing = int(actor["f"])
		p.alive = actor["alive"]
		p.network_active = actor.get("connected",true)
		p.visible = p.network_active
		p.net_on_floor = actor["floor"]
		p.weapon = actor["weapon"]
		p._invuln = float(actor["hurt"])
		if i!=NetSession.local_index: p._dash_time = float(actor.get("dash",0))
		p.landing_squash = float(actor.get("landing",0))
		p._charge_t = float(actor.get("charge",0))
		p._charging = p._charge_t>0
		p._shoot_cooldown = float(actor.get("shot",0))
		p._shot_flash = float(actor.get("flash",0))
		var upgrades: Array = actor.get("upgrades",[0,0,0])
		p.damage_level = int(upgrades[0])
		p.armor_level = int(upgrades[1])
		p.fire_level = int(upgrades[2])
		p.bonus_mobility = actor.get("mobility",[])
		p.jet_active = actor.get("jet",false)
		p.jet_fuel = float(actor.get("fuel",1))
		if GameManager.p_health[i] != int(data["hp"][i]):
			GameManager.set_player_health(i,int(data["hp"][i]))
	var seen := {}
	for item in data["entities"]:
		var id: String = item["id"]
		seen[id] = true
		if not proxies.has(id):
			var proxy: Node2D
			if item["type"] == "enemy":
				if item["boss"]:
					proxy = BOSS_ART.new()
					proxy.design = item.get("design",GameManager.selected_boss)
					proxy.color = GameManager.BOSSES[proxy.design]["color"]
				else:
					proxy = REGION.new()
					proxy.zone = item.get("zone",GameManager.theme_id)
					proxy.airborne = item.get("air",false)
					proxy.small = item.get("small",false)
				proxy.set_meta("replica",true)
			elif item["type"]=="boss_hazard":
				proxy = BOSS_HAZARD.new()
				proxy.kind = item["kind"]
				proxy.replica = true
				proxy.color = Color.html(item["color"])
				proxy.size = Vector2(item["size"][0],item["size"][1])
			elif item["type"] == "pickup":
				proxy = PICKUP.create(item["kind"],Vector2.ZERO)
			else:
				proxy = Sprite2D.new()
				var path: String = item.get("texture","")
				# Whitelist shipped projectile textures; never load arbitrary resources.
				if not path.begins_with("res://assets/sprites/fx/bullet_") or not path.ends_with(".png"):
					path = "res://assets/sprites/fx/bullet_player.png" if item["player"] else "res://assets/sprites/fx/bullet_enemy.png"
				proxy.texture = load(path)
				proxy.scale = Vector2.ONE*float(item.get("scale",1))
				proxy.set_meta("effect",item.get("effect",""))
				proxy.material = FX.additive()
			game.world.add_child(proxy)
			proxy.set_physics_process(false)
			if item["type"]=="enemy": FX.ring(game.world,Vector2(item["p"][0],item["p"][1]),Color("68deff"),20,4,0.25)
			if proxy is CollisionObject2D:
				proxy.collision_layer = 0
				proxy.collision_mask = 0
			proxies[id] = proxy
		var proxy: Node2D = proxies[id]
		var position_target := Vector2(item["p"][0],item["p"][1])
		if item["type"]=="enemy" and item["boss"]: position_target.y -= 16
		if not _entity_targets.has(id) or proxy.position.distance_to(position_target)>90:
			proxy.position = position_target
		_entity_targets[id] = position_target
		var speed: Array = item.get("v",[0,0])
		_entity_velocities[id] = Vector2(speed[0],speed[1])
		if item["type"] == "enemy":
			if item["boss"]:
				proxy.rage = item["rage"]
				proxy.shielded = item.get("shielded",false)
				proxy.action = item["action"]
				proxy.phase = item["phase"]
				proxy.motion = float(item.get("motion",0))
				proxy.motion_state = item.get("rig_state","idle")
				proxy.t = float(item.get("clock",0))
				proxy.scale.x = -1 if int(item["f"])<0 else 1
			else:
				proxy.health = int(item["hp"])
				proxy.max_health = int(item["max"])
				proxy.facing = int(item["f"])
				proxy._time = float(item.get("clock",0))
				proxy._tell = float(item.get("tell",0))
				proxy.queue_redraw()
		elif item["type"]=="boss_hazard":
			proxy.age = float(item["age"])
			proxy.velocity = Vector2(item.get("v",[0,0])[0],item.get("v",[0,0])[1])
			proxy.warn = float(item["warn"])
			proxy.duration = float(item["duration"])
			proxy.health = int(item["health"])
		elif item["type"] == "bullet":
			proxy.modulate = Color.html(item["color"])
			if item.get("effect","")!="sierra": proxy.rotation = Vector2(item["v"][0],item["v"][1]).angle()
	for id in proxies.keys():
		if not seen.has(id):
			proxies[id].queue_free()
			proxies.erase(id)
			_entity_targets.erase(id)
			_entity_velocities.erase(id)
	for i in mini(game.level.puzzles.size(),data["puzzles"].size()):
		var puzzle: Node2D = game.level.puzzles[i]
		var remote: Dictionary = data["puzzles"][i]
		puzzle.values = remote["values"]
		puzzle.step = int(remote["step"])
		puzzle.clock = float(remote["clock"])
		puzzle.progress = float(remote["progress"])
		if puzzle.has_method("apply_expedition_state"):
			puzzle.apply_expedition_state(remote.get("expedition",{}))
		if remote["solved"]:
			puzzle.solved = true
			if is_instance_valid(puzzle.door): puzzle.door.queue_free()
		puzzle.queue_redraw()
		for terminal in puzzle.terminals:
			terminal.lit = not puzzle.solved
			terminal.queue_redraw()
	for i in mini(game.level.stations.size(),data["stations"].size()):
		var station: Node2D = game.level.stations[i]
		var remote: Dictionary = data["stations"][i]
		station.progress = float(remote["progress"])
		station.wave = int(remote["wave"])
		station.plate_owner = int(remote["owner"])
		if remote["solved"]:
			station.solved = true
			if is_instance_valid(station.gate): station.gate.queue_free()
		station.queue_redraw()
		for child in station.get_children():
			if child.has_method("status_label"):
				child.lit = not station.solved
				child.queue_redraw()
	if GameManager.score != int(data["score"]):
		GameManager.score = int(data["score"])
		GameManager.score_changed.emit(GameManager.score)
	GameManager.kills = int(data["kills"])
	GameManager.play_time = float(data["time"])
	GameManager.team_energy = float(data["energy"])
	GameManager.team_retries = int(data["retries"])
	for power in data["powers"]:
		if not GameManager.acquired_powers.has(power): GameManager.toast("PODER OBTENIDO: "+GameManager.weapon_name(power)+" / Q",GameManager.BOSSES[power]["color"])
	GameManager.acquired_powers.assign(data["powers"])
	for power in GameManager.acquired_powers: GameManager.unlocked[power] = true
	GameManager.current_weapon = game.players[NetSession.local_index].weapon
	GameManager.weapon_changed.emit(GameManager.current_weapon)
	game.level._boss_down = data["boss_down"]
	game.level.goal.visible = data["boss_down"]
	if data["arena"] and not game.level._arena_locked:
		game.level._arena_locked = true
		game._on_arena_locked(Rect2(game.level.arena_x,-40,400,236))
	if int(data["boss_hp"])>0:
		var boss_id: String = data.get("boss_id",GameManager.selected_boss)
		GameManager.boss_activated.emit(boss_id,GameManager.BOSSES[boss_id]["name"])
	GameManager.boss_health_changed.emit(int(data["boss_hp"]),int(data["boss_max"]),(int(data["boss_hp"])>0 if GameManager.horde_mode else data["arena"] and not data["boss_down"]))
	var next_state := int(data["state"])
	if next_state == GameManager.State.WIN and GameManager.state != GameManager.State.WIN:
		GameManager.coop_cleared[GameManager.selected_boss] = true
		GameManager.save_campaign()
	GameManager.state = next_state
	if GameManager.state == GameManager.State.TITLE:
		game.get_node("UI").get_child(2)._tab = 4
	get_tree().paused = GameManager.state != GameManager.State.PLAYING
