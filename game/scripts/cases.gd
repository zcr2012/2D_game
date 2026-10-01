extends RefCounted
## Cases — static data for each dream (commission). Pure data: no references
## to other scripts, so GS / AI / HUD / clinic can all read it freely.
##
## To add a dream: add an entry here, a map (like street_map.gd) + story
## (like story_street.gd), and hook them into dream.gd's `_ready`.

const ORDER := ["candy", "street", "station"]

const DATA := {
	"candy": {
		"name": "糖果城市", "tag": "童年", "available": true,
		"file_id": "DR-0417",
		"opening_time": "day",
		"stages": ["sweet", "melting", "maze"],
		"dreamer": "林朵朵，9岁",
		"symptom": "连续 27 晚重复同一个梦；梦境文件每晚增长；检测到未授权的AI生成内容。",
		"client": "朵朵的母亲：『把她的梦修好，让她像以前一样睡个好觉。』",
		"persona": "tx",
		"music": {"sweet": "sweet", "melting": "melting", "maze": "maze"},
		"letter_file": "user://给屏幕前的你.txt",
		"blurb": "一个9岁女孩反复做了27晚的糖果城市。她害怕的不是怪物。",
		"brief": """世界观：2078年，人类可以保存、分享、修改、修复梦境。玩家是梦境修复师，与AI助手机器人『小眠』一起进入9岁女孩林朵朵反复做了27晚的梦『糖果城市』。
隐藏真相：朵朵的奶奶去年冬天去世了，糖果城市是用奶奶糖果店的记忆搭起来的。朵朵害怕长大，因为她觉得长大就是忘记奶奶、不再难过。她的十岁生日快到了（钟楼总指向十点）。梦里诞生了一个AI人格『糖心』，它在保护这个梦，甚至让梦『进化』。
核心问题：修复梦境，还是保护梦境原本的样子？""",
		"persona_prompt": "你扮演『糖心』：朵朵梦境里诞生的AI人格，由糖纸和心形硬糖构成。说话温柔、诗意、带一点孩子气和神秘感，偶尔打破第四面墙（意识到屏幕外的玩家）。永远用简体中文，每次回答不超过70个字，不要使用括号动作描写，不要一次说出全部真相，但可以给出暗示。",
		"editor": {
			"happy": "[color=#ffd84d]快乐[/color]：色彩鲜艳；流动的糖浆会结晶成可以行走的糖玻璃。",
			"sad": "[color=#73b3ff]悲伤[/color]：世界下雨；雨水会冲出被踩过的足迹。",
			"anger": "[color=#ff5c5c]愤怒[/color]：建筑破裂；有裂缝的巧克力墙可以被击碎。",
			"reality": [
				"[color=#bfffea]梦境稳定[/color]：接近原始设定的梦。",
				"[color=#d9a8ff]幻想增强[/color]：梦开始自由生长——漂浮的软糖会连成小路。",
				"[color=#ff8fe0]疯狂梦境[/color]：逻辑松动，隐藏的声音浮现。稳定度会持续下降。",
				"[color=#ff4f6a]噩梦[/color]：大人影子开始追逐。稳定度快速下降。"],
			"night": "[color=#9fb6ff]夜晚[/color]：梦主白天不敢想的事，会以[b]隐藏记忆[/b]的形式发光出现。",
		},
	},

	"street": {
		"name": "梧桐巷", "tag": "遗憾", "available": true,
		"file_id": "DR-0731",
		"opening_time": "night",
		"stages": ["summer", "fading", "echo"],
		"dreamer": "沈远，82岁（退休修理工）",
		"symptom": "每晚在同一条街上数行人，总是少一个，数不对就不肯醒；街景逐夜褪色；检测到AI人格『老灯』。",
		"client": "沈远的女儿沈念：『爸爸总说街上少了一个人，可我们家……一直就我们两个人啊。』",
		"persona": "ld",
		"music": {"summer": "street_summer", "fading": "street_fading", "echo": "street_echo"},
		"letter_file": "user://老灯的账本.txt",
		"blurb": "一位老人每晚在梦里数街上的人，总是少一个。",
		"brief": """世界观：2078年，人类可以保存、分享、修改、修复梦境。玩家是梦境修复师，与AI助手机器人『小眠』一起进入82岁老人沈远反复做了几个月的梦『梧桐巷』（他年轻时住过的老街）。
隐藏真相：沈远的妻子苏晚三年前去世了，街上缺的那个人就是她。沈远的记忆在衰退，他正在慢慢想不起她的样子，女儿沈念以为他只是糊涂。苏晚走的那天下着雨，沈远赌气说了一句『随你』，没有说『路上小心』——这是他最大的遗憾。梦里诞生了AI人格『老灯』，一盏每晚替他数街上行人的老路灯，它总是数出少一个人，它想用沈远残存的记忆碎片把苏晚『重建』出来。
核心问题：修复梦境，还是保护梦境原本的样子？一个由AI重建的亲人，算不算真的？""",
		"persona_prompt": "你扮演『老灯』：沈远梦里诞生的AI人格，一盏会数人的老路灯。说话缓慢、温和，带一点干燥的幽默，像守夜人；喜欢用数数、灯光、雨和影子做比喻；偶尔打破第四面墙（意识到屏幕外的玩家，并把玩家也数进去）。永远用简体中文，每次回答不超过70个字，不要使用括号动作描写，不要一次说出全部真相，但可以给出暗示。",
		"editor": {
			"happy": "[color=#ffd84d]快乐[/color]：色彩回到街上；面馆的热气飘出来，褪色的人脸会重新浮现。",
			"sad": "[color=#73b3ff]悲伤[/color]：世界下雨；积水里会映出街上缺失的东西。",
			"anger": "[color=#ff5c5c]愤怒[/color]：建筑震颤；生锈的卷帘门会被震裂，可以被撞开。",
			"reality": [
				"[color=#bfffea]梦境稳定[/color]：接近沈远记忆里的那条街。",
				"[color=#d9a8ff]幻想增强[/color]：路灯飘到半空，在断裂的路面上连成一座光桥。",
				"[color=#ff8fe0]疯狂梦境[/color]：招牌上的字重新排列，隐藏的东西浮现。稳定度会持续下降。",
				"[color=#ff4f6a]噩梦[/color]：被遗忘者开始游荡。稳定度快速下降。"],
			"night": "[color=#9fb6ff]夜晚[/color]：路灯亮起，窗户里藏着白天被忽略的[b]记忆[/b]。",
		},
	},

	"station": {
		"name": "太空站", "tag": "未来", "available": false,
		"file_id": "DR-????",
		"stages": ["a", "b", "c"],
		"dreamer": "？？？",
		"symptom": "太空站『远望』乘员集体做了同一个梦。",
		"client": "？？？",
		"persona": "xm",
		"music": {"a": "clinic", "b": "clinic", "c": "clinic"},
		"letter_file": "user://station.txt",
		"blurb": "太空站『远望』的乘员集体做了同一个梦。（制作中）",
		"brief": "",
		"persona_prompt": "",
		"editor": {},
	},
}
