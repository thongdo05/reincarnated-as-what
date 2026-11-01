extends RefCounted
class_name HopWorld

## Grid hop simulation. Travel is +x. Lanes are columns. Hazards move on y.
## Presentation lives in HopGame. The bot ticks this directly.

const SAFE := 0
const WALK := 1
const SHOT := 2
const PIANO := 3

var seed_value := 0
var form_id := FormCatalog.Id.SLIME
var alive := true
var elapsed := 0.0
var score := 0
var skill := 0
var lanes := 0
var combo := 0
var combo_left := 0.0
var rank_index := 0
var rank2_at := -1.0
var rank3_at := -1.0
var killer := ""
var loot_count := 0
var small := false
var split_ready := false
var invuln := 0.0
var rest_col := HopBalance.START_COL
var rest_row := HopBalance.START_ROW
var cam_x := 0.0

var hop_u := -1.0
var hop_from_col := 0
var hop_from_row := 0
var hop_to_col := 0
var hop_to_row := 0
var _furthest := HopBalance.START_COL
var _small_for := 0.0
var _fire_cd := 0.2
var _loot_flip := 0
var _lanes: Dictionary = {}
var _hurt: Dictionary = {}
var _dead: Dictionary = {}
var _reach: Dictionary = {}
var _events: Array[Dictionary] = []

var shots: Array[Dictionary] = []
var loot: Array[Dictionary] = []
var draw_hazards: Array[Dictionary] = []
var draw_shots: Array[Dictionary] = []

func setup(run_seed: int, form: int) -> void:
	seed_value = run_seed
	form_id = form
	alive = true
	elapsed = 0.0
	score = 0
	skill = 0
	lanes = 0
	combo = 0
	combo_left = 0.0
	rank_index = 0
	rank2_at = -1.0
	rank3_at = -1.0
	killer = ""
	loot_count = 0
	small = false
	split_ready = form == FormCatalog.Id.SLIME
	invuln = HopBalance.OPEN_INVULN
	rest_col = HopBalance.START_COL
	rest_row = HopBalance.START_ROW
	cam_x = 0.0
	hop_u = -1.0
	_furthest = rest_col
	_small_for = 0.0
	_fire_cd = 0.25
	_loot_flip = 0
	_lanes = {}
	_hurt = {}
	_dead = {}
	_events = []
	shots = []
	loot = []
	refresh_draw()

static func roll_form(rng: RandomNumberGenerator) -> int:
	var forms := FormCatalog.IDS
	return int(forms[rng.randi_range(0, forms.size() - 1)])

func hopping() -> bool:
	return hop_u >= 0.0

func hop_duration() -> float:
	return HopBalance.hop_seconds(form_id)

func goblin_airborne() -> bool:
	if form_id != FormCatalog.Id.GOBLIN or hop_u < 0.0:
		return false
	return hop_u >= HopBalance.GOBLIN_AIR_START and hop_u <= HopBalance.GOBLIN_AIR_END

func player_sprite() -> String:
	var spec := FormCatalog.rank_spec(form_id, rank_index)
	if small and form_id == FormCatalog.Id.SLIME:
		return str(spec["sprite_small"])
	return str(spec["sprite"])

func visual_pos() -> Vector2:
	if hop_u < 0.0:
		return _tile_center(rest_col, rest_row)
	var eased := hop_u * hop_u * (3.0 - 2.0 * hop_u)
	var from := _tile_center(hop_from_col, hop_from_row)
	var to := _tile_center(hop_to_col, hop_to_row)
	return from.lerp(to, eased)

func hop_arc() -> float:
	if hop_u < 0.0:
		return 0.0
	var height := 12.0 if form_id == FormCatalog.Id.GOBLIN else 4.0
	return -sin(hop_u * PI) * height

func buffer_seconds() -> float:
	var gap := visual_pos().x - kill_x_at(elapsed)
	var speed := maxf(HopBalance.pressure_speed(elapsed), 12.0)
	return gap / speed

