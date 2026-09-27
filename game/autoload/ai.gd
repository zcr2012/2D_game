extends Node
## AI — optional live LLM narration (Anthropic Messages API).
##
## The game is fully playable offline: every call site has authored fallback
## text. To enable live generation, either set the environment variable
## ANTHROPIC_API_KEY, or create  user://ai_config.cfg :
##
##   [anthropic]
##   api_key="sk-ant-..."
##   model="claude-sonnet-4-5"
##
## (user:// is shown on the title screen; on Windows it is
##  %APPDATA%/Godot/app_userdata/梦境修复师 Dream Repair/)

const ENDPOINT := "https://api.anthropic.com/v1/messages"

var api_key := ""
var model := "claude-sonnet-4-5"
var enabled := false
var last_error := ""

const WORLD_BRIEF := """世界观：2078年，人类可以保存、分享、修改、修复梦境。玩家是梦境修复师，与AI助手机器人『小眠』一起进入9岁女孩林朵朵反复做了27晚的梦『糖果城市』。
隐藏真相：朵朵的奶奶去年冬天去世了，糖果城市是用奶奶糖果店的记忆搭起来的。朵朵害怕长大，因为她觉得长大就是忘记奶奶、不再难过。她的十岁生日快到了（钟楼总指向十点）。梦里诞生了一个AI人格『糖心』，它在保护这个梦，甚至让梦『进化』。
核心问题：修复梦境，还是保护梦境原本的样子？"""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	api_key = OS.get_environment("ANTHROPIC_API_KEY")
	var cfg := ConfigFile.new()
	if cfg.load("user://ai_config.cfg") == OK:
		api_key = str(cfg.get_value("anthropic", "api_key", api_key))
		model = str(cfg.get_value("anthropic", "model", model))
	enabled = api_key.strip_edges() != ""


## Saves / clears the API key from the in-game settings (needed on phones).
func configure(key: String) -> void:
	api_key = key.strip_edges()
	enabled = api_key != ""
	if GS.test_mode:
		return
	var cfg := ConfigFile.new()
	cfg.load("user://ai_config.cfg")
	cfg.set_value("anthropic", "api_key", api_key)
	cfg.set_value("anthropic", "model", model)
	cfg.save("user://ai_config.cfg")


func status_text() -> String:
	return ("AI 叙事：已连接（%s）" % model) if enabled else "AI 叙事：离线模式（使用预设文本，可在『设置』里填写 API Key）"


## Returns generated text, or "" on failure / offline (caller uses fallback).
func complete(system: String, messages: Array, max_tokens := 220) -> String:
	if not enabled:
		return ""
	var http := HTTPRequest.new()
	http.timeout = 25.0
	add_child(http)
	var body := {"model": model, "max_tokens": max_tokens, "system": system, "messages": messages}
	var headers := PackedStringArray([
		"content-type: application/json",
		"x-api-key: " + api_key,
		"anthropic-version: 2023-06-01",
	])
	var err := http.request(ENDPOINT, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		last_error = "request error %d" % err
		return ""
	var res: Array = await http.request_completed
	http.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		last_error = "http %s / %s" % [res[0], res[1]]
		push_warning("AI request failed: " + last_error + " " + (res[3] as PackedByteArray).get_string_from_utf8().left(300))
		return ""
	var data = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not data is Dictionary or not data.has("content"):
		return ""
	var out := ""
	for block in data["content"]:
		if block is Dictionary and block.get("type", "") == "text":
			out += str(block.get("text", ""))
	return out.strip_edges()


func state_brief() -> String:
	var frs: Array = []
	for id in GS.fragments.keys():
		frs.append(GS.FRAGMENTS[id]["name"])
	return "当前：第%d次潜入（%s）。梦境编辑器状态：%s。稳定度%d。玩家累计：修复%d次、守护%d次、增强%d次。已收集碎片：%s。小眠性格：%s。" % [
		GS.dive(), GS.STAGE_NAMES[GS.stage()], GS.editor_summary(), int(GS.stability),
		GS.scores["repair"], GS.scores["protect"], GS.scores["enhance"],
		"、".join(frs) if frs.size() > 0 else "无", GS.trait_name()]


## The dream persona "糖心" answering a free-form question from the player.
func ask_tangxin(question: String, history: Array) -> String:
	var system := WORLD_BRIEF + "\n\n你扮演『糖心』：朵朵梦境里诞生的AI人格，由糖纸和心形硬糖构成。说话温柔、诗意、带一点孩子气和神秘感，偶尔打破第四面墙（意识到屏幕外的玩家）。永远用简体中文，每次回答不超过70个字，不要使用括号动作描写，不要一次说出全部真相，但可以给出暗示。\n" + state_brief()
	var msgs: Array = history.duplicate()
	msgs.append({"role": "user", "content": question})
	return await complete(system, msgs, 200)


## Xiaomian's live dream analysis.
func analyze(hint: String) -> String:
	var system := WORLD_BRIEF + "\n\n你扮演『小眠』：修复师的AI助手小机器人，性格会随玩家行为改变。当前性格：" + GS.trait_name() + "（懵懂=天真好奇的新手；温柔=体贴，希望保护梦；怀疑=开始质疑『修复就是抹除』；好奇=想看看梦会进化成什么）。请用简体中文，给出一段不超过80字的『梦境分析』，自然地包含下面这条游戏提示，不要剧透隐藏真相。\n" + state_brief()
	return await complete(system, [{"role": "user", "content": "游戏提示：" + hint + "\n请分析当前梦境。"}], 200)
