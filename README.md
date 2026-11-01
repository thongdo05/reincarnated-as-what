# Reincarnated as WHAT?!

Landscape side-scrolling shooter. You fly right while the ground scrolls left. Each run you are reborn as a different form, and a retry never repeats the form you just died as. This build plays five of them: Slime, Goblin, Vending Machine, Cat (ex-CEO), and Demon Lord.

Play it: https://thongdo05.github.io/reincarnated-as-what/

## Play

Turn the phone sideways. In portrait the game asks you to rotate instead of squashing the field.

Drag anywhere. The ship follows the drag, so your finger does not have to sit on it. You start in the left third and can drag anywhere on the screen. You fire forward, to the right, on your own. One life per run: a hit ends it. The first card of a visit is the full reveal. After that, tap through the death sting, then tap the card (or **Reincarnate**) and the next form is a short flash you can tap past. The very first run on a device is a wordless opening: a quiet drifter, a gem, and one shot, with a tiny ghost finger. Later runs use the short brutal pacing. Arrow keys or WASD also move, for a desktop check.

The pause mark in the top-right is 18 pixels and is not scaled. Its touch target is at least 44 points, so a thumb can hit it on an iPhone. Tap it again, or press Esc, to resume. Just under it, **SND** turns sound off and **OFF** turns it back on. That choice stays in the browser.

Sound is a test mix (Hibiki, 1 Nov 2026), not the final one. Music loops for the whole run. The Slime's shot is a quiet bloop. The other forms' shots stay silent until they have their own samples. A kill pops, death lines up with the burst, `REBORN AS...?` gets the tease sting, and `EVOLVED!` lands on the evolve hit. The vending-machine sting plays on that form's title card. On an iPhone, Safari stays quiet until the first tap. That tap is the title card or the first touch in the run, and the music starts then.

The field is 480×270 and scales up by whole pixels, so the art stays sharp. On a desktop the window opens at 960×540, which is that field at 2×.

The form order and the enemy spawns come from the UTC date. Everyone gets the same order and the same spawns that day. Your place in the order is remembered in the browser. There is no leaderboard yet.

Score is kills, a combo when kills are chained, near-misses, and survival time. The form does not multiply it. The death card shows your best as that form and your best overall. Those two numbers stay in the browser. There is no online leaderboard.

- **Slime.** Blue jelly cube. Shots fly right and split in two when they hit. Movement keeps sliding after you stop. Its trait, not an extra life: the hit that would kill a full-size Slime swaps in the small slime of the same rank, with a short moment of safety and a `SPLIT!` pop. Stay alive 15 seconds and it grows back at the same rank, trait included. A hit while small ends the run. One life still holds. Ranks: Slime, Gel Knight, Ooze Titan.
- **Goblin.** Tiny crown. Stones lob forward and drop. Each rock hits harder than a slime shot and pierces one target. Rank 2 and rank 3 use the larger stones and a wider arc. Movement snaps to the finger. Kills can drop a gem that drifts left. Touch one to add score and evolution points. The slingshot does not level from a pickup count. Ranks: Goblin, Goblin Chief, Goblin King.
- **Vending Machine.** Heavy drift: it trails the finger for a few frames and still finishes a flick. Three cans fly forward in a spread. There is no random burst. Kills fill a WINNER! meter, and a full meter is the only WINNER! screen clear in the game. Ranks: Vending Machine, Mega Vendor, Vending Fortress.
- **Cat (ex-CEO).** A hard flick blinks a short dash, then the body snaps the rest of the way. The swipe in front reflects enemy bullets. A streak of near-misses makes nearby enemies fight for you for a moment. Ranks: Cat (ex-CEO), Cat Chairman, Cat Overlord.
- **Demon Lord.** Large body. Big slow orbs home in, and they hit harder the more enemies are on screen. Ranks: Demon Lord, Demon Emperor, True Demon King.

Kills, combos, near-misses, and Goblin pickups fill an evolution meter. The gates are placeholder constants. Each rank swaps in that rank's sprite and a stronger weapon: a gold rim, a white flash, then an `EVOLVED!` banner. The run does not stop. A hit plays the death burst. Tap through it, then the card. The card shows the score large, the best as that form, and the best overall. A new best pops `NEW BEST!`. **Share** saves a picture of the run. **Challenge a friend** sends a link to the same daily seed and form, then the button reads `LINK COPIED!`. All five forms can start from that link. **Reincarnate**, or a tap on the card, starts the next one as a different form. A Challenge a Friend link (`?seed=&form=`) keeps that form for the challenged run only; the retry rolls again and still will not repeat the form you just died as. `?mode=flappy` and `?mode=hop` stay on Slime and Goblin.

The field is the painted isekai sky: an opaque sky, then castles and floating islands, then hills, treetops, and crystals. The three layers are 480×270 and tile sideways, each faster than the one behind it.

Enemies come in from the right and are drawn facing left. A Floating Eye drifts, bobs, and fires a bolt. A Dire Wolf charges. A Skeleton Archer stands on the ground or rides a floating island and shoots arrows left. A Wyvern swoops in a wave and spits a fireball. An anvil or a piano sometimes falls. None of them is a slime or a goblin. Dire wolves and wyverns together stay at two on screen.

Hit shapes are per sprite in `art/hitboxes.json`. A player shot connects when it touches the opaque body, including a long wolf or a wyvern wing. The player's hurtbox follows that same visible body, head and feet included, and leaves out the ink outline. Enemy bodies and shots kill when they overlap any part of it. Press **H** to draw them, or open the page with `?hitbox=1`: yellow is where shots connect, red is what can kill you, green is your body.

Each run opens on a title card, then about 1.5 seconds where you cannot die.

Demon Lord orbs are 4-frame pulse sheets, so a shot plays one cell at a time instead of the whole strip. The vending machine weapon has no random WINNER! burst. WINNER! is only that form's meter-triggered screen clear.

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

`.github/workflows/pages.yml` exports the game and deploys it on every push to `main`. The export stamps `index.js`, `index.wasm`, `index.pck`, and the other build files with the commit, and `index.html` checks `version.json` before starting the engine. The next page load after a deploy gets that build without clearing Safari data. `?mode=flappy`, `?mode=hop`, `?seed=`, and `?form=` stay on the URL.

Pages is already set to GitHub Actions. A green run on `main` updates https://thongdo05.github.io/reincarnated-as-what/ . The first load is the Godot web binary, so give it a moment on a phone. Hold the phone in landscape.

The iOS preset in `export_presets.cfg` is only a stub (bundle id, landscape project settings, GL Compatibility). It is not signed and it is not a TestFlight build.