func try_hop(dc: int, dr: int) -> bool:
	if not alive or hop_u >= 0.0:
		return false
	if dc != 0 and dr != 0:
		return false
	if dc == 0 and dr == 0:
		return false
	var ncol := rest_col + dc
	var nrow := rest_row + dr
	if ncol < 0 or nrow < 0 or nrow >= HopBalance.ROWS:
		return false
	if ncol == rest_col and nrow == rest_row:
		return false
	hop_from_col = rest_col
	hop_from_row = rest_row
	hop_to_col = ncol
	hop_to_row = nrow
	hop_u = 0.0
	return true

func arrival_safe(ncol: int, nrow: int) -> bool:
	if ncol < 0 or nrow < 0 or nrow >= HopBalance.ROWS:
		return false
	var dur := hop_duration()
	var from := _tile_center(rest_col, rest_row)
	var to := _tile_center(ncol, nrow)
	var steps := 10
	for i in steps + 1:
		var u := float(i) / float(steps)
		var eased := u * u * (3.0 - 2.0 * u)
		var at := elapsed + dur * u
		var airborne := form_id == FormCatalog.Id.GOBLIN and u >= HopBalance.GOBLIN_AIR_START and u <= HopBalance.GOBLIN_AIR_END
		if _pos_deadly(from.lerp(to, eased), at, airborne):
			return false
	var hold := elapsed + dur
	var end := hold + 0.28
	while hold <= end + 0.0001:
		if _pos_deadly(to, hold, false):
			return false
		hold += 0.035
	return true

func landing_clear(ncol: int, nrow: int) -> bool:
	if ncol < 0 or nrow < 0 or nrow >= HopBalance.ROWS:
		return false
	var pos := _tile_center(ncol, nrow)
	var t := elapsed + hop_duration()
	var end := t + 0.12
	while t <= end + 0.0001:
		if _pos_deadly(pos, t, false):
			return false
		t += 0.04
	return true

func cell_deadly(col: int, row: int, at: float) -> bool:
	return _pos_deadly(_tile_center(col, row), at, false)

func _pos_deadly(pos: Vector2, at: float, airborne: bool) -> bool:
	# Iframes are applied when a hit actually lands. Treating them as "safe"
	# here makes the bot sprint through the opening and die the frame they end.
	if pos.x < kill_x_at(at):
		return true
	if airborne:
		return false
	var sprite := player_sprite()
	var self_reach := _shape_reach(sprite, "hurt")
	for hazard in _collect(at, false):
		var hpos: Vector2 = hazard["pos"]
		var file := str(hazard["sprite"])
		# A telegraphing piano is not a hit yet. The bot still treats the
		# landing tile as taken, using the same full-body hurt shape.
		var aim := hpos
		var blocking := bool(hazard.get("deadly", false))
		if bool(hazard.get("warn", false)):
			aim = hazard["target"] + _nudge(file)
			blocking = true
		if not blocking:
			continue
		var limit := self_reach + _shape_reach(file, "threat") + 2.0
		if pos.distance_squared_to(aim) > limit * limit:
			continue
		if HitLibrary.gap(pos, sprite, "hurt", aim, file, "threat") <= 2.0:
			return true
	return false

func _shape_reach(file_name: String, role: String) -> float:
	var key := file_name + "|" + role
	if not _reach.has(key):
		_reach[key] = HitLibrary.bounds_radius(file_name, role)
	return float(_reach[key])

func kill_x_at(at: float) -> float:
	var ahead := maxf(at - elapsed, 0.0)
	return cam_x + HopBalance.pressure_speed(elapsed) * ahead + HopBalance.KILL_INSET

func take_events() -> Array[Dictionary]:
	var out := _events.duplicate()
	_events = []
	return out

func tick(delta: float) -> void:
	if not alive:
		return
	var left := maxf(delta, 0.0)
	while left > 0.0001 and alive:
		var step := minf(left, 1.0 / 60.0)
		_step(step)
		left -= step

