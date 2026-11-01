# Reincarnated as WHAT?!

Landscape side-scrolling shooter. You fly right while the ground scrolls left. Each run you are reborn as a different form. This prototype has two of them, Slime and Goblin, so the core loop can be judged in Safari on an iPhone held sideways.

Play it: https://thongdo05.github.io/reincarnated-as-what/

## Play

Turn the phone sideways. In portrait the game asks you to rotate instead of squashing the field.

Drag anywhere. The ship follows the drag, so your finger does not have to sit on it. You start in the left third and can drag anywhere on the screen. You fire forward, to the right, on your own. One life per run: a hit ends it. Tap **Reincarnate** for the next one. Arrow keys or WASD also move, for a desktop check.

The pause mark in the top-left is 18 pixels and is not scaled. Its touch target is at least 44 points, so a thumb can hit it on an iPhone. Tap it again, or press Esc, to resume.

The field is 480×270 and scales up by whole pixels, so the art stays sharp. On a desktop the window opens at 960×540, which is that field at 2×.

The form order and the enemy spawns come from the UTC date. Everyone gets the same order and the same spawns that day. Your place in the order is remembered in the browser. There is no leaderboard yet.

Score is kills, a combo when kills are chained, near-misses, and survival time. The form does not multiply it. The death card shows your best as that form and your best overall. Those two numbers stay in the browser. There is no online leaderboard.

- **Slime.** Blue jelly cube. Shots fly right and split in two when they hit. Movement keeps sliding after you stop. Its trait, not an extra life: the hit that would kill a full-size Slime swaps in the small slime of the same rank, with a short moment of safety and a `SPLIT!` pop. Stay alive 15 seconds and it grows back at the same rank, trait included. A hit while small ends the run. One life still holds. Ranks: Slime, Gel Knight, Ooze Titan.
- **Goblin.** Tiny crown. Stones lob forward and drop. Rank 2 and rank 3 use the larger stones. Movement is a short sprint, then a planted step. Kills drop a coin or a gem that drifts left. Touch one to pick it up for a score bonus. The slingshot does not level from a pickup count. Ranks: Goblin, Goblin Chief, Goblin King.

Kills, combos, near-misses, and Goblin pickups fill an evolution meter. The gates are placeholder constants. Each rank swaps in that rank's sprite and a stronger weapon, with an `EVOLVED!` pop. The death card names the highest rank, for example `Reborn as SLIME, reached OOZE TITAN`.

The field is the painted isekai sky: an opaque sky, then castles and floating islands, then hills, treetops, and crystals. The three layers are 480×270 and tile sideways, each faster than the one behind it.

Enemies come in from the right and are drawn facing left. A Floating Eye drifts, bobs, and fires a bolt. A Dire Wolf charges. A Skeleton Archer stands on the ground or rides a floating island and shoots arrows left. A Wyvern swoops in a wave and spits a fireball. An anvil or a piano sometimes falls. None of them is a slime or a goblin. Dire wolves and wyverns together stay at two on screen.

Hitboxes sit inside the painted sprites, about half to two thirds of the art, and grow a little when a form ranks up.

Each run opens on a title card, then about 1.5 seconds where you cannot die.

Vending Machine, Cat, and Demon Lord sprites are in the project and are not in this build. Demon Lord orbs are 4-frame pulse sheets, so a shot plays one cell at a time instead of the whole strip. When the vending machine is playable, its weapon has no random WINNER! burst. WINNER! is only the meter-triggered screen clear.

## Run locally

Godot **4.7.2**. https://godotengine.org/download

1. Open this folder in the Godot project manager.
2. Press F5. The window opens at 960×540.

Headless check:

```
godot --headless --path . --import --quit
godot --headless --path . -s res://tests/smoke.gd
godot --headless --path . --quit-after 240
```

Web export, after installing the matching export templates:

```
godot --headless --path . --export-release "Web" build/web/index.html
```

Serve `build/web` with any static file server and open it in a wide window.

## Phone site

The web export leaves thread support off. A threaded Godot build needs cross-origin headers that GitHub Pages does not send, and that build does not load in iOS Safari. The single-threaded build does.

`.github/workflows/pages.yml` exports the game and deploys it on every push to `main`.

Pages is already set to GitHub Actions. A green run on `main` updates https://thongdo05.github.io/reincarnated-as-what/ . The first load is the Godot web binary, so give it a moment on a phone. Hold the phone in landscape.

The iOS preset in `export_presets.cfg` is only a stub (bundle id, landscape project settings, GL Compatibility). It is not signed and it is not a TestFlight build.
