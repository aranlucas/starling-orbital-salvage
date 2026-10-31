extends SceneTree
## Invoked by smoke_test in a child engine process to exercise the actual CLI flag.
func _initialize() -> void:
	verify.call_deferred()

func verify() -> void:
	var real_path := "user://starling.cfg"
	var existed := FileAccess.file_exists(real_path)
	var before := FileAccess.get_file_as_bytes(real_path) if existed else PackedByteArray()
	var game := load("res://scenes/main.tscn").instantiate() as Node2D
	game.auto_pause = false
	root.add_child(game)
	await process_frame
	var valid: bool = game.profile.preview and game.profile.path != real_path and game.profile.scrap == 5000 and game.profile.owned.size() == FlightProfile.ITEMS.size()
	game.profile.save()
	var after := FileAccess.get_file_as_bytes(real_path) if FileAccess.file_exists(real_path) else PackedByteArray()
	valid = valid and existed == FileAccess.file_exists(real_path) and before == after
	var temporary_path: String = game.profile.path
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
	print("PREVIEW FLAG: " + ("PASS" if valid else "FAIL"))
	quit(0 if valid else 1)
