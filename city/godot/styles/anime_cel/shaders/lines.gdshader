// The city's ink lines: one full-screen pass that draws ink where depth or
// surface direction changes sharply (silhouettes, creases), fading out with
// distance so the far city never shimmers. Drawn on a 2 x 2 quad that the
// vertex stage stretches over the whole screen.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, blend_mix, fog_disabled, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform vec4 ink : source_color = vec4(0.17, 0.15, 0.30, 0.85);
// A depth step this fraction of the distance is an edge.
uniform float depth_edge = 0.06;
// Normals this far apart (1 - cosine) are a crease.
uniform float normal_edge = 0.35;
uniform float fade_begin = 60.0;
uniform float fade_end = 140.0;
uniform float width_px = 1.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_depth(vec2 uv, mat4 inv_projection) {
	float d = texture(depth_texture, uv).r;
	vec4 v = inv_projection * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

vec3 view_normal(vec2 uv) {
	return normalize(texture(normal_texture, uv).xyz * 2.0 - 1.0);
}

void fragment() {
	vec2 px = width_px / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float d0 = view_depth(uv, INV_PROJECTION_MATRIX);
	vec3 n0 = view_normal(uv);
	vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	float lap = -4.0 * d0;
	float crease = 0.0;
	for (int k = 0; k < 4; k++) {
		lap += view_depth(uv + offs[k], INV_PROJECTION_MATRIX);
		crease = max(crease, 1.0 - dot(n0, view_normal(uv + offs[k])));
	}
	float edge = max(step(depth_edge * d0, abs(lap)), step(normal_edge, crease));
	float fade = 1.0 - smoothstep(fade_begin, fade_end, d0);
	ALBEDO = ink.rgb;
	ALPHA = edge * fade * ink.a;
}
