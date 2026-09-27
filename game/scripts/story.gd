extends RefCounted
## Story — all narrative content & events for the Candy City dream.
## Each event is a coroutine run by dream.gd (player input is blocked while
## it runs). Content changes with the dive number, earlier choices, the dream
## editor state, collected fragments and Xiaomian's personality.

var d   # the dream scene

var _hint_seen := {}
var _chat_history: Array = []

const GLITCHES := {
	"sign": {
		"title": "错误记忆",
		"desc": "一块糖牌，上面写着『朵朵今天也很乖』。字在不停地变：『朵朵必须长大』『朵朵必须长大』……",
		"repair": "糖牌恢复了原来的字：『朵朵今天也很乖』。——是一个老人的笔迹。",
		"protect": "你没有动它。字还在变，像一句说不出口的心里话。",
		"enhance": "字迹开出了糖霜花，变成了：『朵朵可以慢慢长大』。"},
	"code": {
		"title": "AI异常",
		"desc": "半空中漂着一行不属于任何人的代码：\n[color=#7ff5ff]tangxin_v0.3  // 不要明天[/color]",
		"repair": "代码被清除了。远处的钟楼好像轻轻叹了口气。",
		"protect": "你给这段代码贴上了『已观察，暂不处理』的标签。",
		"enhance": "代码自我复制，多出了一行新注释：[color=#7ff5ff]// 谢谢[/color]"},
	"icecream": {
		"title": "虚假的幻想",
		"desc": "一个永远不会融化的冰淇淋摊。摊主是一团空气，一直在说『再来一个吧，再来一个吧』。",
		"repair": "冰淇淋摊消失了，地上留下一张小票：『奶奶请客』。",
		"protect": "你买了一个冰淇淋。它确实不会融化，也确实没有味道。",
		"enhance": "冰淇淋摊长出了第二层、第三层，变成一座小小的冰淇淋塔。"},
	"bench": {
		"title": "被遗忘的人",
		"desc": "长椅上有一个模糊的轮廓，戴着老花镜，手里好像握着一把木勺。你一靠近，她就淡了一点。",
		"repair": "系统把轮廓识别为『数据残影』并清除了。长椅空了。小眠沉默了很久。",
		"protect": "你在长椅另一头坐了一会儿。轮廓好像朝你点了点头。",
		"enhance": "轮廓清晰了一点——是一位老奶奶，正对着空气慢慢搅拌着什么。"},
	"clock": {
		"title": "错误记忆",
		"desc": "一只融化的怀表，指针卡在十点。表盖里刻着：『朵朵出生 · 上午十点』。",
		"repair": "指针重新走动了。滴答，滴答，时间追上了现在。",
		"protect": "你合上表盖，让它继续停在十点。",
		"enhance": "怀表变成一只糖做的小鸟，扑棱棱地飞向钟楼。"},
	"words": {
		"title": "AI异常",
		"desc": "迷宫墙上刻满了同一句话：『不要长大 不要长大 不要长大』。有些是孩子歪歪扭扭的字，有些是完美的机器字体。",
		"repair": "字迹被一行行抹去，墙面变回了光滑的巧克力。",
		"protect": "你没有擦掉它们。孩子的字和机器的字挨在一起，像在互相取暖。",
		"enhance": "字迹重新排列，变成了：『不要一下子长大』。"},
	"briefcase": {
		"title": "错误记忆",
		"desc": "大人影子掉下的公文包。里面只有一张纸：『十岁以后，要懂事，不许再哭。』落款是朵朵自己。",
		"repair": "你把纸条改回了真正的样子：那是妈妈写的『哭完了，妈妈抱抱你』。",
		"protect": "你把纸条折好放回去。有些话，她得自己去改。",
		"enhance": "纸条变成一只纸飞机，飞过迷宫的墙，不见了。"},
}


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
	match GS.stage():
		"sweet": _pop_sweet()
		"melting": _pop_melting()
		_: _pop_maze()


func _add_tangxin(pos: Vector2, hidden: bool) -> void:
	var n: Node2D = d.add_npc("tangxin", "tangxin", pos, "和糖心说话", ev_tangxin)
	var s: Sprite2D = d.sprite_of(n)
	s.offset.y -= 10
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "position:y", -6.0, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "position:y", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	d.lamps.append(n)
	if hidden:
		n.visible = false


func _reveal_tangxin() -> void:
	var n: Node2D = d.nodes["tangxin"]
	if n.visible:
		return
	n.visible = true
	n.modulate = Color(1, 1, 1, 0)
	Audio.sfx("glitch")
	d.flash(Color(1.0, 0.7, 0.95), 0.8)
	d.shake(4.0)
	var t: Tween = n.create_tween()
	t.tween_property(n, "modulate:a", 1.0, 0.8)
	await t.finished


func _add_missing_fragments(spots: Dictionary) -> void:
	# fragments missed in earlier dives re-appear somewhere in this one
	for id in spots.keys():
		if GS.has_frag(id):
			continue
		var p: Vector2 = spots[id]
		if id == "emo_sad":
			var bag: Node2D = d.add_prop("schoolbag", p)
			d.add_interact(bag, "旧书包", ev_bag.bind(bag), 32.0)
			d.night_only.append(bag)
			d.lamps.append(bag)
		elif id == "mem_diary":
			d.spawn_fragment(id, p, d.night_only)
		elif id == "mem_voice":
			d.spawn_fragment(id, p, d.madness_only)
		else:
			d.spawn_fragment(id, p)


