extends Node
## Headless autoplay smoke test: plays through all three dives by triggering
## story events directly (dialogue auto-advances with scripted choices).
##   godot --headless --path game res://tests/smoke.tscn
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
	print("\n==== SMOKE TEST: %d checks, %d failures ====" % [checks, failures])
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
	print("==== title ====")
	GS.new_game()
	var t := spawn_scene("title")
	await frames(10)
	t.queue_free()
	await frames(2)

	print("\n==== clinic (visit 0) ====")
	var c := spawn_scene("clinic")
	await frames(60)
	check(GS.flag("briefed"), "clinic briefing played")
	c.queue_free()
	await frames(2)

	# ------------------------------------------------------------ dive 1
	print("\n==== DIVE 1: sweet ====")
	var d := spawn_scene("dream")
	await frames(5)
	await wait_idle(d)
	check(GS.stage() == "sweet", "stage is sweet")
	check(d.nodes.has("duoduo") and d.nodes.has("tangxin"), "npcs spawned")
	await edit("emotion", "happy", false)
	await interact(d, "朵朵", [2])
	check(GS.has_frag("emo_joy"), "joy fragment from Duoduo")
	await edit("emotion", "happy", true)
	await interact(d, "熊先生", [1])
	await interact(d, "钟楼", [2])
	check(GS.flag("v1_tx"), "met Tangxin")
	check(d.nodes["tangxin"].visible, "Tangxin revealed")
	check(find_interact(d, "旧书包") == null, "school bag hidden during day")
	await edit("time", "night", true)
	await interact(d, "旧书包")
	check(GS.has_frag("emo_sad"), "sad fragment from night-only bag")
	await interact(d, "拾取：记忆碎片")
	check(GS.has_frag("mem_photo"), "photo fragment")
	await interact(d, "异常数据", [0])
	await interact(d, "异常数据", [1])
	await interact(d, "异常数据", [2])
	await interact(d, "模糊的房子")
	await edit("emotion", "sad", true)
	await frames(10)
	check(d.rain.emitting, "rain while sad")
	await edit("emotion", "anger", false)
	await edit("reality", 1, true)
	await edit("reality", 2, false)
	print("\n-- ask xm")
	await d._run(d.story.ask_xm)
	await physics(30)
	check(GS.stability > 0.0, "stability %d > 0" % int(GS.stability))
	await interact(d, "钟楼", [2])
	await frames(30)
	check(GS.visit == 1, "dive 1 completed")
	check(GS.last_goto == "clinic", "goes to clinic")
	check(GS.residue["emotion"] == "sad" and GS.residue["time"] == "night", "residue saved")
	d.queue_free()
	await frames(3)

	print("\n==== clinic (visit 1) ====")
	c = spawn_scene("clinic")
	await frames(40)
	c.queue_free()
	await frames(2)

	# ------------------------------------------------------------ dive 2
	print("\n==== DIVE 2: melting ====")
	d = spawn_scene("dream")
	await frames(5)
	await wait_idle(d)
	check(GS.stage() == "melting", "stage is melting")
	check(GS.time == "night" and GS.emotion == "sad", "dream starts from residue")
	check(d.syrup_blobs.size() == 16, "syrup ring built")
	await edit("emotion", "happy", true)
	await physics(3)
	var all_open := true
	for b in d.syrup_blobs:
		all_open = all_open and b["col"].disabled
	check(all_open, "happy crystallises syrup")
	await interact(d, "朵朵", [0])
	check(GS.flag("v2_dd"), "talked to Duoduo v2")
	await interact(d, "熊先生")
	check(GS.has_frag("emo_anger"), "anger fragment from bear")
	await interact(d, "巧克力墙")
	check(d.breakables.size() == 2, "wall does not break without anger")
	await edit("emotion", "anger", true)
	await interact(d, "巧克力墙")
	await frames(2)
	await interact(d, "巧克力墙")
	await frames(20)
	check(d.breakables.size() == 0, "walls broken with anger")
	await interact(d, "拾取：情绪碎片")
	check(GS.has_frag("emo_fear"), "fear fragment")
	await interact(d, "拾取：记忆碎片")
	check(GS.has_frag("mem_diary"), "diary at night")
	await interact(d, "奶奶的糖果店")
	check(GS.has_frag("emo_regret"), "regret at grandma's shop")
	await interact(d, "异常数据", [1])
	await interact(d, "异常数据", [2])
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
	await interact(d, "钟楼", [2, 2])
	await frames(30)
	check(GS.visit == 2, "dive 2 completed")
	d.queue_free()
	await frames(3)

	# ------------------------------------------------------------ dive 3
	print("\n==== DIVE 3: maze ====")
	d = spawn_scene("dream")
	await frames(5)
	await wait_idle(d)
	check(GS.stage() == "maze", "stage is maze")
	check(d.maze_path.size() > 30, "maze path is long (%d cells)" % d.maze_path.size())
	var on_path := {}
	for mc in d.maze_path:
		on_path[mc] = true
	for y in d.MH:
		var row := ""
		for x in d.MW:
			row += "#" if d.maze[y][x] == 1 else ("." if on_path.has(Vector2i(x, y)) else " ")
		print("    ", row)
	check(d.shadows.size() == 2, "maze shadows at fantasy level (%d)" % d.shadows.size())
	await physics(60)
	await edit("emotion", "sad", true)
	check(d.sad_only.size() > 0 and d.sad_only[0].visible, "footprints visible when sad")
	await edit("time", "day", true)
	await edit("reality", 2, true)
	await frames(3)
	await interact(d, "拾取：记忆碎片")
	check(GS.has_frag("mem_voice"), "echo memory in madness")
	await edit("reality", 0, true)
	await interact(d, "异常数据", [0])
	await interact(d, "异常数据", [2])
	await edit("emotion", "anger", true)
	var nb: int = d.breakables.size()
	await interact(d, "巧克力墙")
	await frames(20)
	check(d.breakables.size() == nb - 1, "maze wall broken")
	d.player.global_position = Vector2(600, 520)
	await physics(5)
	await wait_idle(d)
	check(GS.flag("v3_arrived"), "arrival trigger")
	await interact(d, "糖心")
	check(not GS.flag("letter_path"), "Tangxin waits until Duoduo talked")
	await interact(d, "朵朵")
	Dialog.autoplay_inputs = ["你为什么要造迷宫？", "你害怕吗", ""]
	await interact(d, "糖心", [2])
	await frames(30)
	check(GS.ending == "creator", "ending = creator (%s)" % GS.ending)
	check(GS.visit == 3 and GS.last_goto == "ending", "goes to ending")
	d.queue_free()
	await frames(3)

	print("\n==== ending ====")
	var e := spawn_scene("ending")
	await get_tree().create_timer(30.0).timeout
	e.queue_free()
	await frames(2)

	# ------------------------------------------------------------ collapse
	print("\n==== collapse test ====")
	GS.new_game()
	d = spawn_scene("dream")
	await frames(5)
	await wait_idle(d)
	GS.change_stability(-150)
	await get_tree().create_timer(6.0).timeout
	check(GS.last_collapse and GS.last_goto == "clinic" and GS.visit == 0, "collapse returns to clinic without counting")
	d.queue_free()
	await frames(3)

	# alternative ending path: doubtful Xiaomian intervenes on perfect repair
	print("\n==== xiaomian intervention ====")
	GS.new_game()
	GS.visit = 2
	GS.xm = {"warmth": 0, "doubt": 5, "curiosity": 0}
	GS.set_flag("v3_dd")
	d = spawn_scene("dream")
	await frames(5)
	await wait_idle(d)
	Dialog.autoplay_inputs = [""]
	await interact(d, "糖心", [0, 1, 1])
	await frames(30)
	check(GS.ending == "guardian", "reconsidered -> guardian (%s)" % GS.ending)
	d.queue_free()
	await frames(3)
