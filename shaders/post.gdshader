shader_type canvas_item;
// Пост-обработка: мягкий bloom, тёплая тонировка, виньетка, лёгкая зернистость.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float bloom_strength : hint_range(0.0, 2.0) = 0.55;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.62;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float saturation : hint_range(0.0, 2.0) = 1.08;
uniform float grain : hint_range(0.0, 0.1) = 0.018;
uniform vec4 tint : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform float brightness = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;
	// bloom из мип-уровней
	vec3 b = vec3(0.0);
	b += textureLod(screen_tex, uv, 2.0).rgb;
	b += textureLod(screen_tex, uv, 3.0).rgb * 1.2;
	b += textureLod(screen_tex, uv, 4.0).rgb * 1.4;
	b /= 3.6;
	float lum = dot(b, vec3(0.299, 0.587, 0.114));
	b *= smoothstep(bloom_threshold - 0.15, bloom_threshold + 0.25, lum);
	col += b * bloom_strength;
	// тонировка и насыщенность
	col *= tint.rgb * brightness;
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(g), col, saturation);
	// мягкий tone-map
	col = col / (col + vec3(0.6)) * 1.6;
	// виньетка
	vec2 c = (uv - 0.5) * vec2(1.3, 1.0);
	col *= 1.0 - vignette * smoothstep(0.45, 1.1, length(c));
	// зерно
	col += (hash(uv * vec2(1920.0, 1080.0) + fract(TIME)) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
