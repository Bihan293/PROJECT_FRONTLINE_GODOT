extends CharacterBody3D
class_name DummySoldier

signal soldier_died(soldier, killer_team)

@export var team: int = 2 # 1: Blue (Player's allies), 2: Red (Enemies)
@export var max_health: float = 100.0
@export var move_speed: float = 4.4
@export var difficulty: float = 1.0

var health: float = 100.0
var target: Node3D = null
var current_target_point: Vector3 = Vector3.ZERO
var next_think_time: float = 0.0
var next_fire_time: float = 0.0
var walk_phase: float = 0.0
var strafe_dir: float = 1.0
var next_strafe_change: float = 0.0
var flinch_amount: float = 0.0
var is_dead: bool = false

# Articulated skeleton parts
@onready var visuals: Node3D = $Visuals
@onready var pelvis: Node3D = $Visuals/Pelvis
@onready var torso: Node3D = $Visuals/Torso
@onready var neck: Node3D = $Visuals/Torso/Neck
@onready var helmet: MeshInstance3D = $Visuals/Torso/Neck/Helmet
@onready var left_shoulder: Node3D = $Visuals/Torso/LeftShoulder
@onready var right_shoulder: Node3D = $Visuals/Torso/RightShoulder
@onready var left_hip: Node3D = $Visuals/Pelvis/LeftHip
@onready var right_hip: Node3D = $Visuals/Pelvis/RightHip
@onready var left_knee: Node3D = $Visuals/Pelvis/LeftHip/LeftKnee
@onready var right_knee: Node3D = $Visuals/Pelvis/RightHip/RightKnee
@onready var weapon: Node3D = $Visuals/Torso/RightShoulder/Weapon
@onready var muzzle: Node3D = $Visuals/Torso/RightShoulder/Weapon/Muzzle

const RAGDOLL_SCENE = preload("res://scenes/ragdoll.tscn")

func _ready() -> void:
	add_to_group("soldiers")
	health = max_health
	walk_phase = randf() * TAU
	next_fire_time = randf_range(0.4, 1.2)
	strafe_dir = 1.0 if randf() > 0.5 else -1.0
	setup_team_materials()
	pick_strategic_point()

func setup_team_materials() -> void:
	var vest_mesh = $Visuals/Torso/Vest
	if vest_mesh and vest_mesh is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.4, 0.65) if team == 1 else Color(0.68, 0.22, 0.18)
		vest_mesh.material_override = mat

	if helmet:
		var h_mat = StandardMaterial3D.new()
		h_mat.albedo_color = Color(0.16, 0.3, 0.48) if team == 1 else Color(0.52, 0.16, 0.14)
		helmet.material_override = h_mat

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Decay flinch
	flinch_amount = max(0.0, flinch_amount - delta * 5.0)

	# Gravity
	if not is_on_floor():
		velocity.y -= 14.0 * delta

	# Periodic thinking cycle (target selection, tactical decisions)
	next_think_time -= delta
	if next_think_time <= 0.0:
		next_think_time = randf_range(0.25, 0.5)
		find_best_target()
		if target == null:
			pick_strategic_point()

	# Strafe direction timer
	next_strafe_change -= delta
	if next_strafe_change <= 0.0:
		next_strafe_change = randf_range(1.5, 3.5)
		strafe_dir = -strafe_dir

	var moving = false

	# === COMBAT ENGAGEMENT ===
	if target != null and is_instance_valid(target) and not is_target_dead(target):
		var target_pos = target.global_position
		var diff = target_pos - global_position
		var dist = Vector2(diff.x, diff.z).length()

		# Rotate body smoothly to face target
		var target_angle = atan2(-diff.x, -diff.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * 9.0)

		# Pitch torso to aim at enemy chest/head
		var pitch = clamp(-atan2(diff.y, dist), -0.65, 0.65)
		torso.rotation.x = pitch - flinch_amount * 0.35

		# Check if line of sight is clear (not blocked by walls/buildings)
		var has_los = has_line_of_sight(target_pos + Vector3(0, 1.2, 0))

		if has_los:
			# Combat movement: maintain optimal distance (10-22m) and strafe
			var desired_dir = Vector3.ZERO
			if dist > 20.0:
				desired_dir += Vector3(diff.x, 0, diff.z).normalized() * 0.75
			elif dist < 9.0:
				desired_dir -= Vector3(diff.x, 0, diff.z).normalized() * 0.75

			# Add strafing component
			var right_vec = transform.basis.x.normalized()
			desired_dir += right_vec * (strafe_dir * 0.6)

			# Apply obstacle avoidance
			desired_dir = steer_around_obstacles(desired_dir)

			if desired_dir.length_squared() > 0.01:
				var move_v = desired_dir.normalized() * (move_speed * 0.85)
				velocity.x = move_v.x
				velocity.z = move_v.z
				moving = true
			else:
				velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 6.0)
				velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 6.0)

			# Weapon firing
			next_fire_time -= delta
			if next_fire_time <= 0.0 and dist < 55.0:
				var fire_interval = (0.75 / difficulty) + randf_range(0.1, 0.4)
				next_fire_time = fire_interval
				fire_at_target(target)
		else:
			# Target hidden behind cover: move towards last known position or steer around cover
			var forward_dir = Vector3(diff.x, 0, diff.z).normalized()
			forward_dir = steer_around_obstacles(forward_dir)
			velocity.x = forward_dir.x * move_speed
			velocity.z = forward_dir.z * move_speed
			moving = true

	# === STRATEGIC ADVANCE / CAPTURE POINT PATROL ===
	else:
		target = null
		var diff = current_target_point - global_position
		var dist = Vector2(diff.x, diff.z).length()

		if dist > 3.5:
			var dir = Vector3(diff.x, 0, diff.z).normalized()
			dir = steer_around_obstacles(dir)
			velocity.x = dir.x * (move_speed * 0.85)
			velocity.z = dir.z * (move_speed * 0.85)
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), delta * 6.0)
			moving = true
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
			velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
			# Small patrol rotation around the point
			rotation.y += delta * 0.8

	move_and_slide()

	# Procedural Dummy War animation
	animate_limbs(delta, moving, move_speed)

