extends EnemyActor
class_name BossActor

## One boss body. Art is the PNG named by the slug, so a later file drop at
## art/<slug>.png replaces the placeholder without a code change. Hit shapes
## stay in art/hitboxes.json.

const ENTER := 0
const HOLD := 1
const CHARGE := 2
const RETURN := 3
const FLEE := 4

var generation := 0
var hold_x := 410.0
var state := ENTER
var fight_left := 0.0
var return_booked := false
var _attack_i := 0
var _attack_cd := 0.6
var _summon_cd := 3.2
var _attack_id := ""
var _charge_y := 120.0
var _charge_speed := 320.0
var _row_left := 0.0
var _rain_left := 0.0
var _rain_time := 0.0
var _rain_columns: Array[float] = []
var enraged := false
var enrage_flash := 0.0
var shield_left := 0.0
var _beam_mode := 0
var _beam_time := 0.0
var _beam_emit := 0.0
var _beam_y := 0.0
var _beam_chain := 0
var _spiral_left := 0.0
var _spiral_age := 0.0
var _spiral_emit := 0.0
var _spiral_spin := 0.4
var _hands_left := 0.0
var _hands_live := 0.0
var _hand_xs: Array[float] = []
var _fake_stage := 0
var _intro_shook := false
var _hell_gap_y := -1.0
var _hell_gap_left := 0.0
var _hell_gap_dir := 1.0
var _phase_seen := 0
var _gust_warn := 0.0
var gust_left := 0.0

func is_boss() -> bool:
	return true

func hurt(amount: int) -> void:
	if intro_left > 0.0 or not alive:
		return
	super.hurt(amount)
	if boss_slug == "great_dragon":
		_note_dragon_phase()
		return
	if enraged:
		return
	if hp * 2 <= max_hp:
		enraged = true
		enrage_flash = 0.42
		var host := get_parent()
		if host != null and host.has_method("_note_boss_enrage"):
			host._note_boss_enrage(self)

func blocks_player_shot(shot: Shot) -> bool:
	if shield_left <= 0.0:
		return false
	var shield_at := position + Vector2(-22.0, -8.0)
	return shot.position.x < position.x + 8.0 and shot.position.distance_to(shield_at) <= 26.0

func fury() -> int:
	if boss_slug == "great_dragon":
		return dragon_phase()
	if hp * 2 <= max_hp:
		return 2
	return 1

func sprite_file() -> String:
	return BossCatalog.sprite_for(boss_slug)

func dragon_phase() -> int:
	if boss_slug != "great_dragon":
		return 1
	var ratio := float(hp) / float(maxi(max_hp, 1))
	if ratio > 0.66:
		return 1
	if ratio > 0.33:
		return 2
	return 3

func _note_dragon_phase() -> void:
	var now := dragon_phase()
	if _phase_seen == 0:
		_phase_seen = now
		return
	if now == _phase_seen:
		return
	_phase_seen = now
	enrage_flash = 0.45
	var host := get_parent()
	if host != null and host.has_method("_dragon_roar"):
		host._dragon_roar()
	if host != null and host.has_method("_bump_shake"):
		host._bump_shake()

func setup(spawn_id: int, data: Dictionary, field: Vector2, field_background: FieldBackground) -> void:
	id = spawn_id
	kind = -1
	boss_slug = str(data.get("slug", "lich_king"))
	generation = int(data.get("generation", 0))
	kind_name = BossCatalog.display_name(boss_slug)
	max_hp = BossCatalog.max_hp(boss_slug, generation)
	hp = max_hp
	score_value = BossCatalog.score_value(boss_slug)
	radius = HitLibrary.bounds_radius(sprite_file(), "body")
	field_size = field
	background = field_background
	hold_x = clampf(float(data.get("hold_x", BossCatalog.rest_x(boss_slug))), 380.0, 440.0)
	var limits := _y_limits(field.y)
	origin_y = clampf(float(data.get("origin_y", field.y * 0.45)), limits.x, limits.y)
	phase = float(data.get("phase", 0.0))
	wave_amp = float(data.get("wave_amp", 18.0))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The sweeper drops anything past x = field + 80. A boss body is wide
	# enough that field + radius + 28 starts past that line, so the boss was
	# removed on the frame it spawned and the clock did not try again.
	var enter_x := minf(field.x + radius + 28.0, field.x + 70.0)
	position = Vector2(enter_x, origin_y)
	if boss_slug == "lich_king":
		intro_left = BossCatalog.LICH_INTRO
		position = Vector2(hold_x, origin_y + 42.0)
	elif boss_slug == "great_dragon":
		intro_left = BossCatalog.DRAGON_INTRO
		position = Vector2(field.x + 36.0, origin_y)
		_phase_seen = 1
	state = ENTER
	fight_left = 0.0
	_attack_cd = 0.55
	_summon_cd = 3.4
	_charge_speed = 340.0 if boss_slug == "great_dragon" else 300.0

func take_spawns() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	pending.append_array(_pending_spawns)
	_pending_spawns.clear()
	return pending

