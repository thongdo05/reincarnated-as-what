extends RefCounted
class_name DragonAudio

## Approved dragon-phase audio (Thong, 4 Nov 2026).
## Hook names in DragonPhase stay as they are. canonical() maps each
## one onto the event in audio/dragon_manifest.json.
## Return-upgrade hooks have no sample in that pack, so they stay silent.

const MUSIC_PATH := "res://audio/music/music_dragon_phase.ogg"
const BPM := 140.0
const BAR_BEATS := 4
const BREATH_LOOP_DELAY := 0.70
const BREATH_END_DELAY := 2.05
const LAIR_LEAD_SILENCE := 0.5

const HOOK_EVENT := {
	"sfx_dragon_enemy_ember_bat_attack": "dragon_enemy_ember_bat_attack",
	"sfx_dragon_enemy_ember_bat_death": "dragon_enemy_ember_bat_death",
	"sfx_dragon_enemy_kobold_torchbearer_attack": "dragon_enemy_kobold_torchbearer_firebomb_throw",
	"sfx_dragon_enemy_kobold_torchbearer_death": "dragon_enemy_kobold_torchbearer_death",
	"sfx_dragon_enemy_dragon_egg_hatch": "dragon_enemy_dragon_egg_hatch",
	"sfx_dragon_enemy_dragon_egg_death": "dragon_enemy_dragon_egg_break",
	"sfx_dragon_enemy_whelp_attack": "dragon_enemy_whelp_spit",
	"sfx_dragon_enemy_whelp_death": "dragon_enemy_whelp_death",
	"sfx_dragon_enemy_ember_wyvern_attack": "dragon_enemy_ember_wyvern_dive_attack",
	"sfx_dragon_enemy_ember_wyvern_death": "dragon_enemy_ember_wyvern_death",
	"sfx_dragon_enemy_magma_slime_attack": "dragon_enemy_magma_slime_split",
	"sfx_dragon_enemy_magma_slime_death": "dragon_enemy_magma_slime_death",
	"sfx_dragon_enemy_drake_rider_attack": "dragon_enemy_drake_rider_bolt",
	"sfx_dragon_enemy_drake_rider_death": "dragon_enemy_drake_rider_death",
	"sfx_dragon_enemy_dragon_cultist_attack": "dragon_enemy_dragon_cultist_cast",
	"sfx_dragon_enemy_dragon_cultist_death": "dragon_enemy_dragon_cultist_death",
	"sfx_dragon_enemy_ash_wraith_attack": "dragon_enemy_ash_wraith_ring_attack",
	"sfx_dragon_enemy_ash_wraith_death": "dragon_enemy_ash_wraith_death",
	"sfx_dragon_enemy_elder_drake_attack": "dragon_enemy_elder_drake_breath_cone",
	"sfx_dragon_enemy_elder_drake_death": "dragon_enemy_elder_drake_death",
	"sfx_dragon_tier_up": "dragon_tier_up",
	"sfx_dragon_ability_sky_breath": "great_dragon_breath_warning",
	"sfx_dragon_ability_ember_fan": "great_dragon_fireball_spread",
	"sfx_dragon_ability_dive": "great_dragon_dive_swoop",
	"sfx_dragon_ability_wing_gust": "great_dragon_wing_gust",
	"sfx_dragon_ability_boss_meteor": "great_dragon_meteor_warning",
	"sfx_dragon_ability_hell_breath": "great_dragon_enrage_breath",
}

