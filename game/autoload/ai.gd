extends Node
## AI — optional live LLM narration through any of several API protocols.
##
## The game is fully playable offline: every call site has authored fallback
## text. Live generation needs ONE configured provider:
##
##   * 在『设置 → AI 接口设置』里选择厂商预设（Claude / OpenAI / Gemini /
##     DeepSeek / Kimi / 通义千问 / 智谱 / SiliconFlow / OpenRouter / Ollama /
##     LM Studio），填 Key 即可；
##   * 或者『添加自定义接口』：任意 OpenAI 兼容 / Anthropic / Gemini /
##     OpenAI Responses 协议的地址，可自定义请求头和额外请求体（JSON）；
##   * 也可以用环境变量（ANTHROPIC_API_KEY、OPENAI_API_KEY、GEMINI_API_KEY、
##     DEEPSEEK_API_KEY、MOONSHOT_API_KEY、DASHSCOPE_API_KEY、ZHIPU_API_KEY、
##     SILICONFLOW_API_KEY、OPENROUTER_API_KEY）；DREAM_AI_PROVIDER=<id> 指定使用哪个。
##
## 配置保存在 user://ai_providers.json（旧版 user://ai_config.cfg 会自动迁移）。
##
## Protocols ("type"):
##   openai            POST {base}/chat/completions     Authorization: Bearer
##   openai_responses  POST {base}/responses            Authorization: Bearer
##   anthropic         POST {base}/v1/messages          x-api-key
##   gemini            POST {base}/models/{m}:generateContent   x-goog-api-key

const CONFIG_PATH := "user://ai_providers.json"
const LEGACY_PATH := "user://ai_config.cfg"

const TYPES := {
	"openai": "OpenAI 兼容（Chat Completions）",
	"openai_responses": "OpenAI Responses",
	"anthropic": "Anthropic Messages（Claude）",
	"gemini": "Google Gemini（generateContent）",
}
const TYPE_ORDER := ["openai", "anthropic", "gemini", "openai_responses"]

## Built-in provider templates. Users edit key / model / url; presets can be
## reset but not deleted.
const PRESETS := [
	{"id": "anthropic", "name": "Anthropic Claude", "type": "anthropic",
		"base_url": "https://api.anthropic.com", "model": "claude-sonnet-4-5", "env": "ANTHROPIC_API_KEY"},
	{"id": "openai", "name": "OpenAI", "type": "openai",
		"base_url": "https://api.openai.com/v1", "model": "gpt-4o-mini", "env": "OPENAI_API_KEY",
		"max_tokens_param": "max_completion_tokens", "temperature": -1.0},
	{"id": "gemini", "name": "Google Gemini", "type": "gemini",
		"base_url": "https://generativelanguage.googleapis.com/v1beta", "model": "gemini-2.5-flash", "env": "GEMINI_API_KEY"},
	{"id": "deepseek", "name": "DeepSeek 深度求索", "type": "openai",
		"base_url": "https://api.deepseek.com/v1", "model": "deepseek-chat", "env": "DEEPSEEK_API_KEY"},
	{"id": "moonshot", "name": "Moonshot Kimi 月之暗面", "type": "openai",
		"base_url": "https://api.moonshot.cn/v1", "model": "moonshot-v1-8k", "env": "MOONSHOT_API_KEY"},
	{"id": "qwen", "name": "阿里云百炼 通义千问", "type": "openai",
		"base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1", "model": "qwen-plus", "env": "DASHSCOPE_API_KEY"},
	{"id": "zhipu", "name": "智谱 GLM", "type": "openai",
		"base_url": "https://open.bigmodel.cn/api/paas/v4", "model": "glm-4-flash", "env": "ZHIPU_API_KEY"},
	{"id": "siliconflow", "name": "SiliconFlow 硅基流动", "type": "openai",
		"base_url": "https://api.siliconflow.cn/v1", "model": "Qwen/Qwen2.5-7B-Instruct", "env": "SILICONFLOW_API_KEY"},
	{"id": "openrouter", "name": "OpenRouter", "type": "openai",
		"base_url": "https://openrouter.ai/api/v1", "model": "openai/gpt-4o-mini", "env": "OPENROUTER_API_KEY"},
	{"id": "ollama", "name": "Ollama（本地）", "type": "openai",
		"base_url": "http://localhost:11434/v1", "model": "qwen2.5:7b", "key_optional": true},
	{"id": "lmstudio", "name": "LM Studio（本地）", "type": "openai",
		"base_url": "http://localhost:1234/v1", "model": "local-model", "key_optional": true},
]

