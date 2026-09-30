## Faces and robot eyes for the lit styles (solarpunk, neon noir): every
## person's face plate draws with one shared face material per atlas, and
## every robot's eyes with one shared emissive material; per character only
## instance uniforms change (face, expression, blink offset, glow).
extends RefCounted
class_name LitFace

const FACE_SHADER := preload("res://styles/lit/face.gdshader")
const EYES_SHADER := preload("res://styles/lit/robot_eyes.gdshader")
const EXPRESSIONS := ["neutral", "smile", "talk", "surprised", "blink"]
const VARIANTS := 4

static var _materials := {}
## Read atlases from their files, not the project's imports (the asset
## preview draws fresh builds before any import).
static var read_files := false


static func _material(shader: Shader, atlas_path: String) -> ShaderMaterial:
	var key := shader.resource_path + "|" + atlas_path
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("atlas", _texture(atlas_path))
		_materials[key] = m
	return _materials[key]


## The atlas as a texture: imported when the project has imported it,
## else read from the file (asset previews run before an import).
static func _texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path) and not read_files:
		return load(path)
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Gives `model`'s face plate (a person) the face material over
## `atlas_path`, face `variant` and a blink offset. Returns it, or null.
static func dress(model: Node, atlas_path: String, variant: int, seed: float) -> GeometryInstance3D:
	var face := model.find_child("face", true, false)
	if not (face is GeometryInstance3D):
		return null
	face.material_override = _material(FACE_SHADER, atlas_path)
	face.set_instance_shader_parameter("variant", float(posmod(variant, VARIANTS)))
	face.set_instance_shader_parameter("blink_seed", seed)
	face.set_instance_shader_parameter("expression", 0.0)
	return face


## Gives `model`'s eyes plate (a robot) the emissive eye material over
## `atlas_path`. Returns it, or null.
static func light_eyes(model: Node, atlas_path: String, seed: float, glow := 1.6) -> GeometryInstance3D:
	var eyes := model.find_child("eyes", true, false)
	if not (eyes is GeometryInstance3D):
		return null
	eyes.material_override = _material(EYES_SHADER, atlas_path)
	eyes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	eyes.set_instance_shader_parameter("blink_seed", seed)
	eyes.set_instance_shader_parameter("expression", 0.0)
	eyes.set_instance_shader_parameter("glow", glow)
	return eyes


## Sets a face's or eyes' expression by name.
static func express(plate: GeometryInstance3D, expression: String) -> void:
	plate.set_instance_shader_parameter("expression", float(maxi(EXPRESSIONS.find(expression), 0)))