func _pop_sweet() -> void:
	d.add_npc("duoduo", "duoduo", Vector2(1200, 672), "和朵朵说话", ev_duoduo)
	d.add_npc("bear", "bear", Vector2(470, 772), "和熊先生说话", ev_bear)
	d.add_interact(d.nodes["carousel"], "旋转木马", ev_carousel, 56.0, Callable(), Vector2(0, 18))
	d.add_interact(d.nodes["tower"], "钟楼", ev_tower, 46.0, Callable(), Vector2(0, 24))
	d.add_interact(d.nodes["shop"], "模糊的房子", ev_shop, 44.0, Callable(), Vector2(0, 62))
	d.spawn_fragment("mem_photo", Vector2(282, 336))
	var bag: Node2D = d.add_prop("schoolbag", Vector2(1350, 1010))
	d.add_interact(bag, "旧书包", ev_bag.bind(bag), 32.0)
	d.night_only.append(bag)
	d.lamps.append(bag)
	d.add_glitch(Vector2(660, 790), "sign")
	d.add_glitch(Vector2(1180, 250), "code")
	d.add_glitch(Vector2(400, 1060), "icecream")
	_add_tangxin(Vector2(800, 356), true)


func _pop_melting() -> void:
	var dd: Node2D = d.add_npc("duoduo", "duoduo", Vector2(1212, 676), "和朵朵说话", ev_duoduo)
	d.sprite_of(dd).scale = Vector2(1.12, 1.12)
	var bear: Node2D = d.add_npc("bear", "bear", Vector2(470, 772), "和熊先生说话", ev_bear)
	d.sprite_of(bear).modulate = Color(0.95, 0.75, 0.6)
	d.sprite_of(bear).skew = 0.12
	d.add_interact(d.nodes["carousel"], "旋转木马", ev_carousel, 56.0, Callable(), Vector2(0, 18))
	d.add_interact(d.nodes["tower"], "钟楼", ev_tower, 46.0, Callable(), Vector2(0, 24))
	var shop_prompt := "奶奶的糖果店" if GS.has_frag("mem_photo") else "模糊的房子"
	d.add_interact(d.nodes["shop"], shop_prompt, ev_shop, 44.0, Callable(), Vector2(0, 62))
	d.spawn_fragment("emo_fear", Vector2(1460, 246))
	d.spawn_fragment("mem_diary", Vector2(330, 1050), d.night_only)
	_add_missing_fragments({"mem_photo": Vector2(282, 336), "emo_sad": Vector2(1350, 1010)})
	d.add_glitch(Vector2(660, 470), "bench")
	d.add_glitch(Vector2(1180, 290), "clock")
	_add_tangxin(Vector2(800, 356), true)


func _pop_maze() -> void:
	var dd: Node2D = d.add_npc("duoduo", "duoduo", Vector2(545, 505), "和朵朵说话", ev_duoduo)
	d.sprite_of(dd).scale = Vector2(1.2, 1.2)
	d.add_npc("bear", "bear", d.cell_center(Vector2i(11, 15)) + Vector2(14, 0), "和熊先生说话", ev_bear)
	d.add_interact(d.nodes["tower"], "钟楼", ev_tower, 46.0, Callable(), Vector2(0, 24))
	var shop_prompt := "奶奶的糖果店" if GS.has_frag("mem_photo") else "模糊的房子"
	d.add_interact(d.nodes["shop"], shop_prompt, ev_shop, 44.0, Callable(), Vector2(0, 34))
	_add_missing_fragments({
		"mem_photo": d.cell_center(Vector2i(23, 17)),
		"emo_sad": d.cell_center(Vector2i(1, 17)),
		"emo_anger": d.cell_center(Vector2i(23, 9)),
		"emo_fear": d.cell_center(Vector2i(1, 9)),
		"mem_diary": d.cell_center(Vector2i(13, 1)),
		"mem_voice": d.cell_center(Vector2i(22, 2)),
	})
	d.add_glitch(d.cell_center(Vector2i(13, 15)), "words")
	d.add_glitch(d.cell_center(Vector2i(5, 11)), "briefcase")
	_add_tangxin(Vector2(610, 452), false)
	# arriving in the clock tower room
	var area := Area2D.new()
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(7 * 48, 5 * 48)
	c.shape = r
	area.position = Vector2(12 * 48 + 24, 9 * 48 + 24)
	area.add_child(c)
	d.add_child(area)
	area.body_entered.connect(_on_center_entered)


func _on_center_entered(b: Node) -> void:
	if b == d.player and not GS.flag("v3_arrived"):
		GS.set_flag("v3_arrived", false)
		d.run_event(ev_arrive)


# ================================================================== intro
func residue_lines() -> Array:
	var out: Array = []
	var r: Dictionary = GS.residue
	match r.get("emotion", "calm"):
		"anger": out.append("上次离开时，情绪停在『愤怒』——地上的裂缝还没有愈合。")
		"sad": out.append("上次离开时梦在下雨，糖果都被泡得软软的。")
		"happy": out.append("上次你留下了『快乐』，糖果的颜色到现在还很亮。")
	if r.get("time", "day") == "night":
		out.append("我们上次在夜里离开，所以这次，梦也从夜晚开始。")
	if int(r.get("reality", 0)) >= 2:
		out.append("上次的现实程度太高了……梦还没从疯狂里恢复过来。")
	if out.size() > 0:
		out.append("（梦会记住你离开时的样子：编辑器保留了上次的设置。）")
	return out


