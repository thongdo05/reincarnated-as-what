extends EnemyActor
class_name DragonEnemy

## One of the ten post-dragon enemies. Move and attack sheets share a frame
## and an anchor (the body centre). Death and hatch sheets are drawn by the
## game at this position plus the manifest offset. Art faces left. Do not flip.

var dragon_id := DragonPhase.BAT
var bullet_density := 1.0
var move_scale := 1.0
var suppress_fire := false
var shield_hits := 0
var warden_id := -1
var hp_mul := DragonPhase.HP_MULT_START

var _allies: Array[EnemyActor] = []
var _anim := ""
var _anim_age := 0.0
var _anim_left := 0.0
var _farewell: Dictionary = {}
var _blocked := false
var _hooked_enter := false
var _intangible := false
var _attack_wait := 0.0
var _threw := false
var _planted := false
var _scroll_mark := 0.0
var _diving := false
var _dive_vel := Vector2.ZERO
var _ward_id := -1
var _mode := 0
var _mode_age := 0.0
var _crack_frame := -1
var _phase_frame := -1
var _ring_left := 0.0
var _breath_left := 0.0
var _breath_aim := 0.0
var _breathing := false
var _move_snd := 0.35

func sprite_file() -> String:
	return DragonPhase.move_file(dragon_id)

func can_be_hit() -> bool:
	return alive and not _intangible and warn_left <= 0.0

func threatens_player() -> bool:
	return alive and not _intangible and warn_left <= 0.0

func take_spawns() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	pending.append_array(_pending_spawns)
	_pending_spawns.clear()
	return pending

func take_farewell() -> Dictionary:
	var data := _farewell
	_farewell = {}
	return data

func consume_block() -> bool:
	var blocked := _blocked
	_blocked = false
	return blocked

func is_phased() -> bool:
	return _intangible

func is_telegraphing() -> bool:
	return warn_left > 0.0 or _ring_left > 0.0 or _breath_left > 0.0

func bind_allies(allies: Array[EnemyActor]) -> void:
	_allies = allies

func detach() -> void:
	_release_ward()

func death_visual() -> Dictionary:
	var file := DragonPhase.death_file(dragon_id)
	return {
		"file": file,
		"offset": DragonPhase.death_offset(file),
		"cue": DragonPhase.death_hook(dragon_id),
	}

func death_shots() -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	if dragon_id != DragonPhase.SLIME:
		return shots
	_hook(DragonPhase.HOOK_SLIME_ATTACK)
	for side in [-1.0, 1.0]:
		shots.append(_shot(
			Vector2(DragonPhase.PUDDLE_DRIFT, 0.0),
			Vector2(side * DragonPhase.PUDDLE_SPREAD, 4.0),
			DragonPhase.PUDDLE,
			0.0,
			DragonPhase.PUDDLE_LIFE
		))
	return shots

func death_gem() -> Dictionary:
	if dragon_id != DragonPhase.ELDER:
		return {}
	return {
		"sprite": DragonPhase.ELDER_GEM,
		"bonus": DragonPhase.ELDER_GEM_BONUS,
		"life": DragonPhase.ELDER_GEM_LIFE,
		"at": position + Vector2(0, -18),
	}

