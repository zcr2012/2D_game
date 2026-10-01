extends Node
## Save/load regression test. Uses a dedicated user:// file and removes it afterward.

var failures := 0
var checks := 0


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("  ✔ ", description)
	else:
		failures += 1
		print("  ✘ FAIL: ", description)


func _ready() -> void:
	GS.test_mode = false
	GS.save_path = "user://dream_repair_save_regression.json"
	GS.delete_save()
	GS.new_game()
	GS.begin_dive()
	check(GS.time == "day", "Candy City opens in its endless afternoon")
	GS.start_case("street")
	GS.begin_dive()
	check(GS.time == "night", "Old Street opens under its summer night lights")

	GS.new_game()
	GS.start_case("street")
	GS.visit = 2
	GS.core_choices = ["repair", "protect"]
	GS.ending = "guardian"
	GS.fragments = {"st_photo": true, "st_sad": true}
	GS.flags = {"briefed_street": true}
	GS.scores = {"repair": 3, "protect": 2, "enhance": 1}
	GS.xm = {"warmth": 2, "doubt": 1, "curiosity": 4}
	GS.dream_log = [{"case": "street", "dive": 2, "text": "save regression"}]
	GS.residue = {"time": "night", "emotion": "sad", "reality": 2}
	GS.last_collapse = true
	GS.save_game()
	check(GS.has_save(), "writes a save file")

	GS.new_game()
	check(GS.load_game(), "loads the saved game")
	check(GS.case_id == "street" and GS.visit == 2, "restores case and dive progress")
	check(GS.core_choices == ["repair", "protect"] and GS.ending == "guardian", "restores choices and ending")
	check(GS.has_frag("st_photo") and GS.flag("briefed_street"), "restores fragments and story flags")
	check(GS.scores == {"repair": 3, "protect": 2, "enhance": 1}, "restores scores")
	check(GS.xm == {"warmth": 2, "doubt": 1, "curiosity": 4}, "restores Xiaomian's traits")
	check(GS.residue == {"time": "night", "emotion": "sad", "reality": 2}, "restores the dream residue")
	check(GS.last_collapse, "restores collapse state")

	GS.visit = GS.MAX_DIVES
	GS.core_choices = ["repair", "protect", "enhance"]
	GS.ending = "creator"
	GS.save_game()
	GS.new_game()
	check(GS.load_game(), "loads a completed case")
	check(GS.visit == GS.MAX_DIVES and GS.ending == "creator", "preserves the completed ending for Continue")
	GS.test_mode = true
	var ending_screen = preload("res://scripts/ending.gd").new()
	ending_screen._to_title()
	check(GS.last_goto == "title" and GS.has_save(), "keeps the completed save when returning to title")
	var title_screen = preload("res://scripts/title.gd").new()
	title_screen._continue()
	check(GS.last_goto == "ending", "Continue opens the saved ending after a completed case")
	GS.visit = 2
	title_screen._continue()
	check(GS.last_goto == "clinic", "Continue opens the clinic at the saved next dive")
	GS.test_mode = false

	GS.new_game()
	GS.start_case("station")
	GS.visit = 2
	GS.fragments = {"sp_photo": true, "sp_chart": true}
	GS.flags = {"briefed_station": true, "sp_blueprint": "library"}
	GS.save_game()
	GS.new_game()
	check(GS.load_game() and GS.case_id == "station" and GS.stage() == "genesis", "restores a Space Station save at its third dive")
	check(GS.has_frag("sp_chart") and GS.flags.get("sp_blueprint", "") == "library", "restores station fragments and the chosen blueprint")

	var broken := FileAccess.open(GS.save_path, FileAccess.WRITE)
	broken.store_string("{\"version\": 2, \"progress\": \"not an object\"}")
	broken.close()
	var saved_case := GS.case_id
	var saved_visit := GS.visit
	check(not GS.load_game(), "rejects malformed save data")
	check(GS.has_save() and GS.case_id == saved_case and GS.visit == saved_visit, "keeps the unreadable file and current progress intact")

	var legacy := FileAccess.open(GS.save_path, FileAccess.WRITE)
	legacy.store_string("{\"visit\": 2, \"core_choices\": [\"repair\", \"protect\"], \"ending\": \"guardian\"}")
	legacy.close()
	GS.new_game()
	check(GS.load_game(), "loads a legacy Candy City save")
	check(GS.case_id == "candy" and GS.visit == 2 and GS.ending == "guardian", "migrates legacy progress into the current save model")

	GS.delete_save()
	GS.save_path = GS.SAVE_PATH
	GS.test_mode = true
	print("\n==== SAVE TEST: %d checks, %d failures ====" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
