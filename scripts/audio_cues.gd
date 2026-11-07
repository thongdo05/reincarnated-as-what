extends RefCounted
class_name AudioCues

## TEST audio from Hibiki, 1 Nov 2026 (ElevenLabs sample, not the final mix),
## plus the 3 Nov 2026 form shots and pickups. Files are already at the loudness
## in audio/manifest.json. The buses pull the loop above the stings: Music at
## -6 dB, SFX at -12 dB. Each form shot is another -10 dB on its player, and
## it is capped at about 4 plays a second. A cue whose imported sample is
## not in the project yet is skipped. See audio/README.md.

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const MUSIC_BUS_DB := -6.0
const SFX_BUS_DB := -12.0
const SETTINGS_PATH := "user://audio.cfg"

## Heard cap. Rank 3 fires every 0.10 s, which used to retrigger the bloop
## on every volley and turned the run into one beep. One sound per volley
## still holds; this drops the ones that arrive sooner than 0.25 s.
const SHOT_MIN_INTERVAL := 0.25
const SHOT_VOLUME_DB := -10.0
## +/- 8% around the recorded pitch. Not a semitone jump.
const SHOT_PITCH_RATIO := 0.08
## 8 shots/s of a 0.22 s bloop is under 2 voices. The heard cap is 4/s,
## so three voices stay a small ceiling rather than a stack.
const SHOT_POLYPHONY := 3
const SHOT_STRESS_RATE := 8.0
const SHOT_DURATION := 0.22
const POP_POLYPHONY := 4
const POP_SEMITONE_MIN := 1.0
const POP_SEMITONE_MAX := 2.0
const GEM_POLYPHONY := 4
const GEM_MIN_INTERVAL := 0.05
const GEM_CHAIN_RESET := 0.6
const GEM_CHAIN_CAP := 7
const POWER_POLYPHONY := 1
## Level 1 stays at the recorded pitch. Each level above that is one semitone.
const POWER_LEVEL_PITCH_CAP := 12

## Fanfare chord inside sfx_evolve.wav. Evolve frame 5, the EVOLVED! pop.
const EVOLVE_HIT_SECONDS := 0.42

## Plays with the Vending Machine title card. The other forms stay silent
## until a reveal_<form> file is dropped in.
const VENDING_TITLE := "title_cards/title_vending_machine.png"

## Designer drop-ins. Each event loads res://audio/<event>.ogg, then .wav.
## A missing file keeps today's sound, so a build with no new assets plays
## the same cues as before. See audio/README.md.
const SIGNATURE_EVENT := "sting_reincarnation_signature"
const NEW_BEST_EVENT := "new_best"
const FORM_KEYS: PackedStringArray = ["slime", "vending_machine", "goblin", "cat", "demon_lord", "dragon"]
## The vending reveal is 1.6 s and the card is 1.5 s (0.48 s on a retry).
## Fade it out instead of letting the tail play into the run.
const REVEAL_FADE_SECONDS := 0.08

## A DragonPhase hook name is a cue even when its sample has not been matched.
static func is_hook(event: String) -> bool:
	return DragonPhase.is_hook(event)

