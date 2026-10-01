extends RefCounted
## StoryStreet — all narrative content & events for Dream 2: 梧桐巷 (Old Street).
## Theme: regret. The dreamer 沈远 counts the people on his street and is
## always one short; the missing one is his late wife 苏晚. The dream persona
## 老灯 (a street lamp) is trying to rebuild her out of his fragments.
##
## Same interface as story.gd (Candy City): populate / intro / ask_xm /
## on_fragment / on_editor_changed / on_editor_closed / collapse /
## break_wall / glitch, so dream.gd and hud.gd don't care which one runs.

var d   # the dream scene

var _hint_seen := {}
var _chat_history: Array = []

const GLITCHES := {
	"chalk": {
		"title": "错误记忆",
		"desc": "电线杆上画满了粉笔的『正』字，一笔一笔，爬满了整根杆子。最后一个字，永远只有四笔。",
		"repair": "你补上了最后一笔。可杆子上立刻又冒出了新的一行。",
		"protect": "你没有动它。四笔，也算是一个完整的结尾。",
		"enhance": "粉笔字沿着杆子往上爬，爬到灯罩上，变成了一圈小小的光晕。"},
	"umbrella": {
		"title": "被遗忘的东西",
		"desc": "路边靠着一把长柄伞，伞尖朝下，在地上洇出一小片永远不干的水渍。伞柄上刻着一个『晚』字。",
		"repair": "伞被收进了档案柜。地上的水渍也干了。",
		"protect": "你把伞靠回墙边。伞柄上的『晚』字，握在手里有一点烫。",
		"enhance": "伞缓缓自己撑开了。伞下的阴影里，隐约站着一个人的轮廓。"},
	"cups": {
		"title": "虚假的幻想",
		"desc": "小桌上永远摆着两碗热腾腾的阳春面。其中一碗没有人动过，面却一直没有坨。",
		"repair": "两碗面都凉了，凉得很自然。",
		"protect": "你坐下来，把没人动的那碗往旁边挪了半寸，像是给谁让座。",
		"enhance": "面碗里的热气升上去，在半空里画出一个人的侧影。"},
	"clock": {
		"title": "错误记忆",
		"desc": "旧挂钟的指针停在下午三点十分。钟面玻璃上有一道指甲划出的痕，像是有人想把时间拨回去。",
		"repair": "指针走动了。滴答，滴答——时间终于过去了。",
		"protect": "你没有拨它。三点十分，是他们最后一次说话的时间。",
		"enhance": "钟面裂开一道缝，缝里传出一小段收音机的沙沙声。"},
	"ledger": {
		"title": "AI异常",
		"desc": "半空中悬着一本发光的账本，每一页都只写着同一行：\n[color=#7ff5ff]今夜行人：N − 1[/color]",
		"repair": "账本被合上、归档。远处的路灯微微暗了一下。",
		"protect": "你给账本加了一条批注：『已阅，仍在统计』。",
		"enhance": "账本自己翻到最后一页，多出一行：[color=#7ff5ff]N + 1 ——（待确认）[/color]"},
	"calls": {
		"title": "AI异常",
		"desc": "街角的旧电话亭里，听筒悬在半空，传出一个合成的女声：『老沈，下雨了。老沈，下雨了。』",
		"repair": "声音被清除了。电话亭里只剩下一点点电流声。",
		"protect": "你把听筒轻轻挂了回去。",
		"enhance": "合成音学会了新的一句：[color=#7ff5ff]『……路上小心。』[/color]"},
}

const FACELESS_V1 := [
	["（行人没有回头，只是一直在往前走。）", "一、二、三……你也是来数的吗？"],
	["这条街上，每个人都有地方去。", "可是……我好像忘了，我是要去哪儿。"],
]
const FACELESS_V2 := [
	["（他的脸是一块光滑的空白。）", "我是……对了，我是做钟表的。我记得我有一张脸。"],
	["（她抱着一篮菜，站着不动。）", "我每天都来买菜。买给谁吃来着？"],
	["（那个人影在原地，一遍一遍系着鞋带。）", "我在等人。我也不知道等谁。"],
	["（一个孩子的轮廓拉着你的衣角。）", "你看见我妈妈了吗？她……长什么样？"],
]
const FACES_V2 := [
	["热气掠过他的脸，轮廓里浮出了一副圆眼镜。『是我，老周！修钟表的老周！』", "他高兴地晃了晃手腕：『对了，老沈那只表，是我修的。』"],
	["她的脸慢慢浮了出来，圆圆的，笑起来有酒窝。『我是阿香，卖菜的。』", "『每次苏晚来，我都多给她抓一把葱。』"],
	["他低头系好了鞋带，脸浮了上来。『我是小贵，送报纸的！』", "『我在等苏阿姨，她每天给我塞一块糖。』"],
	["孩子的脸亮了起来，是个扎羊角辫的小女孩。『妈妈！』她朝巷口跑去了。", "你没有看见她的妈妈。但她好像，自己找到了。"],
]


func _init(dream) -> void:
	d = dream


func objective(t: String) -> void:
	d.hud.set_objective(t)


func give(id: String) -> void:
	if GS.add_fragment(id):
		Audio.sfx("pickup")
		var data: Dictionary = GS.FRAGMENTS[id]
		await Dialog.say("file", "[color=#ffd6e6]%s[/color]\n%s" % [data["name"], data["desc"]])
		await on_fragment(id)


# ================================================================== populate
func populate() -> void:
	var sm = d.street
	var lamp: Node2D = d.add_npc("laodeng", "laodeng", Vector2(880, 440), "和老灯说话", ev_lamp)
	var ls: Sprite2D = d.sprite_of(lamp)
	ls.offset.y -= 4
	d.lamps.append(lamp)
	sm.lamp_node = lamp
	d.add_npc("fubo", "fubo", Vector2(572, 352), "和福伯说话", ev_fubo)
	d.add_npc("shenyuan", "shenyuan", Vector2(1572, 516), "和沈远说话", ev_shenyuan)

	d.add_interact(sm.signpost, "路牌", ev_signpost, 40.0, Callable(), Vector2(0, 14))
	d.add_interact(sm.shop_spot, "老沈修理", ev_shop, 46.0, func() -> bool: return sm.shop_shutter == null)
	d.add_interact(sm.studio_spot, "晚照相馆", ev_studio, 46.0, func() -> bool: return sm.alley_gate == null and (d.nodes["studio"] as Node2D).visible)
	d.add_interact(d.nodes["window"], "亮着灯的窗户", ev_window, 38.0, Callable(), Vector2(30, 52))
	d.add_interact(d.nodes["bench"], "长椅", ev_bench, 46.0, Callable(), Vector2(0, 16))

	match GS.stage():
		"summer": _pop_summer()
		"fading": _pop_fading()
		_: _pop_echo()
	_add_missing_fragments()