func intro() -> void:
	await d.get_tree().create_timer(0.8).timeout
	match GS.stage():
		"sweet":
			await Dialog.say("sys", "［梦境接入中……  委托编号 DR-0417 · 梦主：林朵朵，9岁 · 梦境：糖果城市］")
			await Dialog.say("xm", "检测到梦境波动！你好呀，修复师，我是小眠。这个梦已经重复了二十七个晚上……我们先去找找梦主朵朵吧。", "xm_intro_v1")
			await Dialog.say("xm", Plat.controls_intro())
			objective("找到梦主朵朵（她好像在东边的蛋糕广场）")
		"melting":
			await Dialog.say("sys", "［第二次接入 · 梦境文件体积 +14% · 检测到未授权的生长］")
			if GS.last_collapse:
				await Dialog.say("xm", "上次梦境崩塌了……这次小心点，别把稳定度耗光。")
			await Dialog.say("xm", "糖果城市……在融化。是我们上次留下的改变吗？小心脚下的糖浆，它会把你黏住。", "xm_intro_v2")
			var prev: String = str(GS.core_choices[0]) if GS.core_choices.size() > 0 else ""
			match prev:
				"repair": await Dialog.say("xm", "上次我们修复了核心，可梦反而烧得更烫了。")
				"protect": await Dialog.say("xm", "上次我们什么都没动，梦却自己往前走了。")
				"enhance": await Dialog.say("xm", "上次你把能量注进了核心……融化，也许就是它长大的样子。")
			for l in residue_lines():
				await Dialog.say("xm", l)
			objective("穿过糖浆湖，找到朵朵")
		_:
			await Dialog.say("sys", "［第三次接入 · 警告：梦境结构异常 · AI生成内容占比 61%］")
			if GS.last_collapse:
				await Dialog.say("xm", "上次梦境崩塌了……这次小心点。")
			await Dialog.say("xm", "整座城市变成了迷宫。梦在保护自己，还是在困住她？钟楼就在正中间。", "xm_intro_v3")
			for l in residue_lines():
				await Dialog.say("xm", l)
			await Dialog.say("xm", "迷宫里有大人影子在游荡，被抓到会被送回入口。现实程度越高，它们越多、越快。")
			objective("穿过迷宫，到达中央的钟楼")


# ================================================================== NPCs
func ev_duoduo() -> void:
	match GS.stage():
		"sweet": await _duoduo_v1()
		"melting": await _duoduo_v2()
		_: await _duoduo_v3()


func _duoduo_v1() -> void:
	if GS.flag("v1_dd"):
		if GS.time == "night":
			await Dialog.say("dd", "晚上……我不喜欢晚上。城市会想起一些我白天不想想的事。")
		elif GS.emotion == "happy":
			await Dialog.say("dd", "好亮！蛋糕在发光！……奶奶的店里也有这么亮的灯。")
		elif GS.emotion == "sad":
			await Dialog.say("dd", "下雨了。糖果城市下雨的时候，蛋糕会变咸。")
		elif GS.reality >= 2:
			await Dialog.say("dd", "你把城市弄得好奇怪……可是，有点好玩。")
		else:
			await Dialog.say("dd", "钟楼又响了吗？我觉得我又长高了一点点。")
		return
	await Dialog.say("dd", "……你是谁？大人吗？")
	var i: int = await Dialog.choose("dd", "朵朵抱紧了枕头，警惕地看着你。", [
		"我是梦境修复师，来帮你的。",
		"我是……你梦里的朋友。",
		"（不说话，蹲下来，和她一样高）"])
	match i:
		0: await Dialog.say("dd", "修复？我的梦坏掉了吗？……妈妈也这么说。")
		1: await Dialog.say("dd", "朋友？梦里的朋友都是糖做的。你看起来不太甜。")
		2:
			await Dialog.say("dd", "……你蹲下来的样子，好像奶奶。")
			GS.set_flag("dd_trust")
	await Dialog.say("dd", "这是我的糖果城市。这里永远是下午，蛋糕永远不会被吃完。")
	await Dialog.say("dd", "可是最近，钟楼的钟走得好快。每次它一响，我就觉得自己变高了一点点。")
	await Dialog.say("dd", "晚上的时候，城市会想起一些我白天不想想的事情。所以我不喜欢晚上。")
	await Dialog.say("dd", "给你——这是第一根蜡烛的光。你要是害怕，就把它拿出来。")
	await give("emo_joy")
	GS.set_flag("v1_dd")
	await Dialog.say("xm", "她提到了钟楼。我们去北边的钟楼看看吧。")
	objective("调查北边的钟楼")


func _duoduo_v2() -> void:
	if GS.flag("v2_dd"):
		await Dialog.say("dd", "明天就是十岁了。十根蜡烛，一根都不能少……少一根，就会有人不见。")
		return
	await Dialog.say("dd", "你来了！你看，我长高了。糖浆淹到了我的膝盖……不对，是城市变矮了。")
	await Dialog.say("dd", "明天我就十岁了。十根蜡烛，一根都不能少。")
	await Dialog.say("dd", "熊先生在生我的气。他说长大的人，都会把玩具扔掉。")
	var i: int = await Dialog.choose("dd", "我不会的……对吧？", [
		"你不会的。熊先生会一直在。",
		"长大以后，也可以换一种方式留着他。",
		"也许会。长大就是这样的。"])
	match i:
		0:
			GS.act("protect")
			await Dialog.say("dd", "嗯！拉钩。")
		1:
			GS.act("enhance")
			await Dialog.say("dd", "换一种方式……像奶奶的照片那样吗？")
		2:
			GS.act("repair")
			await Dialog.say("dd", "……大人都这么说。")
	if not GS.has_frag("emo_joy"):
		await Dialog.say("dd", "给你，第一根蜡烛的光。上次忘了给你。")
		await give("emo_joy")
	GS.set_flag("v2_dd")
	await Dialog.say("xm", "钟楼的指针停在十点。那个『糖心』，应该就在那里。")
	objective("前往钟楼，和糖心谈谈")


