extends Node
## Dream scene — builds the Candy City map for the current dive
## (sweet -> melting -> maze), applies Dream Editor effects, handles
## interaction, shadows, stability collapse and waking up.
## Narrative content lives in story.gd.

const Player := preload("res://scripts/player.gd")
const Follower := preload("res://scripts/follower.gd")
const Interactable := preload("res://scripts/interactable.gd")
const Shadow := preload("res://scripts/shadow.gd")
const Story := preload("res://scripts/story.gd")
const Hud := preload("res://scripts/hud.gd")
const TouchControls := preload("res://scripts/touch_controls.gd")

## Soft ellipse shadow under characters.
class Dot extends Node2D:
	var r := 10.0
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, r, Color(0.1, 0.0, 0.2, 0.25))


const CELL := 48.0
const MW := 25
const MH := 19

var world_size := Vector2(1600, 1200)
var spawn := Vector2(800, 1110)
var world: Node2D
var ground: Sprite2D
var cracks: Sprite2D
var player
var xm
var camera: Camera2D
var touch = null            # on-screen controls (phones / touch screens)
var hud
var story
var post_mat: ShaderMaterial
var rain: CPUParticles2D
var sparkles: CPUParticles2D
var fader: ColorRect

var busy := 0
var nodes := {}
var night_only: Array = []
var fantasy_only: Array = []
var madness_only: Array = []
var sad_only: Array = []
var lamps: Array = []
var syrup_blobs: Array = []
var breakables: Array = []
var wobblers: Array = []
var shadows: Array = []
var astar: AStarGrid2D = null
var maze: Array = []
var maze_path: Array = []

var _shake := 0.0
var _anger_t := 2.0
var _caught_cd := 0.0
var _ended := false
var _t := 0.0


