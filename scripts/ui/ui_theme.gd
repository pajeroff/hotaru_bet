class_name UITheme
## Тема «дерево и бумага»: панели и кнопки из нарисованных текстур (9-slice), тёплая палитра.

const TEX_PANEL := preload("res://assets/ui/panel.png")
const TEX_BUTTON := preload("res://assets/ui/button.png")
const TEX_SIGN := preload("res://assets/ui/sign.png")
const TEX_SEAL := preload("res://assets/ui/seal.png")

const PAPER := Color(0.96, 0.90, 0.76)
const INK := Color(0.30, 0.20, 0.14)          # тёмно-коричневые чернила
const INK_SOFT := Color(0.45, 0.34, 0.26)
const GOLD := Color(0.93, 0.72, 0.36)
const GLOW := Color(1.0, 0.85, 0.5)
const TEXT_LIGHT := Color(0.98, 0.94, 0.85)
const MUTED := Color(0.55, 0.47, 0.40)
const DIM := Color(0.06, 0.05, 0.10, 0.62)    # затемнение фона под окнами

# совместимость со старыми именами
const TEXT := INK
const PANEL_DARK := Color(0.16, 0.12, 0.10, 0.82)
const ACCENT := GOLD
const ACCENT_SOFT := GLOW
const BUTTON := PAPER

static func make_theme(_dark := false) -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	t.set_color("font_color", "Label", INK)
	t.set_font_size("font_size", "Label", 20)
	# кнопки — дощечка
	t.set_stylebox("normal", "Button", _btn_tex(Color(1, 1, 1)))
	t.set_stylebox("hover", "Button", _btn_tex(Color(1.08, 1.04, 0.95)))
	t.set_stylebox("pressed", "Button", _btn_tex(Color(0.9, 0.85, 0.75)))
	t.set_stylebox("focus", "Button", _focus_style())
	t.set_stylebox("disabled", "Button", _btn_tex(Color(0.7, 0.68, 0.64, 0.7)))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color(0.2, 0.12, 0.08))
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_font_size("font_size", "Button", 21)
	for cls in ["OptionButton", "CheckButton", "CheckBox"]:
		t.set_color("font_color", cls, INK)
		t.set_color("font_hover_color", cls, INK)
		t.set_color("font_pressed_color", cls, INK)
		t.set_color("font_focus_color", cls, INK)
	t.set_stylebox("normal", "OptionButton", _btn_tex(Color(1, 1, 1), true))
	t.set_stylebox("hover", "OptionButton", _btn_tex(Color(1.08, 1.04, 0.95), true))
	t.set_stylebox("pressed", "OptionButton", _btn_tex(Color(0.9, 0.85, 0.75), true))
	t.set_font_size("font_size", "OptionButton", 18)
	t.set_stylebox("focus", "OptionButton", _focus_style())
	t.set_stylebox("normal", "CheckButton", _empty())
	t.set_stylebox("hover", "CheckButton", _empty())
	t.set_stylebox("pressed", "CheckButton", _empty())
	t.set_stylebox("focus", "CheckButton", _empty())
	# панели — деревянная рамка с бумагой
	t.set_stylebox("panel", "PanelContainer", _panel_tex())
	t.set_stylebox("panel", "Panel", _panel_tex())
	# вкладки
	t.set_stylebox("panel", "TabContainer", _paper_flat())
	t.set_stylebox("tab_selected", "TabContainer", _tab_style(true))
	t.set_stylebox("tab_unselected", "TabContainer", _tab_style(false))
	t.set_stylebox("tab_hovered", "TabContainer", _tab_style(false, true))
	t.set_color("font_selected_color", "TabContainer", INK)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", INK)
	t.set_font_size("font_size", "TabContainer", 20)
	# слайдеры
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.42, 0.30, 0.6)
	sb.set_corner_radius_all(5)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", sb)
	var sf := StyleBoxFlat.new()
	sf.bg_color = GOLD
	sf.set_corner_radius_all(5)
	t.set_stylebox("grabber_area", "HSlider", sf)
	t.set_stylebox("grabber_area_highlight", "HSlider", sf)
	# всплывающие меню OptionButton
	var pm := StyleBoxFlat.new()
	pm.bg_color = PAPER
	pm.border_color = Color(0.45, 0.32, 0.22)
	pm.set_border_width_all(2)
	pm.set_corner_radius_all(8)
	pm.content_margin_left = 8
	pm.content_margin_right = 8
	pm.content_margin_top = 6
	pm.content_margin_bottom = 6
	t.set_stylebox("panel", "PopupMenu", pm)
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", Color(0.2, 0.12, 0.08))
	var ph := StyleBoxFlat.new()
	ph.bg_color = Color(0.93, 0.80, 0.55, 0.8)
	ph.set_corner_radius_all(6)
	t.set_stylebox("hover", "PopupMenu", ph)
	# поле ввода
	var le := StyleBoxFlat.new()
	le.bg_color = Color(1, 0.98, 0.92)
	le.border_color = Color(0.55, 0.42, 0.30)
	le.set_border_width_all(2)
	le.set_corner_radius_all(8)
	le.content_margin_left = 10
	le.content_margin_right = 10
	le.content_margin_top = 6
	le.content_margin_bottom = 6
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	# диалоги
	t.set_stylebox("panel", "AcceptDialog", _panel_tex())
	t.set_stylebox("panel", "ConfirmationDialog", _panel_tex())
	return t

