extends RefCounted
class_name WorldCatalog

## Seven backgrounds. Sky Castle stays on the original res://art/bg_*.png files.
## The other six live under res://art/worlds/<slug>/ and use the same four names
## field_background.gd already draws. Scroll speeds come from art/worlds/manifest.json
## when that file is packed; otherwise they stay at the Sky Castle speeds.
## Music is res://audio/music/world_<slug>.ogg. Sky Castle keeps the current loop.
## A missing track falls back to that loop. Existence uses ResourceLoader, because
## FileAccess.file_exists does not see res:// files inside an exported pck.

const SKY_CASTLE := "sky_castle"
## After the Great Dragon dies the run stays here. It is not part of ORDER,
## so a normal reincarnation never rolls it.
const DRAGON_LAIR := "dragon_lair"
const FALLBACK_MUSIC := "res://audio/music_gameplay_loop.ogg"
const WORLD_MUSIC := "res://audio/music/world_%s.ogg"
const MANIFEST_PATH := "res://art/worlds/manifest.json"
const LAYER_NAMES: PackedStringArray = ["bg_sky.png", "bg_clouds.png", "bg_far.png", "bg_near.png"]
const DEFAULT_FACTORS: Array[float] = [0.05, 0.15, 0.3, 0.6]

const ORDER: PackedStringArray = [
	SKY_CASTLE,
	"neon_tokyo",
	"office_hell",
	"underworld",
	"candy_kingdom",
	"ice_tundra",
	"sunken_ruins",
]

const _FLASH := {
	SKY_CASTLE: "SKY CASTLE",
	"neon_tokyo": "NEON TOKYO",
	"office_hell": "OFFICE HELL",
	"underworld": "UNDERWORLD",
	"candy_kingdom": "CANDY KINGDOM",
	"ice_tundra": "ICE TUNDRA",
	"sunken_ruins": "SUNKEN RUINS",
	DRAGON_LAIR: "DRAGON LAIR",
}

const _SKY: Array[Texture2D] = [
	preload("res://art/bg_sky.png"),
	preload("res://art/bg_clouds.png"),
	preload("res://art/bg_far.png"),
	preload("res://art/bg_near.png"),
]
const _NEON: Array[Texture2D] = [
	preload("res://art/worlds/neon_tokyo/bg_sky.png"),
	preload("res://art/worlds/neon_tokyo/bg_clouds.png"),
	preload("res://art/worlds/neon_tokyo/bg_far.png"),
	preload("res://art/worlds/neon_tokyo/bg_near.png"),
]
const _OFFICE: Array[Texture2D] = [
	preload("res://art/worlds/office_hell/bg_sky.png"),
	preload("res://art/worlds/office_hell/bg_clouds.png"),
	preload("res://art/worlds/office_hell/bg_far.png"),
	preload("res://art/worlds/office_hell/bg_near.png"),
]
const _UNDER: Array[Texture2D] = [
	preload("res://art/worlds/underworld/bg_sky.png"),
	preload("res://art/worlds/underworld/bg_clouds.png"),
	preload("res://art/worlds/underworld/bg_far.png"),
	preload("res://art/worlds/underworld/bg_near.png"),
]
const _CANDY: Array[Texture2D] = [
	preload("res://art/worlds/candy_kingdom/bg_sky.png"),
	preload("res://art/worlds/candy_kingdom/bg_clouds.png"),
	preload("res://art/worlds/candy_kingdom/bg_far.png"),
	preload("res://art/worlds/candy_kingdom/bg_near.png"),
]
const _ICE: Array[Texture2D] = [
	preload("res://art/worlds/ice_tundra/bg_sky.png"),
	preload("res://art/worlds/ice_tundra/bg_clouds.png"),
	preload("res://art/worlds/ice_tundra/bg_far.png"),
	preload("res://art/worlds/ice_tundra/bg_near.png"),
]
const _SUNKEN: Array[Texture2D] = [
	preload("res://art/worlds/sunken_ruins/bg_sky.png"),
	preload("res://art/worlds/sunken_ruins/bg_clouds.png"),
	preload("res://art/worlds/sunken_ruins/bg_far.png"),
	preload("res://art/worlds/sunken_ruins/bg_near.png"),
]
const _LAIR: Array[Texture2D] = [
	preload("res://art/worlds/dragon_lair/bg_sky.png"),
	preload("res://art/worlds/dragon_lair/bg_clouds.png"),
	preload("res://art/worlds/dragon_lair/bg_far.png"),
	preload("res://art/worlds/dragon_lair/bg_near.png"),
]

