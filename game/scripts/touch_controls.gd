extends CanvasLayer
## On-screen controls for phones / tablets / touch laptops.
##
##  * floating joystick: touch anywhere on the left 45% of the screen
##  * round buttons on the right: 互动 (big), 编辑, 小眠, 碎片
##  * 菜单 button in the top-right corner
##
## Everything is multi-touch (walk with one thumb, press with the other) and
## drives the same input actions as the keyboard, so game code does not need
## to know where the input came from.

const STICK_RADIUS := 78.0
const KNOB_RADIUS := 34.0
const STICK_ZONE := 0.45          # left fraction of the screen that spawns the stick

var dream = null

var _stick_idx := -1
var _stick_origin := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _home := Vector2.ZERO         # where the idle stick hint is drawn
var _buttons: Array = []          # [{action, label, radius, pos, idx, node}]
var _canvas: Node2D
var _margin := Rect2()


func _ready() -> void:
	layer = 20
	_canvas = Node2D.new()
	add_child(_canvas)
	_canvas.draw.connect(_draw_controls)
	_add_button("interact", "互动", 66.0)
	_add_button("editor", "编辑", 46.0)
	_add_button("ask_xm", "小眠", 42.0)
	_add_button("fragments", "碎片", 38.0)
	_add_button("pause", "菜单", 34.0)
	get_viewport().size_changed.connect(layout)
	Plat.input_mode_changed.connect(_on_mode_changed)
	layout()
	_refresh_visibility()


