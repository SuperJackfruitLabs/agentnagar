// A character's ink line: the surface drawn again, back faces only, pushed
// out along its normals by `width_px` screen pixels at its distance (so
// the line stays as thin from overhead as close up), in the ink colour.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 ink : source_color = vec4(0.16, 0.14, 0.28, 1.0);
uniform float width_px = 1.5;
// Never thinner or thicker than this in metres.
uniform float min_grow = 0.002;
uniform float max_grow = 0.02;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float px_metres = 2.0 * max(-view.z, 0.05) / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	view.xyz += n * clamp(width_px * px_metres, min_grow, max_grow);
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	ALBEDO = ink.rgb;
}
