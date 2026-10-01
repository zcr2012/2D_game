extends Node
## GS — global game state for Dream Repair.
## Holds everything that persists between dives: visits, fragments, choice
## scores, Xiaomian's personality, the dream-editor state and its "residue".

signal editor_changed            # time / emotion / reality changed
signal stats_changed             # stability, scores, personality
signal fragment_added(id: String)
signal toast(text: String)
signal collapsed                 # stability reached 0

const Cases := preload("res://scripts/cases.gd")

const SAVE_PATH := "user://dream_repair_save.json"
const FONT_PATH := "res://assets/fonts/fusion-pixel-12px-proportional-sc.ttf"
const MAX_DIVES := 3

# ------------------------------------------------------------------ data
const FRAGMENTS := {
	"mem_photo": {
		"dream": "candy",
		"type": "memory", "name": "照片：2077年的夏天",
		"desc": "奶奶的糖果店门口，朵朵举着一根比脸还大的棒棒糖。背面写着：『等朵朵十岁，奶奶教你熬糖。』",
		"effect": "解锁隐藏地点：奶奶的糖果店"},
	"mem_diary": {
		"dream": "candy",
		"type": "memory", "name": "日记：不想不难过",
		"desc": "『妈妈说，长大了就不会那么难过了。可是我不想不难过。不难过，就是忘记了。』",
		"effect": "糖心会说出更多真话"},
	"mem_voice": {
		"dream": "candy",
		"type": "memory", "name": "录音：熬糖的声音",
		"desc": "咕嘟，咕嘟。一个苍老的声音在笑：『糖要慢慢熬，人要慢慢长。』",
		"effect": "解锁特殊结局台词"},
	"emo_joy": {
		"dream": "candy", "emo": "joy",
		"type": "emotion", "name": "情绪碎片：快乐",
		"desc": "生日蛋糕上第一根蜡烛的光。",
		"effect": "梦境编辑器：解锁『快乐』（色彩增强，糖浆结晶）"},
	"emo_sad": {
		"dream": "candy", "emo": "sad",
		"type": "emotion", "name": "情绪碎片：悲伤",
		"desc": "作文本《我的奶奶》，最后一句被橡皮擦得发白。",
		"effect": "梦境编辑器：解锁『悲伤』（下雨，显现足迹）"},
	"emo_anger": {
		"dream": "candy", "emo": "anger",
		"type": "emotion", "name": "情绪碎片：愤怒",
		"desc": "熊先生身上被缝了又拆、拆了又缝的那条线。",
		"effect": "梦境编辑器：解锁『愤怒』（建筑破裂，可击碎巧克力墙）"},
	"emo_fear": {
		"dream": "candy", "emo": "fear",
		"type": "emotion", "name": "情绪碎片：恐惧",
		"desc": "一只大人的手表，指针永远停在十点整。",
		"effect": "梦境编辑器：解锁『疯狂梦境』与『噩梦』，开启隐藏区域"},
	"emo_regret": {
		"dream": "candy", "emo": "regret",
		"type": "emotion", "name": "情绪碎片：遗憾",
		"desc": "糖果店柜台上，最后一颗没有吃掉的糖。",
		"effect": "解锁特殊剧情"},

	# ---------------------------------------------------------- dream 2: Old Street
	"st_photo": {
		"dream": "street", "type": "memory", "name": "照片：2041年的夏天",
		"desc": "梧桐巷口，两个人挤在一把伞下。照片左边那个人，被剪掉了半边。背面写着：『等你修好那台收音机，我们就去看海。』",
		"effect": "解锁隐藏地点：照相馆"},
	"st_radio": {
		"dream": "street", "type": "memory", "name": "录音：收音机里的声音",
		"desc": "沙沙……一个温和的女声：『老沈，下雨了，记得带伞——』后面是长长的电流声。",
		"effect": "解锁特殊结局台词"},
	"st_ticket": {
		"dream": "street", "type": "memory", "name": "车票：末班车，只有一张",
		"desc": "一张去海边的车票，日期是她离开的那天。座位号：只有一个。",
		"effect": "老灯会说出更多真话"},
	"st_joy": {
		"dream": "street", "emo": "joy", "type": "emotion", "name": "情绪碎片：快乐",
		"desc": "面馆里，第二碗阳春面升起的热气。",
		"effect": "梦境编辑器：解锁『快乐』（色彩回到街上，褪色的人脸重新浮现）"},
	"st_sad": {
		"dream": "street", "emo": "sad", "type": "emotion", "name": "情绪碎片：悲伤",
		"desc": "雨天积水里的倒影：一把为两个人撑开的伞，其中一个人的位置是空的。",
		"effect": "梦境编辑器：解锁『悲伤』（下雨，积水映出缺失的东西）"},
	"st_anger": {
		"dream": "street", "emo": "anger", "type": "emotion", "name": "情绪碎片：愤怒",
		"desc": "修理铺工作台上的一张维修单，备注栏只有两个字：『随你。』",
		"effect": "梦境编辑器：解锁『愤怒』（卷帘门震裂，可以被撞开）"},
	"st_fear": {
		"dream": "street", "emo": "fear", "type": "emotion", "name": "情绪碎片：恐惧",
		"desc": "一块镜子的碎片。镜子里的老街上，所有人都没有脸，包括你。",
		"effect": "梦境编辑器：解锁『疯狂梦境』与『噩梦』，开启隐藏区域"},
	"st_regret": {
		"dream": "street", "emo": "regret", "type": "emotion", "name": "情绪碎片：遗憾",
		"desc": "照相馆橱窗里最后一张照片的背面，有一行没写完的字：『路上小——』",
		"effect": "解锁特殊剧情"},
}
const FRAGMENT_ORDER := ["mem_photo", "mem_diary", "mem_voice", "emo_joy", "emo_sad", "emo_anger", "emo_fear", "emo_regret",
	"st_photo", "st_radio", "st_ticket", "st_joy", "st_sad", "st_anger", "st_fear", "st_regret"]