func steer_around_obstacles(desired_dir: Vector3) -> Vector3:
	if desired_dir.length_squared() < 0.01:
		return desired_dir

	var space_state = get_world_3d().direct_space_state
	var start_pos = global_position + Vector3(0, 0.8, 0)
	var forward = desired_dir.normalized()

	# Central ray
	var query = PhysicsRayQueryParameters3D.create(start_pos, start_pos + forward * 3.2, 1) # layer 1: world
	query.exclude = [self]
	var hit = space_state.intersect_ray(query)

	if hit:
		# Test left and right whiskers
		var left_whisker = forward.rotated(Vector3.UP, deg_to_rad(45))
		var right_whisker = forward.rotated(Vector3.UP, deg_to_rad(-45))

		var q_left = PhysicsRayQueryParameters3D.create(start_pos, start_pos + left_whisker * 3.0, 1)
		q_left.exclude = [self]
		var hit_l = space_state.intersect_ray(q_left)

		var q_right = PhysicsRayQueryParameters3D.create(start_pos, start_pos + right_whisker * 3.0, 1)
		q_right.exclude = [self]
		var hit_r = space_state.intersect_ray(q_right)

		if not hit_l:
			return left_whisker
		elif not hit_r:
			return right_whisker
		else:
			# Both blocked, reflect off normal
			return (forward - hit.normal * 2.0).normalized()

	return desired_dir

