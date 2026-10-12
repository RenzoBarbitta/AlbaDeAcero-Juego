extends Node2D
var zone := "fundicion"
var chapter := 0
var stage: Node2D
var solved := false
var values: Array = []
var target: Array = []
var sequence: Array = []
var step := 0
var progress := 0.0
var clock := 0.0
var door: StaticBody2D
var terminals: Array = []
var control_positions: Array = []
var _inside: Array = []
var _announced := false
const PT := preload("res://scripts/ui/pixel_text.gd")
const TITLES := {"fundicion":"PRESION DE LOS HORNOS","ruinas":"RUTA DE SUMINISTRO","glaciar":"MEMORIA DEL HIELO","volcan":"BALANCE DEL REFRIGERANTE","central":"CIRCUITO XOR","cantera":"PESO DE CONTRAPESOS","ciudad":"CODIGO DE SOMBRAS","biolab":"SINTESIS DEL ANTIDOTO"}
const HINTS := {"fundicion":"AJUSTA LAS 3 VALVULAS AL OBJETIVO EN FRIO","ruinas":"GIRA LOS 4 CONDUCTOS HASTA CONECTAR LA RUTA","glaciar":"MIRA LOS DESTELLOS Y PISA LAS PLACAS EN ORDEN","volcan":"CADA VALVULA TRANSFIERE UNA UNIDAD A LA SIGUIENTE","central":"CADA INTERRUPTOR CAMBIA SU LUZ Y LAS DOS VECINAS","cantera":"AJUSTA LOS PESOS: CADA LADO DEBE PESAR TRES","ciudad":"LEE EL CODIGO Y ACTIVA LAS TERMINALES EN ORDEN","biolab":"MEZCLA EN ORDEN Y MANTEN LA ESTACION 3 OCUPADA"}

func _ready() -> void:
	add_to_group("zone_puzzle")
	match zone:
		"fundicion":
			values = [0,0,0]
			target = [[1,3,2],[2,3,2],[3,1,2]][chapter%3]
		"ruinas":
			values = [0,0,0,0]
			target = [1,2,(chapter+1)%4,3]
		"glaciar","ciudad","biolab":
			sequence = [[2,0,1],[1,2,0,2],[0,2,1,0,2]][chapter%3]
			values = [0,0,0]
		"volcan":
			values = [6,0,0]
			target = [[2,3,1],[1,2,3],[3,2,1]][chapter%3]
		"central":
			values = [false,false,false,false]
			target = [[true,false,false,false],[false,true,false,false],[false,false,true,false]][chapter%3]
		"cantera":
			values = [0,0,0]
			target = [2,1,3] if chapter%2 == 0 else [1,2,3]
	door = StaticBody2D.new()
	door.position = Vector2(718,-700)
	door.collision_layer = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12,896)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(6,448)
	door.add_child(cs)
	add_child(door)
	for i in values.size():
		if zone == "glaciar":
			continue
		var terminal := preload("res://scripts/world/puzzle_terminal.gd").new()
		terminal.puzzle = self
		terminal.terminal_index = i
		terminal.position = control_position(i)-Vector2(0,18)
		terminal.color = stage.theme["accent"]
		add_child(terminal)
		terminals.append(terminal)

func control_position(i: int) -> Vector2:
	if i<control_positions.size(): return control_positions[i]
	return Vector2(160+i*145,150 if i%2 == 0 else 86)

func activate(i: int) -> bool:
	if solved or i < 0 or i >= values.size():
		return false
	if zone=="biolab" and progress>0:
		return false
	match zone:
		"fundicion":
			if fposmod(clock,4.0) < 1.4:
				GameManager.toast("HORNO CALIENTE: ESPERA LA VENTANA AZUL",Color("ff8c42"))
				return false
			values[i] = (int(values[i])+1)%4
		"ruinas":
			values[i] = (int(values[i])+1)%4
		"volcan":
			if int(values[i]) > 0:
				values[i] -= 1
				values[(i+1)%3] += 1
			else:
				GameManager.toast("DEPOSITO VACIO: TRANSFIERE DESDE OTRO",Color("ff8c42"))
				return false
		"central":
			values[i] = not values[i]
			values[(i+1)%4] = not values[(i+1)%4]
			values[(i+3)%4] = not values[(i+3)%4]
		"cantera":
			values[i] = (int(values[i])+1)%4
		"glaciar","ciudad","biolab":
			if i == int(sequence[step]):
				step += 1
			else:
				step = 0
				GameManager.toast("ORDEN INCORRECTO - EL CODIGO SIGUE VISIBLE",Color("ffd45a"))
			if step >= sequence.size():
				if zone != "biolab":
					finish()
				else:
					progress = 0.01
				step = 0 if solved else mini(step,sequence.size()-1)
	var balanced := zone == "cantera" and int(values[0])+int(values[1]) == int(values[2]) and int(values[2]) == 3
	if balanced or (zone != "cantera" and not target.is_empty() and values == target):
		finish()
	AudioManager.play("select",-14)
	return true

