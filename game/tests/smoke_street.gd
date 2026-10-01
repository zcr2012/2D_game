extends Node
## Headless autoplay smoke test for Dream 2 (Old Street): plays all three dives
## by triggering story events directly (dialogue auto-advances with scripted
## choices).
##   godot --headless --path game res://tests/smoke_street.tscn
## Exit code 0 = all checks passed.

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
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
	Engine.time_scale = 8.0
	await run()
	print("\n==== STREET SMOKE TEST: %d checks, %d failures ====" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func find_interact(d, contains: String):
	for it in get_tree().get_nodes_in_group("interactable"):
		if it.is_inside_tree() and it.prompt.find(contains) != -1 and it.available():
			return it
	return null


func interact(d, contains: String, choices: Array = []) -> bool:
	var it = find_interact(d, contains)
	if it == null:
		print("  (no available interactable: %s)" % contains)
		return false
	print("\n-- interact: ", it.prompt)
	Dialog.autoplay_choices = choices.duplicate()
	d.player.global_position = it.global_position + Vector2(0, 12)
	await d._run(it.action)
	await frames(2)
	return true


func wait_idle(d) -> void:
	for i in 600:
		if d.busy == 0 and not Dialog.active:
			return
		await get_tree().process_frame
	check(false, "dream became idle")


func spawn_scene(name: String) -> Node:
	var s: Node = load("res://scenes/%s.tscn" % name).instantiate()
	add_child(s)
	return s


func edit(kind: String, val, expect: bool) -> void:
	var ok := GS.apply_edit(kind, val)
	check(ok == expect, "editor %s=%s -> %s" % [kind, str(val), str(expect)])
	await frames(3)


func run() -> void:
	print("==== case setup ====")
	GS.new_game()
	GS.start_case("street")
	check(GS.case_id == "street" and GS.stage() == "summer", "street case starts in summer")
	check(not GS.has_frag("mem_photo") and GS.frag_count() == 0, "street fragments are separate from candy")
	var c := spawn_scene("clinic")
	await frames(60)
	check(GS.flag("briefed_street"), "street briefing played")
	c.queue_free()
	await frames(2)

	# ------------------------------------------------------------ dive 1
	print("\n==== DIVE 1: summer ====")
	var d := spawn_scene("dream")
	await frames(5)
	await wait_idle(d)
	check(d.street != null and d.world_size == Vector2(1760, 700), "street map built")
	check(d.nodes.has("laodeng") and d.nodes.has("fubo") and d.nodes.has("shenyuan"), "npcs spawned")
	check(d.street._fracture_col == null and d.street.fog == null, "no fracture / fog in summer")
	check(find_interact(d, "亮着灯的窗户") == null, "radio window hidden in daytime")
	await interact(d, "老灯")
	check(GS.flag("met_ld"), "met the lamp")
	await edit("emotion", "happy", false)
	await interact(d, "福伯")
	check(GS.has_frag("st_joy"), "joy fragment from Fubo")
	await edit("emotion", "happy", true)
	await interact(d, "沈远", [0])
	check(GS.flag("v1_sy"), "talked to Shen Yuan")
	await interact(d, "老灯", [0, 3])
	check(GS.flag("v1_ld"), "lamp conversation v1")
	await edit("time", "night", true)
	await interact(d, "亮着灯的窗户")
	check(GS.has_frag("st_radio"), "radio memory from the night window")
	await interact(d, "发光的积水")
	check(GS.has_frag("st_sad"), "sad fragment from the night puddle")
	await interact(d, "花盆")
	check(GS.has_frag("st_photo"), "photo fragment from the planter")
	check(d.nodes["studio"].visible, "studio shows up once we hold the photo")
	await interact(d, "晚照相馆")
	check(not GS.has_frag("st_regret"), "studio stays closed in summer")
	await interact(d, "异常数据", [0])
	await interact(d, "异常数据", [1])
	await interact(d, "异常数据", [2])
	await edit("emotion", "sad", true)
	await frames(10)
	check(d.rain.emitting, "rain while sad")
	await edit("emotion", "anger", false)
	await edit("reality", 3, false)
	await edit("reality", 1, true)
	print("\n-- ask xm")
	await d._run(d.story.ask_xm)
	await physics(30)
	check(GS.stability > 0.0, "stability %d > 0" % int(GS.stability))
	await interact(d, "老灯", [2])
	await frames(30)
	check(GS.visit == 1, "dive 1 completed")
	check(GS.last_goto == "clinic", "goes to clinic")
	d.queue_free()
	await frames(3)

	print("\n==== clinic (visit 1) ====")
	c = spawn_scene("clinic")
	await frames(40)
	c.queue_free()
	await frames(2)

	# ------------------------------------------------------------ dive 2
	print("\n==== DIVE 2: fading ====")
	d = spawn_scene("dream")
	await frames(5)
	await wait_idle(d)
	check(GS.stage() == "fading", "stage is fading")
	check(d.street._fracture_col != null and not d.street._fracture_col.disabled, "fracture blocks the street")
	check(d.street.shop_shutter != null and d.street.alley_gate != null, "shutters built")
	await edit("reality", 0, true)
	await interact(d, "福伯")
	check(GS.has_frag("st_anger"), "anger fragment from Fubo")
	await edit("emotion", "calm", true)
	await interact(d, "生锈的卷帘门")
	check(d.street.shop_shutter != null, "shutter does not break without anger")
	await edit("emotion", "anger", true)
	await interact(d, "生锈的卷帘门")
	await frames(20)
	check(d.street.shop_shutter == null, "shop shutter broken with anger")
	await interact(d, "老沈修理")
	check(GS.has_frag("st_fear"), "fear fragment in the repair shop")
	await interact(d, "锈死的铁闸")
	await frames(20)
	check(d.street.alley_gate == null, "alley gate broken with anger")
	await interact(d, "晚照相馆")
	check(GS.has_frag("st_regret"), "regret fragment in the studio")
	await edit("emotion", "happy", true)
	await interact(d, "路人")
	var faces := 0
	for k in 4:
		faces += int(GS.flag("face_%d" % k))
	check(faces >= 1, "happy restores a face")
	await edit("reality", 1, true)
	await physics(4)
	check(d.street._fracture_col.disabled, "fantasy opens the light bridge")
	d.player.global_position = Vector2(1080, 440)
	await edit("reality", 0, true)
	await physics(4)
	check(d.street._fracture_col.disabled, "bridge stays open while standing on it")
	d.player.global_position = Vector2(1300, 440)
	await physics(4)
	check(not d.street._fracture_col.disabled, "fracture closes again once we are across")
	await edit("reality", 1, true)
	await interact(d, "沈远", [0])
	check(GS.flag("v2_sy"), "talked to Shen Yuan v2")
	await edit("reality", 2, true)
	await frames(3)
	await interact(d, "拾取：记忆碎片")
	check(GS.has_frag("st_ticket"), "ticket memory in madness")
	check(d.shadows.size() == 1, "forgotten one appears at reality 2 (%d)" % d.shadows.size())
	await edit("reality", 3, true)
	await frames(5)
	check(d.shadows.size() == 3, "nightmare spawns shadows (%d)" % d.shadows.size())
	var s0: Vector2 = d.shadows[0].global_position
	await physics(40)
	check(d.shadows[0].global_position != s0, "shadow moves")
	d.shadows[0].global_position = d.player.global_position
	await physics(3)
	check(d._caught_cd > 0.0, "caught by shadow")
	await edit("reality", 1, true)
	await frames(5)
	check(d.shadows.size() == 0, "shadows gone when reality drops")
	await interact(d, "老灯", [0, 1])
	await frames(30)
	check(GS.flag("v2_ld") and GS.flag("s_knows_wife"), "lamp confession v2")
	check(GS.visit == 2, "dive 2 completed")
	d.queue_free()
	await frames(3)

	# ------------------------------------------------------------ dive 3
	print("\n==== DIVE 3: echo ====")
	d = spawn_scene("dream")
	await frames(5)
	await wait_idle(d)
	check(GS.stage() == "echo", "stage is echo")
	check(d.street.fog != null and not d.street.loop_open, "fog closes the east end")
	await edit("reality", 0, true)
	await edit("time", "day", true)
	d.player.global_position = Vector2(1700, 440)
	await physics(4)
	await frames(4)
	await wait_idle(d)
	check(d.street.laps == 1 and d.player.global_position.x < 300.0, "east edge wraps to the west (lap %d)" % d.street.laps)
	await interact(d, "老灯")
	check(not GS.flag("e1"), "lamp tally needs the night")
	await edit("time", "night", true)
	await interact(d, "老灯")
	check(GS.flag("e1"), "echo 1: lamp tally")
	await edit("emotion", "sad", true)
	await interact(d, "积水里的倒影")
	check(GS.flag("e2"), "echo 2: puddle reflection")
	await edit("reality", 2, true)
	await frames(3)
	check(d.street.sign_label.text == "苏晚巷", "madness rewrites the street sign")
	await interact(d, "路牌")
	await wait_idle(d)
	check(GS.flag("e3") and d.street.loop_open, "echo 3: sign -> fog opens")
	await edit("reality", 3, true)
	await frames(5)
	check(d.shadows.size() == 3 and d.shadows[0].skin == "faceless", "faceless chasers in the nightmare")
	await edit("reality", 0, true)
	await edit("emotion", "calm", true)
	await frames(5)
	await interact(d, "老灯")
	check(GS.ending == "", "lamp waits until Shen Yuan has spoken")
	await interact(d, "沈远")
	check(GS.flag("v3_sy"), "talked to Shen Yuan v3")
	Dialog.autoplay_inputs = ["你为什么要重建她？", "苏晚是谁", ""]
	await interact(d, "老灯", [2])
	await frames(30)
	check(GS.ending == "creator", "ending = creator (%s)" % GS.ending)
	check(GS.visit == 3 and GS.last_goto == "ending", "goes to ending")
	check(GS.flags.has("letter_path_street"), "lamp writes its ledger")
	d.queue_free()
	await frames(3)

	print("\n==== ending ====")
	var e := spawn_scene("ending")
	await get_tree().create_timer(30.0).timeout
	e.queue_free()
	await frames(2)

	print("\n==== guardian path ====")
	GS.new_game()
	GS.start_case("street")
	GS.visit = 2
	GS.set_flag("v3_sy")
	GS.set_flag("e1")
	GS.set_flag("e2")
	GS.set_flag("e3")
	d = spawn_scene("dream")
	await frames(5)
	await wait_idle(d)
	d.street.open_loop()
	Dialog.autoplay_inputs = [""]
	await interact(d, "老灯", [1])
	await frames(30)
	check(GS.ending == "guardian", "guardian ending (%s)" % GS.ending)
	d.queue_free()
	await frames(3)
