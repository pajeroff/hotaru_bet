extends CanvasLayer
## HUD: слева сверху — блок «часы + дата + фаза/погода», по центру сверху — скорость времени,
## справа сверху — живая банка и состояние храма; снизу — подсказки и тост «Сохранено».

var _clock: ClockWidget
var _time_text: Label
var _date_text: Label
var _phase_text: Label
var _jar_view: JarView
var _jar_text: Label
var _hint: Label
var _saved: Label
var _controls: Label
var _fps: Label
var _speed_buttons: Array = []
var _fireflies = null
var _weekday_base := 0
var _hot_slots: Array = []
var _toast: Label

func _ready() -> void:
	layer = 10
	var hud_theme := UITheme.make_theme(true)
	var st := UITheme.hud_style()

	# ---------- левый блок: часы ----------
	var left := PanelContainer.new()
	left.theme = hud_theme
	left.add_theme_stylebox_override("panel", st)
	left.position = Vector2(14, 14)
	add_child(left)
	var lh := HBoxContainer.new()
	lh.add_theme_constant_override("separation", 12)
	left.add_child(lh)
	_clock = ClockWidget.new()
	_clock.custom_minimum_size = Vector2(112, 112)
	lh.add_child(_clock)
	var lv := VBoxContainer.new()
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lv.add_theme_constant_override("separation", 2)
	lh.add_child(lv)
	_time_text = UITheme.label("", 30, UITheme.TEXT_LIGHT)
	_time_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_time_text.add_theme_constant_override("shadow_offset_y", 2)
	lv.add_child(_time_text)
	_date_text = UITheme.label("", 15, UITheme.GLOW)
	lv.add_child(_date_text)
	_phase_text = UITheme.label("", 15, UITheme.INK_SOFT)
	lv.add_child(_phase_text)

	# ---------- центр сверху: скорость времени ----------
	var sp := PanelContainer.new()
	sp.theme = hud_theme
	sp.add_theme_stylebox_override("panel", st)
	sp.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sp.offset_top = 14
	sp.offset_bottom = 14
	add_child(sp)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 6)
	sp.add_child(sh)
	var speed_lbl := UITheme.label(tr("TIME_SPEED_SHORT"), 15, UITheme.GLOW)
	speed_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sh.add_child(speed_lbl)
	var speeds: Array[String] = ["normal", "fast", "faster"]
	var labels: Array[String] = ["×1", "×1.5", "×2"]
	for i in range(3):
		var b := Button.new()
		b.text = labels[i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(58, 32)
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_stylebox_override("normal", _speed_style(false))
		b.add_theme_stylebox_override("hover", _speed_style(false, true))
		b.add_theme_stylebox_override("pressed", _speed_style(true))
		b.add_theme_color_override("font_color", UITheme.INK_SOFT)
		b.add_theme_color_override("font_pressed_color", UITheme.INK)
		b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.85))
		b.pressed.connect(_on_speed_pressed.bind(speeds[i]))
		sh.add_child(b)
		_speed_buttons.append(b)

	# ---------- правый блок: банка ----------
	var right := PanelContainer.new()
	right.theme = hud_theme
	right.add_theme_stylebox_override("panel", st)
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -14
	right.offset_left = -14
	right.offset_top = 14
	right.offset_bottom = 14
	add_child(right)
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 10)
	right.add_child(rh)
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_theme_constant_override("separation", 2)
	rh.add_child(rv)
	_jar_text = UITheme.label("", 15, UITheme.TEXT_LIGHT)
	_jar_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(_jar_text)
	var jar_hint := UITheme.label("[%s] %s" % [Settings.get_action_key_name("open_jar"), tr("JAR_LOOK")], 12, Color(1, 1, 1, 0.5))
	jar_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(jar_hint)
	_jar_view = JarView.new()
	_jar_view.custom_minimum_size = Vector2(60, 90)
	rh.add_child(_jar_view)

	# ---------- низ по центру: быстрый доступ + рюкзак ----------
	var hot := PanelContainer.new()
	hot.theme = hud_theme
	hot.add_theme_stylebox_override("panel", st)
	hot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hot.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hot.offset_top = -34
	hot.offset_bottom = -34
	add_child(hot)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 8)
	hot.add_child(hh)
	for i in range(Inventory.HOTBAR_SIZE):
		var slot := ItemSlot.new("hotbar", i, 56)
		slot.hotkey = str(i + 1)
		var idx := i
		slot.pressed.connect(func(): Inventory.set_active(idx))
		hh.add_child(slot)
		_hot_slots.append(slot)
	var sep := ColorRect.new()
	sep.color = Color(UITheme.EDGE.r, UITheme.EDGE.g, UITheme.EDGE.b, 0.4)
	sep.custom_minimum_size = Vector2(1, 40)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hh.add_child(sep)
	var bag := ItemSlot.new("bag", -1, 56)
	bag.hotkey = "B"
	bag.item_id = "backpack"
	bag.tooltip_text = tr("INV_TITLE")
	var bag_icon := TextureRect.new()
	bag_icon.texture = _load_tex("res://assets/items/backpack.png")
	bag_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bag_icon.offset_left = 6
	bag_icon.offset_top = 6
	bag_icon.offset_right = -6
	bag_icon.offset_bottom = -6
	bag_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag.add_child(bag_icon)
	bag.pressed.connect(func(): Input.parse_input_event(_make_action("open_inventory")))
	hh.add_child(bag)
	Inventory.changed.connect(_refresh_hotbar)
	_refresh_hotbar()

	# ---------- низ ----------
	_hint = UITheme.label(tr("HINT_CATCH"), 20, UITheme.TEXT_LIGHT)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.position.y -= 120
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_hint.add_theme_constant_override("shadow_outline_size", 6)
	_hint.modulate.a = 0.0
	add_child(_hint)

	_toast = UITheme.label("", 20, UITheme.AMBER)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.position.y -= 150
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_toast.add_theme_constant_override("shadow_outline_size", 6)
	_toast.modulate.a = 0.0
	add_child(_toast)

	_controls = UITheme.label(tr("CONTROLS_HINT"), 13, Color(1, 1, 1, 0.45))
	_controls.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_controls.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_controls.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_controls.position.y -= 8
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_controls.add_theme_constant_override("shadow_outline_size", 4)
	add_child(_controls)

	_saved = UITheme.label("✿ " + tr("SAVED"), 18, UITheme.GLOW)
	_saved.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_saved.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_saved.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_saved.position -= Vector2(20, 60)
	_saved.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_saved.add_theme_constant_override("shadow_outline_size", 6)
	_saved.modulate.a = 0.0
	add_child(_saved)

	_fps = UITheme.label("", 14, Color(0.8, 1.0, 0.8, 0.9))
	_fps.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fps.position = Vector2(16, 150)
	_fps.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_fps.add_theme_constant_override("shadow_outline_size", 4)
	add_child(_fps)

	Settings.settings_changed.connect(_refresh_speed)
	_refresh_speed()
	GameState.jar_changed.connect(_refresh_jar)
	GameState.temple_changed.connect(func(_l: int): _refresh_jar())
	SaveManager.game_saved.connect(func(_s: String): show_saved())
	_refresh_jar()

