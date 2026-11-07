# CrazyGames

The Pages site and the iOS and Android builds stay on their own presets. This export is a second web preset named `CrazyGames`. It adds the feature tag `crazygames`, swaps in `web/shell_crazygames.html`, and is the only build that boots the CrazyGames SDK.

Basic Launch only. There are no SDK ads in this build.

## Build the zip

Actions → **CrazyGames** → Run workflow. The workflow is `workflow_dispatch` only. It does not run on push or on a pull request, and it does not edit `.github/workflows/pages.yml` or the TestFlight workflow.

The job installs Godot 4.7.2 and the matching export templates, re-encodes the long music loops to 80 kbps Vorbis, registers the SDK autoloads, exports the `CrazyGames` preset, and uploads `reincarnated-crazygames.zip`.

On a machine with Godot 4.7.2, the export templates, and ffmpeg:

```bash
python3 tools/prepare_crazygames_export.py --self-test
python3 tools/prepare_crazygames_export.py
godot --headless --path . --import --quit
mkdir -p build/crazygames
godot --headless --path . --export-release "CrazyGames" build/crazygames/index.html
cp app_icon/app_icon_64.png build/crazygames/favicon.png
cp app_icon/app_icon_180.png build/crazygames/apple-touch-icon.png
cp app_icon/app_icon_180.png build/crazygames/icon-180.png
cp app_icon/app_icon_512.png build/crazygames/icon-512.png
python3 tools/pack_crazygames_zip.py build/crazygames build/reincarnated-crazygames.zip
```

`tools/prepare_crazygames_export.py` edits `project.godot` (two autoload lines) and replaces the music loops in the working tree. Do not commit those edits. The Pages preset excludes `addons/crazygames/*`, so a normal Web export still omits the SDK even if the autoload lines were left in by mistake. The addon itself also refuses to load the JavaScript SDK unless the `crazygames` feature is set.

The zip root is `index.html` next to `index.js`, `index.wasm`, and `index.pck`. Paths inside the zip are relative. The pack script rejects an absolute path, a fullscreen API call, more than 1500 files, or more than 250MB raw.

Serve the folder from `localhost` or `127.0.0.1` to exercise the SDK in its `local` environment. Any other host reports `disabled`, and this game then skips every SDK call.

## What this build turns off

`StoreConfig.stores_available()` is false when the `crazygames` feature is set, the same way it is already false for the editor and for every web export. That hides:

- AdMob banners, interstitials, and rewarded ads
- the Remove Ads button, the Restore button, and the offer screen
- the "watch an ad to pick a form" button

There is no App Store, Google Play, or "get the app" link in the game. There is no in-game fullscreen button. CrazyGames provides fullscreen on the site.

## Web shell

`web/shell_crazygames.html` is the Pages shell plus:

- `user-select: none` on `body`, including the `-webkit-`, `-moz-`, and `-ms-` prefixes, so a long-press on a tablet does not select the canvas
- a hidden `#safe-probe` that reads `env(safe-area-inset-*)`. The canvas stays full-bleed. The game insets the HUD, the pause mark, the title button, and the death card
- the existing first-tap audio unlock, which calls `resume()` on `touchend` and `click` when the AudioContext is `suspended` or `interrupted`. A `visibilitychange` alone cannot resume audio on iOS Safari

The first screen is the title card. It starts the run on its own after 1.5 seconds. On this build the first click starts the run immediately, so gameplay is never more than one click from the loaded page.

## Text at 800×450 and 1920×1080

The project stretch mode stays integer for Pages and the phone builds. At 800×450 that scale is 1, so the 480×270 view sits in a letterbox and a 5px glyph is 5 CSS pixels.

This export sets the root window to fractional stretch at startup. 800×450 and 1920×1080 are both 16:9.

| Window | Integer scale | CrazyGames scale | 5px glyph |
| --- | --- | --- | --- |
| 800×450 | 1 | 1.667 (800/480) | about 8.3 CSS px |
| 1920×1080 | 4 | 4 | 20 CSS px |

## Framerate

Movement, shots, scrolling, and the player’s arrive step already multiply by `delta`. The dragon meteor show steps on a 15 Hz clock driven by an accumulator, so 144 Hz and 165 Hz do not speed it up.

