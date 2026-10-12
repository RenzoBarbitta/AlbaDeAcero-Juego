extends "res://scripts/world/zone_puzzle.gd"
## Spatial objectives: navigation, transport, timing and pursuit, rather than three valve rooms.
const RULES := {
	"fundicion":["coolant","furnace_hold"],"ruinas":["glyph_route","counterweight"],
	"glaciar":["ice_race","warmth"],"volcan":["vent_route","hot_cargo"],
	"central":["frequency","capacitors"],"cantera":["ore_cargo","collapse_race"],
	"ciudad":["stealth","courier"],"biolab":["samples","antidote"]
}
const HELP := {
	"coolant":"RECUPERA LOS TRES NUCLEOS SOLO DURANTE EL CICLO FRIO",
	"furnace_hold":"ENFRIA LAS CAMARAS 1 Y 4: PERMANECE DOS SEGUNDOS EN CADA UNA",
	"glyph_route":"RECORRE LOS GLIFOS 1 - 3 - 2 - 4; EL ERROR REINICIA LA RUTA",
	"counterweight":"LLEVA DOS PESOS DEL NIDO 1 A LOS CONTRAPESOS 4 Y 5",
	"ice_race":"PISA 1 - 2 - 3 - 4 - 5 - 6 ANTES DE QUE TERMINE EL DESHIELO",
	"warmth":"SIGUE EL NUCLEO TERMICO; SOLO AVANZA SI TE MANTENES CERCA",
	"vent_route":"SELLA 2 Y 5 EN FRIO, Y EL RESPIRADERO 4 DURANTE EL CALOR",
	"hot_cargo":"LLEVA EL REFRIGERANTE DE 1 A 4; DESCANSA EN 2 O 5 PARA ENFRIARLO",
	"frequency":"DISPARA A LOS EMISORES 2 - 4 - 5 CUANDO SU ANILLO ESTE ABIERTO",
	"capacitors":"CARGA 1 Y 4 SIN DISPARAR; LOS DISPAROS DESCARGAN EL ACUMULADOR",
	"ore_cargo":"TRANSPORTA TRES MINERALES DE 1 A 4; CADA VIAJE DEBE TERMINAR",
	"collapse_race":"MARCA 1 - 3 - 4 - 5 - 6 EN 22 SEGUNDOS, O VUELVE AL INICIO",
	"stealth":"INFILTRA 2 - 4 - 5 SOLO CUANDO EL RADAR ESTE APAGADO",
	"courier":"ALCANZA EL DRON Y SIGUE SU RUTA HASTA COMPLETAR LA DESCARGA",
	"samples":"RECOGE LAS MUESTRAS VERDES 2 - 4 - 6; LAS ROJAS CONTAMINAN",
	"antidote":"LLEVA LA MUESTRA DE 1 A 4 SIN RECIBIR DANO"
}
var rule := "coolant"
var nodes := [Vector2(220,30),Vector2(350,-90),Vector2(170,-210),Vector2(430,-290),Vector2(630,-170),Vector2(760,30)]
var _contacts: Array = []
var _cargo_health := 0
var _carrier := -1
var _elapsed := 0.0
var escort_carrier: MovingPlatform

func _ready() -> void:
	add_to_group("zone_puzzle")
	rule = RULES[zone][chapter-1]
	values = [0,0,0,0,0,0]
	match rule:
		"glyph_route": sequence = [0,2,1,3]
		"ice_race": sequence = [0,1,2,3,4,5]
		"collapse_race": sequence = [0,2,3,4,5]
		"frequency","stealth": sequence = [1,3,4]
		"samples": sequence = [1,3,5]
	door = StaticBody2D.new()
	door.position = Vector2(972,-700)
	door.collision_layer = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12,896)
	cs.shape = shape
	cs.position = shape.size*0.5
	door.add_child(cs)
	add_child(door)
	if rule == "frequency":
		for i in sequence:
			var terminal := preload("res://scripts/world/puzzle_terminal.gd").new()
			terminal.puzzle = self
			terminal.terminal_index = i
			terminal.position = nodes[i]-Vector2(0,18)
			add_child(terminal)
			terminals.append(terminal)