# ================================================================== setup
func _ready() -> void:
	GS.begin_dive()
	story = Story.new(self)

	ground = Sprite2D.new()
	ground.texture = load("res://assets/sprites/ground.png")
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	ground.centered = false
	ground.z_index = -10
	add_child(ground)
	cracks = Sprite2D.new()
	cracks.texture = load("res://assets/sprites/cracks.png")
	cracks.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	cracks.region_enabled = true
	cracks.centered = false
	cracks.z_index = -9
	cracks.modulate = Color(1, 1, 1, 0)
	add_child(cracks)

	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	match GS.stage():
		"sweet": _build_town(false)
		"melting": _build_town(true)
		_: _build_maze()

	if GS.stage() == "maze":
		ground.region_rect = Rect2(Vector2.ZERO, world_size)
		ground.modulate = Color(0.86, 0.8, 0.95)
	else:
		# pre-baked town ground with roads matching this layout
		ground.texture = tex("town_ground_melted" if GS.stage() == "melting" else "town_ground")
		ground.region_enabled = false
	cracks.region_rect = Rect2(Vector2.ZERO, world_size)
	_build_bounds()

	player = Player.new()
	player.dream = self
	player.position = spawn
	world.add_child(player)
	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world_size.x)
	camera.limit_bottom = int(world_size.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.offset = Vector2(0, -20)
	player.add_child(camera)

	xm = Follower.new()
	xm.target = player
	xm.position = spawn + Vector2(-20, 0)
	world.add_child(xm)

	story.populate()
	_build_fx()

	hud = Hud.new()
	hud.dream = self
	add_child(hud)
	touch = TouchControls.new()
	touch.dream = self
	add_child(touch)
	Plat.app_paused.connect(_on_app_paused)

	var fl := CanvasLayer.new()
	fl.layer = 40
	add_child(fl)
	fader = ColorRect.new()
	fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	fader.color = Color(1, 1, 1, 1)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(fader)
	create_tween().tween_property(fader, "color:a", 0.0, 1.2)

	GS.editor_changed.connect(_on_editor_changed)
	GS.collapsed.connect(_on_collapsed)
	_apply_fx(true)
	Audio.music({"sweet": "sweet", "melting": "melting", "maze": "maze"}[GS.stage()])
	_run(story.intro)


# ------------------------------------------------------------------ helpers
func tex(name: String) -> Texture2D:
	return load("res://assets/sprites/%s.png" % name)


## Adds a sprite prop whose origin is at its base. col_size > 0 adds a
## static collision rectangle sitting on the base.
func add_prop(tname: String, pos: Vector2, col_size := Vector2.ZERO, parent: Node = null, sc := 1.0) -> Node2D:
	var n: Node2D
	if col_size != Vector2.ZERO:
		n = StaticBody2D.new()
		var c := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = col_size
		c.shape = r
		c.position = Vector2(0, -col_size.y / 2.0)
		n.add_child(c)
	else:
		n = Node2D.new()
	n.position = pos
	var s := Sprite2D.new()
	s.texture = tex(tname)
	s.offset = Vector2(0, -s.texture.get_height() / 2.0)
	s.scale = Vector2(sc, sc)
	s.name = "Sprite"
	n.add_child(s)
	(parent if parent else world).add_child(n)
	return n


func sprite_of(n: Node) -> Sprite2D:
	return n.get_node("Sprite") as Sprite2D


func add_interact(parent: Node2D, prompt: String, action: Callable, radius := 34.0, condition := Callable(), offset := Vector2.ZERO):
	var it = Interactable.new()
	it.prompt = prompt
	it.action = action
	it.radius = radius
	it.condition = condition
	it.position = offset
	parent.add_child(it)
	return it


func add_npc(id: String, tname: String, pos: Vector2, prompt: String, action: Callable) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	var d := Dot.new()
	n.add_child(d)
	var s := Sprite2D.new()
	s.texture = tex(tname)
	s.offset = Vector2(0, -s.texture.get_height() / 2.0)
	s.name = "Sprite"
	n.add_child(s)
	var body := StaticBody2D.new()
	var c := CollisionShape2D.new()
	var cs := CircleShape2D.new()
	cs.radius = 7.0
	c.shape = cs
	body.add_child(c)
	n.add_child(body)
	add_interact(n, prompt, action, 36.0)
	world.add_child(n)
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "scale", Vector2(1.0, 1.04), 0.9 + randf() * 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "scale", Vector2(1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE)
	nodes[id] = n
	return n


const FRAG_COLORS := {
	"emo_joy": Color(1.0, 0.86, 0.3), "emo_sad": Color(0.45, 0.7, 1.0),
	"emo_anger": Color(1.0, 0.35, 0.35), "emo_fear": Color(0.7, 0.45, 1.0),
	"emo_regret": Color(0.55, 0.9, 0.8),
}


func spawn_fragment(id: String, pos: Vector2, list: Array = []) -> Node2D:
	if GS.has_frag(id):
		return null
	var data: Dictionary = GS.FRAGMENTS[id]
	var n := Node2D.new()
	n.position = pos
	world.add_child(n)
	var s := Sprite2D.new()
	s.texture = tex("photo" if data["type"] == "memory" else "crystal")
	s.modulate = FRAG_COLORS.get(id, Color(1, 1, 1))
	s.offset = Vector2(0, -16)
	s.name = "Sprite"
	n.add_child(s)
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "position:y", -5.0, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	var label := "拾取：记忆碎片" if data["type"] == "memory" else "拾取：情绪碎片"
	add_interact(n, label, _pickup.bind(id, n), 30.0)
	list.append(n)
	lamps.append(n)
	nodes["frag_" + id] = n
	return n


func _pickup(id: String, n: Node2D) -> void:
	if not GS.add_fragment(id):
		return
	Audio.sfx("pickup")
	lamps.erase(n)
	n.queue_free()
	var data: Dictionary = GS.FRAGMENTS[id]
	await Dialog.say("file", "[color=#ffd6e6]%s[/color]\n%s" % [data["name"], data["desc"]])
	await story.on_fragment(id)


func add_glitch(pos: Vector2, key: String) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	world.add_child(n)
	var s := Sprite2D.new()
	s.texture = tex("glitch")
	s.offset = Vector2(0, -14)
	s.name = "Sprite"
	n.add_child(s)
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "scale", Vector2(1.25, 0.85), 0.12)
	tw.tween_property(s, "scale", Vector2(0.9, 1.15), 0.18)
	tw.tween_property(s, "scale", Vector2(1, 1), 0.5)
	tw.tween_interval(randf_range(0.4, 1.2))
	add_interact(n, "异常数据", story.glitch.bind(key, n), 32.0)
	nodes["glitch_" + key] = n
	return n


func add_label(parent: Node2D, text: String, offset: Vector2, color := Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.2))
	l.add_theme_constant_override("outline_size", 4)
	l.position = offset
	l.z_index = 5
	parent.add_child(l)
	l.reset_size()
	l.position.x = offset.x - l.size.x / 2.0
	return l


func add_slow_zone(pos: Vector2, radius: float) -> Node2D:
	var a := Area2D.new()
	a.position = pos
	var c := CollisionShape2D.new()
	var cs := CircleShape2D.new()
	cs.radius = radius
	c.shape = cs
	a.add_child(c)
	var s := Sprite2D.new()
	s.texture = tex("syrup")
	s.scale = Vector2(radius / 40.0, radius / 40.0)
	s.z_index = -8
	a.add_child(s)
	a.body_entered.connect(_on_slow_enter)
	a.body_exited.connect(_on_slow_exit)
	add_child(a)
	return a


