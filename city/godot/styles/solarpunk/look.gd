## 09 Solarpunk's light and air: a warm golden sun with soft shadows (two
## splits to 140 m, a wide blur), filmic tone mapping, subtle ambient
## occlusion, glow on lamps and lit windows only, and a warm haze.
extends RefCounted
class_name SolarpunkLook


static func tune(env: Environment, sun: DirectionalLight3D) -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.0
	env.ssao_power = 1.2
	env.ssil_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.14
	env.adjustment_contrast = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_blur = 1.2
	sun.light_angular_distance = 0.8
