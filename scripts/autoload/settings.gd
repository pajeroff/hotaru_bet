extends Node
## Настройки игры: графика, звук, управление, игра. Сохраняются автоматически.

signal settings_changed
signal quality_changed
signal language_changed

const PATH := "user://settings.cfg"
const ACTIONS := ["move_up", "move_down", "move_left", "move_right", "interact", "open_jar", "open_inventory", "toggle_lantern", "pause"]
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const TIME_SPEEDS := {"normal": 1.0, "fast": 1.5, "faster": 2.0}
const FPS_LIMITS: Array[int] = [0, 30, 60, 90, 120, 144, 165, 240]

var fullscreen := true
var resolution_index := 0
var vsync := true
var particle_quality := 1 # 0 low, 1 medium, 2 high — общий пресет качества графики
var brightness := 1.0
var fps_limit_index := 0 # индекс в FPS_LIMITS, 0 = без ограничения
var show_fps := false

var master_volume := 0.8
var music_volume := 0.7
var sfx_volume := 0.8

var time_speed := "normal"
var language := "ru"

var _default_events := {}
var _custom_events := {}

func _ready() -> void:
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		_default_events[a] = InputMap.action_get_events(a).duplicate()
	_load()
	_install_translations()
	apply_all()
	# окно может ещё не быть готово к смене режима на самом первом кадре
	call_deferred("apply_graphics")

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	fullscreen = cfg.get_value("graphics", "fullscreen", fullscreen)
	resolution_index = cfg.get_value("graphics", "resolution_index", resolution_index)
	vsync = cfg.get_value("graphics", "vsync", vsync)
	particle_quality = cfg.get_value("graphics", "particle_quality", particle_quality)
	brightness = cfg.get_value("graphics", "brightness", brightness)
	fps_limit_index = int(cfg.get_value("graphics", "fps_limit_index", fps_limit_index))
	show_fps = bool(cfg.get_value("graphics", "show_fps", show_fps))
	master_volume = cfg.get_value("audio", "master", master_volume)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	time_speed = cfg.get_value("game", "time_speed", time_speed)
	if not TIME_SPEEDS.has(time_speed):
		time_speed = "normal"
	language = cfg.get_value("game", "language", language)
	for a in ACTIONS:
		var code: int = int(cfg.get_value("controls", a, -1))
		if code > 0:
			_custom_events[a] = code

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.set_value("graphics", "resolution_index", resolution_index)
	cfg.set_value("graphics", "vsync", vsync)
	cfg.set_value("graphics", "particle_quality", particle_quality)
	cfg.set_value("graphics", "brightness", brightness)
	cfg.set_value("graphics", "fps_limit_index", fps_limit_index)
	cfg.set_value("graphics", "show_fps", show_fps)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("game", "time_speed", time_speed)
	cfg.set_value("game", "language", language)
	for a in _custom_events.keys():
		cfg.set_value("controls", a, _custom_events[a])
	cfg.save(PATH)

func apply_all() -> void:
	apply_graphics()
	apply_audio()
	apply_controls()
	TranslationServer.set_locale(language)
	save()
	settings_changed.emit()

func apply_graphics() -> void:
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen:
		if not is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var res: Vector2i = RESOLUTIONS[clampi(resolution_index, 0, RESOLUTIONS.size() - 1)]
		if DisplayServer.window_get_size() != res:
			DisplayServer.window_set_size(res)
			var screen_size: Vector2i = DisplayServer.screen_get_size()
			var origin: Vector2i = DisplayServer.screen_get_position()
			DisplayServer.window_set_position(origin + Vector2i((screen_size - res) / 2.0))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS_LIMITS[clampi(fps_limit_index, 0, FPS_LIMITS.size() - 1)]
	Engine.physics_ticks_per_second = 120

func apply_audio() -> void:
	_set_bus("Master", master_volume)
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)

