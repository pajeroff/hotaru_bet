extends Node
## Процедурный звук: адаптивная музыка (мягкие пады), эмбиент природы и эффекты.
## Всё синтезируется на лету, без внешних файлов.

const SAMPLE_RATE := 16000.0

var _music_player: AudioStreamPlayer
var _music_playback: AudioStreamGeneratorPlayback
var _amb_player: AudioStreamPlayer
var _amb_playback: AudioStreamGeneratorPlayback

var _phase := 0.0
var _chord_t := 0.0
var _chord_idx := 0
var _mood := "menu" # menu, day, night, fog, rain, silence
var _target_gain := 0.6
var _gain := 0.0
var _amb_mode := "none" # none, wind, rain, snow, silence
var _amb_gain := 0.0
var _amb_target := 0.0
var _rain_lp := 0.0
var _wind_lp := 0.0
var _wind_mod := 0.0
var _whisper_t := 0.0
var _bird_t := 0.0
var _bird_freq := 0.0
var _bird_len := 0.0
var _noise_state := 12345
var _voices: Array = [] # [freq, phase, amp]

# Пентатонические, мягкие аккорды (Гц)
const CHORDS_DAY := [[261.63, 329.63, 392.0, 587.33], [220.0, 293.66, 349.23, 523.25], [196.0, 293.66, 392.0, 493.88], [174.61, 261.63, 349.23, 440.0]]
const CHORDS_NIGHT := [[220.0, 261.63, 329.63, 493.88], [174.61, 220.0, 329.63, 440.0], [196.0, 246.94, 293.66, 392.0], [164.81, 220.0, 261.63, 392.0]]

var _sfx_cache := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.25
	_music_player.stream = gen
	_music_player.bus = "Music"
	add_child(_music_player)
	_music_player.play()
	_music_playback = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback

	_amb_player = AudioStreamPlayer.new()
	var gen2 := AudioStreamGenerator.new()
	gen2.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	gen2.mix_rate = SAMPLE_RATE
	gen2.buffer_length = 0.25
	_amb_player.stream = gen2
	_amb_player.bus = "SFX"
	add_child(_amb_player)
	_amb_player.play()
	_amb_playback = _amb_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_set_chord(CHORDS_DAY[0])

func _process(_delta: float) -> void:
	if _music_playback == null and _music_player.playing:
		_music_playback = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _amb_playback == null and _amb_player.playing:
		_amb_playback = _amb_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_fill_music()
	_fill_ambient()

# ---------- Музыка ----------

func set_mood(mood: String) -> void:
	if mood == _mood:
		return
	_mood = mood
	_target_gain = 0.0 if mood == "silence" else (0.35 if mood == "menu" else 0.45)

func _set_chord(freqs: Array) -> void:
	_voices.clear()
	for f in freqs:
		_voices.append([f, randf() * TAU, 0.0])

func _fill_music() -> void:
	if _music_playback == null:
		return
	var frames := _music_playback.get_frames_available()
	if frames <= 0:
		return
	var chords: Array = CHORDS_NIGHT if (_mood == "night" or _mood == "fog") else CHORDS_DAY
	var chord_len := 9.0 if _mood != "rain" else 7.0
	var buf := PackedVector2Array()
	buf.resize(frames)
	var dt := 1.0 / SAMPLE_RATE
	for i in range(frames):
		_chord_t += dt
		if _chord_t >= chord_len:
			_chord_t = 0.0
			_chord_idx = (_chord_idx + 1) % chords.size()
			_set_chord(chords[_chord_idx])
		# огибающая аккорда: мягкий вход и выход
		var env := smoothstep(0.0, 2.5, _chord_t) * (1.0 - smoothstep(chord_len - 2.5, chord_len, _chord_t))
		_gain = lerpf(_gain, _target_gain, dt * 0.4)
		var s := 0.0
		var vi := 0
		for v in _voices:
			v[1] += TAU * v[0] * dt
			var vib := sin(_phase * 0.7 + vi) * 0.002
			var tone := sin(v[1] * (1.0 + vib)) + 0.35 * sin(v[1] * 2.0) * 0.5 + 0.12 * sin(v[1] * 3.0)
			s += tone * (0.22 - vi * 0.03)
			vi += 1
		_phase += dt
		var slow := 0.85 + 0.15 * sin(_phase * 0.31)
		var out := s * env * _gain * slow * 0.5
		# Лёгкое стерео
		buf[i] = Vector2(out * (1.0 + 0.1 * sin(_phase * 0.2)), out * (1.0 - 0.1 * sin(_phase * 0.2)))
	_music_playback.push_buffer(buf)

# ---------- Эмбиент ----------

