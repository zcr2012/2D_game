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