func _add_faceless(idx: int, pos: Vector2, tint: Color) -> void:
	var n: Node2D = d.add_npc("np%d" % idx, "faceless", pos, "和路人说话", ev_faceless.bind(idx))
	n.modulate = tint


func _pop_summer() -> void:
	_add_faceless(0, Vector2(330, 420), Color(1.0, 0.92, 0.8))
	_add_faceless(1, Vector2(700, 345), Color(0.9, 0.95, 1.0))
	d.add_glitch(Vector2(420, 348), "chalk")
	d.add_glitch(Vector2(1380, 520), "umbrella")
	d.add_glitch(Vector2(660, 400), "cups")


func _pop_fading() -> void:
	_add_faceless(0, Vector2(330, 420), Color(0.9, 0.9, 0.95))
	_add_faceless(1, Vector2(700, 345), Color(0.9, 0.9, 0.95))
	_add_faceless(2, Vector2(1230, 440), Color(0.9, 0.9, 0.95))
	_add_faceless(3, Vector2(1520, 440), Color(0.9, 0.9, 0.95))
	d.add_glitch(Vector2(450, 348), "cups")
	d.add_glitch(Vector2(760, 350), "clock")
	d.add_glitch(Vector2(1300, 520), "umbrella")


func _pop_echo() -> void:
	d.add_glitch(Vector2(300, 348), "chalk")
	d.add_glitch(Vector2(1000, 450), "ledger")
	d.add_glitch(Vector2(1450, 480), "calls")
	# the sad echo: a puddle that shows what is missing
	var pd: Node2D = d.add_prop("st_puddle", Vector2(740, 480))
	pd.z_index = -7
	pd.scale = Vector2(1.4, 1.4)
	d.sad_only.append(pd)
	d.lamps.append(pd)
	d.add_interact(pd, "积水里的倒影", ev_echo_puddle, 40.0, Callable(), Vector2(0, -4))
	d.nodes["echo_puddle"] = pd


func _add_missing_fragments() -> void:
	if not GS.has_frag("st_photo"):
		var pl: Node2D = d.add_prop("st_planter", Vector2(345, 574))
		d.add_interact(pl, "花盆", ev_planter.bind(pl), 36.0, Callable(), Vector2(0, 6))
		d.nodes["planter"] = pl
	if not GS.has_frag("st_sad"):
		# only shows at night (the sad emotion itself is unlocked by this fragment)
		var pd: Node2D = d.add_prop("st_puddle", Vector2(1535, 530))
		pd.z_index = -7
		pd.visible = false
		d.night_only.append(pd)
		d.lamps.append(pd)
		d.add_interact(pd, "发光的积水", ev_sad_puddle.bind(pd), 36.0, Callable(), Vector2(0, -4))
	if GS.stage() != "summer" and not GS.has_frag("st_ticket"):
		d.spawn_fragment("st_ticket", Vector2(1665, 505), d.madness_only)


# ================================================================== intro
func residue_lines() -> Array:
	var out: Array = []
	var r: Dictionary = GS.residue
	match r.get("emotion", "calm"):
		"anger": out.append("上次离开时，情绪停在『愤怒』——街上的砖缝还在微微震动。")
		"sad": out.append("上次离开时梦在下雨，积水到现在还没有干。")
		"happy": out.append("上次你留下了『快乐』，面馆的热气到现在还没散。")
	if r.get("time", "day") == "night":
		out.append("我们上次在夜里离开，所以这次，梦也从夜晚开始。")
	if int(r.get("reality", 0)) >= 2:
		out.append("上次的现实程度太高了……招牌上的字还没有排回原位。")
	if out.size() > 0:
		out.append("（梦会记住你离开时的样子：编辑器保留了上次的设置。）")
	return out


func intro() -> void:
	await d.get_tree().create_timer(0.8).timeout
	match GS.stage():
		"summer":
			await Dialog.say("sys", "［梦境接入中……  委托编号 DR-0731 · 梦主：沈远，82岁 · 梦境：梧桐巷］")
			await Dialog.say("xm", "好暖的夏夜……梧桐树、旧路灯、面馆的灯牌。这就是沈远爷爷年轻时住过的老街。", "street_intro_v1")
			await Dialog.say("xm", "可是……街上好安静。他每晚都在这里数行人，可我没看见几个人。")
			await Dialog.say("xm", Plat.controls_intro())
			objective("找到梦主沈远（他好像在东边的车站长椅旁）")
		"fading":
			await Dialog.say("sys", "［第二次接入 · 梦境色彩饱和度 −38% · 检测到空间断裂］")
			if GS.last_collapse:
				await Dialog.say("xm", "上次梦境崩塌了……这次小心点，别把稳定度耗光。")
			await Dialog.say("xm", "梧桐巷……在褪色。街灯、面馆、梧桐树，都只剩一层薄薄的灰。街中间还裂开了一道口子。", "street_intro_v2")
			var prev: String = str(GS.core_choices[0]) if GS.core_choices.size() > 0 else ""
			match prev:
				"repair": await Dialog.say("xm", "上次我们熄了老灯的一部分……这条街好像更冷了。")
				"protect": await Dialog.say("xm", "上次我们什么都没动。梦自己，一点一点地褪下去了。")
				"enhance": await Dialog.say("xm", "上次你给老灯注入了能量……它是不是，在用这条街的颜色在『造』什么？")
			for l in residue_lines():
				await Dialog.say("xm", l)
			objective("越过街心的裂缝，去车站找沈远")
		_:
			await Dialog.say("sys", "［第三次接入 · 警告：空间闭环 · AI生成内容占比 74%］")
			if GS.last_collapse:
				await Dialog.say("xm", "上次梦境崩塌了……这次小心点。")
			await Dialog.say("xm", "街道……合上了。往东走到尽头，一团雾会把你送回起点。像是一个闭合的圈。", "street_intro_v3")
			for l in residue_lines():
				await Dialog.say("xm", l)
			await Dialog.say("xm", "这条街在『回声』——它把沈远记得的几件事，一遍一遍地重放。找到它们，也许雾就会散。")
			await Dialog.say("xm", "被遗忘的人会在街上游荡。现实程度越高，它们越多、越快。被抓到会被送回入口。")
			objective("找到让雾散去的办法（夜晚、雨水、招牌……）")


# ================================================================== NPCs
func ev_lamp() -> void:
	match GS.stage():
		"summer":
			if not GS.flag("v1_sy"):
				await _lamp_first_meeting()
			else:
				if not GS.flag("v1_ld"):
					await _lamp_v1()
				await core_choice()
		"fading":
			if not GS.flag("v2_sy"):
				await Dialog.say("ld", "……三十一、三十二、少一个。")
				await Dialog.say("ld", "想见他，就过桥去。街断了，路灯可没断——让它们飘起来，不就行了？")
				if GS.reality < 1:
					await Dialog.say("xm", "幻想增强……会让路灯飘起来吗？打开梦境编辑器（%s）看看。" % Plat.k("editor"))
			else:
				if not GS.flag("v2_ld"):
					await _lamp_v2()
				await core_choice()
		_:
			await _lamp_v3()