## Puts the named attack's telegraph on screen without waiting out the cooldown.
func present(attack: String, aim: Vector2) -> void:
	state = HOLD
	intro_left = 0.0
	position.x = hold_x
	fight_left = BossDirector.LIFE
	_attack_id = attack
	_attack_cd = 10.0
	telegraphs.clear()
	_halt_attacks()
	if attack == "charge" or attack == "dive":
		_charge_y = _clamp_row(aim.y)
		_attack_id = attack
		# Reuse the shot telegraph timer by parking a zero-velocity mark the
		# drawer ignores, and keep the warning on _attack_cd's sibling.
		_arm_row(BossCatalog.windup(attack, dragon_phase(), generation))
		return
	if attack == "bone_rain":
		_begin_rain(aim.x, 30.0)
		return
	if attack == "soul_beam" or attack == "double_beam":
		_start_beam(aim.y, 1 if attack == "double_beam" else 0)
		_beam_mode = 2
		return
	if attack == "skull_spiral" or attack == "spiral_hands":
		_start_spiral()
		if attack == "spiral_hands":
			_start_hands(aim.x)
		return
	if attack == "grave_hands":
		_start_hands(aim.x)
		return
	if attack == "beam_rain":
		_start_beam(aim.y, 0)
		_beam_mode = 2
		_begin_rain(aim.x, 30.0)
		return
	if attack == "fake_charge":
		_charge_y = _clamp_row(aim.y + 58.0)
		_fake_stage = 2
		_arm_row(0.4)
		return
	if attack == "sword_waves":
		_arm_sword(aim, 40.0)
		return
	if attack == "shield":
		shield_left = BossCatalog.SHIELD_TIME
		return
	_arm_shots(attack, aim, BossCatalog.windup(attack, dragon_phase(), generation))

func tick(delta: float, player_pos: Vector2, run_time: float = 0.0, scale: float = 1.0) -> Array[Dictionary]:
	age += delta
	speed_scale = maxf(scale, 0.05)
	var player_vel := Vector2.ZERO
	if _have_player and delta > 0.0:
		player_vel = (player_pos - _last_player) / delta
	_last_player = player_pos
	_have_player = true
	var fired: Array[Dictionary] = []
	match state:
		ENTER:
			if intro_left > 0.0 and (boss_slug == "lich_king" or boss_slug == "great_dragon"):
				_tick_intro(delta)
			else:
				position.x = move_toward(position.x, hold_x, 120.0 * delta)
				position.y = origin_y
				if absf(position.x - hold_x) <= 1.0:
					position.x = hold_x
					state = HOLD
					fight_left = BossDirector.LIFE
					_attack_cd = 0.45
		FLEE:
			position.x += 170.0 * delta
			if position.x > field_size.x + radius + 36.0:
				alive = false
		CHARGE:
			position.y = _charge_y
			position.x -= _charge_speed * delta
			if position.x < 26.0:
				state = RETURN
		RETURN:
			position.x = move_toward(position.x, hold_x, 250.0 * delta)
			position.y = move_toward(position.y, origin_y, 120.0 * delta)
			if absf(position.x - hold_x) <= 2.0:
				position.x = hold_x
				state = HOLD
				_attack_cd = BossCatalog.cooldown(_attack_id, dragon_phase(), run_time, generation)
		_:
			_drift(delta)
			_fight(delta, player_pos, player_vel, run_time, fired)
	if _flees() and state != ENTER and state != FLEE:
		fight_left -= delta
		if fight_left <= 0.0:
			_begin_flee()
	if charmed > 0.0:
		_halt_attacks()
	enrage_flash = maxf(enrage_flash - delta, 0.0)
	_release_telegraphs(fired, delta)
	if is_inside_tree():
		queue_redraw()
	return fired

## Regular bosses used to flee after BossDirector.LIFE. They stay until killed.
## The dragon never left on that timer, and still does not.
func _flees() -> bool:
	return false

## Makes room for the Great Dragon. Not a kill: no score, no gems, no death sting.
func dismiss() -> void:
	_begin_flee()
	alive = false
	visible = false

func _begin_flee() -> void:
	state = FLEE
	telegraphs.clear()
	_attack_id = ""
	_pending_spawns.clear()
	_halt_attacks()

func _halt_attacks() -> void:
	_cancel_rain()
	_beam_mode = 0
	_beam_chain = 0
	_spiral_left = 0.0
	_hands_left = 0.0
	_hands_live = 0.0
	shield_left = 0.0
	_fake_stage = 0
	_gust_warn = 0.0
	gust_left = 0.0
	gust_push = 0.0
	_hell_gap_left = 0.0

func _cancel_rain() -> void:
	_rain_left = 0.0
	_rain_columns.clear()
	if telegraphs.is_empty():
		return
	var still: Array[Dictionary] = []
	for item in telegraphs:
		if str(item.get("sprite", "")) == BossCatalog.BONE_SHOT:
			continue
		still.append(item)
	telegraphs = still

func _y_limits(height: float) -> Vector2:
	var file := sprite_file()
	var point := ArtLibrary.anchor(file)
	var box := ArtLibrary.art_bbox(file)
	var top := point.y + 4.0
	var bottom := height - (box.y - point.y) - 6.0
	if bottom < top:
		bottom = top
	return Vector2(top, bottom)

func _drift(delta: float) -> void:
	var bob := sin(age * 1.15 + phase) * wave_amp
	var limits := _y_limits(field_size.y)
	position.y = clampf(origin_y + bob, limits.x, limits.y)
	if absf(position.x - hold_x) > 0.5:
		position.x = move_toward(position.x, hold_x, 80.0 * delta)

