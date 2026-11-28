// Quick Rules' spotlight: everything dark except rounded holes round
// several targets at once (spotlight.gdshader has one).
shader_type canvas_item;
uniform vec4 shade : source_color = vec4(0.031, 0.039, 0.055, 0.62);
uniform vec4 holes[8];  // x, y, w, h in this rect's pixels
uniform int count = 0;
uniform float radius = 12.0;
varying vec2 px;

void vertex() {
	px = VERTEX;
}

void fragment() {
	float a = 1.0;
	for (int i = 0; i < 8; i++) {
		if (i >= count) {
			break;
		}
		vec2 half_size = holes[i].zw * 0.5;
		vec2 q = abs(px - (holes[i].xy + half_size)) - half_size + radius;
		float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;  // < 0 inside the hole
		a = min(a, smoothstep(-0.5, 0.5, d));
	}
	COLOR = vec4(shade.rgb, shade.a * a);
}
