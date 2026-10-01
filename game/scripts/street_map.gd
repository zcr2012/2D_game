extends RefCounted
## StreetMap — the world of Dream 2 (梧桐巷 / Old Street): geometry, props,
## the fracture + light bridge, the echo fog and the wandering "forgotten ones".
## Story content lives in story_street.gd; dream.gd owns the scene.
##
## Layout (world 1760 x 700, y grows downwards):
##   y   0..300  building frontage (north)      alley x 1330..1480 goes north
##   y 300..370  north pavement
##   y 370..500  road (centre line y = 435)
##   y 500..560  south pavement, trees; y > 590 is a hedge (walled off)
##   x 1040..1120 is the "fracture" in the fading street (needs the light bridge)

const Shadow := preload("res://scripts/shadow.gd")

const WORLD := Vector2(1760, 700)
const SPAWN := Vector2(110, 440)
const FRACTURE := Rect2(1040, 300, 80, 290)
const FOG_X := 1680.0
const ALLEY := Rect2(1330, 90, 150, 210)
const SHADOW_HOMES := [Vector2(60, 330), Vector2(1700, 560), Vector2(700, 565)]

var d                              # the dream scene
var loop_open := false             # echo stage: the east fog has lifted
var laps := 0                      # echo stage: how often the fog sent us back
var fog: Sprite2D = null
var sign_label: Label = null
var shop_shutter: Node2D = null    # fading stage only
var alley_gate: Node2D = null      # fading stage only
var signpost: Node2D = null
var shop_spot: Node2D = null       # where the repair shop can be entered
var studio_spot: Node2D = null     # where the photo studio can be entered
var lamp_node: Node2D = null       # the sentient street lamp (老灯)

var _fracture_col: CollisionShape2D = null
var _bridge_open := false
var _fracture_closed := true
var _wrapping := false


func _init(dream) -> void:
	d = dream


# ================================================================== build
func build() -> void:
	d.world_size = WORLD
	d.spawn = SPAWN
	var stage: String = GS.stage()

	# --- invisible walls: north frontage, alley, south hedge
	_wall(Rect2(0, 285, 1330, 30))
	_wall(Rect2(1480, 285, 280, 30))
	_wall(Rect2(1310, 80, 20, 220))
	_wall(Rect2(1480, 80, 20, 220))
	_wall(Rect2(1310, 70, 190, 20))
	_wall(Rect2(0, 590, WORLD.x, 30))

	# --- buildings on the north side (drawn only; the wall above blocks them)
	for b in [["st_flat", 170], ["st_noodle", 500], ["st_repair", 830], ["st_flat", 1170], ["st_flat", 1640]]:
		var n: Node2D = d.add_prop(str(b[0]), Vector2(float(b[1]), 300.0))
		d.wobblers.append(n)
		if b[0] == "st_noodle":
			d.add_label(n, "福记面馆", Vector2(0, -128), Color(1.0, 0.9, 0.7))
		elif b[0] == "st_repair":
			d.add_label(n, "老沈修理", Vector2(0, -108), Color(0.8, 0.95, 1.0))
	var studio: Node2D = d.add_prop("st_studio", Vector2(1405, 225), Vector2(140, 26), null, 0.8)
	d.wobblers.append(studio)
	d.add_label(studio, "晚照相馆", Vector2(0, -130), Color(1.0, 0.85, 0.9))
	studio.visible = stage != "summer" or GS.has_frag("st_photo")
	d.nodes["studio"] = studio

	# --- plane trees on the south edge of the road
	for x in [260, 640, 960, 1230]:
		d.add_prop("st_tree", Vector2(float(x), 545.0), Vector2(18, 10))

	# --- street lamps (they glow at night)
	for x in [320, 640, 960, 1220, 1560]:
		var lp: Node2D = d.add_prop("st_lamp", Vector2(float(x), 372.0), Vector2(8, 6))
		d.lamps.append(lp)

	# --- street sign (rewrites itself in madness)
	signpost = d.add_prop("st_signpost", Vector2(215, 365), Vector2(10, 6))
	sign_label = d.add_label(signpost, "梧桐巷", Vector2(0, -72), Color(0.9, 1.0, 0.9))
	d.nodes["signpost"] = signpost

	# --- the bus stop and bench at the east end
	var bench: Node2D = d.add_prop("st_bench", Vector2(1610, 548), Vector2(70, 14))
	d.nodes["bench"] = bench

	# --- decorative puddles (only when it rains)
	for p in [Vector2(420, 460), Vector2(760, 400), Vector2(1330, 470), Vector2(1500, 410)]:
		var pd: Node2D = d.add_prop("st_puddle", p)
		pd.z_index = -7
		d.sad_only.append(pd)

	# --- the repair shop's night window
	var win: Node2D = d.add_prop("st_window", Vector2(852, 268))
	win.visible = false
	d.night_only.append(win)
	d.lamps.append(win)
	d.nodes["window"] = win

	# --- spots where doors can be entered once they are open
	shop_spot = Node2D.new()
	shop_spot.position = Vector2(830, 330)
	d.world.add_child(shop_spot)
	studio_spot = Node2D.new()
	studio_spot.position = Vector2(1405, 250)
	d.world.add_child(studio_spot)

	match stage:
		"fading":
			_build_fracture()
			_build_shutters()
		"echo":
			_build_fog()

	# hint trigger in front of the fracture
	if stage == "fading":
		var a := Area2D.new()
		a.position = Vector2(1000, 445)
		var c := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(40, 290)
		c.shape = rs
		a.add_child(c)
		a.body_entered.connect(_on_fracture_near)
		d.add_child(a)


