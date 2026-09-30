## Plants that sway (interactions spec section 2): a soft shape's clumps
## part round anyone whose body passes through them. Client-side only:
## nothing in the core depends on it.
##
## Built once from the layout's placements and the catalogue (which
## placements are soft, and where), then given the clumps a pack drew
## there (bind): a spatial hash of them per district, a grid of CELL_M
## cells over the district's soft ground. Each frame (update), for the
## people within REACH_M of the camera only, the clumps their body circle
## overlaps are pushed away from them:
##
## - a 3D pack's clump (an instance of a MultiMesh) gets the push in its
##   custom data (custom_data_of): the push (its direction, in the clump's
##   own frame, times its strength), where its ease-in starts, and when it
##   came; the sway shader eases it over and springs it back from then;
## - a pixel-art clump (a sprite) plays its three rustle frames: pushed
##   over while touched, swinging back, then at rest.
##
## Either way a clump comes to rest within SETTLE_S of its last contact.
## Updating allocates nothing: the hash, the clumps' state and the list of
## rustling sprites are made at bind.
extends RefCounted
class_name SoftContacts

## Contacts are found only for people within this many metres of the
## camera (spec section 2): of the ground point in the middle of its view
## (StylePack.sway_centre).
const REACH_M := 15.0
## A person's body circle, metres: legs and hips, where they brush grass.
const BODY_RADIUS_M := 0.25
## A clump is still again this long after its last contact (spec: "springs
## back within a second").
const SETTLE_S := 1.0
## The side of a hash cell, metres: about one clump a cell (meadows plant
## one every 25 cm), so the cells a body circle and a clump's reach span
## hold little beyond the clumps it touches.
const CELL_M := 0.25
## How a 3D clump moves, as the sway shader draws it (see spring): pushed,
## it eases over for ATTACK_S (so grass never jumps, even at someone
## already standing in it as they come within reach), holds for HOLD_S
## (longer than two frames down to 20 frames a second, so a body looked at
## every other frame holds it: see update), then springs back,
## swinging past upright once, decaying at SPRING_DECAY a second at
## SPRING_RATE radians a second, faded out from SPRING_FADE_S to
## SPRING_END_S after the push, from when it stands upright: a little
## inside SETTLE_S, so a frame's rounding never carries it past.
const ATTACK_S := 0.08
const HOLD_S := 0.1
const SPRING_DECAY := 4.5
const SPRING_RATE := 9.0
const SPRING_FADE_S := 0.7
const SPRING_END_S := 0.95
## A pixel-art clump's rustle: pushed over (frame 1) until this long after
## its last contact, then swinging back (frame 2) until RUSTLE_BACK_S, then
## at rest (frame 0).
const RUSTLE_PUSHED_S := 0.3
const RUSTLE_BACK_S := 0.65
## The contacts' clock runs from 0 up to this and starts over, so the
## contact times a shader reads stay exact in 32 bits. Every clump's contact
## time moves back with it (_start_over).
const CLOCK_WRAP_S := 1024.0

## Seconds, for contact times (see CLOCK_WRAP_S); the sway shader's `now`.
var clock := 0.0
## Soft placement ID -> [district index, its soft shapes' bounds (Rect2,
## metres)...], from the layout (from_layout).
var areas := {}
## Each district's hash of its clumps (see Grid), in the layout's order.
var _grids: Array[Grid] = []
## Per clump, in bind order: its root (metres), its reach across the
## ground (metres), how its own frame is turned (the cosine and sine of its
## yaw, to put a push in it), which of the bound sets it belongs to and its
## index there, and its district.
var _x := PackedFloat32Array()
var _z := PackedFloat32Array()
var _reach := PackedFloat32Array()
var _cos := PackedFloat32Array()
var _sin := PackedFloat32Array()
var _set := PackedInt32Array()
var _index := PackedInt32Array()
var _district := PackedInt32Array()
## Per clump, its last push: strength (0 to 1), the direction it leans (the
## ground, away from who touched it), the lean its ease-in started from
## (of its strength; see spring) and when (clock).
var _strength := PackedFloat32Array()
var _start := PackedFloat32Array()
var _dir_x := PackedFloat32Array()
var _dir_z := PackedFloat32Array()
## (Times in 64 bits, as the clock is: a time rounded to 32 bits can lie
## after the clock that set it.)
var _touched := PackedFloat64Array()
## Per clump, the frame (_frames) it was last pushed on: a push is shown
## once a frame, the hardest.
var _pushed_on := PackedInt32Array()
var _frames := 0
## The bound sets (see bind), for each whether it draws sprites, and its
## MultiMesh (null for sprites).
var _sets: Array = []
var _sprites := PackedByteArray()
var _multimeshes: Array[MultiMesh] = []
## The sway materials of the bound MultiMeshes, whose `now` follows the
## clock while anything moves.
var _materials: Array[ShaderMaterial] = []
## The sprites rustling now (indices of clumps, the first _rustling_count),
## and the frame each clump shows.
var _rustling := PackedInt32Array()
var _rustling_count := 0
var _frame := PackedByteArray()
## The clock at the last contact; nothing moves once SETTLE_S has passed.
var _last_contact := -INF
## For tests: while set, the custom data last written to each 3D clump is
## kept in `written`, by clump (a MultiMesh's own is not readable
## headless).
var record_writes := false
var written := {}