func set_ambient(mode: String, target_gain := 0.5) -> void:
	_amb_mode = mode
	_amb_target = target_gain

func _noise() -> float:
	_noise_state = (_noise_state * 1103515245 + 12345) & 0x7fffffff
	return float(_noise_state) / float(0x7fffffff) * 2.0 - 1.0

func _fill_ambient() -> void:
	if _amb_playback == null:
		return
	var frames := _amb_playback.get_frames_available()
	if frames <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(frames)
	var dt := 1.0 / SAMPLE_RATE
	for i in range(frames):
		_amb_gain = lerpf(_amb_gain, _amb_target, dt * 0.5)
		var n := _noise()
		var out := 0.0
		match _amb_mode:
			"wind", "snow", "bloom", "fog":
				_wind_mod += dt
				var gust := 0.5 + 0.5 * sin(_wind_mod * 0.23) * sin(_wind_mod * 0.071 + 1.0)
				_wind_lp += (n - _wind_lp) * (0.02 if _amb_mode == "snow" else 0.05)
				out = _wind_lp * (0.35 + 0.65 * gust) * 1.6
				if _amb_mode == "fog":
					# далёкий шёпот: модулированный шум
					_whisper_t += dt
					var w := sin(_whisper_t * 3.1) * sin(_whisper_t * 0.37)
					out += _wind_lp * maxf(w, 0.0) * 1.2
				# птицы днём (короткие чирики)
				if _amb_mode == "wind":
					_bird_t -= dt
					if _bird_t <= 0.0:
						_bird_t = randf_range(2.0, 7.0)
						_bird_freq = randf_range(2200.0, 3400.0)
						_bird_len = randf_range(0.08, 0.2)
					if _bird_len > 0.0:
						_bird_len -= dt
						out += sin(_phase * 0.0 + _wind_mod * TAU * _bird_freq * (1.0 + sin(_wind_mod * 60.0) * 0.03)) * 0.05 * minf(_bird_len * 10.0, 1.0)
			"rain", "storm":
				_rain_lp += (n - _rain_lp) * 0.35
				out = _rain_lp * 0.5 + n * 0.08
				_wind_mod += dt
				out *= 0.8 + 0.2 * sin(_wind_mod * 0.5)
			"silence":
				_wind_lp += (n - _wind_lp) * 0.01
				out = _wind_lp * 0.3
			_:
				out = 0.0
		out *= _amb_gain
		buf[i] = Vector2(out, out)
	_amb_playback.push_buffer(buf)

# ---------- Эффекты ----------

func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(SAMPLE_RATE)
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	wav.data = bytes
	return wav

func _synth(kind: String) -> AudioStreamWAV:
	if _sfx_cache.has(kind):
		return _sfx_cache[kind]
	var n := int(SAMPLE_RATE * 1.2)
	var s := PackedFloat32Array()
	s.resize(n)
	var dt := 1.0 / SAMPLE_RATE
	for i in range(n):
		var t := i * dt
		var v := 0.0
		match kind:
			"chime": # ловля: звон
				v = sin(TAU * 1318.5 * t) * exp(-t * 4.0) * 0.5 + sin(TAU * 1975.5 * t) * exp(-t * 6.0) * 0.3 + sin(TAU * 2637.0 * t) * exp(-t * 9.0) * 0.15
			"release": # отпускание: поднимающийся мягкий тон
				var f := 660.0 + 500.0 * t
				v = sin(TAU * f * t) * exp(-t * 3.0) * 0.4
			"hover":
				v = sin(TAU * 880.0 * t) * exp(-t * 30.0) * 0.15
			"click":
				v = sin(TAU * 523.25 * t) * exp(-t * 14.0) * 0.3 + sin(TAU * 784.0 * t) * exp(-t * 18.0) * 0.2
			"step":
				var nz := _noise()
				v = nz * exp(-t * 40.0) * 0.18
			"save":
				v = (sin(TAU * 523.25 * t) * exp(-t * 5.0) + sin(TAU * 659.25 * maxf(t - 0.12, 0.0)) * exp(-maxf(t - 0.12, 0.0) * 5.0) * float(t > 0.12)) * 0.25
			"thunder":
				var nz2 := _noise()
				_rain_lp += (nz2 - _rain_lp) * 0.02
				v = _rain_lp * exp(-t * 1.5) * 2.5
			"lantern":
				v = sin(TAU * 440.0 * t) * exp(-t * 20.0) * 0.2
			"open":
				v = sin(TAU * (392.0 + 200.0 * t) * t) * exp(-t * 8.0) * 0.2
		s[i] = v
	var wav := _make_wav(s)
	_sfx_cache[kind] = wav
	return wav

func play_sfx(kind: String, volume_db := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _synth(kind)
	p.bus = "SFX"
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
