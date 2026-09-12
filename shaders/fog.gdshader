shader_type canvas_item;
// Объёмный туман: слои шума, плывущие по экрану.
uniform float density : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fog_color : source_color = vec4(0.88, 0.9, 0.96, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 3; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 uv = UV * vec2(1.78, 1.0);
	float t = TIME * 0.03;
	float f = fbm(uv * 2.5 + vec2(t * 2.0, t * 0.7));
	f = f * 0.6 + fbm(uv * 5.0 - vec2(t * 3.0, t)) * 0.4;
	float a = smoothstep(0.35, 0.8, f) * density;
	// у краёв экрана гуще
	vec2 c = (UV - 0.5) * 2.0;
	a += density * 0.45 * smoothstep(0.5, 1.2, length(c));
	COLOR = vec4(fog_color.rgb, clamp(a, 0.0, 0.92));
}