func setup(spawn_id: int, data: Dictionary, field: Vector2, field_background: FieldBackground) -> void:
	id = spawn_id
	dragon_id = int(data.get("dragon_id", data.get("kind", DragonPhase.BAT)))
	kind = 100 + dragon_id
	kind_name = str(DragonPhase.stat(dragon_id)["name"])
	hp_mul = float(data.get("hp_mul", DragonPhase.HP_MULT_START))
	max_hp = maxi(1, int(round(float(DragonPhase.stat(dragon_id)["hp"]) * hp_mul)))
	hp = max_hp
	score_value = int(DragonPhase.stat(dragon_id)["score"])
	speed = float(DragonPhase.stat(dragon_id)["speed"])
	radius = HitLibrary.bounds_radius(sprite_file(), "body")
	if radius < 4.0:
		radius = 8.0
	phase = float(data.get("phase", 0.0))
	field_size = field
	background = field_background
	wave_amp = float(data.get("wave_amp", 12.0))
	y_bias = float(data.get("y_bias", 0.0))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	alive = true
	var lane := float(data.get("x_ratio", 0.5))
	if dragon_id == DragonPhase.WYVERN:
		var marker_y := clampf(lane * field.y + y_bias, 48.0, field.y - 86.0)
		position = Vector2(field.x - 28.0, marker_y)
		origin_y = marker_y
		warn_left = DragonPhase.WYVERN_WARN
	elif DragonPhase.grounded(dragon_id):
		var foot := DragonPhase.feet_y(sprite_file())
		position = Vector2(field.x + radius + 18.0, foot)
		origin_y = foot
		if dragon_id == DragonPhase.EGG:
			position.x = clampf(lane * field.x, field.x * 0.48, field.x - 28.0)
			_planted = true
			_scroll_mark = background.scroll_near if background != null else 0.0
	else:
		origin_y = clampf(lane * field.y + y_bias, 36.0, field.y - 78.0)
		position = Vector2(field.x + radius + 18.0, origin_y)
	if data.has("spawn_at"):
		var at: Vector2 = data["spawn_at"]
		position = at
		origin_y = at.y
	_attack_wait = 0.35
	if dragon_id == DragonPhase.ELDER:
		_attack_wait = DragonPhase.ELDER_OPEN

func hurt(amount: int) -> void:
	if not alive or _intangible or warn_left > 0.0:
		return
	if shield_hits > 0 and amount < DragonPhase.SHIELD_PIERCE:
		shield_hits -= 1
		_blocked = true
		if shield_hits <= 0:
			warden_id = -1
			_hook("dragon_enemy_dragon_cultist_shield_down")
		return
	if shield_hits > 0:
		shield_hits = 0
		warden_id = -1
	hp -= amount
	if hp <= 0:
		hp = 0
		alive = false
		_release_ward()

func tick(delta: float, player_pos: Vector2, _run_time: float = 0.0, _scale: float = 1.0) -> Array[Dictionary]:
	age += delta
	if not _hooked_enter:
		_hooked_enter = true
		if dragon_id == DragonPhase.BAT:
			_hook(DragonPhase.HOOK_BAT_ATTACK)
		elif dragon_id == DragonPhase.WYVERN:
			_hook("dragon_enemy_ember_wyvern_dive_warning")
	var fired: Array[Dictionary] = []
	if suppress_fire:
		telegraphs.clear()
		_ring_left = 0.0
		_breath_left = 0.0
	_tick_anim(delta)
	var pace := move_scale * (DragonPhase.BOSS_EXIT_SPEED if suppress_fire else 1.0)
	match dragon_id:
		DragonPhase.BAT:
			_tick_bat(delta, pace)
		DragonPhase.KOBOLD:
			_tick_kobold(delta, pace, fired)
		DragonPhase.EGG:
			_tick_egg(delta)
		DragonPhase.WHELP:
			_tick_whelp(delta, pace, player_pos, fired)
		DragonPhase.WYVERN:
			_tick_wyvern(delta)
		DragonPhase.SLIME:
			_tick_walker(delta, pace)
		DragonPhase.RIDER:
			_tick_rider(delta, pace, player_pos, fired)
		DragonPhase.CULTIST:
			_tick_walker(delta, pace)
			_tick_cultist(delta)
		DragonPhase.WRAITH:
			_tick_wraith(delta, pace, fired)
		DragonPhase.ELDER:
			_tick_elder(delta, pace, player_pos, fired)
	_release_telegraphs(fired, delta)
	if position.x < -90.0 or position.x > field_size.x + 120.0 or position.y > field_size.y + 80.0:
		alive = false
	if is_inside_tree():
		queue_redraw()
	return fired

func _tick_anim(delta: float) -> void:
	if _anim == "":
		return
	_anim_age += delta
	_anim_left -= delta
	if _anim_left <= 0.0:
		_anim = ""
		_anim_age = 0.0
		_anim_left = 0.0

func _play_anim(file_name: String) -> void:
	if file_name == "":
		return
	_anim = file_name
	_anim_age = 0.0
	_anim_left = DragonPhase.sheet_time(file_name)

