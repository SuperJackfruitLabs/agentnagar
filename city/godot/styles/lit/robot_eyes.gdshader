// A robot agent's eyes: one cell of the eye atlas (one row of
// expressions, light on black) added over the dark visor as light, so
// black leaves the glass as it is. `glow` dims them by day; blinks like
// the faces, offset per robot.
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float columns = 5.0;
uniform float blink_column = 4.0;
uniform vec3 tint : source_color = vec3(1.0);
instance uniform float expression = 0.0;
instance uniform float blink_seed = 0.0;
instance uniform float blinking = 1.0;
instance uniform float glow = 1.6;

void fragment() {
	float e = expression;
	float period = 4.5 + fract(blink_seed * 7.31) * 2.5;
	float t = mod(TIME + blink_seed * 53.9, period);
	if (blinking > 0.5 && e < 0.5 && t < 0.12) {
		e = blink_column;
	}
	vec3 c = texture(atlas, UV + vec2(e / columns, 0.0)).rgb;
	ALBEDO = c * tint * glow;
}
