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


## One row each. Numbers are read from Difficulty so a balance change lands here.
## Gem art is the normal 8x8. The elder gem is a different sprite and is not listed.
static func pickups() -> Array[Dictionary]:
	var seconds := int(Difficulty.POWER_DURATION)
	return [
		{
			"id": "gem",
			"icon": "gem.png",
			"line": "Grows your form, +%d pts." % Difficulty.GEM_SCORE,
		},
		{
			"id": "bomb",
			"icon": "ui/icons/icon_bomb.png",
			"line": "Clears bullets, +%d." % Difficulty.BOMB_SCORE,
		},
		{
			"id": "shield",
			"icon": "ui/icons/icon_shield.png",
			# game.gd sets shield_hits to 1. One hit spends it.
			"line": "Blocks 1 hit.",
		},
		{
			"id": "rapid",
			"icon": "ui/icons/icon_rapid.png",
			"line": "Faster fire, %ds." % seconds,
		},
		{
			"id": "magnet",
			"icon": "ui/icons/icon_magnet.png",
			"line": "Pulls loot, %ds." % seconds,
		},
		{
			"id": "overdrive",
			"icon": "ui/icons/icon_overdrive.png",
			"line": "Clears the screen, +%d." % Difficulty.OVERDRIVE_SCORE,
		},
	]


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