func _tick_bat(delta: float, pace: float) -> void:
	position.x -= speed * pace * delta
	position.y = origin_y + sin(age * 3.4 + phase) * 16.0
	position.y = clampf(position.y, 28.0, field_size.y - 72.0)

func _tick_kobold(delta: float, pace: float, fired: Array[Dictionary]) -> void:
	_tick_walker(delta, pace)
	if _anim == DragonPhase.attack_file(dragon_id):
		if suppress_fire:
			return
		if not _threw and _anim_age >= DragonPhase.KOBOLD_THROW_AT:
			_threw = true
			if not suppress_fire and fire_room != 0:
				fired.append(_shot(
					Vector2(DragonPhase.KOBOLD_BOMB_VX, DragonPhase.KOBOLD_BOMB_VY),
					Vector2(-8.0, -8.0),
					DragonPhase.FIREBOMB,
					DragonPhase.KOBOLD_BOMB_GRAVITY,
					DragonPhase.KOBOLD_BOMB_LIFE
				))
				_spend(1)
				_hook(DragonPhase.HOOK_KOBOLD_ATTACK)
		return
	if suppress_fire:
		return
	_attack_wait -= delta
	if _attack_wait > 0.0:
		return
	_attack_wait = DragonPhase.attack_gap(DragonPhase.KOBOLD_INTERVAL, bullet_density)
	_threw = false
	_play_anim(DragonPhase.attack_file(dragon_id))

func _tick_egg(delta: float) -> void:
	_follow_ground(delta)
	var stage := int(floor(age / DragonPhase.EGG_CRACK_STEP))
	var crack := clampi(stage, 0, 3)
	if crack > _crack_frame and crack > 0:
		_hook("dragon_enemy_dragon_egg_crack")
	_crack_frame = crack
	if age < DragonPhase.EGG_HATCH or not alive:
		return
	alive = false
	var hatch := DragonPhase.EGG_HATCH_FILE
	_farewell = {
		"file": hatch,
		"offset": DragonPhase.death_offset(hatch),
		"cue": DragonPhase.HOOK_EGG_HATCH,
	}
	_pending_spawns.append({
		"dragon": true,
		"dragon_id": DragonPhase.WHELP,
		"kind": DragonPhase.WHELP,
		"hp_mul": hp_mul,
		"x_ratio": 0.5,
		"phase": phase,
		"stop_ratio": 0.3,
		"wave_amp": 10.0,
		"y_bias": 0.0,
		"spawn_at": position + Vector2(-4.0, -8.0),
	})

func _tick_whelp(delta: float, pace: float, player_pos: Vector2, fired: Array[Dictionary]) -> void:
	position.x -= speed * pace * delta
	var chase := speed * DragonPhase.WHELP_CHASE * pace
	position.y = move_toward(position.y, player_pos.y, chase * delta)
	position.y = clampf(position.y, 28.0, field_size.y - 72.0)
	if suppress_fire or not telegraphs.is_empty():
		return
	_attack_wait -= delta
	if _attack_wait > 0.0 or fire_room == 0:
		return
	_attack_wait = DragonPhase.attack_gap(DragonPhase.WHELP_INTERVAL, bullet_density)
	var muzzle := Vector2(-12.0, 2.0)
	var aim := (player_pos - (position + muzzle)).normalized()
	if aim.length() < 0.2 or aim.x > -0.15:
		aim = Vector2.LEFT
	_commit_shot(fired, aim * DragonPhase.WHELP_SHOT_SPEED, muzzle, DragonPhase.WHELP_PROJ, DragonPhase.WHELP_WINDUP)
	_spend(1)
	_play_anim(DragonPhase.attack_file(dragon_id))
	_hook(DragonPhase.HOOK_WHELP_ATTACK)

