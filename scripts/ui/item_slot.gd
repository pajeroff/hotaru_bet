class_name ItemSlot
extends Button
## Ячейка предмета: иконка, номер клавиши, подсветка активной/выбранной.

var container := "hotbar"
var index := 0
var item_id := ""
var hotkey := ""
var active := false
var selected := false
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
	tooltip_text = "" if id == "" else "%s\n%s" % [tr(Inventory.ITEMS[id]["name"]), tr(Inventory.ITEMS[id]["desc"])]
	_apply()

func set_state(is_active: bool, is_selected: bool) -> void:
	active = is_active
	selected = is_selected
	_apply()

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