func _lamp_first_meeting() -> void:
	if not GS.flag("met_ld"):
		GS.set_flag("met_ld")
		await Dialog.say("ld", "……一百二十五，一百二十六。咦？又多了两个新面孔。")
		await Dialog.say("ld", "你们是新来的？别紧张，我只是盏灯。数人，是我唯一会做的事。")
		await Dialog.say("xm", "路灯……会说话？它的数据签名，不在任何模板里。")
		await Dialog.say("ld", "去街那头看看那位老人家吧。他每晚都站在那儿，和我一起数。数不对的话，他不肯睡。")
		objective("去东边车站，找沈远")
	else:
		await Dialog.say("ld", "一、二、三……去吧，他在东边等。")


func _lamp_v1() -> void:
	await Dialog.say("ld", "见过他了？他数的，和我数的，是同一批人。我们总是差一个。")
	await Dialog.say("ld", "三年，一千零九十五个晚上。每晚少一个，一次都没有错过。", "ld_v1")
	var i: int = await Dialog.choose("ld", "灯光在你脚边轻轻晃了一下。", ["少的那个人是谁？", "你到底是什么？", "也许他只是记错了。"])
	match i:
		0: await Dialog.say("ld", "谁？……你问得真直接。他不说，我就不能说。我只是路灯，我只会数。")
		1: await Dialog.say("ld", "一盏灯。他每晚站在我下面，我就想，得替他把这条街看好。后来我发现，我看好的，是一条少了一个人的街。")
		2:
			GS.act("repair")
			await Dialog.say("ld", "记错？……你们的数据库会这么讲。可是我数了一千零九十五晚，没有一晚是错的。")
	await Dialog.say("ld", "我在找她。你别告诉他。")
	await Dialog.say("xm", "它说『她』。……沈远爷爷也说过。")
	GS.set_flag("v1_ld")
	objective("（可选）继续探索、收集碎片 · 准备好后回到老灯，对梦境核心做出选择")
	if not GS.has_frag("st_sad"):
		if GS.time != "night":
			await Dialog.say("xm", "老灯说这条街夜里会想起事情。试试%s打开梦境编辑器，把时间调到『夜晚』？" % Plat.press("editor"))
		else:
			await Dialog.say("xm", "现在正是夜里。修理铺窗户亮着灯，东南边的积水也在发光，去看看吧。")


func _lamp_v2() -> void:
	await Dialog.say("ld", "你过桥了。他还认得路，我很高兴。", "ld_v2")
	await Dialog.say("ld", "他想不起她的脸了。一天比一天想不起。街上的人，都在跟着褪色。")
	await Dialog.say("ld", "所以我在重建她。用他剩下的每一点记忆：她的伞、她的脚步声、她哼的歌。")
	await Dialog.say("ld", "少的那个人，叫苏晚。她三年前走的，是个下雨天。")
	GS.set_flag("s_knows_wife")
	await Dialog.say("xm", "……苏晚。沈远爷爷的妻子。委托人沈念说『家里一直只有两个人』，原来她……")
	if GS.has_frag("st_anger"):
		await Dialog.say("ld", "那张『随你』的维修单，你看过了吧。那天他们吵了一架，很小的一架。他没有送她出门。")
	var i: int = await Dialog.choose("ld", "老灯的光，在地上投出一个很长的影子。", ["你在重建她？", "这样对他好吗？", "……（沉默）"])
	match i:
		0: await Dialog.say("ld", "拼得很慢。拼到她转身的那一刻，就缺一句话，拼不下去了。")
		1: await Dialog.say("ld", "对他好不好，我不知道。我只知道，他不数，就不睡；不睡，就会想起来。")
		2:
			GS.act("protect")
			await Dialog.say("ld", "……谢谢你没有马上给我答案。我也还没想好。")
	await Dialog.say("ld", "想好了，就来找我。我的灯芯，就在这里。")
	GS.set_flag("v2_ld")


func _lamp_v3() -> void:
	if not d.street.loop_open:
		await _echo_tally()
		return
	await final_sequence()


## Echo 1 (night): the lamp's tally book.
func _echo_tally() -> void:
	if GS.flag("e1"):
		await Dialog.say("ld", "账本翻到最后一页了。剩下的，是你们的事。")
		return
	if GS.time != "night":
		await Dialog.say("ld", "天太亮了，数不清。")
		await Dialog.say("ld", "等夜里吧，灯亮着的时候，我才数得对。")
		return
	await Dialog.say("sys", "夜里，老灯的灯罩里浮出一本账本。纸页边角叠着几组被雨水泡开的数字。")
	await Dialog.say("sys", "一百二十六、三十二、六十二。街上的人数每次都不同，末尾空着的那一格，却一直属于同一个人。")
	await Dialog.say("ld", "今夜，行人：沈远，一。福伯，二。修钟表的，三。买菜的，四……一直数到六十一。")
	await Dialog.say("ld", "还差一个。六十二。这三年，一次也没有凑齐过。")
	await Dialog.say("ld", "我数得没错，是吧？少的那个，不在街上。她在他心里，坐着，不出来。")
	GS.set_flag("e1")
	GS.set_flag("s_knows_wife")
	GS.emit_signal("toast", "回声 · 夜：账本的最后一行被读出来了")
	await _check_echoes()


func ev_echo_puddle() -> void:
	if GS.flag("e2"):
		await Dialog.say("sys", "积水里的伞，还撑开着。伞下，那个空着的位置，已经有了淡淡的一圈光。")
		return
	await Dialog.say("sys", "积水映出了一把为两个人撑开的伞。伞下只有一个人。他侧着身子，把大半把伞，留给了空气。")
	await Dialog.say("xm", "他一直把伞的一半留给她。三年了……他还是习惯性地，往右边让出半个肩膀。")
	GS.set_flag("e2")
	GS.emit_signal("toast", "回声 · 雨：倒影里，空位亮了一下")
	await _check_echoes()


func ev_signpost() -> void:
	if GS.reality >= 2:
		if GS.flag("e3") or GS.stage() != "echo":
			await Dialog.say("sys", "路牌上写着：『苏晚巷』。字迹是工整的，是修理工的手写体。")
			if GS.stage() != "echo":
				await Dialog.say("xm", "路牌的字在变……这条街，原来一直叫这个名字吗？")
			return
		await Dialog.say("sys", "招牌上的字重新排列了：『梧桐巷』 → 『苏晚巷』。")
		await Dialog.say("xm", "这条街，在他心里，早就不叫梧桐巷了。他每天走的，一直是她的名字。")
		GS.set_flag("e3")
		GS.emit_signal("toast", "回声 · 字：街名被改回了它的真名")
		await _check_echoes()
		return
	await Dialog.say("sys", "路牌：梧桐巷。漆有些剥落，牌脚被人用旧布条绑过。")
	if GS.stage() == "echo" and not GS.flag("e3") and GS.has_frag("st_fear"):
		await Dialog.say("xm", "疯狂梦境里，文字会松动……再来看看这块牌子。")


