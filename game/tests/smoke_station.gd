extends Node
## Headless autoplay test for Dream 3 (Space Station): three dives, bridge,
## maintenance gate, anchors, tomorrow hatch, drones, all three endings' choice
## logic, plus Xiaomian's voice-over id parity.
##   godot --headless --path game res://tests/smoke_station.tscn

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
	print("\n==== STATION SMOKE TEST: %d checks, %d failures ====" % [checks, failures])
	print("(Xiaomian lines without a recording during this run: %d)" % Dialog.missing_voice.size())
	get_tree().quit(1 if failures > 0 else 0)


func find_interact(contains: String):
	for it in get_tree().get_nodes_in_group("interactable"):
		if it.is_inside_tree() and it.prompt.find(contains) != -1 and it.available():
			return it
	return null


func interact(d, contains: String, choices: Array = []) -> bool:
	var it = find_interact(contains)
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
	GS.settings["unlock_all"] = false
	GS.new_game()
	check(GS.case_unlocked("candy") and not GS.case_unlocked("station"), "station locked at the start")
	GS.progress["candy"] = {"visit": 3, "core": [], "scores": {}, "ending": "guardian"}
	GS.progress["street"] = {"visit": 3, "core": [], "scores": {}, "ending": "guardian"}
	check(GS.case_unlocked("station") and GS.next_case_id() == "station", "station unlocks after Old Street")
	# play from a clean slate: no emotion tags from earlier dreams
	GS.start_case("station")
	check(GS.case_id == "station" and GS.stage() == "orbit" and GS.case_name() == "太空站", "station case starts in orbit")
	check(GS.frag_ids().size() == 8 and GS.frag_count() == 0, "eight station fragments, separate from other dreams")
	var c := spawn_scene("clinic")
	await frames(60)
	check(GS.flag("briefed_station"), "station briefing played")
	c.queue_free()
	await frames(2)

	# ------------------------------------------------------------ dive 1
	print("\n==== DIVE 1: orbit ====")
	var d := spawn_scene("dream")
	await frames(5)
	await wait_idle(d)
	check(d.station != null and d.world_size == Vector2(1920, 1000), "station map built")
	check(d.nodes.has("linzhou") and d.nodes.has("xingya") and d.nodes.has("gardener"), "npcs spawned")
	check(d.station.gap_col == null and d.station.hatch_col == null, "orbit has no gap and no hatch")
	check(not d.station.vault_open and not d.station.vault_col.disabled, "seed vault starts locked")
	var spawn_ok: bool = d.player.position.y > 280 and d.player.position.y < 870
	check(spawn_ok, "player starts on the deck")
	await interact(d, "和林舟")
	check(GS.flag("sp_captain_orbit"), "captain briefing")
	await interact(d, "和园丁机器人")
	check(GS.has_frag("sp_joy"), "joy fragment from the gardener")
	await interact(d, "种子盒")
	check(GS.has_frag("sp_photo"), "photo fragment from the seed box")
	await interact(d, "地球来信")
	check(not GS.has_frag("sp_voice"), "earth letter needs night")
	await edit("time", "night", true)
	await interact(d, "地球来信")
	check(GS.has_frag("sp_voice") and GS.has_frag("sp_sad"), "earth letter gives voice + sad fragment")
	await interact(d, "育种舱入口")
	check(not d.station.vault_open, "vault stays closed without joy")
	await edit("emotion", "happy", true)
	check(d.station.vault_open and d.station.vault_col.disabled, "photo + joy opens the seed vault")
	await interact(d, "空花盆")
	check(GS.has_frag("sp_regret"), "regret fragment in the vault")
	await interact(d, "异常数据", [0])
	await interact(d, "异常数据", [1])
	await interact(d, "异常数据", [2])
	check(find_interact("异常数据") == null, "all three orbit anomalies handled")
	await edit("emotion", "sad", true)
	await frames(10)
	check(d.rain.emitting, "rain while sad")
	await edit("reality", 3, false)
	await edit("reality", 1, true)
	print("\n-- ask xm")
	await d._run(d.story.ask_xm)
	await physics(30)
	check(GS.stability > 0.0, "stability %d > 0" % int(GS.stability))
	await interact(d, "和星芽", [2])
	await frames(30)
	check(GS.visit == 1 and GS.last_goto == "clinic", "dive 1 completed -> clinic")
	d.queue_free()
	await frames(3)

	print("\n==== clinic (visit 1) ====")
	c = spawn_scene("clinic")
	await frames(40)
	c.queue_free()
	await frames(2)

	# ------------------------------------------------------------ dive 2
	print("\n==== DIVE 2: drift ====")
	d = spawn_scene("dream")
	await frames(5)
	await wait_idle(d)
	check(GS.stage() == "drift", "stage is drift")
	check(d.station.gap_col != null and d.station.gate != null, "gap and maintenance gate built")
	await edit("reality", 0, true)
	await physics(4)
	check(not d.station.gap_col.disabled, "gap blocks the deck at reality 0")
	await edit("reality", 1, true)
	await physics(4)
	check(d.station.gap_col.disabled, "fantasy opens the gravity bridge")
	d.player.position = Vector2(960, 560)
	await edit("reality", 0, true)
	await physics(4)
	check(d.station.gap_col.disabled, "bridge stays open while standing on it")
	d.player.position = Vector2(1100, 560)
	await physics(4)
	check(not d.station.gap_col.disabled, "gap closes again once we are across")
	await edit("reality", 1, true)
	await interact(d, "和林舟")
	check(GS.flag("sp_captain_drift"), "captain talk v2")
	await interact(d, "和园丁机器人")
	check(GS.has_frag("sp_anger"), "anger fragment from the gardener")
	await interact(d, "卡住的维护门")
	check(d.station.gate != null, "gate does not open without anger")
	await edit("emotion", "anger", true)
	await interact(d, "卡住的维护门")
	await frames(20)
	check(d.station.gate == null, "anger opens the maintenance gate")
	await interact(d, "维护终端")
	check(GS.has_frag("sp_fear"), "fear fragment from the maintenance terminal")
	await edit("reality", 3, true)
	await frames(5)
	check(d.shadows.size() == 2 and d.shadows[0].skin == "sp_drone", "nightmare releases two repair drones")
	var drone: Node2D = d.shadows[0]
	d._caught_cd = 0.0
	d.player.global_position = drone.global_position + Vector2(100, 0)
	var s0: Vector2 = drone.global_position
	await physics(3)
	check(drone.global_position != s0, "drone chases the player")
	await edit("reality", 1, true)
	await frames(5)
	check(d.shadows.size() == 0, "drones leave when reality drops")
	await interact(d, "和星芽", [0])
	await frames(30)
	check(GS.visit == 2, "dive 2 completed")
	d.queue_free()
	await frames(3)

	# ------------------------------------------------------------ dive 3
	print("\n==== DIVE 3: genesis ====")
	d = spawn_scene("dream")
	await frames(5)
	await wait_idle(d)
	check(GS.stage() == "genesis" and d.station.hatch_col != null and not d.station.hatch_open, "tomorrow hatch is sealed")
	await edit("reality", 0, true)
	await edit("time", "day", true)
	await interact(d, "轨道钟")
	check(not GS.flag("sp_anchor_now"), "clock anchor needs the night")
	await edit("time", "night", true)
	await interact(d, "轨道钟")
	check(GS.flag("sp_anchor_now"), "anchor 1: now")
	await interact(d, "冷凝水")
	check(not GS.flag("sp_anchor_earth"), "puddle anchor needs sadness")
	await edit("emotion", "sad", true)
	await interact(d, "冷凝水")
	check(GS.flag("sp_anchor_earth"), "anchor 2: Earth")
	await interact(d, "星图")
	check(not GS.flag("sp_anchor_unknown"), "chart needs madness")
	await edit("reality", 2, true)
	await frames(3)
	check(d.station.chart_label.text.contains("未知"), "madness rewrites the star chart")
	await interact(d, "星图")
	check(GS.has_frag("sp_chart") and GS.flag("sp_anchor_unknown"), "anchor 3: unknown + chart fragment")
	await wait_idle(d)
	check(d.station.hatch_open and d.station.hatch_col.disabled, "three anchors open the tomorrow hatch")
	await edit("reality", 0, true)
	await edit("emotion", "calm", true)
	await interact(d, "造梦台", [1])
	check(GS.flags.get("sp_blueprint", "") == "harbor" and d.station.creations.size() == 6, "blueprint changes the new dream")
	await interact(d, "和星芽")
	check(GS.ending == "", "persona waits for the captain")
	await interact(d, "和林舟")
	check(GS.flag("sp_captain_genesis"), "talked to the captain v3")
	Dialog.autoplay_inputs = ["你真的知道明天吗？", "地球是什么", ""]
	await interact(d, "和星芽", [2])
	await frames(30)
	check(GS.ending == "creator", "ending = creator (%s)" % GS.ending)
	check(GS.visit == 3 and GS.last_goto == "ending", "goes to ending")
	check(GS.flags.has("letter_path_station"), "persona writes the log letter")
	d.queue_free()
	await frames(3)

	print("\n==== ending ====")
	var e := spawn_scene("ending")
	await get_tree().create_timer(30.0).timeout
	e.queue_free()
	await frames(2)

	print("\n==== guardian + perfect paths ====")
	for pair in [[1, "guardian"], [0, "perfect"]]:
		GS.new_game()
		GS.start_case("station")
		GS.visit = 2
		for f in ["sp_chart", "sp_regret"]:
			GS.fragments[f] = true
		for k in ["sp_anchor_now", "sp_anchor_earth", "sp_anchor_unknown", "sp_captain_genesis"]:
			GS.set_flag(k)
		d = spawn_scene("dream")
		await frames(5)
		await wait_idle(d)
		d.station.open_hatch()
		Dialog.autoplay_inputs = [""]
		await interact(d, "和星芽", [pair[0]])
		await frames(30)
		check(GS.ending == pair[1], "%s ending (%s)" % [pair[1], GS.ending])
		d.queue_free()
		await frames(3)

	print("\n==== collapse ====")
	GS.new_game()
	GS.start_case("station")
	d = spawn_scene("dream")
	await frames(5)
	await wait_idle(d)
	GS.change_stability(-200.0)
	await frames(40)
	check(GS.last_collapse and GS.last_goto == "clinic", "collapse returns to the clinic without using a dive")
	d.queue_free()
	await frames(3)

	print("\n==== Xiaomian voice-over ====")
	check(Audio.xm_id("你确定吗？") == "xm_d10d3ea645", "GDScript id matches tools/xm_voice.py")
	check(Audio.xm_id("[color=#fff]你确定 吗？\n[/color]") == "xm_d10d3ea645", "ids ignore BBCode and whitespace")
	GS.new_game()
	GS.start_case("station")
	d = spawn_scene("dream")
	await frames(5)
	await wait_idle(d)
	var hint: String = Plat.speech_of(d.story.current_hint)
	check(not hint.contains("Tab") and hint.length() > 4, "device-neutral hint has no key names")
	check(Audio.has_voice("xm_d10d3ea645"), "recorded clips ship with the game")
	d.queue_free()
	await frames(3)
	GS.new_game()