func _fight(delta: float, player_pos: Vector2, player_vel: Vector2, run_time: float, fired: Array[Dictionary]) -> void:
	if charmed > 0.0:
		return
	if boss_slug == "lich_king":
		_summon_cd -= delta
		if _summon_cd <= 0.0 and telegraphs.is_empty() and _row_left <= 0.0 and _rain_left <= 0.0 and _beam_mode == 0 and _spiral_left <= 0.0 and _hands_left <= 0.0 and shield_left <= 0.0:
			_summon_eyes()
			_summon_cd = BossCatalog.cooldown("summon", 1, run_time, generation)
	if _rain_left > 0.0:
		_rain_left -= delta
		if _rain_left <= 0.0:
			_loose_rain()
	_tick_beam(delta, player_pos, fired)
	_tick_spiral(delta, fired)
	_tick_hands(delta, fired)
	if shield_left > 0.0:
		shield_left = maxf(shield_left - delta, 0.0)
	if _gust_warn > 0.0:
		_gust_warn = maxf(_gust_warn - delta, 0.0)
		if _gust_warn <= 0.0:
			gust_left = 0.34
			gust_push = -130.0
	elif gust_left > 0.0:
		gust_left = maxf(gust_left - delta, 0.0)
		if gust_left <= 0.0:
			gust_push = 0.0
	if _hell_gap_left > 0.0:
		_tick_hell_gap(delta, run_time)
		return
	if not telegraphs.is_empty():
		return
	if _row_left > 0.0:
		_row_left -= delta
		if _row_left <= 0.0:
			if _attack_id == "fake_charge" and _fake_stage == 1:
				_fake_stage = 2
				_charge_y = _shift_row(_charge_y)
				_arm_row(_paced(0.4))
			else:
				state = CHARGE
				position.y = _charge_y
		return
	if _attack_busy():
		return
	_attack_cd -= delta
	if _attack_cd > 0.0:
		return
	var phase_now := fury()
	var cycle := BossCatalog.attack_cycle(boss_slug, phase_now)
	var attack := cycle[_attack_i % cycle.size()]
	_attack_i += 1
	_attack_id = attack
	_hook_ability(attack)
	if attack == "hell_breath" and BossCatalog.hell_gap_speed(generation) > 0.0:
		_hell_gap_y = BossCatalog.hell_gap_center(player_pos.y)
		_hell_gap_left = BossCatalog.windup(attack, phase_now, generation)
		_hell_gap_dir = -1.0 if player_pos.y < _hell_gap_y else 1.0
		return
	if attack == "charge" or attack == "dive":
		_charge_y = _clamp_row(player_pos.y)
		_fake_stage = 0
		_arm_row(_paced(BossCatalog.windup(attack, phase_now, generation)))
		return
	if attack == "fake_charge":
		_charge_y = _clamp_row(player_pos.y)
		_fake_stage = 1
		_arm_row(_paced(0.55))
		return
	if attack == "bone_rain":
		_begin_rain(player_pos.x, run_time)
		_attack_cd = _cooled("bone_rain", run_time, phase_now)
		return
	if attack == "soul_beam":
		_start_beam(player_pos.y, 0)
		_attack_cd = _cooled("soul_beam", run_time, phase_now)
		return
	if attack == "double_beam":
		_start_beam(player_pos.y, 1)
		_attack_cd = _cooled("double_beam", run_time, phase_now)
		return
	if attack == "skull_spiral":
		_start_spiral()
		_attack_cd = _cooled("skull_spiral", run_time, phase_now)
		return
	if attack == "grave_hands":
		_start_hands(player_pos.x)
		_attack_cd = _cooled("grave_hands", run_time, phase_now)
		return
	if attack == "spiral_hands":
		_start_spiral()
		_start_hands(player_pos.x)
		_attack_cd = _cooled("spiral_hands", run_time, phase_now)
		return
	if attack == "beam_rain":
		_start_beam(player_pos.y, 0)
		_begin_rain(player_pos.x, run_time)
		_attack_cd = _cooled("beam_rain", run_time, phase_now)
		return
	if attack == "sword_waves":
		_arm_sword(player_pos, run_time)
		_attack_cd = _cooled("sword_waves", run_time, phase_now)
		return
	if attack == "shield":
		shield_left = _paced(BossCatalog.SHIELD_TIME)
		_attack_cd = _cooled("shield", run_time, phase_now)
		return
	if attack == "skull":
		var speed := BossCatalog.skull_speed(run_time)
		var aim := _lead(position + BossCatalog.MOUTH, player_pos, player_vel, speed, run_time)
		_commit_shot(fired, aim, BossCatalog.SKULL_MUZZLE, "lich_skull.png", BossCatalog.windup("skull", 1, generation))
		_attack_cd = BossCatalog.cooldown("skull", 1, run_time, generation)
		return
	if attack == "wing_gust":
		_gust_warn = BossCatalog.windup(attack, phase_now, generation)
		gust_push = 0.0
		_attack_cd = BossCatalog.cooldown(attack, phase_now, run_time, generation)
		return
	_arm_shots(attack, player_pos, BossCatalog.windup(attack, dragon_phase(), generation))
	_attack_cd = BossCatalog.cooldown(attack, dragon_phase(), run_time, generation)

