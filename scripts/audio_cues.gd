extends RefCounted
class_name AudioCues

## TEST audio from Hibiki, 1 Nov 2026 (ElevenLabs sample, not the final mix).
## Files are already at the loudness in audio/manifest.json. The buses pull
## the loop above the stings: Music at -6 dB, SFX at -12 dB. The slime shot
## is another -10 dB on its player, and it is capped at about 4 plays a second.
## See audio/README.md.

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

## Fanfare chord inside sfx_evolve.wav. Evolve frame 5, the EVOLVED! pop.
const EVOLVE_HIT_SECONDS := 0.42

## Plays with the Vending Machine title card. The other forms stay silent.
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
				"pitch_ratio": SHOT_PITCH_RATIO,
				"volume_db": SHOT_VOLUME_DB,
				"min_interval": SHOT_MIN_INTERVAL,
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

## Only the slime has a shot sample. The other forms stay silent.
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
