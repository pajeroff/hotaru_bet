shader_type canvas_item;
// Дождь: три слоя тонких косых штрихов с разной скоростью/плотностью + лёгкая дымка внизу.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float wind = -0.18;      // наклон капель
uniform vec4 tint : source_color = vec4(0.75, 0.9, 1.0, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float layer(vec2 uv, float t, float density, float speed, float len, float w) {
	uv.x += uv.y * wind;
	vec2 g = vec2(uv.x * density, uv.y * density * 0.22);
	vec2 id = floor(g);
	vec2 f = fract(g);
	float h = hash(id);
	float drop = step(h, 0.55);           // не в каждой ячейке
	float y = fract(f.y + t * speed + h * 7.0);
	float line = smoothstep(w, 0.0, abs(f.x - 0.5 - (h - 0.5) * 0.6)) * smoothstep(0.0, 0.08, y) * smoothstep(len, len * 0.3, y);
	return line * drop;
}

void fragment() {
	if (intensity <= 0.001) { COLOR = vec4(0.0); }
	else {
		vec2 uv = SCREEN_UV * vec2(1.6, 1.0);
		float t = TIME;
		float r = 0.0;
		r += layer(uv, t, 60.0, 1.3, 0.55, 0.06) * 0.6;
		r += layer(uv + 0.37, t, 95.0, 1.8, 0.45, 0.05) * 0.45;
		r += layer(uv + 0.71, t, 140.0, 2.4, 0.35, 0.04) * 0.3;
		r *= intensity;
		float haze = intensity * 0.06 * smoothstep(0.3, 1.0, SCREEN_UV.y);
		COLOR = vec4(tint.rgb, clamp(r * 0.75 + haze, 0.0, 1.0));
	}
}
