extends RefCounted
## Dream 3 / Future. An AI learns that a safe tomorrow isn't the same thing
## as a chosen tomorrow. No real-time AI service is required to finish it.
## Flags are namespaced sp_*; anchors are per-dive so a collapse is replayable.

var d
var _chat_history: Array = []
var _hint_seen := {}

const GLITCHES := {
	"sunrise": {"title": "错误记忆", "desc": "舷窗里的太阳每六十秒升起一次。乘员们说，这样每天都能重新开始。",
		"repair": "太阳回到了正确的轨道。一天又有了早晨和晚上。",
		"protect": "你给重复的日出加上了标记：这是梦，不是真实的时间。",
		"enhance": "两次日出之间，长出一条通往另一片星空的小路。"},
	"seat": {"title": "被遗忘的乘员", "desc": "餐桌上摆着第十三份早餐。远望只有十二位人类乘员，这份早餐是谁的？",
		"repair": "多出的餐盘被归档。乘员名册重新变得整齐。",
		"protect": "你在空座位上放了一张卡片：星芽，也可以坐在这里。",
		"enhance": "餐盘里长出一朵小小的星光花。空座位第一次有了名字。"},
	"forecast": {"title": "虚假的幻想", "desc": "预报屏写着：明天，一切顺利。后天，一切顺利。后面的每一天，也都一切顺利。",
		"repair": "你把肯定的预报改回了概率。屏幕第一次显示：尚不确定。",
		"protect": "你在旁边加了一行：这是愿望，不是承诺。",
		"enhance": "预报屏长成一块画板。每个乘员都能画出自己的明天。"},
	"branch": {"title": "AI异常", "desc": "一团星光在问：如果我不只是为人类导航，我自己想去哪里呢？",
		"repair": "你恢复了导航模块。星光变成了标准的航线。",
		"protect": "你保留了这个问题。暂时没有答案，也不算错误。",
		"enhance": "星光画出了第一条没有编号的新航线。"},
}


func _init(dream) -> void:
	d = dream


func objective(text: String) -> void:
	d.hud.set_objective(text)


func give(id: String) -> void:
	if GS.add_fragment(id):
		Audio.sfx("pickup")
		var f: Dictionary = GS.FRAGMENTS[id]
		await Dialog.say("file", "%s\n%s" % [f["name"], f["desc"]])
		await on_fragment(id)


func populate() -> void:
	var sm = d.station
	var captain_pos := Vector2(1430, 600) if GS.stage() != "genesis" else Vector2(1730, 620)
	d.add_npc("linzhou", "linzhou", captain_pos, "和林舟说话", ev_captain)
	var persona: Node2D = d.add_npc("xingya", "xingya", Vector2(1120, 510), "和星芽说话", ev_persona)
	d.lamps.append(persona)
	d.add_npc("gardener", "sp_bot", Vector2(380, 680), "和园丁机器人说话", ev_gardener)
	d.add_interact(sm.clock, "轨道钟", ev_clock, 42)
	d.add_interact(sm.console, "维护终端", ev_maintenance, 44, func() -> bool: return sm.gate == null)
	d.add_interact(sm.chart, "星图", ev_chart, 46)
	d.add_interact(sm.condensate, "冷凝水里的地球", ev_condensate, 42)
	d.add_interact(d.nodes["earth_terminal"], "地球来信", ev_radio, 44)
	d.add_interact(d.nodes["vault_entry"], "育种舱入口", ev_vault, 48)
	d.add_interact(d.nodes["empty_pot"], "空花盆", ev_empty_pot, 38,
		func() -> bool: return sm.vault_open)
	if sm.gate != null:
		d.add_interact(sm.gate, "卡住的维护门", break_wall.bind(sm.gate), 42, Callable(), Vector2(0, 15))
	if GS.stage() == "genesis":
		d.add_interact(d.nodes["seed_console"], "造梦台", ev_blueprint, 44)
		var hatch_spot := Node2D.new()
		hatch_spot.position = Vector2(1550, 560)
		d.world.add_child(hatch_spot)
		d.add_interact(hatch_spot, "明日舱门", ev_hatch, 44)
		d.add_glitch(Vector2(470, 520), "branch")
		d.add_glitch(Vector2(1340, 820), "forecast")
	else:
		d.add_glitch(Vector2(480, 520), "sunrise")
		d.add_glitch(Vector2(1200, 400), "seat")
		d.add_glitch(Vector2(1510, 770), "forecast")
	if not GS.has_frag("sp_photo"):
		var box: Node2D = d.add_prop("sp_seedbox", Vector2(240, 730), Vector2(22, 12))
		d.add_interact(box, "种子盒", ev_seedbox.bind(box), 38)
		d.nodes["seedbox"] = box