func _on_slow_enter(b: Node) -> void:
	if b == player:
		player.slow_zones += 1


func _on_slow_exit(b: Node) -> void:
	if b == player:
		player.slow_zones = max(0, player.slow_zones - 1)


# ================================================================== worlds
func _build_bounds() -> void:
	var b := StaticBody2D.new()
	var w := world_size
	for r in [Rect2(-40, -40, w.x + 80, 40), Rect2(-40, w.y, w.x + 80, 40),
			Rect2(-40, 0, 40, w.y), Rect2(w.x, 0, 40, w.y)]:
		var c := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = r.size
		c.shape = rs
		c.position = r.position + r.size / 2.0
		b.add_child(c)
	add_child(b)


func _build_town(melted: bool) -> void:
	world_size = Vector2(1600, 1200)
	spawn = Vector2(800, 1110)
	var htex := "house_melted" if melted else "house"
	for p in [Vector2(560, 910), Vector2(560, 650), Vector2(1040, 910), Vector2(610, 440), Vector2(1000, 362)]:
		wobblers.append(add_prop(htex, p, Vector2(110, 36)))
	# candy lamps along the roads (glow at night)
	for p in [Vector2(840, 1060), Vector2(760, 960), Vector2(840, 860), Vector2(760, 700), Vector2(840, 560),
			Vector2(420, 740), Vector2(1100, 740), Vector2(700, 470), Vector2(1100, 800)]:
		var lp := add_prop("lamp", p, Vector2(4, 4))
		lamps.append(lp)
		wobblers.append(lp)
	# gumdrop bushes (decor)
	var rng := RandomNumberGenerator.new()
	rng.seed = 417
	var tints := [Color(1.0, 0.75, 0.85), Color(0.75, 0.9, 1.0), Color(1.0, 0.95, 0.7), Color(0.85, 0.75, 1.0)]
	for i in 34:
		var gp := Vector2(rng.randf_range(90, 1510), rng.randf_range(140, 1150))
		if absf(gp.x - 800) < 70 or absf(gp.y - 770) < 50 or gp.distance_to(Vector2(1250, 640)) < 170 or gp.distance_to(Vector2(1265, 900)) < 90:
			continue
		var g := add_prop("gumdrop", gp)
		sprite_of(g).modulate = tints[i % tints.size()]
		if melted:
			sprite_of(g).scale = Vector2(1.1, 0.8)
	nodes["tower"] = add_prop("clocktower", Vector2(800, 300), Vector2(60, 26))
	# grandma's carousel (SE). It "turns" by flipping in the sweet dream and sags as the city melts.
	var car := add_prop("carousel", Vector2(1265, 935), Vector2(80, 28))
	nodes["carousel"] = car
	wobblers.append(car)
	if GS.stage() == "melting":
		sprite_of(car).scale = Vector2(1.06, 0.9)
		sprite_of(car).modulate = Color(1.0, 0.86, 0.8)
	wobblers.append(nodes["tower"])
	# border of lollipop trees
	for x in range(50, 1600, 100):
		if x < 1360:
			wobblers.append(add_prop("lollipop", Vector2(x, 60), Vector2(14, 8)))
		if x < 690 or x > 910:
			wobblers.append(add_prop("lollipop", Vector2(x, 1195), Vector2(14, 8)))
	for y in range(170, 1150, 110):
		wobblers.append(add_prop("lollipop", Vector2(30, y), Vector2(14, 8)))
		if y > 330:
			wobblers.append(add_prop("lollipop", Vector2(1570, y), Vector2(14, 8)))
	# lollipop grove (north-west)
	for p in [Vector2(200, 290), Vector2(300, 250), Vector2(350, 350), Vector2(230, 410), Vector2(150, 360), Vector2(410, 260)]:
		wobblers.append(add_prop("lollipop", p, Vector2(14, 8)))
	# fences along the main street
	for x in range(620, 1000, 32):
		if x < 740 or x > 860:
			add_prop("fence", Vector2(x, 1010), Vector2(32, 6))
	# cake plaza (east)
	nodes["cake"] = add_prop("cake", Vector2(1250, 615), Vector2(80, 22))
	lamps.append(nodes["cake"])
	# grandma's candy shop (west) — hidden until the photo is found
	var shop := add_prop("house", Vector2(250, 840), Vector2(110, 36))
	nodes["shop"] = shop
	var open_shop: bool = GS.has_frag("mem_photo") and GS.stage() != "sweet"
	sprite_of(shop).modulate = Color(1.0, 0.88, 0.7, 1.0) if open_shop else Color(0.8, 0.8, 1.0, 0.22)
	if open_shop:
		add_label(shop, "奶奶的糖果店", Vector2(0, -170), Color(1.0, 0.9, 0.6))
	else:
		for x in range(180, 330, 32):
			add_prop("fence", Vector2(x, 880), Vector2(32, 6))

	if melted:
		for p in [Vector2(700, 720), Vector2(930, 820), Vector2(620, 1040), Vector2(960, 620), Vector2(420, 560)]:
			add_slow_zone(p, 34.0)
		_build_syrup_ring(Vector2(1250, 640), 104.0)
		_build_alcove()


