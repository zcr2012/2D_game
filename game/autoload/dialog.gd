extends CanvasLayer
## Dialog — portrait dialogue box usable from any scene with await:
##   await Dialog.say("xm", "你好")
##   var i: int = await Dialog.choose("tx", "选择？", ["A", {"text": "B", "disabled": true}])
##   var s: String = await Dialog.ask_text("tx", "问点什么？", "输入…")

signal advanced
signal chosen(index: int)
signal input_done(text: String)

const SPEAKERS := {
	"xm": {"name": "小眠", "portrait": "xiaomian", "color": Color(0.5, 0.95, 1.0), "pitch": 1.6},
	"tx": {"name": "糖心", "portrait": "tangxin", "color": Color(1.0, 0.62, 0.9), "pitch": 0.8},
	"dd": {"name": "朵朵", "portrait": "duoduo", "color": Color(1.0, 0.78, 0.84), "pitch": 1.35},
	"bear": {"name": "熊先生", "portrait": "bear", "color": Color(0.95, 0.75, 0.5), "pitch": 0.7},
	"sy": {"name": "沈远", "portrait": "shenyuan", "color": Color(0.95, 0.82, 0.62), "pitch": 0.75},
	"ld": {"name": "老灯", "portrait": "laodeng", "color": Color(1.0, 0.85, 0.45), "pitch": 0.6},
	"fb": {"name": "福伯", "portrait": "fubo", "color": Color(0.9, 0.8, 0.7), "pitch": 0.85},
	"sw": {"name": "苏晚", "portrait": "suwan", "color": Color(0.75, 0.8, 1.0), "pitch": 1.15},
	"np": {"name": "路人", "portrait": "", "color": Color(0.75, 0.75, 0.8), "pitch": 0.9},
	"me": {"name": "你", "portrait": "player", "color": Color(0.7, 0.85, 1.0), "pitch": 1.0},
	"sys": {"name": "", "portrait": "", "color": Color(0.8, 0.8, 0.9), "pitch": 1.0},
	"file": {"name": "档案", "portrait": "", "color": Color(1.0, 0.9, 0.55), "pitch": 1.0},
}

var active := false
## Test harness support: when true, lines auto-advance, choices are taken
## from autoplay_choices (or the first enabled option) and text input from
## autoplay_inputs. Everything is printed as a transcript.
var autoplay := false
var autoplay_choices: Array = []
var autoplay_inputs: Array = []
var mode := ""            # "say" | "choose" | "input"
var _typing := false
var _chars := 0.0
var _opened_at := 0
var _has_voice := false
var _pending_close := false

var _root: Control
var _panel: PanelContainer
var _portrait: TextureRect
var _portrait_box: Control
var _name: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _line: LineEdit
var _input_row: HBoxContainer
var _more: Label


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 36
	_panel.offset_right = -36
	_panel.offset_top = -236
	_panel.offset_bottom = -18
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	_panel.add_child(hb)

	_portrait_box = Control.new()
	_portrait_box.custom_minimum_size = Vector2(190, 190)
	hb.add_child(_portrait_box)
	_portrait = TextureRect.new()
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_portrait_box.add_child(_portrait)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	hb.add_child(vb)

	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 24)
	vb.add_child(_name)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0, 60)
	_text.add_theme_font_size_override("normal_font_size", 24)
	_text.add_theme_font_size_override("bold_font_size", 24)
	_text.add_theme_constant_override("line_separation", 6)
	vb.add_child(_text)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 4)
	vb.add_child(_choices)

	_input_row = HBoxContainer.new()
	_input_row.add_theme_constant_override("separation", 8)
	_input_row.visible = false
	vb.add_child(_input_row)
	_line = LineEdit.new()
	_line.add_theme_font_size_override("font_size", 24)
	_line.max_length = 60
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line.custom_minimum_size = Vector2(0, 52)
	_line.virtual_keyboard_enabled = true
	_line.text_submitted.connect(_on_line_submitted)
	_input_row.add_child(_line)
	var send := Button.new()
	send.text = "发送"
	send.custom_minimum_size = Vector2(110, 52)
	send.focus_mode = Control.FOCUS_NONE
	send.pressed.connect(_on_send_pressed)
	_input_row.add_child(send)
	var skip := Button.new()
	skip.text = "跳过"
	skip.custom_minimum_size = Vector2(110, 52)
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(_on_skip_pressed)
	_input_row.add_child(skip)

	_more = Label.new()
	_more.text = "▼"
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more.modulate = Color(0.5, 0.95, 1.0)
	vb.add_child(_more)

	_panel.visible = false
	get_viewport().size_changed.connect(_layout)
	_layout()


## Safe area + (while typing on a phone) lift the box above the virtual keyboard.
func _layout() -> void:
	var m := Plat.safe_margins(get_viewport())
	var kb := 0.0
	if mode == "input" and Plat.is_mobile:
		kb = Plat.window_to_canvas(float(DisplayServer.virtual_keyboard_get_height()))
	_root.offset_left = m.position.x
	_root.offset_top = m.position.y
	_root.offset_right = -m.size.x
	_root.offset_bottom = -maxf(m.size.y, kb)


# ------------------------------------------------------------------ public
func say(who: String, text: String, voice := "") -> void:
	if autoplay:
		print("  [%s] %s%s" % [who, text.replace("\n", " / "), ("  (voice:%s %s)" % [voice, "ok" if ResourceLoader.exists("res://assets/audio/voice/%s.mp3" % voice) else "MISSING"]) if voice != "" else ""])
		await get_tree().process_frame
		return
	mode = "say"
	_set_text(text)
	_has_voice = Audio.voice(voice)
	await advanced
	Audio.stop_voice()
	_schedule_close()


