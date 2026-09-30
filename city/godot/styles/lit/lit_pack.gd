## The lit styles' pack (09 Solarpunk, 10 Neon noir): Pack3D's assembly of
## the kit under physically based light (each style's look), semi-real
## faces that blink, robot agents whose eyes glow, brighter by night, City
## Agent A1 as the sheets paint it, a distant crowd drawn simply, the
## style's extras worn by outfit (aprons, jackets, hoods, scarves), wet
## glossy ground and umbrellas in rain, neon lit from dusk, and street
## lamps as cheap warm lights that fade with distance.
extends Pack3D
class_name LitPack

const LitTown = preload("res://styles/lit/townscape.gd")
## Robot eyes by day and by night.
const EYE_GLOW_DAY := 1.3
const EYE_GLOW_NIGHT := 2.4

var _eyes: Array[GeometryInstance3D] = []
## The glazing of the buildings people walk into (the workshop's and the
## library's pieces): see-through by day, so the rooms show from outside
## and the day from inside, and lit from within after dark. Material ->
## its own colour.
var _room_glass := {}
const ROOM_PIECES := ["/hall_", "/lib_"]
const ROOM_GLASS_ALPHA := 0.3
## Each neon material's own colour, which by day darkens to glass.
var _neon_albedo := {}


func _make_town():
	return LitTown.new(style.get("palette", {}), func(path: String) -> Node3D: return _scene(path))


func _environment() -> void:
	super()
	_tune(env, sun)


## The style's light: its look's tuning of the environment and the sun.
func _tune(_env: Environment, _sun: DirectionalLight3D) -> void:
	pass


## Registers the room glazing under `node` (see _room_glass), and sets
## the leaf cards (tools/styles/shared/foliage.py, alpha-scissored
## `<colour>_leaves`) to smooth their edges with the MSAA samples and to
## take their light from the crown alone: a card tipped across the sun
## would shadow itself in stripes.
func _style_node(node: Node) -> void:
	for n in [node] + node.find_children("*", "GeometryInstance3D", true, false):
		for mat in Toon.materials_of(n):
			if not (mat is BaseMaterial3D) or _room_glass.has(mat):
				continue
			var rn := str(mat.resource_name)
			if rn.ends_with("_leaves") and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				mat.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
				mat.alpha_antialiasing_edge = 0.3
				mat.disable_receive_shadows = true
				continue
			if (rn.begins_with("glass") or rn == "window_glow") and ROOM_PIECES.any(func(p): return mat.resource_path.contains(p)):
				_room_glass[mat] = StylePack.original(mat, "albedo", mat.albedo_color)


func build_world(m: Dictionary) -> bool:
	if not super(m):
		return false
	return true


func on_shown() -> void:
	super()
	if is_inside_tree():
		# MSAA for geometry (the style's level), FXAA for the glints on glass
		# and metal.
		var vp := get_viewport()
		vp.msaa_3d = msaa_level()
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA


## Lit styles smooth glints with FXAA over their MSAA.
func uses_fxaa() -> bool:
	return true


func build_scenery(items: Array) -> void:
	super(items)
	# The street lamps are the layout's placements, lit where their kit
	# piece has its light (Pack3D._light), in the style's own lamp colour.
	for lamp in lamps:
		if lamp.has_meta("lamp_of"):
			lamp.light_color = Color(str(style.get("palette", {}).get("lamp_glow", "#FFD08A")))
	# A style may light the ground under the hanging lights of the pieces
	# it names (the great tree's bulbs and lanterns): a lamp at their
	# `lights` node.
	var glowing: Array = style.get("glow_lights", [])
	if not glowing.is_empty():
		for n in world.find_children("lights", "Node3D", true, false):
			var piece: Node = n.get_parent()
			if not (str(piece.scene_file_path).get_file().get_basename() in glowing or str(piece.name) in glowing):
				continue
			var glow := OmniLight3D.new()
			glow.omni_range = float(style.get("lamp_range", 9.0))
			glow.light_color = Color(str(style.get("palette", {}).get("lamp_glow", "#FFD08A")))
			glow.set_meta("lights_of", str(n.get_parent().name))
			world.add_child(glow)
			glow.global_position = n.global_position
			lamps.append(glow)
	var fade := float(style.get("lamp_fade_m", 0.0))
	for lamp in lamps:
		lamp.shadow_enabled = false
		lamp.omni_range = maxf(lamp.omni_range, float(style.get("lamp_range", 0.0)))
		# A light near the ground (under a bench, in a planter) washes a
		# little paving, not the square: dimmer, and short, since a light
		# costs by its reach.
		if lamp.position.y < 1.5 and not lamp.has_meta("lights_of"):
			lamp.set_meta("energy_scale", 0.3)
			lamp.omni_range = minf(lamp.omni_range, 3.5)
		if fade > 0.0:
			lamp.distance_fade_enabled = true
			lamp.distance_fade_begin = fade
			lamp.distance_fade_length = 20.0
	if minutes >= 0:
		set_time_of_day(minutes)


# ---- People ----

