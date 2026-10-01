extends RefCounted
## Small UI construction helpers shared by title / clinic / ending.


static func nebula(parent: Node, dim := 1.0) -> ColorRect:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/nebula.gdshader")
	if dim < 1.0:
		m.set_shader_parameter("c2", Color(0.32, 0.12, 0.40) * dim)
		m.set_shader_parameter("c3", Color(0.95, 0.55, 0.75) * dim)
	bg.material = m
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	return bg


static func label(parent: Node, text: String, size := 24, color := Color(0.95, 0.93, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


static func rich(parent: Node, text: String, min_size := Vector2.ZERO) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = min_size
	r.text = text
	r.add_theme_constant_override("line_separation", 5)
	parent.add_child(r)
	return r


static func button(parent: Node, text: String, cb: Callable, min_size := Vector2(0, 52)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(func(): Audio.sfx("click"))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


static func portrait(parent: Node, name: String, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load("res://assets/portraits/%s.png" % name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = size
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(t)
	return t


## A 1280x720 design-space container centred on screen. Title / clinic /
## ending lay their content out inside it, so wide phones (20:9), 4:3 tablets
## and ultrawide monitors all get a centred layout; backgrounds stay full-screen.
static func stage(parent: Control) -> Control:
	var s := Control.new()
	s.anchor_left = 0.5
	s.anchor_right = 0.5
	s.anchor_top = 0.5
	s.anchor_bottom = 0.5
	s.offset_left = -640
	s.offset_right = 640
	s.offset_top = -360
	s.offset_bottom = 360
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)
	return s


## A small ✕ button pinned to the top-right corner of a panel (mouse & touch).
static func close_button(panel: Control, cb: Callable) -> Button:
	var b := Button.new()
	b.text = "×"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(56, 56)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = -60
	b.offset_right = -4
	b.offset_top = 4
	b.offset_bottom = 60
	b.pressed.connect(func(): Audio.sfx("click"))
	b.pressed.connect(cb)
	# PanelContainer would stretch a direct child; wrap it in a free Control
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(b)
	panel.add_child(holder)
	return b


## Settings used by both the title screen and the in-dream pause menu.
static func settings_box(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	parent.add_child(v)

	if not Plat.is_mobile:
		var fs := CheckButton.new()
		fs.text = "全屏（F11 / Alt+Enter）"
		fs.button_pressed = Plat.fullscreen
		fs.toggled.connect(func(on: bool): Plat.set_fullscreen(on))
		v.add_child(fs)

	var th := HBoxContainer.new()
	v.add_child(th)
	var tl := Label.new()
	tl.text = "触屏按键"
	tl.custom_minimum_size = Vector2(150, 0)
	th.add_child(tl)
	var opt := OptionButton.new()
	opt.add_item("自动（触摸时显示）", 0)
	opt.add_item("总是显示", 1)
	opt.add_item("隐藏", 2)
	opt.selected = ["auto", "on", "off"].find(Plat.touch_pref)
	opt.custom_minimum_size = Vector2(280, 48)
	opt.item_selected.connect(func(i: int): Plat.set_touch_pref(["auto", "on", "off"][i]))
	th.add_child(opt)

	var vt := CheckButton.new()
	vt.text = "角色语音"
	vt.button_pressed = GS.settings["voice"]
	vt.toggled.connect(_set_voice)
	v.add_child(vt)

	var mh := HBoxContainer.new()
	v.add_child(mh)
	var ml := Label.new()
	ml.text = "音乐音量"
	ml.custom_minimum_size = Vector2(150, 0)
	mh.add_child(ml)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = GS.settings["music_volume"]
	sl.custom_minimum_size = Vector2(280, 40)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.value_changed.connect(func(x: float): Audio.set_music_volume(x))
	sl.drag_ended.connect(func(_c: bool): Plat.save_settings())
	mh.add_child(sl)

	var ut := CheckButton.new()
	ut.text = "解锁全部梦境（测试用）"
	ut.button_pressed = bool(GS.settings.get("unlock_all", false))
	ut.toggled.connect(_set_unlock)
	v.add_child(ut)

	# live AI narration: several vendors / custom endpoints (see ai_panel.gd)
	var ah := HBoxContainer.new()
	ah.add_theme_constant_override("separation", 10)
	v.add_child(ah)
	var al := Label.new()
	al.text = "AI 叙事"
	al.custom_minimum_size = Vector2(150, 0)
	ah.add_child(al)
	var st := Label.new()
	st.text = AI.status_text()
	st.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	st.custom_minimum_size = Vector2(430, 0)
	st.modulate = Color(0.5, 0.95, 1.0, 0.8)
	var ab := Button.new()
	ab.text = "AI 接口设置…（多厂商 / 自定义）"
	ab.custom_minimum_size = Vector2(280, 48)
	ab.pressed.connect(_open_ai.bind(v, st))
	ah.add_child(ab)
	v.add_child(st)
	return v


static func _open_ai(parent: Node, status: Label) -> void:
	var panel = load("res://scripts/ai_panel.gd").new()
	parent.add_child(panel)
	panel.closed.connect(func(): status.text = AI.status_text())


static func _set_voice(on: bool) -> void:
	GS.settings["voice"] = on
	Plat.save_settings()


static func _set_unlock(on: bool) -> void:
	GS.settings["unlock_all"] = on
	Plat.save_settings()
