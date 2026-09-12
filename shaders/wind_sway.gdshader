shader_type canvas_item;
// Покачивание ветром + расступание от игрока. Один материал на много объектов:
// фаза берётся из мировой позиции, позиция игрока — глобальный uniform.
uniform float strength : hint_range(0.0, 0.2) = 0.03;
uniform float speed : hint_range(0.0, 5.0) = 1.2;
global uniform vec2 player_world_pos;

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float phase = fract(sin(dot(world, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831;
	float t = TIME * speed + phase;
	float h = 1.0 - UV.y;
	float sway = sin(t + UV.x * 2.0) * strength + sin(t * 2.3) * strength * 0.35;
	vec2 d = world - player_world_pos;
	float dist = length(d);
	float push = (1.0 - smoothstep(20.0, 60.0, dist)) * sign(d.x + 0.001) * 0.10;
	VERTEX.x += (sway + push) * h * h * 60.0;
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
}
