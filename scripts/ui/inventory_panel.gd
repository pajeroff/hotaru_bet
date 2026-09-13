extends CanvasLayer
## Рюкзак: сетка 20 ячеек + строка быстрого доступа; перекладывание кликом (выбрать → положить).

signal closed

var _root: Control
var _bag_slots: Array = []
var _hot_slots: Array = []
var _sel_cont := ""
var _sel_idx := -1
var _info: Label

func _ready() -> void:
	layer = 20
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
	panel.custom_minimum_size = Vector2(560, 0)
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var st := UITheme.sign_title(tr("INV_TITLE"))
	st.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(st)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(grid)
	for i in range(Inventory.BAG_SIZE):
		var sl := ItemSlot.new("bag", i, 64)
		sl.pressed.connect(_on_slot.bind(sl))
		grid.add_child(sl)
		_bag_slots.append(sl)
	v.add_child(UITheme.label(tr("HOTBAR"), 15, UITheme.MUTED))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(hb)
	for i in range(Inventory.HOTBAR_SIZE):
		var sl := ItemSlot.new("hotbar", i, 64)
		sl.hotkey = str(i + 1)
		sl.pressed.connect(_on_slot.bind(sl))
		hb.add_child(sl)
		_hot_slots.append(sl)
	_info = UITheme.label(tr("INV_HINT"), 15, UITheme.MUTED)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(500, 44)
	v.add_child(_info)
	var close := UITheme.button(tr("CLOSE"), 180)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close)
	v.add_child(close)
	Inventory.changed.connect(_refresh)
	_refresh()
	UITheme.pop_in(panel)
	AudioManager.play_sfx("open", -8.0)

func _on_slot(sl: ItemSlot) -> void:
	if _sel_idx < 0:
		if sl.item_id == "":
			return
		_sel_cont = sl.container
		_sel_idx = sl.index
		_info.text = "%s — %s" % [tr(Inventory.ITEMS[sl.item_id]["name"]), tr(Inventory.ITEMS[sl.item_id]["desc"])]
	else:
		Inventory.swap(_sel_cont, _sel_idx, sl.container, sl.index)
		_sel_idx = -1
		_sel_cont = ""
		_info.text = tr("INV_HINT")
		AudioManager.play_sfx("click", -8.0)
	_refresh()

func _refresh() -> void:
	for sl in _bag_slots:
		sl.set_item(str(Inventory.bag[sl.index]))
		sl.set_state(false, _sel_cont == "bag" and _sel_idx == sl.index)
	for sl in _hot_slots:
		sl.set_item(str(Inventory.hotbar[sl.index]))
		sl.set_state(Inventory.active_slot == sl.index, _sel_cont == "hotbar" and _sel_idx == sl.index)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory") or event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	closed.emit()
	queue_free()
