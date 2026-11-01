extends Node
class_name SoundRig

## TEST audio player. Music sits at -6 dB and SFX at -12 dB so the loop is
## above the stings. The slime shot is another -10 dB and at most about 4/s.
## Web builds wait for a user gesture before the first play. iOS Safari ignores
## audio that starts before that tap, and it will not play the ogg as a stream.
## See audio/README.md.

var settings_path := AudioCues.SETTINGS_PATH
var enabled := true
var played: Array[String] = []

var _music_wanted := false
var _unlocked := false
var _shot_lockout := 0.0
var _music: AudioStreamPlayer
var _pools: Dictionary = {}
var _cursors: Dictionary = {}

func _ready() -> void:
	setup()

# Children leave the tree before the rig does. Stop each player on its own
# tree_exiting, while it is still inside, or the looping ogg playback leaks
# and the headless quit check reports an error.
func _silence_player(player: AudioStreamPlayer) -> void:
	if not is_instance_valid(player):
		return
	player.stop()

func setup() -> void:
	AudioCues.apply_bus_levels()
	enabled = AudioCues.read_enabled(settings_path)
	_build_players()
	_apply_mute()
	if not OS.has_feature("web") or _web_already_unlocked():
		_unlocked = true

func start_gameplay_music() -> void:
	_music_wanted = true
	_ensure_music()

func unlock_from_gesture() -> void:
	_resume_web_audio()
	_unlocked = true
	_ensure_music()

func poll_web_gesture() -> void:
	if not OS.has_feature("web"):
		return
	var flagged: Variant = JavaScriptBridge.eval(
		"(function(){if(!window.__godotAudioGesture)return 0;window.__godotAudioGesture=false;return 1;})()",
		true
	)
	if int(flagged) == 1:
		_unlocked = true
		_resume_web_audio()
	if _unlocked:
		_ensure_music()

func _process(delta: float) -> void:
	if _shot_lockout > 0.0:
		_shot_lockout = maxf(_shot_lockout - delta, 0.0)
	poll_web_gesture()

func play_title_card(card: String) -> void:
	var event := AudioCues.reveal_event_for_card(card)
	if event == "":
		return
	play_event(event)

## The vending machine is not in the run roster. Call this to hear its sting.
func debug_play_vending_reveal() -> void:
	play_event("reveal_vending_machine")

func play_event(event: String) -> void:
	if AudioCues.spec(event).is_empty():
		return
	if event == "slime_shot" and not _claim_shot():
		return
	played.append(event)
	if not enabled:
		return
	# Same reason as the music player: a stream left running at process
	# exit is reported as a leak, and the headless check fails CI on it.
	if DisplayServer.get_name() == "headless":
		return
	var player := _take_player(event)
	if player == null:
		return
	player.pitch_scale = _pitch_for(event)
	player.play()

func stop_event(event: String) -> void:
	for item in _pool(event):
		var player := item as AudioStreamPlayer
		if player.playing:
			player.stop()

func play_count(event: String) -> int:
	var count := 0
	for item in played:
		if item == event:
			count += 1
	return count

func set_enabled(on: bool) -> void:
	enabled = on
	AudioCues.write_enabled(on, settings_path)
	_apply_mute()
	if enabled:
		_ensure_music()

func set_music_paused(paused: bool) -> void:
	if _music != null:
		_music.stream_paused = paused

func music_is_playing() -> bool:
	return _music != null and _music.playing and not _music.stream_paused

func music_stream() -> AudioStream:
	if _music == null:
		return null
	return _music.stream

func player_for(event: String) -> AudioStreamPlayer:
	if event == "gameplay_music":
		return _music
	var pool := _pool(event)
	if pool.is_empty():
		return null
	return pool[0] as AudioStreamPlayer

func active_voices(event: String) -> int:
	var count := 0
	for item in _pool(event):
		var player := item as AudioStreamPlayer
		if player.playing:
			count += 1
	return count

func _pool(event: String) -> Array:
	var found: Variant = _pools.get(event, [])
	if typeof(found) != TYPE_ARRAY:
		return []
	return found