func _step(delta: float) -> void:
	elapsed += delta
	if elapsed >= HopBalance.CAP_SECONDS:
		_die("time")
		return
	if invuln > 0.0:
		invuln = maxf(invuln - delta, 0.0)
	if combo_left > 0.0:
		combo_left = maxf(combo_left - delta, 0.0)
		if combo_left <= 0.0:
			combo = 0
	if hop_u >= 0.0:
		hop_u += delta / hop_duration()
		if hop_u >= 1.0:
			hop_u = -1.0
			rest_col = hop_to_col
			rest_row = hop_to_row
			if rest_col > _furthest:
				var gained := rest_col - _furthest
				_furthest = rest_col
				lanes += gained
				score += gained * HopBalance.LANE_POINTS
	var lead := visual_pos().x - HopBalance.CAM_MAX_LEAD
	cam_x += HopBalance.pressure_speed(elapsed) * delta
	if cam_x < lead:
		cam_x = lead
	if small:
		_small_for += delta
		if _small_for >= HopBalance.REGROW_SECONDS:
			small = false
			split_ready = true
			_small_for = 0.0
			_events.append({"name": "regrow", "at": visual_pos()})
	_touch_player()
	if not alive:
		refresh_draw()
		return
	_fire(delta)
	_tick_shots(delta)
	_tick_loot(delta)
	if not alive:
		refresh_draw()
		return
	refresh_draw()

func _touch_player() -> void:
	if invuln > 0.0:
		return
	var pos := visual_pos()
	if pos.x < kill_x_at(elapsed):
		_hurt_player("the road")
		return
	if goblin_airborne():
		return
	var sprite := player_sprite()
	for hazard in _collect(elapsed, false):
		if not bool(hazard.get("deadly", false)):
			continue
		var hpos: Vector2 = hazard["pos"]
		if absf(hpos.x - pos.x) > 96.0 or absf(hpos.y - pos.y) > 72.0:
			continue
		if HitLibrary.overlaps(pos, sprite, "hurt", hpos, str(hazard["sprite"]), "threat"):
			_hurt_player(str(hazard.get("killer", "something")))
			return

func _hurt_player(name: String) -> void:
	if not alive or invuln > 0.0:
		return
	if form_id == FormCatalog.Id.SLIME and split_ready and not small:
		split_ready = false
		small = true
		_small_for = 0.0
		invuln = HopBalance.SPLIT_IFRAMES
		_events.append({"name": "split", "at": visual_pos()})
		return
	_die(name)

func _die(name: String) -> void:
	if not alive:
		return
	alive = false
	killer = name
	hop_u = -1.0
	_events.append({"name": "dead", "at": visual_pos(), "killer": name})

func _fire(delta: float) -> void:
	_fire_cd -= delta
	if _fire_cd > 0.0:
		return
	_fire_cd = HopBalance.fire_interval(form_id, rank_index)
	var spec := FormCatalog.rank_spec(form_id, rank_index)
	var sprite := str(spec["shot_sprite"])
	var origin := visual_pos() + Vector2(0.0, hop_arc())
	var speed := HopBalance.shot_speed(form_id)
	var reach := HopBalance.shot_range(form_id, rank_index)
	if form_id == FormCatalog.Id.SLIME:
		var lanes_y: Array = spec["lanes"]
		for lane_y in lanes_y:
			var y := float(lane_y) * 0.45
			_add_shot(origin + Vector2(8.0, y), Vector2(speed, 0.0), 0.0, 1, 0, 1, sprite, reach)
		_events.append({"name": "shot", "at": origin})
		return
	var fan := _goblin_fan(rank_index)
	var damage := int(FormCatalog.goblin_f("damage"))
	var pierce := int(FormCatalog.goblin_f("pierce"))
	for vy in fan:
		_add_shot(origin + Vector2(8.0, -1.0), Vector2(speed, float(vy)), HopBalance.GOBLIN_GRAVITY, damage, pierce, 0, sprite, reach)
	_events.append({"name": "shot", "at": origin})

func _goblin_fan(rank: int) -> Array:
	if rank <= 0:
		return [22.0]
	if rank == 1:
		return [-34.0, 34.0]
	return [-46.0, 0.0, 46.0]