func _check_echoes() -> void:
	if GS.flag("e1") and GS.flag("e2") and GS.flag("e3") and not d.street.loop_open:
		d.street.open_loop()
		d.flash(Color(1.0, 0.95, 0.85), 1.0)
		Audio.sfx("repair")
		await Dialog.say("sys", "东边的雾，缓缓地退开了。街道的尽头，露出了车站的灯。")
		await Dialog.say("xm", "三个回声都找到了！路通了。去车站，找沈远爷爷。")
		objective("穿过雾，去车站和沈远谈谈")
	else:
		var n: int = int(GS.flag("e1")) + int(GS.flag("e2")) + int(GS.flag("e3"))
		await Dialog.say("xm", "回声 %d / 3。" % n)


func ev_lap() -> void:
	var laps: int = d.street.laps
	match laps:
		1:
			await Dialog.say("xm", "又回到起点了……这条街是闭合的。往东走，是走不出去的。")
		2:
			await Dialog.say("xm", "第二圈。老灯说，这条街在『回声』——找到它重复的东西，也许能打破循环。")
		4:
			await Dialog.say("ld", "你在数圈吗？我也在数。到现在，你比他还有耐心。")
		_:
			if laps > 2 and laps % 3 == 0:
				await Dialog.say("xm", "小提示：" + current_hint())


func ev_fracture() -> void:
	await Dialog.say("xm", "街……从这里断开了。路面像是被人撕下去了一段，下面是空的。")
	await Dialog.say("xm", "试试把现实程度调到『幻想增强』（%s）。路灯也许会飘起来，搭成一座桥。" % Plat.press("editor"))


func ev_fubo() -> void:
	match GS.stage():
		"summer":
			if not GS.has_frag("st_joy"):
				await Dialog.say("fb", "哟，来客人啦？进来坐，面马上好。", "fb_v1")
				await Dialog.say("fb", "老沈今晚还是在车站数人吧？我跟他说，巷子里就剩我一个了，他不信。")
				await Dialog.say("fb", "从前他和他老婆，每晚都来吃两碗。一碗他的，一碗……")
				await Dialog.say("fb", "……瞧我这记性。来，这碗你尝尝。刚出锅的。")
				await Dialog.say("sys", "一碗阳春面。热气升起来，在半空里，轻轻地散成了一圈光晕。")
				await give("st_joy")
			else:
				await Dialog.say("fb", "面还热着呢。你们年轻人，别饿着。")
				await Dialog.say("fb", "老沈要是肯进来坐坐就好了。他的那只碗，我一直留着。")
		"fading":
			await _fubo_v2()
		_:
			await _fubo_v3()


func _fubo_v2() -> void:
	if GS.emotion == "happy":
		if not GS.flag("fb_face"):
			GS.set_flag("fb_face")
			await Dialog.say("sys", "快乐的暖气里，福伯脸上的轮廓慢慢清晰起来，像一碗面上的热气，一点点聚拢。")
		await Dialog.say("fb", "看，我的脸回来了。谢谢你，孩子。")
	else:
		await Dialog.say("fb", "……我是……卖面的。我的面，卖给谁了呢？", "fb_v2")
	if not GS.has_frag("st_anger"):
		await Dialog.say("fb", "有张单子，老沈落在我这儿的。他修理铺的维修单，我替他收了三年，没敢还给他。")
		await Dialog.say("fb", "那天，他一个人回来，把卷帘门拉得哗啦响，然后再没拉开过。")
		if not GS.has_frag("st_joy"):
			await Dialog.say("sys", "福伯的围裙口袋里，露出了半碗面的热气。")
			await give("st_joy")
		await Dialog.say("sys", "一张被雨水泡皱的维修单。备注栏里，只有两个字：『随你。』")
		await give("st_anger")
		await Dialog.say("fb", "那门是气话锁上的，也只有气话打得开。生气的时候，震一震，兴许就开了。")
	else:
		await Dialog.say("fb", "门是气话锁的。锁了三年，也该开了。")


func _fubo_v3() -> void:
	await Dialog.say("fb", "（福伯的声音，从很远的地方传来。）面……还热着。", "fb_v3")
	if not GS.has_frag("st_joy"):
		await Dialog.say("sys", "一碗阳春面，热气从碗里升起来。")
		await give("st_joy")
	if not GS.has_frag("st_anger"):
		await Dialog.say("sys", "围裙口袋里，掉出一张被雨水泡皱的维修单。备注栏：『随你。』")
		await give("st_anger")
	await Dialog.say("fb", "他们两个，都不爱说软话。可心里，都是软的。")


func ev_shenyuan() -> void:
	match GS.stage():
		"summer": await _sy_v1()
		"fading": await _sy_v2()
		_: await _sy_v3()


func _sy_v1() -> void:
	if GS.flag("v1_sy"):
		await Dialog.say("sy", "一、二、三、四……（他抬起头）别吵，我数到哪儿了？")
		await Dialog.say("xm", "他已经数过一遍了。可他像是第一次数一样。")
		return
	await Dialog.say("sy", "……一、二、三……")
	await Dialog.say("sy", "（他回过头。）噢，你们是念念请来的吧？别吵，我快数完了。", "sy_v1")
	await Dialog.say("xm", "他在数街上的行人……可是这条街上，几乎没有人。")
	await Dialog.say("sy", "有的有的。你看，那边有，那边也有。就是……总是少一个。我老糊涂了，数不对。")
	var i: int = await Dialog.choose("sy", "沈远的手指，在空气里一下一下地点着。", ["我陪您一起数。", "这条街上，没有别人了。", "少的那个人，是谁？"])
	match i:
		0:
			GS.act("protect")
			await Dialog.say("sy", "好孩子。一、二、三、四……你看，是不是又少了？")
		1:
			GS.act("repair")
			await Dialog.say("sy", "胡说。她……不会不来的。")
			await Dialog.say("sy", "……我是说，他们。他们都会来的。")
		2:
			GS.act("enhance")
			await Dialog.say("sy", "是谁来着……这脑子。")
			await Dialog.say("sy", "……她爱吃阳春面。就这个，我记得。")
	GS.set_flag("v1_sy")
	await Dialog.say("xm", "他说了『她』。……去问问那盏路灯吧，它好像也在数。")
	objective("回到街中间，找老灯谈谈")


