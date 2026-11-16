// Paints an icon one colour, keeping its shape (CSS brightness(0) invert(1)
// on the black suit glyphs: white).
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);
}
