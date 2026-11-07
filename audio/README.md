# Audio (TEST)

These are **test assets**. The loop, death, evolve, and slime shot are from Hibiki, 1 Nov 2026, made with ElevenLabs. The form shots and pickups are from 3 Nov 2026. They are not the final mix. Loudness, loop, and timing notes live in `manifest.json`. The game plays the files as mastered, then the buses pull the loop forward: Music at -6 dB, SFX at -12 dB. Each form's shot player is another -10 dB. If a cue's file is missing, that cue is skipped.

The reborn tease ships as `sting_reborn_tease.ogg` (about 15 KB). The same sting's WAV is about 96 KB and is not in the project.

## Hookup

| File | When |
| --- | --- |
| `music_gameplay_loop.ogg` | Sky Castle, from the title card on, and any world whose own loop is not imported yet. `loop` on, `loop_offset` 0. Desktop streams the ogg. The web export plays that same file as a sample. Volume, mute, and the loop stay as they are. |
| `music/world_<slug>.ogg` | Neon Tokyo, Office Hell, Underworld, Candy Kingdom, Ice Tundra, and Sunken Ruins. A reincarnation crossfades to that world's loop in about 0.4 seconds. Each file is looped from the start (`LOOPSTART=0`, `LOOPLENGTH` is the whole file). A slug with no file still falls back to `music_gameplay_loop.ogg`. |
| `sfx_shot_slime.wav` | Slime auto-fire, once per volley (a rank 3 triple is still one bloop). Heard at most about 4 times a second, -10 dB on the player, pitch +/- 8%. |
| `sfx_shot_goblin.wav` | Goblin auto-fire. Same cap, trim, and pitch as the slime shot. |
| `sfx_shot_vending_machine.wav` | Vending Machine auto-fire. Same cap, trim, and pitch. The file sits at about -20.8 LUFS. |
| `sfx_shot_cat.wav` | Cat auto-fire. Same cap, trim, and pitch. |
| `sfx_shot_demon_lord.wav` | Demon Lord auto-fire. Same cap, trim, and pitch. |
| `sfx_pickup_gem.wav` | A gem pickup. Up to 4 voices, at most about every 0.05 s. Each gem in a quick chain is one semitone higher, up to +7, and the chain resets after about 0.6 s with no pickup. |
| `sfx_pickup_power.wav` | OVERDRIVE and the other rare power drops (bomb, shield, rapid, magnet). One voice. |
| `sfx_power_level_up.wav` | Power level-up after the final form. Once per increase, even if several levels land in one step. Pitch rises one semitone per level above 1, capped at +12. Gem pickups duck 5 dB for 0.25 s while it plays. |
| `sfx_enemy_pop.wav` | Enemy killed. Pitch is random by 1–2 semitones, up or down. |
| `sfx_death.wav` | Fallback for every `player_death_<form>` hook. Starts at the hit. The file is still the 0.92 s recording. |
| `sting_reborn_tease.ogg` | Fallback for `sting_reincarnation_signature`. The file is 1.0 s. It starts at 0.20 s so it finishes as the 1.2 s card opens, instead of being cut off. |
| `sfx_evolve.wav` | Evolve frame 0. The fanfare hit is at 0.42 s, on the `EVOLVED!` pop (frame 5). |
| `sting_reveal_vending_machine.wav` | Fallback for `reveal_vending_machine`. The file is 1.6 s. It fades out (about 0.08 s) when play begins, including a tap that skips the card, so it does not keep playing into the run. |
| `new_best.wav` | NEW BEST on the death card. The approved 0.70 s stereo file. It replaces the enemy pop at that moment and plays as mastered. |
| `sfx_boss_lich_king_enter.wav` | Lich King enters. Same bus level as the other stings. No pitch shift. |
| `sfx_boss_lich_king_death.wav` | Lich King dies. Same level, no pitch shift. Being cleared for the dragon, without dying, stays silent. |
| `sfx_boss_death_knight_enter.wav` | Death Knight enters. Same level, no pitch shift. |
| `sfx_boss_death_knight_death.wav` | Death Knight dies. Same level, no pitch shift. Being cleared for the dragon, without dying, stays silent. |
| `sfx_boss_great_dragon_enter.wav` | Great Dragon enters. Same level, no pitch shift. |
| `sfx_boss_great_dragon_death.wav` | Great Dragon dies. Same level, no pitch shift. |
| `sting_dragon_slain.wav` | DRAGON SLAIN banner. Plays with `sfx_dragon_lair_transition.wav` (that file keeps its opening 0.5 s of silence). |
| `music/music_dragon_phase.ogg` | Dragon-phase loop from the transform until death, on every map. |
| `audio/dragon_manifest.json` | The other 58 dragon cues. Each event name is wired in `scripts/dragon_audio.gd`. The five return-upgrade cues play once per fight, over the attack sound. |

