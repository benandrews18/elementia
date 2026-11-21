// Professor Mouse's spotlight (#mouseHighlight: box-shadow 0 0 0 9999px):
// everything dark except a rounded hole around the tip's target.
shader_type canvas_item;
uniform vec4 shade : source_color = vec4(0.031, 0.039, 0.055, 0.74);
uniform vec2 hole_pos;   // the hole's top-left, in this rect's pixels
uniform vec2 hole_size;
uniform float radius = 14.0;
varying vec2 px;

void vertex() {
	px = VERTEX;
}

void fragment() {
	vec2 half_size = hole_size * 0.5;
	vec2 q = abs(px - (hole_pos + half_size)) - half_size + radius;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;  // < 0 inside the hole
	COLOR = vec4(shade.rgb, shade.a * smoothstep(-0.5, 0.5, d));
}