const _SETS := {
	SKY_CASTLE: _SKY,
	"neon_tokyo": _NEON,
	"office_hell": _OFFICE,
	"underworld": _UNDER,
	"candy_kingdom": _CANDY,
	"ice_tundra": _ICE,
	"sunken_ruins": _SUNKEN,
	DRAGON_LAIR: _LAIR,
}

static var last_id := ""
static var _factors: Dictionary = {}
static var _flashes: Dictionary = {}
static var _ready := false

static func ids() -> PackedStringArray:
	_ensure()
	return ORDER

static func flash_name(id: String) -> String:
	_ensure()
	return str(_flashes.get(id, _FLASH.get(id, "SKY CASTLE")))

static func layers(id: String) -> Array[Texture2D]:
	_ensure()
	var found: Variant = _SETS.get(id, _SKY)
	return found

static func factors(id: String) -> Array[float]:
	_ensure()
	var found: Variant = _factors.get(id, DEFAULT_FACTORS)
	return found

## Worlds that may follow `avoid`. The previous world is left out so a
## reincarnation never repeats the background you just left.
static func candidates(avoid: String) -> PackedStringArray:
	_ensure()
	var pool := PackedStringArray()
	for id in ORDER:
		if id == avoid and ORDER.size() > 1:
			continue
		pool.append(id)
	return pool

static func roll(rng: RandomNumberGenerator) -> String:
	var pool := candidates(last_id)
	var pick := pool[rng.randi_range(0, pool.size() - 1)]
	last_id = pick
	return pick

## Sky Castle always uses the current gameplay loop. Every other world looks
## for res://audio/music/world_<slug>.ogg and falls back when it is not imported yet.
static func music_path(world_id: String) -> String:
	if world_id == SKY_CASTLE or world_id == "":
		return FALLBACK_MUSIC
	var own := WORLD_MUSIC % world_id
	if ResourceLoader.exists(own):
		return own
	return FALLBACK_MUSIC

static func _ensure() -> void:
	if _ready:
		return
	_ready = true
	for id in ORDER:
		_flashes[id] = str(_FLASH[id])
		_factors[id] = DEFAULT_FACTORS.duplicate()
	_flashes[DRAGON_LAIR] = str(_FLASH[DRAGON_LAIR])
	_factors[DRAGON_LAIR] = DEFAULT_FACTORS.duplicate()
	_apply_manifest(_read_manifest())

static func _read_manifest() -> Variant:
	# Open the packed file directly. file_exists returns false for res:// in an export.
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)

static func _apply_manifest(parsed: Variant) -> void:
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var body: Dictionary = parsed
	for item in body.get("worlds", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		var id := str(entry.get("world", ""))
		if not _SETS.has(id):
			continue
		var title := str(entry.get("title", "")).to_upper()
		if title != "":
			_flashes[id] = title
		var listed: Array = entry.get("files", [])
		var next: Array[float] = []
		for index in LAYER_NAMES.size():
			var layer_name := LAYER_NAMES[index]
			var factor := DEFAULT_FACTORS[index]
			for layer in listed:
				if typeof(layer) != TYPE_DICTIONARY:
					continue
				var layer_entry: Dictionary = layer
				if str(layer_entry.get("file", "")).ends_with(layer_name):
					factor = float(layer_entry.get("scroll_factor", factor))
					break
			if absf(factor - DEFAULT_FACTORS[index]) < 0.0001:
				factor = DEFAULT_FACTORS[index]
			next.append(factor)
		_factors[id] = next