var providers: Array = []          # Array[Dictionary], presets first, then custom ones
var active_id := ""                # "" = offline
var enabled := false
var last_error := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_config()


# ------------------------------------------------------------------ providers
static func blank_provider(id: String) -> Dictionary:
	return {
		"id": id, "name": "自定义接口", "type": "openai", "base_url": "", "api_key": "",
		"model": "", "headers": "", "extra_body": "", "temperature": 0.9,
		"max_tokens_param": "max_tokens", "timeout": 25.0, "key_optional": false,
		"custom": true, "env": "",
	}


static func _from_preset(preset: Dictionary) -> Dictionary:
	var p := blank_provider(str(preset["id"]))
	p["custom"] = false
	for k in preset.keys():
		p[k] = preset[k]
	return p


func get_provider(id: String) -> Dictionary:
	for p in providers:
		if p["id"] == id:
			return p
	return {}


func active() -> Dictionary:
	return get_provider(active_id)


func is_ready(p: Dictionary) -> bool:
	if p.is_empty():
		return false
	if str(p.get("base_url", "")).strip_edges() == "" or str(p.get("model", "")).strip_edges() == "":
		return false
	if str(p.get("api_key", "")).strip_edges() == "" and not bool(p.get("key_optional", false)):
		return false
	return true


func _refresh_enabled() -> void:
	enabled = is_ready(active())


func set_active(id: String) -> void:
	active_id = id if not get_provider(id).is_empty() else ""
	_refresh_enabled()
	save_config()


## Insert or replace a provider (matched by id).
func upsert(p: Dictionary) -> void:
	for i in providers.size():
		if providers[i]["id"] == p["id"]:
			providers[i] = p
			_refresh_enabled()
			return
	providers.append(p)
	_refresh_enabled()


func new_custom() -> Dictionary:
	var n := 1
	while not get_provider("custom%d" % n).is_empty():
		n += 1
	var p := blank_provider("custom%d" % n)
	p["name"] = "自定义接口 %d" % n
	return p


## Deletes a custom provider; resets a preset to its template (key is kept).
func remove_or_reset(id: String) -> void:
	for i in providers.size():
		if providers[i]["id"] != id:
			continue
		if bool(providers[i].get("custom", false)):
			providers.remove_at(i)
			if active_id == id:
				active_id = ""
		else:
			var key: String = str(providers[i].get("api_key", ""))
			for pr in PRESETS:
				if pr["id"] == id:
					providers[i] = _from_preset(pr)
					providers[i]["api_key"] = key
		break
	_refresh_enabled()
	save_config()


