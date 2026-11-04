# Reincarnated as WHAT?!

Landscape side-scrolling shooter. You fly right while the ground scrolls left. Each run you are reborn as a different form, and a retry never repeats the form you just died as. This build plays five of them: Slime, Goblin, Vending Machine, Cat (ex-CEO), and Demon Lord.

Play it: https://thongdo05.github.io/reincarnated-as-what/

## Play

Turn the phone sideways. In portrait the game asks you to rotate instead of squashing the field.

Drag anywhere. The ship follows the drag, so your finger does not have to sit on it. You start in the left third and can drag anywhere on the screen. You fire forward, to the right, on your own. One life per run: a hit ends it. The first card of a visit is the full reveal. After that, tap through the death sting, then tap the card (or **Reincarnate**) and the next form is a short flash you can tap past. The very first run on a device is a wordless opening: a quiet drifter, a gem, and one shot, with a tiny ghost finger. Later runs use the short brutal pacing. Arrow keys or WASD also move, for a desktop check.

The pause mark in the top-right is 18 pixels and is not scaled. Its touch target is at least 44 points, so a thumb can hit it on an iPhone. Tap it again, or press Esc, to resume. Just under it, **SND** turns sound off and **OFF** turns it back on. That choice stays in the browser.

Sound is a test mix (Hibiki, 1 Nov 2026), not the final one. Music loops for the whole run. The Slime's shot is a quiet bloop. Goblin, Vending Machine, Cat, and Demon Lord each have their own shot, at the same quiet trim. Gems and power drops have pickup cues. A missing file is skipped. A kill pops, death lines up with the burst, `REBORN AS...?` gets the tease sting, and `EVOLVED!` lands on the evolve hit. The vending-machine sting plays on that form's title card. On an iPhone, Safari stays quiet until the first tap. That tap is the title card or the first touch in the run, and the music starts then.

The field is 480×270 and scales up by whole pixels, so the art stays sharp. On a desktop the window opens at 960×540, which is that field at 2×.

The form order and the enemy spawns come from the UTC date. Everyone gets the same order and the same spawns that day. Your place in the order is remembered in the browser.

Score is kills, a combo when kills are chained, near-misses, and survival time. The form does not multiply it. The death card shows your best as that form and your best overall. Those two numbers stay in the browser. The same run is also posted to an online board: all-time and the UTC day, overall or for that form. You pick a short name the first time. A device id in the browser keeps your row. The post sends that name, the device id, the form, the score, how long the run lasted, and whether that run killed the Great Dragon. A slayer run shows DRAGONSLAYER beside the name. That database update was applied on Nov 4, 2026. **Reincarnate** stays the big button. The board can be opened from the title card or the death card, and a miss on the network says it can't reach the leaderboard and can be tapped to try again.

- **Slime.** Blue jelly cube. Shots fly right and split when they hit. Later ranks add lanes and a wider split. Its trait, not an extra life: the hit that would kill a full-size Slime swaps in the small slime of the same rank, with a short moment of safety and a `SPLIT!` pop. Stay alive 15 seconds and it grows back at the same rank, trait included. A hit while small ends the run. One life still holds. Ranks: Slime, Gel Knight, Ooze Titan, Gel Paladin, Prism Ooze.
- **Goblin.** Tiny crown. Stones lob forward and drop. Each rock hits harder than a slime shot and can pierce. Later ranks throw more rocks that hit harder. Movement snaps to the finger. Kills can drop a gem that drifts left. Touch one to add score and evolution points. The slingshot does not level from a pickup count. Ranks: Goblin, Goblin Chief, Goblin King, Goblin Warlord, Goblin Emperor.
- **Vending Machine.** Drawn at 70% of its source art, hurtbox included. Heavy drift: it trails the finger for a few frames and still finishes a flick. Three cans fly forward in a spread. There is no random burst. Kills fill a WINNER! meter, and a full meter is the only WINNER! in the game. It hits every enemy hard and clears enemy shots. Later ranks pay a bigger WINNER!. Ranks: Vending Machine, Mega Vendor, Vending Fortress, Vending Citadel, Golden Jackpot.
- **Cat (ex-CEO).** A hard flick blinks a short dash, then the body snaps the rest of the way. The swipe in front reflects enemy bullets. A streak of near-misses makes nearby enemies fight for you for a moment. Later ranks dash farther and charm more. Ranks: Cat (ex-CEO), Cat Chairman, Cat Overlord, Cat Tycoon, Briefcase Boss.
- **Demon Lord.** Large body, drawn at three quarters of the source art. Big slow orbs home in, and they hit harder the more enemies are on screen. Rank 4 fires a pair. Rank 5 fires three. Ranks: Demon Lord, Demon Emperor, True Demon King, Demon Overlord, Abyss Sovereign.

The first ten seconds are the short brutal opening. After that the field climbs, and at three minutes only a very strong run is still alive. It holds there. Gaps in the rake and the aimed fans stay wider than the body, and shots are telegraphed.

Gems fill an evolution meter and add score. Each rank costs more gems than the last. A rare OVERDRIVE drop clears the screen. It is stronger than the Bomb drop, and it can show up at any rank. Rank 5 is the final form: a short slow-motion hit, a screen flash, and a `FINAL FORM!` banner. An aura sits under enemy bullets and does not change the hitbox. Earlier ranks play a gold rim, a white flash, then an `EVOLVED!` pop. Rank 4's pop is the smaller one. After that, gems raise Power (+1, +2, and on). Each level costs more gems than the last and adds a small bump to that form's shots. The run does not stop. A hit plays the death burst. Tap through it, then the card. The card shows the score large, the best as that form, and the best overall. A new best pops `NEW BEST!`. **Share** saves a picture of the run. **Challenge a friend** sends a link to the same daily seed and form, then the button reads `LINK COPIED!`. All five forms can start from that link. **Reincarnate**, or a tap on the card, starts the next one as a different form. A Challenge a Friend link (`?seed=&form=`) keeps that form for the challenged run only; the retry rolls again and still will not repeat the form you just died as.

