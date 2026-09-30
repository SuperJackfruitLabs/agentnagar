## Collects flat-shaded boxes, prisms and triangles, and builds them as one
## mesh per material: a whole building or a street of houses costs a few
## draw calls, not hundreds. Materials are shared by colour across batches,
## so a night change to one window material lights every window.
extends RefCounted
class_name MeshBatch

static var _materials := {}

var _tools := {}


## A shared material for this colour, roughness and emission.
static func material(colour: Color, roughness := 0.85, emission := Color(0, 0, 0, 0), metallic := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%s|%.2f" % [colour.to_html(), roughness, emission.to_html(), metallic]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.roughness = roughness
		m.metallic = metallic
		if emission.a > 0.0:
			m.emission_enabled = true
			m.emission = Color(emission.r, emission.g, emission.b)
			m.emission_energy_multiplier = 0.0
		_materials[key] = m
	return _materials[key]


func _tool(m: Material) -> SurfaceTool:
	if not _tools.has(m):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[m] = st
	return _tools[m]


func is_empty() -> bool:
	return _tools.is_empty()


## One triangle, wound so its front faces along `outward`.
func tri(a: Vector3, b: Vector3, c: Vector3, m: Material, outward := Vector3.ZERO) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	if outward != Vector3.ZERO and n.dot(outward) > 0.0:
		var t := b
		b = c
		c = t
		n = -n
	elif outward == Vector3.ZERO:
		# Godot's front faces wind clockwise: the geometric normal is -n.
		var t := b
		b = c
		c = t
		n = -n
	var st := _tool(m)
	st.set_normal(-n.normalized())
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, m: Material, outward: Vector3) -> void:
	tri(a, b, c, m, outward)
	tri(a, c, d, m, outward)


## A box of `size` centred on `xf`'s origin.
func box(size: Vector3, xf: Transform3D, m: Material) -> void:
	var h := size / 2.0
	var c := []
	for k in 8:
		c.append(xf * Vector3(h.x if k & 1 else -h.x, h.y if k & 2 else -h.y, h.z if k & 4 else -h.z))
	var b := xf.basis
	quad(c[1], c[3], c[7], c[5], m, b.x)
	quad(c[0], c[4], c[6], c[2], m, -b.x)
	quad(c[2], c[6], c[7], c[3], m, b.y)
	quad(c[0], c[1], c[5], c[4], m, -b.y)
	quad(c[4], c[5], c[7], c[6], m, b.z)
	quad(c[0], c[2], c[3], c[1], m, -b.z)


## An axis-aligned box from its minimum corner to its maximum.
func block(from: Vector3, to: Vector3, m: Material) -> void:
	box((to - from).abs(), Transform3D(Basis(), (from + to) / 2.0), m)


## A polygon `profile` (x across, y up) extruded `length` along z, centred
## on `xf`'s origin, with both ends capped.
func prism(profile: PackedVector2Array, length: float, xf: Transform3D, m: Material, caps := true) -> void:
	var p := profile
	if Geometry2D.is_polygon_clockwise(p):
		p = PackedVector2Array()
		for k in range(profile.size() - 1, -1, -1):
			p.append(profile[k])
	var hz := length / 2.0
	var b := xf.basis
	for k in p.size():
		var u: Vector2 = p[k]
		var v: Vector2 = p[(k + 1) % p.size()]
		var out2 := Vector2(v.y - u.y, u.x - v.x)
		var outward := b * Vector3(out2.x, out2.y, 0)
		quad(xf * Vector3(u.x, u.y, -hz), xf * Vector3(v.x, v.y, -hz), xf * Vector3(v.x, v.y, hz), xf * Vector3(u.x, u.y, hz), m, outward)
	if caps:
		var idx := Geometry2D.triangulate_polygon(p)
		for k in range(0, idx.size(), 3):
			var a: Vector2 = p[idx[k]]
			var bb: Vector2 = p[idx[k + 1]]
			var c: Vector2 = p[idx[k + 2]]
			tri(xf * Vector3(a.x, a.y, hz), xf * Vector3(bb.x, bb.y, hz), xf * Vector3(c.x, c.y, hz), m, b.z)
			tri(xf * Vector3(a.x, a.y, -hz), xf * Vector3(bb.x, bb.y, -hz), xf * Vector3(c.x, c.y, -hz), m, -b.z)