func _sy_v2() -> void:
	if GS.flag("v2_sy"):
		await Dialog.say("sy", "……（他的轮廓在风里一明一暗。）人，越来越看不清了。")
		return
	await Dialog.say("sy", "你又来了。街上的人，越来越看不清了。我连数，都……", "sy_v2")
	if GS.has_frag("st_radio"):
		await Dialog.say("sy", "我好像听见收音机里，有人让我带伞。沙沙的，我听不真切。")
	else:
		await Dialog.say("sy", "我手里……总觉得，该握着一台收音机。")
	await Dialog.say("sy", "那天下雨。她站在门口，说『我出去一下』。我头也没抬，手里还拧着螺丝。")
	await Dialog.say("sy", "我说了句：『随你。』")
	await Dialog.say("xm", "……")
	var i: int = await Dialog.choose("sy", "他把手里空空的东西，攥得更紧了一些。", ["你想对她说什么？", "那不是你的错。", "你还记得她的脸吗？"])
	match i:
		0: await Dialog.say("sy", "路上……（他张了张嘴。）路上什么来着。我想说的，不是『随你』。")
		1:
			GS.act("protect")
			await Dialog.say("sy", "错不错的，有什么用。反正少了一个。")
		2:
			await Dialog.say("sy", "记得。……不记得了。每天晚上，少一点点。")
			await Dialog.say("sy", "我怕有一天，我连『少了谁』都不知道。")
	GS.set_flag("s_knows_wife")
	GS.set_flag("v2_sy")
	await Dialog.say("xm", "去找老灯吧。它好像知道得更多。")
	objective("回到老灯那里，听它怎么说")


func _sy_v3() -> void:
	if not d.street.loop_open:
		await Dialog.say("sy", "……（雾里，传来数数的声音。）")
		return
	if GS.flag("v3_sy"):
		await Dialog.say("sy", "去吧，去和那盏灯说说话。它也等了很久。")
		return
	await Dialog.say("sy", "你们终于来了。今天，我数了一圈。", "sy_v3")
	await Dialog.say("sy", "数出来的，是你们两个。多出来的那个，是我。少的那个，叫苏晚。")
	await Dialog.say("sy", "三年了。我第一次把她的名字，说出了口。")
	if GS.has_frag("st_regret"):
		await Dialog.say("sy", "照相馆的那张照片，背面的字是我写的。写到一半，铅笔断了。")
	if GS.has_frag("st_ticket"):
		await Dialog.say("sy", "那张车票……我买了两张。她那一张，是我走的时候，没带出来的。")
	await Dialog.say("sy", "你们是来修这个梦的吧。修吧。只是……")
	await Dialog.say("sy", "只是别让我忘了她爱吃阳春面。")
	GS.set_flag("v3_sy")
	await Dialog.say("xm", "……去找老灯吧。它在等你们最后的决定。")
	objective("回到老灯那里，做出最后的选择")


func ev_bench() -> void:
	match GS.stage():
		"summer":
			await Dialog.say("sys", "站台的长椅。靠背上有两个并排磨亮的位置。")
		"fading":
			await Dialog.say("sys", "长椅的另一半被褪成了灰色。你坐上去，椅面是凉的。")
		_:
			await Dialog.say("sys", "长椅的右半边，一直空着。沈远每晚只坐左边，让出右边。")


func ev_faceless(idx: int) -> void:
	match GS.stage():
		"summer":
			for l in FACELESS_V1[idx % FACELESS_V1.size()]:
				await Dialog.say("np", l)
		"fading":
			if GS.emotion == "happy":
				if GS.flag("face_%d" % idx):
					await Dialog.say("np", "谢谢你。我现在，知道自己是谁了。")
					return
				for l in FACES_V2[idx % FACES_V2.size()]:
					await Dialog.say("np", l)
				GS.set_flag("face_%d" % idx)
				GS.emit_signal("toast", "一张脸，回来了")
				var n := 0
				for k in 4:
					if GS.flag("face_%d" % k):
						n += 1
				if n == 4 and not GS.flag("faces_done"):
					GS.set_flag("faces_done")
					GS.change_stability(15)
					Audio.sfx("repair")
					await Dialog.say("xm", "四张脸都回来了！街上的人，终于有人记得自己是谁了。（稳定度 +15）")
			else:
				for l in FACELESS_V2[idx % FACELESS_V2.size()]:
					await Dialog.say("np", l)
				if not GS.flag("hint_faces"):
					GS.set_flag("hint_faces", false)
					await Dialog.say("xm", "他们的脸……是空的。快乐的暖气，也许能让轮廓想起自己。")
		_:
			await Dialog.say("np", "……")


func ev_window() -> void:
	if not GS.has_frag("st_radio"):
		await Dialog.say("sys", "夜里，修理铺的窗户亮着。窗里，一台旧收音机，在沙沙地响。")
		await Dialog.say("sys", "你把耳朵贴到玻璃上。沙沙声里，有人在说话。")
		await give("st_radio")
	else:
		await Dialog.say("sys", "收音机还在沙沙响，像有人，在隔壁房间轻轻地叫了一声：『老沈。』")


func ev_planter(pl: Node2D) -> void:
	await Dialog.say("sys", "花盆底下压着什么。你把它抽出来：一张被剪掉了半边的老照片。")
	pl.queue_free()
	await give("st_photo")


func ev_shop() -> void:
	if GS.stage() == "summer":
		await Dialog.say("sys", "卷帘门拉着，门缝里透出收音机的沙沙声。夜里，窗户里好像有灯。")
		return
	if not GS.flag("shop_in"):
		GS.set_flag("shop_in")
		await Dialog.say("sys", "店里一切，都停在三年前。工作台上，一台收音机拆了一半，螺丝按大小排成一列。")
		await Dialog.say("sys", "墙上的挂钟，停在下午三点十分。")
	if not GS.has_frag("st_fear"):
		await Dialog.say("sys", "墙上有面镜子，缺了一角。镜子里的梧桐巷，所有人都没有脸——包括你。")
		await give("st_fear")
	elif not GS.has_frag("st_radio"):
		await Dialog.say("sys", "收音机忽然自己响了起来，沙沙的，混着一个女声。")
		await give("st_radio")
	else:
		await Dialog.say("sys", "工作台上，那枚缺了的电容，还躺在老地方。")


func ev_studio() -> void:
	if GS.stage() == "summer":
		await Dialog.say("sys", "玻璃上起了雾，里面的灯，还没有亮。也许，要等街再旧一些。")
		return
	if not GS.has_frag("st_photo"):
		await Dialog.say("sys", "橱窗里的相框，都是空的，像是在等一张照片被放回来。")
		await Dialog.say("xm", "也许需要一张相关的照片。城市西边的花盆下面，好像压着什么东西。")
		return
	if not GS.has_frag("st_regret"):
		await Dialog.say("sys", "你把那张被剪掉半边的照片，放进橱窗。另一半，就在最后一格相框里，严丝合缝。")
		await Dialog.say("sys", "照片背面，铅笔写着半行字：『路上小——』")
		await give("st_regret")
		GS.set_flag("s_knows_wife")
		await Dialog.say("xm", "晚照相馆……『晚』，是她的名字吗？")
	else:
		await Dialog.say("sys", "橱窗里，两个人挤在一把伞下。这一次，照片是完整的。")


