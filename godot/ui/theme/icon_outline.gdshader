// A thin dark outline that follows an icon's silhouette (base.css
// --icon-outline). width: the outline as a fraction of the icon (set by
// Tok.outline()), so it scales with the screen.
shader_type canvas_item;
uniform float width = 0.035;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = 0.0;
	for (int i = 0; i < 8; i++) {
		float t = float(i) * 0.785398;
		a = max(a, texture(TEXTURE, UV + vec2(cos(t), sin(t)) * width).a);
	}
	COLOR = mix(vec4(0.0, 0.0, 0.0, a), c, c.a);
}
