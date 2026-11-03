extends Node
class_name SoundRig

## TEST audio player. Music sits at -6 dB and SFX at -12 dB so the loop is
## above the stings. Form shots are another -10 dB and at most about 4/s.
## A cue whose imported sample is missing is skipped, with no error.
## The web export plays the loop as a sample. Godot 4.7 does not put GodotAudio
## on the page, so iOS Safari can be running for WAV shots while this rig still
## thinks the context is missing and never starts the loop. The shell publishes
## the real context. See audio/README.md.

var settings_path := AudioCues.SETTINGS_PATH
var enabled := true
var played: Array[String] = []

var _music_wanted := false
var _unlocked := false
var _shot_lockout := 0.0
var _gaps: Dictionary = {}
var _gem_step := 0
var _gem_quiet := 0.0
var last_gain_db := 0.0
var last_pitch_scale := 1.0
## True while the web context is locked, or the loop was asked for and did not start.
var output_blocked := false
var _web_state := ""
var _music_silent_for := 0.0
var _music_sources := 0
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

func poll_web_gesture(delta: float = 0.0) -> void:
	if not OS.has_feature("web"):
		output_blocked = false
		return
	# One read: gesture, visibility restart, context state, live music sources.
	var packed := str(JavaScriptBridge.eval(
		"(function(){var g=window.__godotAudioGesture?1:0;window.__godotAudioGesture=false;var r=window.__godotAudioRestartMusic?1:0;window.__godotAudioRestartMusic=false;var state=window.__godotAudioState||(window.__godotAudioCtx&&window.__godotAudioCtx.state)||(typeof GodotAudio!=='undefined'&&GodotAudio.ctx&&GodotAudio.ctx.state)||'missing';var n=window.__godotMusicSources||0;return g+'|'+r+'|'+state+'|'+n;})()",
		true
	))
	var gesture := 0
	var restart := 0
	var parts := packed.split("|")
	if parts.size() >= 4:
		gesture = int(parts[0])
		restart = int(parts[1])
		_web_state = parts[2]
		_music_sources = int(parts[3])
	else:
		_web_state = "missing"
		_music_sources = 0
	# A running context is the unlock. iOS stays suspended until a tap, and
	# that tap is what moves the context to running.
	if _web_state == "running":
		_unlocked = true
	if gesture == 1:
		_unlocked = true
		_resume_web_audio()
	if restart == 1 and _unlocked:
		_restart_music_from_web()
	elif _unlocked:
		_ensure_music()
	_update_output_blocked(delta)

func _restart_music_from_web() -> void:
	_music_silent_for = 0.0
	if not _music_wanted or not enabled or _music == null:
		return
	# Pause already owns the player. Coming back to the tab must not unpause it.
	if _music.stream_paused:
		return
	# The buffer source is still connected. Resuming the context is enough,
	# and a second play() would stack another loop on top.
	if _music_sources > 0 and _web_audio_state() == "running" and _music.playing:
		return
	if _music.playing:
		_music.stop()
	_ensure_music()

func _update_output_blocked(delta: float) -> void:
	if not enabled:
		output_blocked = false
		_music_silent_for = 0.0
		return
	if _web_audio_state() != "running":
		output_blocked = true
		_music_silent_for = 0.0
		return
	if _music != null and _music.stream_paused:
		output_blocked = false
		_music_silent_for = 0.0
		return
	var music_live := _music_wanted and _music != null and _music.playing and _music_sources > 0
	if music_live:
		_music_silent_for = 0.0
		output_blocked = false
		return
	_music_silent_for += delta
	# The worklet starts the buffer a moment after play(). Don't flash the mark.
	output_blocked = _music_silent_for >= 0.6

func _process(delta: float) -> void:
	if _shot_lockout > 0.0:
		_shot_lockout = maxf(_shot_lockout - delta, 0.0)
	var gap_keys: Array = _gaps.keys()
	for key in gap_keys:
		var left := float(_gaps[key]) - delta
		if left <= 0.0:
			_gaps.erase(key)
		else:
			_gaps[key] = left
	_gem_quiet = minf(_gem_quiet + delta, AudioCues.GEM_CHAIN_RESET)
	if _gem_quiet >= AudioCues.GEM_CHAIN_RESET:
		_gem_step = 0
	poll_web_gesture(delta)

func play_title_card(card: String) -> void:
	var event := AudioCues.reveal_event_for_card(card)
	if event == "":
		return
	play_event(event)

## The vending machine is not in the run roster. Call this to hear its sting.
func debug_play_vending_reveal() -> void:
	play_event("reveal_vending_machine")

