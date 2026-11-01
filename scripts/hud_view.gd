extends Control
class_name HudView

var score_text := "0"
var time_text := "0:00"
var coin_text := "x0"
var rank_text := ""
var rank_index := 0
var fill_px := 0
var show_coins := false
var shield_on := false
var rapid_s := 0
var magnet_s := 0
var overdrive_px := -1
var winner_px := -1

var _score: Texture2D
var _time: Texture2D
var _rank: Texture2D
var _coin: Texture2D
var _built := ""

func set_run(score: String, time: String, coins: int, rank_name: String, rank: int, fill: int, loot: bool, shield: bool = false, rapid: int = 0, magnet: int = 0, overdrive: int = -1, winner: int = -1) -> void:
	var coin := "x%d" % coins
	var signature := "%s|%s|%s|%s|%d|%d|%s|%s|%d|%d|%d|%d" % [score, time, coin, rank_name, rank, fill, loot, shield, rapid, magnet, overdrive, winner]
	if signature == _built:
		return
	score_text = score
	time_text = time
	coin_text = coin
	rank_text = rank_name
	rank_index = rank
	fill_px = fill
	show_coins = loot
	shield_on = shield
	rapid_s = rapid
	magnet_s = magnet
	overdrive_px = overdrive
	winner_px = winner
	_score = PixelFont.score_texture(score_text)
	_time = PixelFont.outlined_texture(time_text, HudLayout.TIME_COLOR)
	_rank = PixelFont.outlined_texture(rank_text, HudLayout.RANK_COLOR)
	_coin = PixelFont.outlined_texture(coin_text, HudLayout.COIN_COLOR) if loot else null
	_built = signature
	queue_redraw()

func _draw() -> void:
	if _score == null:
		return
	draw_texture(_score, HudLayout.SCORE_POS)
	draw_texture(ArtLibrary.texture("ui/hud_clock_icon.png"), HudLayout.CLOCK_POS)
	draw_texture(_time, HudLayout.TIME_PEN - Vector2(PixelFont.PAD, PixelFont.PAD))
	draw_texture(ArtLibrary.texture(HudLayout.meter_file(rank_index)), HudLayout.METER_POS)
	if fill_px > 0:
		var fill := ArtLibrary.texture("ui/hud_evo_meter_fill_64x6.png")
		var width := mini(fill_px, HudLayout.FILL_FULL)
		draw_texture_rect_region(fill, Rect2(HudLayout.FILL_POS, Vector2(width, 6)), Rect2(0, 0, width, 6))
	draw_texture(_rank, HudLayout.RANK_PEN - Vector2(PixelFont.PAD, PixelFont.PAD))
	if show_coins and _coin != null:
		draw_texture(ArtLibrary.texture("ui/hud_coin_icon.png"), HudLayout.COIN_POS)
		draw_texture(_coin, HudLayout.COIN_PEN - Vector2(PixelFont.PAD, PixelFont.PAD))
	var icon_x := 6.0
	var icon_y := 66.0
	if shield_on:
		draw_texture(ArtLibrary.texture("hit_flash.png"), Vector2(icon_x, icon_y))
		icon_x += 14.0
	if rapid_s > 0:
		draw_texture(ArtLibrary.texture("slime_shot.png"), Vector2(icon_x, icon_y + 3.0))
		draw_texture(PixelFont.outlined_texture(str(rapid_s), HudLayout.TIME_COLOR), Vector2(icon_x + 10.0, icon_y) - Vector2(PixelFont.PAD, PixelFont.PAD))
		icon_x += 22.0
	if magnet_s > 0:
		draw_texture(ArtLibrary.texture("ui/hud_coin_icon.png"), Vector2(icon_x, icon_y))
		draw_texture(PixelFont.outlined_texture(str(magnet_s), HudLayout.COIN_COLOR), Vector2(icon_x + 12.0, icon_y) - Vector2(PixelFont.PAD, PixelFont.PAD))
	if overdrive_px >= 0:
		var bar := Rect2(Vector2(HudLayout.FILL_POS.x, 66.0), Vector2(HudLayout.FILL_FULL, 6))
		draw_rect(bar, Color(0.08, 0.05, 0.1, 0.9))
		var width := mini(overdrive_px, HudLayout.FILL_FULL)
		if width > 0:
			var fill := ArtLibrary.texture("ui/hud_evo_meter_fill_64x6.png")
			draw_texture_rect_region(fill, Rect2(bar.position, Vector2(width, 6)), Rect2(0, 0, width, 6), Color("ffe56a"))
		draw_texture(PixelFont.outlined_texture("OD", Color("ffe56a")), Vector2(HudLayout.FILL_POS.x + 66.0, 64.0) - Vector2(PixelFont.PAD, PixelFont.PAD))
	if winner_px >= 0:
		var bar := Rect2(Vector2(HudLayout.FILL_POS.x, 78.0), Vector2(HudLayout.FILL_FULL, 6))
		draw_rect(bar, Color(0.16, 0.05, 0.08, 0.9))
		var width := mini(winner_px, HudLayout.FILL_FULL)
		if width > 0:
			var fill := ArtLibrary.texture("ui/hud_evo_meter_fill_64x6.png")
			draw_texture_rect_region(fill, Rect2(bar.position, Vector2(width, 6)), Rect2(0, 0, width, 6), Color("ff4d5e"))
		draw_texture(PixelFont.outlined_texture("WIN", Color("ffe56a")), Vector2(HudLayout.FILL_POS.x + 66.0, 76.0) - Vector2(PixelFont.PAD, PixelFont.PAD))
