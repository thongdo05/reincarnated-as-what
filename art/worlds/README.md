# Random worlds: FINAL layers (Kaito, Nov 3 2026)
Thong approved ("Do what you think is best"). Six worlds plus the current sky castle.

## Drop-in files (names match scripts/field_background.gd: bg_sky.png, bg_clouds.png, bg_far.png, bg_near.png)
| world | folder |
|---|---|
| Neon Tokyo | neon_tokyo/ |
| Office Hell | office_hell/ |
| Underworld | underworld/ |
| Candy Kingdom | candy_kingdom/ |
| Ice Tundra | ice_tundra/ |
| Sunken Ruins | sunken_ruins/ |

Each folder holds bg_sky.png (opaque, scroll 0.05), bg_clouds.png (transparent, 0.15), bg_far.png (transparent, 0.3) and bg_near.png (transparent, 0.6).
- Every file is 480x270 RGBA, with alpha only 0 or 255, and tiles seamlessly left to right.
- The loader currently loads one fixed set by filename. A per-world folder or prefix switch on reincarnation is code work for Gon.
- manifest.json lists each world's files, size, scroll factor and opaque/transparent type. It also has the deck coordinates, ground y, the deck feet colour, and every background colour per world. None of them are in the master palette yet; add them as background-only colours.

## Decks and ground (same as today's code)
- Deck feet rows are exactly ISLANDS (63,43) and (227,59). Deck A spans x 37-89 (53 px) and deck B spans x 210-244 (35 px), with a lighter lip row at y-1. Nothing on the far layer sits inside the 28x44 archer box above either deck.
- The feet pixel is green-dominant in every world (teal roof trim, green desk leather, moss, mint frosting, mint-tinted snow, algae), so the tests/smoke.gd "archer feet on grass" check passes unchanged. I checked this on the written files.
- Near-layer row y=234 is opaque on all 480 columns (smoke test: 60 of 60 samples).

## Readability pass (final)
- **Neon Tokyo, Office Hell, Underworld:** I lifted the brightness of the whole action band so the player's #14121f outer ring reaches about 2.2-2.4:1. That's the median against background pixels at y 40-230; it was 1.3-1.6.
- **Near layer on those 3 worlds:** lifted further, so the Dire Wolf's outline separates from the ground (about 2.2:1, was 1.1-1.2).
- **Sunken Ruins:** I darkened the water so the blue Slime body reaches 2.2:1 and the pink bolts 2.4:1 (were 1.7 and 1.8).
- **Candy Kingdom, Ice Tundra:** unchanged.
- Full numbers are in checks_report.json (sprite_contrast_before / sprite_contrast_after).
- Demon Lord r3 drawn at 0.75x, plus 2 Dire Wolves, on each world: <slug>/wip/check_demon_r3_wolf_2x.png (+ _gray_2x).

## Dire Wolf anchor issue (code, please check)
- The manifest gives dire_wolf.png a CENTRE anchor (28,20), and enemy_actor.gd sets position.y = GROUND_FEET (234). ArtLibrary.draw_loop draws at origin minus anchor.
- So the wolf's body spans y 214-254, with its feet about 20 px below the y=234 ground line, at about y=254. The previews draw its feet on 234. Either use a bottom-centre anchor (28,40) like the archer, or subtract 20 from its y.

## Other files
- Previews: <slug>/preview_<slug>_480x270.png, _2x and _gray_2x. Contact sheet: previews_all_6.png. Current world with the same sprites: _reference_current/preview/.
- Seam checks: <slug>/wip/seam_check_bg_*_tiled2.png and seam_check_composite_tiled2.png.
- How seams were verified: every world is re-rendered shifted 240 px and must equal np.roll of the original. All 24 layers are identical.
- Source: src/lib.py, src/worlds.py (drawing), src/tone.py (readability remap), src/build_final.py (finals, previews, checks, manifest). The preview-stage scripts are kept as src/*_preview_v1.py and src/build.py.
