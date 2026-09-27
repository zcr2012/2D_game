extends CharacterBody2D
## The Dream Repairer. Top-down movement with a procedural walk bob.

const SPEED := 118.0

var dream = null
var sprite: Sprite2D
var slow_zones := 0
var facing := Vector2.DOWN
var _bob := 0.0


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/player.png")
	sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)
	add_child(sprite)
	var col := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 6.0
	col.shape = sh
	add_child(col)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 9.0, Color(0.1, 0.0, 0.2, 0.28))


func can_move() -> bool:
	return dream != null and dream.can_player_act()


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if can_move():
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var spd := SPEED * (0.45 if slow_zones > 0 else 1.0)
	velocity = input * spd
	move_and_slide()
	if input.length() > 0.1:
		facing = input.normalized()
		_bob += delta * (8.0 if slow_zones > 0 else 13.0)
		if absf(input.x) > 0.1:
			sprite.flip_h = input.x < 0.0
		sprite.position.y = -absf(sin(_bob)) * 2.5
		sprite.rotation = sin(_bob) * 0.05
	else:
		sprite.position.y = lerpf(sprite.position.y, 0.0, 0.3)
		sprite.rotation = lerpf(sprite.rotation, 0.0, 0.3)
		_bob = 0.0
