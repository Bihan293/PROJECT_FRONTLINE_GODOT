extends RigidBody3D
class_name SoldierRagdoll

@export var is_headshot: bool = false
@export var impulse_vector: Vector3 = Vector3.ZERO

@onready var helmet_node: Node3D = $Visuals/Torso/Neck/Helmet
@onready var left_hip: Node3D = $Visuals/Pelvis/LeftHip
@onready var right_hip: Node3D = $Visuals/Pelvis/RightHip
@onready var left_knee: Node3D = $Visuals/Pelvis/LeftHip/LeftKnee
@onready var right_knee: Node3D = $Visuals/Pelvis/RightHip/RightKnee
@onready var torso: Node3D = $Visuals/Torso
@onready var neck: Node3D = $Visuals/Torso/Neck
@onready var left_shoulder: Node3D = $Visuals/Torso/LeftShoulder
@onready var right_shoulder: Node3D = $Visuals/Torso/RightShoulder

var settled: bool = false
var time_settled: float = 0.0

func _ready() -> void:
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 3

	# Apply initial impact force and angular spin
	if impulse_vector.length_squared() > 0.01:
		apply_central_impulse(impulse_vector)
		var spin = Vector3(
			randf_range(-4.0, 4.0),
			randf_range(-3.0, 3.0),
			randf_range(-4.0, 4.0)
		)
		apply_torque_impulse(spin)

	# If killed by a headshot, detach the helmet so it tumbles separately
	if is_headshot and helmet_node != null:
		var helm_pos = helmet_node.global_position
		helmet_node.get_parent().remove_child(helmet_node)
		get_parent().add_child(helmet_node)
		helmet_node.global_position = helm_pos

		var helm_body = RigidBody3D.new()
		get_parent().add_child(helm_body)
		helm_body.global_position = helm_pos

		var col = CollisionShape3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = 0.22
		col.shape = sphere
		helm_body.add_child(col)

		helmet_node.get_parent().remove_child(helmet_node)
		helm_body.add_child(helmet_node)
		helmet_node.position = Vector3.ZERO

		helm_body.apply_central_impulse(impulse_vector * 0.7 + Vector3(0, 3.5, 0))
		helm_body.apply_torque_impulse(Vector3(randf_range(5.0, 10.0), randf_range(5.0, 10.0), 0))

		# Despawn detached helmet after 20 seconds
		get_tree().create_timer(20.0).timeout.connect(func(): helm_body.queue_free())

	# Initial limb flopping
	torso.rotation.x = randf_range(-0.6, -1.0)
	left_hip.rotation.x = randf_range(0.3, 0.8)
	right_hip.rotation.x = randf_range(-0.4, -0.9)
	left_shoulder.rotation.z = -1.1
	right_shoulder.rotation.z = 1.1

func _physics_process(delta: float) -> void:
	if settled:
		return

	# Relax and flop limbs towards ground position as body falls
	if linear_velocity.length_squared() < 0.15 and angular_velocity.length_squared() < 0.2:
		time_settled += delta
		if time_settled > 0.8:
			settled = true
			freeze = true # Put physics to sleep to maximize mobile FPS
	else:
		time_settled = 0.0

		# Slowly drape limbs onto the terrain
		torso.rotation.x = lerp_angle(torso.rotation.x, -0.85, delta * 3.0)
		neck.rotation.x = lerp_angle(neck.rotation.x, -0.6, delta * 3.0)
		left_knee.rotation.x = lerp_angle(left_knee.rotation.x, 0.8, delta * 2.5)
		right_knee.rotation.x = lerp_angle(right_knee.rotation.x, 0.5, delta * 2.5)
