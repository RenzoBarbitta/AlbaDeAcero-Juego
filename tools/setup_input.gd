extends SceneTree
## Configura el InputMap del proyecto y lo guarda en project.godot.
## Ejecutar: godot --headless --path . --script res://tools/setup_input.gd

func _initialize() -> void:
	var actions := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"aim_up": [KEY_W, KEY_UP],
		"aim_down": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE, KEY_Z],
		"shoot": [KEY_J, KEY_X],
		"dash": [KEY_SHIFT, KEY_K],
		"weapon_switch": [KEY_Q, KEY_TAB],
		"pause": [KEY_ESCAPE, KEY_P],
	}
	for action in actions.keys():
		var events: Array = []
		for kc in actions[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = kc
			events.append(ev)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.5, "events": events})
	var err := ProjectSettings.save()
	print("INPUT_DONE err=", err)
	quit()
