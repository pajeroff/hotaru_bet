extends CanvasLayer
## Пауза: продолжить, настройки, сохранить, выйти (с предупреждением, если давно не сохранялись).

signal resumed

var _root: Control
var _panel: PanelContainer
var _warn: PanelContainer

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UITheme.make_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.add_child(UITheme.dim_layer())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	var st := UITheme.sign_title(tr("PAUSE_TITLE"))
	st.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(st)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)

	var b_resume := UITheme.button(tr("RESUME"), 300)
	b_resume.pressed.connect(resume)
	v.add_child(b_resume)
	var b_save := UITheme.button(tr("SAVE_GAME"), 300)
	b_save.pressed.connect(_open_save)
	v.add_child(b_save)
	var b_settings := UITheme.button(tr("MENU_SETTINGS"), 300)
	b_settings.pressed.connect(_open_settings)
	v.add_child(b_settings)
	var b_menu := UITheme.button(tr("TO_MENU"), 300)
	b_menu.pressed.connect(_try_quit)
	v.add_child(b_menu)
	if SaveManager.active_name != "":
		var cur := UITheme.label("%s: %s" % [tr("CURRENT_SAVE"), SaveManager.active_name], 14, UITheme.MUTED)
		cur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cur)

	# панель предупреждения (скрыта)
	_warn = PanelContainer.new()
	_warn.custom_minimum_size = Vector2(520, 0)
	_warn.visible = false
	center.add_child(_warn)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 12)
	_warn.add_child(wv)
	var wl := UITheme.label(tr("UNSAVED_WARN"), 20)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wv.add_child(wl)
	var b1 := UITheme.button(tr("SAVE_AND_QUIT"), 320)
	b1.pressed.connect(func():
		_warn.visible = false
		if SaveManager.quick_save():
			_quit()
		else:
			var d = preload("res://scripts/ui/save_dialog.gd").new()
			add_child(d)
			d.done.connect(func(saved: bool):
				if saved: _quit()
				else: _panel.visible = true
			)
	)
	wv.add_child(b1)
	var b2 := UITheme.button(tr("QUIT_NO_SAVE"), 320)
	b2.pressed.connect(_quit)
	wv.add_child(b2)
	var b3 := UITheme.button(tr("CANCEL"), 320)
	b3.pressed.connect(func():
		_warn.visible = false
		_panel.visible = true
	)
	wv.add_child(b3)

	UITheme.pop_in(_panel)
	b_resume.grab_focus()
	var idx := AudioServer.get_bus_index("Master")
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(func(vv): AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(Settings.master_volume * vv, 0.0001))), 1.0, 0.35, 0.4)

func _open_save() -> void:
	_panel.visible = false
	var d = preload("res://scripts/ui/save_dialog.gd").new()
	add_child(d)
	d.done.connect(func(_saved: bool): _panel.visible = true)

func _open_settings() -> void:
	var s = preload("res://scripts/ui/settings_screen.gd").new()
	s.embedded = true
	_root.visible = false
	s.closed.connect(func(): _root.visible = true)
	add_child(s)

func _try_quit() -> void:
	if SaveManager.needs_save_warning():
		_panel.visible = false
		_warn.visible = true
		UITheme.pop_in(_warn)
	else:
		_quit()

func _quit() -> void:
	var midx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(midx, linear_to_db(maxf(Settings.master_volume, 0.0001)))
	SaveManager.autosave()
	AudioManager.set_ambient("wind", 0.25)
	SceneRouter.go_to(SceneRouter.MAIN_MENU, 0.8)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _root.visible and _panel.visible:
		resume()
		get_viewport().set_input_as_handled()

func resume() -> void:
	var idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(Settings.master_volume, 0.0001)))
	get_tree().paused = false
	resumed.emit()
	queue_free()
