# Dragon-phase enemies - FINALS (Kaito, Nov 4 2026)

Approved for finals by Thong on Nov 4, 2026 at 2:04 PM ET (his own answer in Gon's chat). He also asked for a hand-drawn unique death for each enemy.

- 40 horizontal strips, all facing LEFT. Pixels are hand-placed in PIL, master palette only, alpha 0/255 only. The checks are in `manifest_dragon_enemies.json`.
- **Anchors:** every move and attack sheet of one enemy (fly/walk/dive/throw/spit/fire/cast/phase/breath/idle/crack) shares ONE frame size. Its `anchor` is the centre of the body in the key pose. Death sheets (and `dragon_egg_hatch`) have their own frame size. To place one, draw it centred at `enemy_pos + death_anchor_offset`.
- **Unique deaths** (hostile magenta, violet and ember tones, no gold):
  - **Ember Bat:** pops into embers and ash.
  - **Kobold:** drops its torch, which flares on the ground.
  - **Egg:** the shell shatters in 4 pieces around a yolk-fire.
  - **Whelp:** spirals down trailing smoke.
  - **Ember Wyvern:** its armour plates fly off and its veins flare and linger.
  - **Magma Slime:** the approved hand-drawn split, kept as it was.
  - **Drake Rider:** the kobold is thrown off while the drake collapses.
  - **Cultist:** the robe crumples and the sigil shatters.
  - **Ash Wraith:** disperses into ash swirls.
  - **Elder Drake:** a 10-frame collapse (roar, buckle, plates fly, crash, body breaks up), ending with the gem popping up.
- Projectiles, telegraphs, puddle, shield, gem and the egg crack/hatch are the approved preview art, unchanged.
- `frame_spec.md` holds the full table, with every size that changed from `preview/` marked. `deaths_preview.gif` (4x) shows all 10 deaths for reference. `preview_sheet.png` shows every frame.
- Source: `src/` (`parts.py` poses, `deaths.py` deaths, `finals.py` builds, `checks_sheets.py` checks and sheets). Rebuild: `cd src && python3 finals.py && python3 checks_sheets.py`.