func _tick_intro(delta: float) -> void:
	intro_left = maxf(intro_left - delta, 0.0)
	if boss_slug == "great_dragon":
		var span := maxf(BossCatalog.DRAGON_INTRO, 0.1)
		var along := clampf(1.0 - intro_left / span, 0.0, 1.0)
		var slide := clampf((along - 0.42) / 0.38, 0.0, 1.0)
		position.x = lerpf(field_size.x + 36.0, hold_x, slide)
		position.y = origin_y
		if not _intro_shook and along >= 0.28:
			_intro_shook = true
			var host := get_parent()
			if host != null and host.has_method("_dragon_roar"):
				host._dragon_roar()
			if host != null and host.has_method("_dragon_shake"):
				host._dragon_shake(4.0, 0.45)
		if intro_left <= 0.0:
			intro_left = 0.0
			position = Vector2(hold_x, origin_y)
			state = HOLD
			fight_left = BossDirector.LIFE
			_attack_cd = 0.55
			if generation >= 3:
				_hook(DragonPhase.HOOK_RETURN_GAPS)
		return
	var span := maxf(BossCatalog.LICH_INTRO, 0.1)
	var along := clampf(1.0 - intro_left / span, 0.0, 1.0)
	position.x = hold_x
	position.y = lerpf(origin_y + 42.0, origin_y, clampf(along * 1.25, 0.0, 1.0))
	if not _intro_shook and along >= 0.42:
		_intro_shook = true
		var host := get_parent()
		if host != null and host.has_method("_bump_shake"):
			host._bump_shake()
	if intro_left <= 0.0:
		intro_left = 0.0
		position = Vector2(hold_x, origin_y)
		state = HOLD
		fight_left = BossDirector.LIFE
		_attack_cd = 0.4

func _attack_busy() -> bool:
	return not telegraphs.is_empty() or _row_left > 0.0 or _rain_left > 0.0 or _beam_mode != 0 or _spiral_left > 0.0 or _hands_left > 0.0 or _hands_live > 0.0 or shield_left > 0.0 or _gust_warn > 0.0 or gust_left > 0.0 or _hell_gap_left > 0.0

func _tick_hell_gap(delta: float, run_time: float) -> void:
	var speed := BossCatalog.hell_gap_speed(generation)
	_hell_gap_y += _hell_gap_dir * speed * delta
	var half := BossCatalog.HELL_GAP * 0.5
	var lo := 36.0 + half
	var hi := 206.0 - half
	if _hell_gap_y <= lo:
		_hell_gap_y = lo
		_hell_gap_dir = 1.0
	elif _hell_gap_y >= hi:
		_hell_gap_y = hi
		_hell_gap_dir = -1.0
	_hell_gap_left = maxf(_hell_gap_left - delta, 0.0)
	if _hell_gap_left > 0.0:
		return
	var phase_now := dragon_phase()
	var bullet := BossCatalog.bullet_speed(phase_now, generation)
	for spec in BossCatalog.hell_breath_plan(position, _hell_gap_y, bullet, generation):
		telegraphs.append({
			"left": 0.02 + 0.03 * float(spec["stagger"]),
			"velocity": spec["velocity"],
			"pos": position + spec["offset"],
			"sprite": str(spec.get("sprite", BossCatalog.DRAGON_SHOT)),
		})
	_attack_cd = BossCatalog.cooldown("hell_breath", phase_now, run_time, generation)

func _hook_ability(attack: String) -> void:
	if boss_slug != "great_dragon":
		return
	_hook(DragonPhase.hook_for_boss(attack))
	if (attack == "sky_breath" or attack == "hell_breath") and DragonPhase.has_return(generation, 0):
		_hook(DragonPhase.HOOK_RETURN_BREATH)
	if attack == "boss_meteor" and DragonPhase.has_return(generation, 1):
		_hook(DragonPhase.HOOK_RETURN_METEORS)
	if attack == "hell_breath" and DragonPhase.has_return(generation, 3):
		_hook(DragonPhase.HOOK_RETURN_HELL)
	if attack == "ember_fan" and DragonPhase.has_return(generation, 4):
		_hook(DragonPhase.HOOK_RETURN_FAN)

func _hook(cue: String) -> void:
	if cue == "":
		return
	var host := get_parent()
	if host != null and host.has_method("play_sfx_hook"):
		host.play_sfx_hook(cue)

func _cooled(pattern: String, run_time: float, phase_now: int) -> float:
	return _paced(BossCatalog.cooldown(pattern, phase_now, run_time, generation))

func _paced(seconds: float) -> float:
	if boss_slug == "great_dragon":
		return seconds
	return BossCatalog.fury_time(seconds, fury())

func _shift_row(y: float) -> float:
	var shifted := y + 58.0
	if shifted > field_size.y - 86.0:
		shifted = y - 58.0
	return _clamp_row(shifted)

func _clamp_beam_y(y: float) -> float:
	return clampf(y, 40.0, field_size.y - 52.0)

func _start_beam(aim_y: float, chain: int) -> void:
	_beam_mode = 1
	_beam_time = 0.0
	_beam_emit = 0.0
	_beam_y = _clamp_beam_y(aim_y)
	_beam_chain = chain
	_attack_id = "soul_beam"

func _tick_beam(delta: float, player_pos: Vector2, fired: Array[Dictionary]) -> void:
	if _beam_mode == 0:
		return
	_beam_time += delta
	if _beam_mode == 1:
		_beam_y = _clamp_beam_y(player_pos.y)
		if _beam_time >= BossCatalog.BEAM_TRACK:
			_beam_mode = 2
			_beam_time = 0.0
		return
	if _beam_mode == 2:
		if _beam_time >= BossCatalog.BEAM_LOCK:
			_beam_mode = 3
			_beam_time = 0.0
			_beam_emit = 0.0
		return
	if _beam_mode == 4:
		if _beam_time >= BossCatalog.BEAM_FADE:
			_beam_time = 0.0
			if _beam_chain > 0:
				_beam_chain -= 1
				_beam_mode = 1
			else:
				_beam_mode = 0
		return
	if _beam_time >= BossCatalog.BEAM_FIRE:
		_beam_mode = 4
		_beam_time = 0.0
		return
	_beam_emit -= delta
	if _beam_emit > 0.0:
		return
	_beam_emit = 0.06
	var step := BossCatalog.BEAM_HIT_R * 1.55
	var x := 16.0
	var guard := 0
	while x < field_size.x - 12.0 and guard < 48:
		_beam_hit(x, fired)
		x += step
		guard += 1
	_beam_hit(field_size.x - 10.0, fired)