func _speed_style(pressed: bool, hover := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.20, 0.42, 0.46) if pressed else (Color(0.12, 0.24, 0.28, 0.9) if hover else Color(0.06, 0.13, 0.16, 0.8))
	s.border_color = UITheme.CYAN if pressed else UITheme.EDGE
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s

func set_firefly_manager(fm) -> void:
	_fireflies = fm

func _process(delta: float) -> void:
	var t: float = GameState.time_of_day
	var h := int(t)
	var m := int((t - h) * 60.0)
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	_time_text.text = "%d:%02d %s" % [h12, m, "AM" if h < 12 else "PM"]
	var wd := (GameState.day - 1) % 7
	_date_text.text = "%s %d · %s · %s" % [tr("DAY"), GameState.day, tr("WEEKDAY_%d" % wd), tr("MONTH_" + GameState.season)]
	_phase_text.text = "%s · %s" % [tr("PHASE_" + GameState.get_phase()), tr("W_" + GameState.weather)]
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
		dots += " +%d" % (used - GameState.JAR_SLOTS)
	_jar_text.text = "%s  %s\n%s: %s" % [tr("JAR_TITLE"), dots, tr("TEMPLE"), tr("TEMPLE_%d" % GameState.temple_level)]
	_jar_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.8) if GameState.jar_is_over() else UITheme.TEXT_LIGHT)

func show_saved() -> void:
	AudioManager.play_sfx("save", -8.0)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_saved, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.6)
	tw.tween_property(_saved, "modulate:a", 0.0, 0.8)

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null

func _make_action(action: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev

func _refresh_hotbar() -> void:
	for sl in _hot_slots:
		sl.set_item(str(Inventory.hotbar[sl.index]))
		sl.set_state(Inventory.active_slot == sl.index, false)

func show_toast(text: String) -> void:
	_toast.text = text
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