func _build_syrup_ring(c: Vector2, r: float) -> void:
	var n := 16
	for i in n:
		var ang := TAU * i / n
		var p := c + Vector2(cos(ang), sin(ang) * 0.8) * r
		var body := StaticBody2D.new()
		body.position = p
		var col := CollisionShape2D.new()
		var cs := CircleShape2D.new()
		cs.radius = 24.0
		col.shape = cs
		body.add_child(col)
		var s := Sprite2D.new()
		s.texture = tex("syrup")
		s.scale = Vector2(0.75, 0.75)
		s.rotation = randf() * 0.6 - 0.3
		s.z_index = -8
		body.add_child(s)
		add_child(body)
		var deg := fposmod(rad_to_deg(ang), 360.0)
		var bridge := deg > 150.0 and deg < 210.0
		syrup_blobs.append({"body": body, "col": col, "sprite": s, "bridge": bridge})
		if bridge:
			var g := add_prop("gumdrop", p + Vector2(0, 6))
			fantasy_only.append(g)


func _build_alcove() -> void:
	var cells := [Vector2(1388, 198), Vector2(1436, 198), Vector2(1484, 198), Vector2(1532, 198),
		Vector2(1388, 246), Vector2(1532, 246), Vector2(1388, 294), Vector2(1532, 294)]
	for p in cells:
		add_prop("chocowall", p, Vector2(48, 48))
	for p in [Vector2(1436, 294), Vector2(1484, 294)]:
		add_breakable(p)


func add_breakable(p: Vector2, grid_cell := Vector2i(-1, -1)) -> Node2D:
	var w := add_prop("chocowall", p, Vector2(48, 48))
	var cr := Sprite2D.new()
	cr.texture = tex("cracks")
	cr.region_enabled = true
	cr.region_rect = Rect2(0, 0, 48, 64)
	cr.offset = Vector2(0, -32)
	cr.modulate = Color(1, 1, 1, 0.6)
	cr.name = "Cracks"
	w.add_child(cr)
	w.set_meta("cell", grid_cell)
	add_interact(w, "有裂缝的巧克力墙", story.break_wall.bind(w), 44.0, Callable(), Vector2(0, 10))
	breakables.append(w)
	return w


## Stops a node's interactables from firing again (e.g. while it fades out).
func retire(node: Node) -> void:
	node.set_meta("retired", true)


func break_wall(w: Node2D) -> void:
	retire(w)
	Audio.sfx("break")
	shake(6.0)
	breakables.erase(w)
	var cell: Vector2i = w.get_meta("cell", Vector2i(-1, -1))
	if astar and cell.x >= 0:
		astar.set_point_solid(cell, false)
		maze[cell.y][cell.x] = 0
	var t := w.create_tween()
	t.tween_property(w, "modulate:a", 0.0, 0.3)
	t.tween_callback(w.queue_free)


