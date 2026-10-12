extends "res://scripts/world/stage.gd"
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
const SHOP := {"damage":{"name":"POTENCIA +20%","cost":90},"armor":{"name":"BLINDAJE +1","cost":110},"fire":{"name":"CADENCIA +15%","cost":100},"heal":{"name":"REPARAR +14","cost":40},"double_jump":{"name":"DOBLE SALTO","cost":180},"jetpack":{"name":"JETPACK","cost":300}}

func _init() -> void:
	player_spawn = Vector2(400,150)
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
	preload("res://scripts/world/arena_layout.gd").build(self,0,960)
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
	return 20+wave_number*8+(count-1)*14

func start_wave() -> void:
	wave += 1
	GameManager.run_wave = wave
	phase = "combat"
	remaining = wave_budget(_players.size(),wave)
	spawn_clock = 0
	ready_players.clear()
	bonus_progress = 0
	bonus_done = false
	bonus_owners = [-1,-1]
	boss_pending = wave%3==0
	GameManager.banner("OLEADA %d" % wave,"%d ENEMIGOS / %d PILOTOS" % [remaining,_players.size()],theme["accent"])

func _physics_process(delta: float) -> void:
	if not NetSession.is_authority() or GameManager.state!=GameManager.State.PLAYING: return
	for p in _players:
		if p.alive and p.global_position.y>220: p.fall_death()
	if phase=="preparing" or phase=="shop":
		phase_time -= delta
		if phase_time<=0 or ready_players.size()==_players.size(): start_wave()
		return
	_update_bonus(delta)
	if GameManager.kills>last_kills:
		var reward := (GameManager.kills-last_kills)*4
		for i in _players.size(): wallets[i] += reward
		last_kills = GameManager.kills
	spawn_clock -= delta
	if remaining>0 and spawn_clock<=0 and living_count()<24+_players.size()*8:
		spawn_clock = maxf(0.2,0.7-wave*0.025)
		for i in mini(remaining,2+_players.size()):
			_spawn_horde_enemy()
			remaining -= 1
	if boss_pending and remaining< wave_budget(_players.size(),wave)/2.0:
		boss_pending = false
		_spawn_wave_boss()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.global_position.y>240 and not enemy.dead: enemy.take_damage(100000,enemy.global_position)
	if remaining==0 and not boss_pending and living_count()==0:
		finish_wave()

func _update_bonus(delta: float) -> void:
	if wave%2!=0 or bonus_done: return
	bonus_owners = [-1,-1]
	for p in _players:
		if not p.alive: continue
		for i in 2:
			if Rect2(180+i*560,115,60,40).has_point(p.position): bonus_owners[i] = p.index
	var held: bool = bonus_owners[0]>=0 or bonus_owners[1]>=0
	if _players.size()>1: held = bonus_owners[0]>=0 and bonus_owners[1]>=0 and bonus_owners[0]!=bonus_owners[1]
	bonus_progress = clampf(bonus_progress+delta*(1 if held else -0.4),0,6)
	if bonus_progress>=6:
		bonus_done = true
		for i in _players.size(): wallets[i] += 80
		GameManager.team_energy = minf(100,GameManager.team_energy+25)
		GameManager.toast("ENLACE COMPLETADO / +80 CREDITOS",Color("63ffc3"))
	queue_redraw()

func _draw() -> void:
	if wave%2!=0 or wave==0 or bonus_done or phase!="combat": return
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
	enemy.max_health = roundi(enemy.max_health*(1+wave*0.1+(_players.size()-1)*0.3))
	enemy.health = enemy.max_health
	if wave>=4 and remaining%11==0: enemy.make_elite("CAPITAN",1.6,1.8)
	preload("res://scripts/fx/fx.gd").ring(self,enemy.position+Vector2(0,-12),theme["accent"],22,4,0.3)

func _spawn_wave_boss() -> void:
	var id: String = GameManager.BOSS_ORDER[(floori(float(wave)/3)-1)%8]
	var chief := BossScript.new()
	chief.boss_id = id
	chief.position = Vector2(740,148 if GameManager.BOSSES[id]["mode"]=="ground" else 40)
	add_child(chief)
	chief.max_health = roundi(chief.max_health*(1+(_players.size()-1)*0.6+wave*0.08))
	chief.health = chief.max_health
	chief.defeated.connect(func():
		GameManager.acquire_boss_power(id)
		for i in _players.size(): wallets[i] += 100)
	chief.activate()
	boss = chief
	wave_bosses.append(chief)

func finish_wave() -> void:
	phase = "shop"
	phase_time = 30
	ready_players.clear()
	GameManager.record_progress("",wave)
	get_tree().call_group("enemy_bullet","queue_free")
	for p in _players:
		wallets[p.index] += 70+wave*10
		if not p.alive: p.respawn_at(player_spawn+Vector2(p.index*24,0))
		GameManager.heal_player(p.index,6)
	GameManager.banner("OLEADA SUPERADA","B ABRE MEJORAS / EQUIPO LISTO PARA CONTINUAR",Color("63ffc3"))

func price(index: int,id: String) -> int:
	if not SHOP.has(id) or index<0 or index>=_players.size(): return -1
	var p: Player = _players[index]
	var level: int = p.damage_level if id=="damage" else (p.armor_level if id=="armor" else (p.fire_level if id=="fire" else 0))
	return int(SHOP[id]["cost"])+level*60

func buy_upgrade(index: int,id: String) -> bool:
	if not NetSession.is_authority() or phase not in ["preparing","shop"] or not SHOP.has(id) or index<0 or index>=_players.size(): return false
	var cost := price(index,id)
	var p: Player = _players[index]
	if wallets[index]<cost: return false
	if id in ["double_jump","jetpack"] and p.has_mobility(id): return false
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
		_: p.bonus_mobility.append(id)
	return true

func mark_ready(index: int) -> void:
	if index>=0 and index<_players.size() and not ready_players.has(index): ready_players.append(index)

func horde_snapshot() -> Dictionary:
	return {"bonus":bonus_progress,"bonus_done":bonus_done,"owners":bonus_owners,"wave":wave,"phase":phase,"timer":phase_time,"remaining":remaining,"alive":living_count(),"wallets":wallets,"ready":ready_players,"best":GameManager.best_wave,"bosses":GameManager.profile_bosses,"mobility":GameManager.mobility}

func apply_horde_snapshot(data: Dictionary) -> void:
	var previous_phase := phase
	var previous_wave := wave
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
	GameManager.best_wave = maxi(GameManager.best_wave,int(data.get("best",0)))
	for id in data.get("bosses",[]):
		if not GameManager.profile_bosses.has(id): GameManager.profile_bosses.append(id)
	for id in data.get("mobility",[]):
		if not GameManager.mobility.has(id): GameManager.mobility.append(id)

	if previous_wave!=wave: GameManager.banner("OLEADA %d" % wave,"%d PILOTOS / DEFIENDAN LA ARENA" % _players.size(),theme["accent"])
	if previous_phase != phase:
		GameManager.save_campaign()
		if phase=="shop": GameManager.banner("OLEADA SUPERADA","B ABRE EL TALLER DE MEJORAS",Color("63ffc3"))
