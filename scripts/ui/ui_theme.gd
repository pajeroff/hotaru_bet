class_name UITheme
## Тема «тёмное стекло»: полупрозрачные панели цвета ночного леса, тонкая светящаяся кромка,
## холодный циан как акцент и тёплый янтарь фонаря как второй акцент.

const TEX_SEAL := preload("res://assets/ui/seal.png")

const GLASS := Color(0.07, 0.13, 0.17, 0.82)
const GLASS_LIGHT := Color(0.11, 0.20, 0.25, 0.90)
const EDGE := Color(0.62, 0.92, 0.95, 0.55)
const CYAN := Color(0.55, 0.95, 0.95)
const AMBER := Color(1.0, 0.78, 0.45)
const TEXT_LIGHT := Color(0.90, 0.96, 0.96)
const MUTED := Color(0.55, 0.68, 0.70)
const INK := TEXT_LIGHT
const INK_SOFT := Color(0.75, 0.86, 0.88)
const GOLD := AMBER
const GLOW := CYAN
const PAPER := GLASS
const DIM := Color(0.01, 0.03, 0.05, 0.55)

# совместимость
const TEXT := TEXT_LIGHT
const PANEL_DARK := GLASS
const ACCENT := CYAN
const ACCENT_SOFT := CYAN
const BUTTON := GLASS_LIGHT

static func make_theme(_dark := false) -> Theme:
	var t := Theme.new()
	t.default_font_size = 19
	t.set_color("font_color", "Label", TEXT_LIGHT)
	t.set_font_size("font_size", "Label", 19)
	t.set_stylebox("normal", "Button", _btn(GLASS_LIGHT, EDGE))
	t.set_stylebox("hover", "Button", _btn(Color(0.15, 0.27, 0.32, 0.95), CYAN, true))
	t.set_stylebox("pressed", "Button", _btn(Color(0.20, 0.36, 0.40, 1.0), CYAN, true))
	t.set_stylebox("focus", "Button", _focus())
	t.set_stylebox("disabled", "Button", _btn(Color(0.06, 0.10, 0.12, 0.6), Color(0.3, 0.4, 0.42, 0.4)))
	t.set_color("font_color", "Button", TEXT_LIGHT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	t.set_color("font_focus_color", "Button", TEXT_LIGHT)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_font_size("font_size", "Button", 20)
	for cls in ["OptionButton", "CheckButton", "CheckBox"]:
		t.set_color("font_color", cls, TEXT_LIGHT)
		t.set_color("font_hover_color", cls, Color(1, 1, 1))
		t.set_color("font_pressed_color", cls, Color(1, 1, 1))
		t.set_color("font_focus_color", cls, TEXT_LIGHT)
	t.set_stylebox("normal", "OptionButton", _btn(GLASS_LIGHT, EDGE, false, true))
	t.set_stylebox("hover", "OptionButton", _btn(Color(0.15, 0.27, 0.32, 0.95), CYAN, true, true))
	t.set_stylebox("pressed", "OptionButton", _btn(Color(0.20, 0.36, 0.40, 1.0), CYAN, true, true))
	t.set_stylebox("focus", "OptionButton", _focus())
	t.set_font_size("font_size", "OptionButton", 18)
	for st in ["normal", "hover", "pressed", "focus"]:
		t.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_stylebox("panel", "TabContainer", _flat(Color(0.05, 0.10, 0.13, 0.5), EDGE, 1, 8))
	t.set_stylebox("tab_selected", "TabContainer", _tab(true))
	t.set_stylebox("tab_unselected", "TabContainer", _tab(false))
	t.set_stylebox("tab_hovered", "TabContainer", _tab(false, true))
	t.set_color("font_selected_color", "TabContainer", CYAN)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", TEXT_LIGHT)
	t.set_font_size("font_size", "TabContainer", 19)
	var sb := _flat(Color(0.2, 0.32, 0.36, 0.7), Color(0, 0, 0, 0), 0, 4)
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", sb)
	var sf := _flat(CYAN, Color(0, 0, 0, 0), 0, 4)
	t.set_stylebox("grabber_area", "HSlider", sf)
	t.set_stylebox("grabber_area_highlight", "HSlider", sf)
	var pm := _flat(Color(0.06, 0.12, 0.15, 0.97), EDGE, 1, 8)
	pm.content_margin_left = 8
	pm.content_margin_right = 8
	pm.content_margin_top = 6
	pm.content_margin_bottom = 6
	t.set_stylebox("panel", "PopupMenu", pm)
	t.set_color("font_color", "PopupMenu", TEXT_LIGHT)
	t.set_color("font_hover_color", "PopupMenu", Color(1, 1, 1))
	t.set_stylebox("hover", "PopupMenu", _flat(Color(0.2, 0.4, 0.45, 0.8), Color(0, 0, 0, 0), 0, 6))
	var le := _flat(Color(0.04, 0.08, 0.10, 0.9), EDGE, 1, 8)
	le.content_margin_left = 10
	le.content_margin_right = 10
	le.content_margin_top = 6
	le.content_margin_bottom = 6
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", _flat(Color(0.04, 0.08, 0.10, 0.95), CYAN, 1, 8))
	t.set_color("font_color", "LineEdit", TEXT_LIGHT)
	t.set_color("caret_color", "LineEdit", CYAN)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_stylebox("panel", "AcceptDialog", panel_style())
	t.set_stylebox("panel", "ConfirmationDialog", panel_style())
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return t

static func _flat(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	return s

static func _btn(bg: Color, border: Color, glow := false, compact := false) -> StyleBoxFlat:
	var s := _flat(bg, border, 1, 10)
	s.content_margin_left = 22 if not compact else 12
	s.content_margin_right = 22 if not compact else 12
	s.content_margin_top = 9 if not compact else 5
	s.content_margin_bottom = 9 if not compact else 5
	if glow:
		s.shadow_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.25)
		s.shadow_size = 8
	return s

static func _focus() -> StyleBoxFlat:
	var s := _flat(Color(0, 0, 0, 0), Color(CYAN.r, CYAN.g, CYAN.b, 0.9), 2, 11)
	s.set_expand_margin_all(2)
	s.shadow_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.3)
	s.shadow_size = 10
	return s