func _beam_hit(x: float, fired: Array[Dictionary]) -> void:
	var bolt := _bolt(Vector2.ZERO, Vector2(x - position.x, _beam_y - position.y), BossCatalog.SOUL_BEAM)
	bolt["expires"] = true
	bolt["life"] = 0.09
	# The strip is drawn on the lich. These are only the hit volume.
	bolt["visible"] = false
	fired.append(bolt)

func _start_spiral() -> void:
	_spiral_left = _paced(1.25)
	_spiral_age = 0.0
	_spiral_emit = 0.0
	_spiral_spin = phase
	_attack_id = "skull_spiral"

func _tick_spiral(delta: float, fired: Array[Dictionary]) -> void:
	if _spiral_left <= 0.0:
		return
	_spiral_left = maxf(_spiral_left - delta, 0.0)
	_spiral_age += delta
	_spiral_emit -= delta
	if _spiral_emit > 0.0:
		return
	_spiral_emit = 0.18
	var speed := lerpf(118.0, 156.0, BossCatalog.attack_unit(_rain_time if _rain_time > 0.0 else age))
	for arm in 2:
		if fire_room == 0:
			return
		var ang := _spiral_spin + _spiral_age * 2.4 + float(arm) * PI
		var dir := Vector2(cos(ang), sin(ang))
		if dir.x > -0.08:
			continue
		fired.append(_bolt(dir * speed, BossCatalog.SKULL_MUZZLE, BossCatalog.SPIRAL_SKULL))
		if fire_room > 0:
			fire_room -= 1

func _hand_ground_y() -> float:
	var box := ArtLibrary.art_bbox(BossCatalog.GRAVE_HAND)
	var point := ArtLibrary.anchor(BossCatalog.GRAVE_HAND)
	return FieldBackground.GROUND_FEET - (box.y - point.y)

func _start_hands(player_x: float) -> void:
	_hand_xs = BossCatalog.hand_columns(player_x)
	_hands_left = _paced(0.8)
	_hands_live = 0.0
	_attack_id = "grave_hands"

func _tick_hands(delta: float, fired: Array[Dictionary]) -> void:
	if _hands_left > 0.0:
		_hands_left = maxf(_hands_left - delta, 0.0)
		if _hands_left <= 0.0:
			var ground := _hand_ground_y()
			for column in _hand_xs:
				if fire_room == 0:
					break
				var bolt := _bolt(Vector2(0.0, -78.0), Vector2(column - position.x, ground - position.y), BossCatalog.GRAVE_HAND)
				bolt["expires"] = true
				bolt["life"] = 0.55
				fired.append(bolt)
				if fire_room > 0:
					fire_room -= 1
			_hands_live = 0.55
		return
	if _hands_live > 0.0:
		_hands_live = maxf(_hands_live - delta, 0.0)

func _arm_sword(player_pos: Vector2, run_time: float) -> void:
	var speed := lerpf(150.0, 198.0, BossCatalog.attack_unit(run_time))
	var origin := position + Vector2(-18.0, -6.0)
	var wind := _paced(0.48)
	for off in BossCatalog.sword_offsets():
		if fire_room == 0:
			break
		var aim := player_pos + Vector2(0.0, off)
		var dir := aim - origin
		if dir.length() < 1.0:
			dir = Vector2.LEFT
		dir = dir.normalized()
		if dir.x > -0.4:
			dir = Vector2(-0.55, dir.y).normalized()
		telegraphs.append({
			"left": wind,
			"velocity": dir * speed,
			"pos": origin,
			"sprite": BossCatalog.SWORD_WAVE,
		})
		if fire_room > 0:
			fire_room -= 1
	_attack_id = "sword_waves"

func _begin_rain(player_x: float, run_time: float) -> void:
	_attack_id = "bone_rain"
	_rain_time = run_time
	_rain_columns = BossCatalog.bone_columns(player_x, run_time, field_size.x)
	_rain_left = BossCatalog.windup("bone_rain", 1, generation)

func _loose_rain() -> void:
	var speed := BossCatalog.bone_fall_speed(_rain_time)
	var columns: Array[float] = []
	columns.append_array(_rain_columns)
	_rain_columns.clear()
	for column in columns:
		for step in 2:
			if fire_room == 0:
				return
			telegraphs.append({
				"left": 0.02 + 0.14 * float(step),
				"velocity": Vector2(0.0, speed),
				"pos": Vector2(column, BossCatalog.BONE_SPAWN_Y),
				"sprite": BossCatalog.BONE_SHOT,
			})
			if fire_room > 0:
				fire_room -= 1

func _arm_shots(attack: String, aim: Vector2, windup: float) -> void:
	var phase_now := dragon_phase()
	var speed := BossCatalog.bullet_speed(phase_now, generation)
	for spec in BossCatalog.shot_plan(attack, phase_now, generation, position, aim, speed):
		var extra := 0.03 * float(spec["stagger"])
		var picture := str(spec.get("sprite", BossCatalog.DRAGON_SHOT))
		telegraphs.append({
			"left": windup + extra,
			"velocity": spec["velocity"],
			"pos": position + spec["offset"],
			"sprite": picture,
		})