func control_position(i: int) -> Vector2:
	return nodes[i]

func hint_text() -> String:
	return HELP[rule]

func status_text() -> String:
	if solved: return "RUTA DESBLOQUEADA"
	if rule in ["warmth","courier"]: return "TRANSFERENCIA %d%% / SIGUE EL ANILLO" % int(progress*100)
	if rule in ["furnace_hold","capacitors"]: return "CARGA %d%% / COMPLETADAS %d/2" % [int(progress*100),int(values[0])+int(values[3])]
	if rule in ["counterweight","ore_cargo","hot_cargo","antidote"]:
		return "ENTREGAS %d / %s" % [step,"CARGA EN MANO" if _carrier>=0 or values[0]==2 else "RECOGE EN 1"]
	if not sequence.is_empty():
		return "RUTA "+value_label(sequence.map(func(n): return int(n)+1))+" / PASO %d / TIEMPO %d" % [step,maxi(0,22-int(_elapsed))]
	return "NODOS %d/3 / %s" % [step,"FRIO" if fposmod(clock,4)<2 else "CALIENTE"]

func activate(i: int) -> bool:
	if rule != "frequency" or solved: return false
	if int(values[i])==1: return false
	if fposmod(clock+float(i)*0.4,3.0)<1.2:
		GameManager.toast("EMISOR CERRADO: ESPERA EL ANILLO AZUL",Color("ffb15c"))
		return false
	return _ordered(i)

func terminal_label(i: int) -> String:
	if solved or int(values[i])==1: return "OK"
	return "ESPERA" if fposmod(clock+float(i)*0.4,3.0)<1.2 else "E / DISPARA"

func node_used(i: int) -> bool:
	if rule in ["coolant","vent_route"]: return i in [1,3,4]
	if rule in ["furnace_hold","capacitors"]: return i in [0,3]
	if rule in ["ore_cargo","hot_cargo","antidote"]: return i in [0,3]
	if rule=="counterweight": return i in [0,3,4]
	if rule=="samples": return true
	if not sequence.is_empty(): return sequence.has(i)
	return false

func _ordered(i: int) -> bool:
	if step>=sequence.size(): return false
	if i!=int(sequence[step]):
		values.fill(0)
		step = 0
		_elapsed = 0
		GameManager.toast("RUTA REINICIADA",Color("ffb15c"))
		return false
	values[i] = 1
	step += 1
	AudioManager.play("select",-14)
	if step==sequence.size(): finish()
	return true

func _visit(i: int,p: Node2D) -> void:
	if rule in ["frequency","warmth","courier","furnace_hold","capacitors"]: return
	var cold := fposmod(clock,4)<2
	match rule:
		"coolant","vent_route":
			var valid := i in [1,3,4]
			var open := cold if rule=="coolant" or i!=3 else not cold
			if valid and open and int(values[i])==0:
				values[i] = 1
				step += 1
				AudioManager.play("select",-14)
				if step==3: finish()
		"glyph_route","ice_race","collapse_race","samples","stealth":
			if rule=="stealth" and not cold:
				GameManager.toast("RADAR ACTIVO: ESPERA EN COBERTURA",Color("ffb15c"))
				return
			_ordered(i)
		"counterweight","ore_cargo","hot_cargo","antidote":
			if i==0 and _carrier<0:
				_carrier = p.index
				_cargo_health = GameManager.p_health[p.index]
				values[0] = 2
				progress = 0
				GameManager.toast("CARGA RECOGIDA: LLEVALA ARRIBA",Color("63ffc3"))
			var destination := 3+step if rule=="counterweight" else 3
			if i==destination and _carrier==p.index:
				_carrier = -1
				values[0] = 0
				step += 1
				var deliveries := 2 if rule=="counterweight" else (3 if rule=="ore_cargo" else 1)
				if step==deliveries: finish()

