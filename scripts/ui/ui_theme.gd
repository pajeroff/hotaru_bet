class_name UITheme
## Пастельная тема и хелперы для построения интерфейса кодом.

const BG := Color(0.93, 0.89, 0.93)
const PANEL := Color(0.99, 0.97, 0.95, 0.85)
const PANEL_DARK := Color(0.16, 0.16, 0.24, 0.72)
const TEXT := Color(0.33, 0.28, 0.36)
const TEXT_LIGHT := Color(0.96, 0.94, 0.92)
const ACCENT := Color(0.98, 0.83, 0.55)
const ACCENT_SOFT := Color(1.0, 0.92, 0.75)
const BUTTON := Color(1.0, 0.98, 0.95, 0.9)
const BUTTON_HOVER := Color(1.0, 0.94, 0.82, 1.0)
const MUTED := Color(0.6, 0.57, 0.63)

static func make_theme(dark := false) -> Theme:
	var t := Theme.new()
	var font_color := TEXT_LIGHT if dark else TEXT
	t.set_color("font_color", "Label", font_color)
	t.set_font_size("font_size", "Label", 20)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_font_size("font_size", "Button", 22)
	t.set_stylebox("normal", "Button", _btn_style(BUTTON))
	t.set_stylebox("hover", "Button", _btn_style(BUTTON_HOVER, true))
	t.set_stylebox("pressed", "Button", _btn_style(ACCENT_SOFT, true))
	t.set_stylebox("focus", "Button", _btn_style(BUTTON_HOVER, true))
	t.set_stylebox("disabled", "Button", _btn_style(Color(0.9, 0.88, 0.9, 0.5)))
	t.set_stylebox("panel", "PanelContainer", _panel_style(PANEL_DARK if dark else PANEL))
	t.set_stylebox("panel", "Panel", _panel_style(PANEL_DARK if dark else PANEL))
	t.set_color("font_color", "CheckButton", font_color)
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_stylebox("normal", "OptionButton", _btn_style(BUTTON))
	t.set_stylebox("hover", "OptionButton", _btn_style(BUTTON_HOVER, true))
	t.set_stylebox("pressed", "OptionButton", _btn_style(ACCENT_SOFT, true))
	t.set_stylebox("focus", "OptionButton", _btn_style(BUTTON_HOVER, true))
	t.set_color("font_color", "TabContainer", TEXT)
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.85, 0.82, 0.88, 0.8)
	slider_bg.set_corner_radius_all(6)
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", slider_bg)
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = ACCENT
	slider_fill.set_corner_radius_all(6)
	t.set_stylebox("grabber_area", "HSlider", slider_fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	return t

static func _btn_style(color: Color, glow := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(14)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if glow:
		s.shadow_color = Color(1.0, 0.85, 0.55, 0.45)
		s.shadow_size = 10
	else:
		s.shadow_color = Color(0.3, 0.25, 0.35, 0.12)
		s.shadow_size = 4
	return s

static func _panel_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(22)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 22
	s.content_margin_bottom = 22
	s.shadow_color = Color(0.2, 0.15, 0.3, 0.15)
	s.shadow_size = 18
	return s

static func _audio() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("AudioManager")

## Подключает мягкий звук и лёгкое увеличение при наведении.
static func decorate_button(b: Button) -> void:
	b.pivot_offset = b.size / 2.0
	b.mouse_entered.connect(func():
		var am := _audio()
		if am: am.play_sfx("hover", -8.0)
		b.pivot_offset = b.size / 2.0
		var tw := b.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(b, "scale", Vector2(1.04, 1.04), 0.15).set_trans(Tween.TRANS_SINE)
	)
	b.mouse_exited.connect(func():
		var tw := b.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(b, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE)
	)
	b.pressed.connect(func():
		var am := _audio()
		if am: am.play_sfx("click", -6.0)
	)

static func button(text_key: String, min_w := 260) -> Button:
	var b := Button.new()
	b.text = text_key
	b.custom_minimum_size = Vector2(min_w, 0)
	b.focus_mode = Control.FOCUS_ALL
	decorate_button(b)
	return b

static func label(text: String, size := 20, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func title(text: String, size := 64, color := TEXT) -> Label:
	var l := label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(1, 0.9, 0.7, 0.5))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 8)
	return l

static func fade_in(node: CanvasItem, duration := 0.8) -> void:
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(node, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