# ------------------------------------------------------------------ config io
func load_config() -> void:
	providers = []
	for pr in PRESETS:
		providers.append(_from_preset(pr))
	active_id = ""

	# legacy single-provider file
	var cfg := ConfigFile.new()
	if cfg.load(LEGACY_PATH) == OK:
		var lp := get_provider("anthropic")
		lp["api_key"] = str(cfg.get_value("anthropic", "api_key", ""))
		lp["model"] = str(cfg.get_value("anthropic", "model", lp["model"]))

	# environment variables fill in keys that are not set yet
	for p in providers:
		var env := str(p.get("env", ""))
		if env != "" and str(p.get("api_key", "")) == "":
			p["api_key"] = OS.get_environment(env)
	if str(get_provider("gemini").get("api_key", "")) == "":
		get_provider("gemini")["api_key"] = OS.get_environment("GOOGLE_API_KEY")

	var stored := ""
	if FileAccess.file_exists(CONFIG_PATH):
		var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if f:
			stored = f.get_as_text()
	var data = JSON.parse_string(stored) if stored != "" else null
	var has_stored_active := false
	if data is Dictionary:
		for sp in data.get("providers", []):
			if not sp is Dictionary or not sp.has("id"):
				continue
			var base := get_provider(str(sp["id"]))
			if base.is_empty():
				base = blank_provider(str(sp["id"]))
				base["custom"] = true
				providers.append(base)
			for k in sp.keys():
				# an empty stored key must not hide an environment variable
				if k == "api_key" and str(sp[k]) == "":
					continue
				base[k] = sp[k]
		if data.has("active"):
			active_id = str(data["active"])
			has_stored_active = true
	var forced := OS.get_environment("DREAM_AI_PROVIDER")
	if forced != "" and not get_provider(forced).is_empty():
		active_id = forced
	elif not has_stored_active:
		# first run: use whichever cloud provider already has a key
		for p in providers:
			if str(p.get("api_key", "")).strip_edges() != "" and not bool(p.get("key_optional", false)):
				active_id = str(p["id"])
				break
	if get_provider(active_id).is_empty():
		active_id = ""
	_refresh_enabled()


func save_config() -> void:
	if GS.test_mode:
		return
	var out: Array = []
	for p in providers:
		var q: Dictionary = (p as Dictionary).duplicate()
		out.append(q)
	var f := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": 1, "active": active_id, "providers": out}, "\t"))


func status_text() -> String:
	if enabled:
		var p := active()
		return "AI 叙事：已连接（%s · %s）" % [p["name"], p["model"]]
	return "AI 叙事：离线模式（使用预设文本，可在『设置 → AI 接口设置』里配置）"


## Short label for HUD.
func short_status() -> String:
	return ("AI 叙事：在线 · " + str(active()["name"])) if enabled else "AI 叙事：离线（预设文本）"


# ------------------------------------------------------------------ requests
static func _join_url(base: String, suffix: String) -> String:
	var b := base.strip_edges()
	while b.ends_with("/"):
		b = b.left(b.length() - 1)
	if b.ends_with(suffix):
		return b
	return b + suffix


