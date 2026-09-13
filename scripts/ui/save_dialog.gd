extends CanvasLayer
## Диалог сохранения: ввод названия, перезапись текущего или новое сохранение.

signal done(saved: bool)

var _edit: LineEdit
var _root: Control

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UITheme.make_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.add_child(UITheme.dim_layer())
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(cc)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var st := UITheme.sign_title(tr("SAVE_TITLE"), 26)
	st.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(st)
	v.add_child(UITheme.label(tr("SAVE_NAME_PROMPT"), 18, UITheme.INK_SOFT))
	_edit = LineEdit.new()
	_edit.max_length = 32
	_edit.placeholder_text = tr("SAVE_DEFAULT_NAME")
	_edit.text = SaveManager.active_name if SaveManager.active_name != "" else _suggest_name()
	_edit.text_submitted.connect(func(_t): _save(SaveManager.active_slot != ""))
	v.add_child(_edit)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	if SaveManager.active_slot != "":
		var b_over := UITheme.button(tr("SAVE_OVERWRITE"), 190)
		b_over.pressed.connect(func(): _save(true))
		h.add_child(b_over)
	var b_new := UITheme.button(tr("SAVE_NEW"), 210)
	b_new.pressed.connect(func(): _save(false))
	h.add_child(b_new)
	var b_cancel := UITheme.button(tr("CANCEL"), 140)
	b_cancel.pressed.connect(func(): _close(false))
	h.add_child(b_cancel)
	UITheme.pop_in(panel)
	_edit.grab_focus()
	_edit.select_all()

func _suggest_name() -> String:
	return "%s %d · %s" % [tr("DAY"), GameState.day, tr("PHASE_" + GameState.get_phase())]

func _save(overwrite: bool) -> void:
	var id := SaveManager.active_slot if overwrite else ""
	SaveManager.save_game(id, _edit.text)
	_close(true)

func _close(saved: bool) -> void:
	done.emit(saved)
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_close(false)
		get_viewport().set_input_as_handled()
