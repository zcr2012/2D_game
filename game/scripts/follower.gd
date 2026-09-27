extends Node2D
## Xiaomian, the floating assistant robot that follows the player.

var target = null   # the player (untyped: we read its custom `sprite` field)
var sprite: Sprite2D
var bubble: Label
var _t := 0.0


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/xiaomian.png")
	sprite.offset = Vector2(0, -44)
	add_child(sprite)
	bubble = Label.new()
	bubble.text = "!"
	bubble.add_theme_font_size_override("font_size", 12)
	bubble.modulate = Color(1.0, 0.9, 0.4)
	bubble.position = Vector2(8, -78)
	bubble.visible = false
	add_child(bubble)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 6.0, Color(0.1, 0.0, 0.2, 0.18))


func set_alert(on: bool) -> void:
	bubble.visible = on


func _process(delta: float) -> void:
	_t += delta
	if target:
		var side := -1.0
		if target.sprite.flip_h:
			side = 1.0
		var goal: Vector2 = target.global_position + Vector2(18.0 * side, 2.0)
		global_position = global_position.lerp(goal, 1.0 - exp(-3.5 * delta))
		sprite.flip_h = (target.global_position.x as float) < global_position.x
	sprite.position.y = sin(_t * 2.6) * 3.0
	bubble.position.y = -78 + sin(_t * 6.0) * 2.0
