shader_type canvas_item;
// Покачивание листвы/травы ветром: верх спрайта качается, низ закреплён.
uniform float strength : hint_range(0.0, 0.2) = 0.03;
uniform float speed : hint_range(0.0, 5.0) = 1.2;
uniform float phase = 0.0;
uniform float player_push = 0.0; // -1..1 боковой толчок от игрока

void vertex() {
	float t = TIME * speed + phase;
	float h = 1.0 - UV.y; // 1 наверху, 0 внизу
	float sway = sin(t + UV.x * 2.0) * strength + sin(t * 2.3) * strength * 0.35 + player_push * 0.12;
	VERTEX.x += sway * h * h * 60.0;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = c;
}
