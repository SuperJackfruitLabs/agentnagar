## Anime faces: every character's face plate draws with one shared face
## shader over the atlas; per person only instance uniforms change (which
## face, which expression, when it blinks), so a crowd costs no extra
## materials.
extends RefCounted
class_name AnimeFace

const SHADER := preload("res://styles/anime_cel/shaders/face.gdshader")
const EXPRESSIONS := ["neutral", "smile", "talk", "surprised", "blink"]
## Face variants in the atlas (rows); variant 0 is City Agent A1's.
const VARIANTS := 4

static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("atlas", load("res://styles/anime_cel/assets/face_atlas.png"))
	return _material


## Gives `model`'s face plate the shared face material, face `variant`
## and a blink offset from `seed`. Returns the plate, or null.
static func dress(model: Node, variant: int, seed: float) -> GeometryInstance3D:
	var face := model.find_child("face", true, false)
	if not (face is GeometryInstance3D):
		return null
	face.material_override = material()
	face.set_instance_shader_parameter("variant", float(posmod(variant, VARIANTS)))
	face.set_instance_shader_parameter("blink_seed", seed)
	face.set_instance_shader_parameter("expression", 0.0)
	return face


## Sets the face's expression by name ("neutral", "smile", "talk",
## "surprised", "blink").
static func express(face: GeometryInstance3D, expression: String) -> void:
	var k := EXPRESSIONS.find(expression)
	face.set_instance_shader_parameter("expression", float(maxi(k, 0)))
