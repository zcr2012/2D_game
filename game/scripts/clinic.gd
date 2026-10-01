extends Node
## Dream Repair Clinic — the hub between dives. Case file, Xiaomian's
## personality, dream log, fragments, and the dream pod.

const U := preload("res://scripts/ui_util.gd")

const NEWS := [
	"【晨间新闻】梦境共享平台『同眠』用户突破 40 亿，官方提醒：请勿在他人梦中停留超过 6 小时。",
	"【科技】研究称 3.7% 的存储梦境出现『自发生长』现象，专家：『不排除梦境具有某种演化能力。』",
	"【社会】梦境修复师资格考试报名开启，今年新增科目：《AI人格伦理》。",
	"【本地】第七区一位老人委托修复梦境：『街道上少了一个人，但我不知道是谁。』",
	"【国际】太空站『远望』乘员集体做了同一个梦，调查仍在进行中。",
]

var _ticker: Label
var _speech: RichTextLabel
var _bars := {}
var _dive_btn: Button


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	U.nebula(root, 0.55)
	var stage := U.stage(root)

	var header := U.label(stage, "梦境修复所 · 2078", 36, Color(0.5, 0.95, 1.0))
	header.position = Vector2(30, 18)
	var sub := U.label(stage, "DREAM REPAIR CLINIC — 第七区 · 夜班", 24, Color(1, 1, 1, 0.5))
	sub.position = Vector2(32, 62)

	var cols := HBoxContainer.new()
	cols.position = Vector2(24, 104)
	cols.size = Vector2(1232, 500)
	cols.add_theme_constant_override("separation", 16)
	stage.add_child(cols)

	# ---- Xiaomian
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(360, 500)
	cols.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	left.add_child(lv)
	U.label(lv, "梦境助手 · 小眠", 24, Color(0.5, 0.95, 1.0))
	U.portrait(lv, "xiaomian", Vector2(0, 150))
	U.label(lv, "性格：" + GS.trait_name(), 24, Color(1.0, 0.92, 0.6))
	for k in [["warmth", "温柔"], ["doubt", "怀疑"], ["curiosity", "好奇"]]:
		var h := HBoxContainer.new()
		lv.add_child(h)
		var l := U.label(h, k[1], 24)
		l.custom_minimum_size = Vector2(60, 0)
		var pb := ProgressBar.new()
		pb.max_value = 8
		pb.value = GS.xm[k[0]]
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(240, 16)
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(pb)
		_bars[k[0]] = pb
	_speech = U.rich(lv, "", Vector2(320, 120))

	# ---- case file
	var mid := PanelContainer.new()
	mid.custom_minimum_size = Vector2(470, 500)
	cols.add_child(mid)
	var mv := VBoxContainer.new()
	mid.add_child(mv)
	var cd: Dictionary = GS.case_data()
	U.label(mv, "委托档案 " + str(cd["file_id"]), 24, Color(1.0, 0.9, 0.55))
	var size_mb := 128.0 * pow(1.14, GS.visit)
	var choices_txt := ""
	var names := {"repair": "修复", "protect": "守护", "enhance": "增强"}
	for i in GS.core_choices.size():
		choices_txt += "  第%d次：%s\n" % [i + 1, names.get(GS.core_choices[i], "?")]
	if choices_txt == "":
		choices_txt = "  （尚未潜入）\n"
	U.rich(mv, ("[color=#bbbbdd]梦主[/color]  " + str(cd["dreamer"]) + "\n" +
		"[color=#bbbbdd]梦境[/color]  " + str(cd["name"]) + "（" + str(cd["tag"]) + "）\n" +
		"[color=#bbbbdd]症状[/color]  " + str(cd["symptom"]) + "\n" +
		"[color=#bbbbdd]委托人[/color]  " + str(cd["client"]) + "\n\n" +
		"[color=#7ff5ff]梦境文件[/color]  %.1f MB   [color=#7ff5ff]潜入[/color]  %d / %d\n" +
		"[color=#7ff5ff]梦境核心处理记录[/color]\n%s" +
		"[color=#7ff5ff]累计[/color]  修复 %d · 守护 %d · 增强 %d") % [
			size_mb, GS.visit, GS.MAX_DIVES, choices_txt,
			GS.scores["repair"], GS.scores["protect"], GS.scores["enhance"]], Vector2(440, 0))

	# ---- log
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(370, 500)
	cols.add_child(right)
	var rv := VBoxContainer.new()
	right.add_child(rv)
	U.label(rv, "梦境日志", 24, Color(1.0, 0.8, 0.9))
	U.label(rv, "碎片 %d / %d" % [GS.frag_count(), GS.frag_ids().size()], 24, Color(1, 1, 1, 0.7))
	var log_txt := ""
	var mine: Array = []
	for e in GS.dream_log:
		if str(e.get("case", "candy")) == GS.case_id:
			mine.append(e)
	var start: int = max(0, mine.size() - 12)
	for i in range(start, mine.size()):
		var e: Dictionary = mine[i]
		log_txt += "[color=#8888aa]#%d[/color] %s\n" % [int(e.get("dive", 0)), e.get("text", "")]
	if log_txt == "":
		log_txt = "[color=#8888aa]还没有记录。[/color]"
	U.rich(rv, log_txt, Vector2(340, 0))

	# ---- actions
	var actions := HBoxContainer.new()
	actions.position = Vector2(24, 620)
	actions.add_theme_constant_override("separation", 16)
	stage.add_child(actions)
	_dive_btn = U.button(actions, "躺进梦境舱 · 第 %d 次潜入" % GS.dive(), _dive, Vector2(460, 56))
	U.button(actions, "回到标题", func(): GS.goto("title"), Vector2(200, 56))
	_dive_btn.disabled = true

	# ---- ticker
	var tbg := ColorRect.new()
	tbg.color = Color(0, 0, 0, 0.45)
	tbg.anchor_top = 1.0
	tbg.anchor_bottom = 1.0
	tbg.anchor_right = 1.0
	tbg.offset_top = -34
	root.add_child(tbg)
	_ticker = U.label(root, "      ".join(NEWS), 24, Color(1.0, 0.92, 0.6, 0.85))
	_ticker.anchor_top = 1.0
	_ticker.anchor_bottom = 1.0
	_ticker.offset_top = -30
	_ticker.position.x = _screen_w()

	Audio.music("clinic")
	_intro()