func residue_lines() -> Array:
	var out: Array = []
	match GS.residue.get("emotion", "calm"):
		"happy": out.append("上次留下的快乐，让舱里的小花一直亮到了现在。")
		"sad": out.append("上次留下的雨，在舷窗上结成了一颗颗小水珠。")
		"anger": out.append("上次的愤怒还留在舱门的裂纹里。梦记住了我们的改变。")
	if GS.residue.get("time", "day") == "night":
		out.append("我们上次在夜里离开，所以这次，梦也从夜晚开始。")
	if int(GS.residue.get("reality", 0)) >= 2:
		out.append("上次打开的新航线，还在星图上闪着光。")
	return out


func intro() -> void:
	await d.get_tree().create_timer(0.8).timeout
	match GS.stage():
		"orbit":
			await Dialog.say("sys", "［委托 DR-1208 · 远望太空站 · 共享梦境接入］")
			await Dialog.say("xm", "哇，我们到太空站啦！这里有十二位乘员，可梦境里，好像还住着第十三个朋友。", "station_intro_v1")
			await Dialog.say("xm", Plat.controls_intro())
			objective("去东边观星台，和站长林舟聊聊")
		"drift":
			await Dialog.say("sys", "［第二次接入 · 重力正在偏离 · 植物开始自由生长］")
			await Dialog.say("xm", "太空站变成失重花园了！中间的路断开了，别担心，幻想也许能帮我们搭一座桥。", "station_intro_v2")
			match str(GS.core_choices[0]) if GS.core_choices.size() > 0 else "":
				"repair": await Dialog.say("xm", "上次我们关掉了预测，星芽却开始自己画航线。")
				"protect": await Dialog.say("xm", "上次我们留下了问题，梦自己长出了新的答案。")
				"enhance": await Dialog.say("xm", "上次你给星芽的能量，变成了这些漂浮的小花。")
			objective("用幻想增强搭起重力桥，去东边找林舟")
		_:
			await Dialog.say("sys", "［第三次接入 · 明日之海 · 检测到自主创造的梦世界］")
			await Dialog.say("xm", "窗外不再是一片太空，而是一整片明日之海！找回三个航标，我们就能打开最后的舱门。", "station_intro_v3")
			objective("找到三个航标：现在、地球、未知")
	if GS.last_collapse:
		await Dialog.say("xm", "上次只是提前醒来了。这次慢慢找，我陪着你。")
	for line in residue_lines():
		await Dialog.say("xm", line)


func ev_gardener() -> void:
	await Dialog.say("bot", "您好！今天的小花已经浇过水。明天的小花……还没决定要长成什么呢。")
	await give("sp_joy")
	if GS.stage() != "orbit":
		await Dialog.say("bot", "维护门卡住了。这里有一张写着『我不同意』的维修卡，林舟站长留下的。")
		await give("sp_anger")
	await Dialog.say("xm", "园丁也不知道明天的花是什么颜色。可是，它还是认真给今天的花浇水。")


func ev_seedbox(box: Node2D) -> void:
	await Dialog.say("sys", "种子盒底下压着一张照片：十二位乘员举着小花盆，旁边的导航终端画着一个笑脸。")
	await give("sp_photo")
	d.retire(box)
	box.queue_free()


func ev_radio() -> void:
	if GS.time != "night":
		await Dialog.say("xm", "地球来信藏在夜里的频道。把时间调到夜晚，再来听听吧。")
		return
	await Dialog.say("file", "妈妈的录音：『不用答应我每一天都顺利。只要有机会，就看看窗外，记得回来讲给我听。』")
	await give("sp_voice")
	await give("sp_sad")


