extends RefCounted
class_name HopBot

## One-lane lookahead. Hops forward when the landing stays clear for a beat,
## otherwise sidesteps toward a row that does. Panic-hops when the road is close.

static func steer(world: HopWorld) -> void:
	if world == null or not world.alive or world.hopping():
		return
	var move := choose(world)
	if move != Vector2i.ZERO:
		world.try_hop(move.x, move.y)

static func choose(world: HopWorld) -> Vector2i:
	var col := world.rest_col
	var row := world.rest_row
	# Full-body shapes get clipped by a body that is still a tile away.
	# If this tile is about to hit, leave even when the next lane is not clear for long.
	var urgent := not world.landing_clear(col, row)
	if not urgent and world.arrival_safe(col + 1, row):
		return Vector2i(1, 0)
	var best := Vector2i.ZERO
	var best_rank := 0
	for dr in [-1, 1]:
		var step := int(dr)
		var nrow := row + step
		if nrow < 0 or nrow >= HopBalance.ROWS:
			continue
		var safe := world.landing_clear(col, nrow) if urgent else world.arrival_safe(col, nrow)
		if not safe:
			continue
		var rank := 1
		if world.arrival_safe(col + 1, nrow):
			rank = 3
		elif urgent and world.landing_clear(col + 1, nrow):
			rank = 2
		if rank > best_rank:
			best_rank = rank
			best = Vector2i(0, step)
	if best != Vector2i.ZERO:
		return best
	if world.landing_clear(col + 1, row) and (urgent or world.buffer_seconds() < 0.9):
		return Vector2i(1, 0)
	if col > 0 and world.landing_clear(col - 1, row) and urgent:
		return Vector2i(-1, 0)
	return Vector2i.ZERO