func _tick_wyvern(delta: float) -> void:
	if warn_left > 0.0:
		warn_left = maxf(warn_left - delta, 0.0)
		if warn_left > 0.0:
			return
		_diving = true
		_dive_vel = Vector2(DragonPhase.WYVERN_DIVE_VX, DragonPhase.WYVERN_DIVE_VY)
		position = Vector2(field_size.x + 24.0, origin_y - 30.0)
		_play_anim(DragonPhase.attack_file(dragon_id))
		_anim_left = 8.0
		_hook(DragonPhase.HOOK_WYVERN_ATTACK)
		return
	position += _dive_vel * move_scale * delta

func _tick_walker(delta: float, pace: float) -> void:
	if _planted:
		_follow_ground(delta)
		return
	position.x -= speed * pace * delta
	position.y = DragonPhase.feet_y(sprite_file())
	if dragon_id == DragonPhase.SLIME:
		_move_snd -= delta
		if _move_snd <= 0.0:
			_move_snd = 0.7
			_hook("dragon_enemy_magma_slime_move")
	if dragon_id == DragonPhase.ELDER and position.x <= field_size.x * DragonPhase.ELDER_PARK_X:
		position.x = field_size.x * DragonPhase.ELDER_PARK_X
		_planted = true
		_scroll_mark = background.scroll_near if background != null else 0.0

func _tick_rider(delta: float, pace: float, _player_pos: Vector2, fired: Array[Dictionary]) -> void:
	position.x -= speed * pace * delta
	position.y = origin_y + sin(age * 1.3 + phase) * DragonPhase.RIDER_STRAFE
	position.y = clampf(position.y, 42.0, field_size.y - 78.0)
	if suppress_fire or not telegraphs.is_empty():
		return
	_attack_wait -= delta
	if _attack_wait > 0.0:
		return
	_attack_wait = DragonPhase.attack_gap(DragonPhase.RIDER_INTERVAL, bullet_density)
	var fired_any := false
	for i in DragonPhase.RIDER_SHOTS:
		if fire_room == 0:
			break
		var off := (float(i) - 1.0) * DragonPhase.RIDER_GAP
		_commit_shot(fired, Vector2(-DragonPhase.RIDER_BOLT_SPEED, 0.0), Vector2(-18.0, off), DragonPhase.RIDER_BOLT, DragonPhase.RIDER_WINDUP)
		_spend(1)
		fired_any = true
	if fired_any:
		_play_anim(DragonPhase.attack_file(dragon_id))
		_hook(DragonPhase.HOOK_RIDER_ATTACK)

func _tick_cultist(delta: float) -> void:
	if suppress_fire:
		_release_ward()
		return
	if not _ward_ok():
		_release_ward()
		_claim_ward()

func _tick_wraith(delta: float, pace: float, fired: Array[Dictionary]) -> void:
	position.x -= speed * pace * 0.65 * delta
	position.y = origin_y + sin(age * 1.1 + phase) * 12.0
	position.y = clampf(position.y, 36.0, field_size.y - 70.0)
	if suppress_fire:
		_mode = 0
		_intangible = false
		_phase_frame = -1
		return
	_mode_age += delta
	var phase_file := DragonPhase.attack_file(dragon_id)
	var phase_time := DragonPhase.sheet_time(phase_file)
	match _mode:
		0:
			_intangible = false
			_phase_frame = -1
			if _mode_age >= maxf(DragonPhase.WRAITH_FLOAT / maxf(bullet_density, 0.2), 1.4):
				_set_mode(1)
		1:
			_phase_frame = _sheet_frame(phase_file, _mode_age)
			if _mode_age >= phase_time:
				_intangible = true
				_set_mode(2)
		2:
			_intangible = true
			_phase_frame = 3
			if _mode_age >= DragonPhase.WRAITH_OUT:
				_set_mode(3)
		3:
			_intangible = true
			_phase_frame = 3 - _sheet_frame(phase_file, _mode_age)
			if _mode_age >= phase_time:
				_intangible = false
				_phase_frame = -1
				_ring_left = DragonPhase.WRAITH_WARN
				_set_mode(4)
		4:
			_ring_left = maxf(DragonPhase.WRAITH_WARN - _mode_age, 0.0)
			if _mode_age >= DragonPhase.WRAITH_WARN:
				_fire_ring(fired)
				_set_mode(0)

