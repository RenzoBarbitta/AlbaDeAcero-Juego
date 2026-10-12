extends SceneTree
var failures := 0
var checked := 0

func _initialize() -> void:
	ProjectSettings.set_setting("debug/gdscript/warnings/treat_warnings_as_errors",true)
	scan("res://scripts")
	print("STRICT SCRIPTS: %d scripts, %d failures" % [checked,failures])
	quit(0 if failures == 0 else 1)

func scan(folder: String) -> void:
	var dir := DirAccess.open(folder)
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var source: GDScript = load(folder+"/"+file)
		var result := source.reload(true)
		checked += 1
		if result != OK:
			failures += 1
			print("FAILED: "+folder+"/"+file)
	for subdir in dir.get_directories():
		scan(folder+"/"+subdir)