const TIME_NAMES := {"day": "白天", "night": "夜晚"}
const EMOTION_NAMES := {"calm": "平静", "happy": "快乐", "sad": "悲伤", "anger": "愤怒"}
const REALITY_NAMES := ["梦境稳定", "幻想增强", "疯狂梦境", "噩梦"]
const TRAIT_NAMES := {"naive": "懵懂", "warm": "温柔", "doubt": "怀疑", "curious": "好奇"}
const STAGE_NAMES := {"sweet": "甜蜜童话", "melting": "融化之城", "maze": "巨大迷宫",
	"summer": "夏夜老街", "fading": "褪色之街", "echo": "回声之街"}

# ------------------------------------------------------------------ state
var case_id := "candy"                 # the dream (commission) being played
## Per-dream progress: id -> {"visit": 0..3, "core": [..], "ending": "", "scores": {..}}
var progress := {}
var fragments := {}                    # id -> true (all dreams)
var flags := {}                        # story flags (persist between dives)
var scores := {"repair": 0, "protect": 0, "enhance": 0}   # all dreams
var xm := {"warmth": 0, "doubt": 0, "curiosity": 0}   # Xiaomian personality (carries over)
var dream_log: Array = []              # [{"dive": n, "case": id, "text": "..."}]
var residue := {"time": "day", "emotion": "calm", "reality": 0}
var last_collapse := false

## These three belong to the CURRENT dream; they are views into `progress`.
var visit: int:                        # completed dives (0..3)
	get:
		return int(_prog()["visit"])
	set(v):
		_prog()["visit"] = v
var core_choices: Array:               # "repair" / "protect" / "enhance" per dive
	get:
		return _prog()["core"]
	set(v):
		_prog()["core"] = v
var ending: String:
	get:
		return str(_prog()["ending"])
	set(v):
		_prog()["ending"] = v

# per-dive (not saved)
var stability := 100.0
var time := "day"
var emotion := "calm"
var reality := 0
var dive_flags := {}

var settings := {"ai_analysis": true, "voice": true, "music_volume": 0.7, "unlock_all": false}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_setup_theme()


