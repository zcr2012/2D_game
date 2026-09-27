extends Node2D
## "Grown-up shadow" — chases the player. In the maze it walks the corridors
## using an AStarGrid2D; in open maps it drifts straight through things.

var dream = null
var player: Node2D
var astar: AStarGrid2D = null
var cell := 48.0
var speed := 55.0
var home := Vector2.ZERO
var sprite: Sprite2D
var _path: PackedVector2Array = PackedVector2Array()
var _repath := 0.0
var _wander_target := Vector2.ZERO
var _t := 0.0
var active := true


func _ready() -> void:
	add_to_group("shadow")
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/shadow.png")
	sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)
	sprite.modulate = Color(1, 1, 1, 0.9)
	add_child(sprite)
	home = global_position
	_wander_target = home
	_t = randf() * 10.0


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 12.0, Color(0.05, 0.0, 0.1, 0.45))


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(p.x / cell), int(p.y / cell))


func _physics_process(delta: float) -> void:
	_t += delta
	sprite.skew = sin(_t * 2.0) * 0.08
	sprite.modulate.a = 0.75 + 0.2 * sin(_t * 3.0)
	if not active or player == null or dream == null:
		return
	if not dream.can_player_act():
		return
	var to_player := player.global_position - global_position
	var chasing := to_player.length() < 220.0
	var goal := player.global_position if chasing else _wander_target
	var step := speed * (1.0 if chasing else 0.6) * delta
	if astar:
		_repath -= delta
		if _repath <= 0.0 or _path.is_empty():
			_repath = 0.5
			var from := _cell_of(global_position)
			var to := _cell_of(goal)
			if astar.is_in_boundsv(from) and astar.is_in_boundsv(to) and not astar.is_point_solid(to):
				_path = astar.get_point_path(from, to)
				if _path.size() > 0:
					_path.remove_at(0)
			else:
				_path = PackedVector2Array()
		if _path.size() > 0:
			var nxt := _path[0] + Vector2(cell / 2.0, cell / 2.0 + 10.0)
			global_position = global_position.move_toward(nxt, step)
			if global_position.distance_to(nxt) < 2.0:
				_path.remove_at(0)
		elif not chasing:
			_pick_wander()
	else:
		global_position = global_position.move_toward(goal, step)
		if not chasing and global_position.distance_to(_wander_target) < 4.0:
			_pick_wander()
	if absf(to_player.x) > 2.0:
		sprite.flip_h = to_player.x < 0.0
	if to_player.length() < 15.0:
		dream.on_caught(self)


func _pick_wander() -> void:
	if astar:
		for i in 12:
			var c := Vector2i(randi_range(1, astar.region.size.x - 2), randi_range(1, astar.region.size.y - 2))
			if not astar.is_point_solid(c) and Vector2(c).distance_to(Vector2(_cell_of(global_position))) < 7.0:
				_wander_target = Vector2(c) * cell + Vector2(cell / 2.0, cell / 2.0 + 10.0)
				return
	else:
		_wander_target = home + Vector2(randf_range(-120, 120), randf_range(-80, 80))