static func spec(event: String) -> Dictionary:
	var dragon := DragonAudio.spec(event)
	if not dragon.is_empty():
		return dragon
	if is_drop_in(event):
		return _drop_in_spec(event)
	match event:
		"gameplay_music":
			return {
				"file": "res://audio/music_gameplay_loop.ogg",
				"bus": MUSIC_BUS,
				"loop": true,
				"loop_offset": 0.0,
				"lufs": -22.0,
				"polyphony": 1,
				"pitch_semitones": 0.0,
			}
		"slime_shot":
			return _shot_spec("res://audio/sfx_shot_slime.wav", -20.0, 0.22, false)
		"goblin_shot":
			return _shot_spec("res://audio/sfx_shot_goblin.wav", -20.0, 0.15, true)
		"vending_machine_shot":
			return _shot_spec("res://audio/sfx_shot_vending_machine.wav", -20.8, 0.16, true)
		"cat_shot":
			return _shot_spec("res://audio/sfx_shot_cat.wav", -20.0, 0.21, true)
		"demon_lord_shot":
			return _shot_spec("res://audio/sfx_shot_demon_lord.wav", -20.0, 0.23, true)
		"gem_pickup":
			return {
				"file": "res://audio/sfx_pickup_gem.wav",
				"bus": SFX_BUS,
				"loop": false,
				"lufs": -19.0,
				"polyphony": GEM_POLYPHONY,
				"pitch_chain": true,
				"min_interval": GEM_MIN_INTERVAL,
				"duration": 0.13,
				"optional": true,
			}
		"power_pickup":
			return {
				"file": "res://audio/sfx_pickup_power.wav",
				"bus": SFX_BUS,
				"loop": false,
				"lufs": -16.0,
				"polyphony": POWER_POLYPHONY,
				"pitch_semitones": 0.0,
				"duration": 0.80,
				"optional": true,
			}
		"power_level_up":
			return {
				"file": "res://audio/sfx_power_level_up.wav",
				"bus": SFX_BUS,
				"loop": false,
				"lufs": -19.8,
				"polyphony": 1,
				"pitch_semitones": 0.0,
				"duration": 0.68,
			}
		"enemy_killed":
			return _enemy_pop_spec()
		"player_death":
			return _player_death_spec()
		"reborn_tease":
			return _reborn_spec()
		"evolve":
			return {
				"file": "res://audio/sfx_evolve.wav",
				"bus": SFX_BUS,
				"loop": false,
				"lufs": -19.1,
				"polyphony": 1,
				"pitch_semitones": 0.0,
				"hit_seconds": EVOLVE_HIT_SECONDS,
			}
		"boss_lich_king_enter":
			return _boss_cue("sfx_boss_lich_king_enter.wav", -19.9, 1.24)
		"boss_lich_king_death":
			return _boss_cue("sfx_boss_lich_king_death.wav", -19.0, 1.29)
		"boss_death_knight_enter":
			return _boss_cue("sfx_boss_death_knight_enter.wav", -20.2, 1.19)
		"boss_death_knight_death":
			return _boss_cue("sfx_boss_death_knight_death.wav", -18.7, 1.06)
		"boss_great_dragon_enter":
			return _boss_cue("sfx_boss_great_dragon_enter.wav", -19.7, 1.19)
		"boss_great_dragon_death":
			return _boss_cue("sfx_boss_great_dragon_death.wav", -19.3, 1.11)
		_:
			return {}

## Boss stings sit on the SFX bus with the other stings. No extra trim and no
## pitch wobble. A missing import is skipped by ResourceLoader.exists.
static func _boss_cue(file_name: String, lufs: float, duration: float) -> Dictionary:
	return {
		"file": "res://audio/%s" % file_name,
		"bus": SFX_BUS,
		"loop": false,
		"lufs": lufs,
		"polyphony": 1,
		"pitch_semitones": 0.0,
		"duration": duration,
	}

static func _shot_spec(path: String, lufs: float, duration: float, optional: bool) -> Dictionary:
	return {
		"file": path,
		"bus": SFX_BUS,
		"loop": false,
		"lufs": lufs,
		"polyphony": SHOT_POLYPHONY,
		"pitch_semitones": 0.0,
		"pitch_ratio": SHOT_PITCH_RATIO,
		"volume_db": SHOT_VOLUME_DB,
		"min_interval": SHOT_MIN_INTERVAL,
		"duration": duration,
		"optional": optional,
	}

static func _enemy_pop_spec() -> Dictionary:
	return {
		"file": "res://audio/sfx_enemy_pop.wav",
		"bus": SFX_BUS,
		"loop": false,
		"lufs": -17.0,
		"polyphony": POP_POLYPHONY,
		"pitch_semitones": POP_SEMITONE_MAX,
	}

static func _player_death_spec() -> Dictionary:
	return {
		"file": "res://audio/sfx_death.wav",
		"bus": SFX_BUS,
		"loop": false,
		"lufs": -18.3,
		"polyphony": 1,
		"pitch_semitones": 0.0,
	}

