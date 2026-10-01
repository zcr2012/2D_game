extends CanvasLayer
## In-dream HUD: status, objective, interaction prompt, toasts,
## the Dream Editor (time / emotion / reality), fragment journal, pause menu.

const EMO_COLORS := {
	"emo_joy": Color(1.0, 0.86, 0.3), "emo_sad": Color(0.45, 0.7, 1.0),
	"emo_anger": Color(1.0, 0.35, 0.35), "emo_fear": Color(0.7, 0.45, 1.0),
	"emo_regret": Color(0.55, 0.9, 0.8),
	"st_joy": Color(1.0, 0.86, 0.3), "st_sad": Color(0.45, 0.7, 1.0),
	"st_anger": Color(1.0, 0.35, 0.35), "st_fear": Color(0.7, 0.45, 1.0),
	"st_regret": Color(0.55, 0.9, 0.8),
}

const U := preload("res://scripts/ui_util.gd")

var dream = null

var _title: Label
var _stab_bar: ProgressBar
var _stab_label: Label
var _objective: Label
var _state_label: Label
var _trait_label: Label
var _frag_label: Label
var _prompt: Label
var _toasts: VBoxContainer
var _ai_label: Label

var editor: PanelContainer
var _ed_rows := {}
var _ed_desc: RichTextLabel
var _ed_stab: Label
var fragments_panel: PanelContainer
var _frag_list: GridContainer
var pause_panel: PanelContainer
var settings_panel: PanelContainer
var _root: Control
var _hint: Label
var _ed_footer: Label
var _frag_footer: Label


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root

	# ---- top-left status
	var tl := PanelContainer.new()
	tl.position = Vector2(14, 12)
	tl.custom_minimum_size = Vector2(430, 0)
	root.add_child(tl)
	var tlv := VBoxContainer.new()
	tlv.add_theme_constant_override("separation", 4)
	tl.add_child(tlv)
	_title = Label.new()
	tlv.add_child(_title)
	var sh := HBoxContainer.new()
	tlv.add_child(sh)
	var sl := Label.new()
	sl.text = "稳定度"
	sl.modulate = Color(0.7, 0.9, 1.0)
	sh.add_child(sl)
	_stab_bar = ProgressBar.new()
	_stab_bar.custom_minimum_size = Vector2(240, 18)
	_stab_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stab_bar.show_percentage = false
	_stab_bar.max_value = 100
	sh.add_child(_stab_bar)
	_stab_label = Label.new()
	sh.add_child(_stab_label)
	_objective = Label.new()
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(400, 0)
	_objective.modulate = Color(1.0, 0.92, 0.6)
	tlv.add_child(_objective)

	# ---- top-right state
	var tr := PanelContainer.new()
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.offset_left = -400
	tr.offset_right = -14
	tr.offset_top = 12
	root.add_child(tr)
	var trv := VBoxContainer.new()
	tr.add_child(trv)
	_state_label = Label.new()
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trv.add_child(_state_label)
	_trait_label = Label.new()
	_trait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_trait_label.modulate = Color(0.5, 0.95, 1.0)
	trv.add_child(_trait_label)
	_frag_label = Label.new()
	_frag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_frag_label.modulate = Color(1.0, 0.8, 0.9)
	trv.add_child(_frag_label)

	# ---- bottom hints
	var hint := Label.new()
	_hint = hint
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 16
	hint.offset_top = -34
	hint.modulate = Color(1, 1, 1, 0.65)
	root.add_child(hint)

	_ai_label = Label.new()
	_ai_label.anchor_left = 1.0
	_ai_label.anchor_right = 1.0
	_ai_label.anchor_top = 1.0
	_ai_label.anchor_bottom = 1.0
	_ai_label.offset_left = -520
	_ai_label.offset_right = -16
	_ai_label.offset_top = -34
	_ai_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ai_label.modulate = Color(0.5, 0.95, 1.0, 0.6)
	_ai_label.text = AI.short_status()
	root.add_child(_ai_label)

	# ---- prompt
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.2))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.visible = false
	root.add_child(_prompt)

	# ---- toasts
	_toasts = VBoxContainer.new()
	_toasts.anchor_left = 0.5
	_toasts.anchor_right = 0.5
	_toasts.offset_left = -330
	_toasts.offset_right = 330
	_toasts.offset_top = 110
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)

	_build_editor(root)
	_build_fragments(root)
	_build_pause(root)
	_build_settings(root)

	get_viewport().size_changed.connect(_apply_safe_area)
	Plat.input_mode_changed.connect(_on_input_mode)
	_apply_safe_area()
	_on_input_mode("")

	GS.stats_changed.connect(refresh)
	GS.editor_changed.connect(refresh)
	GS.fragment_added.connect(_on_fragment_added)
	GS.toast.connect(toast)
	refresh()


