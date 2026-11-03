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
| `sfx_enemy_pop.wav` | Enemy killed. Pitch is random by 1–2 semitones, up or down. |
| `sfx_death.wav` | Death FX frame 0. The file is cut to the 0.92 s timeline. |
| `sting_reborn_tease.ogg` | Death frame 11 (0.92 s), as `REBORN AS...?` starts. |
| `sfx_evolve.wav` | Evolve frame 0. The fanfare hit is at 0.42 s, on the `EVOLVED!` pop (frame 5). |
| `sting_reveal_vending_machine.wav` | The Vending Machine title card. A run that opens as that form plays it. `SoundRig.debug_play_vending_reveal()` plays it anyway. |
| `sfx_boss_lich_king_enter.wav` | Lich King enters. Same bus level as the other stings. No pitch shift. |
| `sfx_boss_lich_king_death.wav` | Lich King dies. Same level, no pitch shift. A timeout flee stays silent. |
| `sfx_boss_death_knight_enter.wav` | Death Knight enters. Same level, no pitch shift. |
| `sfx_boss_death_knight_death.wav` | Death Knight dies. Same level, no pitch shift. A timeout flee stays silent. |
| `sfx_boss_great_dragon_enter.wav` | Great Dragon enters. Same level, no pitch shift. |
| `sfx_boss_great_dragon_death.wav` | Great Dragon dies. Same level, no pitch shift. |

Each form uses its own shot file. The slime bloop is not reused.

iOS Safari will not start the audio context until a tap, and Godot 4.7 keeps `GodotAudio` inside the engine, so the page cannot read `GodotAudio.ctx`. The shell catches the `AudioContext` the engine constructs and resumes it on the first touch, on the speaker-off mark, and when the tab becomes visible again. The loop starts once that context reports `running`. WAV shots do not wait on that check. A later run in the same tab starts the music on its own, because the context is already running. While the context is locked, or the loop never started, a speaker-off mark sits under SND.