static func _reborn_spec() -> Dictionary:
	return {
		"file": "res://audio/sting_reborn_tease.ogg",
		"bus": SFX_BUS,
		"loop": false,
		"lufs": -18.7,
		"polyphony": 1,
		"pitch_semitones": 0.0,
		"duration": 1.0,
	}

static func _vending_reveal_spec() -> Dictionary:
	return {
		"file": "res://audio/sting_reveal_vending_machine.wav",
		"bus": SFX_BUS,
		"loop": false,
		"lufs": -19.3,
		"polyphony": 1,
		"pitch_semitones": 0.0,
		"duration": 1.6,
	}

static func _plain_sting() -> Dictionary:
	return {
		"file": "",
		"bus": SFX_BUS,
		"loop": false,
		"lufs": -18.0,
		"polyphony": 1,
		"pitch_semitones": 0.0,
		"optional": true,
	}

## player_death_<form>, sting_reincarnation_signature, new_best, reveal_<form>.
static func is_drop_in(event: String) -> bool:
	if event == SIGNATURE_EVENT or event == NEW_BEST_EVENT:
		return true
	if event.begins_with("player_death_") and event != "player_death":
		return true
	return event.begins_with("reveal_")

static func _drop_in_base(event: String) -> Dictionary:
	if event.begins_with("player_death_"):
		return _player_death_spec()
	if event == SIGNATURE_EVENT:
		return _reborn_spec()
	if event == NEW_BEST_EVENT:
		return _enemy_pop_spec()
	if event == "reveal_vending_machine":
		return _vending_reveal_spec()
	return {}

## ogg wins when both are present. ResourceLoader sees the imported sample
## inside an exported pck. FileAccess also sees a source file a designer
## just dropped in, which is what the headless fallback test writes.
static func hook_file(event: String) -> String:
	for ext in ["ogg", "wav"]:
		var path := "res://audio/%s.%s" % [event, ext]
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return path
	return ""

static func _drop_in_spec(event: String) -> Dictionary:
	var custom := hook_file(event)
	if custom != "":
		var shell := _drop_in_base(event)
		if shell.is_empty():
			shell = _plain_sting()
		var data := _use_custom_file(shell, custom)
		if event == NEW_BEST_EVENT:
			# Approved file, Thong, 7 Nov 2026. Played as mastered.
			data["lufs"] = -17.7
			data["duration"] = 0.7
		return data
	var base := _drop_in_base(event)
	if base.is_empty():
		return {}
	var data := base.duplicate(true)
	data["using_fallback"] = true
	return data

## A dropped-in file plays as mastered: one voice, no pitch wobble.
static func _use_custom_file(base: Dictionary, path: String) -> Dictionary:
	var data := base.duplicate(true)
	data["file"] = path
	data["using_fallback"] = false
	data["pitch_semitones"] = 0.0
	data["pitch_ratio"] = 0.0
	data["polyphony"] = 1
	data["optional"] = true
	if data.has("pitch_chain"):
		data["pitch_chain"] = false
	return data

static func death_event_for_form(form_id: int) -> String:
	return "player_death_%s" % FormCatalog.key_for(form_id)

static func reveal_event_for_form(form_id: int) -> String:
	var event := "reveal_%s" % FormCatalog.key_for(form_id)
	if hook_file(event) != "":
		return event
	if event == "reveal_vending_machine":
		return event
	return ""

static func reveal_events() -> PackedStringArray:
	var names := PackedStringArray()
	for key in FORM_KEYS:
		names.append("reveal_%s" % key)
	return names

static func death_events() -> PackedStringArray:
	var names := PackedStringArray()
	names.append("player_death")
	for key in FORM_KEYS:
		names.append("player_death_%s" % key)
	return names

## Death stings, the tease, and NEW BEST. Skip and retry stop all of these.
## None of them block the tap.
static func run_end_events() -> PackedStringArray:
	var names := death_events()
	names.append("reborn_tease")
	names.append(SIGNATURE_EVENT)
	names.append(NEW_BEST_EVENT)
	return names