# ------------------------------------------------------------------ platform
## Keeps the HUD clear of notches / rounded corners on phones.
func _apply_safe_area() -> void:
	var m := Plat.safe_margins(get_viewport())
	_root.offset_left = m.position.x
	_root.offset_top = m.position.y
	_root.offset_right = -m.size.x
	_root.offset_bottom = -m.size.y


## Swaps key hints between keyboard / gamepad / touch wording.
func _on_input_mode(_m: String) -> void:
	var touch := Plat.touch_ui()
	_hint.text = Plat.controls_hint()
	# on touch screens the bottom corners belong to the joystick and buttons
	_hint.visible = not touch
	_ai_label.visible = not touch
	if touch:
		_ed_footer.text = "点右上角 × 关闭      修改会立即作用于整个梦境，并消耗稳定度"
		_frag_footer.text = "点右上角 × 关闭"
	else:
		_ed_footer.text = "%s / %s 关闭      修改会立即作用于整个梦境，并消耗稳定度" % [Plat.k("editor"), Plat.k("pause")]
		_frag_footer.text = "%s / %s 关闭" % [Plat.k("fragments"), Plat.k("pause")]


# ------------------------------------------------------------------ status
func _on_fragment_added(_id: String) -> void:
	refresh()


func refresh() -> void:
	_title.text = "%s · 第%d次潜入 · %s" % [GS.case_name(), GS.dive(), GS.stage_name()]
	_stab_bar.value = GS.stability
	_stab_label.text = "%d" % int(GS.stability)
	var fill := _stab_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		var f := fill.duplicate() as StyleBoxFlat
		f.bg_color = Color(0.5, 0.95, 1.0) if GS.stability > 50 else (Color(1.0, 0.8, 0.3) if GS.stability > 25 else Color(1.0, 0.3, 0.35))
		_stab_bar.add_theme_stylebox_override("fill", f)
	_state_label.text = "%s · %s · %s" % [GS.TIME_NAMES[GS.time], GS.EMOTION_NAMES[GS.emotion], GS.REALITY_NAMES[GS.reality]]
	_trait_label.text = "小眠性格：" + GS.trait_name()
	_frag_label.text = "碎片 %d / %d" % [GS.frag_count(), GS.frag_ids().size()]
	if editor and editor.visible:
		_refresh_editor()
	if fragments_panel and fragments_panel.visible:
		_refresh_fragments()


func set_objective(t: String) -> void:
	_objective.text = "目标：" + t
	var tw := create_tween()
	_objective.modulate = Color(1, 1, 1)
	tw.tween_property(_objective, "modulate", Color(1.0, 0.92, 0.6), 0.8)


func show_prompt(text: String, screen_pos: Vector2) -> void:
	_prompt.visible = true
	_prompt.text = ("[互动] " if Plat.touch_ui() else "[%s] " % Plat.k("interact")) + text
	_prompt.size = Vector2.ZERO
	_prompt.reset_size()
	_prompt.position = screen_pos - Vector2(_prompt.size.x / 2.0, 0)


func hide_prompt() -> void:
	_prompt.visible = false


func toast(text: String) -> void:
	var p := PanelContainer.new()
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	p.modulate = Color(1, 1, 1, 0)
	_toasts.add_child(p)
	var t := create_tween()
	t.tween_property(p, "modulate", Color(1, 1, 1, 1), 0.25)
	t.tween_interval(3.2)
	t.tween_property(p, "modulate", Color(1, 1, 1, 0), 0.5)
	t.tween_callback(p.queue_free)


func any_panel_open() -> bool:
	return editor.visible or fragments_panel.visible or pause_panel.visible or settings_panel.visible