static func parse_headers(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line in text.split("\n"):
		var l := line.strip_edges()
		if l == "" or l.begins_with("#") or l.find(":") < 1:
			continue
		out.append(l)
	return out


static func _temperature(p: Dictionary) -> float:
	return float(p.get("temperature", -1.0))


## Builds {"url": String, "headers": PackedStringArray, "body": String} for a
## provider's protocol. Pure function (no network) so tests can inspect it.
static func build_request(p: Dictionary, system: String, messages: Array, max_tokens: int) -> Dictionary:
	var type := str(p.get("type", "openai"))
	var key := str(p.get("api_key", "")).strip_edges()
	var model := str(p.get("model", "")).strip_edges()
	var base := str(p.get("base_url", ""))
	var url := ""
	var headers := PackedStringArray(["content-type: application/json"])
	var body := {}
	var temp := _temperature(p)
	match type:
		"anthropic":
			var b := base.strip_edges()
			while b.ends_with("/"):
				b = b.left(b.length() - 1)
			if b.ends_with("/messages"):
				url = b
			elif b.ends_with("/v1"):
				url = b + "/messages"
			else:
				url = b + "/v1/messages"
			if key != "":
				headers.append("x-api-key: " + key)
			headers.append("anthropic-version: 2023-06-01")
			body = {"model": model, "max_tokens": max_tokens, "messages": messages}
			if system != "":
				body["system"] = system
			if temp >= 0.0:
				body["temperature"] = temp
		"gemini":
			var b2 := base.strip_edges()
			while b2.ends_with("/"):
				b2 = b2.left(b2.length() - 1)
			if b2.find(":generateContent") != -1:
				url = b2
			else:
				url = b2 + "/models/" + model.trim_prefix("models/") + ":generateContent"
			if key != "":
				headers.append("x-goog-api-key: " + key)
			var contents: Array = []
			for m in messages:
				contents.append({
					"role": "model" if str(m["role"]) == "assistant" else "user",
					"parts": [{"text": str(m["content"])}],
				})
			var gen := {"maxOutputTokens": max_tokens}
			if temp >= 0.0:
				gen["temperature"] = temp
			body = {"contents": contents, "generationConfig": gen}
			if system != "":
				body["systemInstruction"] = {"parts": [{"text": system}]}
		"openai_responses":
			url = _join_url(base, "/responses")
			if key != "":
				headers.append("Authorization: Bearer " + key)
			body = {"model": model, "input": messages, "max_output_tokens": max_tokens}
			if system != "":
				body["instructions"] = system
			if temp >= 0.0:
				body["temperature"] = temp
		_:
			url = _join_url(base, "/chat/completions")
			if key != "":
				headers.append("Authorization: Bearer " + key)
			var msgs: Array = []
			if system != "":
				msgs.append({"role": "system", "content": system})
			msgs.append_array(messages)
			body = {"model": model, "messages": msgs}
			var tp := str(p.get("max_tokens_param", "max_tokens"))
			body[tp if tp != "" else "max_tokens"] = max_tokens
			if temp >= 0.0:
				body["temperature"] = temp
	# user extras: custom headers and a JSON object merged into the body
	for h in parse_headers(str(p.get("headers", ""))):
		headers.append(h)
	var extra_text := str(p.get("extra_body", "")).strip_edges()
	if extra_text != "":
		var extra = JSON.parse_string(extra_text)
		if extra is Dictionary:
			for k in extra.keys():
				body[k] = extra[k]
	return {"url": url, "headers": headers, "body": JSON.stringify(body)}


static func _clean(t: String) -> String:
	var out := t
	# reasoning models (DeepSeek-R1, Qwen3 local ...) may include <think> blocks
	while true:
		var a := out.find("<think>")
		if a == -1:
			break
		var b := out.find("</think>", a)
		if b == -1:
			out = out.left(a)
			break
		out = out.left(a) + out.substr(b + 8)
	return out.strip_edges()


static func _text_of(v) -> String:
	if v is String:
		return v
	var s := ""
	if v is Array:
		for part in v:
			if part is Dictionary:
				s += str(part.get("text", ""))
			elif part is String:
				s += part
	return s


## Extracts the generated text from a protocol's JSON response ("" on failure).
static func parse_response(p: Dictionary, text: String) -> String:
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		return ""
	var out := ""
	match str(p.get("type", "openai")):
		"anthropic":
			for block in data.get("content", []):
				if block is Dictionary and str(block.get("type", "")) == "text":
					out += str(block.get("text", ""))
		"gemini":
			var cands = data.get("candidates", [])
			if cands is Array and cands.size() > 0 and cands[0] is Dictionary:
				var content = cands[0].get("content", {})
				if content is Dictionary:
					for part in content.get("parts", []):
						if part is Dictionary and not bool(part.get("thought", false)):
							out += str(part.get("text", ""))
		"openai_responses":
			if data.has("output_text") and data["output_text"] is String:
				out = data["output_text"]
			else:
				for item in data.get("output", []):
					if item is Dictionary and str(item.get("type", "")) == "message":
						for c in item.get("content", []):
							if c is Dictionary and str(c.get("type", "")) == "output_text":
								out += str(c.get("text", ""))
		_:
			var choices = data.get("choices", [])
			if choices is Array and choices.size() > 0 and choices[0] is Dictionary:
				var msg = choices[0].get("message", {})
				if msg is Dictionary:
					out = _text_of(msg.get("content", ""))
				if out == "" and choices[0].has("text"):
					out = str(choices[0]["text"])
	return _clean(out)


static func error_message(text: String) -> String:
	var data = JSON.parse_string(text)
	if data is Dictionary:
		var e = data.get("error", null)
		if e is Dictionary:
			return str(e.get("message", e))
		if e != null:
			return str(e)
		if data.has("message"):
			return str(data["message"])
	return text.left(160)


## One request to a specific provider. Returns {"ok": bool, "text": String, "error": String}.
func request(p: Dictionary, system: String, messages: Array, max_tokens := 220) -> Dictionary:
	if not is_ready(p):
		return {"ok": false, "text": "", "error": "未配置完整（需要地址、模型，云端接口还需要 API Key）"}
	var req := build_request(p, system, messages, max_tokens)
	var http := HTTPRequest.new()
	http.timeout = float(p.get("timeout", 25.0))
	add_child(http)
	var err := http.request(str(req["url"]), req["headers"] as PackedStringArray, HTTPClient.METHOD_POST, str(req["body"]))
	if err != OK:
		http.queue_free()
		return {"ok": false, "text": "", "error": "无法发出请求（错误码 %d），请检查接口地址" % err}
	var res: Array = await http.request_completed
	http.queue_free()
	var body_text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "text": "", "error": "网络错误（%d）：连不上 %s 或超时" % [int(res[0]), str(p.get("base_url", ""))]}
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return {"ok": false, "text": "", "error": "HTTP %d：%s" % [int(res[1]), error_message(body_text)]}
	var out := parse_response(p, body_text)
	if out == "":
		return {"ok": false, "text": "", "error": "接口返回了空内容，可能是协议类型选错了"}
	return {"ok": true, "text": out, "error": ""}


