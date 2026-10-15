extends "res://scripts/world/stage.gd"
var floor_number := 1
var lift_progress := 0.0
var cabin_players: Array = []
var floor_decks: Array = []
var floor_details: Array = []
const FLOOR_LAYOUTS := [
	[[72,110],[190,70],[296,110],[408,30],[584,110],[692,70],[812,110]],
	[[44,110],[148,70],[256,30],[408,30],[602,70],[714,30],[844,110]],
	[[80,110],[208,110],[304,70],[408,30],[584,70],[708,110],[830,110]],
	[[56,70],[176,110],[286,70],[408,30],[590,70],[710,110],[830,70]],
	[[64,110],[184,70],[288,30],[408,30],[592,30],[712,70],[832,110]],
	[[40,110],[156,70],[276,110],[408,30],[604,110],[720,70],[848,110]],
	[[64,110],[188,70],[284,70],[408,30],[590,70],[706,70],[828,110]],
	[[56,110],[170,70],[278,30],[408,30],[594,30],[708,70],[832,110]]
]
var stations: Array = []
var bonus_progress := 0.0
var bonus_done := false
var bonus_owners := [-1,-1]
var remote_alive := 0
var wave := 0
var phase := "preparing"
var phase_time := 8.0
var remaining := 0
var spawn_clock := 0.0
var wallets := [0,0,0,0]
var ready_players: Array = []
var wave_bosses: Array = []
var last_kills := 0
var boss_pending := false
var bosses_defeated := 0
var final_boss_active := false
const SHOP := {
	"damage":{"name":"POTENCIA +20%","cost":90},
	"armor":{"name":"BLINDAJE +1","cost":110},
	"fire":{"name":"CADENCIA +15%","cost":100},
	"heal":{"name":"REPARAR +14","cost":40},
	"double_jump":{"name":"DOBLE SALTO","cost":180},
	"jetpack":{"name":"JETPACK","cost":300},
	"triple_jump":{"name":"TRIPLE SALTO [ONLINE]","cost":360},
	"phase_dash":{"name":"DASH FASE [ONLINE]","cost":330},
	"aero_boost":{"name":"AERO BOOST [ONLINE]","cost":320},
	"combat_regen":{"name":"NANORREPARACION [ONLINE]","cost":350},
	"overclock":{"name":"OVERCLOCK [ONLINE]","cost":370},
	"online_arc":{"name":"ARCO TESLA [ONLINE]","cost":540},
	"online_lance":{"name":"LANZA FOTONICA [ONLINE]","cost":620},
	"online_swarm":{"name":"ENJAMBRE X4 [ONLINE]","cost":690},
	"online_nova":{"name":"NOVA CIRCULAR [ONLINE]","cost":650},
	"online_saw":{"name":"DOBLE SIERRA [ONLINE]","cost":670},
	"online_void":{"name":"LANZA VACIO [ONLINE]","cost":820},
}

func _init() -> void:
	player_spawn = Vector2(426,150)
	camera_rect = Rect2(0,-270,960,466)

func build(players: Array) -> void:
	_players = players
	theme_id = GameManager.theme_id
	theme = Themes.get_theme(theme_id)
	_checkpoint = player_spawn
	arena_x = 0
	_cursor = 960
	GameManager.level_length = 960
	GameManager.checkpoints = []
	_ground(0,960)
	for at in FLOOR_LAYOUTS[0]:
		var deck := preload("res://scripts/world/architectural_deck.gd").new()
		deck.position = Vector2(at[0],at[1])
		deck.size = Vector2(144 if int(at[0])==408 else 72,16)
		add_child(deck)
		floor_decks.append(deck)
	var interior := preload("res://scripts/world/tower_interior.gd").new()
	interior.stage = self
	add_child(interior)
	var doors := preload("res://scripts/world/tower_doors.gd").new()
	doors.stage = self
	add_child(doors)
	for side in [0,600]:
		var detail := preload("res://scripts/world/scene_landmarks.gd").new()
		detail.span = 360
		detail.position.x = side
		add_child(detail)
		detail.z_index = -2
		floor_details.append(detail)
	configure_floor(1)
	_arena_wall(-16)
	_arena_wall(960)
	goal = GoalScript.create(Vector2(940,150))
	goal.visible = false
	goal.monitoring = false
	add_child(goal)
	for i in players.size(): wallets[i] = 120
	set_process(true)


func _arena_wall(x: float) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector2(x+8,-100)
	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16,800)
	collision.shape = rect
	wall.add_child(collision)
	add_child(wall)

