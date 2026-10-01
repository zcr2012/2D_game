extends Node
## Headless test for the multi-protocol AI layer and the dream (case) system.
##
##   godot --headless --path game res://tests/ai_test.tscn
##
## No network access: it only checks the pure request builder / response
## parser of every protocol, custom provider handling, the settings panel and
## the case-unlock rules.

var checks := 0
var failures := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		print("  ✔ ", what)
	else:
		failures += 1
		print("  ✘ FAIL: ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	GS.test_mode = true
	await run()
	print("\n==== AI TEST: %d checks, %d failures ====" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _header(h: PackedStringArray, name: String) -> String:
	for line in h:
		if line.to_lower().begins_with(name.to_lower() + ":"):
			return line.substr(name.length() + 1).strip_edges()
	return ""


func run() -> void:
	var msgs := [{"role": "user", "content": "你好"}]

	print("==== presets ====")
	var types := {}
	for pr in AI.PRESETS:
		types[pr["type"]] = true
	check(AI.PRESETS.size() >= 8, "%d vendor presets" % AI.PRESETS.size())
	check(types.has("openai") and types.has("anthropic") and types.has("gemini"), "presets cover OpenAI / Anthropic / Gemini protocols")

	print("\n==== request builders ====")
	var p := AI.blank_provider("t")
	p["api_key"] = "sk-test"
	p["model"] = "m1"
	p["base_url"] = "https://example.com/v1/"
	var r := AI.build_request(p, "SYS", msgs, 100)
	var body: Dictionary = JSON.parse_string(r["body"])
	check(r["url"] == "https://example.com/v1/chat/completions", "openai url: %s" % r["url"])
	check(_header(r["headers"], "authorization") == "Bearer sk-test", "openai bearer header")
	check(body["messages"][0]["role"] == "system" and body["messages"][1]["content"] == "你好", "openai system + messages")
	check(int(body["max_tokens"]) == 100, "openai max_tokens")
	p["max_tokens_param"] = "max_completion_tokens"
	body = JSON.parse_string(AI.build_request(p, "SYS", msgs, 100)["body"])
	check(body.has("max_completion_tokens") and not body.has("max_tokens"), "configurable token parameter name")
	p["base_url"] = "https://example.com/v1/chat/completions"
	check(AI.build_request(p, "", msgs, 10)["url"] == "https://example.com/v1/chat/completions", "full endpoint url is not doubled")

	p["type"] = "anthropic"
	p["base_url"] = "https://api.anthropic.com"
	r = AI.build_request(p, "SYS", msgs, 100)
	body = JSON.parse_string(r["body"])
	check(r["url"] == "https://api.anthropic.com/v1/messages", "anthropic url: %s" % r["url"])
	check(_header(r["headers"], "x-api-key") == "sk-test" and _header(r["headers"], "anthropic-version") != "", "anthropic headers")
	check(body["system"] == "SYS" and body["messages"].size() == 1, "anthropic system is a top-level field")

	p["type"] = "gemini"
	p["base_url"] = "https://generativelanguage.googleapis.com/v1beta"
	p["model"] = "gemini-x"
	r = AI.build_request(p, "SYS", [{"role": "user", "content": "a"}, {"role": "assistant", "content": "b"}], 100)
	body = JSON.parse_string(r["body"])
	check(r["url"].ends_with("/models/gemini-x:generateContent"), "gemini url: %s" % r["url"])
	check(_header(r["headers"], "x-goog-api-key") == "sk-test", "gemini key header")
	check(body["contents"][1]["role"] == "model" and body["systemInstruction"]["parts"][0]["text"] == "SYS", "gemini roles + system instruction")

	p["type"] = "openai_responses"
	p["base_url"] = "https://api.openai.com/v1"
	r = AI.build_request(p, "SYS", msgs, 100)
	body = JSON.parse_string(r["body"])
	check(r["url"] == "https://api.openai.com/v1/responses", "responses url")
	check(body["instructions"] == "SYS" and int(body["max_output_tokens"]) == 100, "responses body")

	print("\n==== custom headers / extra body ====")
	p["type"] = "openai"
	p["headers"] = "X-Org: abc\n# comment\nbad line\nX-Two: 2"
	p["extra_body"] = "{\"top_p\": 0.8, \"enable_thinking\": false}"
	r = AI.build_request(p, "", msgs, 50)
	body = JSON.parse_string(r["body"])
	check(_header(r["headers"], "x-org") == "abc" and _header(r["headers"], "x-two") == "2", "custom headers parsed")
	check(r["headers"].size() == 4, "invalid header lines are dropped (%d headers)" % r["headers"].size())
	check(float(body["top_p"]) == 0.8 and body["enable_thinking"] == false, "extra JSON merged into the body")

	print("\n==== response parsers ====")
	p["type"] = "openai"
	check(AI.parse_response(p, JSON.stringify({"choices": [{"message": {"content": "  好的  "}}]})) == "好的", "openai response")
	check(AI.parse_response(p, JSON.stringify({"choices": [{"message": {"content": "<think>x</think>答案"}}]})) == "答案", "think blocks stripped")
	p["type"] = "anthropic"
	check(AI.parse_response(p, JSON.stringify({"content": [{"type": "text", "text": "甲"}, {"type": "text", "text": "乙"}]})) == "甲乙", "anthropic response")
	p["type"] = "gemini"
	check(AI.parse_response(p, JSON.stringify({"candidates": [{"content": {"parts": [{"text": "丙"}]}}]})) == "丙", "gemini response")
	p["type"] = "openai_responses"
	check(AI.parse_response(p, JSON.stringify({"output": [{"type": "message", "content": [{"type": "output_text", "text": "丁"}]}]})) == "丁", "responses response")
	check(AI.parse_response(p, "not json") == "", "garbage gives empty text")
	check(AI.error_message(JSON.stringify({"error": {"message": "bad key"}})) == "bad key", "error message extracted")

	print("\n==== provider management ====")
	var cp := AI.new_custom()
	check(cp["custom"] == true and cp["id"].begins_with("custom"), "new custom provider %s" % cp["id"])
	check(not AI.is_ready(cp), "empty custom provider is not ready")
	cp["base_url"] = "http://localhost:8000/v1"
	cp["model"] = "local"
	check(not AI.is_ready(cp), "key required unless marked optional")
	cp["key_optional"] = true
	check(AI.is_ready(cp), "local provider without key is ready")
	var n: int = AI.providers.size()
	AI.upsert(cp)
	check(AI.providers.size() == n + 1 and not AI.get_provider(cp["id"]).is_empty(), "custom provider added")
	cp["model"] = "local2"
	AI.upsert(cp)
	check(AI.providers.size() == n + 1 and AI.get_provider(cp["id"])["model"] == "local2", "upsert replaces by id")
	AI.providers.erase(AI.get_provider(cp["id"]))

	print("\n==== settings panel ====")
	var panel: Node = load("res://scripts/ai_panel.gd").new()
	add_child(panel)
	await frames(5)
	check(panel.is_inside_tree(), "provider panel opens")
	panel.queue_free()
	await frames(2)

	print("\n==== dream (case) system ====")
	GS.settings["unlock_all"] = false
	GS.new_game()
	check(GS.case_id == "candy" and GS.case_unlocked("candy"), "candy is available from the start")
	check(not GS.case_unlocked("street"), "street is locked before candy is finished")
	check(not GS.case_unlocked("station"), "station is locked before Old Street is finished")
	GS.settings["unlock_all"] = true
	check(GS.case_unlocked("street") and GS.case_unlocked("station"), "unlock_all opens all three dreams")
	GS.settings["unlock_all"] = false
	GS.progress["candy"] = {"visit": 3, "core": [], "scores": {}, "ending": "guardian"}
	check(GS.case_unlocked("street"), "street unlocks once candy is done")
	check(GS.next_case_id() == "street", "next case after candy is street")
	check(not GS.case_unlocked("station"), "station still needs Old Street")
	GS.progress["street"] = {"visit": 3, "core": [], "scores": {}, "ending": "creator"}
	check(GS.case_unlocked("station") and GS.next_case_id() == "station", "station unlocks once Old Street is done")
	check(GS.case_data("station")["persona"] == "xy" and (GS.case_data("station")["stages"] as Array).size() == 3, "station case data is complete")
	GS.progress.erase("street")
	GS.start_case("street")
	check(GS.stage() == "summer" and GS.case_name() == "梧桐巷" and GS.visit == 0, "street case starts fresh")
	GS.fragments["st_joy"] = true
	check(GS.frag_count("street") == 1 and GS.frag_count("candy") == 0, "fragments are counted per dream")
	GS.new_game()
