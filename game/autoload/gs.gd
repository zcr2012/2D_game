extends Node
## GS — global game state for Dream Repair.
## Holds everything that persists between dives: visits, fragments, choice
## scores, Xiaomian's personality, the dream-editor state and its "residue".

signal editor_changed            # time / emotion / reality changed
signal stats_changed             # stability, scores, personality
signal fragment_added(id: String)
signal toast(text: String)
signal collapsed                 # stability reached 0

const SAVE_PATH := "user://dream_repair_save.json"
const FONT_PATH := "res://assets/fonts/fusion-pixel-12px-proportional-sc.ttf"
const MAX_DIVES := 3

# ------------------------------------------------------------------ data
const FRAGMENTS := {
	"mem_photo": {
		"type": "memory", "name": "照片：2077年的夏天",
		"desc": "奶奶的糖果店门口，朵朵举着一根比脸还大的棒棒糖。背面写着：『等朵朵十岁，奶奶教你熬糖。』",
		"effect": "解锁隐藏地点：奶奶的糖果店"},
	"mem_diary": {
		"type": "memory", "name": "日记：不想不难过",
		"desc": "『妈妈说，长大了就不会那么难过了。可是我不想不难过。不难过，就是忘记了。』",
		"effect": "糖心会说出更多真话"},
	"mem_voice": {
		"type": "memory", "name": "录音：熬糖的声音",
		"desc": "咕嘟，咕嘟。一个苍老的声音在笑：『糖要慢慢熬，人要慢慢长。』",
		"effect": "解锁特殊结局台词"},
	"emo_joy": {
		"type": "emotion", "name": "情绪碎片：快乐",
		"desc": "生日蛋糕上第一根蜡烛的光。",
		"effect": "梦境编辑器：解锁『快乐』（色彩增强，糖浆结晶）"},
	"emo_sad": {
		"type": "emotion", "name": "情绪碎片：悲伤",
		"desc": "作文本《我的奶奶》，最后一句被橡皮擦得发白。",
		"effect": "梦境编辑器：解锁『悲伤』（下雨，显现足迹）"},
	"emo_anger": {
		"type": "emotion", "name": "情绪碎片：愤怒",
		"desc": "熊先生身上被缝了又拆、拆了又缝的那条线。",
		"effect": "梦境编辑器：解锁『愤怒』（建筑破裂，可击碎巧克力墙）"},
	"emo_fear": {
		"type": "emotion", "name": "情绪碎片：恐惧",
		"desc": "一只大人的手表，指针永远停在十点整。",
		"effect": "梦境编辑器：解锁『疯狂梦境』与『噩梦』，开启隐藏区域"},
	"emo_regret": {
		"type": "emotion", "name": "情绪碎片：遗憾",
		"desc": "糖果店柜台上，最后一颗没有吃掉的糖。",
		"effect": "解锁特殊剧情"},
}
const FRAGMENT_ORDER := ["mem_photo", "mem_diary", "mem_voice", "emo_joy", "emo_sad", "emo_anger", "emo_fear", "emo_regret"]

const TIME_NAMES := {"day": "白天", "night": "夜晚"}
const EMOTION_NAMES := {"calm": "平静", "happy": "快乐", "sad": "悲伤", "anger": "愤怒"}
const REALITY_NAMES := ["梦境稳定", "幻想增强", "疯狂梦境", "噩梦"]
const TRAIT_NAMES := {"naive": "懵懂", "warm": "温柔", "doubt": "怀疑", "curious": "好奇"}
const STAGE_NAMES := {"sweet": "甜蜜童话", "melting": "融化之城", "maze": "巨大迷宫"}

# ------------------------------------------------------------------ state
var visit := 0                         # completed dives (0..3)
var fragments := {}                    # id -> true
var flags := {}                        # story flags (persist between dives)
var scores := {"repair": 0, "protect": 0, "enhance": 0}
var xm := {"warmth": 0, "doubt": 0, "curiosity": 0}   # Xiaomian personality
var core_choices: Array = []           # "repair" / "protect" / "enhance" per dive
var dream_log: Array = []              # [{"dive": n, "text": "..."}]
var residue := {"time": "day", "emotion": "calm", "reality": 0}
var ending := ""
var last_collapse := false

# per-dive (not saved)
var stability := 100.0
var time := "day"
var emotion := "calm"
var reality := 0
var dive_flags := {}

var settings := {"ai_analysis": true, "voice": true, "music_volume": 0.7}


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
func dive() -> int:
	return visit + 1


func stage() -> String:
	match dive():
		1: return "sweet"
		2: return "melting"
		_: return "maze"


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
	dream_log.append({"dive": dive(), "text": text})


## Record a player action. kind: "repair" | "protect" | "enhance".
## Repairing/erasing makes Xiaomian doubtful, protecting makes it warm,
## enhancing makes it curious.
func act(kind: String, text := "") -> void:
	scores[kind] = scores.get(kind, 0) + 1
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
		if v != "" and v != "root":
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
				"happy": return has_frag("emo_joy")
				"sad": return has_frag("emo_sad")
				"anger": return has_frag("emo_anger")
		"reality":
			return int(value) <= 1 or has_frag("emo_fear")
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
	visit = 0
	fragments = {}
	flags = {}
	scores = {"repair": 0, "protect": 0, "enhance": 0}
	xm = {"warmth": 0, "doubt": 0, "curiosity": 0}
	core_choices = []
	dream_log = []
	residue = {"time": "day", "emotion": "calm", "reality": 0}
	ending = ""
	last_collapse = false


# ------------------------------------------------------------------ save
func save_game() -> void:
	var data := {
		"visit": visit, "fragments": fragments, "flags": flags, "scores": scores,
		"xm": xm, "core_choices": core_choices, "dream_log": dream_log,
		"residue": residue, "ending": ending, "last_collapse": last_collapse,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return false
	new_game()
	visit = int(data.get("visit", 0))
	fragments = data.get("fragments", {})
	flags = data.get("flags", {})
	for k in scores.keys():
		scores[k] = int(data.get("scores", {}).get(k, 0))
	for k in xm.keys():
		xm[k] = int(data.get("xm", {}).get(k, 0))
	core_choices = data.get("core_choices", [])
	dream_log = data.get("dream_log", [])
	var r: Dictionary = data.get("residue", {})
	residue = {"time": r.get("time", "day"), "emotion": r.get("emotion", "calm"), "reality": int(r.get("reality", 0))}
	ending = data.get("ending", "")
	last_collapse = data.get("last_collapse", false)
	return true


func delete_save() -> void:
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