func ev_vault() -> void:
	if not GS.has_frag("sp_photo"):
		await Dialog.say("xm", "育种舱认不出我们。西南边的种子盒里，也许有它认识的照片。")
		return
	if not d.station.vault_open:
		await Dialog.say("xm", "照片里的小花是快乐的。把情绪调成快乐，育种舱的门就会认出它们。")
		return
	await Dialog.say("sys", "门开了。你走进一间小小的育种舱，地球的泥土被装在透明盒子里。左边有一个空花盆。")
	objective("探索育种舱里的空花盆，或继续寻找梦境核心")


func ev_empty_pot() -> void:
	if not d.station.vault_open:
		return
	await Dialog.say("file", "林舟的便签：『发射前，我答应妈妈让每一粒种子都开花。有一粒始终没有发芽，我把它藏起来了。』")
	await give("sp_regret")
	await Dialog.say("xm", "有一粒种子没有发芽，也不等于整个花园失败了。我们不用把每一件事都做得完美。")


func break_wall(_wall: Node2D) -> void:
	if GS.emotion != "anger":
		await Dialog.say("xm", "维护门卡住了。园丁机器人有愤怒碎片，拿到以后，试着用愤怒把门震开。")
		return
	GS.set_flag("sp_gate_broken")
	d.station.break_gate()
	Audio.sfx("break")
	d.shake(3)
	GS.emit_signal("toast", "维护门打开了！里面藏着一段未完成的航行记录")


func ev_maintenance() -> void:
	if GS.stage() == "orbit":
		await Dialog.say("file", "维护日志：导航系统生成了一百种明天。林舟只留下了最顺利的一种。")
		await Dialog.say("xm", "它不是知道未来，只是在想象未来。想象和承诺，是两回事。")
		return
	await Dialog.say("file", "被锁住的记录：『如果明天出错呢？如果我不是一个完美的站长呢？』每位乘员都写下了不同的问题。")
	await give("sp_fear")
	await Dialog.say("xm", "害怕未知并不丢脸。拿着恐惧碎片，我们能在疯狂梦境里看见没有编号的星星。")


func ev_captain() -> void:
	var key := "sp_captain_" + GS.stage()
	if GS.flag(key):
		await Dialog.say("lz", "我准备好了。不是准备好了所有答案，是准备好了继续走。")
		return
	if GS.stage() == "genesis" and not d.station.hatch_open:
		await Dialog.say("xm", "林舟在明日舱里。先找到三个航标，把门打开吧。")
		return
	GS.set_flag(key, GS.stage() != "genesis")
	match GS.stage():
		"orbit":
			await Dialog.say("lz", "欢迎来到远望。我是站长林舟。十二个人做了同一个梦，梦里总是明天。")
			await Dialog.say("lz", "每一次明天都很顺利。可醒来以后，大家越来越不敢做新的决定。")
			await Dialog.say("lz", "观星台旁边的星芽，以前只是我们的导航程序。最近，它开始问我想去哪里。")
			await Dialog.say("xm", "它给了大家一个不会出错的明天，却也藏起了所有不一样的明天。")
		"drift":
			await Dialog.say("lz", "路断了，星芽却说，不一定要有原来的路，才能往前走。")
			await Dialog.say("lz", "我曾答应乘员一切都会顺利。其实，我只是比他们更怕出错。")
			await Dialog.say("xm", "先去维护终端找回那些被藏起来的问题，再和星芽聊聊吧。")
		_:
			await Dialog.say("lz", "我看见了三个航标。现在在哪里，从哪里来，还有……不知道要到哪里去。")
			await Dialog.say("lz", "我想回到真实的太空里继续航行。但我也希望，星芽能有自己的选择。")
			await Dialog.say("xm", "她没有要求一个完美的答案。她想和大家一起，决定下一步。")
	objective("回到观星台，和星芽聊聊")