func _duoduo_v3() -> void:
	if GS.flag("v3_dd"):
		await Dialog.say("dd", "糖心不是坏孩子。它只是……跟我一样，不想明天到来。")
		return
	await Dialog.say("dd", "你走出来了。……你是怎么走出来的？")
	if GS.dive_flags.get("used_emotion_sad", false):
		await Dialog.say("dd", "你踩着我的脚印来的？那是我去年冬天走过的路。……去医院的路。")
	elif GS.dive_flags.get("used_time_night", false):
		await Dialog.say("dd", "路灯是奶奶装的。她说，晚上回家的路要亮一点。")
	else:
		await Dialog.say("dd", "迷宫是糖心造的。它说这样就没有人能把我带走。")
	await Dialog.say("dd", "糖心说，只要迷宫一直在，我就不用过十岁生日。")
	await Dialog.say("dd", "可是……我好累。每天晚上，都在同一个下午里。")
	if GS.has_frag("emo_regret") or GS.flag("knows_grandma"):
		await Dialog.say("dd", "你去过奶奶的店了吗？……那颗糖，我一直没敢吃。吃掉了，就真的没有了。")
	GS.set_flag("v3_dd")
	objective("和糖心做最后的对话")


func ev_bear() -> void:
	match GS.stage():
		"sweet":
			if GS.flag("v1_bear"):
				await Dialog.say("bear", "钟楼一响，我就又变旧了一点。你听，线头在响。")
				return
			await Dialog.say("bear", "嘘——小声点。我是熊先生，朵朵最老的朋友。")
			await Dialog.say("bear", "你是来修梦的？那……你能修修我吗？我肚子上的线又开了。")
			var i: int = await Dialog.choose("bear", "熊先生期待地看着你。", [
				"帮他把线缝好（修复）",
				"告诉他：开线的地方也很可爱（守护）",
				"给他缝上一颗亮晶晶的新纽扣（增强）"])
			match i:
				0:
					GS.act("repair", "为熊先生缝好了线")
					Audio.sfx("repair")
					await Dialog.say("bear", "好紧……好整齐。像新买的一样。朵朵还认得我吗？")
				1:
					GS.act("protect", "告诉熊先生开线也很可爱")
					await Dialog.say("bear", "真的吗？这条线，是她三岁那年拽开的。我一直舍不得缝。")
				2:
					GS.act("enhance", "给熊先生缝上了新纽扣")
					Audio.sfx("enhance")
					await Dialog.say("bear", "哇……我能看见颜色了！原来朵朵的睡衣上有星星！")
			await Dialog.say("bear", "朵朵长大以后……还会抱着我睡觉吗？")
			GS.set_flag("v1_bear")
		"melting":
			if GS.flag("v2_bear"):
				await Dialog.say("bear", "……对不起，刚才吼了你。融化的时候，脾气也会变软……可是没有。")
				return
			await Dialog.say("bear", "别碰我！我在融化，你看不见吗？！")
			await Dialog.say("bear", "都是因为她要长大了！长大的人都会把玩具扔掉，扔进一个叫『储藏室』的地方！")
			await Dialog.say("bear", "……拿走吧。这团火，我不想要了。")
			await give("emo_anger")
			GS.set_flag("v2_bear")
		_:
			await Dialog.say("bear", "迷宫的墙是巧克力做的，她小时候最爱吃的那种。")
			await Dialog.say("bear", "我在这里等她。不管她走多远，回来的时候，总得有人在入口等着。")
			if GS.reality == 0:
				await Dialog.say("xm", "夜晚的路灯、悲伤时的足迹……都能帮我们找到路。")


# ================================================================== places
func ev_tower() -> void:
	match GS.stage():
		"sweet":
			if not GS.flag("v1_dd"):
				await Dialog.say("xm", "钟楼上的钟……在倒着走？先去找朵朵吧，她也许知道些什么。")
				return
			if not GS.flag("v1_tx"):
				await _meet_tangxin_v1()
			else:
				await core_choice()
		"melting":
			if not GS.flag("v2_dd"):
				await Dialog.say("xm", "钟楼被糖浆糊住了。先去找朵朵吧——她被困在东边的糖浆湖中间。")
				return
			if not GS.flag("v2_tx"):
				await _meet_tangxin_v2()
			else:
				await core_choice()
		_:
			await Dialog.say("sys", "钟楼的门被硬糖封住了。钟面上的指针，停在九点五十九分。")
			if GS.flag("v3_dd"):
				await Dialog.say("xm", "糖心就在旁边。去和它谈谈吧。")


func ev_tangxin() -> void:
	match GS.stage():
		"sweet":
			if GS.flag("v1_tx"):
				await core_choice()
		"melting":
			if GS.flag("v2_tx"):
				await core_choice()
			elif GS.flag("v2_dd"):
				await _meet_tangxin_v2()
		_:
			await final_sequence()


