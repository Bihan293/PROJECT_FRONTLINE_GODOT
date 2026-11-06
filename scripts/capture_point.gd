extends Area3D
class_name CapturePoint

signal point_owner_changed(point_id: String, new_owner: int)

@export var point_id: String = "A" # A, B, or C
@export var capture_radius: float = 9.0
@export var capture_rate: float = 0.25 # seconds to capture

var owner_team: int = 0 # 0: Neutral, 1: Blue, 2: Red
var progress: float = 0.0 # -1.0 (Red) to +1.0 (Blue)
var blue_count: int = 0
var red_count: int = 0
var is_contested: bool = false

@onready var flag_mesh: MeshInstance3D = $Flag
@onready var ring_mesh: MeshInstance3D = $Ring
@onready var label: Label3D = $Label3D

const COLOR_NEUTRAL = Color(0.65, 0.65, 0.65)
const COLOR_BLUE = Color(0.2, 0.55, 0.85)
const COLOR_RED = Color(0.85, 0.25, 0.2)
const COLOR_CONTESTED = Color(0.95, 0.8, 0.2)

func _ready() -> void:
	if label:
		label.text = point_id
	update_visuals()

func _physics_process(delta: float) -> void:
	count_occupants()
	is_contested = (blue_count > 0 and red_count > 0)

	if not is_contested and (blue_count > 0 or red_count > 0):
		var direction = 1.0 if blue_count > red_count else -1.0
		progress += direction * delta * capture_rate
		progress = clamp(progress, -1.0, 1.0)

		var prev_owner = owner_team
		if progress >= 1.0:
			owner_team = 1
		elif progress <= -1.0:
			owner_team = 2

		if prev_owner != owner_team:
			point_owner_changed.emit(point_id, owner_team)

	update_visuals()

func count_occupants() -> void:
	blue_count = 0
	red_count = 0
	for body in get_overlapping_bodies():
		if body is DummySoldier and not body.is_dead:
			if body.team == 1:
				blue_count += 1
			elif body.team == 2:
				red_count += 1
		elif body is Player and not body.is_dead:
			blue_count += 1

func update_visuals() -> void:
	var color = COLOR_NEUTRAL
	if is_contested:
		color = COLOR_CONTESTED
	elif owner_team == 1:
		color = COLOR_BLUE
	elif owner_team == 2:
		color = COLOR_RED

	if flag_mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		flag_mesh.material_override = mat

	if ring_mesh:
		var r_mat = StandardMaterial3D.new()
		r_mat.albedo_color = Color(color.r, color.g, color.b, 0.75)
		r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mesh.material_override = r_mat
