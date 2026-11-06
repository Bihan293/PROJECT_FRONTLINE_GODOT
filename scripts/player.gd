extends CharacterBody3D
class_name Player

signal health_changed(new_health, bleeding, bandages)
signal ammo_changed(ammo, reserve, weapon_name)
signal hit_enemy(is_headshot, is_kill)
signal player_died()

@export var move_speed: float = 6.8
@export var sprint_speed: float = 9.8
@export var jump_velocity: float = 5.2
@export var mouse_sensitivity: float = 0.0025

var health: float = 100.0
var bleeding: bool = false
var bandages: int = 3
var is_dead: bool = false
var is_crouched: bool = false
var is_aiming: bool = false

# Current weapon
var current_weapon_key: String = "ak"
var weapon_states = {}
var can_fire: bool = true
var is_reloading: bool = false
var recoil_amount: float = 0.0
var move_input: Vector2 = Vector2.ZERO # from joystick or keys

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var raycast: RayCast3D = $Head/Camera3D/RayCast3D
@onready var weapon_holder: Node3D = $Head/Camera3D/WeaponHolder
@onready var gun_mesh: MeshInstance3D = $Head/Camera3D/WeaponHolder/GunMesh

func _ready() -> void:
	add_to_group("player")
	# Initialize ammo states for all weapons
	for key in WeaponsData.WEAPONS.keys():
		var w = WeaponsData.WEAPONS[key]
		weapon_states[key] = {
			"ammo": w.mag,
			"reserve": w.reserve
		}
	equip_weapon("ak")
	emit_health()

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return

	# Mouse look for desktop testing
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		apply_look(event.relative * mouse_sensitivity)

func apply_look(relative: Vector2) -> void:
	rotate_y(-relative.x)
	head.rotation.x = clamp(head.rotation.x - relative.y, -deg_to_rad(85), deg_to_rad(85))

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= 14.0 * delta

	# Decay weapon recoil
	recoil_amount = max(0.0, recoil_amount - delta * 4.5)
	weapon_holder.position.z = -0.45 + recoil_amount * 0.12
	weapon_holder.rotation.x = recoil_amount * 0.18

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Movement calculation (keyboard + virtual joystick)
	var input_dir = Vector2.ZERO
	if move_input != Vector2.ZERO:
		input_dir = move_input
	else:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var current_speed = (move_speed * 0.5) if is_crouched else move_speed

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0, current_speed * delta * 8.0)

	move_and_slide()

	# Continuous auto-firing if fire held
	if Input.is_action_pressed("fire") and WeaponsData.WEAPONS[current_weapon_key].automatic:
		fire()

	# Aiming zoom
	if Input.is_action_pressed("aim"):
		set_aim(true)
	else:
		set_aim(false)

	# Bleeding damage over time
	if bleeding and health > 1.0:
		health -= 1.2 * delta
		emit_health()

func set_joystick_input(vec: Vector2) -> void:
	move_input = vec

func set_aim(aim: bool) -> void:
	is_aiming = aim
	var target_fov = 42.0 if is_aiming else 75.0
	camera.fov = lerp(camera.fov, target_fov, 0.2)

func fire() -> void:
	if not can_fire or is_reloading:
		return

	var w = WeaponsData.WEAPONS[current_weapon_key]
	var s = weapon_states[current_weapon_key]

	if s.ammo <= 0:
		reload()
		return

	s.ammo -= 1
	can_fire = false
	recoil_amount = w.recoil
	emit_ammo()

	# Raycast hitscan check
	for i in range(w.pellets):
		var spread_vec = Vector3(
			randf_range(-w.spread, w.spread),
			randf_range(-w.spread, w.spread),
			-1.0
		).normalized()

		var from = camera.global_position
		var to = from + camera.global_transform.basis * spread_vec * w.range

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [self]
		var result = space_state.intersect_ray(query)

		if result:
			var collider = result.collider
			var hit_pos = result.position
			var hit_dir = (to - from).normalized()

			# Check if hit a soldier bot
			if collider is DummySoldier:
				var is_head = (hit_pos.y - collider.global_position.y) > 1.6
				collider.take_damage(w.damage, hit_dir, hit_pos, is_head)
				hit_enemy.emit(is_head, collider.health <= 0.0)

	# Fire rate cooldown timer
	get_tree().create_timer(w.fire_rate).timeout.connect(func(): can_fire = true)

func reload() -> void:
	if is_reloading:
		return
	var w = WeaponsData.WEAPONS[current_weapon_key]
	var s = weapon_states[current_weapon_key]

	if s.ammo >= w.mag or s.reserve <= 0:
		return

	is_reloading = true
	get_tree().create_timer(1.8).timeout.connect(func():
		var needed = w.mag - s.ammo
		var transfer = min(needed, s.reserve)
		s.ammo += transfer
		s.reserve -= transfer
		is_reloading = false
		emit_ammo()
	)

func equip_weapon(key: String) -> void:
	if not WeaponsData.WEAPONS.has(key):
		return
	current_weapon_key = key
	is_reloading = false
	emit_ammo()

func use_bandage() -> bool:
	if bandages <= 0 or (health >= 100.0 and not bleeding):
		return false
	bandages -= 1
	bleeding = false
	health = min(100.0, health + 20.0)
	emit_health()
	return true

func take_damage(amount: float, impulse: Vector3, hit_point: Vector3, _is_headshot: bool = false) -> void:
	if is_dead:
		return
	health -= amount
	if health < 70.0:
		bleeding = true
	emit_health()

	if health <= 0.0:
		health = 0.0
		is_dead = true
		player_died.emit()

func emit_health() -> void:
	health_changed.emit(ceil(health), bleeding, bandages)

func emit_ammo() -> void:
	var w = WeaponsData.WEAPONS[current_weapon_key]
	var s = weapon_states[current_weapon_key]
	ammo_changed.emit(s.ammo, s.reserve, w.name)
