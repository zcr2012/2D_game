extends Node
## Headless test for phone / tablet / desktop adaptation.
##
##   godot --headless --path game res://tests/platform_test.tscn
##
## 1. Layout on several screen shapes (16:9 desktop, 20:9 & 19.5:9 phones,
##    4:3 tablet, 21:9 ultrawide): everything on screen, touch buttons never
##    cover the HUD or each other. Prints "LAYOUT {json}" lines for tools/layout_preview.py.
## 2. Touch input: joystick walks the player, buttons fire actions, multi-touch,
##    Android back button, app backgrounding, keyboard <-> touch switching.
## 3. Dialogue text input: send / skip buttons.

const SIZES := [
	[Vector2i(1280, 720), "desktop 16:9"],
	[Vector2i(2400, 1080), "phone 20:9"],
	[Vector2i(2532, 1170), "iPhone 19.5:9"],
	[Vector2i(2048, 1536), "iPad 4:3"],
	[Vector2i(3440, 1440), "ultrawide 21:9"],
]

var checks := 0
var failures := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		print("  ✔ ", what)
	else:
		failures += 1
		print("  ✘ FAIL: ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	GS.test_mode = true
	Dialog.autoplay = true
	Engine.time_scale = 1.0
	await run()
	print("\n==== PLATFORM TEST: %d checks, %d failures ====" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func spawn(name: String) -> Node:
	var s: Node = load("res://scenes/%s.tscn" % name).instantiate()
	add_child(s)
	return s


func wait_idle(d) -> void:
	for i in 600:
		if d.busy == 0 and not Dialog.active:
			return
		await get_tree().process_frame


func inside(r: Rect2, screen: Rect2) -> bool:
	return screen.grow(0.5).encloses(r)


func rect_json(r: Rect2) -> Array:
	return [snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.size.x, 0.1), snappedf(r.size.y, 0.1)]


## Real touch events arrive in window pixels; convert from canvas coordinates.
func win(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p


func touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = win(pos)
	e.pressed = pressed
	Input.parse_input_event(e)


func drag(idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = win(pos)
	Input.parse_input_event(e)


func key(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)


func run() -> void:
	# ------------------------------------------------------------ layouts
	Plat.touch_pref = "on"
	for entry in SIZES:
		var sz: Vector2i = entry[0]
		print("\n==== layout: %s (%dx%d) ====" % [entry[1], sz.x, sz.y])
		get_tree().root.size = sz
		await frames(2)
		var screen := get_viewport().get_visible_rect()
		var out := {"name": entry[1], "window": [sz.x, sz.y], "canvas": [screen.size.x, screen.size.y], "boxes": []}

		# title
		GS.new_game()
		var t := spawn("title")
		await frames(3)
		var all_in := true
		for b in _find_all(t, "Button"):
			if b.is_visible_in_tree():
				var r: Rect2 = b.get_global_rect()
				all_in = all_in and inside(r, screen)
				out["boxes"].append({"scene": "title", "kind": "button", "text": b.text, "r": rect_json(r)})
		check(all_in, "title buttons on screen")
		t.queue_free()
		await frames(2)

		# dream (touch UI)
		GS.new_game()
		var d := spawn("dream")
		await frames(5)
		await wait_idle(d)
		await frames(2)
		check(d.touch.visible, "touch controls visible")
		var tr: Dictionary = d.touch.button_rects()
		var hud_boxes: Array = []
		for c in d.hud._root.get_children():
			if c is PanelContainer and c.visible:
				hud_boxes.append(c.get_global_rect())
				out["boxes"].append({"scene": "dream", "kind": "hud", "text": "", "r": rect_json(c.get_global_rect())})
		var ok_in := true
		var ok_hud := true
		var ok_self := true
		var keys := tr.keys()
		for i in keys.size():
			var r: Rect2 = tr[keys[i]]
			out["boxes"].append({"scene": "dream", "kind": "touch", "text": keys[i], "r": rect_json(r)})
			ok_in = ok_in and inside(r, screen)
			for h in hud_boxes:
				if r.intersects(h):
					ok_hud = false
					print("    overlap: %s with HUD %s" % [keys[i], h])
			for j in range(i + 1, keys.size()):
				if r.intersects(tr[keys[j]]):
					ok_self = false
					print("    overlap: %s with %s" % [keys[i], keys[j]])
		check(ok_in, "touch controls on screen")
		check(ok_hud, "touch controls do not cover the HUD")
		check(ok_self, "touch controls do not overlap each other")

		# panels
		for pname in ["editor", "fragments_panel", "pause_panel", "settings_panel"]:
			var p: Control = d.hud.get(pname)
			p.visible = true
			await frames(2)
			var pr := p.get_global_rect()
			check(inside(pr, screen), "%s on screen %s" % [pname, pr])
			out["boxes"].append({"scene": "panel", "kind": pname, "text": "", "r": rect_json(pr)})
			p.visible = false
		check(not d.touch.visible or d.can_player_act(), "touch hidden while a panel is open")

		# dialogue box (measure it as it would appear)
		Dialog._set_text("测试对白：一行比较长的文字，用来量一量对话框在不同屏幕上的大小。")
		Dialog._panel.visible = true
		await frames(2)
		var dr: Rect2 = Dialog._panel.get_global_rect()
		check(inside(dr, screen), "dialogue box on screen")
		out["boxes"].append({"scene": "dialog", "kind": "dialog", "text": "", "r": rect_json(dr)})
		Dialog._panel.visible = false
		print("LAYOUT " + JSON.stringify(out))
		d.queue_free()
		await frames(3)

	# ------------------------------------------------------------ touch input
	print("\n==== touch input (phone 20:9) ====")
	get_tree().root.size = Vector2i(2400, 1080)
	await frames(2)
	GS.new_game()
	var d := spawn("dream")
	await frames(5)
	await wait_idle(d)
	var p0: Vector2 = d.player.global_position
	touch(0, Vector2(220, 520), true)
	drag(0, Vector2(300, 520))
	await frames(1)
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	check(v.x > 0.8 and absf(v.y) < 0.2, "joystick right -> move vector %s" % v)
	await physics(30)
	check(d.player.global_position.x > p0.x + 20.0, "player walked right (%.0f -> %.0f)" % [p0.x, d.player.global_position.x])
	# second finger presses a button while walking (multi-touch)
	var rects: Dictionary = d.touch.button_rects()
	touch(1, rects["fragments"].get_center(), true)
	await frames(3)
	check(d.hud.fragments_panel.visible, "碎片 button opens fragments while walking")
	check(not d.touch.visible, "touch controls hide while a panel is open")
	check(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "movement released when controls hide")
	touch(1, rects["fragments"].get_center(), false)
	touch(0, Vector2(300, 520), false)
	d.hud.toggle_fragments()
	await frames(2)
	check(d.touch.visible, "touch controls back after closing panel")

	# interact via 互动 button next to Duoduo
	var dd = null
	for it in get_tree().get_nodes_in_group("interactable"):
		if "朵朵" in it.prompt:
			dd = it
	d.player.global_position = dd.global_position + Vector2(0, 10)
	await physics(2)
	await frames(2)
	touch(2, rects["interact"].get_center(), true)
	touch(2, rects["interact"].get_center(), false)
	await frames(3)
	await wait_idle(d)
	check(GS.has_frag("emo_joy"), "互动 button talks to Duoduo (joy fragment)")

	# editor button + close (×) button
	touch(3, rects["editor"].get_center(), true)
	touch(3, rects["editor"].get_center(), false)
	await frames(2)
	check(d.hud.editor.visible, "编辑 button opens the dream editor")
	d.hud.close_editor()
	await frames(2)
	check(not d.hud.editor.visible, "× closes the editor")

	# 菜单 -> settings -> back
	touch(4, rects["pause"].get_center(), true)
	touch(4, rects["pause"].get_center(), false)
	await frames(2)
	check(d.hud.pause_panel.visible, "菜单 button opens pause")
	d.hud.open_settings()
	check(d.hud.settings_panel.visible and not d.hud.pause_panel.visible, "settings opens from pause")
	Plat.press_action("pause")
	await frames(2)
	check(d.hud.pause_panel.visible and not d.hud.settings_panel.visible, "back from settings returns to pause")
	d.hud.toggle_pause()
	await frames(2)

	# Android back button & app backgrounding
	Plat._on_back()
	await frames(2)
	check(d.hud.pause_panel.visible, "Android back opens the pause menu")
	d.hud.toggle_pause()
	await frames(2)
	Plat.app_paused.emit()
	await frames(2)
	check(d.hud.pause_panel.visible, "app going to background pauses the dive")
	d.hud.toggle_pause()
	await frames(2)

	# hints follow the device
	check(Plat.k("editor") == "『编辑』" and "左侧" in Plat.controls_intro(), "touch wording: %s" % Plat.press("editor"))
	check("[互动]" in d.hud._prompt.text or not d.hud._prompt.visible, "prompt uses touch wording")
	Plat.touch_pref = "auto"
	key(KEY_W)
	await frames(2)
	check(Plat.device == "kbd" and not d.touch.visible, "keyboard use hides touch controls (auto)")
	check(Plat.k("editor") == "Tab" and d.hud._hint.visible, "keyboard wording: %s" % Plat.press("editor"))
	touch(5, Vector2(200, 400), true)
	touch(5, Vector2(200, 400), false)
	await frames(2)
	check(Plat.device == "touch" and d.touch.visible, "touching the screen brings them back (auto)")
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_A
	jb.pressed = true
	Input.parse_input_event(jb)
	jb = jb.duplicate()
	jb.pressed = false
	Input.parse_input_event(jb)
	await frames(2)
	check(Plat.device == "pad" and Plat.k("interact") == "A", "gamepad wording: %s" % Plat.press("interact"))
	check(InputMap.action_has_event("interact", jb), "gamepad A mapped to interact")
	d.queue_free()
	await frames(3)

	# ------------------------------------------------------------ text input
	print("\n==== dialogue text input ====")
	Dialog.autoplay = false
	var res := [null]
	var ask := func():
		res[0] = await Dialog.ask_text("tx", "问点什么？", "")
	ask.call()
	await frames(2)
	check(Dialog._input_row.visible, "input row with send / skip buttons shown")
	Dialog._line.text = "你好，糖心"
	Dialog._on_send_pressed()
	await frames(2)
	check(res[0] == "你好，糖心", "发送 button submits text")
	res[0] = null
	ask.call()
	await frames(2)
	Dialog._on_skip_pressed()
	await frames(2)
	check(res[0] == "", "跳过 button skips")
	check(not Dialog._input_row.visible, "input row hidden afterwards")
	Dialog.autoplay = true
	get_tree().root.size = Vector2i(1280, 720)


func _find_all(n: Node, cls: String) -> Array:
	var out: Array = []
	if n.is_class(cls):
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_all(c, cls))
	return out