func has_line_of_sight(target_world_pos: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state
	var from = global_position + Vector3(0, 1.4, 0)
	var to = target_world_pos

	var query = PhysicsRayQueryParameters3D.create(from, to, 1) # layer 1 = world geometry / buildings
	query.exclude = [self]
	var hit = space_state.intersect_ray(query)

	# If no world obstacle hit, line of sight is clear
	return hit.is_empty()

func find_best_target() -> void:
	var best_score = -999.0
	var candidate: Node3D = null

	# Check opposing soldiers
	var soldiers = get_tree().get_nodes_in_group("soldiers")
	for s in soldiers:
		if s == self or not is_instance_valid(s):
			continue
		if s is DummySoldier and s.team != self.team and not s.is_dead:
			var d = global_position.distance_to(s.global_position)
			if d < 65.0:
				var has_los = has_line_of_sight(s.global_position + Vector3(0, 1.2, 0))
				var score = (65.0 - d) + (40.0 if has_los else 0.0)
				if score > best_score:
					best_score = score
					candidate = s

	# Check player if on enemy team (Red)
	if team == 2:
		var players = get_tree().get_nodes_in_group("player")
		for p in players:
			if is_instance_valid(p) and not p.is_dead:
				var d = global_position.distance_to(p.global_position)
				if d < 65.0:
					var has_los = has_line_of_sight(p.global_position + Vector3(0, 1.2, 0))
					var score = (65.0 - d) * 1.2 + (45.0 if has_los else 0.0)
					if score > best_score:
						best_score = score
						candidate = p

	target = candidate

func pick_strategic_point() -> void:
	# Capture points: A (0, 0, -55), B (0, 0, 0), C (0, 0, 55)
	# Red advances towards B and C; Blue advances towards B and A
	var points = [Vector3(0, 0, 0)] # Point B is key
	if team == 1:
		points.append(Vector3(randf_range(-15, 15), 0, -55)) # Point A
	else:
		points.append(Vector3(randf_range(-15, 15), 0, 55))  # Point C

	# Also add flank paths
	var chosen = points.pick_random()
	var offset = Vector3(randf_range(-8.0, 8.0), 0, randf_range(-8.0, 8.0))
	current_target_point = chosen + offset

func is_target_dead(tgt: Node3D) -> bool:
	if tgt is DummySoldier:
		return tgt.is_dead
	if tgt is Player:
		return tgt.is_dead
	return false

func fire_at_target(tgt: Node3D) -> void:
	var hit_chance = clamp(0.5 + 0.3 * (difficulty - 1.0), 0.3, 0.85)
	var target_center = tgt.global_position + Vector3(0, 1.2, 0)
	var my_muzzle_pos = muzzle.global_position if muzzle else (global_position + Vector3(0, 1.3, 0))
	var dir = (target_center - my_muzzle_pos).normalized()

	# Recoil animation
	torso.rotation.x -= 0.12

	# Visual muzzle flash
	spawn_muzzle_flash()

	# Bullet tracer effect
	var hit_pos = target_center + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
	spawn_bullet_tracer(my_muzzle_pos, hit_pos)

	# Hit determination
	if randf() < hit_chance:
		var dmg = randf_range(10.0, 18.0) * difficulty
		var is_head = randf() < 0.22 # 22% headshot chance
		if tgt.has_method("take_damage"):
			tgt.take_damage(dmg, dir, hit_pos, is_head)

func spawn_muzzle_flash() -> void:
	if muzzle == null:
		return
	var flash = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	flash.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.2, 1.0)
	flash.material_override = mat

	muzzle.add_child(flash)
	get_tree().create_timer(0.06).timeout.connect(func():
		if is_instance_valid(flash):
			flash.queue_free()
	)

func spawn_bullet_tracer(from: Vector3, to: Vector3) -> void:
	var parent_node = get_parent()
	if parent_node == null:
		return

	var tracer = MeshInstance3D.new()
	var length = from.distance_to(to)
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.02
	cylinder.bottom_radius = 0.02
	cylinder.height = length
	tracer.mesh = cylinder

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.4, 0.8)
	tracer.material_override = mat

	parent_node.add_child(tracer)
	tracer.global_position = (from + to) / 2.0
	tracer.look_at(to, Vector3.UP)
	tracer.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))

	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(tracer):
			tracer.queue_free()
	)

func animate_limbs(delta: float, moving: bool, speed: float) -> void:
	if moving:
		walk_phase += speed * delta * 4.6

	var sin_w = sin(walk_phase) if moving else 0.0
	var cos_w = cos(walk_phase) if moving else 0.0

	# Swing legs with knee bending
	left_hip.rotation.x = sin_w * 0.65
	left_knee.rotation.x = max(0.0, -sin_w * 0.85)
	right_hip.rotation.x = -sin_w * 0.65
	right_knee.rotation.x = max(0.0, sin_w * 0.85)

	# Pelvis bounce
	pelvis.position.y = 0.94 + (abs(cos_w) * 0.04 if moving else 0.0)

	# Weapon holding stance (fixed Vector3 assignment, no invalid .set() call!)
	right_shoulder.rotation = Vector3(-0.75, -0.2, 0.12)
	left_shoulder.rotation = Vector3(-0.65, 0.4, -0.3)

func take_damage(amount: float, impulse_dir: Vector3, hit_point: Vector3, is_headshot: bool = false) -> void:
	if is_dead:
		return

	var effective_damage = amount * (2.5 if is_headshot else 1.0)
	health -= effective_damage
	flinch_amount = 1.0

	# Spawn directional blood spray and ground puddle
	BloodEffect.spawn(get_parent(), hit_point, impulse_dir, is_headshot)

	if health <= 0.0:
		die(impulse_dir * (effective_damage * 0.2), is_headshot)

func die(impulse: Vector3, is_headshot: bool = false) -> void:
	if is_dead:
		return
	is_dead = true
	soldier_died.emit(self, team)

	# Spawn active physical ragdoll in place of soldier
	var ragdoll = RAGDOLL_SCENE.instantiate()
	ragdoll.global_position = global_position
	ragdoll.rotation = rotation
	ragdoll.team = team
	ragdoll.is_headshot = is_headshot
	ragdoll.impulse_vector = impulse
	get_parent().add_child(ragdoll)

	# Remove AI bot
	queue_free()