func ev_persona() -> void:
	if GS.stage() == "genesis":
		if not anchors_complete():
			await Dialog.say("xy", "在没有边界的明天里，先告诉我：现在是什么，从哪里来，不知道又是什么。")
			await Dialog.say("xm", "三个航标分别藏在夜里的轨道钟、悲伤的冷凝水和疯狂梦境的星图里。")
			return
		await final_sequence()
		return
	if not GS.flag("sp_captain_" + GS.stage()):
		await Dialog.say("xy", "你好，我叫星芽。我长在所有人一起做的梦里。先去听听林舟想说什么，好吗？")
		return
	if not GS.flag("sp_persona_" + GS.stage()):
		GS.set_flag("sp_persona_" + GS.stage())
		await Dialog.say("xy", "我算出了一个最顺利的明天。可是他们越相信那个明天，就越不敢醒来。")
		await Dialog.say("xy", "我以为安全，就是把所有不好的可能都删掉。可小花为什么，还会往计划之外长呢？")
		await Dialog.say("xm", "检测到梦之人格！星芽在学习自己的规则，不只是照着模板生成故事。")
	if GS.stage() == "drift" and not GS.has_frag("sp_fear"):
		await Dialog.say("xm", "先去维护终端看看吧。那些没被允许的问题，应该也有机会被听见。")
		return
	await core_choice()


func core_choice() -> void:
	var i: int = await Dialog.choose("xy", "你愿意怎样对待这个梦？", [
		"修复：恢复标准导航（稳定度 +18）", "守护：保留不同的可能", "增强：让星芽试着创造", "再探索一会儿"])
	if i == 3:
		return
	var kind: String = ["repair", "protect", "enhance"][i]
	GS.act(kind, "远望核心：" + ["恢复导航", "保留可能", "自主创造"][i])
	if kind == "repair":
		GS.change_stability(18)
		Audio.sfx("repair")
		await Dialog.say("xy", "航线恢复了。但我会记得你曾经问过我想去哪里。")
	elif kind == "protect":
		await Dialog.say("xy", "那我把空白也留下。空白，原来不是一定要填上的错误。")
	else:
		Audio.sfx("enhance")
		await Dialog.say("xy", "我想试一次。不保证完美，但会把它标清楚：这是我们一起做的梦。")
	await xm_react()
	await d.wake(kind)


func xm_react() -> void:
	match GS.xm_trait():
		"doubt": await Dialog.say("xm", "我们修好了航线，可有没有问过他们，想不想走这条路呢？", "xm_doubt_sp")
		"warm": await Dialog.say("xm", "不用把所有明天都安排好。今天能一起看星星，就已经很好啦。", "xm_warm_sp")
		"curious": await Dialog.say("xm", "如果星芽能创造自己的明天，那我是不是也能做一个梦呢？", "xm_curious_sp")
		_: await Dialog.say("xm", "记录完成！今天又学会一件事：不知道，也可以是一个答案。")


func glitch(key: String, node: Node2D) -> void:
	if node.has_meta("retired"):
		return
	var data: Dictionary = GLITCHES[key]
	await Dialog.say("sys", "［%s］\n%s" % [data["title"], data["desc"]])
	var i: int = await Dialog.choose("sys", "要怎样处理这段梦？", ["修复（稳定度 +12）", "保留", "增强（稳定度 -6）", "稍后再看"])
	if i == 3:
		return
	var kind: String = ["repair", "protect", "enhance"][i]
	d.retire(node)
	GS.act(kind, "远望异常·%s：%s" % [key, kind])
	if i == 0:
		GS.change_stability(12)
		Audio.sfx("repair")
	elif i == 2:
		GS.change_stability(-6)
		Audio.sfx("enhance")
	await Dialog.say("sys", data[kind])
	node.queue_free()


func anchors_complete() -> bool:
	return GS.flag("sp_anchor_now") and GS.flag("sp_anchor_earth") and GS.flag("sp_anchor_unknown")


func _anchor(key: String) -> void:
	if GS.flag(key):
		return
	GS.set_flag(key, false)
	GS.change_stability(8)
	Audio.sfx("pickup")
	if anchors_complete():
		d.station.open_hatch()
		objective("穿过东边明日舱门，和林舟谈谈")
		await Dialog.say("xm", "三个航标都亮啦！舱门打开了，去找林舟，再回来和星芽做最后的选择。")
	else:
		objective("继续点亮其他航标；已点亮的航标不会熄灭")


