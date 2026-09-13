class_name ItemSlot
extends Button
## Ячейка предмета: иконка, номер клавиши, подсветка активной; drag & drop между ячейками.

var container := "hotbar"
var index := 0
var item_id := ""
var hotkey := ""
var active := false
var selected := false
var allow_drag := true
var _icon: TextureRect
var _key: Label

func _init(cont: String, idx: int, size_px := 58) -> void:
	container = cont
	index = idx
	custom_minimum_size = Vector2(size_px, size_px)
	focus_mode = Control.FOCUS_NONE
	toggle_mode = false
	_icon = TextureRect.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 6
	_icon.offset_top = 6
	_icon.offset_right = -6
	_icon.offset_bottom = -6
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_key = Label.new()
	_key.add_theme_font_size_override("font_size", 11)
	_key.add_theme_color_override("font_color", UITheme.MUTED)
	_key.position = Vector2(4, 1)
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_key)
	_apply()

func set_item(id: String) -> void:
	item_id = id
	_icon.texture = Inventory.icon(id)
	tooltip_text = "" if id == "" or not Inventory.ITEMS.has(id) else "%s\n%s" % [tr(Inventory.ITEMS[id]["name"]), tr(Inventory.ITEMS[id]["desc"])]
	_apply()

func set_state(is_active: bool, is_selected: bool) -> void:
	active = is_active
	selected = is_selected
	_apply()

# ---- drag & drop ----
func _get_drag_data(_at: Vector2) -> Variant:
	if not allow_drag or item_id == "" or index < 0:
		return null
	var pv := TextureRect.new()
	pv.texture = _icon.texture
	pv.custom_minimum_size = Vector2(48, 48)
	pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pv.modulate.a = 0.9
	var wrap := Control.new()
	wrap.add_child(pv)
	pv.position = Vector2(-24, -24)
	set_drag_preview(wrap)
	_icon.modulate.a = 0.35
	return {"container": container, "index": index, "item": item_id}

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return allow_drag and index >= 0 and data is Dictionary and data.has("container")

func _drop_data(_at: Vector2, data: Variant) -> void:
	var d: Dictionary = data
	Inventory.swap(str(d["container"]), int(d["index"]), container, index)
	AudioManager.play_sfx("click", -8.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_icon.modulate.a = 1.0 if item_id != "" else 0.0

func _apply() -> void:
	_key.text = hotkey
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.22, 0.26, 0.9) if active else Color(0.04, 0.09, 0.12, 0.8)
	s.border_color = UITheme.CYAN if active else (UITheme.AMBER if selected else UITheme.EDGE)
	s.set_border_width_all(2 if (active or selected) else 1)
	s.set_corner_radius_all(9)
	if active:
		s.shadow_color = Color(UITheme.CYAN.r, UITheme.CYAN.g, UITheme.CYAN.b, 0.35)
		s.shadow_size = 8
	add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.14, 0.28, 0.32, 0.95)
	add_theme_stylebox_override("hover", h)
	add_theme_stylebox_override("pressed", h)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_icon.modulate.a = 1.0 if item_id != "" else 0.0