func _arm_row(seconds: float) -> void:
	_row_left = seconds

func _clamp_row(y: float) -> float:
	return clampf(y, 64.0, field_size.y - 76.0)

func _summon_eyes() -> void:
	var spots: Array[Vector2] = [Vector2(-36, -16), Vector2(-28, 18)]
	for spot in spots:
		var at := position + spot
		_pending_spawns.append({
			"kind": SpawnDirector.EYE,
			"x_ratio": clampf(at.y / field_size.y, 0.15, 0.85),
			"phase": phase + at.y * 0.01,
			"stop_ratio": 0.3,
			"wave_amp": 8.0,
			"y_bias": 0.0,
			"hold_fire": false,
			"spawn_at": at,
		})

func _draw() -> void:
	if charmed > 0.0:
		modulate = Color(0.62, 1.0, 0.72)
	elif boss_slug == "great_dragon" and dragon_phase() >= 3:
		modulate = Color(1.0, 0.42, 0.32)
	elif enraged:
		modulate = Color(1.0, 0.46, 0.4)
	else:
		modulate = Color.WHITE
	if intro_left > 0.0:
		_draw_intro()
	# Body, then the no-hit FX. Both sit on this node, under enemy bullets.
	var entry := ArtLibrary.entry(sprite_file())
	var body := str(entry.get("body_file", ""))
	var fx := str(entry.get("fx_file", ""))
	ArtLibrary.draw_loop(self, body if body != "" else sprite_file(), age)
	if fx != "":
		ArtLibrary.draw_loop(self, fx, age)
	_draw_attack_flash()
	_draw_specials()
	_draw_telegraphs()
	if HitLibrary.show:
		HitLibrary.draw(self, sprite_file(), "body", Color(1.0, 0.86, 0.2, 0.95))
		HitLibrary.draw(self, sprite_file(), "threat", Color(1.0, 0.28, 0.32, 0.95))

func _draw_intro() -> void:
	if boss_slug == "great_dragon":
		_draw_dragon_intro()
		return
	var fade := clampf(intro_left / 0.35, 0.25, 1.0)
	if intro_left > BossCatalog.LICH_INTRO - 0.35:
		fade = clampf((BossCatalog.LICH_INTRO - intro_left) / 0.35, 0.2, 1.0)
	draw_rect(Rect2(-position, field_size), Color(0.01, 0.03, 0.02, 0.5 * fade))
	var feet := Vector2(0.0, 18.0)
	var jade := Color(0.48, 1.0, 0.78, fade)
	draw_arc(feet, 28.0, 0.0, TAU, 28, jade, 2.0, true)
	draw_arc(feet, 16.0, 0.0, TAU, 20, Color(0.35, 0.9, 0.55, fade), 1.0, true)
	draw_arc(feet, 8.0, age * 3.0, age * 3.0 + PI, 12, Color(0.7, 0.4, 1.0, fade), 2.0, true)
	var tex := PixelFont.outlined_texture("LICH KING", Color("7affc6"))
	var at := Vector2(field_size.x * 0.5, 64.0) - position - tex.get_size()
	draw_texture_rect(tex, Rect2(at, tex.get_size() * 2.0), false)

func _draw_dragon_intro() -> void:
	var span := maxf(BossCatalog.DRAGON_INTRO, 0.1)
	var along := clampf(1.0 - intro_left / span, 0.0, 1.0)
	var fade := clampf(intro_left / 0.4, 0.35, 1.0)
	draw_rect(Rect2(-position, field_size), Color(0.05, 0.0, 0.0, 0.45 * fade))
	var shadow_x := lerpf(-position.x - 80.0, field_size.x - position.x, clampf(along / 0.45, 0.0, 1.0))
	draw_rect(Rect2(Vector2(shadow_x, -position.y), Vector2(90.0, field_size.y)), Color(0.0, 0.0, 0.0, 0.55 * fade))
	var tex := PixelFont.outlined_texture("GREAT DRAGON", Color("ffb15a"))
	var at := Vector2(field_size.x * 0.5, 58.0) - position - tex.get_size()
	draw_texture_rect(tex, Rect2(at, tex.get_size() * 2.0), false)

func _draw_specials() -> void:
	var pulse := 0.45 + 0.55 * absf(sin(age * 22.0))
	if _beam_mode != 0:
		_draw_beam(pulse)
	if _hands_left > 0.0:
		var ground := FieldBackground.GROUND_FEET - position.y
		for column in _hand_xs:
			var c := Vector2(column - position.x, ground)
			draw_arc(c, 12.0, 0.0, TAU, 16, Color(0.55, 1.0, 0.7, pulse), 2.0, true)
			draw_arc(c, 6.0, 0.0, TAU, 10, Color(0.65, 0.35, 1.0, pulse), 1.0, true)
	if shield_left > 0.0:
		ArtLibrary.draw_loop(self, BossCatalog.KNIGHT_SHIELD, age, Vector2(-22.0, -8.0))
		draw_arc(Vector2(-22.0, -8.0), 18.0, 0.0, TAU, 18, Color(0.75, 0.85, 1.0, 0.35 + 0.25 * pulse), 1.0, true)
	if _attack_id == "sword_waves":
		for item in telegraphs:
			if str(item.get("sprite", "")) != BossCatalog.SWORD_WAVE:
				continue
			var origin: Vector2 = item["pos"] - position
			var vel: Vector2 = item["velocity"]
			if vel.length_squared() < 1.0:
				continue
			var dir := vel.normalized()
			draw_line(origin, origin + dir * 110.0, Color(1.0, 0.86, 0.45, pulse), 2.0)
			draw_line(origin + dir * 96.0, origin + dir * 110.0, Color(0.95, 0.95, 0.85, pulse), 3.0)
	if boss_slug == "great_dragon" and dragon_phase() >= 3:
		draw_rect(Rect2(-position, field_size), Color(0.45, 0.05, 0.0, 0.16))
	if _attack_id == "sky_breath" or _attack_id == "hell_breath":
		_draw_breath()
	if _gust_warn > 0.0 or gust_left > 0.0:
		_draw_gust()
	if _attack_id == "boss_meteor":
		_draw_meteor_marks()
	if enrage_flash > 0.0:
		draw_rect(Rect2(-position, field_size), Color(1.0, 0.25, 0.2, enrage_flash * 0.45))