func choose(who: String, text: String, options: Array) -> int:
	if autoplay:
		var pick := -1
		if autoplay_choices.size() > 0:
			pick = int(autoplay_choices.pop_front())
		var labels: Array = []
		for o in options:
			labels.append(str(o.get("text", "")) + (" [disabled]" if o.get("disabled", false) else "") if o is Dictionary else str(o))
		if pick < 0 or pick >= options.size() or (options[pick] is Dictionary and options[pick].get("disabled", false)):
			pick = 0
		print("  [%s] %s  -> choose %d: %s   (options: %s)" % [who, text, pick, labels[pick], " | ".join(labels)])
		await get_tree().process_frame
		return pick
	mode = "choose"
	_set_text(text)
	_finish_typing()
	var first: Button = null
	for i in options.size():
		var o = options[i]
		var label := ""
		var disabled := false
		if o is Dictionary:
			label = str(o.get("text", ""))
			disabled = bool(o.get("disabled", false))
		else:
			label = str(o)
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, label]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = disabled
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_on_choice.bind(i))
		b.mouse_entered.connect(_hover_focus.bind(b))
		_choices.add_child(b)
		if first == null and not disabled:
			first = b
	_more.visible = false
	_grow_for_choices(options.size())
	if first:
		first.call_deferred("grab_focus")
	var idx: int = await chosen
	Audio.sfx("click")
	for c in _choices.get_children():
		c.queue_free()
	_shrink()
	_schedule_close()
	return idx


func ask_text(who: String, text: String, placeholder := "") -> String:
	if autoplay:
		var ans := str(autoplay_inputs.pop_front()) if autoplay_inputs.size() > 0 else ""
		print("  [%s] %s  -> input: %s" % [who, text, ans])
		await get_tree().process_frame
		return ans
	mode = "input"
	_set_text(text)
	_finish_typing()
	_input_row.visible = true
	_line.text = ""
	_line.placeholder_text = placeholder
	_more.visible = false
	_line.call_deferred("grab_focus")
	var s: String = await input_done
	_input_row.visible = false
	_line.release_focus()
	DisplayServer.virtual_keyboard_hide()
	_layout()
	_schedule_close()
	return s.strip_edges()


## Short non-blocking bubble-less line (used for hints while exploring)
func is_busy() -> bool:
	return active


# ------------------------------------------------------------------ internals
func _open(who: String) -> void:
	_pending_close = false
	active = true
	_panel.visible = true
	_opened_at = Time.get_ticks_msec()
	var sp: Dictionary = SPEAKERS.get(who, SPEAKERS["sys"])
	_name.text = sp["name"]
	_name.modulate = sp["color"]
	_name.visible = sp["name"] != ""
	var p: String = sp["portrait"]
	if p != "":
		_portrait.texture = load("res://assets/portraits/%s.png" % p)
		_portrait_box.visible = true
	else:
		_portrait.texture = null
		_portrait_box.visible = false
	_blip_pitch = sp["pitch"]
	_more.visible = true


var _blip_pitch := 1.0


func _set_text(text: String) -> void:
	_text.text = text
	_text.visible_characters = 0
	_chars = 0.0
	_typing = true


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1


func _schedule_close() -> void:
	_pending_close = true
	call_deferred("_try_close")


func _try_close() -> void:
	if _pending_close:
		_pending_close = false
		active = false
		mode = ""
		_panel.visible = false


func _grow_for_choices(n: int) -> void:
	_panel.offset_top = -236 - n * 44


func _shrink() -> void:
	_panel.offset_top = -236


func _process(delta: float) -> void:
	if not active:
		return
	if mode == "input" and Plat.is_mobile:
		_layout()
	if _typing:
		var total := _text.get_total_character_count()
		var before := int(_chars)
		_chars += delta * 38.0
		_text.visible_characters = int(_chars)
		if not _has_voice and int(_chars) / 3 != before / 3:
			Audio.sfx("blip", _blip_pitch * randf_range(0.95, 1.05), -8.0)
		if int(_chars) >= total:
			_finish_typing()
	_more.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)


func _input(event: InputEvent) -> void:
	if not active:
		return
	if mode == "input":
		if event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			input_done.emit("")
		return
	if mode == "choose":
		var ke := event as InputEventKey
		if ke and ke.pressed and not ke.echo:
			var k: int = ke.keycode
			if k >= KEY_1 and k <= KEY_9:
				var i := k - KEY_1
				if i < _choices.get_child_count():
					var b := _choices.get_child(i) as Button
					if b and not b.disabled:
						get_viewport().set_input_as_handled()
						chosen.emit(i)
		return
	if mode == "say":
		var adv := event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
		var mb := event as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			adv = true
		if adv:
			get_viewport().set_input_as_handled()
			if Time.get_ticks_msec() - _opened_at < 120:
				return
			if _typing:
				_finish_typing()
			else:
				advanced.emit()


func _hover_focus(b: Button) -> void:
	if not b.disabled:
		b.grab_focus()


func _on_choice(i: int) -> void:
	if mode == "choose":
		chosen.emit(i)


func _on_send_pressed() -> void:
	_on_line_submitted(_line.text)


func _on_skip_pressed() -> void:
	if mode == "input":
		input_done.emit("")


func _on_line_submitted(t: String) -> void:
	if mode == "input":
		input_done.emit(t)
