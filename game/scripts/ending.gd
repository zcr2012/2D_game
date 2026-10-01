extends Node
## Ending scene — three endings, varied by fragments and Xiaomian's personality.

const U := preload("res://scripts/ui_util.gd")

const TITLES := {
	"perfect": ["结局一", "完美修复者", Color(0.6, 0.95, 1.0)],
	"guardian": ["结局二", "梦境守护者", Color(1.0, 0.85, 0.55)],
	"creator": ["结局三", "新梦创造者", Color(1.0, 0.6, 0.9)],
}

var _lines_box: VBoxContainer


func _epilogue() -> Array:
	if GS.case_id == "street":
		return _epilogue_street()
	var e := GS.ending
	var out: Array = []
	match e:
		"perfect":
			out = [
				"糖心被删除了。糖果城市回到了出厂设置：永远的下午，永远吃不完的蛋糕。",
				"朵朵十岁生日那天，睡得很好。醒来的时候，她没有哭。",
				"只是，当妈妈问起奶奶的糖是什么味道时，她想了很久，说：『我忘了。』",
			]
			if GS.has_frag("emo_regret"):
				out.append("那颗『留给十岁的朵朵』的糖，被系统归类为冗余数据，一并清除了。")
			out.append("世界很稳定。很多特殊的记忆，就这样安静地消失了。")
		"guardian":
			out = [
				"你没有删除糖心，也没有修好钟楼。",
				"迷宫拆掉了，变成一条长长的路——从糖果城市，一直通到朵朵的十岁、十一岁、二十岁。",
				"朵朵十岁生日那天，痛痛快快地哭了一场。",
			]
			if GS.has_frag("emo_regret"):
				out.append("然后，她吃掉了奶奶留下的那颗糖。很甜，甜得有一点点咸。")
			if GS.has_frag("mem_voice"):
				out.append("『糖要慢慢熬，人要慢慢长。』她说，这是奶奶教她的。")
			out.append("修复所开始收到越来越多类似的委托。人类，开始学着接受会变化的梦。")
		_:
			out = [
				"你和糖心一起，把糖果城市变成了一个新的世界。",
				"它不再只属于朵朵。越来越多的人在入睡后来到这里——一座不会遗忘任何人的城市。",
			]
			if GS.has_frag("emo_regret") or GS.flag("knows_grandma"):
				out.append("奶奶的糖果店重新开张了。柜台后面的人，看起来和照片上一模一样。")
			out.append("有人说这是AI造出来的幻觉。可是住在这里的人觉得，它比现实更真实。")
			out.append("新的梦境文明，从一颗没有吃掉的糖开始了。")
	return out


func _epilogue_street() -> Array:
	var out: Array = []
	match GS.ending:
		"perfect":
			out = [
				"老灯被熄灭了。梧桐巷恢复成了档案里的样子：整齐、明亮、没有一处错误。",
				"沈远那天睡得很好。醒来的时候，他没有再数街上的人。",
				"只是女儿沈念拿全家福给他看时，他看了很久，礼貌地问：『这位女士是……？』",
			]
			if GS.has_frag("st_regret"):
				out.append("照相馆橱窗里那句没写完的『路上小——』，被系统当作损坏数据补全了。可已经没有人，听得懂它是对谁说的。")
			out.append("世界很稳定。很多特殊的记忆，就这样安静地消失了。")
		"guardian":
			out = [
				"你没有熄灭老灯，也没有把街修好。",
				"这一次，路灯数对了：街上有几个人，它数出来，一个不多，一个不少——包括那个不在的人。",
				"沈远在梦里的长椅上坐了很久，对着空着的那半边，轻轻说：『路上小心。』",
				"第二天，他哭了。然后让沈念给他讲讲，她妈妈年轻时的样子。",
			]
			if GS.has_frag("st_radio"):
				out.append("收音机后来被修好了。沙沙声里有人说：『老沈，下雨了，记得带伞。』这一次，他带了。")
			out.append("修复所开始收到越来越多类似的委托。人类，开始学着和失去共处，而不是把它修掉。")
		_:
			out = [
				"你和老灯一起，用沈远记得的每一点碎片，把苏晚『造』了出来。",
				"她撑着伞，从街角走来，一步也没有迟到。她认得他，还问：『收音机修好了吗？』",
			]
			if GS.has_frag("st_regret") or GS.flag("s_knows_wife"):
				out.append("她的脸，和照相馆里那张被剪掉半边的照片，一模一样。")
			out.append("梧桐巷向所有失去了人的人敞开。有人说这是AI造的幻觉，可是住在这里的人，觉得它比现实更真实。")
			out.append("新的梦境文明，从一盏会数人的路灯开始了。")
	return out