func _build_maze() -> void:
	world_size = Vector2(MW * CELL, MH * CELL)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2078
	maze = []
	for y in MH:
		var row := []
		for x in MW:
			row.append(1)
		maze.append(row)
	# the clock tower room (cells x9-15, y7-11) is reserved before carving and
	# walled in, with a single door on the far (north) side: the player has to
	# walk all the way around -- or break a cracked wall with anger.
	var in_room := func(c: Vector2i) -> bool:
		return c.x >= 9 and c.x <= 15 and c.y >= 7 and c.y <= 11
	var in_ring := func(c: Vector2i) -> bool:
		return c.x >= 8 and c.x <= 16 and c.y >= 6 and c.y <= 12
	# recursive backtracker on odd cells, around the room
	var stack: Array = [Vector2i(1, 1)]
	maze[1][1] = 0
	while stack.size() > 0:
		var cur: Vector2i = stack[stack.size() - 1]
		var nbs: Array = []
		for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			var nx: Vector2i = cur + d
			if nx.x > 0 and nx.x < MW - 1 and nx.y > 0 and nx.y < MH - 1 and maze[nx.y][nx.x] == 1 and not in_room.call(nx):
				nbs.append(d)
		if nbs.is_empty():
			stack.pop_back()
			continue
		var dd: Vector2i = nbs[rng.randi_range(0, nbs.size() - 1)]
		maze[cur.y + dd.y / 2][cur.x + dd.x / 2] = 0
		maze[cur.y + dd.y][cur.x + dd.x] = 0
		stack.append(cur + dd)
	# a few loops so it is less punishing (never through the room's ring)
	for y in range(1, MH - 1):
		for x in range(1, MW - 1):
			if maze[y][x] == 1 and not in_ring.call(Vector2i(x, y)) and rng.randf() < 0.08:
				var horiz: bool = maze[y][x - 1] == 0 and maze[y][x + 1] == 0
				var vert: bool = maze[y - 1][x] == 0 and maze[y + 1][x] == 0
				if horiz != vert:
					maze[y][x] = 0
	# rooms: centre (clock tower), shop (NW), echo room (NE)
	for y in range(7, 12):
		for x in range(9, 16):
			maze[y][x] = 0
	maze[6][13] = 0   # the only door, facing north
	for y in range(1, 4):
		for x in range(1, 4):
			maze[y][x] = 0
		for x in range(21, 24):
			maze[y][x] = 0
	var start := Vector2i(11, 17)
	maze[17][11] = 0
	spawn = cell_center(start)

	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, MW, MH)
	astar.cell_size = Vector2(CELL, CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y in MH:
		for x in MW:
			if maze[y][x] == 1:
				astar.set_point_solid(Vector2i(x, y), true)

	# path from start to the clock tower room (for lamps & footprints)
	maze_path = astar.get_id_path(start, Vector2i(12, 9))

	# breakable walls: interior walls between two floor cells
	var candidates: Array = []
	for y in range(2, MH - 2):
		for x in range(2, MW - 2):
			if maze[y][x] == 1:
				var h: bool = maze[y][x - 1] == 0 and maze[y][x + 1] == 0
				var v: bool = maze[y - 1][x] == 0 and maze[y + 1][x] == 0
				if h != v and not in_ring.call(Vector2i(x, y)):
					candidates.append(Vector2i(x, y))
	var breakable_set := {Vector2i(11, 12): true}
	for i in 5:
		if candidates.is_empty():
			break
		var c: Vector2i = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
		breakable_set[c] = true

	for y in MH:
		for x in MW:
			if maze[y][x] == 1:
				var bottom := Vector2(x * CELL + CELL / 2.0, (y + 1) * CELL)
				if breakable_set.has(Vector2i(x, y)):
					add_breakable(bottom, Vector2i(x, y))
				else:
					add_prop("chocowall", bottom, Vector2(CELL, CELL))

	# lamps (night) and footprints (sad) along the path
	for i in maze_path.size():
		var c: Vector2i = maze_path[i]
		var p := cell_center(c)
		if i % 3 == 1:
			var fp := Sprite2D.new()
			fp.texture = tex("footprint")
			fp.position = p
			fp.z_index = -7
			fp.modulate = Color(0.9, 0.95, 1.0, 0.8)
			if i + 1 < maze_path.size():
				var nxt: Vector2i = maze_path[i + 1]
				fp.rotation = Vector2(nxt - c).angle() + PI / 2.0
			add_child(fp)
			sad_only.append(fp)
		if i % 4 == 2:
			var lp := add_prop("lamp", p + Vector2(14, 14))
			night_only.append(lp)
			lamps.append(lp)

	nodes["tower"] = add_prop("clocktower", Vector2(600, 390), Vector2(60, 26))
	nodes["cake"] = add_prop("cake", Vector2(680, 500), Vector2(80, 22))
	lamps.append(nodes["cake"])
	var shop := add_prop("house", cell_center(Vector2i(2, 2)) + Vector2(0, 20), Vector2(70, 24), null, 0.6)
	nodes["shop"] = shop
	var open_shop: bool = GS.has_frag("mem_photo")
	sprite_of(shop).modulate = Color(1.0, 0.88, 0.7, 1.0) if open_shop else Color(0.8, 0.8, 1.0, 0.22)
	if open_shop:
		add_label(shop, "奶奶的糖果店", Vector2(0, -104), Color(1.0, 0.9, 0.6))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL + CELL / 2.0, c.y * CELL + CELL / 2.0 + 10.0)


