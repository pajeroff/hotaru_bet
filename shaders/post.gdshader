shader_type canvas_item;
// Пост-обработка: аккуратный bloom только с ярких участков, тонировка, виньетка, зерно.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float bloom_strength : hint_range(0.0, 2.0) = 0.25;
uniform float bloom_threshold : hint_range(0.0, 1.5) = 0.6;
uniform float vignette : hint_range(0.0, 1.0) = 0.3;
uniform float saturation : hint_range(0.0, 2.0) = 1.05;
uniform float grain : hint_range(0.0, 0.1) = 0.012;
uniform vec4 tint : source_color = vec4(1.0, 0.99, 0.97, 1.0);
uniform float brightness = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;
	vec3 b = textureLod(screen_tex, uv, 3.0).rgb * 0.5 + textureLod(screen_tex, uv, 4.0).rgb * 0.5;
	float lum = dot(b, vec3(0.299, 0.587, 0.114));
	b *= smoothstep(bloom_threshold - 0.1, bloom_threshold + 0.2, lum);
	col += b * bloom_strength;
	col *= tint.rgb * brightness;
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(g), col, saturation);
	// мягкий roll-off только для самых ярких значений, без общего осветления
	col = mix(col, 1.0 - exp(-col), smoothstep(0.8, 1.4, max(col.r, max(col.g, col.b))));
	vec2 c = (uv - 0.5) * vec2(1.3, 1.0);
	col *= 1.0 - vignette * smoothstep(0.5, 1.15, length(c));
	col += (hash(uv * vec2(1920.0, 1080.0) + fract(TIME)) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