func _build_players() -> void:
	for event in AudioCues.all_events():
		var data := AudioCues.spec(event)
		var stream := load(str(data["file"])) as AudioStream
		if stream == null:
			push_error("missing test audio %s" % str(data["file"]))
			continue
		AudioCues.prepare_stream(stream, event)
		if event == "gameplay_music":
			_music = _make_player(event, stream)
			# Desktop can stream the ogg. iOS Safari plays the wav shots and
			# stays silent for a streamed ogg, so the web build uses a sample.
			# The loop flag is on the stream either way, with loop_offset 0.
			_music.playback_type = AudioCues.music_playback_type(OS.has_feature("web"))
			_music.max_polyphony = 1
			continue
		var voices := 1
		if float(data.get("pitch_semitones", 0.0)) > 0.0:
			voices = int(data.get("polyphony", 1))
		var pool: Array[AudioStreamPlayer] = []
		for _i in voices:
			var player := _make_player(event, stream)
			if voices == 1:
				player.max_polyphony = int(data.get("polyphony", 1))
			else:
				player.max_polyphony = 1
			pool.append(player)
		_pools[event] = pool

func _make_player(event: String, stream: AudioStream) -> AudioStreamPlayer:
	var data := AudioCues.spec(event)
	var player := AudioStreamPlayer.new()
	player.name = event
	player.stream = stream
	player.bus = StringName(str(data["bus"]))
	player.volume_db = float(data.get("volume_db", 0.0))
	player.pitch_scale = 1.0
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.tree_exiting.connect(_silence_player.bind(player))
	add_child(player)
	return player

func _take_player(event: String) -> AudioStreamPlayer:
	var pool := _pool(event)
	if pool.is_empty():
		return null
	if pool.size() == 1:
		return pool[0] as AudioStreamPlayer
	for item in pool:
		var free := item as AudioStreamPlayer
		if not free.playing:
			return free
	var cursor := int(_cursors.get(event, 0)) % pool.size()
	_cursors[event] = (cursor + 1) % pool.size()
	var stolen := pool[cursor] as AudioStreamPlayer
	stolen.stop()
	return stolen

func _pitch_for(event: String) -> float:
	var ratio := float(AudioCues.spec(event).get("pitch_ratio", 0.0))
	if ratio > 0.0:
		return AudioCues.shot_pitch_scale(randf())
	var span := float(AudioCues.spec(event).get("pitch_semitones", 0.0))
	if span <= 0.0:
		return 1.0
	return AudioCues.semitone_to_pitch(AudioCues.pop_semitones(randf(), randf()))

func _claim_shot() -> bool:
	if _shot_lockout > 0.0:
		return false
	_shot_lockout = float(AudioCues.spec("slime_shot").get("min_interval", AudioCues.SHOT_MIN_INTERVAL))
	return true

func _ensure_music() -> void:
	if not _music_wanted or _music == null:
		return
	# Headless has no device. Leaving the loop running makes --quit-after
	# report a resource leak, and CI treats that line as a failure.
	# The player is still built, looped, and able to play(); see the smoke test.
	if DisplayServer.get_name() == "headless":
		return
	if OS.has_feature("web") and not _unlocked:
		return
	if OS.has_feature("web") and not _web_audio_ready():
		return
	if _music.stream_paused:
		return
	if not _music.playing:
		_music.play()

func _apply_mute() -> void:
	var mute := not enabled
	AudioServer.set_bus_mute(AudioServer.get_bus_index(AudioCues.MUSIC_BUS), mute)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(AudioCues.SFX_BUS), mute)

func _resume_web_audio() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("if (window.unlockGodotAudio) window.unlockGodotAudio();", true)

func _web_audio_ready() -> bool:
	var state := _web_audio_state()
	if state == "running":
		return true
	_resume_web_audio()
	return _web_audio_state() == "running"

func _web_audio_state() -> String:
	if not OS.has_feature("web"):
		return "running"
	var value: Variant = JavaScriptBridge.eval(
		"(function(){if(typeof GodotAudio==='undefined'||!GodotAudio.ctx)return 'missing';return GodotAudio.ctx.state;})()",
		true
	)
	return str(value)

func _web_already_unlocked() -> bool:
	if not OS.has_feature("web"):
		return true
	var value: Variant = JavaScriptBridge.eval(
		"(function(){if(window.__godotAudioPrimed)return 1;if(typeof GodotAudio!=='undefined'&&GodotAudio.ctx&&GodotAudio.ctx.state==='running')return 1;return 0;})()",
		true
	)
	return int(value) == 1
