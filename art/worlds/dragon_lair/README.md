# Dragon Lair - FINAL layers (Kaito, Nov 4 2026)
Approved by Thong, Nov 4 2026, 2:21 PM ET (his own answers in Gon's chat): the lair previews for finals, and the 27 background-only colours.

One Dragon-phase background. After the Great Dragon is slain it replaces every world's background.

## Drop-in (art/worlds/dragon_lair/)
| file | size | scroll | type |
|---|---|---|---|
| bg_sky.png | 480x270 | 0.05 | opaque |
| bg_clouds.png | 480x270 | 0.15 | transparent |
| bg_far.png | 480x270 | 0.3 | transparent |
| bg_near.png | 480x270 | 0.6 | transparent |

- RGBA, alpha only 0 or 255. Every layer tiles seamlessly on x: a re-render shifted 240 px equals np.roll of the original.
- Ground line y=234: near-layer row 234 is opaque on all 480 columns (60 of 60 smoke samples).
- Archer decks: feet at (63,43) and (227,59), spans x 37-89 and 210-244. The feet pixel is #4a6a52, which is green-dominant, so the tests/smoke.gd grass check passes. There are 0 far-layer pixels in the archer box above either deck.
- Colours: 27 background-only colours, approved for the palette. They're listed in manifest_dragon_lair.json.
- Code work for Gon: add a "dragon_lair" set to WorldCatalog (_SETS plus a manifest entry with scroll speeds 0.05/0.15/0.3/0.6). Swap to it at DRAGON SLAIN and keep it for every later world. Note that smoke.gd loops over every catalog id.

## Transition (timings PROPOSED - retime to the slain sting)
banner 0.4 s, flash 0.1 s, cracks 0.6 s, wipe 0.6 s, settle 0.8 s.
- flash: full-screen #ffffff.
- cracks: hard mask transition/crack_mask_r1..r8.png (480x270, white = show lair). Step r with elapsed/0.6*8, with a 1 px rim around the mask alternating #d06a18 and #e89a30.
- wipe: right-to-left column wipe (lair where x >= wipe_x) with a 4 px ember edge (#e89a30, #d06a18, #b04a12, #7a2a10) and sparks. Cracks stay at r8 during the wipe.
- No alpha blending and no filtering. The masks are screen-space.
See preview/transition_storyboard.png and preview/transition.gif.

## Readability
Slate action band (luminance median about 0.088) with no orange, gold or violet mid-tones. The drama is at the edges: volcanic glow and distant dragons at the top, lava seams below the ground.
- On the lair: gold fireball and Dragon at 100% of edges >=2:1; every Dragon-phase move/attack sheet, bullet and telegraph at >=95.7%.
- ash_wraith_phase (99.9%) and dragon_egg_break (100%) pass after their #14121f outline fix.

## Files
composite_still.png and composite_still_2x.png (final), manifest_dragon_lair.json, transition/, preview/ (the approved previews, left as is), src/ (lair.py draws the layers).