func living_count() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.dead: count += 1
	return count

func wave_budget(count: int,wave_number: int) -> int:
	# Escalado por jugadores: con menos pilotos aparecen MUCHOS menos enemigos,
	# no solo enemigos con menos vida. El techo evita oleadas absurdas en piso 40.
	var base := 8 + mini(wave_number,20)*2 + maxi(0,wave_number-20)
	var scale: float = float([0.45,0.65,0.82,1.0][clampi(count,1,4)-1])
	return maxi(4,roundi(float(base)*float(scale)))

func is_boss_floor(number: int) -> bool:
	return number>=5 and number<=40 and number%5==0

func start_wave() -> void:
	wave += 1
	GameManager.run_wave = wave
	phase = "combat"
	spawn_clock = 0
	ready_players.clear()
	bonus_progress = 0
	bonus_done = false
	bonus_owners = [-1,-1]
	boss_pending = false
	if floor_number==41:
		remaining = 0
		final_boss_active = true
		GameManager.banner("PISO FINAL","NUCLEO OMEGA / JEFE EXCLUSIVO ONLINE",GameManager.BOSSES["nucleo"]["color"])
		_spawn_progression_boss("nucleo",true)
	elif is_boss_floor(floor_number):
		remaining = 0
		var boss_index := clampi(int(floor_number/5)-1,0,7)
		var boss_id: String = GameManager.BOSS_ORDER[boss_index]
		GameManager.banner("PISO %d / JEFE %d DE 8" % [floor_number,boss_index+1],GameManager.BOSSES[boss_id]["name"],GameManager.BOSSES[boss_id]["color"])
		_spawn_progression_boss(boss_id,false)
	else:
		remaining = wave_budget(participating().size(),wave)
		GameManager.banner("PISO %d / OLEADA %d" % [floor_number,wave],"%d ENEMIGOS / %d PILOTOS" % [remaining,participating().size()],theme["accent"])

func _physics_process(delta: float) -> void:
	if not NetSession.is_authority() or GameManager.state!=GameManager.State.PLAYING: return
	for p in participating():
		if p.alive and p.global_position.y>220: p.fall_death()
	if phase not in ["departing","transit"]:
		cabin_players = participating().filter(func(p): return in_cabin(p)).map(func(p): return p.index)
	if phase=="departing" or phase=="transit":
		_update_lift(delta)
		return
	if phase=="preparing":
		phase_time -= delta
		if phase_time<=0 or ready_players.size()==participating().size(): start_wave()
		return
	if phase=="shop":
		_update_boarding(delta)
		return
	_update_bonus(delta)
	if GameManager.kills>last_kills:
		var reward := (GameManager.kills-last_kills)*4
		for i in _players.size(): wallets[i] += reward
		last_kills = GameManager.kills
	spawn_clock -= delta
	var party_count := participating().size()
	if remaining>0 and spawn_clock<=0 and living_count()<8+party_count*6:
		spawn_clock = maxf(0.22,0.72-wave*0.012)
		for i in mini(remaining,maxi(1,party_count)):
			_spawn_horde_enemy()
			remaining -= 1
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.global_position.y>240 and not enemy.dead: enemy.take_damage(100000,enemy.global_position)
	if GameManager.state!=GameManager.State.PLAYING: return
	if remaining==0 and not boss_pending and living_count()==0:
		finish_wave()

func _update_bonus(delta: float) -> void:
	if wave%2!=0 or bonus_done or is_boss_floor(floor_number) or floor_number==41: return
	bonus_owners = [-1,-1]
	for p in participating():
		if not p.alive: continue
		for i in 2:
			if Rect2(180+i*560,115,60,40).has_point(p.position): bonus_owners[i] = p.index
	var held: bool = bonus_owners[0]>=0 or bonus_owners[1]>=0
	if participating().size()>1: held = bonus_owners[0]>=0 and bonus_owners[1]>=0 and bonus_owners[0]!=bonus_owners[1]
	bonus_progress = clampf(bonus_progress+delta*(1 if held else -0.4),0,6)
	if bonus_progress>=6:
		bonus_done = true
		for i in _players.size(): wallets[i] += 80
		GameManager.team_energy = minf(100,GameManager.team_energy+25)
		GameManager.toast("ENLACE COMPLETADO / +80 CREDITOS",Color("63ffc3"))
	queue_redraw()

