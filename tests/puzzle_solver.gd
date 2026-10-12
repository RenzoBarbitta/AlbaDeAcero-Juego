extends RefCounted
static func moves(puzzle: Node2D) -> Array:
	var queue: Array = [{"values":puzzle.values.duplicate(),"moves":[]}]
	var seen := {}
	while not queue.is_empty():
		var node: Dictionary = queue.pop_front()
		if node["values"] == puzzle.target: return node["moves"]
		var key := str(node["values"])
		if seen.has(key): continue
		seen[key] = true
		for i in puzzle.values.size():
			var next: Array = node["values"].duplicate()
			if puzzle.zone=="central":
				for j in [i,(i+1)%4,(i+3)%4]: next[j] = not next[j]
			elif puzzle.zone=="volcan":
				if int(next[i])<=0: continue
				next[i] -= 1
				next[(i+1)%3] += 1
			else: next[i] = (int(next[i])+1)%4
			queue.append({"values":next,"moves":node["moves"]+[i]})
	return []

static func complete(puzzle: Node2D,player: Player) -> bool:
	# El solver llama la fisica manualmente para resolver rapido, pero debe
	# devolver el nodo a su estado original. Si queda desactivado, las pruebas
	# posteriores (por ejemplo escoltas) nunca avanzan en tiempo real.
	var was_processing := puzzle.is_physics_processing()
	puzzle.set_physics_process(false)
	var solved_now := false
	if puzzle.has_method("expedition_state"):
		solved_now = complete_expedition(puzzle,player)
	else:
		puzzle.clock = 2
		if not puzzle.sequence.is_empty():
			for index in puzzle.sequence: puzzle.activate(int(index))
			if puzzle.zone=="biolab":
				player.position = puzzle.position+puzzle.control_position(2)
				puzzle._physics_process(5.1)
		else:
			for index in moves(puzzle): puzzle.activate(int(index))
		solved_now = puzzle.solved
	puzzle.set_physics_process(was_processing)
	return solved_now

static func visit(puzzle: Node2D,player: Player,index: int) -> void:
	player.global_position = puzzle.global_position+Vector2(80,150)
	puzzle._physics_process(0.01)
	player.global_position = puzzle.global_position+puzzle.nodes[index]
	puzzle._physics_process(0.01)

static func complete_expedition(puzzle: Node2D,player: Player) -> bool:
	match puzzle.rule:
		"frequency":
			for i in puzzle.sequence:
				puzzle.clock = 2-float(i)*0.4
				puzzle.activate(i)
		"furnace_hold","capacitors":
			for i in [0,3]:
				player.global_position = puzzle.global_position+puzzle.nodes[i]
				for tick in 30:
					puzzle.clock = 0
					puzzle._physics_process(0.1)
		"warmth","courier":
			for tick in 200:
				player.global_position = puzzle.global_position+puzzle.escort_position()
				puzzle._physics_process(0.1)
		"coolant","vent_route":
			for i in [1,3,4]:
				puzzle.clock = 2.5 if puzzle.rule=="vent_route" and i==3 else 0
				visit(puzzle,player,i)
		"counterweight","ore_cargo","hot_cargo","antidote":
			var deliveries := 2 if puzzle.rule=="counterweight" else (3 if puzzle.rule=="ore_cargo" else 1)
			for i in deliveries:
				visit(puzzle,player,0)
				visit(puzzle,player,3+i if puzzle.rule=="counterweight" else 3)
		_:
			for i in puzzle.sequence:
				puzzle.clock = 0
				visit(puzzle,player,i)
	return puzzle.solved
