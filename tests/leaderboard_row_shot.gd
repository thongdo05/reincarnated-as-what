extends SceneTree

## Mocked leaderboard rows. Does not call the server.
## godot --path . -s res://tests/leaderboard_row_shot.gd

var _phase := 0
var _frames := 0
var _game: Node

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 540))

func _process(_delta: float) -> bool:
	match _phase:
		0:
			var packed: PackedScene = load("res://scenes/main.tscn")
			_game = packed.instantiate()
			_game.process_mode = Node.PROCESS_MODE_DISABLED
			root.add_child(_game)
			_frames = 0
			_phase = 1
		1:
			_frames += 1
			if _frames < 2:
				return false
			_game._board.preview(_rows(), "Spyral")
			_frames = 0
			_phase = 2
		2:
			_frames += 1
			if _frames < 3:
				return false
			_shot()
			print("ROW_SHOT_OK")
			quit(0)
			return true
	return false

func _rows() -> Array:
	return [
		{"rank": 1, "name": "Spyral", "score": 68566, "form": "demon_lord", "is_me": true},
		{"rank": 2, "name": "MMMMMMMMMMMM", "score": 9999999, "form": "goblin", "is_me": false},
		{"rank": 3, "name": "Gel Knight", "score": 42100, "form": "slime", "is_me": false},
		{"rank": 4, "name": "Cat Chairman", "score": 12840, "form": "cat", "is_me": false},
		{"rank": 5, "name": "VEND-MACHINE", "score": 8800, "form": "vending_machine", "is_me": false},
		{"rank": 6, "name": "Prism Ooze", "score": 2500, "form": "slime", "is_me": false},
	]

func _shot() -> void:
	var image := root.get_texture().get_image()
	if image == null:
		push_error("no viewport image")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	var path := "/opt/cursor/artifacts/leaderboard_rows.png"
	if image.save_png(path) != OK:
		push_error("save failed %s" % path)
		quit(1)
		return
	print("WROTE %s %s" % [path, image.get_size()])
