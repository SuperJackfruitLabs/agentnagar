shader_type spatial;
render_mode cull_disabled;

uniform vec4 water_color : source_color = vec4(0.32, 0.67, 0.70, 1.0);
uniform float flow_time = 0.0;
uniform float foam_strength : hint_range(0.0, 1.0) = 0.5;
varying vec3 local_position;
varying float upward_face;

void vertex() {
 local_position = VERTEX;
 upward_face = abs(NORMAL.y);
 float falling_face = 1.0 - smoothstep(0.3, 0.8, upward_face);
 float submerged = smoothstep(0.33, 0.49, VERTEX.y);
 // Millimetres of lateral motion: pools/rims and stream endpoints stay seated.
 float ripple = sin(VERTEX.y * 18.0 + flow_time * 6.2831853 * 2.0);
 float flutter = falling_face * submerged * 0.004 * ripple;
 VERTEX.x += flutter * sin(VERTEX.z * 9.0);
 VERTEX.z += flutter * cos(VERTEX.x * 9.0);
}

void fragment() {
 float falling_face = 1.0 - smoothstep(0.3, 0.8, upward_face);
 float angle = atan(local_position.z, local_position.x);
 // Positive time moves phase contours down the stream. Integer frequencies
 // give a seamless four-second loop; the small central jet flows upward.
 float jet = step(1.665, local_position.y) * (1.0-step(0.10,length(local_position.xz)));
 float phase = local_position.y * 6.0 + flow_time * mix(2.0, -2.0, jet);
 phase += 0.10 * sin(angle * 8.0 + local_position.y * 13.0);
 float ribbon = pow(0.5 + 0.5*cos(6.2831853*phase), 7.0);
 float fine = 0.5+0.5*sin(local_position.y*39.0+angle*11.0+flow_time*6.2831853*3.0);
 float pool_ring = 0.5+0.5*sin(length(local_position.xz)*30.0-flow_time*6.2831853*2.0);
 float shimmer = mix(0.04*pool_ring, 0.08*fine, falling_face);
 vec3 base = water_color.rgb * (0.94+shimmer);
 float foam = falling_face * ribbon * foam_strength;
 ALBEDO = mix(base, vec3(0.79,0.94,0.94), foam);
 ROUGHNESS = 0.3;
 SPECULAR = 0.35;
}
