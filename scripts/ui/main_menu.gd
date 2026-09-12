extends Control

func _ready() -> void:
	theme = UITheme.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameState.running = false
	Settings.apply_audio()
	AudioManager.set_mood("menu")
	AudioManager.set_ambient("wind", 0.25)

	var bg = preload("res://scripts/ui/menu_background.gd").new()
	add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 14)
	add_child(center)

	var t := UITheme.title("Хотару", 84)
	center.add_child(t)
	var sub := UITheme.label("остров у древнего храма", 18, UITheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	center.add_child(spacer)

	var b_continue := UITheme.button(tr("MENU_CONTINUE"))
	b_continue.disabled = SaveManager.get_last_slot() < 0
	b_continue.pressed.connect(func(): SceneRouter.load_game(SaveManager.get_last_slot()))
	center.add_child(b_continue)

	var b_new := UITheme.button(tr("MENU_NEW"))
	b_new.pressed.connect(func(): SceneRouter.start_new_game())
	center.add_child(b_new)

	var b_load := UITheme.button(tr("MENU_LOAD"))
	b_load.pressed.connect(func(): SceneRouter.go_to(SceneRouter.LOAD_SCREEN, 0.4))
	center.add_child(b_load)

	var b_settings := UITheme.button(tr("MENU_SETTINGS"))
	b_settings.pressed.connect(func(): SceneRouter.open_settings(SceneRouter.MAIN_MENU))
	center.add_child(b_settings)

	var b_quit := UITheme.button(tr("MENU_QUIT"))
	b_quit.pressed.connect(func(): get_tree().quit())
	center.add_child(b_quit)

	var ver := UITheme.label("прототип · Godot 4.7", 14, UITheme.MUTED)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.position -= Vector2(16, 12)
	add_child(ver)

	UITheme.fade_in(center, 1.2)
	if not b_continue.disabled:
		b_continue.grab_focus()
	else:
		b_new.grab_focus()
