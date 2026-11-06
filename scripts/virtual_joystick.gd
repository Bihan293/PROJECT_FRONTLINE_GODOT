extends Control
class_name VirtualJoystick

signal joystick_moved(output: Vector2)

@export var max_distance: float = 60.0
@export var deadzone: float = 10.0

var touch_id: int = -1
var touch_start: Vector2 = Vector2.ZERO
var current_pos: Vector2 = Vector2.ZERO
var output: Vector2 = Vector2.ZERO

@onready var base: Panel = $Base
@onready var handle: Panel = $Base/Handle

func _ready() -> void:
	reset()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			# Activate only on left 40% of screen and lower 70% of screen height
			var vp_size = get_viewport_rect().size
			if event.position.x < vp_size.x * 0.40 and event.position.y > vp_size.y * 0.30 and touch_id == -1:
				touch_id = event.index
				global_position = event.position - base.size / 2.0
				touch_start = event.position
				current_pos = event.position
				visible = true
				update_joystick(event.position)
		elif event.index == touch_id:
			reset()

	elif event is InputEventScreenDrag and event.index == touch_id:
		current_pos = event.position
		update_joystick(event.position)

func update_joystick(pos: Vector2) -> void:
	var diff = pos - touch_start
	var dist = diff.length()

	if dist > max_distance:
		diff = diff.normalized() * max_distance

	handle.position = (base.size / 2.0) - (handle.size / 2.0) + diff

	if dist < deadzone:
		output = Vector2.ZERO
	else:
		output = diff / max_distance

	joystick_moved.emit(output)

func reset() -> void:
	touch_id = -1
	output = Vector2.ZERO
	if handle and base:
		handle.position = (base.size / 2.0) - (handle.size / 2.0)
	joystick_moved.emit(Vector2.ZERO)
