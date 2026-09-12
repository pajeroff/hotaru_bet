shader_type canvas_item;
// Земля поляны: тайлинг травы, тропинки по маске, мягкое затемнение к краям леса.
uniform sampler2D grass_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D path_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D path_mask : filter_linear; // 1 = тропинка
uniform float tile_scale = 3.0;
uniform vec2 half_size = vec2(900.0, 620.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec4 g = texture(grass_tex, uv * tile_scale);
	vec4 p = texture(path_tex, uv * tile_scale * 1.3);
	// вариативность оттенка травы крупными пятнами
	float v = noise(uv * 5.0) * 0.5 + noise(uv * 13.0) * 0.5;
	g.rgb *= mix(0.9, 1.1, v);
	g.rgb = mix(g.rgb, g.rgb * vec3(0.95, 1.05, 0.9), noise(uv * 3.0 + 7.0));
	float m = texture(path_mask, uv).r;
	m = smoothstep(0.35, 0.65, m + (noise(uv * 40.0) - 0.5) * 0.25);
	vec4 col = mix(g, p, m);
	// виньетка к краю поляны
	vec2 c = (uv - 0.5) * 2.0;
	float edge = smoothstep(0.75, 1.05, length(c));
	col.rgb *= 1.0 - edge * 0.45;
	COLOR = col;
}
