extends RefCounted
## Dream 3: one walkable station, three futures. Geometry is deliberately
## simple enough for keyboard, controller and a child's first touch game.
## Deck y=280..870; seed vault x=520..780, y=100..280. During drift a
## vacuum divides the deck; during genesis the tomorrow hatch is sealed.

const Shadow := preload("res://scripts/shadow.gd")
const WORLD := Vector2(1920, 1000)
const SPAWN := Vector2(170, 640)
const GAP := Rect2(890, 280, 140, 590)
const HATCH := Rect2(1580, 280, 20, 590)
const HOMES := [Vector2(300, 820), Vector2(1230, 810), Vector2(1450, 330)]
const BLUEPRINTS := {"garden": "星光花园", "harbor": "浮岛港口", "library": "极光图书馆"}

var d
var gap_col: CollisionShape2D = null
var hatch_col: CollisionShape2D = null
var vault_col: CollisionShape2D
var hatch_open := false
var bridge_open := false
var vault_open := false
var clock: Node2D
var console: Node2D
var condensate: Node2D
var chart: Node2D
var chart_label: Label
var blueprint_label: Label
var gate: Node2D = null
var creations: Array = []
var _gap_closed := true
var _hatch_closed := true
var _vault_closed := true
var _t := 0.0


func _init(dream) -> void:
	d = dream


func _wall(rect: Rect2) -> CollisionShape2D:
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	col.position = rect.get_center()
	body.add_child(col)
	d.add_child(body)
	return col


func build() -> void:
	d.world_size = WORLD
	d.spawn = SPAWN
	_wall(Rect2(0, 260, 520, 20))
	_wall(Rect2(780, 260, WORLD.x - 780, 20))
	_wall(Rect2(500, 90, 20, 190))
	_wall(Rect2(780, 90, 20, 190))
	_wall(Rect2(500, 80, 300, 20))
	_wall(Rect2(0, 870, WORLD.x, 20))
	vault_col = _wall(Rect2(520, 260, 260, 20))

	for p in [Vector2(220, 335), Vector2(1120, 330), Vector2(1510, 330)]:
		var pod: Node2D = d.add_prop("sp_pod", p, Vector2(60, 20))
		d.wobblers.append(pod)
	var dome: Node2D = d.add_prop("sp_observatory", Vector2(1370, 267), Vector2.ZERO, null, 1.0)
	d.add_label(dome, "观星台 · 远望", Vector2(0, -156), Color(0.65, 0.9, 1.0))
	d.wobblers.append(dome)
	var vault: Node2D = d.add_prop("sp_greenhouse", Vector2(650, 232), Vector2(100, 16))
	d.add_label(vault, "育种舱", Vector2(0, -106), Color(0.85, 1, 0.7))
	d.nodes["vault"] = vault
	var entry := Node2D.new()
	entry.position = Vector2(650, 300)
	d.world.add_child(entry)
	d.nodes["vault_entry"] = entry
	var pot: Node2D = d.add_prop("sp_planter", Vector2(550, 180), Vector2(18, 10))
	d.nodes["empty_pot"] = pot

	clock = d.add_prop("sp_clock", Vector2(390, 450), Vector2(24, 14))
	d.add_label(clock, "轨道钟", Vector2(0, -78), Color(1, 0.86, 0.55))
	d.lamps.append(clock)
	console = d.add_prop("sp_console", Vector2(760, 430), Vector2(56, 16))
	d.add_label(console, "维护终端", Vector2(0, -70), Color(0.8, 0.93, 1))
	condensate = d.add_prop("sp_condensate", Vector2(760, 800))
	condensate.z_index = -6
	chart = d.add_prop("sp_chart", Vector2(1390, 470), Vector2(50, 16))
	chart_label = d.add_label(chart, "星图 · 已知航线", Vector2(0, -84), Color(0.9, 0.8, 1))
	d.lamps.append(chart)
	var radio: Node2D = d.add_prop("sp_terminal", Vector2(490, 760), Vector2(28, 12))
	d.add_label(radio, "地球来信", Vector2(0, -72), Color(0.8, 0.93, 1))
	d.nodes["earth_terminal"] = radio

	for p in [Vector2(330, 570), Vector2(700, 580), Vector2(1160, 680), Vector2(1460, 750)]:
		var plant: Node2D = d.add_prop("sp_planter", p, Vector2(18, 10))
		d.wobblers.append(plant)
	for x in [120, 510, 840, 1090, 1500, 1820]:
		var light: Node2D = d.add_prop("sp_beacon", Vector2(float(x), 850), Vector2(8, 8))
		d.lamps.append(light)

	if GS.stage() == "drift":
		gap_col = _wall(GAP)
		for i in 8:
			var step: Node2D = d.add_prop("sp_bridge", Vector2(896 + i * 18, 566))
			step.z_index = -6
			d.fantasy_only.append(step)
		gate = d.add_prop("sp_gate", Vector2(760, 466), Vector2(64, 16))
		d.nodes["maintenance_gate"] = gate
		if GS.flag("sp_gate_broken"):
			break_gate()
	if GS.stage() == "genesis":
		hatch_col = _wall(HATCH)
		var hatch: Node2D = d.add_prop("sp_hatch", Vector2(1590, 870))
		hatch.z_index = 4
		d.nodes["tomorrow_hatch"] = hatch
		var seed: Node2D = d.add_prop("sp_console", Vector2(1180, 780), Vector2(56, 16))
		blueprint_label = d.add_label(seed, "造梦台", Vector2(0, -70), Color(1, 0.85, 0.55))
		d.nodes["seed_console"] = seed
		set_blueprint(str(GS.flags.get("sp_blueprint", "garden")))


