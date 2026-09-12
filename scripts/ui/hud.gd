extends CanvasLayer
## Индикаторы: время/фаза, погода, банка, "Сохранено", подсказка ловли.

var _time_label: Label
var _jar_label: Label
var _hint: Label
var _saved: Label
var _controls: Label
var _jar_panel: Control
var _fps: Label
var _speed: Label
var _speed_buttons: Array = []
var _fireflies = null

func _ready() -> void:
	layer = 10
	var hud_theme := UITheme.make_theme(true)
	var top := PanelContainer.new()
	top.theme = hud_theme
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
	_jar_panel.theme = hud_theme
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
	_saved.position -= Vector2(20, 100)
	_saved.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_saved.add_theme_constant_override("shadow_outline_size", 6)
	_saved.modulate.a = 0.0
	add_child(_saved)

	_fps = UITheme.label("", 14, Color(0.8, 1.0, 0.8, 0.9))
	_fps.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fps.position = Vector2(16, 84)
	_fps.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_fps.add_theme_constant_override("shadow_outline_size", 4)
	add_child(_fps)
	# панель скорости времени (справа снизу): ×1 · ×1.5 · ×2
	var sp := PanelContainer.new()
	sp.theme = hud_theme
	sp.add_theme_stylebox_override("panel", st)
	sp.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	sp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	sp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sp.offset_left = -16
	sp.offset_right = -16
	sp.offset_top = -56
	sp.offset_bottom = -56
	add_child(sp)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 6)
	sp.add_child(sh)
	_speed = UITheme.label("⏱", 16, UITheme.TEXT_LIGHT)
	sh.add_child(_speed)
	var speeds: Array[String] = ["normal", "fast", "faster"]
	var labels: Array[String] = ["×1", "×1.5", "×2"]
	for i in range(3):
		var b := Button.new()
		b.text = labels[i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(56, 0)
		b.add_theme_font_size_override("font_size", 16)
		var sb := UITheme._btn_style(UITheme.BUTTON)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		b.add_theme_stylebox_override("normal", sb)
		var sbp := UITheme._btn_style(UITheme.ACCENT, true)
		sbp.content_margin_left = 8
		sbp.content_margin_right = 8
		sbp.content_margin_top = 4
		sbp.content_margin_bottom = 4
		b.add_theme_stylebox_override("pressed", sbp)
		b.add_theme_stylebox_override("hover", sb)
		b.pressed.connect(_on_speed_pressed.bind(speeds[i]))
		sh.add_child(b)
		_speed_buttons.append(b)
	Settings.settings_changed.connect(_refresh_speed)
	_refresh_speed()
	GameState.jar_changed.connect(_refresh_jar)
	SaveManager.game_saved.connect(func(_s): show_saved())
	_refresh_jar()

func set_firefly_manager(fm) -> void:
	_fireflies = fm

func _process(delta: float) -> void:
	_time_label.text = "%s · %s\n%s %d · %s" % [GameState.get_time_string(), tr("PHASE_" + GameState.get_phase()), tr("DAY"), GameState.day, tr("W_" + GameState.weather)]
	_fps.visible = Settings.show_fps
	if Settings.show_fps:
		_fps.text = "%d FPS · %.1f ms" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0]
	var want: bool = false
	if _fireflies != null and not get_tree().paused:
		want = _fireflies.nearest != null
	_hint.modulate.a = move_toward(_hint.modulate.a, 1.0 if want else 0.0, delta * 5.0)

func _on_speed_pressed(speed: String) -> void:
	Settings.time_speed = speed
	Settings.save()
	Settings.settings_changed.emit()
	AudioManager.play_sfx("click", -10.0)

func _refresh_speed() -> void:
	var speeds: Array[String] = ["normal", "fast", "faster"]
	for i in range(_speed_buttons.size()):
		var b: Button = _speed_buttons[i]
		b.set_pressed_no_signal(Settings.time_speed == speeds[i])

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
