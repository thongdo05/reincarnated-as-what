# Capture mode

Flags for recording a specific moment. With no flags the game is unchanged: same daily form, same spawns, same best-score save.

A capture run does not write best scores and does not advance the saved daily-run index. There is no leaderboard in this build; the best-score file is the only score record.

## Flags

On the web export, put them in the page query string:

`https://thongdo05.github.io/reincarnated-as-what/?form=goblin&rank=3&clean=1`

On desktop, put them after `--`:

```
godot --path . -- --form=goblin --rank=3 --clean=1
```

If both are present, the query string wins.

| Flag | Values | Effect |
| --- | --- | --- |
| `form` | `slime`, `goblin`, `vending_machine`, `cat`, `demon_lord` | Forces the form for that run. All five play. A retry after a challenged form rolls a different form. |
| `seed` | integer | Forces the day seed, so the spawn timeline repeats. |
| `clean` | `1` | Hides the D pacing overlay, hitbox draw, the invincibility label, and the engine collision / path / navigation debug hints. Blocks the H and D debug keys. Arrow keys and WASD still move. |
| `hitbox` | `1` | Draws the hurt, body, and threat shapes. Works on a normal run (`?hitbox=1`) without the other capture flags. `clean=1` hides them. |
| `rank` | `1` through `5` | Starts the run at that rank. The meter matches the gate. |
| `evo` | `1` | The E key grants enough points to reach the next rank, through the real EVOLVED! / FINAL FORM! FX. Four presses go from rank 1 to rank 5. |
| `hazard` | `piano` | A piano falls on the player's lane. Other hits do not end the run before it lands, and a Slime does not spend its split on it, so the clip is the piano death. Until the piano connects, a small `INVINCIBLE (until piano)` label sits under the HUD. `clean=1` hides it. At the end of the `REBORN AS...?` tease the next run's title card starts. Omit `form` if that next card should be the other form in the day's order. |
| `hazard_t` | seconds | When the piano lands, measured from the first frame, title card included. Default `6`. The card is 1.5s and the fall needs about 3s, so values under about 4.5s can miss the kill. |
| `invuln` | `1` | The player cannot die. This wins over `hazard=piano`. A small `INVINCIBLE (invuln=1)` label sits under the HUD, including on the title card, so a bookmarked link is not mistaken for a bug. `clean=1` hides that label. |

`clean=1` does not hide the score, the clock, or the evolution meter. Those are the game HUD.

## tools/capture.sh

Records with Godot Movie Maker at a fixed 60 fps, then ffmpeg scales 4× nearest-neighbour to 1920×1080 H.264 (`yuv420p`, crf 16). If Movie Maker wrote an audio track, it is encoded as AAC in the mp4.

```
tools/capture.sh <seconds> <output.mp4> [flag ...]
```

Godot 4.7 cannot record a movie with `--headless`: the dummy renderer crashes on the viewport texture, and that mode forces a silent audio driver. The script uses a real GL context (`opengl3`). When `DISPLAY` is unset it re-runs itself under `xvfb-run`. The window stays up while the clip records, so E and the movement keys work. Set `GODOT` if the 4.7 binary is not on `PATH`.

Movie Maker audio is recorded on this path: the AVI carries 48 kHz stereo PCM, and the script encodes it as AAC in the mp4. A checked 5s Slime clip measured about -29 dB mean, so the track is not silence. Godot prints a "resources still in use" line as the process exits while the music player is still up. The mp4 is already written, and the script still succeeds. `--headless` itself would be silent and would not write frames.

### Form reveals

The title card lasts 1.5s. Four seconds covers the card and a short beat after it. All five forms enter play after the card.

```
tools/capture.sh 4 build/capture/reveal_slime.mp4 form=slime clean=1
tools/capture.sh 4 build/capture/reveal_goblin.mp4 form=goblin clean=1
tools/capture.sh 5 build/capture/reveal_vending_machine.mp4 form=vending_machine clean=1
tools/capture.sh 5 build/capture/reveal_cat.mp4 form=cat clean=1
tools/capture.sh 5 build/capture/reveal_demon_lord.mp4 form=demon_lord clean=1
```

The vending-machine card is the one with a title sting. Cat and Demon Lord are silent on the card.

### Piano death into the next reveal

About 1.5s of card, the landing at 6s, the death burst, `REBORN AS...?`, then the next form's title card. Twelve seconds covers that handoff. No `form` flag, so the second card is the other form in the seeded order.

```
tools/capture.sh 12 build/capture/piano_death.mp4 hazard=piano seed=20261101 clean=1
```

`hazard_t=8` lands the piano two seconds later. Add that time to the clip length.

### Slime, rank 1 to rank 5

`evo=1` waits for the E key. The window is open during the recording. After the title card, press E for each rank. The fourth press is FINAL FORM!. `invuln=1` keeps the run alive while you do it.

```
tools/capture.sh 10 build/capture/slime_r1_r3.mp4 form=slime evo=1 invuln=1 clean=1 seed=1
```

The same flags without the script, if you only need the window:

```
godot --path . -- --form=slime --evo=1 --invuln=1 --clean=1 --seed=1
```

### Normal gameplay

```
tools/capture.sh 10 build/capture/gameplay_slime.mp4 form=slime clean=1 seed=1
```

Leave `form` off to record whatever the daily order would have dealt. `invuln=1` is the clean survival take. Without it, the run can end when something hits.
