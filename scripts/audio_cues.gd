extends RefCounted
class_name AudioCues

## TEST audio from Hibiki, 1 Nov 2026 (ElevenLabs sample, not the final mix).
## Files are already at the loudness in audio/manifest.json, including the shot
## sitting 3 LU under the pop. Music and SFX buses stay at 0 dB so that mix
## is what plays. See audio/README.md.

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const BUS_VOLUME_DB := 0.0
const SETTINGS_PATH := "user://audio.cfg"

## 8 shots/s of a 0.22 s bloop is under 2 voices. Slime rank 3 fires every
## 0.10 s, about 2.2 voices. Three voices cover both without a pile-up.
const SHOT_POLYPHONY := 3
const SHOT_STRESS_RATE := 8.0
const SHOT_DURATION := 0.22
const POP_POLYPHONY := 4
const POP_SEMITONE_MIN := 1.0
const POP_SEMITONE_MAX := 2.0

## Fanfare chord inside sfx_evolve.wav. Evolve frame 5, the EVOLVED! pop.
const EVOLVE_HIT_SECONDS := 0.42

## Not a roster entry. play_title_card uses this when that form is added.
const VENDING_TITLE := "title_cards/title_vending_machine.png"

static func spec(event: String) -> Dictionary:
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
			return {
				"file": "res://audio/sfx_shot_slime.wav",
				"bus": SFX_BUS,
				"loop": false,
				"lufs": -20.0,
				"polyphony": SHOT_POLYPHONY,
				"pitch_semitones": 0.0,
				"duration": SHOT_DURATION,
			}
		"enemy_killed":
			return {
				"file": "res://audio/sfx_enemy_pop.wav",
				"bus": SFX_BUS,
				"loop": false,
				"lufs": -17.0,
				"polyphony": POP_POLYPHONY,
				"pitch_semitones": POP_SEMITONE_MAX,
			}
		"player_death":
			return {
				"file": "res://audio/sfx_death.wav",
				"bus": SFX_BUS,
				"loop": false,
				"lufs": -18.3,
				"polyphony": 1,
				"pitch_semitones": 0.0,
			}
		"reborn_tease":
			return {
				"file": "res://audio/sting_reborn_tease.ogg",
				"bus": SFX_BUS,
				"loop": false,
				"lufs": -18.7,
				"polyphony": 1,
				"pitch_semitones": 0.0,
			}
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
		"reveal_vending_machine":
			return {
				"file": "res://audio/sting_reveal_vending_machine.wav",
				"bus": SFX_BUS,
				"loop": false,
				"lufs": -19.3,
				"polyphony": 1,
				"pitch_semitones": 0.0,
			}
		_:
			return {}

static func all_events() -> PackedStringArray:
	return PackedStringArray([
		"gameplay_music",
		"slime_shot",
		"enemy_killed",
		"player_death",
		"reborn_tease",
		"evolve",
		"reveal_vending_machine",
	])

## Goblin stones have no sample. Leave them silent. Do not reuse the slime bloop.
static func shot_event_for_form(form_id: int) -> String:
	if form_id == FormCatalog.Id.SLIME:
		return "slime_shot"
	return ""

static func reveal_event_for_card(card: String) -> String:
	if card == VENDING_TITLE or card.ends_with(VENDING_TITLE):
		return "reveal_vending_machine"
	return ""

## Death sting at frame 0. Tease sting at frame 11, which is the 0.92 s handoff.
static func cues_for_death_transition(previous: String, stage: String) -> PackedStringArray:
	var cues := PackedStringArray()
	if stage == "hit" and previous != "hit":
		cues.append("player_death")
	if stage == "tease" and previous != "tease":
		cues.append("reborn_tease")
	return cues

static func death_event_seconds(event: String) -> float:
	if event == "player_death":
		return 0.0
	if event == "reborn_tease":
		return float(FxTimeline.DEATH_FRAMES) / FxTimeline.FPS
	return -1.0

static func semitone_to_pitch(semitones: float) -> float:
	return pow(2.0, semitones / 12.0)

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

static func prepare_stream(stream: AudioStream, event: String) -> void:
	var data := spec(event)
	if stream is AudioStreamOggVorbis and bool(data.get("loop", false)):
		var ogg := stream as AudioStreamOggVorbis
		ogg.loop = true
		ogg.loop_offset = float(data.get("loop_offset", 0.0))

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
	AudioServer.set_bus_volume_db(music, BUS_VOLUME_DB)
	AudioServer.set_bus_volume_db(sfx, BUS_VOLUME_DB)
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
