extends Node
## Plat — everything that differs between phones (Android / iOS) and
## desktops (Windows / Linux):
##
##  * device + last-used input device ("kbd" | "touch" | "pad"), so on-screen
##    controls and button hints ("按 E" vs "点『互动』") always match what the
##    player is actually holding
##  * persistent settings (user://settings.cfg): fullscreen, touch UI, voice,
##    music volume
##  * desktop: F11 / Alt+Enter fullscreen
##  * mobile: safe area (notches / rounded corners), Android back button,
##    auto-pause when the app goes to the background
##
## Force a mode for testing with user args:  godot -- --touch   /  -- --no-touch

signal input_mode_changed(mode: String)
signal app_paused

const SETTINGS_PATH := "user://settings.cfg"

var is_mobile := false
var is_ios := false
var device := "kbd"            # last input device: kbd | touch | pad
var touch_pref := "auto"       # on-screen controls: auto | on | off
var fullscreen := false

const LABELS := {
	"kbd": {"move": "WASD", "interact": "E", "editor": "Tab", "ask_xm": "Q", "fragments": "I", "pause": "Esc"},
	"pad": {"move": "左摇杆", "interact": "A", "editor": "Y", "ask_xm": "X", "fragments": "Back", "pause": "Start"},
	"touch": {"move": "左侧摇杆", "interact": "『互动』", "editor": "『编辑』", "ask_xm": "『小眠』", "fragments": "『碎片』", "pause": "『菜单』"},
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_ios = OS.has_feature("ios") or OS.has_feature("web_ios")
	is_mobile = OS.has_feature("mobile") or is_ios or OS.has_feature("web_android")
	device = "touch" if is_mobile else "kbd"
	load_settings()
	for a in OS.get_cmdline_user_args():
		if a == "--touch":
			touch_pref = "on"
		elif a == "--no-touch":
			touch_pref = "off"
	if not is_mobile and fullscreen:
		_apply_fullscreen()
	# raw window input arrives before any node can consume the event
	get_tree().root.window_input.connect(_track_device)


# ------------------------------------------------------------------ queries
## Should the on-screen joystick / buttons be shown?
func touch_ui() -> bool:
	match touch_pref:
		"on": return true
		"off": return false
	return device == "touch"


## Human-readable control name for the current input device.
func k(action: String) -> String:
	var mode := "touch" if touch_ui() else ("pad" if device == "pad" else "kbd")
	return LABELS[mode].get(action, action)


## "按 Tab" / "点『编辑』" / "按 Y" — for dialogue hints.
func press(action: String) -> String:
	return ("点" if touch_ui() else "按 ") + k(action)


## Xiaomian's first control tip, per input device.
func controls_intro() -> String:
	if touch_ui():
		return "操作提示：在屏幕左侧拖动来移动，靠近东西时点右下角的『互动』。有不懂的，随时点『小眠』问我。"
	if device == "pad":
		return "操作提示：左摇杆移动，A 互动。有不懂的，随时按 X 问我。"
	return "操作提示：WASD 移动，E 互动。有不懂的，随时按 Q 问我。"


## One-line control summary for HUD footers.
func controls_hint() -> String:
	if touch_ui():
		return "左侧拖动移动 · 右侧按钮：互动 / 编辑器 / 问小眠 / 碎片"
	if device == "pad":
		return "左摇杆 移动   A 互动   Y 梦境编辑器   X 问小眠   Back 碎片   Start 菜单"
	return "WASD 移动   E 互动   Tab 梦境编辑器   Q 问小眠   I 碎片   Esc 菜单"


## Safe area (notch / rounded corners / home indicator) as margins in
## canvas (stretched viewport) pixels: Rect2(left, top, right, bottom).
func safe_margins(vp: Viewport = null) -> Rect2:
	if vp == null:
		vp = get_viewport()
	if not is_mobile or DisplayServer.get_name() == "headless":
		return Rect2()
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
		return Rect2()
	var vis := vp.get_visible_rect().size
	var sx := vis.x / float(win.x)
	var sy := vis.y / float(win.y)
	var l := maxf(0.0, safe.position.x) * sx
	var t := maxf(0.0, safe.position.y) * sy
	var r := maxf(0.0, win.x - safe.end.x) * sx
	var b := maxf(0.0, win.y - safe.end.y) * sy
	return Rect2(l, t, r, b)


## Converts physical window pixels (e.g. the virtual keyboard height) to canvas pixels.
func window_to_canvas(px: float) -> float:
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return px
	return px * get_viewport().get_visible_rect().size.y / float(win.y)


# ------------------------------------------------------------------ input device tracking
func _input(event: InputEvent) -> void:
	_track_device(event)
	var ke := event as InputEventKey
	if ke and ke.pressed and not ke.echo and not is_mobile:
		if ke.keycode == KEY_F11 or (ke.keycode == KEY_ENTER and ke.alt_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


func _track_device(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_device("touch")
	elif event is InputEventKey:
		if (event as InputEventKey).pressed:
			_set_device("kbd")
	elif event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			_set_device("pad")
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.5:
			_set_device("pad")
	elif event is InputEventMouseButton and not is_mobile:
		# a real mouse on desktop (touch-emulated clicks carry device -1)
		if event.device >= 0 and device == "touch" and touch_pref == "auto":
			_set_device("kbd")


func _set_device(d: String) -> void:
	if d == device:
		return
	device = d
	input_mode_changed.emit(d)


# ------------------------------------------------------------------ app lifecycle
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if is_mobile:
				app_paused.emit()
				if not GS.test_mode:
					save_settings()


## Android back button: acts like Esc (pause / close panel); quits from the title.
func _on_back() -> void:
	var cs := get_tree().current_scene
	if cs and cs.scene_file_path.ends_with("title.tscn"):
		get_tree().quit()
		return
	press_action("pause")


## Emits a full press+release of an input action (used by touch buttons & back key).
func press_action(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.call_deferred("parse_input_event", up)


# ------------------------------------------------------------------ settings
func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	_apply_fullscreen()
	save_settings()


func set_fullscreen(on: bool) -> void:
	if on != fullscreen:
		toggle_fullscreen()


func _apply_fullscreen() -> void:
	if is_mobile or DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func set_touch_pref(p: String) -> void:
	touch_pref = p
	input_mode_changed.emit(device)
	save_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	touch_pref = str(cfg.get_value("input", "touch_ui", touch_pref))
	GS.settings["voice"] = bool(cfg.get_value("audio", "voice", GS.settings["voice"]))
	GS.settings["music_volume"] = float(cfg.get_value("audio", "music_volume", GS.settings["music_volume"]))
	GS.settings["unlock_all"] = bool(cfg.get_value("game", "unlock_all", GS.settings["unlock_all"]))


func save_settings() -> void:
	if GS.test_mode:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("input", "touch_ui", touch_pref)
	cfg.set_value("audio", "voice", GS.settings["voice"])
	cfg.set_value("audio", "music_volume", GS.settings["music_volume"])
	cfg.set_value("game", "unlock_all", GS.settings["unlock_all"])
	cfg.save(SETTINGS_PATH)