func _draw_breath() -> void:
	var pulse := 0.45 + 0.55 * absf(sin(age * 18.0))
	if _hell_gap_left > 0.0:
		var gap := _hell_gap_y - position.y
		var x0 := -position.x
		var x1 := field_size.x - position.x
		draw_rect(Rect2(Vector2(x0, -position.y), Vector2(x1 - x0, field_size.y)), Color(0.55, 0.08, 0.02, 0.28 * pulse))
		draw_rect(Rect2(Vector2(x0, gap - BossCatalog.HELL_GAP * 0.5), Vector2(x1 - x0, BossCatalog.HELL_GAP)), Color(0.85, 0.95, 0.7, 0.55))
		return
	if _attack_id == "hell_breath":
		var gap := 0.0
		var found := false
		var lanes: Array[float] = []
		for item in telegraphs:
			lanes.append((item["pos"] as Vector2).y)
		lanes.sort()
		var cursor := 36.0
		var best := 0.0
		var best_at := 120.0
		for lane in lanes:
			if lane - cursor > best:
				best = lane - cursor
				best_at = (lane + cursor) * 0.5
			cursor = lane
		if 220.0 - cursor > best:
			best_at = (220.0 + cursor) * 0.5
		gap = best_at - position.y
		found = true
		var x0 := -position.x
		var x1 := field_size.x - position.x
		draw_rect(Rect2(Vector2(x0, -position.y), Vector2(x1 - x0, field_size.y)), Color(0.55, 0.08, 0.02, 0.28 * pulse))
		if found:
			draw_rect(Rect2(Vector2(x0, gap - BossCatalog.HELL_GAP * 0.5), Vector2(x1 - x0, BossCatalog.HELL_GAP)), Color(0.85, 0.95, 0.7, 0.55))
		return
	if telegraphs.is_empty():
		return
	var y := (telegraphs[0]["pos"] as Vector2).y - position.y
	var x0 := -position.x
	var x1 := -8.0
	draw_rect(Rect2(Vector2(x0, y - 22.0), Vector2(x1 - x0, 44.0)), Color(1.0, 0.35, 0.08, 0.28 * pulse))
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(1.0, 0.82, 0.35, pulse), 2.0)
	ArtLibrary.draw_loop(self, BossCatalog.BOSS_BREATH, age, Vector2(-18.0, y))

func _draw_gust() -> void:
	var pulse := 0.4 + 0.6 * absf(sin(age * 20.0))
	var ink := Color(0.75, 0.9, 1.0, pulse)
	ArtLibrary.draw_loop(self, BossCatalog.BOSS_GUST, age, Vector2(-30.0, -6.0))
	for step in 4:
		var x := -40.0 - float(step) * 28.0
		draw_line(Vector2(x, -10.0), Vector2(x - 16.0, -10.0), ink, 2.0)
		draw_line(Vector2(x, 8.0), Vector2(x - 16.0, 8.0), ink, 2.0)

func _draw_meteor_marks() -> void:
	var pulse := 0.4 + 0.6 * absf(sin(age * 16.0))
	for item in telegraphs:
		if str(item.get("sprite", "")) != BossCatalog.BOSS_METEOR:
			continue
		var at: Vector2 = item["pos"] - position
		draw_arc(at + Vector2(0.0, 150.0), 16.0, 0.0, TAU, 16, Color(0.85, 0.15, 0.08, pulse), 2.0, true)
		draw_line(at, at + Vector2(0.0, 140.0), Color(0.35, 0.02, 0.02, pulse), 2.0)

func _draw_beam(pulse: float) -> void:
	var y := _beam_y - position.y
	var x0 := -position.x
	var x1 := field_size.x - position.x
	if _beam_mode == 1 or _beam_mode == 2:
		var locked := _beam_mode == 2
		var flash := 1.0 if not locked else 0.35 + 0.65 * absf(sin(_beam_time * 42.0))
		var ink := Color(0.55, 1.0, 0.75, 0.85 * flash)
		var hot := Color(1.0, 0.95, 0.75, flash) if locked else Color(0.7, 0.45, 1.0, 0.7)
		draw_line(Vector2(x0, y), Vector2(x1, y), ink, 1.0)
		draw_line(Vector2(x0, y), Vector2(x1, y), hot, 1.0)
		if locked:
			draw_line(Vector2(x0, y - 3.0), Vector2(x0, y + 3.0), hot, 1.0)
			draw_line(Vector2(x1, y - 3.0), Vector2(x1, y + 3.0), hot, 1.0)
		return
	var alpha := 1.0
	if _beam_mode == 4:
		alpha = 1.0 - clampf(_beam_time / maxf(BossCatalog.BEAM_FADE, 0.05), 0.0, 1.0)
	_paint_beam_tile(Vector2(x0, y), Vector2.RIGHT, 0.0, field_size.x, alpha)