## One district's clumps: a grid of CELL_M cells over its soft ground, and
## the clumps rooted in each, packed cell after cell: `items[start[c]]` to
## `items[start[c + 1] - 1]`. Its clumps reach at most `reach` from their
## roots, so a body circle looks in the cells that far round it.
class Grid:
	var origin := Vector2.ZERO
	var cols := 0
	var rows := 0
	var bounds := Rect2()
	var reach := 0.0
	var start := PackedInt32Array()
	var items := PackedInt32Array()


## The layout's soft ground, from its placements and the catalogue: each
## placement of a kind with soft shapes, by district. A sized kind with soft
## shapes and no footprint (a meadow) is soft over its whole lot; any other
## kind's soft shapes are turned and placed as its footprint is.
static func from_layout(manifest: Dictionary, kinds: Dictionary) -> SoftContacts:
	var out := SoftContacts.new()
	var districts: Array = manifest.get("city", {}).get("districts", [])
	for d in districts.size():
		var one := {"city": {"districts": [districts[d]]}}
		for p in CityGeometry.placements(one):
			var kind: Dictionary = kinds.get(p["kind"], {})
			var soft: Array = kind.get("soft", [])
			if soft.is_empty():
				continue
			var shapes := []
			if kind.get("footprint", []).is_empty() and p["size"] != Vector2.ZERO:
				shapes.append(CityGeometry.lot(p))
			else:
				shapes.append_array(CityGeometry.footprint_rects({"footprint": soft}, p))
				for s in soft:
					if s.has("r"):
						var turn := Transform2D(deg_to_rad(float(p["facing"])), p["pos"])
						var c: Vector2 = turn * (Vector2(s["x"], s["z"]) / 100.0)
						var r := float(s["r"]) / 100.0
						shapes.append(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0))
			if not shapes.is_empty():
				out.areas[p["id"]] = [d] + shapes
		out._grids.append(Grid.new())
	return out