func _wall(r: Rect2) -> void:
	var b := StaticBody2D.new()
	var c := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	c.shape = rs
	c.position = r.position + r.size / 2.0
	b.add_child(c)
	d.add_child(b)


func _build_fracture() -> void:
	var b := StaticBody2D.new()
	_fracture_col = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = FRACTURE.size
	_fracture_col.shape = rs
	_fracture_col.position = FRACTURE.position + FRACTURE.size / 2.0
	b.add_child(_fracture_col)
	d.add_child(b)
	# fantasy: street lamps float up and a path of light crosses the gap
	for i in 6:
		var t: Node2D = d.add_prop("st_lightpath", Vector2(1048.0 + i * 13.0, 440.0 + sin(i * 1.3) * 6.0))
		t.z_index = -6
		t.visible = false
		d.fantasy_only.append(t)
	for p in [Vector2(1040, 405), Vector2(1080, 480), Vector2(1120, 405)]:
		var fl: Node2D = d.add_prop("st_lamp", p)
		fl.visible = false
		fl.modulate = Color(1, 1, 1, 0.8)
		var s: Sprite2D = d.sprite_of(fl)
		s.position.y = -26
		var tw := s.create_tween().set_loops()
		tw.tween_property(s, "position:y", -34.0, 1.1).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "position:y", -26.0, 1.1).set_trans(Tween.TRANS_SINE)
		d.fantasy_only.append(fl)
		d.lamps.append(fl)


func _build_shutters() -> void:
	# rusty roller shutter in front of the repair shop
	shop_shutter = d.add_prop("st_shutter", Vector2(830, 322), Vector2(46, 14))
	shop_shutter.set_meta("key", "shop")
	d.add_interact(shop_shutter, "生锈的卷帘门", d.story.break_wall.bind(shop_shutter), 44.0, Callable(), Vector2(0, 12))
	d.nodes["shop_shutter"] = shop_shutter
	# three of them close off the alley
	alley_gate = Node2D.new()
	alley_gate.position = Vector2(1405, 306)
	alley_gate.set_meta("key", "gate")
	d.world.add_child(alley_gate)
	for i in 3:
		d.add_prop("st_shutter", Vector2(-50.0 + i * 50.0, 0.0), Vector2(52, 16), alley_gate, 1.15)
	d.add_interact(alley_gate, "锈死的铁闸", d.story.break_wall.bind(alley_gate), 70.0, Callable(), Vector2(0, 16))
	d.nodes["alley_gate"] = alley_gate


