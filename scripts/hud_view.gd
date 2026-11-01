extends Control
class_name HudView

var score_text := "0"
var time_text := "0:00"
var coin_text := "x0"
var rank_text := ""
var rank_index := 0
var fill_px := 0

var _score: Texture2D
var _time: Texture2D
var _rank: Texture2D
var _coin: Texture2D
var _built := ""

func set_run(score: String, time: String, coins: int, rank_name: String, rank: int, fill: int) -> void:
	var coin := "x%d" % coins
	var signature := "%s|%s|%s|%s|%d|%d" % [score, time, coin, rank_name, rank, fill]
	if signature == _built:
		return
	score_text = score
	time_text = time
	coin_text = coin
	rank_text = rank_name
	rank_index = rank
	fill_px = fill
	_score = PixelFont.score_texture(score_text)
	_time = PixelFont.outlined_texture(time_text, HudLayout.TIME_COLOR)
	_rank = PixelFont.outlined_texture(rank_text, HudLayout.RANK_COLOR)
	_coin = PixelFont.outlined_texture(coin_text, HudLayout.COIN_COLOR)
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
	draw_texture(ArtLibrary.texture("ui/hud_coin_icon.png"), HudLayout.COIN_POS)
	draw_texture(_coin, HudLayout.COIN_PEN - Vector2(PixelFont.PAD, PixelFont.PAD))
