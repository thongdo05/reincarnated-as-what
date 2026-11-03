extends SceneTree

## Run against a release export:
## godot --headless --main-pack build/web/index.pck -s res://scripts/music_pack_check.gd
## ResourceLoader.exists is what the web build can see. FileAccess.file_exists is not.

func _initialize() -> void:
	var failed := 0
	var ids: PackedStringArray = [
		"neon_tokyo",
		"office_hell",
		"underworld",
		"candy_kingdom",
		"ice_tundra",
		"sunken_ruins",
	]
	for id in ids:
		var path := "res://audio/music/world_%s.ogg" % id
		if WorldCatalog.music_path(id) != path or not ResourceLoader.exists(path):
			push_error("export did not load %s" % path)
			failed += 1
			continue
		var stream := load(path) as AudioStreamOggVorbis
		if stream == null or not stream.loop or absf(stream.loop_offset) > 0.001 or stream.get_length() < 1.0:
			push_error("export stream %s is not a looping ogg" % path)
			failed += 1
			continue
		print("PACK_TRACK %s %.3fs" % [id, stream.get_length()])
	var sky := WorldCatalog.music_path(WorldCatalog.SKY_CASTLE)
	if sky != WorldCatalog.FALLBACK_MUSIC or not ResourceLoader.exists(sky):
		push_error("sky castle export should keep %s" % WorldCatalog.FALLBACK_MUSIC)
		failed += 1
	else:
		var loop := load(sky) as AudioStreamOggVorbis
		if loop == null or not loop.loop:
			push_error("sky castle loop did not load from the export")
			failed += 1
		else:
			print("PACK_TRACK sky_castle %.3fs" % loop.get_length())
	if failed > 0:
		push_error("PACK_MUSIC_FAIL %d" % failed)
		quit(1)
		return
	print("PACK_MUSIC_OK")
	quit(0)