func _physics_process(delta: float) -> void:
	clock += delta
	if solved: return
	if step>0 and rule in ["ice_race","collapse_race"]:
		_elapsed += delta
		if _elapsed>22:
			step = 0
			_elapsed = 0
			values.fill(0)
			GameManager.toast("TIEMPO AGOTADO: RETOMA LA RUTA",Color("ffb15c"))
	var now: Array = []
	var following := false
	for p in stage._players:
		if not p.alive: continue
		var local: Vector2 = p.global_position-global_position
		for i in nodes.size():
			if local.distance_to(nodes[i])<26:
				now.append(i)
				if not _contacts.has(i): _visit(i,p)
		if rule in ["warmth","courier"]:
			if local.distance_to(escort_position())<48: following = true
		if rule in ["furnace_hold","capacitors"]:
			for i in [0,3]:
				var open: bool = fposmod(clock,4)<2 if rule=="furnace_hold" else not p.pressed("shoot")
				if local.distance_to(nodes[i])<26 and open and int(values[i])==0:
					progress = minf(1,progress+delta/2)
					if progress>=1:
						values[i] = 1
						progress = 0
						if int(values[0])+int(values[3])==2: finish()
				elif rule=="capacitors" and p.pressed("shoot"): progress = 0
		if _carrier==p.index:
			if rule=="antidote" and GameManager.p_health[p.index]<_cargo_health:
				_drop_cargo()
			elif rule=="hot_cargo":
				var resting := local.distance_to(nodes[1])<30 or local.distance_to(nodes[4])<30
				progress = maxf(0,progress-delta/2) if resting else progress+delta/18
				if progress>=1: _drop_cargo()
	_contacts = now
	if rule in ["warmth","courier"] and following:
		progress = minf(1,progress+delta/18)
		if progress>=1: finish()
	if is_instance_valid(escort_carrier):
		escort_carrier.global_position = global_position+escort_position()-Vector2(38,8)
	queue_redraw()

func _drop_cargo() -> void:
	_carrier = -1
	values[0] = 0
	progress = 0
	GameManager.toast("CARGA PERDIDA: RECUPERALA EN 1",Color("ffb15c"))

func escort_position() -> Vector2:
	var path := [nodes[0],nodes[1],nodes[2],nodes[3],nodes[4],nodes[5]]
	var travel := minf(progress*5,4.999)
	var index := floori(travel)
	return path[index].lerp(path[index+1],fposmod(travel,1))

func expedition_state() -> Dictionary:
	return {"elapsed":_elapsed,"carrier":_carrier}

func apply_expedition_state(data: Dictionary) -> void:
	_elapsed = float(data.get("elapsed",0))
	_carrier = int(data.get("carrier",-1))

func _draw() -> void:
	var col: Color = stage.theme["accent"]
	for i in nodes.size():
		if not node_used(i): continue
		var at: Vector2 = nodes[i]-Vector2(0,14)
		var active := int(values[i])>0
		var c := Color("63ffc3") if active else col
		if rule=="samples" and i in [0,2,4]: c = Color("ff655c")
		if rule=="frequency" and fposmod(clock+float(i)*0.4,3)<1.2: c = Color("ff655c")
		draw_arc(at,12,0,TAU,24,c,2)
		draw_circle(at,3,c)
		PT.draw_box(self,str(i+1),Rect2(at+Vector2(-8,-28),Vector2(16,14)),c)
	if rule in ["warmth","courier"]:
		var at := escort_position()-Vector2(0,18)
		draw_arc(at,28,0,TAU,24,Color("63ffc3"),1)
		draw_colored_polygon(PackedVector2Array([at+Vector2(-8,0),at+Vector2(0,-8),at+Vector2(8,0),at+Vector2(0,8)]),Color("e1fff2"))
	if not solved: draw_rect(Rect2(972,-700,12,896),Color(col,0.4))
	if _carrier>=0 or values[0]==2:
		for p in stage._players:
			if p.index==_carrier or (NetSession.online and not NetSession.host and p.index==NetSession.local_index):
				draw_circle(p.global_position-global_position+Vector2(0,-42),5,Color("63ffc3"))
