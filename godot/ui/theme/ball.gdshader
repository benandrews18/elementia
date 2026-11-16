// The hub's raised Home button face (#hubHome): a glossy ball, lit from the
// upper left (radial-gradient(circle at 32% 26%, light 0%, color 55%,
// dark 100%)), cut to a circle.
shader_type canvas_item;
uniform vec4 light : source_color;
uniform vec4 base : source_color;
uniform vec4 dark : source_color;

void fragment() {
	vec2 p = UV - vec2(0.5);
	if (length(p) > 0.5) {
		discard;
	}
	// Distance from the highlight, scaled so the far edge is 1.
	float d = length(UV - vec2(0.32, 0.26)) / 0.85;
	vec4 c = d < 0.55 ? mix(light, base, d / 0.55) : mix(base, dark, (d - 0.55) / 0.45);
	// Soft edge (anti-aliasing).
	c.a *= smoothstep(0.5, 0.5 - fwidth(length(p)) * 1.5, length(p));
	COLOR = c;
}
