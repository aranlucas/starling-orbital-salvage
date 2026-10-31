extends SceneTree
## Native manual QA with a separate profile. Run with --maximized on macOS.
## godot --path . --maximized --script tools/native_playtest.gd

const GameScene: PackedScene = preload("res://scenes/main.tscn")


func _initialize() -> void:
	_launch.call_deferred()


func _launch() -> void:
	var game: Node2D = GameScene.instantiate()
	game.profile.path = "user://starling-native-playtest.cfg"
	root.add_child(game)
