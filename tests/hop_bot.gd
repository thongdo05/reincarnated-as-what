extends SceneTree

## Bot study for the hop mode. Not part of CI.
## godot --headless --path . -s res://tests/hop_bot.gd
##
## BOT DATA. n=24 fixed seeds. Median is the mean of the 12th and 13th
## sorted values. Rank columns are the share of runs that reached that rank.

const STEP := 1.0 / 60.0
const N := 24

func _initialize() -> void:
	var header := "form | n | median survival | median lanes | median score | rank 2 % | rank 3 %"
	print("BOT DATA")
	print(header)
	for form in [FormCatalog.Id.SLIME, FormCatalog.Id.GOBLIN]:
		var deaths: Array[float] = []
		var lanes: Array[float] = []
		var scores: Array[float] = []
		var rank2 := 0
		var rank3 := 0
		for i in N:
			var seed_value := 20261101 + i
			var world := HopWorld.new()
			world.setup(seed_value, form)
			var guard := 0
			while world.alive and guard < 7000:
				HopBot.steer(world)
				world.tick(STEP)
				guard += 1
			deaths.append(world.elapsed)
			lanes.append(float(world.lanes))
			scores.append(float(world.score))
			if world.rank2_at >= 0.0:
				rank2 += 1
			if world.rank3_at >= 0.0:
				rank3 += 1
			print("RUN %s seed %d life %.2f lanes %d score %d rank %d killer %s" % [
				FormCatalog.display_name(form),
				seed_value,
				world.elapsed,
				world.lanes,
				world.score,
				world.rank_index + 1,
				world.killer,
			])
		var row := "%s | %d | %.2fs | %.1f | %.0f | %.0f%% | %.0f%%" % [
			FormCatalog.display_name(form),
			N,
			_median(deaths),
			_median(lanes),
			_median(scores),
			100.0 * float(rank2) / float(N),
			100.0 * float(rank3) / float(N),
		]
		print("ROW %s" % row)
		print("SPREAD %s life %.2f-%.2f lanes %.0f-%.0f score %.0f-%.0f" % [
			FormCatalog.display_name(form),
			_min(deaths),
			_max(deaths),
			_min(lanes),
			_max(lanes),
			_min(scores),
			_max(scores),
		])
	print("HOP_BOT_OK")
	quit(0)

func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var mid := sorted.size() / 2
	if sorted.size() % 2 == 1:
		return float(sorted[mid])
	return (float(sorted[mid - 1]) + float(sorted[mid])) * 0.5

func _min(values: Array[float]) -> float:
	var best := values[0]
	for value in values:
		best = minf(best, value)
	return best

func _max(values: Array[float]) -> float:
	var best := values[0]
	for value in values:
		best = maxf(best, value)
	return best