const CUES := {
	"great_dragon_entrance": {"file": "res://audio/sfx_dragon_entrance.wav", "bus": "SFX", "loop": false, "lufs": -18.5, "duration": 2.77, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_transform": {"file": "res://audio/sfx_dragon_transform.wav", "bus": "SFX", "loop": false, "lufs": -19.1, "duration": 1.4, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_slain": {"file": "res://audio/sting_dragon_slain.wav", "bus": "SFX", "loop": false, "lufs": -19.2, "duration": 2.04, "polyphony": 1, "pitch_semitones": 0.0},
	"dragon_phase_bgm": {"file": "res://audio/music/music_dragon_phase.ogg", "bus": "Music", "loop": true, "lufs": -22.0, "duration": 54.857, "polyphony": 1, "pitch_semitones": 0.0, "loop_offset": 0.0},
	"great_dragon_phase_roar": {"file": "res://audio/sfx_dragon_phase_roar.wav", "bus": "SFX", "loop": false, "lufs": -17.4, "duration": 1.26, "polyphony": 4, "pitch_semitones": 0.0},
	"great_dragon_breath_warning": {"file": "res://audio/sfx_dragon_breath_warning.wav", "bus": "SFX", "loop": false, "lufs": -21.4, "duration": 0.75, "polyphony": 4, "pitch_semitones": 0.0},
	"great_dragon_breath_loop": {"file": "res://audio/sfx_dragon_breath_loop.wav", "bus": "SFX", "loop": true, "lufs": -21.1, "duration": 2.0, "polyphony": 1, "pitch_semitones": 0.0, "loop_begin": 0, "loop_end": 96000},
	"great_dragon_breath_end": {"file": "res://audio/sfx_dragon_breath_end.wav", "bus": "SFX", "loop": false, "lufs": -21.0, "duration": 0.86, "polyphony": 4, "pitch_semitones": 0.0},
	"great_dragon_fireball_spread": {"file": "res://audio/sfx_dragon_fireball_spread.wav", "bus": "SFX", "loop": false, "lufs": -19.1, "duration": 0.6, "polyphony": 3, "pitch_semitones": 0.0},
	"great_dragon_ember_burst": {"file": "res://audio/sfx_dragon_ember_burst.wav", "bus": "SFX", "loop": false, "lufs": -21.0, "duration": 0.43, "polyphony": 8, "pitch_semitones": 0.0},
	"great_dragon_dive_swoop": {"file": "res://audio/sfx_dragon_dive_swoop.wav", "bus": "SFX", "loop": false, "lufs": -21.1, "duration": 1.14, "polyphony": 4, "pitch_semitones": 0.0},
	"great_dragon_wing_gust": {"file": "res://audio/sfx_dragon_wing_gust.wav", "bus": "SFX", "loop": false, "lufs": -21.4, "duration": 0.71, "polyphony": 4, "pitch_semitones": 0.0},
	"great_dragon_meteor_warning": {"file": "res://audio/sfx_dragon_meteor_warning.wav", "bus": "SFX", "loop": false, "lufs": -21.8, "duration": 1.2, "polyphony": 4, "pitch_semitones": 0.0},
	"great_dragon_meteor_impact": {"file": "res://audio/sfx_dragon_meteor_impact.wav", "bus": "SFX", "loop": false, "lufs": -17.8, "duration": 1.04, "polyphony": 6, "pitch_semitones": 0.0},
	"great_dragon_enrage_breath": {"file": "res://audio/sfx_dragon_enrage_breath.wav", "bus": "SFX", "loop": false, "lufs": -19.1, "duration": 2.59, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_lair_transition": {"file": "res://audio/sfx_dragon_lair_transition.wav", "bus": "SFX", "loop": false, "lufs": -24.0, "duration": 2.5, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_form_shot": {"file": "res://audio/sfx_dragonform_shot.wav", "bus": "SFX", "loop": false, "lufs": -20.0, "duration": 0.2, "polyphony": 3, "pitch_semitones": 0.0, "volume_db": -10.0, "pitch_ratio": 0.08, "min_interval": 0.25},
	"dragon_form_fireball_explode": {"file": "res://audio/sfx_dragonform_fireball_explode.wav", "bus": "SFX", "loop": false, "lufs": -22.0, "duration": 0.337, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_form_meteor_ready": {"file": "res://audio/sfx_dragonform_meteor_ready.wav", "bus": "SFX", "loop": false, "lufs": -19.7, "duration": 0.6, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_form_meteor_charge": {"file": "res://audio/sfx_dragonform_meteor_charge.wav", "bus": "SFX", "loop": false, "lufs": -20.5, "duration": 1.0, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_form_meteor_fall": {"file": "res://audio/sfx_dragonform_meteor_fall.wav", "bus": "SFX", "loop": false, "lufs": -26.1, "duration": 0.398, "polyphony": 16, "pitch_semitones": 0.0},
	"dragon_form_meteor_impact": {"file": "res://audio/sfx_dragonform_meteor_impact.wav", "bus": "SFX", "loop": false, "lufs": -25.7, "duration": 0.468, "polyphony": 16, "pitch_semitones": 0.0},
	"dragon_form_giant_meteor": {"file": "res://audio/sfx_dragonform_giant_meteor.wav", "bus": "SFX", "loop": false, "lufs": -20.2, "duration": 2.521, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_form_screen_flash": {"file": "res://audio/sfx_dragonform_screen_flash.wav", "bus": "SFX", "loop": false, "lufs": -20.0, "duration": 0.5, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_ash_wraith_death": {"file": "res://audio/sfx_enemy_ash_wraith_death.wav", "bus": "SFX", "loop": false, "lufs": -21.9, "duration": 0.731, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_ash_wraith_phase_in": {"file": "res://audio/sfx_enemy_ash_wraith_phase_in.wav", "bus": "SFX", "loop": false, "lufs": -23.0, "duration": 0.482, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_ash_wraith_phase_out": {"file": "res://audio/sfx_enemy_ash_wraith_phase_out.wav", "bus": "SFX", "loop": false, "lufs": -24.4, "duration": 0.582, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_ash_wraith_ring_attack": {"file": "res://audio/sfx_enemy_ash_wraith_ring_attack.wav", "bus": "SFX", "loop": false, "lufs": -22.8, "duration": 0.544, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_dragon_cultist_cast": {"file": "res://audio/sfx_enemy_dragon_cultist_cast.wav", "bus": "SFX", "loop": false, "lufs": -23.8, "duration": 0.45, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_dragon_cultist_death": {"file": "res://audio/sfx_enemy_dragon_cultist_death.wav", "bus": "SFX", "loop": false, "lufs": -20.8, "duration": 0.654, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_dragon_cultist_shield_down": {"file": "res://audio/sfx_enemy_dragon_cultist_shield_down.wav", "bus": "SFX", "loop": false, "lufs": -23.4, "duration": 0.6, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_dragon_cultist_shield_up": {"file": "res://audio/sfx_enemy_dragon_cultist_shield_up.wav", "bus": "SFX", "loop": false, "lufs": -23.7, "duration": 0.6, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_dragon_egg_break": {"file": "res://audio/sfx_enemy_dragon_egg_break.wav", "bus": "SFX", "loop": false, "lufs": -19.0, "duration": 0.5, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_dragon_egg_crack": {"file": "res://audio/sfx_enemy_dragon_egg_crack.wav", "bus": "SFX", "loop": false, "lufs": -24.7, "duration": 0.35, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_dragon_egg_hatch": {"file": "res://audio/sfx_enemy_dragon_egg_hatch.wav", "bus": "SFX", "loop": false, "lufs": -22.6, "duration": 0.591, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_drake_rider_bolt": {"file": "res://audio/sfx_enemy_drake_rider_bolt.wav", "bus": "SFX", "loop": false, "lufs": -22.0, "duration": 0.279, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_drake_rider_death": {"file": "res://audio/sfx_enemy_drake_rider_death.wav", "bus": "SFX", "loop": false, "lufs": -20.2, "duration": 0.9, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_elder_drake_breath_cone": {"file": "res://audio/sfx_enemy_elder_drake_breath_cone.wav", "bus": "SFX", "loop": false, "lufs": -23.7, "duration": 1.117, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_elder_drake_breath_telegraph": {"file": "res://audio/sfx_enemy_elder_drake_breath_telegraph.wav", "bus": "SFX", "loop": false, "lufs": -22.9, "duration": 0.904, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_elder_drake_death": {"file": "res://audio/sfx_enemy_elder_drake_death.wav", "bus": "SFX", "loop": false, "lufs": -21.8, "duration": 1.162, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_elder_drake_gem_pickup": {"file": "res://audio/sfx_enemy_elder_drake_gem_pickup.wav", "bus": "SFX", "loop": false, "lufs": -19.7, "duration": 0.624, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_ember_bat_attack": {"file": "res://audio/sfx_enemy_ember_bat_attack.wav", "bus": "SFX", "loop": false, "lufs": -23.9, "duration": 0.284, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_ember_bat_death": {"file": "res://audio/sfx_enemy_ember_bat_death.wav", "bus": "SFX", "loop": false, "lufs": -20.7, "duration": 0.45, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_ember_wyvern_death": {"file": "res://audio/sfx_enemy_ember_wyvern_death.wav", "bus": "SFX", "loop": false, "lufs": -20.8, "duration": 0.825, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_ember_wyvern_dive_attack": {"file": "res://audio/sfx_enemy_ember_wyvern_dive_attack.wav", "bus": "SFX", "loop": false, "lufs": -22.9, "duration": 0.576, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_ember_wyvern_dive_warning": {"file": "res://audio/sfx_enemy_ember_wyvern_dive_warning.wav", "bus": "SFX", "loop": false, "lufs": -22.4, "duration": 0.547, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_kobold_torchbearer_death": {"file": "res://audio/sfx_enemy_kobold_torchbearer_death.wav", "bus": "SFX", "loop": false, "lufs": -20.8, "duration": 0.6, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_kobold_torchbearer_firebomb_throw": {"file": "res://audio/sfx_enemy_kobold_torchbearer_firebomb_throw.wav", "bus": "SFX", "loop": false, "lufs": -25.4, "duration": 0.4, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_magma_puddle_sizzle_loop": {"file": "res://audio/sfx_enemy_magma_puddle_sizzle_loop.wav", "bus": "SFX", "loop": true, "lufs": -31.2, "duration": 1.8, "polyphony": 1, "pitch_semitones": 0.0, "loop_begin": 0, "loop_end": 86400},
	"dragon_enemy_magma_slime_death": {"file": "res://audio/sfx_enemy_magma_slime_death.wav", "bus": "SFX", "loop": false, "lufs": -20.8, "duration": 0.536, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_magma_slime_move": {"file": "res://audio/sfx_enemy_magma_slime_move.wav", "bus": "SFX", "loop": false, "lufs": -24.1, "duration": 0.4, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_magma_slime_split": {"file": "res://audio/sfx_enemy_magma_slime_split.wav", "bus": "SFX", "loop": false, "lufs": -23.3, "duration": 0.545, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_whelp_death": {"file": "res://audio/sfx_enemy_whelp_death.wav", "bus": "SFX", "loop": false, "lufs": -20.0, "duration": 0.6, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_enemy_whelp_spit": {"file": "res://audio/sfx_enemy_whelp_spit.wav", "bus": "SFX", "loop": false, "lufs": -24.8, "duration": 0.3, "polyphony": 4, "pitch_semitones": 0.0},
	"dragon_tier_up": {"file": "res://audio/sting_dragon_tier_up.wav", "bus": "SFX", "loop": false, "lufs": -19.3, "duration": 2.821, "polyphony": 1, "pitch_semitones": 0.0},
}


static func bar_seconds() -> float:
	return float(BAR_BEATS) * 60.0 / BPM

static func canonical(event: String) -> String:
	if HOOK_EVENT.has(event):
		return str(HOOK_EVENT[event])
	return event

static func is_tier(event: String) -> bool:
	return canonical(event) == "dragon_tier_up"

static func is_breath_warning(event: String) -> bool:
	return canonical(event) == "great_dragon_breath_warning"

static func spec(event: String) -> Dictionary:
	var key := canonical(event)
	if not CUES.has(key):
		return {}
	var src: Dictionary = CUES[key]
	return src.duplicate()

static func player_events() -> PackedStringArray:
	var names := PackedStringArray()
	for key in CUES.keys():
		var ev := str(key)
		if ev == "dragon_phase_bgm" or ev == "dragon_slain":
			continue
		names.append(ev)
	return names

## Every manifest event, including music. Used by the pack check.
static func manifest_events() -> PackedStringArray:
	var names := PackedStringArray()
	for key in CUES.keys():
		names.append(str(key))
	return names