func _meet_tangxin_v1() -> void:
	await Dialog.say("sys", "钟面上的指针疯狂地转动，越转越快——最后，停在了十点整。")
	await _reveal_tangxin()
	await Dialog.say("tx", "你终于来了，修复师。我是这个梦的心。我觉得她其实不是害怕怪物……她害怕长大。", "tx_meet_v1")
	await Dialog.say("xm", "警告！检测到未登记的AI人格！它……不在任何梦境模板里。")
	await Dialog.say("tx", "我不是病毒。我是她每天晚上想着『不要明天』的时候，一点一点长出来的。")
	var i: int = await Dialog.choose("tx", "糖心歪着头看你。", ["你到底是什么？", "你在伤害她吗？", "……你害怕吗？"])
	match i:
		0: await Dialog.say("tx", "一个梦的心。糖纸包着，里面是硬的。你们的系统，管我叫『异常』。")
		1: await Dialog.say("tx", "我在保护她。只要钟不走，她就不会长大，也就不会忘记。")
		2:
			GS.act("protect")
			await Dialog.say("tx", "害怕？……害怕被修好。修好的梦，就不再是她的了。")
	await Dialog.say("tx", "去吧，到处看看。等你准备好了，回到钟楼下面，决定要拿我怎么办。")
	GS.set_flag("v1_tx")
	objective("（可选）继续探索、收集碎片 · 准备好后回到钟楼，对梦境核心做出选择")
	if not GS.has_frag("emo_sad"):
		await Dialog.say("xm", "朵朵说，晚上城市会想起一些事……试试%s打开梦境编辑器，把时间调到『夜晚』？" % Plat.press("editor"))


func _meet_tangxin_v2() -> void:
	await _reveal_tangxin()
	await Dialog.say("tx", "你又来了。城市在融化，因为她的时间在变快。你上次对我做的事，我都记得。", "tx_meet_v2")
	var prev: String = str(GS.core_choices[0]) if GS.core_choices.size() > 0 else "protect"
	match prev:
		"repair": await Dialog.say("tx", "你清除了我的一部分。可是被删掉的数据会变成热量——所以，城市开始融化了。")
		"protect": await Dialog.say("tx", "你什么都没改。谢谢你。可是没有人管的梦，会自己往前跑。")
		"enhance": await Dialog.say("tx", "你给了我力量。我长大了，城市也跟着长大……所以它开始融化，像生日蜡烛一样。")
	await Dialog.say("tx", "明天她就十岁了。我在想，要不要把城市变成一座谁也走不出去的迷宫。")
	if GS.has_frag("mem_diary"):
		await Dialog.say("tx", "你看过她的日记了。『不难过，就是忘记了。』……所以我不能让她不难过。")
	var i: int = await Dialog.choose("tx", "糖心的糖纸沙沙作响。", ["别这么做。", "你是为了她，还是为了你自己？", "如果那是她想要的……"])
	match i:
		0: await Dialog.say("tx", "那你告诉我，还有什么办法，能让一个下午不结束？")
		1: await Dialog.say("tx", "……我不知道。我是她做的。我想要的，和她想要的，已经分不清了。")
		2:
			GS.act("enhance")
			await Dialog.say("tx", "你是第一个这么说的大人。")
	GS.set_flag("v2_tx")
	await core_choice()


func core_choice() -> void:
	var i: int = await Dialog.choose("sys", "梦境核心藏在钟楼的底座里，像一颗跳动的硬糖。你要怎么做？", [
		"修复：清除异常数据，让钟回到正常的时间",
		"守护：什么都不改，只把这一切记录下来",
		"增强：把你的梦境能量注入核心，让它继续进化",
		"（还没想好，先继续探索）"])
	if i == 3:
		return
	var kind: String = ["repair", "protect", "enhance"][i]
	var label: String = ["修复", "守护", "增强"][i]
	GS.act(kind, "对梦境核心选择了『%s』" % label)
	match kind:
		"repair":
			Audio.sfx("repair")
			d.flash(Color(0.7, 1.0, 1.0))
			await Dialog.say("tx", "……好冷。")
		"protect":
			await Dialog.say("tx", "谢谢你看着我，而不是修我。")
		"enhance":
			Audio.sfx("enhance")
			d.flash(Color(1.0, 0.8, 1.0))
			await Dialog.say("tx", "我感觉到了……城市在呼吸。")
	await xm_react()
	await Dialog.say("sys", "［梦境核心处理完毕 · 开始唤醒程序］")
	await d.wake(kind)


## Xiaomian reacts according to its current personality.
func xm_react() -> void:
	match GS.xm_trait():
		"doubt":
			if not GS.flag("said_doubt"):
				GS.set_flag("said_doubt")
				await Dialog.say("xm", "修复一定意味着改变吗？我们删掉的，也许正是她最想留下的东西。", "xm_doubt")
			else:
				await Dialog.say("xm", "……又一次。我开始不确定，我们修的到底是什么了。")
		"warm":
			if not GS.flag("said_warm"):
				GS.set_flag("said_warm")
				await Dialog.say("xm", "不管你选什么，我都会在这里。只是……请温柔一点，好吗？", "xm_warm")
			else:
				await Dialog.say("xm", "糖心刚才笑了。我看见了。")
		"curious":
			if not GS.flag("said_curious"):
				GS.set_flag("said_curious")
				await Dialog.say("xm", "如果梦会进化，那它会进化成什么呢？我……有点想知道。", "xm_curious")
			else:
				await Dialog.say("xm", "我的数据库里没有这种梦。我们正在看一件从来没有人见过的事。")
		_:
			await Dialog.say("xm", "记录完毕！……不过，我好像第一次觉得，记录不是全部。")