func _build_fog() -> void:
	fog = Sprite2D.new()
	fog.texture = d.tex("st_fog")
	fog.centered = false
	fog.position = Vector2(FOG_X - 40.0, 0)
	fog.scale = Vector2(1.0, WORLD.y / float(fog.texture.get_height()))
	fog.z_index = 20
	d.add_child(fog)
	var tw := fog.create_tween().set_loops()
	tw.tween_property(fog, "modulate:a", 0.8, 2.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(fog, "modulate:a", 1.0, 2.0).set_trans(Tween.TRANS_SINE)


# ================================================================== runtime
func _on_fracture_near(b: Node) -> void:
	if b == d.player and not _bridge_open and not GS.flag("fracture_seen"):
		GS.set_flag("fracture_seen", false)
		d.run_event(d.story.ev_fracture)


func shutter_broken(w: Node2D) -> void:
	d.break_wall(w)
	if w == shop_shutter:
		shop_shutter = null
	elif w == alley_gate:
		alley_gate = null


func open_loop() -> void:
	loop_open = true
	if fog:
		var t := fog.create_tween()
		t.tween_property(fog, "modulate:a", 0.0, 1.5)
		t.tween_callback(fog.hide)


func apply_fx() -> void:
	var r: int = GS.reality
	_bridge_open = r >= 1
	_refresh_fracture()
	if sign_label != null:
		var txt: String = "苏晚巷" if r >= 2 else "梧桐巷"
		if sign_label.text != txt:
			sign_label.text = txt
			sign_label.reset_size()
			sign_label.position.x = -sign_label.size.x / 2.0
	if fog != null and not loop_open:
		fog.visible = true


func _refresh_fracture() -> void:
	if _fracture_col == null:
		return
	var inside: bool = d.player != null and d.player.position.x > FRACTURE.position.x - 14.0 \
		and d.player.position.x < FRACTURE.end.x + 14.0
	var closed: bool = not _bridge_open and not inside
	if closed != _fracture_closed:
		_fracture_closed = closed
		_fracture_col.set_deferred("disabled", not closed)
	elif _fracture_col.disabled != (not closed):
		_fracture_col.set_deferred("disabled", not closed)


func process(_delta: float) -> void:
	_refresh_fracture()
	# echo stage: the east edge of the street leads back to the west edge
	if GS.stage() == "echo" and not loop_open and not _wrapping \
			and d.player.position.x > FOG_X and d.can_player_act():
		_wrap()


func _wrap() -> void:
	_wrapping = true
	laps += 1
	d.flash(Color(0.8, 0.9, 1.0), 0.7)
	Audio.sfx("glitch")
	var y: float = d.player.position.y
	d.player.position = Vector2(80, y)
	d.xm.position = Vector2(50, y)
	d.camera.reset_smoothing()
	GS.emit_signal("toast", "街道把你送回了起点……（第 %d 圈）" % laps)
	d.run_event(d.story.ev_lap)
	await d.get_tree().create_timer(0.8).timeout
	_wrapping = false


## The forgotten ones: they drift towards the player when the dream turns bad.
func sync_shadows() -> void:
	var r: int = GS.reality
	var want := 0
	if GS.stage() == "summer":
		want = 2 if r == 3 else 0
	else:
		want = 3 if r == 3 else (1 if r == 2 else 0)
	var spd: float = 46.0 + 8.0 * r
	while d.shadows.size() > want:
		var old = d.shadows.pop_back()
		old.queue_free()
	while d.shadows.size() < want:
		var s = Shadow.new()
		s.skin = "faceless"
		s.dream = d
		s.player = d.player
		s.position = SHADOW_HOMES[d.shadows.size() % SHADOW_HOMES.size()]
		d.world.add_child(s)
		d.shadows.append(s)
	for s in d.shadows:
		s.speed = spd
