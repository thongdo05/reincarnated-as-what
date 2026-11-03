extends RefCounted
class_name HudLayout

## Positions measured off ui/ui_hud_480x270.png. The score image is the padded
## 2x render, which lines up when its top-left is (3, 2). Other strings are pens:
## outlined glyphs are drawn with a (-1, -1) offset, so the pen sits one pixel
## down-right of the ink.

const SCORE_POS := Vector2(3, 2)
const CLOCK_POS := Vector2(6, 27)
const TIME_PEN := Vector2(17, 28)
const METER_POS := Vector2(5, 38)
const FILL_POS := Vector2(33, 41)
const FILL_FULL := 64
const RANK_PEN := Vector2(6, 52)
const COIN_POS := Vector2(423, 8)
const COIN_PEN := Vector2(434, 9)
const PAUSE_ART_POS := Vector2(458, 4)

const TIME_COLOR := Color("f2fbff")
const RANK_COLOR := Color("ffbcea")
const COIN_COLOR := Color("ffd84a")

static func meter_file(rank_index: int) -> String:
	var shown := clampi(rank_index, 0, 4) + 1
	return "ui/hud_evo_meter_rank%d_empty.png" % shown

## Width of the 64px fill, clipped by progress from this rank to the next.
## Rank 5 has no next rank. The same bar then fills toward the next Power level.
static func fill_px(points: int, rank_index: int) -> int:
	var nxt := FormCatalog.gate_for_next_rank(rank_index)
	if nxt < 0:
		return int(round(float(FILL_FULL) * Difficulty.power_progress(points)))
	var prev := 0
	var gates := FormCatalog.rank_gates()
	if rank_index > 0 and rank_index - 1 < gates.size():
		prev = int(gates[rank_index - 1])
	var span := nxt - prev
	if span <= 0:
		return FILL_FULL
	var along := clampf(float(points - prev) / float(span), 0.0, 1.0)
	return int(round(float(FILL_FULL) * along))
