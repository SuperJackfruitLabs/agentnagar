// Plants that sway (interactions spec section 2), shared by the 3D styles:
// a soft kind's clump (a MultiMesh instance) bent by the push SoftContacts
// writes into its custom data, and sprung back from the moment of contact.
// It stands in for the clump's kit material (a StandardMaterial3D with a
// colour, perhaps vertex colours, and no textures), whose look it copies:
// Pack3D sets these uniforms from it and from the style's `sway` block.
// Render modes cannot follow a uniform, so a kit material that is culled
// or toon-shaded gets a variant of this shader with its render mode
// changed (Pack3D._sway_shader).
shader_type spatial;
render_mode cull_disabled;

// The kit material's look.
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_colour = false;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform float rim : hint_range(0.0, 1.0) = 0.0;
uniform float rim_tint : hint_range(0.0, 1.0) = 0.0;

// The style's sway: how stiff its plants are (a tip pushed right over
// leans LEAN / stiffness metres a metre of its height), and the colour a
// bent blade shows as its side catches the light.
uniform float stiffness = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
const float LEAN = 0.8;
const float TINT_SHARE = 0.35;

// SoftContacts' clock, and its ease-in and spring (SoftContacts.spring:
// the same curve, the same constants).
uniform float now = 0.0;
uniform float attack_s = 0.08;
uniform float hold_s = 0.1;
uniform float spring_end_s = 0.95;
uniform float spring_decay = 4.5;
uniform float spring_rate = 9.0;
uniform float spring_fade_s = 0.7;

varying float bent;

float spring(float age, float start) {
	if (age < 0.0 || age >= spring_end_s) {
		return 0.0;
	}
	if (age < attack_s) {
		return mix(start, 1.0, age / attack_s);
	}
	if (age < attack_s + hold_s) {
		return 1.0;
	}
	float back = age - attack_s - hold_s;
	return exp(-spring_decay * back) * cos(spring_rate * back) * (1.0 - smoothstep(spring_fade_s, spring_end_s, age));
}

void vertex() {
	// INSTANCE_CUSTOM (SoftContacts.custom_data_of): the push in the
	// clump's own frame (x, z; its direction times its strength), the lean
	// its ease-in starts from, and when it came (SoftContacts' clock).
	float lean = spring(now - INSTANCE_CUSTOM.w, INSTANCE_CUSTOM.z) * LEAN / max(stiffness, 0.05);
	// UV2.x: how freely this part of the clump bends, 0 at its root to 1
	// at its tip. Lower down a blade bends less, so it curves.
	float weight = UV2.x;
	float height = max(VERTEX.y, 0.0);
	float push = length(INSTANCE_CUSTOM.xy);
	VERTEX.xz += INSTANCE_CUSTOM.xy * lean * weight * height;
	VERTEX.y -= abs(lean) * push * weight * weight * height * 0.35;
	bent = abs(lean) * push * weight;
}

void fragment() {
	vec3 colour = albedo.rgb;
	if (use_vertex_colour) {
		colour *= COLOR.rgb;
	}
	ALBEDO = mix(colour, tint.rgb, clamp(bent * TINT_SHARE / LEAN, 0.0, TINT_SHARE));
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
	RIM = rim;
	RIM_TINT = rim_tint;
}