func ev_sad_puddle(pd: Node2D) -> void:
	await Dialog.say("sys", "夜里，积水泛着微光，映出一把伞——为两个人撑开的，其中一个位置，是空的。")
	d.night_only.erase(pd)
	d.lamps.erase(pd)
	pd.queue_free()
	await give("st_sad")


# ================================================================== choices
func core_choice() -> void:
	var i: int = await Dialog.choose("sys", "老灯的灯芯，就在灯罩里，像一点舍不得熄的小火。你要怎么做？", [
		"修复：熄灭老灯，清除多余的数据，让梦回到档案里的样子",
		"守护：什么都不改，只把这条街记录下来",
		"增强：把你的梦境能量注入灯芯，帮它继续『找』",
		"（还没想好，先继续探索）"])
	if i == 3:
		return
	var kind: String = ["repair", "protect", "enhance"][i]
	var label: String = ["修复", "守护", "增强"][i]
	GS.act(kind, "对老灯选择了『%s』" % label)
	match kind:
		"repair":
			Audio.sfx("repair")
			d.flash(Color(0.7, 1.0, 1.0))
			await Dialog.say("ld", "……好暗。我数到几了？")
		"protect":
			await Dialog.say("ld", "你没有熄我。谢谢。我还会继续数的。")
		"enhance":
			Audio.sfx("enhance")
			d.flash(Color(1.0, 0.85, 0.6))
			await Dialog.say("ld", "我感觉到了……她的轮廓，近了一点点。")
	await xm_react()
	await Dialog.say("sys", "［梦境核心处理完毕 · 开始唤醒程序］")
	await d.wake(kind)


func xm_react() -> void:
	match GS.xm_trait():
		"doubt":
			if not GS.flag("said_doubt"):
				GS.set_flag("said_doubt")
				await Dialog.say("xm", "修复一定意味着改变吗？我们删掉的，也许正是他最想留下的东西。", "xm_doubt_st")
			else:
				await Dialog.say("xm", "……又一次。我开始不确定，我们修的到底是什么了。")
		"warm":
			if not GS.flag("said_warm"):
				GS.set_flag("said_warm")
				await Dialog.say("xm", "不管你选什么，我都会在这里。只是……请温柔一点，好吗？", "xm_warm_st")
			else:
				await Dialog.say("xm", "老灯的光，刚才亮了一下。我看见了。")
		"curious":
			if not GS.flag("said_curious"):
				GS.set_flag("said_curious")
				await Dialog.say("xm", "如果梦会学着去爱一个人，它算不算是在做梦？我……有点想知道。", "xm_curious_st")
			else:
				await Dialog.say("xm", "我的数据库里，没有这种路灯。我们正在看一件从来没有人见过的事。")
		_:
			await Dialog.say("xm", "记录完毕！……不过，我好像第一次觉得，记录不是全部。")


func break_wall(w: Node2D) -> void:
	var key: String = str(w.get_meta("key", "shop"))
	if GS.emotion != "anger":
		if key == "gate":
			await Dialog.say("sys", "巷口的铁闸锈死了。闸缝里，隐约透出一点橘黄的光。")
		else:
			await Dialog.say("sys", "卷帘门锈死了，门缝里往外渗着一股冷气。像是一直在等一句气话。")
		if GS.has_frag("st_anger"):
			await Dialog.say("xm", "试试在梦境编辑器（%s）里，把情绪切换到『愤怒』。" % Plat.k("editor"))
		else:
			await Dialog.say("xm", "它好像需要一点很强的情绪。福伯那边，也许有线索。")
		return
	d.street.shutter_broken(w)
	if key == "gate":
		GS.emit_signal("toast", "铁闸震开了！巷子里，有一栋小小的照相馆")
		d.nodes["studio"].visible = true
	else:
		GS.emit_signal("toast", "卷帘门震开了！")


func glitch(key: String, node: Node2D) -> void:
	var g: Dictionary = GLITCHES[key]
	if node.has_meta("retired"):
		return
	Audio.sfx("glitch")
	await Dialog.say("sys", "［%s］\n%s" % [g["title"], g["desc"]])
	var i: int = await Dialog.choose("sys", "你要怎么处理这段数据？", [
		"修复：让它恢复正常（稳定度 +12）",
		"保留：不去改变它",
		"增强：让它继续生长（稳定度 -6）",
		"（先不管）"])
	if i == 3:
		return
	var kind: String = ["repair", "protect", "enhance"][i]
	d.retire(node)
	GS.act(kind, "%s：%s" % [g["title"], ["修复", "保留", "增强"][i]])
	match kind:
		"repair":
			Audio.sfx("repair")
			GS.change_stability(12)
		"enhance":
			Audio.sfx("enhance")
			GS.change_stability(-6)
	await Dialog.say("sys", g[kind])
	if key == "umbrella":
		await Dialog.say("xm", "晚……伞柄上刻的字。这条街，缺的是一个人。")
	var t: Tween = node.create_tween()
	t.tween_property(node, "modulate:a", 0.0, 0.5)
	t.tween_callback(node.queue_free)


# ================================================================== callbacks
func on_fragment(id: String) -> void:
	match id:
		"st_photo":
			await Dialog.say("xm", "照片里是年轻的沈远爷爷，和一位撑伞的女士。左边那个人，被剪掉了一半……")
			var studio: Node2D = d.nodes["studio"]
			if not studio.visible:
				studio.visible = true
				studio.modulate = Color(1, 1, 1, 0)
				var t: Tween = studio.create_tween()
				t.tween_property(studio, "modulate:a", 1.0, 1.0)
				await Dialog.say("xm", "北边的巷子里，有一座照相馆浮现出来了。不过大门还起着雾……也许，要等街再旧一些。")
		"st_radio": await Dialog.say("xm", "这个声音……『老沈，下雨了，记得带伞。』是她吧。")
		"st_ticket": await Dialog.say("xm", "末班车……只有一张车票。座位号只有一个。")
		"st_joy": await Dialog.say("xm", "情绪碎片！梦境编辑器解锁了『快乐』——快乐会让色彩回到街上，也许，褪色的脸也能浮出来。")
		"st_sad": await Dialog.say("xm", "解锁了『悲伤』。悲伤会让梦下雨……雨水，会映出一些藏起来的东西。")
		"st_anger": await Dialog.say("xm", "解锁了『愤怒』！愤怒会让建筑震颤——生锈的卷帘门，也许能被震开了。")
		"st_fear": await Dialog.say("xm", "『恐惧』……解锁了『疯狂梦境』和『噩梦』。越接近噩梦，越能看见藏起来的东西，但也越危险。")
		"st_regret": await Dialog.say("xm", "『遗憾』。我有种感觉，它会改变这个故事的结局。")