func _physics_process(delta: float) -> void:
	clock += delta
	if not _announced:
		for p in stage._players:
			if p.alive and absf(p.global_position.x-global_position.x-360) < 330:
				_announced = true
				GameManager.toast(HINTS[zone],stage.theme["accent"])
	if zone == "glaciar" and not solved:
		var now: Array = []
		for i in 3:
			for p in stage._players:
				if p.alive and p.global_position.distance_to(global_position+control_position(i)) < 20:
					now.append(i)
					if not _inside.has(i):
						activate(i)
		_inside = now
	if zone == "biolab" and progress > 0 and not solved:
		var defended := false
		for p in stage._players:
			if p.alive and p.global_position.distance_to(global_position+control_position(2)) < 36:
				defended = true
		progress = maxf(0.01,progress+delta/5.0) if defended else maxf(0.01,progress-delta/8.0)
		if progress >= 1:
			finish()
	queue_redraw()

func finish() -> void:
	if solved:
		return
	solved = true
	if is_instance_valid(door):
		door.queue_free()
	GameManager.add_score(800)
	GameManager.toast("PUZZLE RESUELTO: "+TITLES[zone],Color("63ffc3"))

func value_label(items: Array) -> String:
	var parts := PackedStringArray()
	for item in items:
		parts.append(str(int(item)))
	return " - ".join(parts)

func status_text() -> String:
	var status := ""
	if not target.is_empty():
		status = "ACTUAL "+value_label(values)+" / META "+value_label(target)
	else:
		status = "CODIGO "+value_label(sequence.map(func(n): return int(n)+1))+" / PASO %d" % step
	if zone == "fundicion":
		status += " / "+("CALIENTE" if fposmod(clock,4.0)<1.4 else "FRIO")
	if zone == "cantera":
		status = "BALANZA %d:%d / AMBOS LADOS DEBEN PESAR 3" % [int(values[0])+int(values[1]),int(values[2])]
	if zone == "ruinas":
		var connected := 0
		for i in values.size():
			if values[i] == target[i]: connected += 1
		status = "CONDUCTOS ENLAZADOS %d/4 / IGUALA LAS FLECHAS AZULES" % connected
	if zone == "glaciar":
		status = "OBSERVA LOS DESTELLOS / PASO %d" % step
	return "RESUELTO" if solved else status

func hint_text() -> String:
	return HINTS[zone]

func _draw() -> void:
	var col: Color = stage.theme["accent"]
	for i in values.size():
		var at := control_position(i)
		draw_rect(Rect2(at-Vector2(22,2),Vector2(44,3)),col)
		PT.draw_box(self,str(i+1),Rect2(at-Vector2(10,40),Vector2(20,12)),col)
		if zone == "ruinas":
			draw_line(at-Vector2(0,18),at-Vector2(0,18)+Vector2.RIGHT.rotated(int(values[i])*PI/2)*12,col,2)
			draw_line(at-Vector2(0,55),at-Vector2(0,55)+Vector2.RIGHT.rotated(int(target[i])*PI/2)*10,Color("73f7ff"),2)
		if zone == "glaciar" and not solved:
			var flash := floori(fposmod(clock,float(sequence.size())*0.8+1.6)/0.8)
			if flash < sequence.size() and int(sequence[flash]) == i:
				draw_arc(at-Vector2(0,12),23,PI,TAU,16,Color.WHITE,2)
	if not solved:
		draw_rect(Rect2(718,-700,12,896),Color(col,0.45))
	if zone == "biolab" and progress > 0:
		draw_rect(Rect2(48,58,594*minf(progress,1),3),col)