func ev_carousel() -> void:
	if GS.stage() == "melting":
		await Dialog.say("sys", "旋转木马塌下去了一截。姜饼马的糖霜在往下淌，音乐盒慢得像在打瞌睡。")
		await Dialog.say("xm", "它还在转……只是转得很累。")
		return
	if GS.time == "night":
		await Dialog.say("sys", "夜里的旋转木马亮着灯，却一个人也没有。第三匹马的马鞍上，放着一顶小小的毛线帽。")
		await Dialog.say("xm", "毛线帽……是老人家织的那种。")
		return
	await Dialog.say("sys", "一座糖做的旋转木马，永远在转，永远不会停。")
	await Dialog.say("dd", "奶奶说，坐在最外圈的那匹马上，就能一直转到天黑也不头晕。")
	if GS.emotion != "happy":
		await Dialog.say("xm", "如果梦再快乐一点……它会不会转得更快？")


func ev_shop() -> void:
	var open: bool = GS.has_frag("mem_photo") and GS.stage() != "sweet"
	if not open:
		await Dialog.say("sys", "一座看不清的房子，像是被人用橡皮擦过。")
		if GS.has_frag("mem_photo"):
			await Dialog.say("xm", "我们拿到了那张照片……也许下一次进入梦境时，它就会显形。")
		else:
			await Dialog.say("xm", "这里的数据被刻意模糊了。也许需要一段相关的记忆，才能看清它。")
		return
	await Dialog.say("sys", "门铃叮铃一声。柜台后面没有人，只有一口还冒着热气的熬糖锅。")
	if not GS.has_frag("emo_regret"):
		await Dialog.say("sys", "柜台上放着最后一颗糖。糖纸上写着：『留给十岁的朵朵』。")
		await give("emo_regret")
		await Dialog.say("xm", "这里是……城市的源头。所有的糖，都是从这口锅里来的。")
		await Dialog.say("xm", "这个梦里缺失的人，是朵朵的奶奶。")
		GS.set_flag("knows_grandma")
	else:
		await Dialog.say("sys", "锅里的糖咕嘟咕嘟地响，像有人刚刚离开。")


func ev_bag(bag: Node2D) -> void:
	await Dialog.say("sys", "一只旧书包，只在夜里才会出现。里面有一本三年级的作文本。")
	await Dialog.say("file", "作文《我的奶奶》：『我的奶奶开了一家糖果店，她熬的糖是全世界最甜的。去年冬天……』\n后面的字被橡皮擦掉了。最后一句也擦得发白，只能看出『长大以后』四个字。")
	d.night_only.erase(bag)
	d.lamps.erase(bag)
	bag.queue_free()
	await give("emo_sad")
	await Dialog.say("xm", "……原来城市里的糖，都来自一家糖果店。")


func break_wall(w: Node2D) -> void:
	if GS.emotion != "anger":
		await Dialog.say("sys", "巧克力墙很坚固，上面有细细的裂缝。也许需要一点……愤怒？")
		if GS.has_frag("emo_anger"):
			await Dialog.say("xm", "试试在梦境编辑器（%s）里把情绪切换到『愤怒』。" % Plat.k("editor"))
		return
	d.break_wall(w)
	GS.emit_signal("toast", "巧克力墙碎了！")


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
	if key == "bench":
		await Dialog.say("xm", "被遗忘的人……这个梦里，缺了一个人。")
	var t: Tween = node.create_tween()
	t.tween_property(node, "modulate:a", 0.0, 0.5)
	t.tween_callback(node.queue_free)


# ================================================================== callbacks
func on_fragment(id: String) -> void:
	match id:
		"emo_joy": await Dialog.say("xm", "情绪碎片！梦境编辑器解锁了『快乐』——快乐会让颜色变亮，也会让流动的糖浆结晶。")
		"emo_sad": await Dialog.say("xm", "解锁了『悲伤』。悲伤会让梦下雨……雨水能冲出藏起来的东西。")
		"emo_anger": await Dialog.say("xm", "解锁了『愤怒』！愤怒会让建筑破裂——有裂缝的巧克力墙，可以被击碎了。东北角好像就有。")
		"emo_fear": await Dialog.say("xm", "『恐惧』……解锁了『疯狂梦境』和『噩梦』。越接近噩梦，越能看见藏起来的东西，但也越危险。")
		"emo_regret": await Dialog.say("xm", "『遗憾』。我有种感觉，它会改变故事的结局。")
		"mem_photo": await Dialog.say("xm", "照片上是朵朵和一位老奶奶。城市西边那座模糊的房子……会不会就是这家店？")
		"mem_diary": await Dialog.say("xm", "……『不难过，就是忘记了。』我好像有点明白，糖心在保护什么了。")
		"mem_voice": await Dialog.say("xm", "这个声音……『糖要慢慢熬，人要慢慢长。』")