func _add_shot(pos: Vector2, velocity: Vector2, gravity: float, damage: int, pierce: int, splits: int, sprite: String, reach: float) -> void:
	shots.append({
		"pos": pos,
		"vel": velocity,
		"gravity": gravity,
		"damage": damage,
		"pierce": pierce,
		"splits": splits,
		"sprite": sprite,
		"range": reach,
		"traveled": 0.0,
		"hit": [],
		"alive": true,
	})

func _tick_shots(delta: float) -> void:
	var hazards := _collect(elapsed, false)
	var spawned: Array[Dictionary] = []
	var keep: Array[Dictionary] = []
	for shot in shots:
		if not bool(shot["alive"]):
			continue
		var vel: Vector2 = shot["vel"]
		vel.y += float(shot["gravity"]) * delta
		shot["vel"] = vel
		var pos: Vector2 = shot["pos"]
		var step := vel * delta
		pos += step
		shot["pos"] = pos
		shot["traveled"] = float(shot["traveled"]) + step.length()
		if float(shot["traveled"]) > float(shot["range"]) or pos.y < -40.0 or pos.y > HopBalance.FIELD_H + 40.0:
			continue
		var spent := _shot_vs_hazards(shot, hazards, spawned)
		if spent:
			continue
		keep.append(shot)
	shots = keep
	for child in spawned:
		shots.append(child)

func _shot_vs_hazards(shot: Dictionary, hazards: Array[Dictionary], spawned: Array[Dictionary]) -> bool:
	var pos: Vector2 = shot["pos"]
	var hits: Array = shot["hit"]
	for hazard in hazards:
		if not bool(hazard.get("body", false)):
			continue
		var id := int(hazard.get("id", -1))
		if id < 0 or _is_dead(id):
			continue
		if hits.has(id):
			continue
		var hpos: Vector2 = hazard["pos"]
		if absf(hpos.x - pos.x) > 96.0 or absf(hpos.y - pos.y) > 80.0:
			continue
		if not HitLibrary.overlaps(pos, str(shot["sprite"]), "body", hpos, str(hazard["sprite"]), "body"):
			continue
		hits.append(id)
		shot["hit"] = hits
		var hp := int(hazard.get("hp", 1))
		var taken := int(_hurt.get(id, 0)) + int(shot["damage"])
		_hurt[id] = taken
		if taken >= hp:
			_dead[id] = true
			_award_kill(hazard)
		else:
			_events.append({"name": "ping", "at": hpos})
		if int(shot["splits"]) > 0:
			var vel: Vector2 = shot["vel"]
			for angle in [-0.7, 0.7]:
				var child_vel := vel.rotated(angle) * 0.85
				spawned.append({
					"pos": pos,
					"vel": child_vel,
					"gravity": 0.0,
					"damage": 1,
					"pierce": 0,
					"splits": 0,
					"sprite": "slime_shot.png",
					"range": 42.0,
					"traveled": 0.0,
					"hit": [id],
					"alive": true,
				})
		if int(shot["pierce"]) > 0:
			shot["pierce"] = int(shot["pierce"]) - 1
			continue
		return true
	return false

func _award_kill(hazard: Dictionary) -> void:
	var base := int(hazard.get("score", 50))
	var result := ScoreRules.on_kill(base, combo, combo_left, rank_index)
	combo = int(result["combo"])
	combo_left = float(result["combo_left"])
	var points := int(result["points"])
	_add_skill(points)
	var at: Vector2 = hazard["pos"]
	_events.append({"name": "kill", "at": at, "points": points})
	if form_id == FormCatalog.Id.GOBLIN:
		var file := "coin.png" if _loot_flip % 2 == 0 else "gem.png"
		_loot_flip += 1
		loot.append({
			"pos": at,
			"sprite": file,
			"life": 6.0,
		})