func _draw() -> void:
	if wave%2!=0 or wave==0 or bonus_done or phase!="combat" or is_boss_floor(floor_number) or floor_number==41: return
	for i in 2:
		var at := Vector2(210+i*560,149)
		var color := Color("63ffc3") if bonus_owners[i]>=0 else Color("ffd45a")
		draw_arc(at,26,PI,TAU,24,Color(color,0.4),2)
		draw_arc(at,26,PI,PI+PI*bonus_progress/6,24,color,3)
		draw_rect(Rect2(at+Vector2(-24,0),Vector2(48,3)),color)

func _spawn_horde_enemy() -> void:
	var enemy := preload("res://scripts/enemies/zone_enemy.gd").new()
	enemy.zone = theme_id if remaining%4!=0 else GameManager.BOSSES[GameManager.BOSS_ORDER[(wave+remaining)%8]]["theme"]
	enemy.airborne = remaining%3==0
	enemy.position = Vector2(40 if remaining%2==0 else 920,-80 if enemy.airborne else 150)
	add_child(enemy)
	enemy.max_health = roundi(enemy.max_health*(1+mini(wave,30)*0.055+(participating().size()-1)*0.22))
	enemy.health = enemy.max_health
	if wave>=4 and remaining%11==0: enemy.make_elite("CAPITAN",1.6,1.8)
	preload("res://scripts/fx/fx.gd").ring(self,enemy.position+Vector2(0,-12),theme["accent"],22,4,0.3)

# Compatibilidad con pruebas/herramientas antiguas que invocaban el jefe de
# oleada directamente. La progresion real de la torre usa pisos 5/10/.../40.
func _spawn_wave_boss() -> void:
	var old_index := maxi(0,floori(float(maxi(wave,1))/3.0)-1)%8
	_spawn_progression_boss(GameManager.BOSS_ORDER[old_index],false)

func _spawn_progression_boss(id: String,is_final: bool) -> void:
	var chief := BossScript.new()
	chief.boss_id = id
	chief.position = Vector2(740,148 if GameManager.BOSSES[id]["mode"]=="ground" else 40)
	add_child(chief)
	var party_scale := 1.0+(participating().size()-1)*0.48
	var progression := 1.0+float(floor_number-1)*0.018
	if is_final:
		progression *= 1.35
	chief.max_health = roundi(chief.max_health*party_scale*progression)
	chief.health = chief.max_health
	chief.defeated.connect(func():
		for i in _players.size(): wallets[i] += 300 if is_final else 140
		if is_final:
			final_boss_active = false
			GameManager.add_score(15000)
			GameManager.banner("TORRE COMPLETADA","LOS 8 JEFES + NUCLEO OMEGA DESTRUIDOS",Color("ff73df"))
			GameManager.trigger_win()
		else:
			bosses_defeated = maxi(bosses_defeated,clampi(int(floor_number/5),1,8))
			GameManager.acquire_boss_power(id)
			_grant_online_reward(bosses_defeated)
	)
	chief.activate()
	boss = chief
	wave_bosses.append(chief)

func _grant_online_reward(index: int) -> void:
	var rewards := ["online_arc","online_lance","online_swarm","online_nova","online_saw","online_void","phase_dash","triple_jump"]
	if index<1 or index>rewards.size(): return
	var id: String = rewards[index-1]
	if GameManager.ONLINE_WEAPONS.has(id):
		if not bool(GameManager.unlocked.get(id,false)):
			GameManager.unlocked[id] = true
			GameManager.toast("ARSENAL ONLINE: "+GameManager.weapon_name(id)+" / Q",GameManager.ONLINE_WEAPONS[id]["color"])
	else:
		for p in participating():
			if not p.bonus_mobility.has(id): p.bonus_mobility.append(id)
		GameManager.toast("HABILIDAD ONLINE: "+GameManager.ONLINE_MOBILITY.get(id,id.to_upper()),Color("63ffc3"))

func finish_wave() -> void:
	phase = "shop"
	phase_time = 30
	ready_players.clear()
	GameManager.record_progress("",wave)
	get_tree().call_group("enemy_bullet","queue_free")
	for p in participating():
		wallets[p.index] += 70+wave*10
		if not p.alive: p.respawn_at(player_spawn+Vector2(p.index*24,0))
		GameManager.heal_player(p.index,6)
	GameManager.banner("PISO DESPEJADO","B MEJORAS / ENTREN AL ASCENSOR Y PULSEN E",Color("63ffc3"))