# ------------------------------------------------------------------ input map
func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _setup_input() -> void:
	_add_keys("move_up", [KEY_W, KEY_UP])
	_add_keys("move_down", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("interact", [KEY_E, KEY_SPACE])
	_add_keys("editor", [KEY_TAB])
	_add_keys("ask_xm", [KEY_Q])
	_add_keys("fragments", [KEY_I])
	_add_keys("pause", [KEY_ESCAPE])
	# gamepad (Xbox / PlayStation / Switch Pro / Steam Deck)
	_add_pad("move_up", [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add_pad("move_down", [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_add_pad("move_left", [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_pad("move_right", [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_pad("interact", [JOY_BUTTON_A])
	_add_pad("editor", [JOY_BUTTON_Y])
	_add_pad("ask_xm", [JOY_BUTTON_X])
	_add_pad("fragments", [JOY_BUTTON_BACK])
	_add_pad("pause", [JOY_BUTTON_START])
	for a in ["move_up", "move_down", "move_left", "move_right"]:
		InputMap.action_set_deadzone(a, 0.25)


func _add_pad(action: String, buttons: Array, axis := -1, dir := 0.0) -> void:
	for b in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)
	if axis >= 0:
		var m := InputEventJoypadMotion.new()
		m.axis = axis
		m.axis_value = dir
		InputMap.action_add_event(action, m)


# ------------------------------------------------------------------ theme
var theme: Theme
var font: FontFile


func _setup_theme() -> void:
	font = load(FONT_PATH) as FontFile
	if font:
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.hinting = TextServer.HINTING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 24
	theme = Theme.new()
	if font:
		theme.default_font = font
	theme.default_font_size = 24

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.08, 0.06, 0.17, 0.92)
	panel.border_color = Color(0.5, 0.95, 1.0, 0.85)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(6)
	panel.set_content_margin_all(14)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)

	var bn := StyleBoxFlat.new()
	bn.bg_color = Color(0.16, 0.12, 0.3, 0.95)
	bn.border_color = Color(0.55, 0.45, 0.85)
	bn.set_border_width_all(2)
	bn.set_corner_radius_all(4)
	bn.set_content_margin_all(8)
	var bh := bn.duplicate() as StyleBoxFlat
	bh.bg_color = Color(0.28, 0.2, 0.5, 1.0)
	bh.border_color = Color(0.5, 0.95, 1.0)
	var bp := bn.duplicate() as StyleBoxFlat
	bp.bg_color = Color(0.45, 0.25, 0.6, 1.0)
	bp.border_color = Color(1.0, 0.7, 0.85)
	var bd := bn.duplicate() as StyleBoxFlat
	bd.bg_color = Color(0.1, 0.09, 0.16, 0.8)
	bd.border_color = Color(0.3, 0.28, 0.4)
	var bf := bh.duplicate() as StyleBoxFlat
	bf.border_color = Color(1.0, 0.85, 0.4)
	for t in ["Button"]:
		theme.set_stylebox("normal", t, bn)
		theme.set_stylebox("hover", t, bh)
		theme.set_stylebox("pressed", t, bp)
		theme.set_stylebox("disabled", t, bd)
		theme.set_stylebox("focus", t, bf)
	theme.set_color("font_color", "Button", Color(0.95, 0.93, 1.0))
	theme.set_color("font_hover_color", "Button", Color(1, 1, 1))
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.48, 0.6))
	theme.set_color("font_color", "Label", Color(0.95, 0.93, 1.0))
	theme.set_color("default_color", "RichTextLabel", Color(0.95, 0.93, 1.0))

	var le := bn.duplicate() as StyleBoxFlat
	le.bg_color = Color(0.05, 0.04, 0.1, 1.0)
	theme.set_stylebox("normal", "LineEdit", le)
	theme.set_stylebox("focus", "LineEdit", bf)

	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.1, 0.08, 0.2)
	pb_bg.set_corner_radius_all(3)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.5, 0.95, 1.0)
	pb_fill.set_corner_radius_all(3)
	theme.set_stylebox("background", "ProgressBar", pb_bg)
	theme.set_stylebox("fill", "ProgressBar", pb_fill)
	theme.set_constant("outline_size", "Label", 0)
	get_tree().root.theme = theme


# ------------------------------------------------------------------ helpers
func _new_prog() -> Dictionary:
	return {"visit": 0, "core": [], "ending": "", "scores": {"repair": 0, "protect": 0, "enhance": 0}}


func _prog() -> Dictionary:
	if not progress.has(case_id):
		progress[case_id] = _new_prog()
	return progress[case_id]


func case_data(id := "") -> Dictionary:
	return Cases.DATA[id if id != "" else case_id]


func case_name() -> String:
	return str(case_data()["name"])


## Score of the current dream only (the ending thresholds use this).
func case_score(kind: String) -> int:
	return int(_prog()["scores"].get(kind, 0))


func dive() -> int:
	return visit + 1


func stage() -> String:
	var st: Array = case_data()["stages"]
	return str(st[clampi(dive() - 1, 0, st.size() - 1)])


func stage_name() -> String:
	return str(STAGE_NAMES.get(stage(), ""))


func case_done(id: String) -> bool:
	return progress.has(id) and int(progress[id]["visit"]) >= MAX_DIVES


## Dreams the player may start now: the first one, the one after a finished
## one, or everything when the test option is on.
func case_unlocked(id: String) -> bool:
	if not Cases.DATA[id]["available"]:
		return false
	if bool(settings.get("unlock_all", false)):
		return true
	var i: int = Cases.ORDER.find(id)
	return i <= 0 or case_done(str(Cases.ORDER[i - 1]))


## Next available dream after the current one that is not finished ("" = none).
func next_case_id() -> String:
	var i: int = Cases.ORDER.find(case_id)
	for j in range(i + 1, Cases.ORDER.size()):
		var id: String = Cases.ORDER[j]
		if Cases.DATA[id]["available"] and not case_done(id):
			return id
	return ""


func has_later_unavailable_case() -> bool:
	var i: int = Cases.ORDER.find(case_id)
	for j in range(i + 1, Cases.ORDER.size()):
		if not Cases.DATA[Cases.ORDER[j]]["available"]:
			return true
	return false


func start_case(id: String) -> void:
	case_id = id
	residue = {"time": "day", "emotion": "calm", "reality": 0}
	last_collapse = false
	_prog()


## Fragment ids that belong to a dream, in display order.
func frag_ids(id := "") -> Array:
	var cid := id if id != "" else case_id
	var out: Array = []
	for f in FRAGMENT_ORDER:
		if FRAGMENTS[f].get("dream", "candy") == cid:
			out.append(f)
	return out


func frag_count(id := "") -> int:
	var n := 0
	for f in frag_ids(id):
		if fragments.has(f):
			n += 1
	return n


## True once any collected fragment carries this emotion tag ("joy" ...).
func has_emo(tag: String) -> bool:
	for f in fragments.keys():
		if FRAGMENTS.has(f) and FRAGMENTS[f].get("emo", "") == tag:
			return true
	return false


func has_frag(id: String) -> bool:
	return fragments.has(id)


func add_fragment(id: String) -> bool:
	if fragments.has(id):
		return false
	fragments[id] = true
	var f: Dictionary = FRAGMENTS[id]
	add_log("获得 " + f["name"])
	emit_signal("fragment_added", id)
	emit_signal("toast", "获得碎片 · " + f["name"] + "\n" + f["effect"])
	return true


func flag(k: String) -> bool:
	return flags.get(k, false) or dive_flags.get(k, false)


func set_flag(k: String, persistent := true) -> void:
	if persistent:
		flags[k] = true
	else:
		dive_flags[k] = true


func add_log(text: String) -> void:
	dream_log.append({"dive": dive(), "case": case_id, "text": text})


## Record a player action. kind: "repair" | "protect" | "enhance".
## Repairing/erasing makes Xiaomian doubtful, protecting makes it warm,
## enhancing makes it curious.
func act(kind: String, text := "") -> void:
	scores[kind] = scores.get(kind, 0) + 1
	var cs: Dictionary = _prog()["scores"]
	cs[kind] = int(cs.get(kind, 0)) + 1
	match kind:
		"repair": xm["doubt"] += 1
		"protect": xm["warmth"] += 1
		"enhance": xm["curiosity"] += 1
	if text != "":
		add_log(text)
	emit_signal("stats_changed")


func xm_trait() -> String:
	var w: int = xm["warmth"]
	var d: int = xm["doubt"]
	var c: int = xm["curiosity"]
	if max(w, max(d, c)) < 2:
		return "naive"
	if w >= d and w >= c:
		return "warm"
	if d >= w and d >= c:
		return "doubt"
	return "curious"


func trait_name() -> String:
	return TRAIT_NAMES[xm_trait()]


func real_name() -> String:
	for k in ["USERNAME", "USER", "LOGNAME"]:
		var v := OS.get_environment(k)
		if v != "" and v != "root" and not v.begins_with("u0_a"):
			return v
	return ""


# ------------------------------------------------------------------ editor
func is_unlocked(kind: String, value) -> bool:
	match kind:
		"time":
			return true
		"emotion":
			match value:
				"calm": return true
				"happy": return has_emo("joy")
				"sad": return has_emo("sad")
				"anger": return has_emo("anger")
		"reality":
			return int(value) <= 1 or has_emo("fear")
	return false


func lock_hint(kind: String, value) -> String:
	match kind:
		"emotion":
			match value:
				"happy": return "需要『快乐』碎片"
				"sad": return "需要『悲伤』碎片"
				"anger": return "需要『愤怒』碎片"
		"reality":
			return "需要『恐惧』碎片"
	return ""


func edit_cost(kind: String, value) -> int:
	match kind:
		"time": return 6
		"emotion": return 8
		"reality": return 5 + 4 * int(value)
	return 5


func apply_edit(kind: String, value) -> bool:
	if not is_unlocked(kind, value):
		return false
	var cur = {"time": time, "emotion": emotion, "reality": reality}[kind]
	if cur == value:
		return false
	change_stability(-edit_cost(kind, value))
	match kind:
		"time": time = value
		"emotion": emotion = value
		"reality": reality = int(value)
	dive_flags["edited"] = true
	dive_flags["used_" + kind + "_" + str(value)] = true
	emit_signal("editor_changed")
	return true


func change_stability(delta: float) -> void:
	var before := stability
	stability = clamp(stability + delta, 0.0, 100.0)
	emit_signal("stats_changed")
	if before > 0.0 and stability <= 0.0:
		emit_signal("collapsed")


func editor_summary() -> String:
	return "%s · %s · %s" % [TIME_NAMES[time], EMOTION_NAMES[emotion], REALITY_NAMES[reality]]


# ------------------------------------------------------------------ dive lifecycle
func begin_dive() -> void:
	stability = 100.0
	dive_flags = {}
	time = residue.get("time", "day")
	emotion = residue.get("emotion", "calm")
	reality = int(residue.get("reality", 0))
	# never start above what is unlocked
	if not is_unlocked("emotion", emotion):
		emotion = "calm"
	if not is_unlocked("reality", reality):
		reality = 0
	last_collapse = false


func end_dive(core_choice: String) -> void:
	core_choices.append(core_choice)
	residue = {"time": time, "emotion": emotion, "reality": reality}
	visit += 1
	save_game()


func collapse_dive() -> void:
	# the dive does not count; the dream resets to a calm state
	residue = {"time": "day", "emotion": "calm", "reality": 0}
	last_collapse = true
	add_log("梦境崩塌，被强制唤醒")
	save_game()


func new_game() -> void:
	case_id = "candy"
	progress = {}
	fragments = {}
	flags = {}
	scores = {"repair": 0, "protect": 0, "enhance": 0}
	xm = {"warmth": 0, "doubt": 0, "curiosity": 0}
	dream_log = []
	residue = {"time": "day", "emotion": "calm", "reality": 0}
	last_collapse = false


# ------------------------------------------------------------------ save
func save_game() -> void:
	if test_mode:
		return
	var data := {
		"version": 2, "case_id": case_id, "progress": progress,
		"fragments": fragments, "flags": flags, "scores": scores,
		"xm": xm, "dream_log": dream_log,
		"residue": residue, "last_collapse": last_collapse,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if test_mode or not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return false
	new_game()
	if data.has("progress"):
		var pr: Dictionary = data["progress"]
		for cid in pr.keys():
			if not Cases.DATA.has(cid):
				continue
			var e: Dictionary = pr[cid]
			var np := _new_prog()
			np["visit"] = int(e.get("visit", 0))
			np["core"] = e.get("core", [])
			np["ending"] = str(e.get("ending", ""))
			for k in ["repair", "protect", "enhance"]:
				np["scores"][k] = int(e.get("scores", {}).get(k, 0))
			progress[cid] = np
		var cur := str(data.get("case_id", "candy"))
		case_id = cur if Cases.DATA.has(cur) else "candy"
	else:
		# version 1 save (Candy City only)
		var np1 := _new_prog()
		np1["visit"] = int(data.get("visit", 0))
		np1["core"] = data.get("core_choices", [])
		np1["ending"] = str(data.get("ending", ""))
		for k in ["repair", "protect", "enhance"]:
			np1["scores"][k] = int(data.get("scores", {}).get(k, 0))
		progress["candy"] = np1
	fragments = data.get("fragments", {})
	flags = data.get("flags", {})
	for k in scores.keys():
		scores[k] = int(data.get("scores", {}).get(k, 0))
	for k in xm.keys():
		xm[k] = int(data.get("xm", {}).get(k, 0))
	dream_log = data.get("dream_log", [])
	var r: Dictionary = data.get("residue", {})
	residue = {"time": r.get("time", "day"), "emotion": r.get("emotion", "calm"), "reality": int(r.get("reality", 0))}
	last_collapse = data.get("last_collapse", false)
	return true


func delete_save() -> void:
	if test_mode:
		return
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ------------------------------------------------------------------ scene helper
var test_mode := false          # set by tests/smoke.gd: scene changes are recorded, not performed
var last_goto := ""


func goto(scene: String) -> void:
	last_goto = scene
	if test_mode:
		print("  >> goto ", scene)
		return
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene)