func _tick_loot(delta: float) -> void:
	if loot.is_empty():
		return
	var keep: Array[Dictionary] = []
	var player := visual_pos()
	var reach := 16.0 + FormCatalog.core_radius(form_id, rank_index, small)
	for gem in loot:
		var pos: Vector2 = gem["pos"]
		pos.x -= 10.0 * delta
		pos.y += sin(elapsed * 6.0 + pos.x) * 8.0 * delta
		gem["pos"] = pos
		gem["life"] = float(gem["life"]) - delta
		if player.distance_to(pos) <= reach:
			var picked := FormCatalog.loot_points()
			loot_count += 1
			_add_skill(picked)
			_events.append({"name": "loot", "at": pos, "points": picked})
			continue
		if float(gem["life"]) <= 0.0 or pos.x < cam_x - 40.0:
			continue
		keep.append(gem)
	loot = keep

func _add_skill(points: int) -> void:
	if points <= 0:
		return
	score += points
	skill += points
	var reached := 0
	if skill >= HopBalance.GATE_RANK2:
		reached = 1
	if skill >= HopBalance.GATE_RANK3:
		reached = 2
	if reached > rank_index:
		rank_index = reached
		if reached >= 1 and rank2_at < 0.0:
			rank2_at = elapsed
		if reached >= 2 and rank3_at < 0.0:
			rank3_at = elapsed
		_events.append({"name": "evolve", "at": visual_pos(), "rank": reached})

func refresh_draw() -> void:
	draw_hazards = _collect(elapsed, true)
	draw_shots = []
	for shot in shots:
		draw_shots.append(shot)

func lane_kind(col: int) -> int:
	return int(_lane(col).get("kind", SAFE))

func _tile_center(col: int, row: int) -> Vector2:
	return Vector2((float(col) + 0.5) * HopBalance.TILE, (float(row) + 0.5) * HopBalance.TILE)

func _lane(col: int) -> Dictionary:
	if col < 0:
		return {"kind": SAFE}
	if _lanes.has(col):
		return _lanes[col]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 100003 + col * 9176 + 13
	var lane := {
		"kind": _roll_kind(col, rng),
		"bodies": [],
		"streams": [],
		"piano": {},
	}
	var kind := int(lane["kind"])
	if kind == WALK:
		_fill_bodies(lane, col, rng, false)
	elif kind == SHOT:
		_fill_bodies(lane, col, rng, true)
		_fill_streams(lane, col, rng)
	elif kind == PIANO:
		lane["piano"] = {
			"cycle": 1.9,
			"warn": 0.40,
			"fall": 0.24,
			"sit": 0.62,
			"phase": rng.randf_range(0.0, 0.35),
			"count": 1 if col < 18 else 2,
			"salt": rng.randi(),
		}
	_lanes[col] = lane
	return lane

func _roll_kind(col: int, rng: RandomNumberGenerator) -> int:
	# Full-body hurt shapes fill most of a tile, so safe lanes stay common.
	if col <= 5:
		return SAFE
	if col < 18 and col % 2 == 0:
		return SAFE
	if col >= 16 and col % 3 == 0:
		return SAFE
	var roll := rng.randf()
	var piano := 0.0
	# A piano's threat is taller than a full-body goblin can share with the next row.
	# Keep them out of the opening so a hop isn't a blind drop.
	if col >= 20:
		piano = 0.20
	if roll < piano:
		return PIANO
	if roll < piano + 0.55:
		return WALK
	return SHOT

func _fill_bodies(lane: Dictionary, col: int, rng: RandomNumberGenerator, shot_lane: bool) -> void:
	var count := 1
	if col >= 14:
		count = 2
	if col >= 24:
		count = 3
	if shot_lane:
		count = mini(count, 2)
	var sprites := _body_sprites(col, shot_lane)
	var speed := lerpf(30.0, 58.0, clampf((float(col) - 6.0) / 28.0, 0.0, 1.0))
	if shot_lane:
		speed *= 0.85
	var span := 236.0
	var bodies: Array = []
	for i in count:
		var sprite := str(sprites[rng.randi() % sprites.size()])
		var kind := _kind_of_sprite(sprite)
		bodies.append({
			"sprite": sprite,
			"speed": speed * rng.randf_range(0.84, 1.16),
			"phase": span * float(i) / float(count),
			"span": span,
			"y0": 18.0,
			"hp": SpawnDirector.max_hp(kind),
			"score": SpawnDirector.score_value(kind),
			"id": col * 100 + i + (40 if shot_lane else 0),
			"killer": SpawnDirector.kind_name(kind),
		})
	lane["bodies"] = bodies

