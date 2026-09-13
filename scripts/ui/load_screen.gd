extends Control
## Список сохранений: карточки с именем, датой, днём, погодой; загрузить / переименовать / удалить.

var _selected := ""
var _list: VBoxContainer
var _b_load: Button
var _b_delete: Button
var _b_rename: Button
var _confirm: ConfirmationDialog
var _rename_dialog: ConfirmationDialog
var _rename_edit: LineEdit
var _cards := {}

func _ready() -> void:
	theme = UITheme.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg = preload("res://scripts/ui/menu_background.gd").new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(UITheme.dim_layer())

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 600)
	cc.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)
	var st := UITheme.sign_title(tr("LOAD_TITLE"))
	st.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(st)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 10)
	root.add_child(btns)
	_b_load = UITheme.button(tr("LOAD"), 170)
	_b_load.pressed.connect(_on_load)
	btns.add_child(_b_load)
	_b_rename = UITheme.button(tr("RENAME"), 190)
	_b_rename.pressed.connect(_on_rename)
	btns.add_child(_b_rename)
	_b_delete = UITheme.button(tr("DELETE"), 150)
	_b_delete.pressed.connect(_on_delete)
	btns.add_child(_b_delete)
	var b_back := UITheme.button(tr("BACK"), 150)
	b_back.pressed.connect(func(): SceneRouter.go_to(SceneRouter.MAIN_MENU, 0.4))
	btns.add_child(b_back)

	_confirm = ConfirmationDialog.new()
	_confirm.theme = theme
	_confirm.dialog_text = tr("DELETE_CONFIRM")
	_confirm.ok_button_text = tr("YES")
	_confirm.cancel_button_text = tr("NO")
	_confirm.confirmed.connect(func():
		SaveManager.delete_save(_selected)
		_selected = ""
		_refresh()
	)
	add_child(_confirm)
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.theme = theme
	_rename_dialog.title = tr("RENAME")
	_rename_dialog.ok_button_text = tr("YES")
	_rename_dialog.cancel_button_text = tr("CANCEL")
	_rename_edit = LineEdit.new()
	_rename_edit.max_length = 32
	_rename_edit.custom_minimum_size = Vector2(320, 0)
	_rename_dialog.add_child(_rename_edit)
	_rename_dialog.register_text_enter(_rename_edit)
	_rename_dialog.confirmed.connect(func():
		SaveManager.rename_save(_selected, _rename_edit.text)
		_refresh()
	)
	add_child(_rename_dialog)
	_refresh()
	UITheme.pop_in(panel)

func _on_load() -> void:
	if _selected != "":
		SceneRouter.load_game(_selected)

func _on_delete() -> void:
	if _selected != "":
		_confirm.popup_centered()

func _on_rename() -> void:
	if _selected == "":
		return
	var meta: Dictionary = SaveManager.read_save(_selected).get("meta", {})
	_rename_edit.text = str(meta.get("name", ""))
	_rename_dialog.popup_centered()
	_rename_edit.grab_focus()
	_rename_edit.select_all()

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	_cards.clear()
	var saves := SaveManager.list_saves()
	if saves.is_empty():
		var l := UITheme.label(tr("NO_SAVES"), 20, UITheme.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(l)
	for meta in saves:
		_list.add_child(_make_card(meta))
	var has := _selected != ""
	_b_load.disabled = not has
	_b_delete.disabled = not has
	_b_rename.disabled = not has

func _make_card(meta: Dictionary) -> Button:
	var id := str(meta.get("id", ""))
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = id == _selected
	b.custom_minimum_size = Vector2(0, 74)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	var phase := SaveManager.phase_for(float(meta.get("time_of_day", 7.0)))
	var when := str(meta.get("saved_at", "")).replace("T", "  ")
	b.text = "  %s\n  %s %d · %s, %s · %s: %s · %s: %d      %s" % [
		str(meta.get("name", "")), tr("DAY"), int(meta.get("day", 1)),
		tr("PHASE_" + phase), tr("W_" + str(meta.get("weather", "clear"))),
		tr("TEMPLE"), tr("TEMPLE_%d" % int(meta.get("temple_level", 0))),
		tr("CAUGHT_TOTAL"), int(meta.get("caught", 0)), when]
	b.add_theme_font_size_override("font_size", 17)
	UITheme.decorate_button(b)
	b.pressed.connect(func():
		_selected = id
		for k in _cards:
			(_cards[k] as Button).set_pressed_no_signal(k == id)
		_b_load.disabled = false
		_b_delete.disabled = false
		_b_rename.disabled = false
	)
	_cards[id] = b
	return b
