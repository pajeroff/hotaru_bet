shader_type canvas_item;
// Тёплое внутреннее свечение (для храма): подсвечивает светлые/тёплые пиксели.
uniform float glow : hint_range(0.0, 3.0) = 1.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.45, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float warm = clamp((c.r - c.b) * 2.0, 0.0, 1.0) * clamp(c.r * 1.2 - 0.4, 0.0, 1.0);
	c.rgb += glow_color.rgb * warm * glow * 0.6;
	COLOR = c;
}
