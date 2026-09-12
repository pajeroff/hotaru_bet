extends CanvasLayer
## Панель банки: содержимое, описание светлячка, отпускание.

const GameStateScript := preload("res://scripts/autoload/game_state.gd")

signal closed

var _list: VBoxContainer
var _info: Label
var _slots_label: Label
var _selected := -1
var _release_btn: Button
var _panel: PanelContainer

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UITheme.make_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.1, 0.16, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(620, 420)
	root.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)
	v.add_child(UITheme.title(tr("JAR_TITLE"), 36))
	_slots_label = UITheme.label("", 18, UITheme.MUTED)
	_slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_slots_label)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_info = UITheme.label("", 18)
	_info.custom_minimum_size = Vector2(260, 0)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_info)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 14)
	v.add_child(btns)
	_release_btn = UITheme.button(tr("RELEASE"), 180)
	_release_btn.pressed.connect(_release)
	btns.add_child(_release_btn)
	var close := UITheme.button(tr("CLOSE"), 180)
	close.pressed.connect(close_panel)
	btns.add_child(close)
	_refresh()
	UITheme.fade_in(_panel, 0.3)
	AudioManager.play_sfx("open", -8.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_jar") or event.is_action_pressed("pause"):
		close_panel()
		get_viewport().set_input_as_handled()

func close_panel() -> void:
	closed.emit()
	queue_free()

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var used := GameState.jar_used_slots()
	_slots_label.text = "%d / %d %s" % [used, GameState.JAR_SLOTS, tr("SLOTS")]
	if GameState.jar_is_over():
		_slots_label.text += "  ·  " + tr("JAR_FULL")
	if GameState.jar.is_empty():
		_list.add_child(UITheme.label(tr("JAR_EMPTY"), 18, UITheme.MUTED))
	for i in range(GameState.jar.size()):
		var f: Dictionary = GameState.jar[i]
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = (i == _selected)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var col := FireflyData.color_of(f)
		b.text = "●  %s  (%d)" % [tr(str(f["name"])), GameStateScript.slot_cost(str(f["rarity"]))]
		b.add_theme_color_override("font_color", col.darkened(0.35))
		b.add_theme_color_override("font_hover_color", col.darkened(0.35))
		b.add_theme_color_override("font_pressed_color", col.darkened(0.35))
		UITheme.decorate_button(b)
		b.pressed.connect(_select.bind(i))
		_list.add_child(b)
	if _selected >= 0 and _selected < GameState.jar.size():
		var f: Dictionary = GameState.jar[_selected]
		_info.text = "%s\n\n%s: %s\n%s: %s\n%s: %s" % [
			tr(str(f["name"])),
			tr("RARITY"), tr("RARITY_" + str(f["rarity"])),
			tr("EMOTION"), tr("EMO_" + str(f["emotion"])),
			tr("ELEMENT"), tr("EL_" + str(f["element"])),
		]
		_release_btn.disabled = false
	else:
		_info.text = ""
		_release_btn.disabled = true

func _select(i: int) -> void:
	_selected = i
	_refresh()

func _release() -> void:
	if _selected < 0:
		return
	GameState.release_from_jar(_selected)
	_selected = -1
	_refresh()