func play_event(event: String, gain_db: float = 0.0) -> void:
	var data := AudioCues.spec(event)
	if data.is_empty():
		return
	if not _claim_event(event):
		return
	var pitch := _pitch_for(event)
	played.append(event)
	last_gain_db = gain_db
	last_pitch_scale = pitch
	if not enabled:
		return
	# Same reason as the music player: a stream left running at process
	# exit is reported as a leak, and the headless check fails CI on it.
	if DisplayServer.get_name() == "headless":
		return
	var player := _take_player(event)
	if player == null:
		return
	player.pitch_scale = pitch
	var base_db := float(data.get("volume_db", 0.0))
	player.volume_db = base_db + gain_db
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

func voice_count(event: String) -> int:
	return _pool(event).size()

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
		var path := str(data["file"])
		# The exported pack has the imported sample, not the source wav.
		if not ResourceLoader.exists(path):
			if AudioCues.should_report_missing(data):
				push_error("missing test audio %s" % path)
			continue
		var stream := load(path) as AudioStream
		if stream == null:
			if not bool(data.get("optional", false)):
				push_error("missing test audio %s" % path)
			continue
		AudioCues.prepare_stream(stream, event)
		if event == "gameplay_music":
			_music = _make_player(event, stream)
			# Desktop streams the ogg. The web build uses a sample so the
			# single-threaded export does not garble the loop. loop_offset stays 0.
			_music.playback_type = AudioCues.music_playback_type(OS.has_feature("web"))
			_music.max_polyphony = 1
			continue
		var voices := 1
		if float(data.get("pitch_semitones", 0.0)) > 0.0 or bool(data.get("pitch_chain", false)):
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
	if event == "gem_pickup":
		if _gem_quiet >= AudioCues.GEM_CHAIN_RESET:
			_gem_step = 0
		var semis := AudioCues.gem_chain_semitones(_gem_step)
		_gem_step = mini(_gem_step + 1, AudioCues.GEM_CHAIN_CAP)
		_gem_quiet = 0.0
		return AudioCues.semitone_to_pitch(semis)
	var ratio := float(AudioCues.spec(event).get("pitch_ratio", 0.0))
	if ratio > 0.0:
		return AudioCues.shot_pitch_scale(randf())
	var span := float(AudioCues.spec(event).get("pitch_semitones", 0.0))
	if span <= 0.0:
		return 1.0
	return AudioCues.semitone_to_pitch(AudioCues.pop_semitones(randf(), randf()))

func _claim_event(event: String) -> bool:
	var data := AudioCues.spec(event)
	if AudioCues.is_shot_event(event):
		return _claim_shot(event)
	var interval := float(data.get("min_interval", 0.0))
	if interval <= 0.0:
		return true
	if float(_gaps.get(event, 0.0)) > 0.0:
		return false
	_gaps[event] = interval
	return true

func _claim_shot(event: String) -> bool:
	if _shot_lockout > 0.0:
		return false
	_shot_lockout = float(AudioCues.spec(event).get("min_interval", AudioCues.SHOT_MIN_INTERVAL))
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
	if _web_audio_state() == "running":
		return true
	_resume_web_audio()
	_web_state = str(JavaScriptBridge.eval(
		"(function(){return window.__godotAudioState||(window.__godotAudioCtx&&window.__godotAudioCtx.state)||(typeof GodotAudio!=='undefined'&&GodotAudio.ctx&&GodotAudio.ctx.state)||'missing';})()",
		true
	))
	return _web_state == "running"

func _web_audio_state() -> String:
	if not OS.has_feature("web"):
		return "running"
	if _web_state == "":
		_web_state = str(JavaScriptBridge.eval(
			"(function(){return window.__godotAudioState||(window.__godotAudioCtx&&window.__godotAudioCtx.state)||(typeof GodotAudio!=='undefined'&&GodotAudio.ctx&&GodotAudio.ctx.state)||'missing';})()",
			true
		))
	return _web_state

func _web_already_unlocked() -> bool:
	if not OS.has_feature("web"):
		return true
	var value: Variant = JavaScriptBridge.eval(
		"(function(){if(window.__godotAudioPrimed)return 1;var state=window.__godotAudioState||(window.__godotAudioCtx&&window.__godotAudioCtx.state)||(typeof GodotAudio!=='undefined'&&GodotAudio.ctx&&GodotAudio.ctx.state)||'';if(state==='running')return 1;return 0;})()",
		true
	)
	return int(value) == 1