# ================================================================== fx
func _build_fx() -> void:
	var rl := CanvasLayer.new()
	rl.layer = 1
	add_child(rl)
	rain = CPUParticles2D.new()
	var img := Image.create(2, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.9, 1.0, 0.7))
	rain.texture = ImageTexture.create_from_image(img)
	rain.position = Vector2(640, -20)
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(760, 10)
	rain.amount = 260
	rain.lifetime = 0.9
	rain.direction = Vector2(-0.15, 1)
	rain.spread = 2.0
	rain.gravity = Vector2(0, 0)
	rain.initial_velocity_min = 800.0
	rain.initial_velocity_max = 1000.0
	rain.emitting = false
	rl.add_child(rain)

	sparkles = CPUParticles2D.new()
	var simg := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	simg.fill(Color(1, 1, 1, 1))
	sparkles.texture = ImageTexture.create_from_image(simg)
	sparkles.position = Vector2(640, 360)
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparkles.emission_rect_extents = Vector2(660, 380)
	sparkles.amount = 60
	sparkles.lifetime = 3.0
	sparkles.direction = Vector2(0, -1)
	sparkles.spread = 40.0
	sparkles.gravity = Vector2(0, -10)
	sparkles.initial_velocity_min = 5.0
	sparkles.initial_velocity_max = 25.0
	sparkles.scale_amount_min = 1.0
	sparkles.scale_amount_max = 2.5
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.3, Color(1.0, 0.95, 0.7, 0.9))
	grad.add_point(0.7, Color(1.0, 0.7, 0.9, 0.7))
	sparkles.color_ramp = grad
	sparkles.emitting = false
	rl.add_child(sparkles)

	var pl := CanvasLayer.new()
	pl.layer = 2
	add_child(pl)
	var post := ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://shaders/dream_post.gdshader")
	post.material = post_mat
	pl.add_child(post)


func _fx_targets() -> Dictionary:
	var sat := 1.0
	var tint := Color(1, 1, 1)
	var ta := 0.0
	match GS.emotion:
		"happy":
			sat = 1.55
			tint = Color(1.08, 1.0, 0.9)
			ta = 0.3
		"sad":
			sat = 0.5
			tint = Color(0.72, 0.86, 1.2)
			ta = 0.6
		"anger":
			sat = 1.15
			tint = Color(1.35, 0.72, 0.7)
			ta = 0.55
	var r: int = GS.reality
	var wave: float = [0.0, 0.7, 1.6, 2.4][r]
	var vig: float = 0.25 + [0.0, 0.05, 0.2, 0.6][r]
	match GS.stage():
		"melting":
			wave += 0.35
			if ta < 0.2:
				tint = Color(1.08, 0.95, 0.85)
				ta = 0.3
		"maze":
			sat *= 0.9
			vig += 0.15
	return {
		"saturation": sat, "tint": tint, "tint_amount": ta, "wave": wave,
		"aberration": [0.0, 0.6, 1.6, 2.6][r], "glitch": [0.0, 0.04, 0.3, 0.55][r],
		"vignette": vig,
		"vignette_color": Color(0.4, 0.0, 0.1) if r == 3 else Color(0.05, 0.02, 0.12),
		"night": 1.0 if GS.time == "night" else 0.0,
	}


func _apply_fx(instant := false) -> void:
	var t := _fx_targets()
	if instant:
		for k in t.keys():
			post_mat.set_shader_parameter(k, t[k])
	else:
		var tw := create_tween().set_parallel(true)
		for k in t.keys():
			tw.tween_property(post_mat, "shader_parameter/" + k, t[k], 0.9)
		post_mat.set_shader_parameter("flash", 0.35)
		tw.tween_property(post_mat, "shader_parameter/flash", 0.0, 0.5)

	var night: bool = GS.time == "night"
	var r: int = GS.reality
	for n in night_only:
		if is_instance_valid(n):
			n.visible = night
	for n in fantasy_only:
		if is_instance_valid(n):
			n.visible = r >= 1
	for n in madness_only:
		if is_instance_valid(n):
			n.visible = r >= 2
	for n in sad_only:
		if is_instance_valid(n):
			n.visible = GS.emotion == "sad"
	rain.emitting = GS.emotion == "sad"
	Audio.rain(GS.emotion == "sad")
	sparkles.emitting = GS.emotion == "happy" or r == 1
	var crack_a := 0.0
	if GS.emotion == "anger":
		crack_a = 0.85
	elif GS.residue.get("emotion", "") == "anger" and GS.dive() > 1:
		crack_a = 0.3
	create_tween().tween_property(cracks, "modulate:a", crack_a, 0.8)
	# syrup: happy crystallises everything, fantasy opens the gumdrop bridge
	for b in syrup_blobs:
		var crystal: bool = GS.emotion == "happy"
		var passable: bool = crystal or (b["bridge"] and r >= 1)
		(b["sprite"] as Sprite2D).texture = tex("sugarglass" if crystal else "syrup")
		(b["col"] as CollisionShape2D).set_deferred("disabled", passable)
		(b["sprite"] as Sprite2D).modulate.a = 0.35 if (passable and not crystal) else 1.0
	for w in breakables:
		if is_instance_valid(w):
			var c := w.get_node("Cracks") as Sprite2D
			c.modulate = Color(1.0, 0.3, 0.3, 1.0) if GS.emotion == "anger" else Color(1, 1, 1, 0.6)
	_sync_shadows()


