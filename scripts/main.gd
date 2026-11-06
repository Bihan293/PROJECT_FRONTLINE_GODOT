extends Node3D

@export var target_score: float = 300.0
@export var score_per_second: float = 1.5

var blue_score: float = 0.0
var red_score: float = 0.0
var match_ended: bool = false
var team_size: int = 6
var bot_difficulty: float = 1.0

@onready var player: Player = $Player
@onready var capture_points_parent: Node3D = $CapturePoints
@onready var soldiers_parent: Node3D = $Soldiers

# UI Elements
@onready var start_screen: Control = $UI/StartScreen
@onready var hud: Control = $UI/HUD
@onready var pause_screen: Control = $UI/PauseScreen
@onready var end_screen: Control = $UI/EndScreen

@onready var blue_score_label: Label = $UI/HUD/TopBar/BlueScore
@onready var red_score_label: Label = $UI/HUD/TopBar/RedScore
@onready var health_label: Label = $UI/HUD/BottomLeft/HealthLabel
@onready var health_bar: ProgressBar = $UI/HUD/BottomLeft/HealthBar
@onready var bandage_label: Label = $UI/HUD/BottomRight/BandageBtn/BandageCount
@onready var weapon_name_label: Label = $UI/HUD/BottomCenter/WeaponName
@onready var ammo_label: Label = $UI/HUD/BottomCenter/AmmoLabel
@onready var point_a_indicator: Label = $UI/HUD/TopBar/Points/PointA
@onready var point_b_indicator: Label = $UI/HUD/TopBar/Points/PointB
@onready var point_c_indicator: Label = $UI/HUD/TopBar/Points/PointC
@onready var hitmarker: TextureRect = $UI/HUD/Hitmarker
@onready var virtual_joystick: VirtualJoystick = $UI/HUD/VirtualJoystick
@onready var touch_look: TouchLookArea = $UI/HUD/TouchLookArea

const SOLDIER_SCENE = preload("res://scenes/dummy_soldier.tscn")

func _ready() -> void:
	hud.visible = false
	pause_screen.visible = false
	end_screen.visible = false
	start_screen.visible = true

	connect_ui_buttons()
	setup_player_connections()

func connect_ui_buttons() -> void:
	# Start Screen
	$UI/StartScreen/Panel/StartBtn.pressed.connect(start_match)
	$UI/StartScreen/Panel/TeamSizeOption.item_selected.connect(func(idx):
		var val = $UI/StartScreen/Panel/TeamSizeOption.get_item_text(idx).to_int()
		team_size = val if val > 0 else 6
	)
	$UI/StartScreen/Panel/DifficultyOption.item_selected.connect(func(idx):
		match idx:
			0: bot_difficulty = 0.7
			1: bot_difficulty = 1.0
			2: bot_difficulty = 1.4
	)

	# Touch action buttons
	$UI/HUD/BottomRight/FireBtn.button_down.connect(func(): Input.action_press("fire"))
	$UI/HUD/BottomRight/FireBtn.button_up.connect(func(): Input.action_release("fire"))

	$UI/HUD/BottomRight/AimBtn.button_down.connect(func(): Input.action_press("aim"))
	$UI/HUD/BottomRight/AimBtn.button_up.connect(func(): Input.action_release("aim"))

	$UI/HUD/BottomRight/JumpBtn.pressed.connect(func(): Input.action_press("jump"))
	$UI/HUD/BottomRight/ReloadBtn.pressed.connect(func(): player.reload())
	$UI/HUD/BottomRight/BandageBtn.pressed.connect(func(): player.use_bandage())
	$UI/HUD/BottomRight/CrouchBtn.pressed.connect(func():
		player.is_crouched = not player.is_crouched
	)

	# Weapon slots
	$UI/HUD/BottomCenter/Slots/AK.pressed.connect(func(): player.equip_weapon("ak"))
	$UI/HUD/BottomCenter/Slots/Shotgun.pressed.connect(func(): player.equip_weapon("shotgun"))
	$UI/HUD/BottomCenter/Slots/Sniper.pressed.connect(func(): player.equip_weapon("sniper"))
	$UI/HUD/BottomCenter/Slots/Pistol.pressed.connect(func(): player.equip_weapon("pistol"))

	# Pause & Restart buttons
	$UI/PauseScreen/Panel/ResumeBtn.pressed.connect(resume_game)
	$UI/PauseScreen/Panel/RestartBtn.pressed.connect(restart_match)
	$UI/EndScreen/Panel/EndRestartBtn.pressed.connect(restart_match)

