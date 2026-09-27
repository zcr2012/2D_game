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
	var a := U.label(v, info[0], 36, Color(1, 1, 1, 0.7))
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t := U.label(v, info[1], 72, info[2])
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.3))
	t.add_theme_constant_override("outline_size", 10)

	_lines_box = VBoxContainer.new()
	_lines_box.add_theme_constant_override("separation", 10)
	v.add_child(_lines_box)
	Audio.music("sweet" if GS.ending != "perfect" else "clinic")
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
		GS.fragments.size(), GS.FRAGMENTS.size(), GS.trait_name()]
	var sl := U.label(v, stats, 24, Color(0.5, 0.95, 1.0))
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lp: String = GS.flags.get("letter_path", "")
	if lp != "":
		var ll := U.label(v, "糖心在你的电脑里留下了一封信：\n" + lp, 24, Color(1.0, 0.75, 0.9))
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ll.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		ll.custom_minimum_size = Vector2(1040, 0)
	var th := U.label(v, "感谢游玩 · 《梦境修复师》垂直切片 Demo", 24, Color(1, 1, 1, 0.6))
	th.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(hb)
	var b := U.button(hb, "回到标题", _to_title, Vector2(260, 52))
	b.grab_focus()


func _to_title() -> void:
	GS.delete_save()
	GS.goto("title")
