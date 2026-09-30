// A semi-realistic face for the lit styles (solarpunk, neon noir): one
// cell of the face atlas (expressions across, faces down) over the head's
// skin, lit like the rest of the body. Blinks on its own, offset per
// person. See styles/anime_cel/shaders/face.gdshader for the toon twin.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float columns = 5.0;
uniform float rows = 4.0;
uniform float blink_column = 4.0;
instance uniform float expression = 0.0;
instance uniform float variant = 0.0;
instance uniform float blink_seed = 0.0;
instance uniform float blinking = 1.0;

void fragment() {
	float e = expression;
	float period = 4.0 + fract(blink_seed * 13.37) * 2.0;
	float t = mod(TIME + blink_seed * 97.1, period);
	if (blinking > 0.5 && e < 0.5 && t < 0.11) {
		e = blink_column;
	}
	vec4 c = texture(atlas, UV + vec2(e, variant) * vec2(1.0 / columns, 1.0 / rows));
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.35;
	ROUGHNESS = 0.62;
	SPECULAR = 0.3;
}
