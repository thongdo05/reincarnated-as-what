# Audio (TEST)

These are **test assets** from Hibiki, 1 Nov 2026, made with ElevenLabs for the sample pass. They are not the final mix. Loudness, loop, and timing notes live in `manifest.json` (copied from that delivery). The game plays the files as mastered: the Music and SFX buses stay at 0 dB.

The reborn tease ships as `sting_reborn_tease.ogg` (about 15 KB). The same sting's WAV is about 96 KB and is not in the project.

## Hookup

| File | When |
| --- | --- |
| `music_gameplay_loop.ogg` | Every run, from the title card on. `loop` on, `loop_offset` 0. Stream playback so the seam stays a loop, not a restart. |
| `sfx_shot_slime.wav` | Slime auto-fire, once per volley. Already 3 LU under the pop. At most 3 voices, so an 8-per-second burst is not stacked or chopped. |
| `sfx_enemy_pop.wav` | Enemy killed. Pitch is random by 1–2 semitones, up or down. |
| `sfx_death.wav` | Death FX frame 0. The file is cut to the 0.92 s timeline. |
| `sting_reborn_tease.ogg` | Death frame 11 (0.92 s), as `REBORN AS...?` starts. |
| `sfx_evolve.wav` | Evolve frame 0. The fanfare hit is at 0.42 s, on the `EVOLVED!` pop (frame 5). |
| `sting_reveal_vending_machine.wav` | Only the Vending Machine title card. That form is not in the roster, so a normal run does not play it. `SoundRig.debug_play_vending_reveal()` plays it anyway. |

The Goblin has no shot file. Those stones stay silent. The slime bloop is not reused.

iOS Safari will not start the audio context until a tap. The web shell resumes Godot's context on the first touch or click, and the music player starts after that. A later run in the same tab starts the music on its own, because the context is already running.