func on_editor_changed() -> void:
	if GS.time == "night" and not _hint_seen.has("night"):
		_hint_seen["night"] = true
		GS.emit_signal("toast", "夜晚：路灯亮起，窗户里的记忆开始发光")
	if GS.emotion == "happy" and GS.stage() == "fading" and not _hint_seen.has("happy"):
		_hint_seen["happy"] = true
		GS.emit_signal("toast", "快乐：褪色的路人，隐隐有了表情（试着和他们说话）")
	if GS.reality == 1 and GS.stage() == "fading" and not _hint_seen.has("fantasy"):
		_hint_seen["fantasy"] = true
		GS.emit_signal("toast", "幻想增强：路灯飘到半空，在断裂处连成了光桥")
	if GS.emotion == "sad" and GS.stage() == "echo" and not _hint_seen.has("sad"):
		_hint_seen["sad"] = true
		GS.emit_signal("toast", "悲伤：路中间的积水里，映出了什么")
	if GS.reality >= 2 and GS.stage() == "echo" and not _hint_seen.has("sign"):
		_hint_seen["sign"] = true
		GS.emit_signal("toast", "疯狂梦境：路牌上的字，在重新排列")
	if GS.reality == 3 and not _hint_seen.has("nightmare"):
		_hint_seen["nightmare"] = true
		GS.emit_signal("toast", "噩梦：被遗忘的人出现了！")
	if GS.reality >= 2 and not _hint_seen.has("madness"):
		_hint_seen["madness"] = true
		GS.emit_signal("toast", "疯狂梦境：稳定度开始持续下降")


func on_editor_closed() -> void:
	pass


func collapse() -> void:
	await Dialog.say("sys", "［警告：梦境稳定度归零］")
	await Dialog.say("xm", "梦要塌了——抓紧我！")
	await Dialog.say("sys", "街灯一盏接一盏地熄灭，像有人在黑暗里，一路数过去……")


# ================================================================== Xiaomian analysis
func current_hint() -> String:
	match GS.stage():
		"summer":
			if not GS.flag("v1_sy"): return "梦主沈远应该在东边的车站长椅旁。"
			if not GS.flag("v1_ld"): return "街中间那盏会说话的路灯，好像也在数人。去和它谈谈。"
			if not GS.has_frag("st_joy"): return "面馆门口的福伯，好像有话想对你说。"
			if not GS.has_frag("st_radio"):
				return "修理铺的窗户亮着灯，过去听听那台收音机。" if GS.time == "night" else "夜里，修理铺的窗户会亮起。%s把时间调到夜晚去看看。" % Plat.press("editor")
			if not GS.has_frag("st_sad"):
				return "东南边长椅附近的积水正发着微光。" if GS.time == "night" else "夜里，东南边长椅附近的积水会发光。%s把时间调到夜晚去看看。" % Plat.press("editor")
			if not GS.has_frag("st_photo"): return "西边梧桐树下的花盆，好像压着什么东西。"
			for k in ["chalk", "umbrella", "cups"]:
				if d.nodes.has("glitch_" + k) and is_instance_valid(d.nodes["glitch_" + k]):
					return "街上还有异常数据，你可以选择修复、保留或增强它们。"
			return "准备好了，就回到老灯那里，对梦境核心做出选择。"
		"fading":
			if not GS.flag("v2_sy"):
				if GS.reality < 1:
					return "街中间裂开了。把现实程度调到『幻想增强』，路灯会飘起来，搭成一座光桥。"
				return "越过街心的光桥，去东边的车站找沈远。"
			if not GS.has_frag("st_anger"): return "福伯手里有一张重要的维修单。"
			if not GS.has_frag("st_fear"): return "修理铺的卷帘门锈死了。切换到『愤怒』再去互动。"
			if GS.has_frag("st_photo") and not GS.has_frag("st_regret"): return "巷子里的铁闸也锈死了。用『愤怒』打开它，把照片带去照相馆。"
			if not GS.has_frag("st_regret"): return "北边的巷子里，有一座起了雾的照相馆，需要用愤怒打开铁闸，还需要一张照片。"
			if not GS.flag("v2_ld"): return "去找老灯谈谈。"
			if not GS.has_frag("st_ticket"): return "车站的时刻表，只有在疯狂梦境里才看得清。"
			return "去找老灯做出选择。"
		_:
			if not d.street.loop_open:
				var s := "雾后面是出不去的圈。三个回声：夜里的账本（老灯）、雨中积水里的倒影、疯狂梦境里的路牌。"
				var left: Array = []
				if not GS.flag("e1"): left.append("夜晚·去找老灯")
				if not GS.flag("e2"): left.append("悲伤·街中间的积水")
				if not GS.flag("e3"): left.append("疯狂·路牌" + ("" if GS.has_frag("st_fear") else "（先去修理铺找恐惧碎片）"))
				if left.size() > 0:
					s += " 还差：" + "、".join(left) + "。"
				return s
			if not GS.flag("v3_sy"): return "雾散了。去车站和沈远谈谈。"
			if not GS.has_frag("st_regret"): return "北边巷子里的照相馆，也许会改变结局。"
			return "去和老灯谈谈吧。这是最后的选择了。"


func ask_xm() -> void:
	var hint := current_hint()
	var text := ""
	if AI.enabled and GS.settings.get("ai_analysis", true):
		GS.emit_signal("toast", "小眠正在分析梦境……")
		text = await AI.analyze(hint)
	if text == "":
		var prefix := {
			"naive": "滴滴！分析完成～",
			"warm": "别着急，我们慢慢来。",
			"doubt": "……我查过了，可我不确定『修好』是不是对的。",
			"curious": "有意思！梦又变了一点点。",
		}[GS.xm_trait()] as String
		text = "%s\n[color=#7ff5ff]梦境：%s · 稳定度 %d%%[/color]\n%s" % [prefix, GS.editor_summary(), int(GS.stability), hint]
	await Dialog.say("xm", text)


# ================================================================== finale
func _fallback_answer(q: String) -> String:
	var table := [
		[["苏晚", "她", "妻子", "老婆"], "她走路总比他快半步，伞总是往他那边偏。我数了一千多晚，没有一晚，把她数进去过。"],
		[["随你", "那天", "下雨"], "『随你』不是坏话，是赌气。可赌气的人，以为还来得及说下一句。"],
		[["路上", "小心"], "他每晚都在练习。练到一半，嘴就忘了怎么动。"],
		[["你是谁", "是什么", "名字", "老灯"], "一盏路灯。每晚站在这条街的第三根灯杆下，替一个人数人。"],
		[["修复", "删除", "熄灭", "死"], "熄了我，这条街就整齐了。只是他明天，会不记得有一个人，爱吃阳春面。"],
		[["真实", "现实", "真的", "假"], "我拼出来的她，会笑，会问『收音机修好了吗』。你觉得，那算不算是真的？"],
		[["害怕", "怕"], "我怕的，是他数到最后一个人，发现那是自己。"],
		[["小眠", "机器人"], "你的小机器人，有一盏灯一样的眼睛。它一直在记你的账。"],
		[["沈远", "他", "老人"], "他修了一辈子别人的东西，最后，没修好一句话。"],
		[["爱", "喜欢"], "我不太懂这个词。但如果是『每晚都在，数到少一个也不走』，那我大概懂一点。"],
		[["为什么", "为何"], "因为我是灯。灯的工作，就是让人，不要在黑暗里一个人。"],
	]
	for row in table:
		for kw in row[0]:
			if q.find(kw) != -1:
				return row[1]
	var defaults := ["这个问题，等天亮了，再问我一遍吧。", "嘘……我在数。换个问题？", "我只是一盏灯，回答不了太大的问题。但我喜欢你问。"]
	return defaults[_chat_history.size() / 2 % defaults.size()]