## Returns generated text from the active provider, or "" on failure /
## offline (the caller then uses its authored fallback).
func complete(system: String, messages: Array, max_tokens := 220) -> String:
	if not enabled:
		return ""
	var r: Dictionary = await request(active(), system, messages, max_tokens)
	if not r["ok"]:
		last_error = str(r["error"])
		push_warning("AI request failed: " + last_error)
		return ""
	last_error = ""
	return str(r["text"])


# ------------------------------------------------------------------ prompts
func state_brief() -> String:
	var frs: Array = []
	for id in GS.fragments.keys():
		if GS.FRAGMENTS.has(id):
			frs.append(GS.FRAGMENTS[id]["name"])
	return "当前：%s，第%d次潜入（%s）。梦境编辑器状态：%s。稳定度%d。玩家累计：修复%d次、守护%d次、增强%d次。已收集碎片：%s。小眠性格：%s。" % [
		GS.case_name(), GS.dive(), GS.stage_name(), GS.editor_summary(), int(GS.stability),
		GS.scores["repair"], GS.scores["protect"], GS.scores["enhance"],
		"、".join(frs) if frs.size() > 0 else "无", GS.trait_name()]


## The dream persona of the current case answering a free-form question.
func ask_persona(question: String, history: Array) -> String:
	var c: Dictionary = GS.case_data()
	var system: String = str(c["brief"]) + "\n\n" + str(c["persona_prompt"]) + "\n" + state_brief()
	var msgs: Array = history.duplicate()
	msgs.append({"role": "user", "content": question})
	return await complete(system, msgs, 200)


func ask_tangxin(question: String, history: Array) -> String:
	return await ask_persona(question, history)


## Xiaomian's live dream analysis.
func analyze(hint: String) -> String:
	var c: Dictionary = GS.case_data()
	var system: String = str(c["brief"]) + "\n\n你扮演『小眠』：修复师的AI助手小机器人，性格会随玩家行为改变。当前性格：" + GS.trait_name() + "（懵懂=天真好奇的新手；温柔=体贴，希望保护梦；怀疑=开始质疑『修复就是抹除』；好奇=想看看梦会进化成什么）。请用简体中文，给出一段不超过80字的『梦境分析』，自然地包含下面这条游戏提示，不要剧透隐藏真相。\n" + state_brief()
	return await complete(system, [{"role": "user", "content": "游戏提示：" + hint + "\n请分析当前梦境。"}], 200)