Hit-stop used to last 2–4 process frames. At 165 Hz that freeze was less than a third of the 60 Hz beat. It is now `frames / 60` seconds, and a frame that finishes the freeze keeps the leftover `delta`.

## SDK

The addon is the official Godot 4 package from the Godot Asset Library (`CrazyGames` 1.0.1, October 2026), copied to `res://addons/crazygames`. One local change: `CrazyGames._ready` returns without calling `init_sdk` unless the export feature is `crazygames` and the platform is web.

`tools/prepare_crazygames_export.py` registers these autoloads, which is what enabling the plugin in the editor writes:

- `CrazyGamesBridge` → `res://addons/crazygames/Utils/CrazyGamesBridge.gd`
- `CrazyGames` → `res://addons/crazygames/CrazyGames.gd`

`scripts/crazygames_host.gd` is the only game script that calls them.

1. On startup it waits for `CrazyGames.is_initialised` (15 seconds, then it gives up).
2. Before `gameplay_start`, `gameplay_stop`, or `happy_time` it reads `CrazyGamesBridge.get_environment()`.
3. The call runs only when that string is `local` or `crazygames`. `disabled` skips the call. The SDK throws on a disabled host.

| Call | When |
| --- | --- |
| `CrazyGames.Game.gameplay_start()` | The title card ends and the run starts, pause ends, the leaderboard closes during a run |
| `CrazyGames.Game.gameplay_stop()` | Pause opens, the player dies, the leaderboard opens during a run |
| `CrazyGames.Game.happy_time()` | A boss dies (Lich King, Death Knight, Great Dragon) |

Loading start/stop is not called. The Godot export reports that itself. No ad, banner, user, or data calls. Those are for a later Full Launch.

If you replace the addon, keep the `_ready` guard and the autoload paths above.

## Submission checklist

- [ ] Zip is built with the workflow above, `index.html` at the root, relative paths only
- [ ] File count ≤ 1500 and raw size ≤ 250MB (the pack script checks both)
- [ ] Initial download is as small as this export got. 50MB is the Basic Launch cap. 20MB is the mobile-homepage cap. The official web template is most of the wasm, and this repo does not compile a custom engine
- [ ] Played on `localhost` and the console shows `gameplayStart` when the run starts
- [ ] Pause, death, and the leaderboard show `gameplayStop`, and unpausing shows `gameplayStart` again
- [ ] Killing a boss shows the happy-time log
- [ ] No AdMob, no Remove Ads, no store link, no fullscreen button
- [ ] Text is readable at 800×450 and 1920×1080
- [ ] A phone in landscape plays, and a notch does not cover the score or the pause mark
- [ ] iOS Safari plays audio after the first tap, including after switching away and back
- [ ] English UI, landscape, one click from the loaded page into a run
- [ ] Covers, description, and controls filled in on the Developer Portal (not in this repo)

## Size

Measured locally with Godot 4.7.2 official `web_nothreads_release`, before and after the 80 kbps music step. Gzip is level 9 of each file. The workflow prints the same lines.

| | Pages export (raw) | Pages (gzip) | CrazyGames (raw) | CrazyGames (gzip) |
| --- | ---: | ---: | ---: | ---: |
| index.wasm | 39,514,754 | 10,054,758 | 39,514,754 | 10,054,758 |
| index.pck | 13,467,772 | 12,476,546 | 7,566,892 | 6,560,698 |
| index.js | 279,815 | 68,471 | 279,815 | 68,471 |
| index.html | 16,926 | 5,381 | 18,514 | 5,876 |
| Initial set | 53,321,215 | 22,633,010 | 47,421,923 | 16,717,657 |

The initial set is every `index.*` file. The zip also carries four small icons (13 files total, 47,430,619 bytes raw, 16.8MB deflate zip). That is under the 250MB and 1500-file caps, and under the 50MB raw initial-download cap.

The wasm is the official template. `web_dlink_nothreads_release` splits out a 44MB `godot.side.wasm` and is larger in total, so this export does not use it. A custom 2D-only template would need an emscripten build of Godot. That is not part of this workflow.

If the portal measures gzip, the CrazyGames initial set is about 15.9MB, which is under the 20MB mobile-homepage figure. This repo has not been run through the CrazyGames QA tool, so that reading is not confirmed.
