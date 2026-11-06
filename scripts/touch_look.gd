extends Control
class_name TouchLookArea

signal look_input(relative: Vector2)

@export var sensitivity: float = 0.0035

var touch_id: int = -1

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var vp_size = get_viewport_rect().size
			# Touch started on the right half of screen
			if event.position.x > vp_size.x * 0.35 and touch_id == -1:
				touch_id = event.index
		elif event.index == touch_id:
			touch_id = -1

	elif event is InputEventScreenDrag and event.index == touch_id:
		look_input.emit(event.relative * sensitivity)