# ------------------------------------------------------------------ editor
func _centered_panel(root: Control, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -size.x / 2.0
	p.offset_right = size.x / 2.0
	p.offset_top = -size.y / 2.0
	p.offset_bottom = size.y / 2.0
	p.visible = false
	root.add_child(p)
	return p


func _build_editor(root: Control) -> void:
	editor = _centered_panel(root, Vector2(900, 560))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	editor.add_child(v)
	var t := Label.new()
	t.text = "梦境编辑器  DREAM EDITOR"
	t.add_theme_font_size_override("font_size", 36)
	t.modulate = Color(0.5, 0.95, 1.0)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_ed_stab = Label.new()
	_ed_stab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_ed_stab)
	v.add_child(HSeparator.new())
	_ed_rows["time"] = _editor_row(v, "时间", "time", ["day", "night"])
	_ed_rows["emotion"] = _editor_row(v, "情绪", "emotion", ["calm", "happy", "sad", "anger"])
	_ed_rows["reality"] = _editor_row(v, "现实程度", "reality", [0, 1, 2, 3])
	v.add_child(HSeparator.new())
	_ed_desc = RichTextLabel.new()
	_ed_desc.bbcode_enabled = true
	_ed_desc.fit_content = true
	_ed_desc.custom_minimum_size = Vector2(0, 150)
	_ed_desc.add_theme_constant_override("line_separation", 4)
	v.add_child(_ed_desc)
	var f := Label.new()
	_ed_footer = f
	f.modulate = Color(1, 1, 1, 0.55)
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(f)
	U.close_button(editor, close_editor)


func _editor_row(parent: Control, label: String, kind: String, values: Array) -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(120, 0)
	l.modulate = Color(1.0, 0.8, 0.9)
	h.add_child(l)
	var buttons: Array = []
	for i in values.size():
		var val = values[i]
		if kind == "reality" and i > 0:
			var arrow := Label.new()
			arrow.text = "→"
			arrow.modulate = Color(1, 1, 1, 0.5)
			h.add_child(arrow)
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 44)
		b.pressed.connect(_on_edit.bind(kind, val))
		h.add_child(b)
		buttons.append({"button": b, "value": val})
	return buttons


func _value_name(kind: String, val) -> String:
	match kind:
		"time": return GS.TIME_NAMES[val]
		"emotion": return GS.EMOTION_NAMES[val]
		"reality": return GS.REALITY_NAMES[int(val)]
	return str(val)


func _refresh_editor() -> void:
	_ed_stab.text = "梦境稳定度 %d / 100      当前：%s" % [int(GS.stability), GS.editor_summary()]
	var current := {"time": GS.time, "emotion": GS.emotion, "reality": GS.reality}
	for kind in _ed_rows.keys():
		for entry in _ed_rows[kind]:
			var b: Button = entry["button"]
			var val = entry["value"]
			var nm := _value_name(kind, val)
			if str(current[kind]) == str(val):
				b.text = "● " + nm
				b.disabled = false
				b.modulate = Color(1.0, 0.95, 0.5)
				b.tooltip_text = "当前状态"
			elif GS.is_unlocked(kind, val):
				b.text = "%s  -%d" % [nm, GS.edit_cost(kind, val)]
				b.disabled = false
				b.modulate = Color(1, 1, 1)
				b.tooltip_text = ""
			else:
				b.text = "[锁] " + nm
				b.disabled = true
				b.modulate = Color(1, 1, 1)
				b.tooltip_text = GS.lock_hint(kind, val)
	_ed_desc.text = _describe()


func _describe() -> String:
	var ed: Dictionary = GS.case_data()["editor"]
	var lines: Array = []
	match GS.time:
		"day": lines.append("[color=#ffe9a8]白天[/color]：正常的梦境。")
		"night": lines.append(str(ed["night"]))
	match GS.emotion:
		"calm": lines.append("[color=#dddddd]平静[/color]：没有情绪波动。")
		"happy": lines.append(str(ed["happy"]))
		"sad": lines.append(str(ed["sad"]))
		"anger": lines.append(str(ed["anger"]))
	lines.append(str((ed["reality"] as Array)[GS.reality]))
	var locked: Array = []
	for tag in ["joy", "sad", "anger", "fear"]:
		if not GS.has_emo(tag):
			locked.append({"joy": "快乐", "sad": "悲伤", "anger": "愤怒", "fear": "恐惧"}[tag])
	if locked.size() > 0:
		lines.append("[color=#8888aa]收集情绪碎片解锁更多选项：%s[/color]" % "、".join(locked))
	return "\n".join(lines)


func _on_edit(kind: String, val) -> void:
	if GS.apply_edit(kind, val):
		Audio.sfx("shift")
	else:
		Audio.sfx("click", 0.7)
	_refresh_editor()


## Closes the editor from its × button or the pause key (fires story hooks).
func close_editor() -> void:
	if editor.visible:
		toggle_editor()
		if dream and dream.story:
			dream.story.on_editor_closed()