func _tick_elder(delta: float, pace: float, player_pos: Vector2, fired: Array[Dictionary]) -> void:
	if _breath_left <= 0.0 and not _breathing:
		_tick_walker(delta, pace)
	if suppress_fire:
		_breath_left = 0.0
		_breathing = false
		return
	if _breath_left > 0.0:
		_breath_left = maxf(_breath_left - delta, 0.0)
		_breath_aim = player_pos.y
		if _breath_left <= 0.0:
			_exhale(fired)
		return
	if _breathing:
		return
	_attack_wait -= delta
	if _attack_wait > 0.0:
		return
	_attack_wait = DragonPhase.attack_gap(DragonPhase.ELDER_INTERVAL, bullet_density)
	_breath_left = DragonPhase.ELDER_WARN
	_breath_aim = player_pos.y
	_hook("dragon_enemy_elder_drake_breath_telegraph")

func _exhale(fired: Array[Dictionary]) -> void:
	_breathing = true
	_play_anim(DragonPhase.attack_file(dragon_id))
	_hook(DragonPhase.HOOK_ELDER_ATTACK)
	var count := DragonPhase.ELDER_CONE
	var span := DragonPhase.ELDER_CONE_SPAN
	for i in count:
		if fire_room == 0:
			break
		var u := 0.5 if count <= 1 else float(i) / float(count - 1)
		var angle := lerpf(-span * 0.5, span * 0.5, u)
		var dir := Vector2(-cos(angle), sin(angle))
		fired.append(_shot(dir * DragonPhase.ELDER_PUFF_SPEED, Vector2(-36.0, -2.0), DragonPhase.BREATH_PUFF, 0.0, DragonPhase.ELDER_PUFF_LIFE))
		_spend(1)
	_breathing = false

func _fire_ring(fired: Array[Dictionary]) -> void:
	var count := DragonPhase.RING_BULLETS
	var fired_any := false
	for i in count:
		if fire_room == 0:
			break
		var angle := TAU * float(i) / float(count)
		var dir := Vector2(cos(angle), sin(angle))
		fired.append(_shot(dir * DragonPhase.RING_SPEED, dir * 16.0, DragonPhase.RING_BULLET, 0.0, 2.4))
		_spend(1)
		fired_any = true
	if fired_any:
		_hook(DragonPhase.HOOK_WRAITH_ATTACK)

func _set_mode(mode: int) -> void:
	_mode = mode
	_mode_age = 0.0
	if mode == 1:
		_hook("dragon_enemy_ash_wraith_phase_out")
	elif mode == 3:
		_hook("dragon_enemy_ash_wraith_phase_in")

func _sheet_frame(file_name: String, time_sec: float) -> int:
	var frames := maxi(int(ArtLibrary.entry(file_name).get("frames", 1)), 1)
	var fps := float(ArtLibrary.entry(file_name).get("fps", 12.0))
	if fps <= 0.0:
		fps = 12.0
	return clampi(int(floor(time_sec * fps)), 0, frames - 1)

func _follow_ground(delta: float) -> void:
	position.y = DragonPhase.feet_y(sprite_file())
	if background == null:
		position.x -= 28.0 * delta
		return
	var now := background.scroll_near
	position.x -= now - _scroll_mark
	_scroll_mark = now

func _claim_ward() -> void:
	var best: DragonEnemy = null
	var best_d := DragonPhase.SHIELD_RANGE
	for ally in _allies:
		if ally == self or not is_instance_valid(ally) or not ally.alive or not (ally is DragonEnemy):
			continue
		var other := ally as DragonEnemy
		if other.dragon_id == DragonPhase.CULTIST or other.warden_id >= 0 or not other.can_be_hit():
			continue
		var dist := position.distance_to(other.position)
		if dist < best_d:
			best_d = dist
			best = other
	if best == null:
		return
	best.shield_hits = DragonPhase.SHIELD_HITS
	best.warden_id = id
	_ward_id = best.id
	_play_anim(DragonPhase.attack_file(dragon_id))
	_hook(DragonPhase.HOOK_CULTIST_ATTACK)
	_hook("dragon_enemy_dragon_cultist_shield_up")