Untapped death, with no tap, reaches the game-over card in 1.2 s. The stages keep their old proportions: hit 0–0.1043 s, pop to 0.2609 s, puff to 0.4696 s, hold to 0.5739 s, then `REBORN AS...?` until 1.2000 s. A tap still skips straight to the card. The 0.25 s card guard, the 0.48 s retry reveal, and the 1.5 s invulnerability are unchanged.

Drop-in hooks load `res://audio/<event>.ogg` if that file exists, otherwise `res://audio/<event>.wav`. `new_best` is the one shipped file. The other hooks still play today's sound (or stay silent) until a file is added. Death and `new_best` stop on skip and on retry, and they do not delay the tap. `reveal_<form>` fades out when play begins.

| Hook | Fallback today | Drop-in file |
| --- | --- | --- |
| `player_death_slime` | `sfx_death.wav` | `audio/player_death_slime.ogg` or `.wav` |
| `player_death_vending_machine` | `sfx_death.wav` | `audio/player_death_vending_machine.ogg` or `.wav` |
| `player_death_goblin` | `sfx_death.wav` | `audio/player_death_goblin.ogg` or `.wav` |
| `player_death_cat` | `sfx_death.wav` | `audio/player_death_cat.ogg` or `.wav` |
| `player_death_demon_lord` | `sfx_death.wav` | `audio/player_death_demon_lord.ogg` or `.wav` |
| `player_death_dragon` | `sfx_death.wav` | `audio/player_death_dragon.ogg` or `.wav` |
| `sting_reincarnation_signature` | `sting_reborn_tease.ogg` | `audio/sting_reincarnation_signature.ogg` or `.wav` |
| `new_best` | shipped: `audio/new_best.wav` | `audio/new_best.ogg` would replace the wav |
| `reveal_slime` | silent | `audio/reveal_slime.ogg` or `.wav` |
| `reveal_vending_machine` | `sting_reveal_vending_machine.wav` | `audio/reveal_vending_machine.ogg` or `.wav` |
| `reveal_goblin` | silent | `audio/reveal_goblin.ogg` or `.wav` |
| `reveal_cat` | silent | `audio/reveal_cat.ogg` or `.wav` |
| `reveal_demon_lord` | silent | `audio/reveal_demon_lord.ogg` or `.wav` |
| `reveal_dragon` | silent | `audio/reveal_dragon.ogg` or `.wav` |

Each form uses its own shot file. The slime bloop is not reused.

iOS Safari will not start the audio context until a tap, and Godot 4.7 keeps `GodotAudio` inside the engine, so the page cannot read `GodotAudio.ctx`. The shell catches the `AudioContext` the engine constructs and resumes it on the first touch, on the speaker-off mark, and when the tab becomes visible again. The loop starts once that context reports `running`. WAV shots do not wait on that check. A later run in the same tab starts the music on its own, because the context is already running. While the context is locked, or the loop never started, a speaker-off mark sits under SND.