func make_occupant(view: Dictionary) -> Node:
	var root: Node3D = super(view)
	var model: Node3D = root.get_node("Model")
	var id: String = view["id"]
	var h := absi(hash(id))
	var seed := float(h % 997) / 997.0
	if model.find_child("eyes", true, false) != null:
		# A robot agent: the kind's colours (A1's own), eyes of light.
		var colours: Dictionary = style.get("a1_look", {}) if id == str(style.get("a1", "")) \
			else style.get("agent_colours", {}).get(occupant_key(view), {})
		for part in colours:
			_paint(model, part, _colour(str(colours[part])))
		var eyes := LitFace.light_eyes(model, asset("assets/eyes_atlas.png"), seed, _eye_glow())
		_eyes.append(eyes)
	else:
		LitFace.dress(model, asset("assets/face_atlas.png"), h % LitFace.VARIANTS, seed)
		_wear_extras(model, view)
	if _dress_far(model):
		_near_parts_end(model)
		# A jacket over the shirt is what shows from afar.
		var jacket = model.find_child("jacket", true, false)
		if jacket is GeometryInstance3D and jacket.visible and jacket.material_override != null:
			var far: MeshInstance3D = model.find_child("far", true, false)
			for s in far.mesh.get_surface_count():
				if str(far.mesh.surface_get_material(s).resource_name) == "top":
					far.set_surface_override_material(s, jacket.material_override)
	return root


## The style's extras by outfit: each extra's "outfits" (outfit numbers,
## 0-7) wear it, in its "colour" (a hood takes the jacket's; never over a
## ponytail or a backpack).
func _wear_extras(model: Node3D, view: Dictionary) -> void:
	var key = view.get("appearance", {}).get("palette", view["id"])
	var k := int(str(key)) if str(key).is_valid_int() else absi(hash(str(key)))
	var extras: Dictionary = style.get("extras", {})
	for part in ["apron", "jacket", "hood", "scarf"]:
		var node = model.find_child(part, true, false)
		if node == null:
			continue
		var rule: Dictionary = extras.get(part, {})
		var outfits: Array = rule.get("outfits", []).map(func(x): return int(x))
		node.visible = posmod(k, 8) in outfits
		# A hood lies where a ponytail falls and a backpack rides.
		if part == "hood" and node.visible:
			for clash in ["hair_2", "backpack"]:
				var other = model.find_child(clash, true, false)
				if other != null and other.visible:
					node.visible = false
		var colour = rule.get("colour", extras.get("jacket", {}).get("colour") if part == "hood" else null)
		if node.visible and colour != null:
			_paint(model, part, _colour(str(colour)))


func _forget(id: String) -> void:
	super(id)
	_eyes = _eyes.filter(func(e): return is_instance_valid(e))


func despawn(id: String) -> void:
	var node = nodes.get(id)
	if node != null:
		var eyes = node.find_child("eyes", true, false)
		_eyes.erase(eyes)
	super(id)


# ---- Time and weather ----

func _daylight(m: int) -> float:
	return clampf(sin((m - 360.0) / 720.0 * PI), 0.0, 1.0)


func _eye_glow() -> float:
	return lerpf(EYE_GLOW_NIGHT, EYE_GLOW_DAY, clampf(_daylight(minutes) * 3.0, 0.0, 1.0)) if minutes >= 0 else EYE_GLOW_DAY


func set_time_of_day(m: int) -> void:
	super(m)
	if sun == null:
		return
	var glow := _eye_glow()
	for eyes in _eyes:
		if is_instance_valid(eyes):
			eyes.set_instance_shader_parameter("glow", glow)
	if town == null:
		return
	var dn: Dictionary = style.get("day_night", {})
	var lit := m >= int(dn.get("lamps_on_from", 1110)) or m < int(dn.get("lamps_off_at", 390))
	# Room glazing: clear glass by day, lit panes at night.
	var tint := Color(str(style.get("day_window", "#9FC4CC")))
	for mat in _room_glass:
		var own: Color = _room_glass[mat]
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var c := own if lit else tint
		c.a = 0.92 if lit else ROOM_GLASS_ALPHA
		mat.albedo_color = c
		if not lit:
			mat.emission_energy_multiplier = 0.0
	# Fairy lights hang dark by day (a faint glow would read as specks).
	for mat in town.lamp_materials:
		if str(mat.resource_name) == "fairy_glow" and not lit:
			mat.emission_energy_multiplier = 0.0
	# Neon lights with the lamps; by day the tubes are dark glass.
	var energy := float(style.get("neon_energy", 4.0))
	for mat in town.neon_materials:
		if not _neon_albedo.has(mat):
			_neon_albedo[mat] = StylePack.original(mat, "albedo", mat.albedo_color)
		mat.emission_enabled = true
		mat.emission = _neon_albedo[mat]
		mat.emission_energy_multiplier = energy if lit else 0.0
		mat.albedo_color = _neon_albedo[mat] if lit else _neon_albedo[mat].darkened(0.72)


func set_rain(amount: float) -> void:
	super(amount)
	# Reflections on the wet ground, where the style can afford them.
	if env != null and style.get("ssr_in_rain", false):
		env.ssr_enabled = amount > 0.3 and not quality_low


func teardown() -> void:
	if is_inside_tree():
		Pack3D.restore_project_aa(get_viewport())
	_eyes.clear()
	for mat in _neon_albedo:
		mat.albedo_color = _neon_albedo[mat]
	_neon_albedo.clear()
	for mat in _room_glass:
		mat.albedo_color = _room_glass[mat]
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_room_glass.clear()
	super.teardown()