## One quad per span, with the tile repeating along the beam. Separate sprites
## leave a crack once the strip is rotated; repeat UVs do not.
func _paint_beam_tile(origin: Vector2, dir: Vector2, from_d: float, to_d: float, alpha: float = 1.0) -> void:
	var tex := ArtLibrary.texture(BossCatalog.SOUL_BEAM)
	if tex == null or to_d <= from_d:
		return
	var side := Vector2(-dir.y, dir.x)
	var half := tex.get_height() * 0.5
	var tile := float(tex.get_width())
	var points := PackedVector2Array([
		origin + dir * from_d + side * -half,
		origin + dir * to_d + side * -half,
		origin + dir * to_d + side * half,
		origin + dir * from_d + side * half,
	])
	var u0 := from_d / tile
	var u1 := to_d / tile
	var uvs := PackedVector2Array([
		Vector2(u0, 0.0),
		Vector2(u1, 0.0),
		Vector2(u1, 1.0),
		Vector2(u0, 1.0),
	])
	var tint := Color(1, 1, 1, alpha)
	var colors := PackedColorArray([tint, tint, tint, tint])
	var saved_repeat := texture_repeat
	var saved_filter := texture_filter
	texture_repeat = TEXTURE_REPEAT_ENABLED
	texture_filter = TEXTURE_FILTER_NEAREST
	draw_polygon(points, colors, uvs, tex)
	texture_repeat = saved_repeat
	texture_filter = saved_filter

func _draw_attack_flash() -> void:
	var pulse := 0.4 + 0.55 * absf(sin(age * 26.0))
	if _attack_id == "bone_rain" and not _rain_columns.is_empty():
		var jade := Color(0.25, 1.0, 0.62, 1.0)
		var royal := Color(0.62, 0.22, 0.98, 1.0)
		var ink := Color(0.08, 0.04, 0.12, pulse)
		var staff := BossCatalog.SKULL_MUZZLE
		draw_line(staff, staff + Vector2(-4.0, -26.0), ink, 3.0)
		draw_line(staff, staff + Vector2(-4.0, -26.0), jade, 1.0)
		draw_circle(staff + Vector2(-4.0, -26.0), 3.0, royal)
		var floor_y := 220.0
		for column in _rain_columns:
			var x := column - position.x
			var top := BossCatalog.BONE_TOP - position.y
			var bottom := floor_y - position.y
			draw_line(Vector2(x, top), Vector2(x, bottom), Color(royal.r, royal.g, royal.b, 0.72 * pulse), 4.0)
			draw_line(Vector2(x, top), Vector2(x, bottom), Color(jade.r, jade.g, jade.b, 0.95 * pulse), 2.0)
			draw_rect(Rect2(Vector2(x - 5.0, top - 6.0), Vector2(10.0, 12.0)), Color(ink.r, ink.g, ink.b, pulse * 0.35))
			var beat := absf(sin(age * 18.0))
			var flash := 0.35 + 0.65 * beat
			ArtLibrary.draw_loop(self, BossCatalog.BONE_MARK, age, Vector2(x, top), Color(1, 1, 1, flash), 0.9 + 0.25 * beat)
		return
	if _attack_id == "skull" and not telegraphs.is_empty():
		var item: Dictionary = telegraphs[0]
		var origin: Vector2 = item["pos"] - position
		var vel: Vector2 = item["velocity"]
		if vel.length_squared() > 1.0:
			var dir := vel.normalized()
			var ink := Color(0.55, 1.0, 0.72, pulse)
			draw_line(origin, origin + dir * 64.0, ink, 2.0)
			draw_circle(origin, 4.0, ink)
		return
	if _attack_id == "sweep" and not telegraphs.is_empty():
		var origin := BossCatalog.MOUTH
		var ink := Color(1.0, 0.42, 0.12, pulse)
		for angle in BossCatalog.sweep_angles(dragon_phase(), generation):
			var dir := Vector2(-cos(angle), sin(angle))
			draw_line(origin, origin + dir * 70.0, ink, 2.0)
		var safe := Color(0.75, 1.0, 0.86, pulse)
		for edge in [BossCatalog.SWEEP_HOLE_LO, BossCatalog.SWEEP_HOLE_HI]:
			var dir := Vector2(-cos(edge), sin(edge))
			draw_line(origin, origin + dir * 78.0, safe, 1.0)
		draw_circle(origin, 5.0, Color(1.0, 0.82, 0.4, pulse))
		return
	if _row_left <= 0.0:
		return
	if _attack_id != "charge" and _attack_id != "dive" and _attack_id != "fake_charge":
		return
	var y := _charge_y - position.y
	var x0 := 16.0 - position.x
	var x1 := -6.0
	var span := HitLibrary.vertical_span(sprite_file(), "threat")
	var half := maxf((span.y - span.x) * 0.5, 6.0)
	draw_rect(Rect2(Vector2(x0, y - half), Vector2(x1 - x0, half * 2.0)), Color(1.0, 0.28, 0.22, 0.28 * pulse))
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(1.0, 0.35, 0.28, pulse), 2.0)
	draw_line(Vector2(x0, y - 5.0), Vector2(x0, y + 5.0), Color(1.0, 0.86, 0.45, pulse), 1.0)
