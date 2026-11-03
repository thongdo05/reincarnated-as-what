extends SceneTree

## Run against a release pack:
## godot --headless --main-pack build/audio.pck -s res://scripts/boss_audio_pack_check.gd
## ResourceLoader.exists is what an exported pck can see. FileAccess.file_exists is not.

func _initialize() -> void:
	var failed := 0
	for slug in ["lich_king", "death_knight", "great_dragon"]:
		for moment in ["enter", "death"]:
			var event := "boss_%s_%s" % [slug, moment]
			var data := AudioCues.spec(event)
			var path := str(data.get("file", ""))
			if not ResourceLoader.exists(path):
				push_error("export did not load %s" % path)
				failed += 1
				continue
			var stream := load(path) as AudioStream
			if stream == null or stream.get_length() < 0.4:
				push_error("export stream %s did not load" % path)
				failed += 1
				continue
			print("PACK_CUE %s %.3fs" % [event, stream.get_length()])
	if failed > 0:
		quit(1)
		return
	print("PACK_AUDIO_OK")
	quit(0)