## Start the 1 s tease sting early enough that it ends as the card opens.
## A sting longer than the whole sequence keeps its ending (the front is trimmed).
## A short sting waits for the REBORN AS...? card.
static func signature_start(length: float) -> float:
	var card := FxTimeline.death_card_at()
	var visual := FxTimeline.death_tease_at()
	if length <= 0.0:
		return visual
	if length >= card:
		return 0.0
	return minf(card - length, visual)

static func signature_offset(length: float) -> float:
	var card := FxTimeline.death_card_at()
	if length > card:
		return length - card
	return 0.0

static func all_events() -> PackedStringArray:
	var names := PackedStringArray([
		"gameplay_music",
		"slime_shot",
		"goblin_shot",
		"vending_machine_shot",
		"cat_shot",
		"demon_lord_shot",
		"gem_pickup",
		"power_pickup",
		"power_level_up",
		"enemy_killed",
		"player_death",
		"reborn_tease",
		SIGNATURE_EVENT,
		NEW_BEST_EVENT,
		"evolve",
	])
	for key in FORM_KEYS:
		names.append("player_death_%s" % key)
		names.append("reveal_%s" % key)
	names.append_array(PackedStringArray([
		"boss_lich_king_enter",
		"boss_lich_king_death",
		"boss_death_knight_enter",
		"boss_death_knight_death",
		"boss_great_dragon_enter",
		"boss_great_dragon_death",
		"dragon_slain",
	]))
	return names

static func is_shot_event(event: String) -> bool:
	var key := DragonAudio.canonical(event)
	return key == "slime_shot" or key == "goblin_shot" or key == "vending_machine_shot" or key == "cat_shot" or key == "demon_lord_shot" or key == "dragon_form_shot"