## Takes the clumps a pack drew on soft ground (StylePack.soft_instances):
## each set is either
##
## - {"multimesh": MultiMeshInstance3D, "reach": metres}: its instances,
##   whose transforms and placement IDs it carries (meta `instance_xforms`
##   and `placement_ids`), each pushed through its custom data; or
## - {"sprites": [Sprite2D], "points": PackedVector2Array (their roots,
##   metres), "id": placement ID, "reach": metres, "rustle": Callable
##   (sprite, frame)}, each shown its rustle frame by the callable.
##
## Only clumps of soft placements, rooted in their soft shapes, are kept.
## Builds each district's hash.
func bind(sets: Array) -> void:
	_sets = sets.duplicate()
	for s in _sets.size():
		var set_: Dictionary = _sets[s]
		if set_.has("multimesh"):
			var node: MultiMeshInstance3D = set_["multimesh"]
			var xforms: Array = node.get_meta("instance_xforms", [])
			var ids: PackedStringArray = node.get_meta("placement_ids", PackedStringArray())
			for k in mini(xforms.size(), ids.size()):
				var x: Transform3D = xforms[k]
				var bx := Vector2(x.basis.x.x, x.basis.x.z).normalized()
				_add(s, k, ids[k], Vector2(x.origin.x, x.origin.z), float(set_["reach"]), bx.x, -bx.y)
			for surface in node.multimesh.mesh.get_surface_count() if node.multimesh.mesh != null else 0:
				var m = node.multimesh.mesh.surface_get_material(surface)
				if m is ShaderMaterial and not _materials.has(m):
					_materials.append(m)
			_sprites.append(0)
			_multimeshes.append(node.multimesh)
		else:
			var points: PackedVector2Array = set_["points"]
			for k in points.size():
				_add(s, k, str(set_["id"]), points[k], float(set_["reach"]), 1.0, 0.0)
			_sprites.append(1)
			_multimeshes.append(null)
	var n := _x.size()
	_strength.resize(n)
	_start.resize(n)
	_dir_x.resize(n)
	_dir_z.resize(n)
	_touched.resize(n)
	_touched.fill(-INF)
	_pushed_on.resize(n)
	_pushed_on.fill(-1)
	_frame.resize(n)
	_rustling.resize(n)
	_build_grids()


func _add(s: int, k: int, id: String, at: Vector2, reach: float, cos_yaw: float, sin_yaw: float) -> void:
	var area: Array = areas.get(id, [])
	if area.is_empty() or not area.slice(1).any(func(r: Rect2): return r.grow(1e-3).has_point(at)):
		return
	_x.append(at.x)
	_z.append(at.y)
	_reach.append(reach)
	_cos.append(cos_yaw)
	_sin.append(sin_yaw)
	_set.append(s)
	_index.append(k)
	_district.append(int(area[0]))


## Lists each clump in the cell of its district's grid its root stands in.
func _build_grids() -> void:
	for id in areas:
		var area: Array = areas[id]
		var g: Grid = _grids[int(area[0])]
		for r in area.slice(1):
			g.bounds = r if g.bounds.size == Vector2.ZERO else g.bounds.merge(r)
	for g in _grids:
		g.origin = g.bounds.position
		g.cols = maxi(1, ceili(g.bounds.size.x / CELL_M))
		g.rows = maxi(1, ceili(g.bounds.size.y / CELL_M))
		g.start.resize(g.cols * g.rows + 1)
	var cells := PackedInt32Array()
	cells.resize(_x.size())
	for i in _x.size():
		var g: Grid = _grids[_district[i]]
		g.reach = maxf(g.reach, _reach[i])
		var cx := clampi(floori((_x[i] - g.origin.x) / CELL_M), 0, g.cols - 1)
		var cz := clampi(floori((_z[i] - g.origin.y) / CELL_M), 0, g.rows - 1)
		cells[i] = cz * g.cols + cx
		g.start[cells[i] + 1] += 1
	for g in _grids:
		for c in g.cols * g.rows:
			g.start[c + 1] += g.start[c]
		g.items.resize(g.start[g.cols * g.rows])
		# A body circle's clumps reach into it from outside the soft ground.
		g.bounds = g.bounds.grow(g.reach + BODY_RADIUS_M)
	for g_index in _grids.size():
		var g: Grid = _grids[g_index]
		var next := g.start.duplicate()
		for i in _x.size():
			if _district[i] == g_index:
				g.items[next[cells[i]]] = i
				next[cells[i]] += 1


func instance_count() -> int:
	return _x.size()


## Clump `i`'s root on the ground, metres.
func instance_point(i: int) -> Vector2:
	return Vector2(_x[i], _z[i])


## How far clump `i` reaches across the ground from its root, metres.
func reach_of(i: int) -> float:
	return _reach[i]


## The way clump `i` was last pushed, on the ground (away from whoever
## touched it).
func push_direction(i: int) -> Vector2:
	return Vector2(_dir_x[i], _dir_z[i])


## How far clump `i` is bent now, 0 (upright) to 1 (pushed right over),
## as the sway shader draws it (its swing back past upright counts as
## bent too).
func bend_of(i: int) -> float:
	return absf(_strength[i] * spring(clock - _touched[i], _start[i]))