func _process(delta: float) -> void:
	_ticker.position.x -= 70.0 * delta
	if _ticker.position.x < -_ticker.size.x:
		_ticker.position.x = _screen_w()


func _screen_w() -> float:
	return get_viewport().get_visible_rect().size.x


func _set_speech(t: String) -> void:
	_speech.text = "[color=#7ff5ff]小眠：[/color]" + t


func _intro() -> void:
	await get_tree().create_timer(0.5).timeout
	if GS.last_collapse:
		GS.last_collapse = false
		await Dialog.say("xm", "呼……梦境崩塌了，我们被弹了出来。别担心，这次不算次数。稳定度快耗光的时候，就少改一点梦吧。")
	if GS.case_id == "street":
		await _intro_street()
		return
	match GS.visit:
		0:
			if not GS.flag("briefed"):
				await Dialog.say("sys", "2078年。人类发明了『梦境存储技术』——梦可以被保存、分享、修改，也可以被修复。")
				await Dialog.say("sys", "于是诞生了一种新的职业：梦境修复师。他们进入别人损坏的梦境，寻找错误记忆、被遗忘的人、虚假的幻想，和AI产生的异常。")
				await Dialog.say("sys", "但是后来有人发现——有些梦，并不是坏掉了，而是在『进化』。")
				await Dialog.say("xm", "早上好，修复师！……啊不对，现在是夜班。晚上好！今天的委托到了。")
				await Dialog.say("xm", "梦主是一个叫朵朵的小女孩。她的梦『糖果城市』已经重复了二十七个晚上，而且每晚都在变大。")
				await Dialog.say("xm", "委托人是朵朵的妈妈。她说：『把她的梦修好，让她像以前一样睡个好觉。』")
				await Dialog.say("xm", "在梦里，%s可以打开梦境编辑器，改变时间、情绪和现实程度。不过每次修改都会消耗梦境稳定度。" % Plat.press("editor"))
				GS.set_flag("briefed")
			_set_speech("准备好了就躺进梦境舱吧，我会跟你一起进去。")
		1:
			_set_speech(_between_line(1))
			await Dialog.say("xm", _between_line(1))
			await Dialog.say("xm", "梦境报告：糖果城市的温度在升高……它好像开始融化了。")
		2:
			_set_speech(_between_line(2))
			await Dialog.say("xm", _between_line(2))
			await Dialog.say("xm", "最后一次潜入了。报告显示……整座城市，变成了一座迷宫。明天就是朵朵的十岁生日。")
		_:
			_set_speech("这个委托已经结束了。")
	_dive_btn.disabled = GS.visit >= GS.MAX_DIVES
	if not _dive_btn.disabled:
		_dive_btn.grab_focus()


