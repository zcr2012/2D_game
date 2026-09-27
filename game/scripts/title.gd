extends Node
## Title screen.

const U := preload("res://scripts/ui_util.gd")

var _float_nodes: Array = []
var _settings: PanelContainer
var _menu_first: Button
var _t := 0.0


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	U.nebula(root)
	var stage := U.stage(root)

	# floating characters
	var tx := U.portrait(stage, "tangxin", Vector2(360, 300))
	tx.position = Vector2(40, 330)
	tx.modulate = Color(1, 1, 1, 0.85)
	var xmn := U.portrait(stage, "xiaomian", Vector2(220, 260))
	xmn.position = Vector2(1010, 380)
	var pl := TextureRect.new()
	pl.texture = load("res://assets/sprites/player.png")
	pl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pl.custom_minimum_size = Vector2(76, 208)
	pl.size = Vector2(76, 208)
	pl.position = Vector2(900, 440)
	stage.add_child(pl)
	_float_nodes = [tx, xmn, pl]

	var v := VBoxContainer.new()
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.offset_left = -360
	v.offset_right = 360
	v.offset_top = 70
	v.add_theme_constant_override("separation", 6)
	stage.add_child(v)
	var t := U.label(v, "梦境修复师", 96, Color(1.0, 0.85, 0.93))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.35))
	t.add_theme_constant_override("outline_size", 12)
	var st := U.label(v, "D R E A M   R E P A I R", 36, Color(0.5, 0.95, 1.0))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tag := U.label(v, "有些梦，并不是坏掉了，而是在『进化』。", 24, Color(1, 1, 1, 0.8))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var menu := VBoxContainer.new()
	menu.anchor_left = 0.5
	menu.anchor_right = 0.5
	menu.offset_left = -200
	menu.offset_right = 200
	menu.offset_top = 360
	menu.add_theme_constant_override("separation", 12)
	stage.add_child(menu)
	var first := U.button(menu, "开始新的委托", _new_game)
	if GS.has_save() and GS.load_game() and GS.visit < GS.MAX_DIVES:
		first = U.button(menu, "继续（第 %d 次潜入）" % GS.dive(), _continue)
		menu.move_child(first, 0)
	U.button(menu, "设置", _open_settings)
	if not Plat.is_ios:   # iOS apps must not quit themselves
		U.button(menu, "退出", func(): get_tree().quit())
	first.call_deferred("grab_focus")
	_menu_first = first
	_build_settings(root)

	var foot := U.label(stage, "垂直切片 Demo · 梦境一《糖果城市》   ·   " + AI.status_text(), 24, Color(1, 1, 1, 0.5))
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 20
	foot.offset_top = -40
	foot.position = Vector2(20, 680)
	Audio.music("clinic")


func _process(delta: float) -> void:
	_t += delta
	for i in _float_nodes.size():
		var n: Control = _float_nodes[i]
		n.position.y += sin(_t * (0.9 + i * 0.3) + i) * 0.25


func _build_settings(root: Control) -> void:
	_settings = PanelContainer.new()
	_settings.anchor_left = 0.5
	_settings.anchor_right = 0.5
	_settings.anchor_top = 0.5
	_settings.anchor_bottom = 0.5
	_settings.offset_left = -320
	_settings.offset_right = 320
	_settings.offset_top = -235
	_settings.offset_bottom = 235
	_settings.visible = false
	root.add_child(_settings)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_settings.add_child(v)
	var t := U.label(v, "设置", 36)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	U.settings_box(v)
	U.close_button(_settings, _close_settings)


func _open_settings() -> void:
	_settings.visible = true


func _close_settings() -> void:
	_settings.visible = false
	_menu_first.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _settings and _settings.visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close_settings()


func _new_game() -> void:
	GS.new_game()
	GS.delete_save()
	GS.goto("clinic")


func _continue() -> void:
	GS.goto("clinic")