static func panel_style() -> StyleBoxFlat:
	var s := _flat(GLASS, EDGE, 1, 14)
	s.content_margin_left = 30
	s.content_margin_right = 30
	s.content_margin_top = 24
	s.content_margin_bottom = 22
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 24
	return s

static func _tab(selected: bool, hovered := false) -> StyleBoxFlat:
	var s := _flat(Color(0.14, 0.26, 0.30, 0.9) if selected else (Color(0.10, 0.18, 0.22, 0.7) if hovered else Color(0.06, 0.12, 0.15, 0.5)), EDGE if selected else Color(0, 0, 0, 0), 1, 0)
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s

static func hud_style() -> StyleBoxFlat:
	var s := _flat(Color(0.04, 0.09, 0.12, 0.72), EDGE, 1, 10)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	return s

static func decorate_button(b: Button) -> void:
	b.mouse_entered.connect(func():
		AudioManager.play_sfx("hover", -8.0)
		b.pivot_offset = b.size / 2.0
		var tw := b.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(b, "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_SINE)
	)
	b.mouse_exited.connect(func():
		var tw := b.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	)
	b.pressed.connect(func(): AudioManager.play_sfx("click", -6.0))

static func button(text_key: String, min_w := 260) -> Button:
	var b := Button.new()
	b.text = text_key
	b.custom_minimum_size = Vector2(min_w, 46)
	b.focus_mode = Control.FOCUS_ALL
	decorate_button(b)
	return b

static func label(text: String, size := 19, color := TEXT_LIGHT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func title(text: String, size := 44, color := TEXT_LIGHT) -> Label:
	var l := label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(CYAN.r, CYAN.g, CYAN.b, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", 8)
	return l

## Заголовок окна: тонкая строка капителью с линией-подчёркиванием.
static func sign_title(text: String, size := 26) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var l := label(text.to_upper(), size, CYAN)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(CYAN.r, CYAN.g, CYAN.b, 0.35))
	l.add_theme_constant_override("shadow_outline_size", 6)
	v.add_child(l)
	var line := ColorRect.new()
	line.color = Color(EDGE.r, EDGE.g, EDGE.b, 0.5)
	line.custom_minimum_size = Vector2(160, 1)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(line)
	return v

static func dim_layer() -> ColorRect:
	var d := ColorRect.new()
	d.color = DIM
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return d

static func fade_in(node: CanvasItem, duration := 0.8) -> void:
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(node, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)

static func pop_in(node: Control, duration := 0.3) -> void:
	node.modulate.a = 0.0
	await node.get_tree().process_frame
	if not is_instance_valid(node):
		return
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2(0.96, 0.96)
	var tw := node.create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(node, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, duration * 0.8)

static func _panel_style(_c: Color) -> StyleBoxFlat:
	return hud_style()

static func _btn_style(_c: Color, _glow := false) -> StyleBoxFlat:
	return _btn(GLASS_LIGHT, EDGE)
