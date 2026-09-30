// The `glow` focus halo, drawn on a panel behind the focused control that
// reaches `spread` pixels beyond it on every side (see Screen). It is
// strongest at the control's rounded edge and fades smoothly to nothing at
// the panel's; inside the control it is clear, since a slider or a switch
// does not cover its whole rectangle.
shader_type canvas_item;

// The skin's focus colour, at the halo's alpha.
uniform vec4 glow_colour : source_color = vec4(0.21, 0.84, 1.0, 0.6);
// The panel's size in pixels: the control's plus `spread` on each side.
uniform vec2 size = vec2(100.0, 64.0);
// How far the halo reaches beyond the control.
uniform float spread = 8.0;
// The control's corner radius.
uniform float radius = 0.0;

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

// Signed distance from `p` to a rounded rectangle centred on the origin.
float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 half_size = size * 0.5;
	vec2 inner = max(half_size - vec2(spread), vec2(0.0));
	float r = min(radius, min(inner.x, inner.y));
	float d = rounded_box(local_position - half_size, inner, r);
	float fade = (1.0 - smoothstep(0.0, spread, d)) * step(0.0, d);
	COLOR = vec4(glow_colour.rgb, glow_colour.a * fade * fade);
}
