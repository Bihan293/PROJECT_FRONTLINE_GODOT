extends Node3D
class_name BloodEffect

static func spawn(parent: Node, pos: Vector3, normal: Vector3, is_headshot: bool = false) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var tree = parent.get_tree()
	if tree == null:
		return

	var effect = Node3D.new()
	parent.add_child(effect)
	effect.global_position = pos

	var count = 30 if is_headshot else 16
	var speed = 7.0 if is_headshot else 4.5

	# CPUParticles3D runs universally on mobile OpenGL ES 3.0 / gl_compatibility
	var particles = CPUParticles3D.new()
	effect.add_child(particles)

	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = count
	particles.lifetime = 0.75

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.65, 0.02, 0.02, 1.0)
	particles.material_override = mat

	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 0.08)
	particles.draw_pass_1 = mesh

	particles.direction = normal.normalized() + Vector3(0, 0.4, 0)
	particles.spread = 45.0
	particles.initial_velocity_min = speed * 0.7
	particles.initial_velocity_max = speed * 1.3
	particles.gravity = Vector3(0, -14.0, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4

	particles.emitting = true

	# Ground blood puddle decal
	var ground_y = 0.03
	var decal_pos = Vector3(pos.x, ground_y, pos.z)
	var decal = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = randf_range(0.25, 0.55) if not is_headshot else randf_range(0.5, 0.9)
	cylinder.bottom_radius = cylinder.top_radius
	cylinder.height = 0.01

	var decal_mat = StandardMaterial3D.new()
	decal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	decal_mat.albedo_color = Color(0.42, 0.02, 0.02, 0.9)
	decal_mat.roughness = 0.3
	decal.mesh = cylinder
	decal.material_override = decal_mat
	parent.add_child(decal)
	decal.global_position = decal_pos

	# Auto cleanup
	tree.create_timer(1.2).timeout.connect(func():
		if is_instance_valid(effect):
			effect.queue_free()
	)

	tree.create_timer(25.0).timeout.connect(func():
		if is_instance_valid(decal):
			var tween = decal.create_tween()
			if tween:
				tween.tween_property(decal_mat, "albedo_color:a", 0.0, 3.0)
				tween.tween_callback(func():
					if is_instance_valid(decal):
						decal.queue_free()
				)
			else:
				decal.queue_free()
	)