func toggle_editor() -> void:
	if fragments_panel.visible or pause_panel.visible or settings_panel.visible:
		return
	editor.visible = not editor.visible
	Audio.sfx("click")
	if editor.visible:
		_refresh_editor()
		var first: Button = _ed_rows["time"][0]["button"]
		first.grab_focus()


# ------------------------------------------------------------------ fragments
func _build_fragments(root: Control) -> void:
	fragments_panel = _centered_panel(root, Vector2(1100, 620))
	var v := VBoxContainer.new()
	fragments_panel.add_child(v)
	var t := Label.new()
	t.text = "梦境碎片"
	t.add_theme_font_size_override("font_size", 36)
	t.modulate = Color(1.0, 0.8, 0.9)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 500)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	_frag_list = GridContainer.new()
	_frag_list.columns = 2
	_frag_list.add_theme_constant_override("h_separation", 12)
	_frag_list.add_theme_constant_override("v_separation", 12)
	_frag_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_frag_list)
	var f := Label.new()
	_frag_footer = f
	f.modulate = Color(1, 1, 1, 0.55)
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(f)


func _refresh_fragments() -> void:
	for c in _frag_list.get_children():
		c.queue_free()
	for id in GS.frag_ids():
		var data: Dictionary = GS.FRAGMENTS[id]
		var have := GS.has_frag(id)
		var h := HBoxContainer.new()
		h.custom_minimum_size = Vector2(520, 110)
		h.add_theme_constant_override("separation", 10)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 56)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = load("res://assets/sprites/photo.png" if data["type"] == "memory" else "res://assets/sprites/crystal.png")
		icon.modulate = EMO_COLORS.get(id, Color(1, 1, 1)) if have else Color(0.2, 0.2, 0.3)
		h.add_child(icon)
		var l := RichTextLabel.new()
		l.bbcode_enabled = true
		l.fit_content = true
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("normal_font_size", 24)
		if have:
			l.text = "[color=#ffd6e6]%s[/color]\n%s\n[color=#7ff5ff]%s[/color]" % [data["name"], data["desc"], data["effect"]]
		else:
			l.text = "[color=#666680]？？？\n%s · 未发现[/color]" % ("记忆碎片" if data["type"] == "memory" else "情绪碎片")
		h.add_child(l)
		_frag_list.add_child(h)


func toggle_fragments() -> void:
	if editor.visible or pause_panel.visible or settings_panel.visible:
		return
	fragments_panel.visible = not fragments_panel.visible
	Audio.sfx("click")
	if fragments_panel.visible:
		_refresh_fragments()


# ------------------------------------------------------------------ pause
func _build_pause(root: Control) -> void:
	pause_panel = _centered_panel(root, Vector2(480, 400))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pause_panel.add_child(v)
	var t := Label.new()
	t.text = "暂停"
	t.add_theme_font_size_override("font_size", 36)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b1 := Button.new()
	b1.text = "继续"
	b1.pressed.connect(toggle_pause)
	v.add_child(b1)
	var b2 := Button.new()
	b2.text = "中止潜入（本次不计入）"
	b2.pressed.connect(func(): dream.abort_dive())
	v.add_child(b2)
	var b3 := Button.new()
	b3.text = "回到标题"
	b3.pressed.connect(func(): GS.goto("title"))
	v.add_child(b3)
	var b4 := Button.new()
	b4.text = "设置"
	b4.pressed.connect(open_settings)
	v.add_child(b4)
	for b in [b1, b2, b3, b4]:
		b.custom_minimum_size = Vector2(0, 56)
	U.close_button(pause_panel, toggle_pause)


func _build_settings(root: Control) -> void:
	settings_panel = _centered_panel(root, Vector2(640, 560))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	settings_panel.add_child(v)
	var t := Label.new()
	t.text = "设置"
	t.add_theme_font_size_override("font_size", 36)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	U.settings_box(v)
	U.close_button(settings_panel, close_settings)


func open_settings() -> void:
	pause_panel.visible = false
	settings_panel.visible = true
	Audio.sfx("click")


func close_settings() -> void:
	settings_panel.visible = false
	pause_panel.visible = true


func _on_voice_toggled(on: bool) -> void:
	GS.settings["voice"] = on


func toggle_pause() -> void:
	if settings_panel.visible:
		close_settings()
		return
	if editor.visible:
		close_editor()
		return
	if fragments_panel.visible:
		fragments_panel.visible = false
		return
	pause_panel.visible = not pause_panel.visible
	Audio.sfx("click")
	if pause_panel.visible:
		(pause_panel.get_child(0).get_child(1) as Button).grab_focus()
