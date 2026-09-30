// The baked ground stores one palette index per pixel (0 is empty); this
// draws each index in its day colour, or its night twin after dark, so
// nightfall re-bakes nothing.
shader_type canvas_item;

uniform bool night = false;
uniform vec4 day_c[33];
uniform vec4 night_c[33];

void fragment() {
	int i = int(round(texture(TEXTURE, UV).r * 255.0));
	if (i <= 0 || i > 32) {
		discard;
	}
	COLOR = night ? night_c[i] : day_c[i];
}
