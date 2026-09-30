## The anime style's light and air, shared by the pack and the asset preview
## tool: true-colour tonemapping (the palette is the lit colour), no ambient
## occlusion (cel shading has no soft dirt), glow only on lamps and lit
## windows, crisp shadows from the sun, 4x MSAA.
extends RefCounted
class_name AnimeLook

const SKY_TOP := Color("#4F9BE8")
const HORIZON := Color("#CDE7F8")
## Shadowed faces take this: the sheets' cool lavender-indigo, not grey.
## With the warm sun at SUN_ENERGY a lit face is about its own colour, a
## little warm, and a shadowed one about half, tinted lavender: the
## sheets' two tones. (The pack's day_night keys drive the game; these
## are noon's, for the asset preview.)
const AMBIENT := Color("#A6ACE4")
const AMBIENT_ENERGY := 0.78
const SUN_ENERGY := 0.56
const SUN := Color("#FFE4B8")


static func tune(env: Environment) -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.02


static func tune_sun(sun: DirectionalLight3D) -> void:
	sun.shadow_enabled = true
	sun.shadow_blur = 0.35
	sun.light_angular_distance = 0.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 140.0


static func tune_viewport(vp: Viewport, msaa := Viewport.MSAA_4X) -> void:
	vp.msaa_3d = msaa
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
