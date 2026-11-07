extends RefCounted
class_name PauseGuide

## Copy and tab rules for the pause guide. A new pickup is one row in pickups().
## A new form's short lines live on FormCatalog.FORM_CARD["short"].
## Dragon, Meteor Rain, the Great Dragon, and the elder gem are not in here.

const TAB_YOU := 0
const TAB_PICKUPS := 1
const TAB_CONTROLS := 2
const TAB_NAMES: PackedStringArray = ["YOU", "PICKUPS", "CONTROLS"]
## The first three runs open on pickups so the icons are the lesson.
const FIRST_RUNS := 3

static func tab_for_runs(runs_started: int) -> int:
	if runs_started <= FIRST_RUNS:
		return TAB_PICKUPS
	return TAB_YOU


## Two columns of three on the pause guide. Numbers come from Difficulty.
## Gem art is the normal 8x8, drawn at 3x. The elder gem is not listed.
## icon_px is the on-screen size. 28 is 1:1. 24 is 8px gem art at 3x.
static func pickups() -> Array[Dictionary]:
	var seconds := int(Difficulty.POWER_DURATION)
	return [
		{
			"id": "gem",
			"icon": "gem.png",
			"name": "GEM",
			"effect": "Grows form, +%d" % Difficulty.GEM_SCORE,
			"icon_px": 24,
		},
		{
			"id": "bomb",
			"icon": "ui/icons/icon_bomb.png",
			"name": "BOMB",
			"effect": "Clears bullets, +%d" % Difficulty.BOMB_SCORE,
			"icon_px": 28,
		},
		{
			"id": "shield",
			"icon": "ui/icons/icon_shield.png",
			# game.gd sets shield_hits to 1. One hit spends it.
			"name": "SHIELD",
			"effect": "Blocks 1 hit",
			"icon_px": 28,
		},
		{
			"id": "rapid",
			"icon": "ui/icons/icon_rapid.png",
			"name": "RAPID",
			"effect": "Faster fire, %ds" % seconds,
			"icon_px": 28,
		},
		{
			"id": "magnet",
			"icon": "ui/icons/icon_magnet.png",
			"name": "MAGNET",
			"effect": "Pulls loot, %ds" % seconds,
			"icon_px": 28,
		},
		{
			"id": "overdrive",
			"icon": "ui/icons/icon_overdrive.png",
			"name": "OVERDRIVE",
			# One column is too narrow for this at 18px, so the score stays on its own line.
			"effect": "Rare! Clears screen,\n+%d" % Difficulty.OVERDRIVE_SCORE,
			"icon_px": 28,
		},
	]


## Kept for the catalog. The 28px grid uses the last row, so this line does not
## fit under the icons without shrinking the 18px type.
static func pickup_footer() -> String:
	return "After rank 5, gems raise POWER."


## H toggles hitbox debug and D toggles the pacing overlay. Neither is a player control.
## D is also the right-move key, which the WASD line already covers.
static func controls() -> PackedStringArray:
	return PackedStringArray([
		"Drag anywhere to move.",
		"The drag is relative.",
		"Firing is automatic.",
		"WASD or arrows move.",
		"P or Esc pauses.",
	])


static func word_count(line: String) -> int:
	var count := 0
	for part in line.split(" ", false):
		if part.strip_edges() != "":
			count += 1
	return count


## True when public guide copy names a secret.
static func mentions_secret(text: String) -> bool:
	var low := text.to_lower()
	if low.find("great dragon") >= 0:
		return true
	if low.find("meteor") >= 0:
		return true
	if low.find("elder") >= 0:
		return true
	if low.find("dragon") >= 0:
		return true
	return false