func _set_bus(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(idx, value <= 0.001)

func apply_controls() -> void:
	for a in ACTIONS:
		InputMap.action_erase_events(a)
		if _custom_events.has(a):
			var ev := InputEventKey.new()
			ev.physical_keycode = _custom_events[a]
			InputMap.action_add_event(a, ev)
		else:
			for ev in _default_events[a]:
				InputMap.action_add_event(a, ev)

func rebind(action: String, physical_keycode: int) -> void:
	if not ACTIONS.has(action):
		return
	_custom_events[action] = physical_keycode
	apply_controls()
	save()
	settings_changed.emit()

func reset_controls() -> void:
	_custom_events.clear()
	apply_controls()
	save()
	settings_changed.emit()

func get_action_key_name(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "—"
	var ev: InputEvent = events[0]
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
		var label: int = code
		if k.physical_keycode != 0:
			label = DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
		var s := OS.get_keycode_string(label as Key)
		return s if s != "" else OS.get_keycode_string(code as Key)
	return ev.as_text()

func get_time_scale() -> float:
	return TIME_SPEEDS.get(time_speed, 1.0)

func set_language(lang: String) -> void:
	language = lang
	TranslationServer.set_locale(lang)
	save()
	language_changed.emit()
	settings_changed.emit()

# ---------- Локализация (встроенная, без внешних файлов) ----------

const STRINGS := {
	"MENU_CONTINUE": ["Продолжить", "Continue"],
	"MENU_NEW": ["Новая игра", "New Game"],
	"MENU_LOAD": ["Загрузить игру", "Load Game"],
	"MENU_SETTINGS": ["Настройки", "Settings"],
	"MENU_QUIT": ["Выход", "Quit"],
	"BACK": ["Назад", "Back"],
	"LOAD_TITLE": ["Загрузка игры", "Load Game"],
	"SLOT": ["Слот", "Slot"],
	"EMPTY": ["Пусто", "Empty"],
	"LOAD": ["Загрузить", "Load"],
	"DELETE": ["Удалить", "Delete"],
	"DELETE_CONFIRM": ["Удалить это сохранение?", "Delete this save?"],
	"YES": ["Да", "Yes"],
	"NO": ["Нет", "No"],
	"DAY": ["День", "Day"],
	"TEMPLE": ["Храм", "Temple"],
	"SETTINGS_TITLE": ["Настройки", "Settings"],
	"TAB_GRAPHICS": ["Графика", "Graphics"],
	"TAB_AUDIO": ["Звук", "Audio"],
	"TAB_CONTROLS": ["Управление", "Controls"],
	"TAB_GAME": ["Игра", "Game"],
	"FULLSCREEN": ["Полноэкранный режим", "Fullscreen"],
	"RESOLUTION": ["Разрешение экрана", "Resolution"],
	"VSYNC": ["Вертикальная синхронизация", "V-Sync"],
	"PARTICLES": ["Качество графики", "Graphics quality"],
	"LOW": ["Низкое", "Low"],
	"MEDIUM": ["Среднее", "Medium"],
	"HIGH": ["Высокое", "High"],
	"BRIGHTNESS": ["Яркость", "Brightness"],
	"FPS_LIMIT": ["Ограничение кадров", "FPS limit"],
	"UNLIMITED": ["Без ограничения", "Unlimited"],
	"SHOW_FPS": ["Счётчик кадров", "FPS counter"],
	"BLOOM": ["Свечение (bloom)", "Bloom"],
	"VOL_MASTER": ["Общая громкость", "Master volume"],
	"VOL_MUSIC": ["Громкость музыки", "Music volume"],
	"VOL_SFX": ["Звуки природы и эффекты", "Nature & effects"],
	"ACT_move_up": ["Движение вверх", "Move up"],
	"ACT_move_down": ["Движение вниз", "Move down"],
	"ACT_move_left": ["Движение влево", "Move left"],
	"ACT_move_right": ["Движение вправо", "Move right"],
	"ACT_interact": ["Взаимодействие", "Interact"],
	"ACT_open_jar": ["Открыть банку", "Open jar"],
	"ACT_open_inventory": ["Рюкзак", "Backpack"],
	"ACT_toggle_lantern": ["Фонарь", "Lantern"],
	"ACT_pause": ["Пауза", "Pause"],
	"PRESS_KEY": ["Нажмите клавишу…", "Press a key…"],
	"RESET_DEFAULT": ["Сбросить по умолчанию", "Reset to default"],
	"TIME_SPEED": ["Скорость времени", "Time speed"],
	"NORMAL": ["Обычно (×1)", "Normal (×1)"],
	"FAST": ["Быстро (×1.5)", "Fast (×1.5)"],
	"FASTER": ["Очень быстро (×2)", "Very fast (×2)"],
	"TIME_HINT": ["1 / 2 / 3 — скорость времени", "1 / 2 / 3 — time speed"],
	"LANGUAGE": ["Язык", "Language"],
	"PAUSE_TITLE": ["Пауза", "Paused"],
	"RESUME": ["Продолжить", "Resume"],
	"SAVE_GAME": ["Сохранить игру", "Save Game"],
	"TO_MENU": ["Выйти в главное меню", "Quit to Menu"],
	"SAVED": ["Сохранено", "Saved"],
	"CHOOSE_SLOT": ["Выберите слот", "Choose a slot"],
	"SAVE_DEFAULT_NAME": ["Без названия", "Untitled"],
	"SAVE_NAME_PROMPT": ["Название сохранения", "Save name"],
	"SAVE_NEW": ["Новое сохранение", "New save"],
	"SAVE_OVERWRITE": ["Перезаписать", "Overwrite"],
	"SAVE_TITLE": ["Сохранить игру", "Save game"],
	"NO_SAVES": ["Сохранений пока нет", "No saves yet"],
	"CAUGHT_TOTAL": ["Поймано", "Caught"],
	"UNSAVED_WARN": ["Вы не сохранялись больше двух минут.\nВыйти без сохранения?", "You haven't saved for over two minutes.\nQuit without saving?"],
	"SAVE_AND_QUIT": ["Сохранить и выйти", "Save and quit"],
	"QUIT_NO_SAVE": ["Выйти без сохранения", "Quit without saving"],
	"CANCEL": ["Отмена", "Cancel"],
	"RENAME": ["Переименовать", "Rename"],
	"AM": ["дп", "AM"],
	"PM": ["пп", "PM"],
	"YEAR_ONE": ["Первый год", "Year one"],
	"MONTH_spring": ["Месяц цветения", "Month of Blossoms"],
	"WEEKDAY_0": ["Пн", "Mon"], "WEEKDAY_1": ["Вт", "Tue"], "WEEKDAY_2": ["Ср", "Wed"], "WEEKDAY_3": ["Чт", "Thu"], "WEEKDAY_4": ["Пт", "Fri"], "WEEKDAY_5": ["Сб", "Sat"], "WEEKDAY_6": ["Вс", "Sun"],
	"TIME_SPEED_SHORT": ["Время", "Time"],
	"JAR_LOOK": ["Заглянуть в банку", "Look into the jar"],
	"CURRENT_SAVE": ["Текущее", "Current"],
	"INV_TITLE": ["Рюкзак", "Backpack"],
	"HOTBAR": ["Быстрый доступ", "Quick slots"],
	"INV_HINT": ["Кликните по предмету, затем по ячейке, чтобы переложить", "Click an item, then a slot to move it"],
	"IT_lantern": ["Фонарь", "Lantern"], "ITD_lantern": ["Тёплый свет отпугивает тьму и подсвечивает тропу.", "Warm light keeps the dark away and lights the path."],
	"IT_net": ["Сачок", "Net"], "ITD_net": ["С ним ловить светлячков чуть проще: радиус ловли больше.", "Makes catching easier: larger catch radius."],
	"IT_jar": ["Банка", "Jar"], "ITD_jar": ["Стеклянная банка для светлячков. Нажмите I, чтобы заглянуть.", "Glass jar for fireflies. Press I to look inside."],
	"IT_bell": ["Колокольчик", "Bell"], "ITD_bell": ["Его звон привлекает любопытных светлячков.", "Its ring attracts curious fireflies."],
	"IT_crystal": ["Кристалл", "Crystal"], "ITD_crystal": ["Осколок света храма.", "A shard of the temple light."],
	"IT_snack": ["Онигири", "Onigiri"], "ITD_snack": ["Перекус на привале.", "A snack for a rest."],
	"IT_flute": ["Флейта", "Flute"], "ITD_flute": ["Тихая мелодия успокаивает пугливых.", "A quiet tune calms the shy ones."],
	"IT_map": ["Карта", "Map"], "ITD_map": ["Старая карта поляны.", "An old map of the glade."],
	"EMPTY_SLOT": ["Пусто", "Empty"],
	"JAR_TITLE": ["Банка", "Jar"],
	"JAR_EMPTY": ["В банке пока пусто", "The jar is empty"],
	"RELEASE": ["Отпустить", "Release"],
	"CLOSE": ["Закрыть", "Close"],
	"SLOTS": ["слотов", "slots"],
	"JAR_FULL": ["Банка полна…", "The jar is full…"],
	"CAUGHT": ["Пойман!", "Caught!"],
	"HINT_CATCH": ["E — поймать", "E — catch"],
	"PHASE_dawn": ["Рассвет", "Dawn"],
	"PHASE_morning": ["Утро", "Morning"],
	"PHASE_day": ["День", "Day"],
	"PHASE_sunset": ["Закат", "Sunset"],
	"PHASE_evening": ["Вечер", "Evening"],
	"PHASE_night": ["Ночь", "Night"],
	"W_clear": ["Ясно", "Clear"],
	"W_fog": ["Туман", "Fog"],
	"W_rain": ["Дождь", "Rain"],
	"W_storm": ["Гроза", "Storm"],
	"W_snow": ["Снег", "Snow"],
	"W_bloom": ["Цветение", "Bloom"],
	"W_silence": ["Тишина", "Silence"],
	"SEASON_spring": ["Весна", "Spring"],
	"PLACE_glade": ["Поляна", "Glade"],
	"TEMPLE_0": ["Тусклый", "Dim"],
	"TEMPLE_1": ["Тлеющий", "Smoldering"],
	"TEMPLE_2": ["Яркий", "Bright"],
	"TEMPLE_3": ["Сияющий", "Radiant"],
	"TEMPLE_4": ["Солнечный", "Sunlit"],
	"RARITY_common": ["Обычный", "Common"],
	"RARITY_rare": ["Редкий", "Rare"],
	"RARITY_legendary": ["Легендарный", "Legendary"],
	"RARITY": ["Редкость", "Rarity"],
	"EMOTION": ["Эмоция", "Emotion"],
	"ELEMENT": ["Элемент", "Element"],
	"EMO_calm": ["Спокойный", "Calm"],
	"EMO_shy": ["Пугливый", "Shy"],
	"EMO_curious": ["Любопытный", "Curious"],
	"EMO_friendly": ["Дружелюбный", "Friendly"],
	"EMO_secret": ["Скрытный", "Secretive"],
	"EMO_joyful": ["Радостный", "Joyful"],
	"EL_light": ["Свет", "Light"],
	"EL_water": ["Вода", "Water"],
	"EL_leaf": ["Лист", "Leaf"],
	"EL_ember": ["Уголёк", "Ember"],
	"EL_moon": ["Луна", "Moon"],
	"FF_gold": ["Золотой огонёк", "Golden Spark"],
	"FF_blue": ["Синяя капля", "Blue Drop"],
	"FF_green": ["Зелёный лист", "Green Leaf"],
	"FF_red": ["Алый уголёк", "Scarlet Ember"],
	"FF_white": ["Белая луна", "White Moon"],
	"FF_mist": ["Туманный шёпот", "Mist Whisper"],
	"FF_petal": ["Лепесток", "Petal"],
	"FF_star": ["Упавшая звезда", "Fallen Star"],
	"CONTROLS_HINT": ["WASD — идти · E — поймать · 1–5 — предмет · B — рюкзак · I — банка · F1–F3 — время · колесо — зум · Esc — пауза", "WASD — move · E — catch · 1–5 — item · B — backpack · I — jar · F1–F3 — time · wheel — zoom · Esc — pause"],
}

func _install_translations() -> void:
	var ru := Translation.new()
	ru.locale = "ru"
	var en := Translation.new()
	en.locale = "en"
	for key in STRINGS.keys():
		ru.add_message(key, STRINGS[key][0])
		en.add_message(key, STRINGS[key][1])
	TranslationServer.add_translation(ru)
	TranslationServer.add_translation(en)