func setup_player_connections() -> void:
	if player:
		player.health_changed.connect(_on_player_health_changed)
		player.ammo_changed.connect(_on_player_ammo_changed)
		player.hit_enemy.connect(_on_player_hit_enemy)
		player.player_died.connect(_on_player_died)

	if virtual_joystick:
		virtual_joystick.joystick_moved.connect(func(vec):
			player.set_joystick_input(vec)
		)

	if touch_look:
		touch_look.look_input.connect(func(rel):
			player.apply_look(rel)
		)

func start_match() -> void:
	start_screen.visible = false
	hud.visible = true
	match_ended = false
	blue_score = 0.0
	red_score = 0.0

	# Spawn Soldier bots
	spawn_teams()

func spawn_teams() -> void:
	# Clear old soldiers if any
	for c in soldiers_parent.get_children():
		c.queue_free()

	# Blue bots (player's allies)
	for i in range(team_size - 1):
		var bot = SOLDIER_SCENE.instantiate()
		bot.team = 1
		bot.difficulty = bot_difficulty
		soldiers_parent.add_child(bot)
		bot.global_position = Vector3(randf_range(-30, 30), 1.0, 45.0 + randf_range(5, 20))

	# Red bots (enemies)
	for i in range(team_size):
		var bot = SOLDIER_SCENE.instantiate()
		bot.team = 2
		bot.difficulty = bot_difficulty
		soldiers_parent.add_child(bot)
		bot.global_position = Vector3(randf_range(-30, 30), 1.0, -45.0 - randf_range(5, 20))

func _physics_process(delta: float) -> void:
	if match_ended or start_screen.visible:
		return

	# Tally score based on captured points
	var blue_points = 0
	var red_points = 0

	for pt in capture_points_parent.get_children():
		if pt is CapturePoint:
			if pt.owner_team == 1:
				blue_points += 1
			elif pt.owner_team == 2:
				red_points += 1
			update_point_indicator(pt.point_id, pt.owner_team, pt.is_contested)

	blue_score += blue_points * delta * score_per_second
	red_score += red_points * delta * score_per_second

	blue_score_label.text = str(floor(blue_score))
	red_score_label.text = str(floor(red_score))

	# Win / Loss condition
	if blue_score >= target_score:
		finish_match("ПОБЕДА", "Ваша команда выполнила задачу и удержала точки!")
	elif red_score >= target_score:
		finish_match("ПОРАЖЕНИЕ", "Противник набрал 300 очков и захватил плацдарм.")

func update_point_indicator(id: String, owner_t: int, contested: bool) -> void:
	var label_node: Label = null
	match id:
		"A": label_node = point_a_indicator
		"B": label_node = point_b_indicator
		"C": label_node = point_c_indicator

	if label_node == null:
		return

	if contested:
		label_node.modulate = Color(1.0, 0.85, 0.2)
	elif owner_t == 1:
		label_node.modulate = Color(0.3, 0.65, 1.0)
	elif owner_t == 2:
		label_node.modulate = Color(1.0, 0.35, 0.3)
	else:
		label_node.modulate = Color(0.8, 0.8, 0.8)

func finish_match(title: String, desc: String) -> void:
	match_ended = true
	hud.visible = false
	end_screen.visible = true
	$UI/EndScreen/Panel/EndTitle.text = title
	$UI/EndScreen/Panel/EndDesc.text = desc

func resume_game() -> void:
	pause_screen.visible = false

func restart_match() -> void:
	get_tree().reload_current_scene()

func _on_player_health_changed(hp: float, bleeding: bool, b_count: int) -> void:
	health_label.text = str(hp)
	health_bar.value = hp
	bandage_label.text = str(b_count)

func _on_player_ammo_changed(ammo: int, reserve: int, w_name: String) -> void:
	weapon_name_label.text = w_name
	ammo_label.text = "%d / %d" % [ammo, reserve]

func _on_player_hit_enemy(is_headshot: bool, _is_kill: bool) -> void:
	# Flash crosshair hitmarker
	hitmarker.modulate = Color(1.0, 0.2, 0.2) if is_headshot else Color.WHITE
	hitmarker.visible = true
	get_tree().create_timer(0.12).timeout.connect(func(): hitmarker.visible = false)

func _on_player_died() -> void:
	finish_match("ВЫ ПОГИБЛИ В БОЮ", "Ваш отряд продолжает операцию...")
