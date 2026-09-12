extends Control

var _selected := -1
var _slot_buttons: Array = []
var _b_load: Button
var _b_delete: Button
var _confirm: ConfirmationDialog

func _ready() -> void:
	theme = UITheme.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg = preload("res://scripts/ui/menu_background.gd").new()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	root.add_child(UITheme.title(tr("LOAD_TITLE"), 48))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	root.add_child(row)
	for i in range(SaveManager.SLOT_COUNT):
		var b := Button.new()
		b.custom_minimum_size = Vector2(250, 190)
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.decorate_button(b)
		b.pressed.connect(_on_slot_pressed.bind(i))
		row.add_child(b)
		_slot_buttons.append(b)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 14)
	root.add_child(btns)
	_b_load = UITheme.button(tr("LOAD"), 180)
	_b_load.pressed.connect(_on_load)
	btns.add_child(_b_load)
	_b_delete = UITheme.button(tr("DELETE"), 180)
	_b_delete.pressed.connect(_on_delete)
	btns.add_child(_b_delete)
	var b_back := UITheme.button(tr("BACK"), 180)
	b_back.pressed.connect(func(): SceneRouter.go_to(SceneRouter.MAIN_MENU, 0.4))
	btns.add_child(b_back)

	_confirm = ConfirmationDialog.new()
	_confirm.dialog_text = tr("DELETE_CONFIRM")
	_confirm.ok_button_text = tr("YES")
	_confirm.cancel_button_text = tr("NO")
	_confirm.confirmed.connect(func():
		SaveManager.delete_slot(_selected)
		_selected = -1
		_refresh()
	)
	add_child(_confirm)
	_refresh()
	UITheme.fade_in(root)

func _on_load() -> void:
	if _selected >= 0:
		SceneRouter.load_game(_selected)

func _on_delete() -> void:
	if _selected >= 0:
		_confirm.popup_centered()

func _on_slot_pressed(i: int) -> void:
	_selected = i
	_refresh()

func _refresh() -> void:
	for i in range(_slot_buttons.size()):
		var b: Button = _slot_buttons[i]
		var d := SaveManager.read_slot(i)
		b.button_pressed = (i == _selected)
		if d.is_empty():
			b.text = "%s %d\n\n%s" % [tr("SLOT"), i + 1, tr("EMPTY")]
			b.modulate = Color(0.85, 0.85, 0.88)
		else:
			b.modulate = Color.WHITE
			var phase := _phase_for(float(d.get("time_of_day", 7.0)))
			b.text = "%s %d\n%s\n%s %d · %s: %s\n%s, %s, %s" % [
				tr("SLOT"), i + 1,
				str(d.get("saved_at", "")).replace("T", " "),
				tr("DAY"), int(d.get("day", 1)),
				tr("TEMPLE"), tr("TEMPLE_%d" % int(d.get("temple_level", 0))),
				tr("PLACE_glade"), tr("PHASE_" + phase), tr("W_" + str(d.get("weather", "clear"))),
			]
	var has := _selected >= 0 and SaveManager.has_save(_selected)
	_b_load.disabled = not has
	_b_delete.disabled = not has

func _phase_for(t: float) -> String:
	if t < 5.0: return "night"
	if t < 7.0: return "dawn"
	if t < 11.0: return "morning"
	if t < 17.0: return "day"
	if t < 19.0: return "sunset"
	if t < 21.5: return "evening"
	return "night"