func _ward_ok() -> bool:
	if _ward_id < 0:
		return false
	for ally in _allies:
		if not is_instance_valid(ally) or ally.id != _ward_id:
			continue
		if not ally.alive:
			return false
		return position.distance_to(ally.position) <= DragonPhase.SHIELD_RANGE * 1.2
	return false

func _release_ward() -> void:
	if _ward_id < 0:
		return
	for ally in _allies:
		if not is_instance_valid(ally) or ally.id != _ward_id or not (ally is DragonEnemy):
			continue
		var other := ally as DragonEnemy
		if other.warden_id == id:
			if other.shield_hits > 0:
				_hook("dragon_enemy_dragon_cultist_shield_down")
			other.shield_hits = 0
			other.warden_id = -1
	_ward_id = -1

func _spend(count: int) -> void:
	if fire_room > 0:
		fire_room = maxi(fire_room - count, 0)

func _shot(bolt_velocity: Vector2, offset: Vector2, sprite: String, gravity: float, life: float) -> Dictionary:
	var rad := HitLibrary.bounds_radius(sprite, "threat")
	if rad < 2.0:
		rad = 3.5
	return {
		"position": position + offset,
		"velocity": bolt_velocity,
		"gravity": gravity,
		"damage": int(DragonPhase.stat(dragon_id)["damage"]),
		"radius": rad,
		"splits": 0,
		"color": Color("c86bff"),
		"style": "blob",
		"sprite": sprite,
		"killer_name": kind_name,
		"expires": life > 0.0,
		"life": life,
	}

func _hook(cue: String) -> void:
	if cue == "":
		return
	var host := get_parent()
	if host != null and host.has_method("play_sfx_hook"):
		host.play_sfx_hook(cue)

func _draw() -> void:
	if _intangible:
		modulate = Color(1, 1, 1, 0.45)
	else:
		modulate = Color.WHITE
	if warn_left > 0.0 and dragon_id == DragonPhase.WYVERN:
		ArtLibrary.draw_loop(self, DragonPhase.WYVERN_WARN_FILE, age)
	elif _crack_frame >= 0 and dragon_id == DragonPhase.EGG:
		var file := DragonPhase.EGG_CRACK if age >= DragonPhase.EGG_CRACK_STEP else sprite_file()
		if age < DragonPhase.EGG_CRACK_STEP:
			ArtLibrary.draw_loop(self, file, age)
		else:
			ArtLibrary.draw_frame(self, DragonPhase.EGG_CRACK, _crack_frame)
	elif _phase_frame >= 0:
		ArtLibrary.draw_frame(self, DragonPhase.attack_file(dragon_id), _phase_frame)
	elif _anim != "":
		ArtLibrary.draw_loop(self, _anim, _anim_age)
	else:
		ArtLibrary.draw_loop(self, sprite_file(), age)
	if shield_hits > 0:
		ArtLibrary.draw_loop(self, DragonPhase.SHIELD_FILE, age)
	if _ring_left > 0.0:
		ArtLibrary.draw_loop(self, DragonPhase.RING_WARN, age)
	if _breath_left > 0.0:
		var aim := clampf(_breath_aim - position.y, -28.0, 20.0)
		ArtLibrary.draw_loop(self, DragonPhase.BREATH_TELEGRAPH, age, Vector2(-62.0, aim))
	_draw_telegraphs()
	if hp < max_hp and alive and shield_hits <= 0:
		var box := ArtLibrary.art_bbox(sprite_file())
		var width := maxf(box.x * 0.45, 8.0)
		var left := -width * 0.5
		var y := -ArtLibrary.anchor(sprite_file()).y - 3.0
		draw_rect(Rect2(left, y, width, 2), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(left, y, width * float(hp) / float(maxi(max_hp, 1)), 2), Color("ffb15a"))
	elif shield_hits > 0:
		var width := 18.0
		var left := -width * 0.5
		var y := -ArtLibrary.anchor(sprite_file()).y - 4.0
		draw_rect(Rect2(left, y, width, 2), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(left, y, width * float(shield_hits) / float(DragonPhase.SHIELD_HITS), 2), Color("d7c4ff"))