static func _empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

static func _btn_tex(mod: Color, compact := false) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = TEX_BUTTON
	var w := TEX_BUTTON.get_width()
	var h := TEX_BUTTON.get_height()
	# бумага начинается на ~18% ширины и ~28% высоты текстуры
	s.texture_margin_left = w * 0.17
	s.texture_margin_right = w * 0.17
	s.texture_margin_top = h * 0.30
	s.texture_margin_bottom = h * 0.30
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	s.content_margin_left = w * 0.17 + 8
	s.content_margin_right = w * 0.17 + 8
	s.content_margin_top = h * 0.30 - 4
	s.content_margin_bottom = h * 0.30 - 2
	if compact:
		s.content_margin_top = h * 0.30 - 10
		s.content_margin_bottom = h * 0.30 - 8
		s.content_margin_left = w * 0.17 + 4
		s.content_margin_right = w * 0.17 + 4
	s.modulate_color = mod
	return s

static func _focus_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = Color(GLOW.r, GLOW.g, GLOW.b, 0.85)
	s.set_border_width_all(2)
	s.set_corner_radius_all(16)
	s.set_expand_margin_all(3)
	s.shadow_color = Color(GLOW.r, GLOW.g, GLOW.b, 0.35)
	s.shadow_size = 10
	return s

static func _panel_tex() -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = TEX_PANEL
	var w := TEX_PANEL.get_width()
	var h := TEX_PANEL.get_height()
	# резные углы ~15% ширины / 17% высоты; бумага внутри начинается чуть дальше
	s.texture_margin_left = w * 0.15
	s.texture_margin_right = w * 0.15
	s.texture_margin_top = h * 0.17
	s.texture_margin_bottom = h * 0.17
	s.content_margin_left = w * 0.13
	s.content_margin_right = w * 0.13
	s.content_margin_top = h * 0.15
	s.content_margin_bottom = h * 0.14
	return s

static func _paper_flat() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.93, 0.86, 0.70, 0.55)
	s.border_color = Color(0.55, 0.42, 0.30, 0.6)
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

static func _tab_style(selected: bool, hovered := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.86, 0.72, 0.50) if selected else (Color(0.78, 0.66, 0.50, 0.7) if hovered else Color(0.70, 0.58, 0.44, 0.5))
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

## Панель-«табличка» для HUD: тёмное дерево с бумагой.
static func hud_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.20, 0.14, 0.11, 0.86)
	s.border_color = Color(0.62, 0.46, 0.30, 0.9)
	s.set_border_width_all(2)
	s.set_corner_radius_all(12)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	return s

static func decorate_button(b: Button) -> void:
	b.mouse_entered.connect(func():
		AudioManager.play_sfx("hover", -8.0)
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
	b.pressed.connect(func(): AudioManager.play_sfx("click", -6.0))

static func button(text_key: String, min_w := 260) -> Button:
	var b := Button.new()
	b.text = text_key
	b.custom_minimum_size = Vector2(min_w, 52)
	b.focus_mode = Control.FOCUS_ALL
	decorate_button(b)
	return b

static func label(text: String, size := 20, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func title(text: String, size := 48, color := INK) -> Label:
	var l := label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(1, 0.9, 0.6, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	return l

## Декоративная деревянная табличка с заголовком (поверх панели).
static func sign_title(text: String, size := 30) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(360, 86)
	var tr_ := TextureRect.new()
	tr_.texture = TEX_SIGN
	tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr_.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(tr_)
	var l := label(text, size, TEXT_LIGHT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_top = 14
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_y", 2)
	c.add_child(l)
	return c

## Затемнение под модальным окном + мягкая виньетка.
static func dim_layer() -> ColorRect:
	var d := ColorRect.new()
	d.color = DIM
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	return d

static func fade_in(node: CanvasItem, duration := 0.8) -> void:
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(node, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)

static func pop_in(node: Control, duration := 0.35) -> void:
	node.modulate.a = 0.0
	# дожидаемся раскладки контейнера, чтобы масштабировать от центра
	await node.get_tree().process_frame
	if not is_instance_valid(node):
		return
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2(0.92, 0.92)
	var tw := node.create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(node, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, duration * 0.7)

## Совместимость: старые вызовы стилей
static func _panel_style(_c: Color) -> StyleBoxFlat:
	return hud_style()

static func _btn_style(_c: Color, _glow := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.93, 0.86, 0.70)
	s.set_corner_radius_all(10)
	return s
