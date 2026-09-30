// An anime face: one cell of the face atlas (expressions across, faces
// down), chosen per person by instance uniforms, over the head's skin
// (the atlas is transparent where skin shows). Blinks on its own: a
// tenth of a second every four to six seconds, offset per person, so a
// crowd never blinks together and no script runs for it.
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back, depth_draw_opaque;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float columns = 5.0;
uniform float rows = 4.0;
// The atlas column that is the closed-eye blink.
uniform float blink_column = 4.0;
instance uniform float expression = 0.0;
instance uniform float variant = 0.0;
instance uniform float blink_seed = 0.0;
// 0 while a close-up (a conversation) wants still eyes.
instance uniform float blinking = 1.0;

void fragment() {
	float e = expression;
	float period = 4.0 + fract(blink_seed * 13.37) * 2.0;
	float t = mod(TIME + blink_seed * 97.1, period);
	if (blinking > 0.5 && e < 0.5 && t < 0.11) {
		e = blink_column;
	}
	vec2 uv = (UV + vec2(e, variant) * vec2(1.0 / columns, 1.0 / rows));
	vec4 c = texture(atlas, uv);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.35;
}
