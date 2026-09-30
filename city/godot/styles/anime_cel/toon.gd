## The anime style's shading: Godot's own toon diffuse and specular with a
## soft rim, converted in place so the materials night lighting drives stay
## the same objects; inverted-hull ink outlines for characters; and the
## full-screen line pass that inks the city.
extends RefCounted
class_name Toon

const OUTLINE := preload("res://styles/anime_cel/shaders/outline.gdshader")
const LINES := preload("res://styles/anime_cel/shaders/lines.gdshader")
## A light-to-shadow step this crisp (toon diffuse reads roughness as the
## step's softness).
const STEP_ROUGHNESS := 0.32
## Glass in the buildings people walk into (the workshop's and the
## library's kit pieces) shows the rooms and the day through it, as the
## sheets draw it; other glass (towers, houses: no rooms behind) stays
## opaque.
const SEE_THROUGH := ["/hall_", "/lib_"]
const GLASS_ALPHA := 0.32


## Toon copies of materials made at runtime, which other styles share
## (MeshBatch caches them by colour): instance id -> copy.
static var _copies := {}


## Turns every lit material under `node` (itself included) toon, once. The
## anime kit's own imported materials turn in place (night lighting holds
## them); materials made at runtime are shared with other styles, so they
## are swapped for toon copies where this node uses them.
static func apply(node: Node) -> void:
	for n in [node] + node.find_children("*", "", true, false):
		if n is GeometryInstance3D and n.material_override != null:
			n.material_override = _toon_of(n.material_override)
		var mesh: Mesh = null
		if n is MeshInstance3D:
			mesh = n.mesh
			for s in n.get_surface_override_material_count():
				if n.get_surface_override_material(s) != null:
					n.set_surface_override_material(s, _toon_of(n.get_surface_override_material(s)))
		elif n is MultiMeshInstance3D and n.multimesh != null:
			mesh = n.multimesh.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s)
			if m == null:
				continue
			var t := _toon_of(m)
			if t == m:
				continue
			if mesh.resource_path == "":
				mesh.surface_set_material(s, t)
			elif n is MeshInstance3D:
				n.set_surface_override_material(s, t)


## The materials a node draws with: its override, its surfaces' (overrides
## or the mesh's own) and a MultiMesh's mesh's.
static func materials_of(n: Node) -> Array:
	var out := []
	if n is GeometryInstance3D and n.material_override != null:
		out.append(n.material_override)
	var mesh: Mesh = null
	if n is MeshInstance3D:
		mesh = n.mesh
		for s in n.get_surface_override_material_count():
			if n.get_surface_override_material(s) != null:
				out.append(n.get_surface_override_material(s))
	elif n is MultiMeshInstance3D and n.multimesh != null:
		mesh = n.multimesh.mesh
	if mesh != null:
		for s in mesh.get_surface_count():
			if mesh.surface_get_material(s) != null:
				out.append(mesh.surface_get_material(s))
	return out


## `m` turned toon: itself when it is the anime kit's own, else its copy.
static func _toon_of(m: Material) -> Material:
	if not (m is BaseMaterial3D) or m.has_meta("toon") or m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return m
	if m.resource_path.contains("anime_cel/"):
		to_toon(m)
		return m
	var key := m.get_instance_id()
	if not _copies.has(key):
		var copy: BaseMaterial3D = m.duplicate()
		to_toon(copy)
		_copies[key] = copy
	return _copies[key]


static func to_toon(m: Material) -> void:
	if not (m is BaseMaterial3D) or m.has_meta("toon") or m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = STEP_ROUGHNESS
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	if m.resource_name.begins_with("glass") and SEE_THROUGH.any(func(p): return m.resource_path.contains(p)):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = GLASS_ALPHA
	# Leaf cards (tools/styles/shared/foliage.py: alpha-scissored, named
	# <colour>_leaves): edges smoothed by the MSAA samples, and lit by their
	# crown's normals alone, since a card tipped across the sun would
	# shadow itself in stripes.
	if m.resource_name.ends_with("_leaves") and m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
		m.alpha_antialiasing_edge = 0.3
		m.disable_receive_shadows = true
	m.set_meta("toon", true)


## An ink line round `mi`: a hull pass after each of its materials, in a
## dark, cool tone of the material's own colour.
static func outline(mi: GeometryInstance3D, width_px: float) -> void:
	var targets := []
	if mi.material_override != null:
		targets.append(mi.material_override)
	elif mi is MeshInstance3D and mi.mesh != null:
		for s in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_material(s) != null:
				targets.append(mi.mesh.surface_get_material(s))
	for m in targets:
		if m.next_pass != null:
			continue
		var hull := ShaderMaterial.new()
		hull.shader = OUTLINE
		hull.set_shader_parameter("ink", ink_for(m.albedo_color if m is BaseMaterial3D else Color.GRAY))
		hull.set_shader_parameter("width_px", width_px)
		m.next_pass = hull


## The ink for a fill: much darker and cooler, never black.
static func ink_for(fill: Color) -> Color:
	var hue := lerpf(fill.h, 0.72, 0.35) if fill.s > 0.08 else 0.72
	return Color.from_hsv(hue, clampf(fill.s * 0.5 + 0.25, 0.25, 0.7), clampf(fill.v * 0.3, 0.1, 0.3))


## The camera's full-screen line pass, made once.
static func line_pass(cam: Camera3D) -> MeshInstance3D:
	var found := cam.get_node_or_null("InkLines")
	if found != null:
		return found
	var quad := MeshInstance3D.new()
	quad.name = "InkLines"
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	quad.mesh = q
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sm := ShaderMaterial.new()
	sm.shader = LINES
	quad.material_override = sm
	cam.add_child(quad)
	return quad