func _body_sprites(col: int, shot_lane: bool) -> Array:
	if shot_lane:
		if col < 18:
			return ["floating_eye.png"]
		return ["floating_eye.png", "skeleton_archer.png"]
	if col < 16:
		return ["floating_eye.png"]
	if col < 22:
		return ["floating_eye.png", "dire_wolf.png"]
	return ["dire_wolf.png", "floating_eye.png", "wyvern.png", "skeleton_archer.png"]

func _fill_streams(lane: Dictionary, col: int, rng: RandomNumberGenerator) -> void:
	var count := 1 if col < 14 else 2
	var sprites := ["floating_eye_bolt.png", "arrow.png", "wyvern_shot.png"]
	var streams: Array = []
	for i in count:
		streams.append({
			"sprite": sprites[i % sprites.size()],
			"interval": lerpf(0.72, 0.46, clampf(float(col) / 28.0, 0.0, 1.0)),
			"speed": lerpf(72.0, 118.0, clampf(float(col) / 28.0, 0.0, 1.0)),
			"phase": rng.randf_range(0.0, 0.4) + float(i) * 0.16,
			"dir": 1.0 if i % 2 == 0 else -1.0,
			"x_off": (float(i) - 1.0) * 7.0,
		})
	lane["streams"] = streams

func _collect(at: float, for_draw: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var last := rest_col + 9
	if hop_u >= 0.0:
		last = maxi(last, hop_to_col + 9)
	for col in range(0, last + 1):
		var lane := _lane(col)
		var kind := int(lane.get("kind", SAFE))
		if kind == SAFE:
			continue
		if kind == WALK or kind == SHOT:
			for body in lane["bodies"]:
				var item := _body_at(body, col, at)
				if item.is_empty():
					continue
				out.append(item)
			if kind == SHOT:
				for stream in lane["streams"]:
					for point in _stream_points(stream, col, at):
						var sprite := str(stream["sprite"])
						out.append({
							"pos": point,
							"sprite": sprite,
							"deadly": true,
							"body": false,
							"warn": false,
							"killer": _shot_killer(sprite),
							"phase": "move",
							"target": point,
							"id": -1,
						})
		elif kind == PIANO:
			for drop in _pianos_at(lane, col, at, for_draw):
				out.append(drop)
	return out

func _body_at(body: Dictionary, col: int, at: float) -> Dictionary:
	var id := int(body["id"])
	if _is_dead(id):
		return {}
	var y := _ping_y(body, at)
	var sprite := str(body["sprite"])
	return {
		"pos": Vector2((float(col) + 0.5) * HopBalance.TILE, y) + _nudge(sprite),
		"sprite": sprite,
		"deadly": true,
		"body": true,
		"warn": false,
		"killer": str(body["killer"]),
		"phase": "move",
		"target": Vector2.ZERO,
		"id": id,
		"hp": int(body["hp"]),
		"score": int(body["score"]),
	}

func _ping_y(body: Dictionary, at: float) -> float:
	var span := float(body["span"])
	var dist := float(body["speed"]) * at + float(body["phase"])
	var trip := fposmod(dist, span * 2.0)
	var y0 := float(body["y0"])
	if trip > span:
		return y0 + span - (trip - span)
	return y0 + trip

func _stream_points(stream: Dictionary, col: int, at: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var interval := float(stream["interval"])
	var speed := float(stream["speed"])
	var phase := float(stream["phase"])
	var dir := float(stream["dir"])
	if interval <= 0.01 or at < phase:
		return points
	var index := int(floor((at - phase) / interval))
	var life := 340.0 / speed
	var back := int(ceil(life / interval)) + 1
	var spawn_y := -16.0 if dir > 0.0 else HopBalance.FIELD_H + 16.0
	var x := (float(col) + 0.5) * HopBalance.TILE + float(stream["x_off"])
	for k in range(maxi(index - back, 0), index + 1):
		var born := phase + float(k) * interval
		var y := spawn_y + dir * speed * (at - born)
		if y < -30.0 or y > HopBalance.FIELD_H + 30.0:
			continue
		points.append(Vector2(x, y))
	return points

func _pianos_at(lane: Dictionary, col: int, at: float, for_draw: bool) -> Array[Dictionary]:
	var piano: Dictionary = lane["piano"]
	if piano.is_empty():
		return []
	var cycle := float(piano["cycle"])
	var shifted := at + float(piano["phase"])
	var cycle_i := int(floor(shifted / cycle))
	if cycle_i < 0:
		return []
	var local := fposmod(shifted, cycle)
	var warn := float(piano["warn"])
	var fall := float(piano["fall"])
	var sit := float(piano["sit"])
	if local >= warn + fall + sit:
		return []
	var phase := "warn"
	var drop_u := 0.0
	if local >= warn + fall:
		phase = "sit"
	elif local >= warn:
		phase = "fall"
		drop_u = (local - warn) / fall
	var sprite := "anvil.png" if cycle_i % 3 == 2 else "piano.png"
	var kind := SpawnDirector.ANVIL if sprite == "anvil.png" else SpawnDirector.PIANO
	var rows := _piano_rows(piano, cycle_i)
	var out: Array[Dictionary] = []
	for row in rows:
		var center := _tile_center(col, int(row))
		var y := center.y
		if phase == "warn":
			y = -50.0
		elif phase == "fall":
			y = lerpf(-30.0, center.y, drop_u)
		# Deadly only once it has landed. While it falls it sweeps other rows;
		# those rows get the telegraph instead of a surprise hit.
		var deadly := phase == "sit"
		var id := col * 1000 + cycle_i * 20 + int(row)
		if _is_dead(id):
			continue
		out.append({
			"pos": Vector2(center.x, y) + _nudge(sprite),
			"sprite": sprite,
			"deadly": deadly,
			"body": phase != "warn",
			"warn": phase != "sit",
			"killer": SpawnDirector.kind_name(kind),
			"phase": phase,
			"target": center,
			"id": id,
			"hp": SpawnDirector.max_hp(kind),
			"score": SpawnDirector.score_value(kind),
		})
	return out

func _piano_rows(piano: Dictionary, cycle_index: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(piano["salt"]) + cycle_index * 104729
	var want := int(piano["count"])
	var rows: Array = []
	var guard := 0
	# Full-body hurt shapes reach into the next tile, so drops stay a row apart.
	while rows.size() < want and guard < 32:
		guard += 1
		var row := rng.randi_range(0, HopBalance.ROWS - 1)
		var spaced := true
		for existing in rows:
			if absi(int(existing) - row) < 2:
				spaced = false
				break
		if spaced:
			rows.append(row)
	return rows

func _is_dead(id: int) -> bool:
	return _dead.has(id)

func _nudge(sprite: String) -> Vector2:
	match sprite:
		"skeleton_archer.png":
			return Vector2(2.0, 20.0)
		"dire_wolf.png":
			return Vector2(0.0, -2.0)
		"wyvern.png":
			return Vector2(0.0, -4.0)
		"floating_eye.png":
			return Vector2(0.0, 1.0)
		"piano.png", "anvil.png":
			return Vector2(0.0, 1.0)
		_:
			return Vector2.ZERO

func _kind_of_sprite(sprite: String) -> int:
	match sprite:
		"dire_wolf.png":
			return SpawnDirector.WOLF
		"skeleton_archer.png":
			return SpawnDirector.ARCHER
		"wyvern.png":
			return SpawnDirector.WYVERN
		"anvil.png":
			return SpawnDirector.ANVIL
		"piano.png":
			return SpawnDirector.PIANO
		_:
			return SpawnDirector.EYE

func _shot_killer(sprite: String) -> String:
	match sprite:
		"arrow.png":
			return "arrow"
		"wyvern_shot.png":
			return "fireball"
		_:
			return "eye bolt"