func price(index: int,id: String) -> int:
	if not SHOP.has(id) or index<0 or index>=_players.size(): return -1
	var p: Player = _players[index]
	var level: int = p.damage_level if id=="damage" else (p.armor_level if id=="armor" else (p.fire_level if id=="fire" else 0))
	return int(SHOP[id]["cost"])+level*60

func buy_upgrade(index: int,id: String) -> bool:
	if not NetSession.is_authority() or phase not in ["preparing","shop"] or not SHOP.has(id) or index<0 or index>=_players.size(): return false
	if not _players[index].network_active: return false
	var cost := price(index,id)
	var p: Player = _players[index]
	if wallets[index]<cost: return false
	if GameManager.ONLINE_WEAPONS.has(id) and bool(GameManager.unlocked.get(id,false)): return false
	if id in ["double_jump","jetpack","triple_jump","phase_dash","aero_boost","combat_regen","overclock"] and p.has_mobility(id): return false
	if id=="damage" and p.damage_level>=5: return false
	if id=="armor" and p.armor_level>=5: return false
	if id=="fire" and p.fire_level>=5: return false
	if id=="heal" and GameManager.p_health[index]>=GameManager.MAX_HEALTH: return false
	wallets[index] -= cost
	match id:
		"damage": p.damage_level += 1
		"armor": p.armor_level += 1
		"fire": p.fire_level += 1
		"heal": GameManager.heal_player(index,14)
		_:
			if GameManager.ONLINE_WEAPONS.has(id):
				GameManager.unlocked[id] = true
				p.equip_power(id)
				GameManager.toast("NUEVA ARMA ONLINE: "+GameManager.weapon_name(id),GameManager.ONLINE_WEAPONS[id]["color"])
			else:
				p.bonus_mobility.append(id)
				GameManager.toast("HABILIDAD ONLINE: "+GameManager.ONLINE_MOBILITY.get(id,id.to_upper()),Color("63ffc3"))
	return true

func mark_ready(index: int) -> void:
	if phase not in ["preparing","shop"]: return
	if index<0 or index>=_players.size() or not _players[index].network_active: return
	if phase=="shop" and not in_cabin(_players[index]):
		GameManager.toast("ENTRA EN LA CABINA CENTRAL PARA SUBIR",Color("ffd45a"))
		return
	if not ready_players.has(index): ready_players.append(index)

func horde_snapshot() -> Dictionary:
	var online_unlocked: Array = []
	for id in GameManager.ONLINE_WEAPONS:
		if bool(GameManager.unlocked.get(id,false)): online_unlocked.append(id)
	return {"floor":floor_number,"lift":lift_progress,"cabin":cabin_players,"bonus":bonus_progress,"bonus_done":bonus_done,"owners":bonus_owners,"wave":wave,"phase":phase,"timer":phase_time,"remaining":remaining,"alive":living_count(),"wallets":wallets,"ready":ready_players,"best":GameManager.best_wave,"bosses":GameManager.profile_bosses,"mobility":GameManager.mobility,"tower_bosses":bosses_defeated,"final":final_boss_active,"online_weapons":online_unlocked}

func apply_horde_snapshot(data: Dictionary) -> void:
	var previous_phase := phase
	var previous_wave := wave
	var target_floor := int(data.get("floor",1))
	if floor_number!=target_floor: configure_floor(target_floor)
	lift_progress = float(data.get("lift",0))
	cabin_players = data.get("cabin",[]).map(func(i): return int(i))
	bonus_progress = float(data.get("bonus",0))
	bonus_done = data.get("bonus_done",false)
	bonus_owners = data.get("owners",[-1,-1])
	queue_redraw()
	wave = int(data["wave"])
	GameManager.run_wave = wave
	remote_alive = int(data.get("alive",0))
	phase = data["phase"]
	phase_time = float(data["timer"])
	remaining = int(data["remaining"])
	wallets = data["wallets"]
	ready_players = data["ready"]
	bosses_defeated = int(data.get("tower_bosses",bosses_defeated))
	final_boss_active = bool(data.get("final",final_boss_active))
	for weapon_id in data.get("online_weapons",[]): GameManager.unlocked[str(weapon_id)] = true
	GameManager.best_wave = maxi(GameManager.best_wave,int(data.get("best",0)))
	for id in data.get("bosses",[]):
		if not GameManager.profile_bosses.has(id): GameManager.profile_bosses.append(id)
	for id in data.get("mobility",[]):
		if not GameManager.mobility.has(id): GameManager.mobility.append(id)

	if previous_wave!=wave: GameManager.banner("PISO %d / OLEADA %d" % [floor_number,wave],"%d PILOTOS / DESPEJEN EL EDIFICIO" % participating().size(),theme["accent"])
	if previous_phase != phase:
		GameManager.save_campaign()
		if phase=="shop": GameManager.banner("PISO DESPEJADO","B MEJORAS / ENTREN AL ASCENSOR Y PULSEN E",Color("63ffc3"))
		elif phase=="departing": GameManager.banner("ASCENSOR / PISO %d" % (floor_number+1),"%d PILOTOS A BORDO / 4 PUESTOS" % participating().size(),Color("63ffc3"))

