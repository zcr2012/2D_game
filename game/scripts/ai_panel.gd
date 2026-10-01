extends CanvasLayer
## AI provider settings panel: pick a vendor preset or add a custom endpoint
## (protocol, base URL, key, model, headers, extra JSON body), test it, and
## choose which one the game uses. Works with mouse, touch and gamepad focus.

const U := preload("res://scripts/ui_util.gd")

signal closed

var _list: ItemList
var _active_opt: OptionButton
var _status: Label
var _result: Label
var _sel := ""
var _ids: Array = []
var _name: LineEdit
var _type: OptionButton
var _url: LineEdit
var _key: LineEdit
var _model: LineEdit
var _temp: LineEdit
var _tokparam: OptionButton
var _timeout: LineEdit
var _headers: TextEdit
var _extra: TextEdit
var _optional: CheckBox
var _test_btn: Button
var _del_btn: Button
var _loading := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = -340
	panel.offset_bottom = 340
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var t := U.label(root, "AI 接口设置", 32, Color(0.5, 0.95, 1.0))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	U.label(top, "当前使用", 24)
	_active_opt = OptionButton.new()
	_active_opt.custom_minimum_size = Vector2(380, 46)
	_active_opt.item_selected.connect(_on_active_selected)
	top.add_child(_active_opt)
	_status = U.label(top, "", 20, Color(0.5, 0.95, 1.0, 0.85))
	_status.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.custom_minimum_size = Vector2(300, 0)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# ---- left: provider list
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(290, 0)
	body.add_child(left)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(290, 360)
	_list.item_selected.connect(_on_list_selected)
	left.add_child(_list)
	U.button(left, "＋ 添加自定义接口", _on_add, Vector2(0, 48))

	# ---- right: form
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 6)
	sc.add_child(form)

	_name = _line(form, "名称", "给这个接口起个名字")
	_type = OptionButton.new()
	for ty in AI.TYPE_ORDER:
		_type.add_item(AI.TYPES[ty])
	_type.custom_minimum_size = Vector2(0, 44)
	_row(form, "协议", _type)
	_url = _line(form, "接口地址", "例如 https://api.example.com/v1")
	_key = _line(form, "API Key", "本地模型可留空")
	_key.secret = true
	var show := CheckBox.new()
	show.text = "显示密钥"
	show.toggled.connect(func(on: bool): _key.secret = not on)
	_row(form, "", show)
	_model = _line(form, "模型", "例如 gpt-4o-mini")
	_optional = CheckBox.new()
	_optional.text = "无需 API Key（本地 / 局域网模型）"
	_row(form, "", _optional)
	_temp = _line(form, "Temperature", "0~2；填 -1 表示不传该参数")
	_tokparam = OptionButton.new()
	_tokparam.add_item("max_tokens")
	_tokparam.add_item("max_completion_tokens")
	_tokparam.custom_minimum_size = Vector2(0, 44)
	_row(form, "长度参数名", _tokparam)
	_timeout = _line(form, "超时（秒）", "25")
	_headers = _text(form, "自定义请求头", "每行一个，例如：\nHTTP-Referer: https://my.game\nX-Api-Version: 3")
	_extra = _text(form, "额外请求体", "JSON 对象，会合并进请求，例如：\n{\"top_p\": 0.9, \"enable_thinking\": false}")

	# ---- result + buttons
	_result = U.label(root, "", 20, Color(1.0, 0.92, 0.6))
	_result.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_result.custom_minimum_size = Vector2(0, 52)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	root.add_child(btns)
	U.button(btns, "保存", _on_save, Vector2(140, 48))
	_test_btn = U.button(btns, "测试连接", _on_test, Vector2(170, 48))
	U.button(btns, "保存并使用", _on_use, Vector2(200, 48))
	_del_btn = U.button(btns, "删除", _on_delete, Vector2(140, 48))
	U.close_button(panel, _close)

	_refresh_all()
	var cur := AI.active_id if AI.active_id != "" else str(AI.providers[0]["id"])
	_select(cur)


func _line(parent: Control, label: String, placeholder: String) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.custom_minimum_size = Vector2(0, 44)
	le.virtual_keyboard_enabled = true
	_row(parent, label, le)
	return le


func _text(parent: Control, label: String, placeholder: String) -> TextEdit:
	var te := TextEdit.new()
	te.placeholder_text = placeholder
	te.custom_minimum_size = Vector2(0, 84)
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.scroll_fit_content_height = false
	_row(parent, label, te)
	return te


func _row(parent: Control, label: String, c: Control) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_font_size_override("font_size", 22)
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	h.add_child(l)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(c)


# ------------------------------------------------------------------ data <-> ui
func _refresh_all() -> void:
	_ids = []
	_list.clear()
	_active_opt.clear()
	_active_opt.add_item("离线（不使用 AI）", 0)
	for i in AI.providers.size():
		var p: Dictionary = AI.providers[i]
		var mark := ""
		if p["id"] == AI.active_id:
			mark = "  ★当前"
		elif not AI.is_ready(p):
			mark = "  （未配置）"
		_list.add_item(str(p["name"]) + mark)
		_ids.append(p["id"])
		_active_opt.add_item(str(p["name"]), i + 1)
	var idx := _ids.find(AI.active_id)
	_active_opt.select(idx + 1 if idx >= 0 else 0)
	var si := _ids.find(_sel)
	if si >= 0:
		_list.select(si)
	_status.text = AI.status_text()