## How far clump `i` leans now toward `direction` (a unit vector on the
## ground), of right over: negative leaning away from it.
func signed_bend_of(i: int, direction: Vector2) -> float:
	return _strength[i] * spring(clock - _touched[i], _start[i]) * push_direction(i).dot(direction)


## The custom data SoftContacts gives clump `i`'s instance (a 3D clump's;
## the sway shader reads it): (push x, push z) in the clump's own frame,
## its direction times its strength; the lean its ease-in starts from; and
## when it came (clock).
func custom_data_of(i: int) -> Color:
	var dx := _dir_x[i] * _strength[i]
	var dz := _dir_z[i] * _strength[i]
	return Color(dx * _cos[i] - dz * _sin[i], dx * _sin[i] + dz * _cos[i], _start[i], _touched[i])


## How far a clump pushed `age` seconds ago leans, of its push: easing
## from `start` (0 upright; negative leaning back) to right over (1) by
## ATTACK_S, held there HOLD_S, then swinging back once past upright, and 0
## from SPRING_END_S on (and before the push). The sway shader draws the
## same.
static func spring(age: float, start := 0.0) -> float:
	if age < 0.0 or age >= SPRING_END_S:
		return 0.0
	if age < ATTACK_S:
		return lerpf(start, 1.0, age / ATTACK_S)
	if age < ATTACK_S + HOLD_S:
		return 1.0
	var back := age - ATTACK_S - HOLD_S
	return exp(-SPRING_DECAY * back) * cos(SPRING_RATE * back) * (1.0 - smoothstep(SPRING_FADE_S, SPRING_END_S, age))


## The rustle frame of a clump pushed `age` seconds ago.
static func rustle_frame(age: float) -> int:
	if age < 0.0 or age >= RUSTLE_BACK_S:
		return 0
	return 1 if age < RUSTLE_PUSHED_S else 2


## One frame: the clock moves on by `delta`, and each of the first `count`
## of `bodies` (people's drawn ground points, metres) within REACH_M of
## `centre` (the ground point in the middle of the view, metres) pushes
## the clumps its body circle overlaps, every other frame (half the bodies
## on one frame, half on the next; the push holds between). Rustling
## sprites move on through their frames.
func update(centre: Vector2, bodies: PackedVector2Array, count: int, delta: float) -> void:
	clock += delta
	_frames += 1
	var wrapped := clock >= CLOCK_WRAP_S
	if wrapped:
		_start_over()
	if _x.is_empty():
		return
	var reach2 := REACH_M * REACH_M
	# Each body is looked at every other frame, half of them on each: a
	# clump it pushed holds over (HOLD_S) until it is looked at again.
	for b in range(_frames % 2, count, 2):
		var at := bodies[b]
		if at.distance_squared_to(centre) > reach2:
			continue
		for g in _grids:
			if g.bounds.has_point(at):
				_touch(g, at)
	_advance_rustles()
	if wrapped or clock - _last_contact <= SETTLE_S + delta:
		for m in _materials:
			m.set_shader_parameter(&"now", clock)


## The clock starts over (CLOCK_WRAP_S): every contact time moves back with
## it, and every 3D clump ever touched is given its moved time, so one
## still moving goes on springing back across the wrap. A settled one's
## push is let go too: the shader's `now` restarts from 0, and a clump left
## with its old time and push would bend again as that time came round.
## Rare (every CLOCK_WRAP_S seconds), so it may look at every clump.
func _start_over() -> void:
	clock -= CLOCK_WRAP_S
	_last_contact -= CLOCK_WRAP_S
	for i in _x.size():
		_touched[i] -= CLOCK_WRAP_S
		if _sprites[_set[i]] != 0 or is_inf(_touched[i]):
			continue
		if clock - _touched[i] >= SPRING_END_S:
			_strength[i] = 0.0
		_write(i, custom_data_of(i))


## Gives 3D clump `i`'s instance `custom` as its custom data.
func _write(i: int, custom: Color) -> void:
	_multimeshes[_set[i]].set_instance_custom_data(_index[i], custom)
	if record_writes:
		written[i] = custom


