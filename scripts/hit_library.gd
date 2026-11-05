extends RefCounted
class_name HitLibrary

## Per-sprite collision from res://art/hitboxes.json. Points are pixels from the
## sprite anchor (the same origin the art is drawn around). +y is down.
##
## body: where a player shot connects. Fitted to the opaque body, so a shot
## that visibly touches the wolf's length or the wyvern's wing counts.
## threat: where that sprite can kill the player. Inset from the body, so a
## brush of a wing, ear, or shot sprite is not a death.
## hurt: the player's visible body. Circles and capsules hug the opaque
## silhouette, head and feet included. The ink outline is not required.
## A hit tests every part. The movement pad is only the bounds radius.

const PATH := "res://art/hitboxes.json"

static var show := false
static var _data: Dictionary = {}
static var _ready := false
static var _warned := {}
static var _derived: Dictionary = {}

static func _ensure() -> void:
	if _ready:
		return
	_ready = true
	if not FileAccess.file_exists(PATH):
		push_error("hitbox table missing at %s" % PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("hitbox table is not an object")
		return
	_data = parsed

static func entry(file_name: String) -> Dictionary:
	_ensure()
	var found: Variant = _data.get(file_name, {})
	if typeof(found) != TYPE_DICTIONARY:
		return {}
	return found

static func has_role(file_name: String, role: String) -> bool:
	return not _parts(file_name, role).is_empty()

static func overlaps(pos_a: Vector2, file_a: String, role_a: String, pos_b: Vector2, file_b: String, role_b: String, scale_a: float = 1.0, scale_b: float = 1.0, frame_a: int = -1) -> bool:
	return gap(pos_a, file_a, role_a, pos_b, file_b, role_b, scale_a, scale_b, frame_a) <= 0.0

## Positive when the shapes are apart, negative when they penetrate.
## scale_* shrinks a role around its anchor. Play uses this so a drawn-smaller
## body and its hurtbox stay the same shape.
static func gap(pos_a: Vector2, file_a: String, role_a: String, pos_b: Vector2, file_b: String, role_b: String, scale_a: float = 1.0, scale_b: float = 1.0, frame_a: int = -1) -> float:
	var parts_a := _parts_scaled(file_a, role_a, scale_a, frame_a)
	var parts_b := _parts_scaled(file_b, role_b, scale_b)
	if parts_a.is_empty() or parts_b.is_empty():
		return 9999.0
	var best := 9999.0
	for part_a in parts_a:
		for part_b in parts_b:
			best = minf(best, _gap_pair(part_a, pos_a, part_b, pos_b))
	return best

static func contains_local(file_name: String, role: String, point: Vector2, frame: int = -1) -> bool:
	return local_gap(file_name, role, point, frame) <= 0.0

## Signed distance from a sprite-local point to the role. Negative is inside.
## Empty when the role has no parts. frame picks a hurt_frames entry when set.
static func local_gap(file_name: String, role: String, point: Vector2, frame: int = -1) -> float:
	var parts := _parts(file_name, role, frame)
	if parts.is_empty():
		return 9999.0
	var best := 9999.0
	for part in parts:
		best = minf(best, _gap_point(point, part))
	return best

## Largest single radius. Used to compare how big a core is, ignoring offset.
static func max_part_radius(file_name: String, role: String) -> float:
	var best := 0.0
	for part in _parts(file_name, role):
		var kind := str(part["type"])
		if kind == "rect":
			var half: Vector2 = part["half"]
			best = maxf(best, maxf(half.x, half.y))
		else:
			best = maxf(best, float(part["r"]))
	return best

## Local vertical extent of a role: x is the top (min y), y is the bottom (max y).
static func vertical_span(file_name: String, role: String) -> Vector2:
	var min_y := 100000.0
	var max_y := -100000.0
	for part in _measure_parts(file_name, role):
		var kind := str(part["type"])
		if kind == "circle":
			var center: Vector2 = part["center"]
			var radius := float(part["r"])
			min_y = minf(min_y, center.y - radius)
			max_y = maxf(max_y, center.y + radius)
		elif kind == "capsule":
			var radius := float(part["r"])
			var cap_a: Vector2 = part["a"]
			var cap_b: Vector2 = part["b"]
			min_y = minf(min_y, minf(cap_a.y, cap_b.y) - radius)
			max_y = maxf(max_y, maxf(cap_a.y, cap_b.y) + radius)
		elif kind == "rect":
			var center: Vector2 = part["center"]
			var half: Vector2 = part["half"]
			min_y = minf(min_y, center.y - half.y)
			max_y = maxf(max_y, center.y + half.y)
	if max_y < min_y:
		return Vector2.ZERO
	return Vector2(min_y, max_y)

static func vertical_extent(file_name: String, role: String) -> float:
	var span := vertical_span(file_name, role)
	return span.y - span.x

## Local horizontal extent of a role: x is the left (min x), y is the right (max x).
static func horizontal_span(file_name: String, role: String) -> Vector2:
	var min_x := 100000.0
	var max_x := -100000.0
	for part in _measure_parts(file_name, role):
		var kind := str(part["type"])
		if kind == "circle":
			var center: Vector2 = part["center"]
			var radius := float(part["r"])
			min_x = minf(min_x, center.x - radius)
			max_x = maxf(max_x, center.x + radius)
		elif kind == "capsule":
			var radius := float(part["r"])
			var cap_a: Vector2 = part["a"]
			var cap_b: Vector2 = part["b"]
			min_x = minf(min_x, minf(cap_a.x, cap_b.x) - radius)
			max_x = maxf(max_x, maxf(cap_a.x, cap_b.x) + radius)
		elif kind == "rect":
			var center: Vector2 = part["center"]
			var half: Vector2 = part["half"]
			min_x = minf(min_x, center.x - half.x)
			max_x = maxf(max_x, center.x + half.x)
	if max_x < min_x:
		return Vector2.ZERO
	return Vector2(min_x, max_x)

static func horizontal_extent(file_name: String, role: String) -> float:
	var span := horizontal_span(file_name, role)
	return span.y - span.x

## Distance from the anchor to the outside of the shape. Movement and spawns use this.
static func bounds_radius(file_name: String, role: String) -> float:
	var best := 0.0
	for part in _measure_parts(file_name, role):
		var kind := str(part["type"])
		if kind == "circle":
			var center: Vector2 = part["center"]
			best = maxf(best, center.length() + float(part["r"]))
		elif kind == "capsule":
			var cap_a: Vector2 = part["a"]
			var cap_b: Vector2 = part["b"]
			var radius := float(part["r"])
			best = maxf(best, maxf(cap_a.length(), cap_b.length()) + radius)
		elif kind == "rect":
			var center: Vector2 = part["center"]
			var half: Vector2 = part["half"]
			for corner in [Vector2(half.x, half.y), Vector2(half.x, -half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y)]:
				best = maxf(best, (center + corner).length())
	return best

static func draw(canvas: CanvasItem, file_name: String, role: String, color: Color, frame: int = -1, scale: float = 1.0) -> void:
	for part in _parts_scaled(file_name, role, scale, frame):
		var kind := str(part["type"])
		if kind == "circle":
			canvas.draw_arc(part["center"], float(part["r"]), 0.0, TAU, 18, color, 1.0, false)
		elif kind == "capsule":
			var cap_a: Vector2 = part["a"]
			var cap_b: Vector2 = part["b"]
			var radius := float(part["r"])
			canvas.draw_arc(cap_a, radius, 0.0, TAU, 16, color, 1.0, false)
			canvas.draw_arc(cap_b, radius, 0.0, TAU, 16, color, 1.0, false)
			var dir := cap_b - cap_a
			if dir.length_squared() > 0.01:
				var normal := dir.orthogonal().normalized() * radius
				canvas.draw_line(cap_a + normal, cap_b + normal, color, 1.0, false)
				canvas.draw_line(cap_a - normal, cap_b - normal, color, 1.0, false)
		elif kind == "rect":
			var center: Vector2 = part["center"]
			var half: Vector2 = part["half"]
			canvas.draw_rect(Rect2(center - half, half * 2.0), color, false, 1.0)

static func _parts_scaled(file_name: String, role: String, scale: float, frame: int = -1) -> Array:
	var parts := _parts(file_name, role, frame)
	if absf(scale - 1.0) < 0.001:
		return parts
	var scaled: Array = []
	for part in parts:
		var copy: Dictionary = (part as Dictionary).duplicate()
		var kind := str(copy["type"])
		if kind == "circle" or kind == "rect":
			var center: Vector2 = copy["center"]
			copy["center"] = center * scale
		if kind == "circle" or kind == "capsule":
			copy["r"] = float(copy["r"]) * scale
		if kind == "capsule":
			var cap_a: Vector2 = copy["a"]
			var cap_b: Vector2 = copy["b"]
			copy["a"] = cap_a * scale
			copy["b"] = cap_b * scale
		if kind == "rect":
			var half: Vector2 = copy["half"]
			copy["half"] = half * scale
		scaled.append(copy)
	return scaled

## Ranks 1-3 of the Vending Machine keep the hand-authored circles from before
## the batch-6 shrink. Later Vending ranks and the other batch-6 bodies have
## no table, so the hurt shape is fit to the loaded pixels. Aura files are
## not hurt sources.
static func _wants_derived_hurt(file_name: String) -> bool:
	if file_name.ends_with("_aura.png"):
		return false
	if _has_authored(file_name, "hurt"):
		return false
	if file_name.begins_with("vending_machine_"):
		return true
	if file_name.ends_with("_body.png"):
		return true
	if file_name.begins_with("slime_small_r4") or file_name.begins_with("slime_small_r5"):
		return true
	return false

static func _has_authored(file_name: String, role: String) -> bool:
	var raw: Variant = entry(file_name).get(role, [])
	return typeof(raw) == TYPE_ARRAY and not (raw as Array).is_empty()

static func _derived_hurt(file_name: String) -> Array:
	if _derived.has(file_name):
		return _derived[file_name]
	var parts: Array = _fit_hurt(file_name)
	_derived[file_name] = parts
	return parts

static func _fit_hurt(file_name: String) -> Array:
	var tex := ArtLibrary.texture(file_name)
	if tex == null:
		return []
	var image := tex.get_image()
	if image == null or image.is_empty():
		return []
	var anchor := ArtLibrary.anchor(file_name)
	var pts: Array[Vector2] = []
	var occ := {}
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.5:
				continue
			if color.r8 == 20 and color.g8 == 18 and color.b8 == 31:
				continue
			var point := Vector2(float(x), float(y)) - anchor + Vector2(0.5, 0.5)
			pts.append(point)
			occ[Vector2i(int(floor(point.x)), int(floor(point.y)))] = true
	if pts.is_empty():
		return []
	var head := pts[0]
	var foot := pts[0]
	for point in pts:
		if point.y < head.y or (is_equal_approx(point.y, head.y) and absf(point.x) < absf(head.x)):
			head = point
		if point.y > foot.y or (is_equal_approx(point.y, foot.y) and absf(point.x) < absf(foot.x)):
			foot = point
	var sky := head + Vector2(0.0, -4.0)
	var remaining: Array[Vector2] = pts.duplicate()
	var circles: Array[Dictionary] = []
	var guard := 0
	while not remaining.is_empty() and guard < 80:
		guard += 1
		var step := maxi(int(remaining.size() / 40), 1)
		var best := remaining[0]
		var best_r := -1.0
		var i := 0
		while i < remaining.size():
			var candidate: Vector2 = remaining[i]
			var radius := _inscribed(candidate, occ, sky)
			if radius > best_r:
				best_r = radius
				best = candidate
			i += step
		var placed := best_r
		if placed < 0.8:
			placed = 1.25
			best = remaining[0]
		else:
			placed = minf(placed, best.distance_to(sky) - 0.2)
			placed = maxf(placed, 1.05)
		circles.append({"type": "circle", "center": best, "r": placed})
		var reach := placed + 1.02
		var next: Array[Vector2] = []
		for point in remaining:
			if point.distance_to(best) > reach:
				next.append(point)
		remaining = next
	# Every pixel on the top row and the bottom row has to sit inside the
	# shape, not merely within a pixel of it. A 1.2 circle on that pixel
	# does not reach the empty space four pixels above the head.
	for point in pts:
		if not is_equal_approx(point.y, head.y) and not is_equal_approx(point.y, foot.y):
			continue
		var gap := 9999.0
		for circle in circles:
			gap = minf(gap, point.distance_to(circle["center"]) - float(circle["r"]))
		if gap > 0.0:
			circles.append({"type": "circle", "center": point, "r": 1.2})
	return circles

static func _inscribed(center: Vector2, occ: Dictionary, sky: Vector2) -> float:
	var step := 1
	while step < 40:
		var rad := float(step) * 0.5
		var ok := true
		for k in 16:
			var ang := float(k) / 16.0 * TAU
			var probe := center + Vector2(cos(ang), sin(ang)) * rad
			if not occ.has(Vector2i(int(floor(probe.x)), int(floor(probe.y)))):
				ok = false
				break
		if not ok:
			return maxf(0.4, rad - 0.5)
		if center.distance_to(sky) <= rad:
			return maxf(0.4, rad - 0.15)
		step += 1
	return 8.0

## Spacing and the movement pad use every frame, so a pose that leans
## out of frame 0 still counts. A hit test passes the live frame instead.
static func _measure_parts(file_name: String, role: String) -> Array:
	_ensure()
	if role == "hurt":
		var frames: Variant = entry(file_name).get("hurt_frames", [])
		if typeof(frames) == TYPE_ARRAY and not (frames as Array).is_empty():
			var list: Array = frames
			var all: Array = []
			for frame in list:
				all.append_array(_decode_parts(frame))
			return all
	return _parts(file_name, role)

static func _parts(file_name: String, role: String, frame: int = -1) -> Array:
	_ensure()
	if role == "hurt" and frame >= 0:
		var frames: Variant = entry(file_name).get("hurt_frames", [])
		if typeof(frames) == TYPE_ARRAY and not (frames as Array).is_empty():
			var list: Array = frames
			var index := clampi(frame, 0, list.size() - 1)
			return _decode_parts(list[index])
	if role == "hurt" and _wants_derived_hurt(file_name):
		return _derived_hurt(file_name)
	var found := entry(file_name)
	var raw: Variant = found.get(role, [])
	if typeof(raw) != TYPE_ARRAY or (raw as Array).is_empty():
		if file_name.begins_with("dragon_enemies/"):
			return _dragon_hit(file_name, role)
		var key := file_name + ":" + role
		if not _warned.has(key):
			_warned[key] = true
			push_error("no %s hit shape for %s" % [role, file_name])
		return []
	return _decode_parts(raw)

## Body centre is the anchor. A wide sprite gets a capsule; a projectile stays a circle.
static func _dragon_hit(file_name: String, role: String) -> Array:
	var box := ArtLibrary.art_bbox(file_name)
	var body := role == "body"
	if box.x <= 18.0 and box.y <= 18.0:
		var radius := 0.42 * minf(box.x, box.y)
		if not body:
			radius *= 0.85
		return [{"type": "circle", "center": Vector2.ZERO, "r": maxf(radius, 2.0)}]
	var sx := 0.36 if body else 0.28
	var sy := 0.34 if body else 0.26
	var rx := maxf(box.x * sx, 3.0)
	var ry := maxf(box.y * sy, 3.0)
	if rx >= ry:
		var reach := maxf(rx - ry, 0.0)
		return [{"type": "capsule", "a": Vector2(-reach, 0.0), "b": Vector2(reach, 0.0), "r": ry}]
	var reach_y := maxf(ry - rx, 0.0)
	return [{"type": "capsule", "a": Vector2(0.0, -reach_y), "b": Vector2(0.0, reach_y), "r": rx}]

static func _decode_parts(raw: Variant) -> Array:
	if typeof(raw) != TYPE_ARRAY:
		return []
	var out: Array = []
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var src: Dictionary = item
		var kind := str(src.get("type", ""))
		var part := {"type": kind}
		if kind == "circle":
			part["center"] = _vec(src.get("center", [0, 0]))
			part["r"] = float(src.get("r", 0.0))
		elif kind == "capsule":
			part["a"] = _vec(src.get("a", [0, 0]))
			part["b"] = _vec(src.get("b", [0, 0]))
			part["r"] = float(src.get("r", 0.0))
		elif kind == "rect":
			part["center"] = _vec(src.get("center", [0, 0]))
			part["half"] = _vec(src.get("half", [1, 1]))
		else:
			push_error("unknown hit shape %s" % kind)
			continue
		out.append(part)
	return out

static func _vec(value: Variant) -> Vector2:
	var pair: Array = value
	return Vector2(float(pair[0]), float(pair[1]))

static func _kind_rank(kind: String) -> int:
	match kind:
		"circle":
			return 0
		"capsule":
			return 1
		_:
			return 2

static func _gap_pair(part_a: Dictionary, origin_a: Vector2, part_b: Dictionary, origin_b: Vector2) -> float:
	if _kind_rank(str(part_a["type"])) > _kind_rank(str(part_b["type"])):
		return _gap_pair(part_b, origin_b, part_a, origin_a)
	var kind_a := str(part_a["type"])
	var kind_b := str(part_b["type"])
	if kind_a == "circle" and kind_b == "circle":
		var center_a: Vector2 = origin_a + part_a["center"]
		var center_b: Vector2 = origin_b + part_b["center"]
		return center_a.distance_to(center_b) - float(part_a["r"]) - float(part_b["r"])
	if kind_a == "circle" and kind_b == "capsule":
		var center: Vector2 = origin_a + part_a["center"]
		var dist := _dist_point_seg(center, origin_b + part_b["a"], origin_b + part_b["b"])
		return dist - float(part_a["r"]) - float(part_b["r"])
	if kind_a == "circle" and kind_b == "rect":
		var center: Vector2 = origin_a + part_a["center"]
		var rect_center: Vector2 = origin_b + part_b["center"]
		return _sdf_box(center - rect_center, part_b["half"]) - float(part_a["r"])
	if kind_a == "capsule" and kind_b == "capsule":
		var dist := _dist_seg_seg(origin_a + part_a["a"], origin_a + part_a["b"], origin_b + part_b["a"], origin_b + part_b["b"])
		return dist - float(part_a["r"]) - float(part_b["r"])
	if kind_a == "capsule" and kind_b == "rect":
		var dist := _dist_seg_aabb(origin_a + part_a["a"], origin_a + part_a["b"], origin_b + part_b["center"], part_b["half"])
		return dist - float(part_a["r"])
	var half_a: Vector2 = part_a["half"]
	var half_b: Vector2 = part_b["half"]
	return _gap_aabb(origin_a + part_a["center"], half_a, origin_b + part_b["center"], half_b)

static func _gap_point(point: Vector2, part: Dictionary) -> float:
	var kind := str(part["type"])
	if kind == "circle":
		return point.distance_to(part["center"]) - float(part["r"])
	if kind == "capsule":
		return _dist_point_seg(point, part["a"], part["b"]) - float(part["r"])
	return _sdf_box(point - part["center"], part["half"])

static func _sdf_box(point: Vector2, half: Vector2) -> float:
	var delta := point.abs() - half
	var outside := Vector2(maxf(delta.x, 0.0), maxf(delta.y, 0.0))
	return outside.length() + minf(maxf(delta.x, delta.y), 0.0)

static func _gap_aabb(center_a: Vector2, half_a: Vector2, center_b: Vector2, half_b: Vector2) -> float:
	var delta := (center_a - center_b).abs()
	var limit := half_a + half_b
	var overlap := limit - delta
	if overlap.x > 0.0 and overlap.y > 0.0:
		return -minf(overlap.x, overlap.y)
	return Vector2(maxf(delta.x - limit.x, 0.0), maxf(delta.y - limit.y, 0.0)).length()

static func _dist_point_seg(point: Vector2, cap_a: Vector2, cap_b: Vector2) -> float:
	var span := cap_b - cap_a
	var length_sq := span.length_squared()
	if length_sq < 0.0001:
		return point.distance_to(cap_a)
	var t := clampf((point - cap_a).dot(span) / length_sq, 0.0, 1.0)
	return point.distance_to(cap_a + span * t)

static func _dist_seg_seg(p1: Vector2, q1: Vector2, p2: Vector2, q2: Vector2) -> float:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var rel := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(rel)
	var s := 0.0
	var t := 0.0
	var eps := 0.00001
	if a <= eps and e <= eps:
		return p1.distance_to(p2)
	if a <= eps:
		t = clampf(f / e, 0.0, 1.0)
	elif e <= eps:
		s = clampf(-d1.dot(rel) / a, 0.0, 1.0)
	else:
		var b := d1.dot(d2)
		var c := d1.dot(rel)
		var denom := a * e - b * b
		s = 0.0 if denom < eps else clampf((b * f - c * e) / denom, 0.0, 1.0)
		t = (b * s + f) / e
		if t < 0.0:
			t = 0.0
			s = clampf(-c / a, 0.0, 1.0)
		elif t > 1.0:
			t = 1.0
			s = clampf((b - c) / a, 0.0, 1.0)
	return (p1 + d1 * s).distance_to(p2 + d2 * t)

static func _dist_seg_aabb(cap_a: Vector2, cap_b: Vector2, center: Vector2, half: Vector2) -> float:
	var bmin := center - half
	var bmax := center + half
	if _point_in(cap_a, bmin, bmax) or _point_in(cap_b, bmin, bmax) or _seg_hits_aabb(cap_a, cap_b, bmin, bmax):
		return 0.0
	var best := _dist_seg_seg(cap_a, cap_b, Vector2(bmin.x, bmin.y), Vector2(bmax.x, bmin.y))
	best = minf(best, _dist_seg_seg(cap_a, cap_b, Vector2(bmax.x, bmin.y), Vector2(bmax.x, bmax.y)))
	best = minf(best, _dist_seg_seg(cap_a, cap_b, Vector2(bmax.x, bmax.y), Vector2(bmin.x, bmax.y)))
	best = minf(best, _dist_seg_seg(cap_a, cap_b, Vector2(bmin.x, bmax.y), Vector2(bmin.x, bmin.y)))
	return best

static func _point_in(point: Vector2, bmin: Vector2, bmax: Vector2) -> bool:
	return point.x >= bmin.x and point.x <= bmax.x and point.y >= bmin.y and point.y <= bmax.y

static func _seg_hits_aabb(cap_a: Vector2, cap_b: Vector2, bmin: Vector2, bmax: Vector2) -> bool:
	var span := [0.0, 1.0]
	var delta := cap_b - cap_a
	if not _slab(cap_a.x, delta.x, bmin.x, bmax.x, span):
		return false
	if not _slab(cap_a.y, delta.y, bmin.y, bmax.y, span):
		return false
	return true

static func _slab(origin: float, delta: float, min_b: float, max_b: float, span: Array) -> bool:
	var t0: float = span[0]
	var t1: float = span[1]
	if absf(delta) < 0.0000001:
		return origin >= min_b and origin <= max_b
	var inv := 1.0 / delta
	var near := (min_b - origin) * inv
	var far := (max_b - origin) * inv
	if near > far:
		var swap := near
		near = far
		far = swap
	t0 = maxf(t0, near)
	t1 = minf(t1, far)
	span[0] = t0
	span[1] = t1
	return t0 <= t1