func _between_line(v: int) -> String:
	if GS.case_id == "street":
		match GS.xm_trait():
			"doubt":
				return "……糖果城市之后，我一直在想『修好』到底是什么意思。这次，我们先听听梧桐巷想说什么。"
			"warm":
				return "沈念今天来了。她在舱外坐了很久，什么也没说。我想，她也在等一个答案。"
			"curious":
				return "梦境文件变大了——老灯在往街上添新东西。修复师，你不想知道它在造什么吗？"
		return "欢迎回来！第 %d 次潜入的数据已经存档。" % v
	match GS.xm_trait():
		"doubt":
			return "我整理了记录……我们到底是在修复她的梦，还是在修改她？这两件事，好像越来越难分开了。"
		"warm":
			return "欢迎回来。朵朵昨晚翻了三次身，但没有哭。我觉得，这是好事。"
		"curious":
			return "梦境文件又变大了！它在长出我们没见过的结构……修复师，你不好奇吗？"
	return "欢迎回来！第 %d 次潜入的数据已经存档。" % v


func _dive() -> void:
	_dive_btn.disabled = true
	Audio.sfx("shift")
	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(1, 1, 1, 0)
	get_child(0).add_child(fade)
	var t := create_tween()
	t.tween_property(fade, "color:a", 1.0, 1.0)
	await t.finished
	GS.goto("dream")


func _intro_street() -> void:
	match GS.visit:
		0:
			if not GS.flag("briefed_street"):
				await Dialog.say("sys", "［新委托已送达 · DR-0731 · 第七区］")
				await Dialog.say("xm", "第二个委托！梦主是沈远爷爷，82岁，退休的修理工。")
				await Dialog.say("xm", "委托人是他的女儿沈念。她说：『爸爸每晚都在梦里数街上的行人，总是少一个，数不对就不肯醒。』")
				await Dialog.say("xm", "可是……沈念也说，他们家一直只有他们两个人。")
				match GS.xm_trait():
					"doubt": await Dialog.say("xm", "糖果城市之后，我一直在想『修好』到底是什么意思。这次，我想先听听这个梦怎么说。")
					"warm": await Dialog.say("xm", "朵朵后来怎么样了呢……这次，我也想温柔一点。")
					"curious": await Dialog.say("xm", "我有点期待！不知道梧桐巷会长成什么样子。")
					_: await Dialog.say("xm", "这次的梦叫『梧桐巷』，是他年轻时住过的老街。别忘了，梦里的每个细节都可能是线索。")
				GS.set_flag("briefed_street")
			_set_speech("准备好了就躺进梦境舱吧，我会跟你一起进去。")
		1:
			_set_speech(_between_line(1))
			await Dialog.say("xm", _between_line(1))
			await Dialog.say("xm", "梦境报告：梧桐巷的颜色在褪去……街上行人的脸，变得模糊了。")
		2:
			_set_speech(_between_line(2))
			await Dialog.say("xm", _between_line(2))
			await Dialog.say("xm", "最后一次潜入了。报告显示：整条街开始循环——走到尽头，就会回到起点。")
		_:
			_set_speech("这个委托已经结束了。")
	_dive_btn.disabled = GS.visit >= GS.MAX_DIVES
	if not _dive_btn.disabled:
		_dive_btn.grab_focus()