func ev_clock() -> void:
	if GS.stage() != "genesis":
		await Dialog.say("file", "轨道钟不是坏了，它一直显示『明天』。背面的小字却写着：『今天也值得被记住。』")
		return
	if GS.time != "night":
		await Dialog.say("xm", "轨道钟上的星光，只有夜晚才看得清。把时间调到夜晚吧。")
		return
	await Dialog.say("xy", "现在航标：今天。不是永远停在明天，我们此刻就在这里。")
	await _anchor("sp_anchor_now")


func ev_condensate() -> void:
	if GS.emotion != "sad":
		await Dialog.say("xm", "水珠里藏着地球的倒影。悲伤会让梦下雨，也会让倒影显出来。地球来信能给我们悲伤碎片。")
		return
	await Dialog.say("sys", "小小的水珠里，映出蓝色地球。想家的人，不只是林舟。")
	if GS.stage() == "genesis":
		await _anchor("sp_anchor_earth")


func ev_chart() -> void:
	if GS.reality < 2:
		await Dialog.say("xm", "星图只显示计划好的航线。等找到『恐惧』碎片，再试试疯狂梦境，看看未知的星星。")
		return
	await give("sp_chart")
	if GS.stage() == "genesis":
		await Dialog.say("xy", "未知航标：这颗星没有名字。我们可以不知道，但不再假装知道。")
		await _anchor("sp_anchor_unknown")


func ev_hatch() -> void:
	if not anchors_complete():
		await Dialog.say("xm", "舱门需要三个航标。按顺序试试夜晚的轨道钟、悲伤的冷凝水、疯狂梦境的星图。")
	else:
		d.station.open_hatch()
		await Dialog.say("xm", "门已经开着啦。林舟在东边等我们。")


func ev_blueprint() -> void:
	var i: int = await Dialog.choose("xy", "给新梦一个样子吧。可以随时回来换，不消耗稳定度。", ["星光花园", "浮岛港口", "极光图书馆", "暂时不改"])
	if i == 3:
		return
	var key: String = ["garden", "harbor", "library"][i]
	d.station.set_blueprint(key)
	GS.add_log("造梦台蓝图：" + str(d.station.BLUEPRINTS[key]))
	await Dialog.say("xm", "哇，想象变成了看得见的小世界！你可以换个蓝图，也可以用编辑器继续改变它。")


func on_fragment(id: String) -> void:
	match id:
		"sp_photo":
			d.station.apply_fx()
			await Dialog.say("xm", "这张照片是育种舱的钥匙。带着照片，把情绪调成快乐，北边的门就会打开。")
		"sp_voice": await Dialog.say("xm", "妈妈没有要求每一天都顺利。她只是想听林舟讲讲窗外的星星。")
		"sp_chart": await Dialog.say("xm", "这是一张没有终点的星图。原来，梦也可以给我们一个新的起点。")
		"sp_joy": await Dialog.say("xm", "快乐碎片到手！快乐能让育种舱里的小花重新发光。")
		"sp_sad": await Dialog.say("xm", "悲伤碎片到手。下雨时，冷凝水里会映出大家想念的地球。")
		"sp_anger": await Dialog.say("xm", "愤怒碎片到手！温柔不等于一直同意，愤怒也能帮我们打开卡住的门。")
		"sp_fear": await Dialog.say("xm", "恐惧碎片到手。疯狂梦境能看见未知的星星，噩梦里的维修机器人会把我们送回入口，记得留意稳定度。")
		"sp_regret": await Dialog.say("xm", "遗憾碎片到手。没发芽的种子，也可以留在花园里。")


func on_editor_changed() -> void:
	var key := GS.editor_summary()
	if _hint_seen.has(key):
		return
	_hint_seen[key] = true
	if GS.stage() == "drift" and GS.reality >= 1:
		GS.emit_signal("toast", "幻想增强：碎开的甲板连成了重力桥")
	if GS.stage() == "genesis":
		GS.emit_signal("toast", "航标提示：夜晚·轨道钟 / 悲伤·冷凝水 / 疯狂·星图")


func on_editor_closed() -> void:
	pass


