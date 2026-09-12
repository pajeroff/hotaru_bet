extends Control
## Экран настроек. Используется и из меню, и из паузы (как оверлей).

var embedded := false # true, если открыт поверх паузы
signal closed

var _rebinding_action := ""
var _rebind_button: Button
var _key_buttons := {}
var _brightness_slider: HSlider

func _ready() -> void:
	theme = UITheme.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	_key_buttons.clear()
	_rebinding_action = ""
	_rebind_button = null
	if not embedded:
		var bg = preload("res://scripts/ui/menu_background.gd").new()
		add_child(bg)
	else:
		var dim := ColorRect.new()
		dim.color = Color(0.1, 0.1, 0.16, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(760, 560)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(UITheme.title(tr("SETTINGS_TITLE"), 40))

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 20)
	v.add_child(tabs)

	tabs.add_child(_graphics_tab())
	tabs.add_child(_audio_tab())
	tabs.add_child(_controls_tab())
	tabs.add_child(_game_tab())

	var b_back := UITheme.button(tr("BACK"), 200)
	b_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b_back.pressed.connect(_on_back)
	v.add_child(b_back)
	UITheme.fade_in(panel, 0.5)

func _on_back() -> void:
	Settings.save()
	if embedded:
		closed.emit()
		queue_free()
	else:
		SceneRouter.go_to(SceneRouter.settings_return_scene, 0.4)

func _row(parent: Control, label_key: String, control: Control) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var l := UITheme.label(tr(label_key), 20)
	l.custom_minimum_size = Vector2(300, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	parent.add_child(h)

func _tab(name_key: String) -> VBoxContainer:
	var m := MarginContainer.new()
	m.name = tr(name_key)
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", 16)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)
	v.set_meta("container", m)
	return v

func _wrap(v: VBoxContainer) -> Control:
	var c: Control = v.get_meta("container")
	return c

func _graphics_tab() -> Control:
	var v := _tab("TAB_GRAPHICS")
	var fs := CheckButton.new()
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(on):
		Settings.fullscreen = on
		Settings.apply_graphics()
		Settings.save()
	)
	_row(v, "FULLSCREEN", fs)

	var res := OptionButton.new()
	for r in Settings.RESOLUTIONS:
		res.add_item("%d × %d" % [r.x, r.y])
	res.selected = Settings.resolution_index
	res.item_selected.connect(func(i):
		Settings.resolution_index = i
		Settings.apply_graphics()
		Settings.save()
	)
	_row(v, "RESOLUTION", res)

	var vs := CheckButton.new()
	vs.button_pressed = Settings.vsync
	vs.toggled.connect(func(on):
		Settings.vsync = on
		Settings.apply_graphics()
		Settings.save()
	)
	_row(v, "VSYNC", vs)

	var pq := OptionButton.new()
	pq.add_item(tr("LOW"))
	pq.add_item(tr("MEDIUM"))
	pq.add_item(tr("HIGH"))
	pq.selected = Settings.particle_quality
	pq.item_selected.connect(func(i):
		Settings.particle_quality = i
		Settings.save()
		Settings.settings_changed.emit()
	)
	_row(v, "PARTICLES", pq)

	_brightness_slider = HSlider.new()
	_brightness_slider.min_value = 0.5
	_brightness_slider.max_value = 1.5
	_brightness_slider.step = 0.05
	_brightness_slider.value = Settings.brightness
	_brightness_slider.custom_minimum_size = Vector2(0, 28)
	_brightness_slider.value_changed.connect(func(val):
		Settings.brightness = val
		Settings.save()
		Settings.settings_changed.emit()
	)
	_row(v, "BRIGHTNESS", _brightness_slider)
	return _wrap(v)

func _slider(value: float, setter: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(0, 28)
	s.value_changed.connect(func(val):
		setter.call(val)
		Settings.apply_audio()
		Settings.save()
	)
	return s

func _audio_tab() -> Control:
	var v := _tab("TAB_AUDIO")
	_row(v, "VOL_MASTER", _slider(Settings.master_volume, func(x): Settings.master_volume = x))
	_row(v, "VOL_MUSIC", _slider(Settings.music_volume, func(x): Settings.music_volume = x))
	_row(v, "VOL_SFX", _slider(Settings.sfx_volume, func(x): Settings.sfx_volume = x))
	return _wrap(v)

func _controls_tab() -> Control:
	var v := _tab("TAB_CONTROLS")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)
	v.add_child(scroll)
	for a in Settings.ACTIONS:
		var b := Button.new()
		b.text = Settings.get_action_key_name(a)
		b.custom_minimum_size = Vector2(180, 0)
		UITheme.decorate_button(b)
		b.pressed.connect(_start_rebind.bind(a, b))
		_key_buttons[a] = b
		_row(inner, "ACT_" + a, b)
	var reset := UITheme.button(tr("RESET_DEFAULT"), 260)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(func():
		Settings.reset_controls()
		_refresh_keys()
	)
	v.add_child(reset)
	return _wrap(v)

func _start_rebind(action: String, b: Button) -> void:
	if _rebind_button != null:
		_rebind_button.text = Settings.get_action_key_name(_rebinding_action)
	_rebinding_action = action
	_rebind_button = b
	b.text = tr("PRESS_KEY")

func _unhandled_input(event: InputEvent) -> void:
	if _rebinding_action == "":
		return
	if event is InputEventKey and event.is_pressed():
		var k := event as InputEventKey
		var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
		if code == KEY_ESCAPE:
			if _rebind_button != null:
				_rebind_button.text = Settings.get_action_key_name(_rebinding_action)
		else:
			Settings.rebind(_rebinding_action, code)
		_rebinding_action = ""
		_rebind_button = null
		_refresh_keys()
		get_viewport().set_input_as_handled()

func _refresh_keys() -> void:
	for a in _key_buttons:
		var b: Button = _key_buttons[a]
		if is_instance_valid(b):
			b.text = Settings.get_action_key_name(a)

func _on_language_selected(i: int) -> void:
	Settings.set_language("ru" if i == 0 else "en")
	# Перестраиваем экран на месте, чтобы язык применился сразу
	call_deferred("_build")

func _game_tab() -> Control:
	var v := _tab("TAB_GAME")
	var ts := OptionButton.new()
	ts.add_item(tr("SLOW"))
	ts.add_item(tr("NORMAL"))
	ts.add_item(tr("FAST"))
	ts.selected = ["slow", "normal", "fast"].find(Settings.time_speed)
	ts.item_selected.connect(func(i):
		Settings.time_speed = ["slow", "normal", "fast"][i]
		Settings.save()
	)
	_row(v, "TIME_SPEED", ts)

	var lang := OptionButton.new()
	lang.add_item("Русский")
	lang.add_item("English")
	lang.selected = 0 if Settings.language == "ru" else 1
	lang.item_selected.connect(_on_language_selected)
	_row(v, "LANGUAGE", lang)
	return _wrap(v)
