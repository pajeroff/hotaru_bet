shader_type canvas_item;
// Пруд: волны, блики, мягкая кромка (без чтения экрана — дёшево).
uniform vec4 deep_color : source_color = vec4(0.22, 0.45, 0.62, 0.95);
uniform vec4 shallow_color : source_color = vec4(0.55, 0.78, 0.86, 0.9);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 0.6);
uniform float time_scale = 0.6;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 c = uv - 0.5;
	float r = length(c * vec2(1.0, 1.6)) * 2.0;
	float t = TIME * time_scale;
	float n = noise(uv * 6.0 + vec2(t * 0.4, t * 0.25)) * 0.6 + noise(uv * 14.0 - vec2(t * 0.3, t * 0.5)) * 0.4;
	float depth = smoothstep(1.0, 0.3, r);
	vec4 col = mix(shallow_color, deep_color, depth);
	float spec = smoothstep(0.62, 0.7, noise(uv * 18.0 + vec2(t * 0.8, -t * 0.6)));
	col.rgb += spec * 0.22 * (1.0 - depth * 0.5);
	float edge = smoothstep(0.86, 0.98, r + n * 0.05);
	col = mix(col, foam_color, edge * 0.6);
	col.a *= smoothstep(1.02, 0.94, r + n * 0.03);
	COLOR = col;
}