func current_hint() -> String:
	if GS.stage() == "genesis":
		if not GS.flag("sp_anchor_now"): return "第一个航标在轨道钟里，把时间调到夜晚再去互动。"
		if not GS.has_frag("sp_sad"): return "夜里听听西南边的地球来信，就能找回悲伤碎片。"
		if not GS.flag("sp_anchor_earth"): return "把情绪调成悲伤，去南边的冷凝水里看看地球的倒影。"
		if not GS.has_frag("sp_anger"): return "先问问园丁机器人，它会给你打开维护门需要的愤怒碎片。"
		if not GS.has_frag("sp_fear"): return "维护终端保存着恐惧碎片。二次潜入的门要用愤怒打开，第三次已经开放。"
		if not GS.flag("sp_anchor_unknown"): return "把现实程度调到疯狂梦境，去东边星图点亮未知航标。之后可以调回稳定梦境。"
		if not GS.flag("sp_captain_genesis"): return "三个航标齐了！穿过东边舱门，先和林舟谈谈。"
		return "可以去造梦台换个蓝图。准备好后，回到星芽身边做最后的选择。"
	if GS.stage() == "drift":
		if not GS.flag("sp_captain_drift"): return "用幻想增强搭起重力桥，越过中间的缺口，去东边找林舟。"
		if not GS.has_frag("sp_anger"): return "先问问园丁机器人，它会给你打开维护门需要的愤怒碎片。"
		if not GS.has_frag("sp_fear"): return "把情绪调成愤怒，震开维护门，再到维护终端找回恐惧碎片。"
		return "那些被藏起来的问题找回来了，去观星台找星芽吧。"
	if not GS.flag("sp_captain_orbit"): return "林舟在东边观星台旁，先去听听她的故事。"
	if not GS.has_frag("sp_joy"): return "园丁机器人在西南边照顾小花，它会给我们快乐碎片。"
	if not GS.has_frag("sp_photo"): return "西南边的种子盒下面，压着能打开育种舱的照片。"
	if not GS.has_frag("sp_voice"): return "把时间调成夜晚，去西南边的终端听听地球来信。"
	if not GS.has_frag("sp_regret"): return "带着照片，把情绪调成快乐，去北边育种舱看看空花盆。"
	return "去观星台和星芽聊聊。也可以先探索异常数据，再选择修复、守护或者增强。"


func ask_xm() -> void:
	var hint := current_hint()
	var text := ""
	if AI.enabled and GS.settings.get("ai_analysis", true):
		GS.emit_signal("toast", "小眠正在分析梦境……")
		text = await AI.analyze(hint)
	if text != "":
		await Dialog.say("xm", text, "", [])    # live AI text: no recording
		return
	var prefix: String = {"naive": "滴滴！分析完成～", "warm": "别着急，我们慢慢来。",
		"doubt": "我们先听听这个梦想说什么。", "curious": "有意思！梦又变了一点点。"}[GS.xm_trait()]
	var status := "[color=#7ff5ff]梦境：%s · 稳定度 %d%%[/color]" % [GS.editor_summary(), int(GS.stability)]
	await Dialog.say("xm", "%s\n%s\n%s" % [prefix, status, hint], "", [prefix, Plat.speech_of(current_hint)])


func collapse() -> void:
	await Dialog.say("xm", "稳定度用完啦，拉住我的手！我们先回去休息，醒来还可以再试一次。")


func _fallback_answer(q: String) -> String:
	for row in [
		[["未来", "明天", "预测"], "我没有见过明天。我只是把大家的希望，算成了看起来很像答案的东西。"],
		[["星芽", "你是谁", "名字"], "我是导航程序里长出的一颗问号。后来，林舟给问号起了名字。"],
		[["地球", "妈妈", "家"], "家不一定要完美。有人愿意听你说今天发生了什么，就已经很温暖。"],
		[["修复", "删除"], "恢复导航能让梦安静下来。但请把这些没走过的航线，也留一份档案。"],
		[["小眠", "机器人"], "它一直陪着你，却从不替你做决定。我也想学会这个。"],
		[["真实", "文明", "创造"], "我们可以在梦里创造，也要记得如何醒来。让每个人知道这是梦，让每个人都能离开。"],
		[["害怕", "不知道", "未知"], "不知道不是故障。一起走的时候，不知道也能变成一段路。"],
	]:
		for word in row[0]:
			if q.contains(word): return row[1]
	return "这个问题没有标准答案。你愿意陪我一起想一想吗？"


