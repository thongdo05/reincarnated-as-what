# Reincarnated as WHAT?!

Portrait one-thumb shooter. Each run you are reborn as a different form. This prototype has two of them, Slime and Goblin, so the core loop can be judged in Safari on an iPhone.

Play it: https://thongdo05.github.io/reincarnated-as-what/

## Play

Drag anywhere. The ship follows the drag, so your finger does not have to sit on it. You fire on your own. One hit ends the run. Tap **Reincarnate** for the next one. Arrow keys or WASD also move, for a desktop check.

The form order and the enemy spawns come from the UTC date. Everyone gets the same order and the same spawns that day. Your place in the order is remembered in the browser. There is no leaderboard yet.

Score is kills, a combo when kills are chained, near-misses, and survival time. The form does not multiply it.

- **Slime.** Green jelly cube. Shots split in two when they hit. Movement keeps sliding after you stop.
- **Goblin.** Tiny crown. Stones leave in an arc. Movement is a short sprint, then a planted step.

Each run opens on a title card, then about 1.5 seconds where you cannot die.

## Run locally

Godot **4.7.2**. https://godotengine.org/download

1. Open this folder in the Godot project manager.
2. Press F5. The window opens at a tall phone size.

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

Serve `build/web` with any static file server and open it in a tall window.

## Phone site

The web export leaves thread support off. A threaded Godot build needs cross-origin headers that GitHub Pages does not send, and that build does not load in iOS Safari. The single-threaded build does.

`.github/workflows/pages.yml` exports the game and deploys it on every push to `main`.

In the repo on GitHub, set **Settings → Pages → Build and deployment → Source** to **GitHub Actions**. After that, a green run on `main` updates https://thongdo05.github.io/reincarnated-as-what/ . The first load is the Godot web binary, so give it a moment on a phone.

The iOS preset in `export_presets.cfg` is only a stub (bundle id, portrait project settings, GL Compatibility). It is not signed and it is not a TestFlight build.