func _select(id: String) -> void:
	var p := AI.get_provider(id)
	if p.is_empty():
		return
	_sel = id
	_loading = true
	_name.text = str(p["name"])
	var ti: int = AI.TYPE_ORDER.find(str(p.get("type", "openai")))
	_type.select(maxi(ti, 0))
	_url.text = str(p.get("base_url", ""))
	_key.text = str(p.get("api_key", ""))
	_model.text = str(p.get("model", ""))
	_optional.button_pressed = bool(p.get("key_optional", false))
	_temp.text = str(snappedf(float(p.get("temperature", 0.9)), 0.01))
	_tokparam.select(1 if str(p.get("max_tokens_param", "max_tokens")) == "max_completion_tokens" else 0)
	_timeout.text = str(int(float(p.get("timeout", 25.0))))
	_headers.text = str(p.get("headers", ""))
	_extra.text = str(p.get("extra_body", ""))
	_del_btn.text = "删除" if bool(p.get("custom", false)) else "恢复默认"
	_loading = false
	var si := _ids.find(id)
	if si >= 0:
		_list.select(si)
	_result.text = ""


func _collect() -> Dictionary:
	var p: Dictionary = AI.get_provider(_sel).duplicate()
	p["name"] = _name.text.strip_edges() if _name.text.strip_edges() != "" else _sel
	p["type"] = AI.TYPE_ORDER[_type.selected]
	p["base_url"] = _url.text.strip_edges()
	p["api_key"] = _key.text.strip_edges()
	p["model"] = _model.text.strip_edges()
	p["key_optional"] = _optional.button_pressed
	p["temperature"] = float(_temp.text) if _temp.text.strip_edges().is_valid_float() else -1.0
	p["max_tokens_param"] = "max_completion_tokens" if _tokparam.selected == 1 else "max_tokens"
	p["timeout"] = clampf(float(_timeout.text) if _timeout.text.strip_edges().is_valid_float() else 25.0, 3.0, 180.0)
	p["headers"] = _headers.text
	p["extra_body"] = _extra.text
	return p


func _extra_valid() -> bool:
	var t := _extra.text.strip_edges()
	return t == "" or JSON.parse_string(t) is Dictionary


# ------------------------------------------------------------------ actions
func _on_list_selected(i: int) -> void:
	if _loading or i < 0 or i >= _ids.size():
		return
	_select(str(_ids[i]))


func _on_active_selected(i: int) -> void:
	if i == 0:
		AI.set_active("")
	else:
		AI.set_active(str(AI.providers[i - 1]["id"]))
	_refresh_all()
	_result.text = AI.status_text()


func _on_add() -> void:
	var p := AI.new_custom()
	AI.upsert(p)
	AI.save_config()
	_refresh_all()
	_select(str(p["id"]))
	_result.text = "已添加。填写协议、地址、Key 和模型后点『测试连接』。"
	_name.grab_focus()


func _on_save() -> bool:
	if _sel == "":
		return false
	if not _extra_valid():
		_result.text = "『额外请求体』不是合法的 JSON 对象，未保存。"
		return false
	AI.upsert(_collect())
	AI.save_config()
	_refresh_all()
	_result.text = "已保存。"
	return true


func _on_use() -> void:
	if not _on_save():
		return
	if not AI.is_ready(AI.get_provider(_sel)):
		_result.text = "已保存，但还不完整（需要地址、模型，云端接口还需要 API Key），暂时无法使用。"
		return
	AI.set_active(_sel)
	_refresh_all()
	_result.text = "现在使用：" + AI.status_text()


func _on_test() -> void:
	if not _extra_valid():
		_result.text = "『额外请求体』不是合法的 JSON 对象。"
		return
	var p := _collect()
	_test_btn.disabled = true
	_result.text = "正在连接 %s ……" % str(p["name"])
	var r: Dictionary = await AI.request(p, "你是接口连通性测试助手。", [{"role": "user", "content": "请只回复两个字：你好"}], 128)
	if is_instance_valid(_test_btn):
		_test_btn.disabled = false
	if not is_instance_valid(_result):
		return
	if r["ok"]:
		_result.text = "✔ 连接成功。模型回复：" + str(r["text"]).left(60)
	else:
		_result.text = "✘ " + str(r["error"])


func _on_delete() -> void:
	if _sel == "":
		return
	var was_custom: bool = bool(AI.get_provider(_sel).get("custom", false))
	var id := _sel
	AI.remove_or_reset(id)
	_refresh_all()
	if was_custom:
		_select(str(AI.providers[0]["id"]))
		_result.text = "已删除。"
	else:
		_select(id)
		_result.text = "已恢复默认设置（API Key 保留）。"


func _close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()