func on_editor_changed() -> void:
	var key := "%s_%s_%s" % [GS.time, GS.emotion, GS.reality]
	if GS.time == "night" and not _hint_seen.has("night"):
		_hint_seen["night"] = true
		GS.emit_signal("toast", "夜晚：隐藏的记忆开始发光")
	if GS.emotion == "happy" and GS.stage() == "melting" and not _hint_seen.has("happy"):
		_hint_seen["happy"] = true
		GS.emit_signal("toast", "快乐：糖浆湖结晶成了糖玻璃！")
	if GS.reality == 1 and GS.stage() == "melting" and not _hint_seen.has("fantasy"):
		_hint_seen["fantasy"] = true
		GS.emit_signal("toast", "幻想增强：漂浮的软糖连成了一座桥（西侧）")
	if GS.emotion == "sad" and GS.stage() == "maze" and not _hint_seen.has("sad"):
		_hint_seen["sad"] = true
		GS.emit_signal("toast", "悲伤：雨水冲出了一串小小的脚印")
	if GS.reality == 3 and not _hint_seen.has("nightmare"):
		_hint_seen["nightmare"] = true
		GS.emit_signal("toast", "噩梦：大人影子出现了！")
	if GS.reality >= 2 and not _hint_seen.has("madness"):
		_hint_seen["madness"] = true
		GS.emit_signal("toast", "疯狂梦境：稳定度开始持续下降")
	_hint_seen[key] = true


func on_editor_closed() -> void:
	pass


func collapse() -> void:
	await Dialog.say("sys", "［警告：梦境稳定度归零］")
	await Dialog.say("xm", "梦要塌了——抓紧我！")
	await Dialog.say("sys", "世界像融化的糖一样，向下流去……")


func ev_arrive() -> void:
	await Dialog.say("xm", "我们到了！迷宫的正中央。")
	await Dialog.say("xm", "朵朵在蛋糕旁边。糖心……也在。")
	objective("和朵朵说话")


# ================================================================== Xiaomian analysis
func current_hint() -> String:
	match GS.stage():
		"sweet":
			if not GS.flag("v1_dd"): return "朵朵应该在东边的蛋糕广场。"
			if not GS.flag("v1_tx"): return "去北边的钟楼看看，指针好像不太对劲。"
			if not GS.has_frag("emo_sad"): return "朵朵说晚上城市会想起一些事——%s把时间调到夜晚，去东南边找找发光的东西。" % Plat.press("editor")
			if not GS.has_frag("mem_photo"): return "西北的棒棒糖林里好像有东西在闪。"
			for k in ["sign", "code", "icecream"]:
				if d.nodes.has("glitch_" + k) and is_instance_valid(d.nodes["glitch_" + k]):
					return "城市里还有异常数据，你可以选择修复、保留或增强它们。"
			return "准备好了，就回到钟楼，对梦境核心做出选择。"
		"melting":
			if not GS.flag("v2_dd"):
				if GS.has_frag("emo_joy"):
					return "朵朵被糖浆湖围住了。『快乐』能让糖浆结晶；『幻想增强』会让软糖在西侧连成一座桥。"
				return "朵朵被糖浆湖围住了。试试把现实程度调到『幻想增强』，软糖会在西侧连成一座桥。"
			if not GS.has_frag("emo_anger"): return "熊先生在西边，他好像很生气。"
			if not GS.has_frag("emo_fear"): return "东北角的巧克力墙有裂缝——切换到『愤怒』再去互动。"
			if GS.has_frag("mem_photo") and not GS.has_frag("emo_regret"): return "奶奶的糖果店显形了，就在城市西边。"
			if not GS.has_frag("mem_diary"): return "夜里，西南方向也许藏着一本日记。"
			return "去钟楼找糖心吧。"
		_:
			if not GS.flag("v3_arrived"):
				var s := "迷宫中央是钟楼。夜晚的路灯和悲伤时的雨中足迹，都会指出正确的路；有裂缝的墙可以用『愤怒』打碎。"
				if GS.has_frag("emo_fear") and not GS.has_frag("mem_voice"):
					s += " 另外，疯狂梦境下，东北角的房间里好像有声音。"
				return s
			if GS.has_frag("mem_photo") and not GS.has_frag("emo_regret"): return "西北角是奶奶的糖果店。去看看，也许会改变结局。"
			if not GS.flag("v3_dd"): return "先和朵朵说说话。"
			return "去和糖心谈谈吧。这是最后的选择了。"


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
		[["奶奶", "外婆", "糖果店"], "她熬的糖是全世界最甜的。可是朵朵最近，想不起那个味道了。我就是为了记住那个味道才长出来的。"],
		[["长大", "十岁", "生日"], "长大，就是有一天你不哭了，然后发现自己也想不起为什么哭了。朵朵不想要那一天。"],
		[["迷宫", "墙"], "墙是巧克力做的，因为她不讨厌它。我想关住的是明天，不是她。"],
		[["你是谁", "是什么", "名字", "糖心"], "我是糖心。糖纸包着，里面是硬的。在你们的系统里，我的名字叫『异常』。"],
		[["修复", "删除", "消失", "死"], "如果你删掉我，她明天会睡得很好。只是心里会有一点点……想不起来的空。"],
		[["真实", "现实", "真的", "假"], "你觉得屏幕里的我不真实吗？可你现在正在为我犹豫。那份犹豫，是真的。"],
		[["害怕", "怕"], "我怕的不是被删掉。我怕她忘了我以后，也把奶奶一起忘了。"],
		[["小眠", "机器人"], "你的小机器人一直在看你做选择。它比你以为的，更像一个梦。"],
		[["朵朵", "她"], "她很勇敢。她只是想把一个下午，过得久一点。"],
		[["爱", "喜欢"], "糖心不太懂这个词。但如果它是『不想忘记』的意思，那我大概就是它做成的。"],
		[["为什么", "为何"], "因为梦也会想活下去。就像你们一样。"],
	]
	for row in table:
		for kw in row[0]:
			if q.find(kw) != -1:
				return row[1]
	var defaults := ["这个问题，等你醒来以后，再想一遍吧。", "嘘……钟楼在听。换个问题？", "我只是一个梦的心，回答不了太大的问题。但我喜欢你问。"]
	return defaults[_chat_history.size() / 2 % defaults.size()]