func break_gate() -> void:
	if not is_instance_valid(gate):
		gate = null
		return
	d.retire(gate)
	for child in gate.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
	gate.hide()
	gate.queue_free()
	gate = null


func open_hatch() -> void:
	hatch_open = true
	if hatch_col:
		hatch_col.set_deferred("disabled", true)
		_hatch_closed = false
	if d.nodes.has("tomorrow_hatch"):
		d.nodes["tomorrow_hatch"].modulate = Color(0.7, 1, 1, 0.18)
	d.flash(Color(0.7, 0.93, 1), 0.7)


func set_blueprint(key: String) -> void:
	if not BLUEPRINTS.has(key):
		key = "garden"
	GS.flags["sp_blueprint"] = key
	for n in creations:
		if is_instance_valid(n):
			n.hide()
			n.queue_free()
	creations.clear()
	var skin: String = {"garden": "sp_starflower", "harbor": "sp_island", "library": "sp_books"}[key]
	for i in 6:
		var pos := Vector2(1080 + (i % 3) * 154, 620 + (i / 3) * 74)
		var n: Node2D = d.add_prop(skin, pos)
		creations.append(n)
	if blueprint_label:
		blueprint_label.text = "造梦台 · " + str(BLUEPRINTS[key])
		blueprint_label.reset_size()
		blueprint_label.position.x = -blueprint_label.size.x / 2.0


func apply_fx() -> void:
	bridge_open = GS.reality >= 1
	vault_open = GS.flag("sp_vault_open") or (GS.has_frag("sp_photo") and GS.emotion == "happy")
	if vault_open:
		GS.set_flag("sp_vault_open")
	if _vault_closed == vault_open:
		_vault_closed = not vault_open
		vault_col.set_deferred("disabled", not _vault_closed)
	d.nodes["vault"].modulate = Color(1, 1, 1, 1) if vault_open else Color(0.55, 0.65, 0.9, 0.45)
	chart_label.text = "星图 · 未知也可以是目的地" if GS.reality >= 2 else "星图 · 已知航线"
	chart_label.reset_size()
	chart_label.position.x = -chart_label.size.x / 2.0
	condensate.modulate.a = 1.0 if GS.emotion == "sad" else 0.2
	_refresh_gap()


func _refresh_gap() -> void:
	if gap_col == null:
		return
	# Closing gravity while on the bridge must not strand the player in a
	# collider. Keep it open until their entire body has crossed either edge.
	var inside: bool = d.player != null and d.player.position.x > GAP.position.x - 14 \
		and d.player.position.x < GAP.end.x + 14
	var closed: bool = not bridge_open and not inside
	if closed != _gap_closed or gap_col.disabled == closed:
		_gap_closed = closed
		gap_col.set_deferred("disabled", not closed)


func process(delta: float) -> void:
	_t += delta
	_refresh_gap()
	for i in creations.size():
		var s: Sprite2D = d.sprite_of(creations[i])
		s.position.y = sin(_t * 1.2 + i) * (3.0 if GS.reality >= 1 else 1.0)


func sync_shadows() -> void:
	# Rounded repair drones, not scary humanoids. They recall you to the
	# docking bay and reduce stability; no combat or damage to the dreamer.
	var want := 2 if GS.reality == 3 else 0
	while d.shadows.size() > want:
		var old = d.shadows.pop_back()
		old.queue_free()
	while d.shadows.size() < want:
		var s = Shadow.new()
		s.skin = "sp_drone"
		s.dream = d
		s.player = d.player
		s.position = HOMES[d.shadows.size()]
		d.world.add_child(s)
		d.shadows.append(s)
	for s in d.shadows:
		s.speed = 44.0
