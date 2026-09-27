extends Node
## Audio — music (cross-faded loops), sfx pool, voice lines, ambient rain.

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music := ""
var _voice: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = _make_player(-80.0)
	_music_b = _make_player(-80.0)
	_voice = _make_player(0.0)
	_rain = _make_player(-80.0)
	for i in 8:
		_sfx.append(_make_player(-4.0))


func _make_player(db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	add_child(p)
	return p


func _load(path: String, loop := false) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	if loop and s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	elif loop and s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	_cache[path] = s
	return s


func music(name: String, fade := 1.2) -> void:
	if name == _current_music:
		return
	_current_music = name
	var stream: AudioStream = null
	if name != "":
		stream = _load("res://assets/audio/music/%s.wav" % name, true)
	var old := _music_a
	var nw := _music_b
	_music_a = nw
	_music_b = old
	var target_db := linear_to_db(max(0.001, GS.settings.get("music_volume", 0.7))) - 6.0
	if stream:
		nw.stream = stream
		nw.volume_db = -60.0
		nw.play()
		create_tween().tween_property(nw, "volume_db", target_db, fade)
	var t := create_tween()
	t.tween_property(old, "volume_db", -60.0, fade)
	t.tween_callback(old.stop)


func sfx(name: String, pitch := 1.0, db := 0.0) -> void:
	var s := _load("res://assets/audio/sfx/%s.wav" % name)
	if s == null:
		return
	for p in _sfx:
		if not p.playing:
			p.stream = s
			p.pitch_scale = pitch
			p.volume_db = -4.0 + db
			p.play()
			return


## Plays a voice clip (res://assets/audio/voice/<id>.mp3). Returns true if found.
func voice(id: String) -> bool:
	if id == "" or not GS.settings.get("voice", true):
		return false
	var s := _load("res://assets/audio/voice/%s.mp3" % id)
	if s == null:
		return false
	_voice.stream = s
	_voice.play()
	return true


func stop_voice() -> void:
	_voice.stop()


func voice_playing() -> bool:
	return _voice.playing


func rain(on: bool) -> void:
	if on and not _rain.playing:
		_rain.stream = _load("res://assets/audio/sfx/rain.wav", true)
		_rain.volume_db = -40.0
		_rain.play()
		create_tween().tween_property(_rain, "volume_db", -10.0, 1.0)
	elif not on and _rain.playing:
		var t := create_tween()
		t.tween_property(_rain, "volume_db", -60.0, 1.0)
		t.tween_callback(_rain.stop)