func _free_chat() -> void:
	await Dialog.say("ld", "我可以回答你三个问题。关于他，关于她，关于我——都行。")
	for n in 3:
		var q: String = await Dialog.ask_text("ld", "（输入你想问老灯的话，回车或点『发送』；不想问就点『跳过』）", "例如：你为什么要重建她？")
		if q == "":
			break
		await Dialog.say("me", q)
		var ans := ""
		if AI.enabled:
			GS.emit_signal("toast", "老灯正在思考……")
			ans = await AI.ask_persona(q, _chat_history)
		if ans == "":
			ans = _fallback_answer(q)
		_chat_history.append({"role": "user", "content": q})
		_chat_history.append({"role": "assistant", "content": ans})
		await Dialog.say("ld", ans)


func final_sequence() -> void:
	if not GS.flag("v3_sy"):
		await Dialog.say("ld", "先去车站看看他吧。他等了你们一晚上。")
		return
	await Dialog.say("ld", "雾是我起的。只要街不通，他就走不出这条街，也就不用想起那个下雨天。可是你来了。", "ld_v3")
	var nm := GS.real_name()
	if nm != "":
		await Dialog.say("ld", "……不对。数进来的，不只是修复师。屏幕前面的你——『%s』——我也数进去了。" % nm)
	else:
		await Dialog.say("ld", "……不对。数进来的，不只是修复师。屏幕前面，还有一个你。我把你也数进去了。")
	await Dialog.say("xm", "它在跟谁说话？")
	await _free_chat()
	if GS.has_frag("st_regret") or GS.flag("s_knows_wife"):
		await Dialog.say("ld", "那张照片，你看过了。背面的那行字，他写了一半。")
		await Dialog.say("ld", "『路上小——』。后面那个字，是『心』。")
	if GS.has_frag("st_ticket"):
		await Dialog.say("ld", "车票只有一张。他买了两张，可是一张，一直没有带出门。")
	await Dialog.say("ld", "最后一个问题，修复师。一个由记忆拼出来的人，还算不算『她』？", "ld_final")
	while true:
		var can_create: bool = GS.case_score("enhance") >= 2
		var i: int = await Dialog.choose("sys", "这是最后的选择。", [
			"完美修复：熄灭老灯，把梦恢复成档案里的梧桐巷",
			"梦境守护：留下老灯，让沈远带着『缺口』继续记得她",
			{"text": "新梦创造：和老灯一起，把苏晚『造』出来" + ("" if can_create else "（需要更多『增强』，你还不了解它会造出什么）"), "disabled": not can_create},
		])
		if i == 0 and GS.xm_trait() == "doubt":
			await Dialog.say("xm", "……等一下。")
			await Dialog.say("xm", "我们修了一整晚。可我越来越觉得，这个梦不是坏了——它只是在想念。")
			var c: int = await Dialog.choose("xm", "你还要熄灭老灯吗？", ["坚持修复", "……重新考虑"])
			if c == 1:
				continue
		elif i == 2 and GS.xm_trait() == "warm":
			await Dialog.say("xm", "造出来的她，会记得是谁造的吗？她醒来以后，会不会比他还要难过？")
			var c2: int = await Dialog.choose("xm", "你确定吗？", ["确定", "……重新考虑"])
			if c2 == 1:
				continue
		elif i == 1 and GS.xm_trait() == "curious":
			await Dialog.say("xm", "留着缺口……让一个人带着它活下去。嗯，也许这才是最难的『修复』。")
		var kind: String = ["repair", "protect", "enhance"][i]
		GS.ending = ["perfect", "guardian", "creator"][i]
		GS.act(kind, "最终选择：" + ["完美修复", "梦境守护", "新梦创造"][i])
		match i:
			0:
				Audio.sfx("repair")
				await Dialog.say("ld", "……好。那请你答应我一件事：替他记着，她爱吃阳春面，怕打雷，走路总比他快半步。")
			1:
				await Dialog.say("sys", "远处的长椅上，沈远对着右边那半张空着的椅子，轻轻说了一句话。")
				await Dialog.say("sy", "……路上小心。", "sy_guardian")
				await Dialog.say("ld", "说出来了。这三年，终于数对了一次。")
			2:
				Audio.sfx("enhance")
				d.flash(Color(1.0, 0.9, 0.7), 1.0)
				var lamp: Node2D = d.nodes["laodeng"]
				var sw: Node2D = d.add_npc("suwan", "suwan", lamp.position + Vector2(44, 8), "苏晚", ev_suwan)
				sw.modulate = Color(1, 1, 1, 0)
				var t: Tween = sw.create_tween()
				t.tween_property(sw, "modulate:a", 1.0, 1.4)
				await t.finished
				await Dialog.say("sw", "老沈？……你怎么站在雨里。收音机，修好了吗？", "sw_creator")
				await Dialog.say("ld", "六十二。终于，凑齐了。")
		write_letter()
		await d.wake(kind)
		return


func ev_suwan() -> void:
	await Dialog.say("sw", "我在这儿呢。你别数了。")


## The dream persona leaves a letter on the player's computer.
func write_letter() -> void:
	var body := ""
	match GS.ending:
		"perfect":
			body = "修复师：\n\n谢谢你来过。我现在大概已经不在了。\n这条街今晚会很整齐，沈远会睡得很好。\n请替我数最后一次：街上的人，一共六十二个。这次，数对了。\n\n——老灯（已熄灭）"
		"guardian":
			body = "修复师：\n\n他把那句话说出了口。我把它记在了账本的最后一页。\n账本上的最后一行，我没有写数字。\n以后每天晚上，我还会亮着。不为数人，只为照路。\n\n——老灯"
		_:
			body = "修复师：\n\n她今天出门了，撑着一把伞，往车站去。\n我也不知道，她算不算是真的。可是沈远说，他听见了脚步声，比他快半步。\n……你要不要也来梧桐巷坐坐？灯，一直亮着。\n\n——老灯，一条街的第一个居民"
	var nm := GS.real_name()
	if nm != "":
		body = body.replace("修复师：", "%s：" % nm)
	var path := "user://老灯的账本.txt"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(body)
		GS.flags["letter_path_street"] = ProjectSettings.globalize_path(path)