## Missing designer files are skipped. A required cue still reports the gap.
## ResourceLoader sees the imported sample inside an exported pck. FileAccess
## only sees the source wav, which the pack does not contain, so that check
## would skip every cue in the web build.
static func should_report_missing(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	if ResourceLoader.exists(str(data.get("file", ""))):
		return false
	return not bool(data.get("optional", false))

static func shot_event_for_form(form_id: int) -> String:
	match form_id:
		FormCatalog.Id.SLIME:
			return "slime_shot"
		FormCatalog.Id.GOBLIN:
			return "goblin_shot"
		FormCatalog.Id.VENDING:
			return "vending_machine_shot"
		FormCatalog.Id.CAT:
			return "cat_shot"
		FormCatalog.Id.DEMON:
			return "demon_lord_shot"
		FormCatalog.Id.DRAGON:
			return "dragon_form_shot"
		_:
			return ""

## Step 0 is the recorded pitch. Each pickup in a chain adds one semitone.
static func gem_chain_semitones(step: int) -> float:
	return float(clampi(step, 0, GEM_CHAIN_CAP))

## Level 1 is the file as mastered. One semitone per level above that, capped at +12.
static func power_level_semitones(level: int) -> float:
	return float(clampi(level - 1, 0, POWER_LEVEL_PITCH_CAP))

static func power_level_pitch(level: int) -> float:
	return semitone_to_pitch(power_level_semitones(level))

static func reveal_event_for_card(card: String) -> String:
	for id in [FormCatalog.Id.SLIME, FormCatalog.Id.GOBLIN, FormCatalog.Id.VENDING, FormCatalog.Id.CAT, FormCatalog.Id.DEMON]:
		var title := FormCatalog.title_card(id)
		if card == title or card.ends_with(title):
			return reveal_event_for_form(id)
	if card == VENDING_TITLE or card.ends_with(VENDING_TITLE):
		return "reveal_vending_machine"
	return ""

## Death sting at the hit. The signature is scheduled by signature_start so a
## 1 s file is not cut off when the card arrives at 1.2 s.
static func cues_for_death_transition(previous: String, stage: String, form_id: int = -1) -> PackedStringArray:
	var cues := PackedStringArray()
	if stage == "hit" and previous != "hit":
		cues.append(death_event_for_form(form_id))
	return cues

static func death_event_seconds(event: String) -> float:
	if event == "player_death" or event.begins_with("player_death_"):
		return 0.0
	if event == "reborn_tease" or event == SIGNATURE_EVENT:
		return signature_start(float(spec(SIGNATURE_EVENT).get("duration", 1.0)))
	return -1.0

static func semitone_to_pitch(semitones: float) -> float:
	return pow(2.0, semitones / 12.0)

## unit is 0..1. 0 is -8%, 1 is +8%, 0.5 is the recorded pitch.
static func shot_pitch_scale(unit: float) -> float:
	return lerpf(1.0 - SHOT_PITCH_RATIO, 1.0 + SHOT_PITCH_RATIO, clampf(unit, 0.0, 1.0))

## Web plays the loop as a sample so the single-threaded export does not garble it.
## Desktop streams the same ogg. The page must report a running context first.
static func music_playback_type(web: bool) -> AudioServer.PlaybackType:
	if web:
		return AudioServer.PLAYBACK_TYPE_SAMPLE
	return AudioServer.PLAYBACK_TYPE_STREAM

## unit_magnitude and unit_sign are each 0..1. Magnitude stays in 1..2 semitones.
static func pop_semitones(unit_magnitude: float, unit_sign: float) -> float:
	var magnitude := lerpf(POP_SEMITONE_MIN, POP_SEMITONE_MAX, clampf(unit_magnitude, 0.0, 1.0))
	var sign := -1.0 if unit_sign < 0.5 else 1.0
	return sign * magnitude

static func overlap_voices(rate: float, duration: float) -> int:
	if rate <= 0.0 or duration <= 0.0:
		return 0
	return int(ceil(rate * duration - 0.0001))

## Voices in use across a capped burst, and how many shots were cut off early.
static func simulate_burst(rate: float, duration: float, cap: int, seconds: float) -> Dictionary:
	var ends: Array[float] = []
	ends.resize(maxi(cap, 0))
	var max_active := 0
	var stolen := 0
	if cap <= 0 or rate <= 0.0:
		return {"max_active": 0, "stolen": 0}
	var t := 0.0
	var step := 1.0 / rate
	var guard := 0
	while t < seconds - 0.00001 and guard < 10000:
		guard += 1
		var voice := -1
		for i in cap:
			if ends[i] <= t + 0.00001:
				voice = i
				break
		if voice < 0:
			voice = 0
			var oldest := ends[0]
			for i in cap:
				if ends[i] < oldest:
					oldest = ends[i]
					voice = i
			if ends[voice] > t + 0.00001:
				stolen += 1
		ends[voice] = t + duration
		var active := 0
		for i in cap:
			if ends[i] > t + 0.00001:
				active += 1
		max_active = maxi(max_active, active)
		t += step
	return {"max_active": max_active, "stolen": stolen}

static func prepare_stream(stream: AudioStream, event: String) -> AudioStream:
	var data := spec(event)
	if stream is AudioStreamOggVorbis and bool(data.get("loop", false)):
		var ogg := stream as AudioStreamOggVorbis
		ogg.loop = true
		ogg.loop_offset = float(data.get("loop_offset", 0.0))
		return ogg
	if stream is AudioStreamWAV and int(data.get("loop_end", 0)) > 0:
		var wav := stream.duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = int(data.get("loop_begin", 0))
		wav.loop_end = int(data.get("loop_end", -1))
		return wav
	return stream

static func ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	return idx

static func apply_bus_levels() -> void:
	var music := ensure_bus(MUSIC_BUS)
	var sfx := ensure_bus(SFX_BUS)
	AudioServer.set_bus_volume_db(music, MUSIC_BUS_DB)
	AudioServer.set_bus_volume_db(sfx, SFX_BUS_DB)
	AudioServer.set_bus_send(music, "Master")
	AudioServer.set_bus_send(sfx, "Master")

static func read_enabled(path: String = SETTINGS_PATH) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return true
	return bool(cfg.get_value("audio", "enabled", true))

static func write_enabled(on: bool, path: String = SETTINGS_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("audio", "enabled", on)
	cfg.save(path)