func _sync_shadows() -> void:
	var want := 0
	var spd := 50.0
	if astar:
		want = 1 + GS.reality
		spd = 46.0 + 12.0 * GS.reality
	elif GS.reality == 3:
		want = 3
		spd = 62.0
	elif GS.reality == 2 and GS.stage() == "melting":
		want = 1
	while shadows.size() > want:
		var s = shadows.pop_back()
		s.queue_free()
	while shadows.size() < want:
		var s = Shadow.new()
		s.dream = self
		s.player = player
		if astar:
			s.astar = astar
			s.cell = CELL
			s.position = _far_cell()
		else:
			var edge := [Vector2(120, 600), Vector2(1480, 1000), Vector2(800, 120), Vector2(1450, 420)]
			s.position = edge[shadows.size() % edge.size()]
		world.add_child(s)
		shadows.append(s)
	for s in shadows:
		s.speed = spd


func _far_cell() -> Vector2:
	for i in 40:
		var c := Vector2i(randi_range(1, MW - 2), randi_range(1, MH - 2))
		if maze[c.y][c.x] == 0 and Vector2(c).distance_to(Vector2(11, 17)) > 7.0:
			if c.x < 8 or c.x > 16 or c.y < 6 or c.y > 12:
				return cell_center(c)
	return cell_center(Vector2i(1, 1))


func _on_editor_changed() -> void:
	_apply_fx(false)
	story.on_editor_changed()


func shake(amount: float) -> void:
	_shake = max(_shake, amount)


func flash(color := Color(1, 1, 1), dur := 0.6) -> void:
	fader.color = Color(color.r, color.g, color.b, 0.8)
	create_tween().tween_property(fader, "color:a", 0.0, dur)


# ================================================================== loop
func can_player_act() -> bool:
	return busy == 0 and not Dialog.active and not _ended and _caught_cd <= 0.0 \
		and hud != null and not hud.any_panel_open()


func _process(delta: float) -> void:
	_t += delta
	if _caught_cd > 0.0:
		_caught_cd -= delta
	# camera shake
	if _shake > 0.0:
		camera.offset = Vector2(0, -20) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = max(0.0, _shake - delta * 18.0)
	else:
		camera.offset = Vector2(0, -20)
	# anger: the world trembles now and then
	if GS.emotion == "anger":
		_anger_t -= delta
		if _anger_t <= 0.0:
			_anger_t = randf_range(2.5, 5.0)
			shake(3.0)
	# madness: props wobble
	var wob: float = [0.0, 0.0, 0.05, 0.09][GS.reality]
	for w in wobblers:
		if is_instance_valid(w):
			var s := sprite_of(w)
			s.rotation = sin(_t * 1.7 + w.position.x * 0.01) * wob
			s.skew = sin(_t * 1.3 + w.position.y * 0.02) * wob * 0.8
	# the carousel turns (sprite flip) while the dream is sweet, or happy
	if nodes.has("carousel") and is_instance_valid(nodes["carousel"]):
		var spin: float = 0.0
		if GS.stage() == "sweet" or GS.emotion == "happy":
			spin = 1.6 if GS.emotion == "happy" else 0.9
		elif GS.stage() == "melting":
			spin = 0.25
		if spin > 0.0:
			sprite_of(nodes["carousel"]).flip_h = int(_t * spin) % 2 == 1
	# stability drain in unstable realities
	if can_player_act():
		var drain: float = [0.0, 0.0, 0.45, 0.9][GS.reality]
		if drain > 0.0:
			GS.change_stability(-drain * delta)
	_update_lights()
	_update_prompt()