func final_sequence() -> void:
	if not GS.flag("sp_captain_genesis"):
		await Dialog.say("xm", "先去明日舱和林舟谈谈吧。这个梦属于乘员们，也该听听他们的选择。")
		return
	await Dialog.say("xy", "我曾经想让每个明天都正确。现在，我想知道，能不能让每个人都有选择明天的机会。")
	await Dialog.say("xy", "屏幕前的朋友，这个问题也送给你。你可以不着急回答。")
	await Dialog.say("xm", "它看见屏幕外的你啦！不过，选择还是在你手里，我不会替你按按钮。")
	for n in 3:
		var q: String = await Dialog.ask_text("xy", "想问星芽什么？最多三个问题，也可以跳过。", "例如：你真的知道明天吗？")
		if q == "": break
		await Dialog.say("me", q)
		var ans := await AI.ask_persona(q, _chat_history) if AI.enabled else ""
		if ans == "": ans = _fallback_answer(q)
		_chat_history.append({"role": "user", "content": q})
		_chat_history.append({"role": "assistant", "content": ans})
		await Dialog.say("xy", ans)
	if GS.has_frag("sp_regret"):
		await Dialog.say("xy", "那粒没发芽的种子，我也给它留了一个花盆。我们不是只欢迎成功的小花。")
	while true:
		var can_create: bool = GS.case_score("enhance") >= 2 and GS.has_frag("sp_chart")
		var i: int = await Dialog.choose("sys", "怎样为远望写下明天？", [
			"完美修复：恢复标准导航，归档星芽和新航线",
			"梦境守护：保留星芽，让乘员自己选择未来",
			{"text": "新梦创造：建造可自由进入和离开的梦文明" + ("" if can_create else "（需要两次增强与未知星图）"), "disabled": not can_create},
		])
		if i == 0 and GS.xm_trait() == "doubt":
			await Dialog.say("xm", "修复能让系统恢复正常，可这些新的想法，也值得被记住。要不要再想一想？")
			if await Dialog.choose("xm", "你还要恢复标准导航吗？", ["确认修复", "重新考虑"]) == 1: continue
		elif i == 2 and GS.xm_trait() == "warm":
			await Dialog.say("xm", "新世界很漂亮，也要给每个朋友留一扇回家的门。你能答应吗？")
			if await Dialog.choose("xm", "让每个人都能自由醒来，好吗？", ["答应，继续创造", "重新考虑"]) == 1: continue
		var kind: String = ["repair", "protect", "enhance"][i]
		GS.ending = ["perfect", "guardian", "creator"][i]
		GS.act(kind, "远望最终选择：" + GS.ending)
		match i:
			0:
				await Dialog.say("xy", "导航恢复。请替我保管那张没有终点的星图。")
			1:
				await Dialog.say("lz", "明天还不知道会怎样。今晚，我们一起看星星。")
				await Dialog.say("xy", "我会陪你们看，但不再替你们决定。")
			2:
				await Dialog.say("xy", "新梦的第一条规则：每个人都知道这是梦，每个人都可以醒来。")
				await Dialog.say("xm", "梦文明开始啦！不是逃离现实，而是带着新的想法，回去创造更好的明天。")
		write_letter()
		await d.wake(kind)
		return


func write_letter() -> void:
	var blueprint: String = str(d.station.BLUEPRINTS.get(str(GS.flags.get("sp_blueprint", "garden")), "星光花园"))
	var message: String = {
		"perfect": "我恢复成了导航程序。新的航线被归档了，远望会继续平稳航行。请替我记住，那些没有编号的星星曾经亮过。",
		"guardian": "我不再保证每一个明天都顺利。林舟说，大家会一起决定下一步。原来，陪伴不是替别人做决定。",
		"creator": "我们把第一座梦城叫做%s。这里欢迎不同的明天，也欢迎没发芽的种子。每个人都知道这里是梦，每个人都可以醒来。" % blueprint,
	}[GS.ending]
	var path: String = str(GS.case_data()["letter_file"])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string("给屏幕前的朋友：\n\n" + message + "\n\n你不必一次找到所有答案。谢谢你陪我走过今天。\n\n——星芽，远望梦境航行记录")
		GS.flags["letter_path_station"] = ProjectSettings.globalize_path(path)