## Pushes the clumps in grid `g` that a body circle at `at` overlaps.
## The hot loop: the arrays it reads are held in locals.
func _touch(g: Grid, at: Vector2) -> void:
	var look := BODY_RADIUS_M + g.reach
	var x0 := maxi(0, floori((at.x - look - g.origin.x) / CELL_M))
	var x1 := mini(g.cols - 1, floori((at.x + look - g.origin.x) / CELL_M))
	var z0 := maxi(0, floori((at.y - look - g.origin.y) / CELL_M))
	var z1 := mini(g.rows - 1, floori((at.y + look - g.origin.y) / CELL_M))
	var start := g.start
	var items := g.items
	var xs := _x
	var zs := _z
	var reaches := _reach
	var strengths := _strength
	var pushed_on := _pushed_on
	var touched := _touched
	var frame := _frames
	for cz in range(z0, z1 + 1):
		var row := cz * g.cols
		for k in range(start[row + x0], start[row + x1 + 1]):
			var i := items[k]
			var dx := xs[i] - at.x
			var dz := zs[i] - at.y
			var r := BODY_RADIUS_M + reaches[i]
			var d2 := dx * dx + dz * dz
			if d2 >= r * r:
				continue
			var d := sqrt(d2)
			# Pushed hardest close in, and still well over most of the way out.
			var strength := 1.0 - d2 / (r * r)
			# Where two people brush one clump, the harder push shows: one
			# weaker than this frame's push, or than the clump's lean now, is
			# left be.
			if pushed_on[i] == frame and strengths[i] >= strength:
				continue
			var age := clock - touched[i]
			var held := age >= ATTACK_S and age < ATTACK_S + HOLD_S
			if held and strengths[i] > strength + 1e-4:
				continue
			if d > 1e-4:
				dx /= d
				dz /= d
			else:
				dx = 0.0
				dz = 1.0
			var drawn := strengths[i] if held else strengths[i] * spring(age, _start[i])
			if absf(drawn) > strength + 1e-4:
				continue
			# The lean now, toward the new push and of its strength: the push
			# takes the clump on from there.
			_push(i, dx, dz, strength, drawn * (_dir_x[i] * dx + _dir_z[i] * dz) / strength)


## Records clump `i`'s push toward (dx, dz), of `strength`, while it leans
## `along` (of that strength) that way now, and shows it: a MultiMesh
## instance's custom data; a sprite starts rustling. The push takes the
## clump on from its lean, never with a jump: a clump leaning its way is
## put that far into its ease-in (its contact time set back); one leaning
## back eases from there (it keeps an ease-in that started farther back).
func _push(i: int, dx: float, dz: float, strength: float, along: float) -> void:
	var start := 0.0
	var into := 0.0
	if along >= 0.0:
		into = ATTACK_S * minf(along, 1.0)
	elif _start[i] <= along:
		start = _start[i]
		into = ATTACK_S * (along - start) / (1.0 - start)
	else:
		start = maxf(along, -1.0)
	_strength[i] = strength
	_start[i] = start
	_dir_x[i] = dx
	_dir_z[i] = dz
	_touched[i] = clock - into
	_pushed_on[i] = _frames
	_last_contact = clock
	var s := _set[i]
	if _sprites[s] == 0:
		# custom_data_of, written out: this is the hot path.
		var px := dx * strength
		var pz := dz * strength
		var custom := Color(px * _cos[i] - pz * _sin[i], px * _sin[i] + pz * _cos[i], start, clock - into)
		_multimeshes[s].set_instance_custom_data(_index[i], custom)
		if record_writes:
			written[i] = custom
		return
	if _frame[i] == 0:
		_rustling[_rustling_count] = i
		_rustling_count += 1
	_show_frame(i, 1)


## Moves each rustling sprite on to the frame its last contact's age
## gives; one at rest leaves the list.
func _advance_rustles() -> void:
	var k := 0
	while k < _rustling_count:
		var i := _rustling[k]
		var frame := rustle_frame(clock - _touched[i])
		_show_frame(i, frame)
		if frame == 0:
			_rustling_count -= 1
			_rustling[k] = _rustling[_rustling_count]
		else:
			k += 1


func _show_frame(i: int, frame: int) -> void:
	if _frame[i] == frame:
		return
	_frame[i] = frame
	var set_: Dictionary = _sets[_set[i]]
	set_["rustle"].call(set_["sprites"][_index[i]], frame)
