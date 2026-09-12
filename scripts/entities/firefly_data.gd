class_name FireflyData
## Каталог видов светлячков и логика выбора по времени/погоде.

const KINDS := {
	"gold":  {"name": "FF_gold",  "color": Color(1.0, 0.85, 0.45), "rarity": "common",    "emotion": "calm",     "element": "light"},
	"green": {"name": "FF_green", "color": Color(0.65, 1.0, 0.6),  "rarity": "common",    "emotion": "friendly", "element": "leaf"},
	"blue":  {"name": "FF_blue",  "color": Color(0.55, 0.8, 1.0),  "rarity": "common",    "emotion": "shy",      "element": "water"},
	"petal": {"name": "FF_petal", "color": Color(1.0, 0.75, 0.85), "rarity": "common",    "emotion": "joyful",   "element": "leaf"},
	"mist":  {"name": "FF_mist",  "color": Color(0.85, 0.9, 0.95), "rarity": "rare",      "emotion": "secret",   "element": "moon"},
	"red":   {"name": "FF_red",   "color": Color(1.0, 0.5, 0.45),  "rarity": "rare",      "emotion": "curious",  "element": "ember"},
	"white": {"name": "FF_white", "color": Color(1.0, 1.0, 0.95),  "rarity": "rare",      "emotion": "calm",     "element": "moon"},
	"star":  {"name": "FF_star",  "color": Color(1.0, 0.95, 0.7),  "rarity": "legendary", "emotion": "curious",  "element": "light"},
}

static func pick_kind(phase: String, weather: String) -> String:
	var w := {"gold": 30, "green": 20, "blue": 8, "petal": 6, "mist": 0, "red": 3, "white": 3, "star": 0}
	match phase:
		"dawn", "morning":
			w["gold"] += 15; w["green"] += 10
		"day":
			w["gold"] += 5
		"sunset", "evening":
			w["red"] += 6; w["white"] += 4
		"night":
			w["white"] += 10; w["red"] += 6; w["star"] += 2; w["gold"] -= 10
	match weather:
		"fog": w["mist"] += 25
		"rain": w["blue"] += 30
		"storm": w["blue"] += 10; w["star"] += 4; w["red"] += 6
		"bloom": w["petal"] += 30
		"snow": w["white"] += 15
		"silence": w["star"] += 3; w["mist"] += 6
	var total := 0
	for k in w: total += maxi(w[k], 0)
	var r := randi() % maxi(total, 1)
	for k in w:
		r -= maxi(w[k], 0)
		if r < 0:
			return k
	return "gold"

static func make(kind: String) -> Dictionary:
	var base: Dictionary = KINDS[kind]
	return {
		"kind": kind, "name": base["name"], "rarity": base["rarity"],
		"emotion": base["emotion"], "element": base["element"],
		"color": [base["color"].r, base["color"].g, base["color"].b],
	}

static func color_of(data: Dictionary) -> Color:
	var c: Array = data.get("color", [1, 0.85, 0.45])
	return Color(c[0], c[1], c[2])

static func target_count(phase: String, weather: String) -> int:
	var n := 6
	match phase:
		"dawn": n = 9
		"morning": n = 10
		"day": n = 4
		"sunset": n = 8
		"evening": n = 12
		"night": n = 16
	if weather == "silence": n = maxi(n - 4, 2)
	if weather == "bloom": n += 3
	return n
