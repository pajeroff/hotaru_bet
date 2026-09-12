extends CanvasLayer
## Индикаторы: время/фаза, погода, банка, "Сохранено", подсказка ловли.

var _time_label: Label
var _jar_label: Label
var _hint: Label
var _saved: Label
var _controls: Label
var _jar_panel: Control
var _fireflies = null

func _ready() -> void:
	layer = 10
	var theme := UITheme.make_theme(true)
	var top := PanelContainer.new()
	top.theme = theme
	top.position = Vector2(16, 16)
	top.custom_minimum_size = Vector2(230, 0)
	var st := UITheme._panel_style(UITheme.PANEL_DARK)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	top.add_theme_stylebox_override("panel", st)
	add_child(top)
	_time_label = UITheme.label("", 18, UITheme.TEXT_LIGHT)
	top.add_child(_time_label)

	_jar_panel = PanelContainer.new()
	_jar_panel.theme = theme
	_jar_panel.add_theme_stylebox_override("panel", st)
	_jar_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_jar_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_jar_panel.offset_right = -16
	_jar_panel.offset_left = -16
	_jar_panel.offset_top = 16
	_jar_panel.offset_bottom = 16
	add_child(_jar_panel)
	_jar_label = UITheme.label("", 18, UITheme.TEXT_LIGHT)
	_jar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_jar_panel.add_child(_jar_label)

	_hint = UITheme.label(tr("HINT_CATCH"), 20, UITheme.TEXT_LIGHT)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.position.y -= 80
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_hint.add_theme_constant_override("shadow_outline_size", 6)
	_hint.modulate.a = 0.0
	add_child(_hint)

	_controls = UITheme.label(tr("CONTROLS_HINT"), 14, Color(1, 1, 1, 0.55))
	_controls.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_controls.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_controls.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_controls.position.y -= 18
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_controls.add_theme_constant_override("shadow_outline_size", 4)
	add_child(_controls)

	_saved = UITheme.label("• " + tr("SAVED"), 18, UITheme.ACCENT_SOFT)
	_saved.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_saved.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_saved.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_saved.position -= Vector2(20, 24)
	_saved.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_saved.add_theme_constant_override("shadow_outline_size", 6)
	_saved.modulate.a = 0.0
	add_child(_saved)

	GameState.jar_changed.connect(_refresh_jar)
	SaveManager.game_saved.connect(func(_s): show_saved())
	_refresh_jar()

func set_firefly_manager(fm) -> void:
	_fireflies = fm

func _process(delta: float) -> void:
	_time_label.text = "%s · %s\n%s %d · %s" % [GameState.get_time_string(), tr("PHASE_" + GameState.get_phase()), tr("DAY"), GameState.day, tr("W_" + GameState.weather)]
	var want := _fireflies != null and _fireflies.nearest != null and not get_tree().paused
	_hint.modulate.a = move_toward(_hint.modulate.a, 1.0 if want else 0.0, delta * 5.0)

func _refresh_jar() -> void:
	var used := GameState.jar_used_slots()
	var dots := ""
	for i in range(GameState.JAR_SLOTS):
		dots += "●" if i < used else "○"
	if used > GameState.JAR_SLOTS:
		dots += "+%d" % (used - GameState.JAR_SLOTS)
	_jar_label.text = "%s  %s\n%s: %s" % [tr("JAR_TITLE"), dots, tr("TEMPLE"), tr("TEMPLE_%d" % GameState.temple_level)]
	_jar_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.8) if GameState.jar_is_over() else UITheme.TEXT_LIGHT)

func show_saved() -> void:
	AudioManager.play_sfx("save", -8.0)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_saved, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.6)
	tw.tween_property(_saved, "modulate:a", 0.0, 0.8)
