extends Node2D
## Something the player can interact with (E). The dream scene polls all
## nodes in group "interactable" and runs `action` on the nearest one.

var prompt := "调查"
var radius := 34.0
var action: Callable
var condition: Callable        # optional: returns bool, if false it can't be used
var once := false
var used := false


func _ready() -> void:
	add_to_group("interactable")


func available() -> bool:
	if once and used:
		return false
	if not is_visible_in_tree():
		return false
	if condition.is_valid() and not condition.call():
		return false
	return true


func trigger() -> void:
	used = true
	if action.is_valid():
		action.call()