func _add_button(action: String, text: String, radius: float) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 36 if radius > 60.0 else 24)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.2))
	l.add_theme_constant_override("outline_size", 6)
	l.size = Vector2(radius * 2.0, radius * 2.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	_buttons.append({"action": action, "label": text, "radius": radius, "pos": Vector2.ZERO, "idx": -1, "node": l})


## Positions everything relative to the current (possibly non-16:9) screen
## and the device safe area.
func layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	_margin = Plat.safe_margins(get_viewport())
	var right := vs.x - _margin.size.x - 28.0
	var bottom := vs.y - _margin.size.y - 28.0
	var pos := {
		"interact": Vector2(right - 66.0, bottom - 66.0),
		"editor": Vector2(right - 66.0, bottom - 66.0 - 130.0),
		"ask_xm": Vector2(right - 66.0 - 128.0, bottom - 36.0),
		"fragments": Vector2(right - 66.0 - 118.0, bottom - 66.0 - 108.0),
		"pause": Vector2(right - 34.0, _margin.position.y + 150.0),
	}
	for b in _buttons:
		b["pos"] = pos[b["action"]]
		var l: Label = b["node"]
		l.position = b["pos"] - l.size / 2.0
	_home = Vector2(_margin.position.x + 150.0, bottom - 110.0)
	_canvas.queue_redraw()


## Screen rectangles of all buttons (used by the layout test).
func button_rects() -> Dictionary:
	var out := {}
	for b in _buttons:
		var r: float = b["radius"]
		out[b["action"]] = Rect2(b["pos"] - Vector2(r, r), Vector2(r, r) * 2.0)
	out["stick"] = Rect2(_home - Vector2(STICK_RADIUS, STICK_RADIUS), Vector2(STICK_RADIUS, STICK_RADIUS) * 2.0)
	return out


func _on_mode_changed(_m: String) -> void:
	_refresh_visibility()


func _wanted() -> bool:
	if not Plat.touch_ui():
		return false
	if dream == null:
		return true
	return dream.can_player_act()


func _refresh_visibility() -> void:
	var want := _wanted()
	if visible != want:
		visible = want
		if not want:
			_release_all()


func _process(_delta: float) -> void:
	_refresh_visibility()
	if visible:
		_canvas.queue_redraw()


# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			var b = _button_at(st.position)
			if b != null and b["idx"] == -1:
				b["idx"] = st.index
				_press(b)
				get_viewport().set_input_as_handled()
			elif _stick_idx == -1 and st.position.x < get_viewport().get_visible_rect().size.x * STICK_ZONE:
				_stick_idx = st.index
				_stick_origin = _clamp_origin(st.position)
				_stick_knob = st.position
				_update_stick()
				get_viewport().set_input_as_handled()
		else:
			if st.index == _stick_idx:
				_release_stick()
				get_viewport().set_input_as_handled()
			for b in _buttons:
				if b["idx"] == st.index:
					b["idx"] = -1
					get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _stick_idx:
			_stick_knob = sd.position
			_update_stick()
			get_viewport().set_input_as_handled()


func _button_at(p: Vector2):
	for b in _buttons:
		# generous hit area (+14 px) for thumbs
		if p.distance_to(b["pos"]) <= b["radius"] + 14.0:
			return b
	return null


func _press(b: Dictionary) -> void:
	Plat.press_action(str(b["action"]))
	if Plat.is_mobile:
		Input.vibrate_handheld(18)


func _clamp_origin(p: Vector2) -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	return Vector2(clampf(p.x, STICK_RADIUS + 8.0, vs.x - STICK_RADIUS - 8.0),
		clampf(p.y, STICK_RADIUS + 8.0, vs.y - STICK_RADIUS - 8.0))


func _update_stick() -> void:
	var d := _stick_knob - _stick_origin
	if d.length() > STICK_RADIUS:
		# drag the base along, so the thumb never "falls off" the stick
		_stick_origin = _stick_knob - d.normalized() * STICK_RADIUS
		d = _stick_knob - _stick_origin
	var v := d / STICK_RADIUS
	if v.length() < 0.18:
		v = Vector2.ZERO
	_stick_vec = v
	_set_axis("move_left", "move_right", v.x)
	_set_axis("move_up", "move_down", v.y)


func _set_axis(neg: String, pos: String, value: float) -> void:
	if value < -0.05:
		Input.action_press(neg, minf(1.0, -value))
		Input.action_release(pos)
	elif value > 0.05:
		Input.action_press(pos, minf(1.0, value))
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _release_stick() -> void:
	_stick_idx = -1
	_stick_vec = Vector2.ZERO
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func _release_all() -> void:
	_release_stick()
	for b in _buttons:
		b["idx"] = -1


func stick_vector() -> Vector2:
	return _stick_vec


# ------------------------------------------------------------------ drawing
func _draw_controls() -> void:
	var near := false
	if dream != null and dream.has_method("_nearest_interactable"):
		near = dream._nearest_interactable() != null
	# joystick
	if _stick_idx >= 0:
		_canvas.draw_circle(_stick_origin, STICK_RADIUS, Color(0.1, 0.05, 0.2, 0.35))
		_canvas.draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 48, Color(0.5, 0.95, 1.0, 0.6), 3.0)
		_canvas.draw_circle(_stick_origin + _stick_vec * STICK_RADIUS, KNOB_RADIUS, Color(0.5, 0.95, 1.0, 0.55))
	else:
		_canvas.draw_arc(_home, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.18), 3.0)
		_canvas.draw_circle(_home, KNOB_RADIUS, Color(1, 1, 1, 0.12))
	# buttons
	for b in _buttons:
		var p: Vector2 = b["pos"]
		var r: float = b["radius"]
		var pressed: bool = b["idx"] >= 0
		var fill := Color(0.12, 0.06, 0.24, 0.45)
		var ring := Color(1.0, 0.8, 0.9, 0.55)
		if b["action"] == "interact":
			if near:
				var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
				fill = Color(0.5, 0.95, 1.0, 0.3 + 0.2 * pulse)
				ring = Color(0.5, 0.95, 1.0, 0.95)
			else:
				ring = Color(1, 1, 1, 0.3)
		if pressed:
			fill = Color(1.0, 0.8, 0.9, 0.55)
		_canvas.draw_circle(p, r, fill)
		_canvas.draw_arc(p, r, 0.0, TAU, 40, ring, 3.0)
		var l: Label = b["node"]
		l.modulate = Color(1, 1, 1, 1.0 if (b["action"] != "interact" or near) else 0.55)
