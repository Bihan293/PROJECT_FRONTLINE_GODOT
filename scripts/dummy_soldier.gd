extends CharacterBody3D
class_name DummySoldier

signal soldier_died(soldier, killer_team)

@export var team: int = 2 # 1: Blue (Player's team), 2: Red (Enemy)
@export var max_health: float = 100.0
@export var move_speed: float = 4.2
@export var difficulty: float = 1.0

var health: float = 100.0
var target: Node3D = null
var next_think_time: float = 0.0
var next_fire_time: float = 0.0
var walk_phase: float = 0.0
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
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var raycast: RayCast3D = $RayCast3D

const RAGDOLL_SCENE = preload("res://scenes/ragdoll.tscn")

func _ready() -> void:
	health = max_health
	walk_phase = randf() * TAU
	next_fire_time = randf_range(0.5, 1.5)
	setup_team_materials()

func setup_team_materials() -> void:
	var vest_mesh = $Visuals/Torso/Vest
	if vest_mesh and vest_mesh is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.35, 0.52) if team == 1 else Color(0.52, 0.22, 0.18)
		vest_mesh.material_override = mat

	if helmet:
		var h_mat = StandardMaterial3D.new()
		h_mat.albedo_color = Color(0.15, 0.28, 0.4) if team == 1 else Color(0.42, 0.16, 0.14)
		helmet.material_override = h_mat

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Decay flinch
	flinch_amount = max(0.0, flinch_amount - delta * 5.0)

	# Gravity
	if not is_on_floor():
		velocity.y -= 14.0 * delta

	# AI Decision Cycle
	next_think_time -= delta
	if next_think_time <= 0.0:
		next_think_time = randf_range(0.3, 0.6)
		find_best_target()

	# Combat & Movement towards target
	var moving = false
	if target != null and is_instance_valid(target):
		var target_pos = target.global_position
		var diff = target_pos - global_position
		var dist = Vector2(diff.x, diff.z).length()

		# Rotate body to face target
		var angle = atan2(-diff.x, -diff.z)
		rotation.y = lerp_angle(rotation.y, angle, delta * 8.0)

		# Pitch torso to aim at enemy height
		var pitch = clamp(-atan2(diff.y, dist), -0.6, 0.6)
		torso.rotation.x = pitch - flinch_amount * 0.4

		# Move closer if beyond effective firing range
		if dist > 14.0:
			var dir = Vector3(diff.x, 0, diff.z).normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			moving = true
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
			velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)

		# Fire weapon
		next_fire_time -= delta
		if next_fire_time <= 0.0 and dist < 50.0:
			next_fire_time = (0.85 / difficulty) + randf_range(0.1, 0.5)
			fire_at_target(target)
	else:
		# Idle / rally towards center
		var rally = Vector3(0, 0, -20 if team == 1 else 20)
		var diff = rally - global_position
		if diff.length() > 5.0:
			var dir = diff.normalized()
			velocity.x = dir.x * (move_speed * 0.7)
			velocity.z = dir.z * (move_speed * 0.7)
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), delta * 5.0)
			moving = true
		else:
			velocity.x = 0.0
			velocity.z = 0.0

	move_and_slide()

	# Procedural Dummy War leg and arm animations
	animate_limbs(delta, moving, move_speed)

func animate_limbs(delta: float, moving: bool, speed: float) -> void:
	if moving:
		walk_phase += speed * delta * 4.5

	var sin_w = sin(walk_phase) if moving else 0.0
	var cos_w = cos(walk_phase) if moving else 0.0

	# Swing legs with knee bending
	left_hip.rotation.x = sin_w * 0.65
	left_knee.rotation.x = max(0.0, -sin_w * 0.85)
	right_hip.rotation.x = -sin_w * 0.65
	right_knee.rotation.x = max(0.0, sin_w * 0.85)

	# Pelvis bounce
	pelvis.position.y = 0.94 + (abs(cos_w) * 0.04 if moving else 0.0)

	# Weapon holding stance (right arm forward, left arm gripping fore-end)
	right_shoulder.rotation.set(-0.75, -0.2, 0.12)
	left_shoulder.rotation.set(-0.65, 0.4, -0.3)

func find_best_target() -> void:
	var soldiers = get_tree().get_nodes_in_group("soldiers")
	var best_dist = 60.0
	var candidate: Node3D = null

	for s in soldiers:
		if s == self or not is_instance_valid(s):
			continue
		if s is DummySoldier and s.team != self.team and not s.is_dead:
			var d = global_position.distance_to(s.global_position)
			if d < best_dist:
				best_dist = d
				candidate = s

	# Check for player if enemy
	if team == 2:
		var players = get_tree().get_nodes_in_group("player")
		for p in players:
			if is_instance_valid(p) and not p.is_dead:
				var d = global_position.distance_to(p.global_position)
				if d < best_dist * 1.15 and d < 55.0:
					candidate = p

	target = candidate

func fire_at_target(tgt: Node3D) -> void:
	var hit_chance = 0.55 * difficulty
	var hit_pos = tgt.global_position + Vector3(0, 1.2, 0)
	var dir = (hit_pos - global_position).normalized()

	# Recoil kick
	torso.rotation.x -= 0.15

	if randf() < hit_chance:
		var dmg = randf_range(8.0, 16.0)
		if tgt.has_method("take_damage"):
			tgt.take_damage(dmg, dir, hit_pos, false)

func take_damage(amount: float, impulse_dir: Vector3, hit_point: Vector3, is_headshot: bool = false) -> void:
	if is_dead:
		return

	var effective_damage = amount * (2.5 if is_headshot else 1.0)
	health -= effective_damage
	flinch_amount = 1.0

	# Spawn directional blood spray and ground puddle
	BloodEffect.spawn(get_parent(), hit_point, impulse_dir, is_headshot)

	if health <= 0.0:
		die(impulse_dir * (effective_damage * 0.18), is_headshot)

func die(impulse: Vector3, is_headshot: bool = false) -> void:
	if is_dead:
		return
	is_dead = true
	soldier_died.emit(self, team)

	# Spawn active physical ragdoll in place of soldier
	var ragdoll = RAGDOLL_SCENE.instantiate()
	ragdoll.global_position = global_position
	ragdoll.rotation = rotation
	ragdoll.is_headshot = is_headshot
	ragdoll.impulse_vector = impulse
	get_parent().add_child(ragdoll)

	# Remove AI bot
	queue_free()