Each run, and each reincarnation, picks one of seven worlds at random and will not repeat the world you just left. Sky Castle is the first. The others are Neon Tokyo, Office Hell, Underworld, Candy Kingdom, Ice Tundra, and Sunken Ruins. The name flashes with the form card, in the same gold type, then stays for a moment once you can move. Four layers, each 480×270, tile sideways: sky, clouds, the far decks, then the near ground. They still scroll at 0.05, 0.15, 0.3, and 0.6. The islands and the ground line do not move. Sky Castle keeps the current music loop. A world with its own file at `audio/music/world_<slug>.ogg` crossfades to that loop in about 0.4 seconds. Until that file exists, the world uses the Sky Castle loop.

Enemies come in from the right and are drawn facing left. A Floating Eye drifts, bobs, and fires a bolt. A Dire Wolf charges. A Skeleton Archer stands on the ground or rides a floating island and shoots arrows left. A Wyvern swoops in a wave and spits a fireball. An anvil or a piano sometimes falls. None of them is a slime or a goblin. Dire wolves and wyverns together stay at two on screen.

Bosses are on their own clock, still fixed by the day's seed. One at a time. The Lich King and the Death Knight alternate from about 45 seconds, then about every 40 seconds, until the Great Dragon has appeared. The Lich King rises out of a rune, then mixes a soul beam that locks onto your row, a skull spiral, grave hands, and bone rain. The Death Knight charges, feints, throws sword waves, and raises a shield. Below half health both of them get faster and angrier. Each holds on the right and stays until it is killed. The Great Dragon is the final boss. It arrives once at about 2:30. If a Lich King or Death Knight is still up, that boss leaves with nothing — no score, no gems, no death sting — and the dragon comes in on time. Its entrance is a shadow, a roar, and a crash, and you cannot be hit until that finishes. Above two thirds health it breathes along one lane and throws fireballs that burst into embers. From there down to a third it also dives, shoves you with a wing gust, and drops dark meteors (black core, not the gold ones you call down). Below a third the sky burns and the breath covers the screen except one moving gap. Each new phase roars. Every attack shows its lane first. The dragon stays until one of you dies. Killing it pays 100,000 points, plays a slow banner that says DRAGON SLAIN, and turns you into the Dragon form until you die. That form is not in the random roll and does not evolve. It fires three exploding fireballs and, after eight kills, calls a Meteor Rain. The rain lasts 3 seconds after a 1 second charge. You can still be hit during it. The pictures sit under your ship and under enemy bullets. A Meteor Rain chips a boss for 15 percent of that boss's max HP, same as WINNER, and does not finish it from full. After that first dragon, the Lich King and the Death Knight do not return. The dragon comes back a minute later, with another 10000 HP each time (10000, then 20000, then 30000). Each return keeps the last one's new trick and adds one more: faster breath, then more dark meteors, then shorter gaps between attacks, then a faster safe gap in the enrage breath, then an extra fireball spread. The warnings stay long enough to read. While that dragon is on screen, the new enemy spawns pause.

The Dragon form replaces the daily enemies. Ten dragon-phase enemies unlock by time survived since the transform: Ember Bat, Kobold Torchbearer, Dragon Egg, and Whelp immediately; Ember Wyvern, Magma Slime, and Drake Rider at about a minute; Dragon Cultist and Ash Wraith at about two minutes; Elder Drake at about three. An egg that lasts about four seconds hatches a Whelp. A cultist shields one neighbour until the cultist dies. The phase opens at about 1.5 times the spawn rate you had and twice the listed enemy HP, then spawn rate, HP, and bullet density climb slowly and stop at a cap. The numbers are in `scripts/dragon_phase.gd`. A WINNER clear chips a boss for 15 percent of its max HP and does not finish it from full.

Hit shapes are per sprite in `art/hitboxes.json`. A player shot connects when it touches the opaque body, including a long wolf or a wyvern wing. The player's hurtbox follows that same visible body, head and feet included, and leaves out the ink outline. Enemy bodies and shots kill when they overlap any part of it. Press **H** to draw them, or open the page with `?hitbox=1`: yellow is where shots connect, red is what can kill you, green is your body.

Each run opens on a title card, then about 1.5 seconds where you cannot die.

Demon Lord orbs are 4-frame pulse sheets, so a shot plays one cell at a time instead of the whole strip. The vending machine weapon has no random WINNER! burst. WINNER! is only that form's meter-triggered blast.

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

`.github/workflows/pages.yml` exports the game and deploys it on every push to `main`. The export stamps `index.js`, `index.wasm`, `index.pck`, and the other build files with the commit, and `index.html` checks `version.json` before starting the engine. The next page load after a deploy gets that build without clearing Safari data. `?seed=` and `?form=` stay on the URL. An unknown `?mode=` is ignored and the normal game loads.

Pages is already set to GitHub Actions. A green run on `main` updates https://thongdo05.github.io/reincarnated-as-what/ . The first load is the Godot web binary, so give it a moment on a phone. Hold the phone in landscape.

The iOS preset in `export_presets.cfg` is only a stub (bundle id, landscape project settings, GL Compatibility). It is not signed and it is not a TestFlight build.
