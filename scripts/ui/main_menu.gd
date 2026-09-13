extends Control

func _ready() -> void:
	theme = UITheme.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameState.running = false
	Settings.apply_audio()
	AudioManager.set_mood("menu")
	AudioManager.set_ambient("wind", 0.25)

	var bg = preload("res://scripts/ui/menu_background.gd").new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# лёгкое затемнение снизу для читаемости
	var grad := TextureRect.new()
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.03, 0.08, 0.0))
	g.set_color(1, Color(0.15, 0.08, 0.15, 0.30))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.3)
	gt.fill_to = Vector2(0, 1)
	grad.texture = gt
	add_child(grad)

	# левая колонка с меню на бумажной панели
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var t := UITheme.title("Хотару", 84, UITheme.TEXT_LIGHT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.add_theme_color_override("font_shadow_color", Color(0.2, 0.1, 0.05, 0.7))
	t.add_theme_constant_override("shadow_offset_y", 4)
	t.add_theme_constant_override("shadow_outline_size", 10)
	col.add_child(t)
	var sub := UITheme.label("остров у древнего храма", 20, Color(1, 0.95, 0.85, 0.85))
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	sub.add_theme_constant_override("shadow_outline_size", 4)
	col.add_child(sub)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	col.add_child(sp)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	var last := SaveManager.get_last_slot()
	var b_continue := UITheme.button(tr("MENU_CONTINUE"), 300)
	b_continue.disabled = last == ""
	if last != "":
		var meta: Dictionary = SaveManager.read_save(last).get("meta", {})
		b_continue.tooltip_text = "%s — %s %d" % [str(meta.get("name", "")), tr("DAY"), int(meta.get("day", 1))]
	b_continue.pressed.connect(func(): SceneRouter.load_game(last))
	v.add_child(b_continue)
	var b_new := UITheme.button(tr("MENU_NEW"), 300)
	b_new.pressed.connect(func(): SceneRouter.start_new_game())
	v.add_child(b_new)
	var b_load := UITheme.button(tr("MENU_LOAD"), 300)
	b_load.pressed.connect(func(): SceneRouter.go_to(SceneRouter.LOAD_SCREEN, 0.4))
	v.add_child(b_load)
	var b_settings := UITheme.button(tr("MENU_SETTINGS"), 300)
	b_settings.pressed.connect(func(): SceneRouter.open_settings(SceneRouter.MAIN_MENU))
	v.add_child(b_settings)
	var b_quit := UITheme.button(tr("MENU_QUIT"), 300)
	b_quit.pressed.connect(func(): get_tree().quit())
	v.add_child(b_quit)

	# печать-декор в углу
	var seal := TextureRect.new()
	seal.texture = UITheme.TEX_SEAL
	seal.custom_minimum_size = Vector2(110, 110)
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	seal.offset_left = -150
	seal.offset_top = -150
	seal.offset_right = -40
	seal.offset_bottom = -40
	seal.modulate.a = 0.85
	add_child(seal)
	var ver := UITheme.label("прототип · Godot 4.7", 13, Color(1, 1, 1, 0.5))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 16
	ver.offset_top = -30
	add_child(ver)

	UITheme.fade_in(col, 1.0)
	if not b_continue.disabled:
		b_continue.grab_focus()
	else:
		b_new.grab_focus()