## A hip roof over a w × d rectangle centred on `at`, rising `h`; the ridge
## runs along the longer side.
func hip_roof(w: float, d: float, h: float, at: Vector3, m: Material, overhang := 0.3) -> void:
	var hw := w / 2.0 + overhang
	var hd := d / 2.0 + overhang
	var inset := minf(hw, hd)
	var c := [at + Vector3(-hw, 0, -hd), at + Vector3(hw, 0, -hd), at + Vector3(hw, 0, hd), at + Vector3(-hw, 0, hd)]
	var r0: Vector3
	var r1: Vector3
	if hw >= hd:
		r0 = at + Vector3(-hw + inset, h, 0)
		r1 = at + Vector3(hw - inset, h, 0)
		quad(c[0], c[1], r1, r0, m, Vector3(0, 1, -1))
		quad(c[2], c[3], r0, r1, m, Vector3(0, 1, 1))
		tri(c[1], c[2], r1, m, Vector3(1, 1, 0))
		tri(c[3], c[0], r0, m, Vector3(-1, 1, 0))
	else:
		r0 = at + Vector3(0, h, -hd + inset)
		r1 = at + Vector3(0, h, hd - inset)
		quad(c[1], c[2], r1, r0, m, Vector3(1, 1, 0))
		quad(c[3], c[0], r0, r1, m, Vector3(-1, 1, 0))
		tri(c[0], c[1], r0, m, Vector3(0, 1, -1))
		tri(c[2], c[3], r1, m, Vector3(0, 1, 1))
	quad(c[0], c[1], c[2], c[3], m, Vector3.DOWN)


## A faceted dome (a hemisphere of `rings` × `segments`) on `at`.
func dome(radius: float, at: Vector3, m: Material, segments := 16, rings := 5, squash := 1.0) -> void:
	for i in rings:
		var a0 := PI / 2.0 * i / rings
		var a1 := PI / 2.0 * (i + 1) / rings
		for j in segments:
			var b0 := TAU * j / segments
			var b1 := TAU * (j + 1) / segments
			var p := func(a: float, bb: float) -> Vector3:
				return at + Vector3(cos(a) * cos(bb) * radius, sin(a) * radius * squash, cos(a) * sin(bb) * radius)
			var mid: Vector3 = p.call((a0 + a1) / 2.0, (b0 + b1) / 2.0) - at
			if i == rings - 1:
				tri(p.call(a0, b0), p.call(a0, b1), p.call(a1, b0), m, mid)
			else:
				quad(p.call(a0, b0), p.call(a0, b1), p.call(a1, b1), p.call(a1, b0), m, mid)


## A faceted upright cylinder from `at` up `h`.
func cylinder(radius: float, h: float, at: Vector3, m: Material, segments := 16, top := true) -> void:
	for j in segments:
		var b0 := TAU * j / segments
		var b1 := TAU * (j + 1) / segments
		var u := Vector3(cos(b0), 0, sin(b0)) * radius
		var v := Vector3(cos(b1), 0, sin(b1)) * radius
		quad(at + u, at + v, at + v + Vector3(0, h, 0), at + u + Vector3(0, h, 0), m, (u + v) / 2.0)
		if top:
			tri(at + Vector3(0, h, 0), at + u + Vector3(0, h, 0), at + v + Vector3(0, h, 0), m, Vector3.UP)


## Builds a node holding one MeshInstance3D per material.
func build(name_: String, shadows := true) -> Node3D:
	var root := Node3D.new()
	root.name = name_
	for m in _tools:
		var mi := MeshInstance3D.new()
		mi.mesh = _tools[m].commit()
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	_tools.clear()
	return root