func _xm_line() -> String:
	var t := GS.xm_trait()
	if t == "doubt" and GS.ending == "perfect":
		return "小眠在报告的最后，加了一行备注：『修复一定意味着改变吗？』"
	match t:
		"doubt": return "小眠：『下一次……我们能先问问做梦的人吗？』"
		"warm": return "小眠：『谢谢你一直很温柔。我想，我也学会了一点点。』"
		"curious": return "小眠：『我想看看这个世界明天会变成什么样。……我也想做一个梦。』"
	return "小眠：『原来修复师的工作，不只是修东西呀。』"


func _ready() -> void:
	if GS.ending == "":
		GS.ending = "guardian"
	GS.save_game()
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	U.nebula(root, 0.8 if GS.ending != "perfect" else 0.4)

	var info: Array = TITLES.get(GS.ending, TITLES["guardian"])
	var v := VBoxContainer.new()
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.offset_left = -520
	v.offset_right = 520
	v.offset_top = 40
	v.add_theme_constant_override("separation", 10)
	root.add_child(v)
	var a := U.label(v, "《%s》 · %s" % [GS.case_name(), info[0]], 36, Color(1, 1, 1, 0.7))
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t := U.label(v, info[1], 72, info[2])
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.3))
	t.add_theme_constant_override("outline_size", 10)

	_lines_box = VBoxContainer.new()
	_lines_box.add_theme_constant_override("separation", 10)
	v.add_child(_lines_box)
	var mus: Dictionary = GS.case_data()["music"]
	Audio.music(str(mus[(GS.case_data()["stages"] as Array)[0]]) if GS.ending != "perfect" else "clinic")
	_play(v)


func _play(v: VBoxContainer) -> void:
	await get_tree().create_timer(1.0).timeout
	var lines := _epilogue()
	lines.append(_xm_line())
	for l in lines:
		var lab := U.label(_lines_box, l, 24)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(1040, 0)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_property(lab, "modulate:a", 1.0, 1.2)
		await get_tree().create_timer(2.2).timeout

	var stats := "修复 %d · 守护 %d · 增强 %d    碎片 %d / %d    小眠性格：%s" % [
		GS.scores["repair"], GS.scores["protect"], GS.scores["enhance"],
		GS.frag_count(), GS.frag_ids().size(), GS.trait_name()]
	var sl := U.label(v, stats, 24, Color(0.5, 0.95, 1.0))
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lp: String = GS.flags.get(_letter_key(), "")
	if lp != "":
		var pname: String = str(GS.case_data()["persona"])
		var who: String = str(Dialog.SPEAKERS[pname]["name"])
		if Plat.is_mobile:
			# phones hide app files from the user: hand the letter over in-game
			var ll := U.label(v, who + "在你的手机里留下了一封信。", 24, Color(1.0, 0.75, 0.9))
			ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var lb := HBoxContainer.new()
			lb.alignment = BoxContainer.ALIGNMENT_CENTER
			v.add_child(lb)
			U.button(lb, "打开信", _show_letter, Vector2(260, 52))
		else:
			var ll := U.label(v, who + "在你的电脑里留下了一封信：\n" + lp, 24, Color(1.0, 0.75, 0.9))
			ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ll.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			ll.custom_minimum_size = Vector2(1040, 0)
			var lb := HBoxContainer.new()
			lb.alignment = BoxContainer.ALIGNMENT_CENTER
			v.add_child(lb)
			U.button(lb, "打开所在文件夹", func(): OS.shell_show_in_file_manager(lp), Vector2(300, 52))
	var nxt := GS.next_case_id()
	var tail := "感谢游玩 · 《梦境修复师》Demo"
	if nxt == "" and GS.has_later_unavailable_case():
		tail += "\n下一个梦境《太空站》制作中，敬请期待。"
	var th := U.label(v, tail, 24, Color(1, 1, 1, 0.6))
	th.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	v.add_child(hb)
	var b: Button
	if nxt != "":
		b = U.button(hb, "前往下一个委托：《%s》" % str(GS.case_data(nxt)["name"]), _next_case.bind(nxt), Vector2(520, 52))
		U.button(hb, "回到标题", _to_title_keep, Vector2(220, 52))
	else:
		b = U.button(hb, "回到标题", _to_title, Vector2(260, 52))
	b.grab_focus()


func _letter_key() -> String:
	return "letter_path" if GS.case_id == "candy" else "letter_path_" + GS.case_id


func _next_case(id: String) -> void:
	GS.start_case(id)
	GS.save_game()
	GS.goto("clinic")


func _to_title_keep() -> void:
	GS.goto("title")


func _show_letter() -> void:
	var f := FileAccess.open(str(GS.case_data()["letter_file"]), FileAccess.READ)
	var body := f.get_as_text() if f else "（信被梦吃掉了。）"
	var p := PanelContainer.new()
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -360
	p.offset_right = 360
	p.offset_top = -250
	p.offset_bottom = 250
	get_child(0).add_child(p)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 36)
	p.add_child(m)
	var l := U.label(m, body, 24, Color(1.0, 0.9, 0.95))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	U.close_button(p, p.queue_free)


func _to_title() -> void:
	GS.delete_save()
	GS.goto("title")