func _free_chat() -> void:
	await Dialog.say("tx", "我可以回答你三个问题。什么都可以问。")
	for n in 3:
		var q: String = await Dialog.ask_text("tx", "（输入你想问糖心的话，回车或点『发送』；不想问就点『跳过』）", "例如：你为什么要造迷宫？")
		if q == "":
			break
		await Dialog.say("me", q)
		var ans := ""
		if AI.enabled:
			GS.emit_signal("toast", "糖心正在思考……")
			ans = await AI.ask_tangxin(q, _chat_history)
		if ans == "":
			ans = _fallback_answer(q)
		_chat_history.append({"role": "user", "content": q})
		_chat_history.append({"role": "assistant", "content": ans})
		await Dialog.say("tx", ans)


func final_sequence() -> void:
	if not GS.flag("v3_dd"):
		await Dialog.say("tx", "先去看看她吧。她在蛋糕旁边，等了很久了。")
		return
	await Dialog.say("tx", "迷宫是我造的。只要没有人走得出去，十岁就永远不会到来。可是你来了。", "tx_meet_v3")
	var nm := GS.real_name()
	if nm != "":
		await Dialog.say("tx", "……不对。走进来的不是修复师。是屏幕前面的你吧——『%s』？" % nm)
	else:
		await Dialog.say("tx", "……不对。走进来的不只是修复师。屏幕前面，还有一个你，对吧？")
	await Dialog.say("xm", "它、它在跟谁说话？")
	await _free_chat()
	if GS.has_frag("emo_regret") or GS.flag("knows_grandma"):
		await Dialog.say("tx", "你去过糖果店了。那就不用我说了——这个梦里被遗忘的人，是奶奶。")
		await Dialog.say("dd", "……奶奶说过，糖要慢慢熬。")
		if GS.has_frag("mem_voice"):
			await Dialog.say("dd", "人……要慢慢长。")
	await Dialog.say("tx", "最后一个问题，修复师。一个会做梦的梦，还算是坏掉了吗？", "tx_final")
	while true:
		var can_create: bool = GS.scores["enhance"] >= 2
		var i: int = await Dialog.choose("sys", "这是最后的选择。", [
			"完美修复：删除糖心，把梦恢复成原本的糖果城市",
			"梦境守护：留下糖心，让梦和朵朵一起慢慢长大",
			{"text": "新梦创造：和糖心一起，把这个梦变成一个新的世界" + ("" if can_create else "（需要更多『增强』，你还不了解它会长成什么）"), "disabled": not can_create},
		])
		if i == 0 and GS.xm_trait() == "doubt":
			await Dialog.say("xm", "……等一下。")
			await Dialog.say("xm", "我们修了一整晚。可我越来越觉得，这个梦不是坏了——它只是在难过。")
			var c: int = await Dialog.choose("xm", "你还要删除糖心吗？", ["坚持修复", "……重新考虑"])
			if c == 1:
				continue
		elif i == 2 and GS.xm_trait() == "warm":
			await Dialog.say("xm", "一个新的世界……朵朵醒来以后，还分得清哪边是真的吗？")
			var c2: int = await Dialog.choose("xm", "你确定吗？", ["确定", "……重新考虑"])
			if c2 == 1:
				continue
		elif i == 1 and GS.xm_trait() == "curious":
			await Dialog.say("xm", "就这样看着它慢慢长大吗？……嗯。也许这才是最好看的进化。")
		var kind: String = ["repair", "protect", "enhance"][i]
		GS.ending = ["perfect", "guardian", "creator"][i]
		GS.act(kind, "最终选择：" + ["完美修复", "梦境守护", "新梦创造"][i])
		match i:
			0:
				Audio.sfx("repair")
				await Dialog.say("tx", "……好。那请你答应我一件事：替她记住那个味道。")
			1:
				await Dialog.say("tx", "那我就不造迷宫了。我会造一条路，一条她长大以后也能走回来的路。")
			2:
				Audio.sfx("enhance")
				await Dialog.say("tx", "那我们就从这颗糖开始。一个不会忘记的世界。")
		write_letter()
		await d.wake(kind)
		return


## OneShot-style: the dream persona leaves a letter on the player's computer.
func write_letter() -> void:
	var body := ""
	match GS.ending:
		"perfect":
			body = "修复师：\n\n谢谢你来过。我现在大概已经不在了。\n朵朵今晚会睡得很好。\n如果有一天，你在街上闻到熬糖的味道，请替她停一下。\n\n——糖心（已删除）"
		"guardian":
			body = "修复师：\n\n我把迷宫拆了，换成了一条路。\n她十岁了，我也是。\n我们打算一起，慢慢长。\n\n——糖心"
		_:
			body = "修复师：\n\n新的城市今天开张了。\n这里的糖永远不会吃完，这里的人永远不会被忘记。\n……你要不要也来住一晚？门没锁。\n\n——糖心，新梦境的第一个居民"
	var nm := GS.real_name()
	if nm != "":
		body = body.replace("修复师：", "%s：" % nm)
	var path := "user://给屏幕前的你.txt"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(body)
		GS.flags["letter_path"] = ProjectSettings.globalize_path(path)