func in_cabin(p: Player) -> bool:
	return p.alive and Rect2(410,86,140,68).has_point(p.position) and absf(p.position.y-150)<10

func configure_floor(number: int) -> void:
	floor_number = number
	var layout_index := (number-1)%8
	if number==41:
		theme_id = "central"
	elif is_boss_floor(number):
		var progression_index := clampi(int(number/5)-1,0,7)
		theme_id = GameManager.BOSSES[GameManager.BOSS_ORDER[progression_index]]["theme"]
	else:
		var boss_index := (GameManager.BOSS_ORDER.find(GameManager.selected_boss)+layout_index)%8
		theme_id = GameManager.BOSSES[GameManager.BOSS_ORDER[boss_index]]["theme"]
	theme = Themes.get_theme(theme_id)
	GameManager.theme_id = theme_id
	for detail in floor_details:
		detail.zone = theme_id
		detail.act = layout_index
	for i in floor_decks.size():
		var at: Array = FLOOR_LAYOUTS[layout_index][i]
		floor_decks[i].position = Vector2(at[0],at[1])
		floor_decks[i].zone = theme_id
		floor_decks[i].accent = theme["accent"]
		floor_decks[i].queue_redraw()

func _update_boarding(delta: float) -> void:
	phase_time = maxf(0,phase_time-delta)
	cabin_players.clear()
	for p in participating():
		if in_cabin(p):
			cabin_players.append(p.index)
			if p.pressed_once("interact"): mark_ready(p.index)
		else: ready_players.erase(p.index)
	if cabin_players.size()==participating().size() and (ready_players.size()==participating().size() or phase_time<=0):
		begin_ascent()

func begin_ascent() -> bool:
	if phase!="shop" or _players.is_empty(): return false
	for p in participating():
		if not in_cabin(p): return false
	phase = "departing"
	phase_time = 1.0
	lift_progress = 0
	cabin_players.clear()
	for p in participating():
		cabin_players.append(p.index)
		p._end_charge()
		p.velocity = Vector2.ZERO
		p.position = Vector2(426+p.index*36,150)
		p.set_physics_process(false)
	GameManager.banner("ASCENSOR / PISO %d" % (floor_number+1),"%d PILOTOS A BORDO / 4 PUESTOS" % participating().size(),Color("63ffc3"))
	return true

func _update_lift(delta: float) -> void:
	phase_time -= delta
	if phase=="departing":
		if phase_time<=0:
			phase = "transit"
			phase_time = 4.0
		return
	lift_progress = clampf(1-phase_time/4.0,0,1)
	if phase_time>0: return
	configure_floor(floor_number+1)
	for p in participating():
		p.position = Vector2(426+p.index*36,150)
		p.velocity = Vector2.ZERO
		p._invuln = 2
		p.set_physics_process(true)
	lift_progress = 0
	start_wave()

func participating() -> Array:
	return _players.filter(func(p): return p.network_active)

func disconnect_pilot(index: int) -> void:
	if index<0 or index>=_players.size(): return
	var old_count := maxi(1,participating().size())
	var p: Player = _players[index]
	p.network_active = false
	p.alive = false
	p.visible = false
	p.set_physics_process(false)
	ready_players.erase(index)
	cabin_players.erase(index)
	var new_count := maxi(1,participating().size())
	# Si alguien sale a mitad de una oleada normal, no obligamos al resto a
	# completar el presupuesto pensado para un equipo mas grande.
	if phase=="combat" and remaining>0 and not is_boss_floor(floor_number) and floor_number!=41:
		remaining = maxi(0,roundi(float(remaining)*float(new_count)/float(old_count)))
	GameManager.toast("P%d SALIO / CONTINUAN %d PILOTOS" % [index+1,participating().size()],Color("ffd45a"))