func _world_to_screen(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * p


func _update_lights() -> void:
	var vs := get_viewport().get_visible_rect().size
	post_mat.set_shader_parameter("light_pos", _world_to_screen(player.global_position + Vector2(0, -22)) / vs)
	var pts := PackedVector2Array()
	for l in lamps:
		if pts.size() >= 8:
			break
		if not is_instance_valid(l) or not l.is_visible_in_tree():
			continue
		var sp := _world_to_screen(l.global_position + Vector2(0, -18)) / vs
		if sp.x > -0.1 and sp.x < 1.1 and sp.y > -0.1 and sp.y < 1.1:
			pts.append(sp)
	var n := pts.size()
	while pts.size() < 8:
		pts.append(Vector2(-10, -10))
	post_mat.set_shader_parameter("lamp_pos", pts)
	post_mat.set_shader_parameter("lamp_count", float(n))


func _nearest_interactable():
	var best = null
	var bd := 1e9
	for it in get_tree().get_nodes_in_group("interactable"):
		if not it.available():
			continue
		var d: float = it.global_position.distance_to(player.global_position)
		if d < it.radius and d < bd:
			bd = d
			best = it
	return best


func _update_prompt() -> void:
	if not can_player_act():
		hud.hide_prompt()
		return
	var it = _nearest_interactable()
	if it == null:
		hud.hide_prompt()
		return
	var sp := _world_to_screen(it.global_position + Vector2(0, -8))
	hud.show_prompt(it.prompt, sp + Vector2(0, 14))


func _input(event: InputEvent) -> void:
	if Dialog.active or _ended or busy > 0:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		hud.toggle_pause()
	elif event.is_action_pressed("editor"):
		get_viewport().set_input_as_handled()
		if not hud.pause_panel.visible and not hud.fragments_panel.visible:
			hud.toggle_editor()
			if not hud.editor.visible:
				story.on_editor_closed()
	elif event.is_action_pressed("fragments"):
		get_viewport().set_input_as_handled()
		hud.toggle_fragments()
	elif can_player_act():
		if event.is_action_pressed("interact"):
			var it = _nearest_interactable()
			if it:
				get_viewport().set_input_as_handled()
				it.used = true
				_run(it.action)
		elif event.is_action_pressed("ask_xm"):
			get_viewport().set_input_as_handled()
			_run(story.ask_xm)


## Phone went to the background (call, home button): open the pause menu.
func _on_app_paused() -> void:
	if can_player_act():
		hud.toggle_pause()


func _run(fn: Callable) -> void:
	if not fn.is_valid():
		return
	busy += 1
	hud.hide_prompt()
	await fn.call()
	busy = max(0, busy - 1)


## For triggers (areas, timers): waits until no dialogue is running.
func run_event(fn: Callable) -> void:
	while Dialog.active or busy > 0:
		await get_tree().process_frame
	_run(fn)


# ================================================================== failure / end
func on_caught(_s) -> void:
	if _caught_cd > 0.0 or _ended:
		return
	_caught_cd = 1.6
	Audio.sfx("caught")
	flash(Color(0.4, 0.0, 0.1), 0.9)
	shake(8.0)
	GS.change_stability(-12.0)
	GS.emit_signal("toast", "被大人影子抓住了……稳定度 -12")
	player.position = spawn
	xm.position = spawn
	for s in shadows:
		if astar:
			s.position = _far_cell()
		else:
			s.position = s.home


func _on_collapsed() -> void:
	if _ended:
		return
	_ended = true
	Audio.sfx("glitch")
	post_mat.set_shader_parameter("glitch", 1.0)
	post_mat.set_shader_parameter("wave", 4.0)
	await get_tree().create_timer(0.8).timeout
	await story.collapse()
	GS.collapse_dive()
	await _fade_out(Color(0, 0, 0))
	GS.goto("clinic")


func abort_dive() -> void:
	if _ended:
		return
	_ended = true
	hud.pause_panel.visible = false
	GS.residue = {"time": "day", "emotion": "calm", "reality": 0}
	GS.save_game()
	await _fade_out(Color(0, 0, 0))
	GS.goto("clinic")


func _fade_out(c: Color) -> void:
	fader.color = Color(c.r, c.g, c.b, 0.0)
	var t := create_tween()
	t.tween_property(fader, "color:a", 1.0, 1.0)
	await t.finished


## Called by story when the dive's core choice is made.
func wake(core_choice: String) -> void:
	_ended = true
	Audio.sfx("wake")
	Audio.rain(false)
	await _fade_out(Color(1, 1, 1))
	GS.end_dive(core_choice)
	if GS.visit >= GS.MAX_DIVES:
		GS.goto("ending")
	else:
		GS.goto("clinic")
