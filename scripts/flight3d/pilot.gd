class_name FlightPilot
extends CharacterBody3D
## Arcade free flight in metres; world-up is stable and banking is cosmetic.
signal damaged
signal destroyed
signal dashed
signal pulse_fired
const SPEED := 38.0
const DASH_SPEED := 110.0
const TURN_RATE := 1.65
var active := false
var mouse_captured := false
var health := 3
var max_health := 3
var frame := "starling"
var reduced_motion := false
var invert_y := false
var speed_multiplier := 1.0
var cargo_drag := 1.0
var cargo_load := 0
var hit_radius := 1.3
var magnet_radius := 7.0
var pulse_radius := 32.0
var cooldown_max := 1.3
var cooldown := 0.0
var pulse_cooldown_max := 7.0
var pulse_cooldown := 0.0
var dash_duration := 0.25
var dash_remaining := 0.0
var invulnerability := 0.0
var external_force := Vector3.ZERO
var gravity_velocity := Vector3.ZERO
var damage_origin := Vector3.ZERO
var dash_direction := Vector3.FORWARD
var yaw := 0.0
var pitch := 0.0
var steering := Vector2.ZERO
var mouse_rate := Vector2.ZERO
var model: Node3D
var boundary_warning := false

func configure(upgrades: Dictionary, hull: int, frame_id: String, plating: bool) -> void:
	frame = frame_id
	var stats: Dictionary = FlightProfile.FRAMES[frame]
	max_health = int(stats.hull) + int(upgrades.hull) + int(plating)
	health = clampi(hull, 1, max_health)
	speed_multiplier = float(stats.speed) + 0.08 * int(upgrades.dash)
	cargo_drag = 0.0 if int(upgrades.ballast) > 0 else float(stats.drag)
	hit_radius = float(stats.radius) / 10.0
	magnet_radius = float(stats.magnet) / 6.5 + 10.0 * int(upgrades.magnet)
	pulse_radius = 32.0 + 12.0 * int(upgrades.pulse)
	cooldown_max = maxf(0.25, float(stats.recharge) - 0.3 * int(upgrades.dash))
	pulse_cooldown_max = 7.0 - int(upgrades.pulse)
	dash_duration = 0.25 + 0.1 * int(upgrades.ram)

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = hit_radius
	shape.shape = sphere
	add_child(shape)
	model = ModelAssets.model("ship" if frame == "starling" else frame, "ship")
	add_child(model)

func _input(event: InputEvent) -> void:
	if active and event is InputEventMouseMotion and mouse_captured and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"):
		mouse_rate += event.relative * 0.055
		mouse_rate = mouse_rate.limit_length(1.0)

func _physics_process(delta: float) -> void:
	if not active:
		return
	cooldown = maxf(0, cooldown - delta)
	pulse_cooldown = maxf(0, pulse_cooldown - delta)
	invulnerability = maxf(0, invulnerability - delta)
	dash_remaining = maxf(0, dash_remaining - delta)
	var keys := Input.get_vector("flight_yaw_left", "flight_yaw_right", "flight_pitch_up", "flight_pitch_down")
	var desired := (keys + mouse_rate).limit_length(1)
	steering = steering.lerp(desired, 1 - exp(-delta * 12))
	mouse_rate *= exp(-delta * 9)
	yaw -= steering.x * TURN_RATE * delta
	pitch = clampf(pitch - steering.y * TURN_RATE * delta * (-1 if invert_y else 1), deg_to_rad(-75), deg_to_rad(75))
	rotation = Vector3(pitch, yaw, 0)
	model.rotation.z = lerpf(model.rotation.z, -steering.x * 0.42, 1 - exp(-delta * 7))
	if Input.is_action_just_pressed("dash") and cooldown <= 0:
		var travel := velocity + gravity_velocity
		dash_direction = travel.normalized() if travel.length() > 2 else -basis.z
		dash_remaining = dash_duration
		cooldown = cooldown_max
		dashed.emit()
	if Input.is_action_just_pressed("pulse") and pulse_cooldown <= 0:
		pulse_cooldown = pulse_cooldown_max
		pulse_fired.emit()
	var thrust := Input.get_axis("flight_brake", "flight_thrust")
	var strafe := Input.get_axis("flight_left", "flight_right")
	var load_factor := maxf(0.82, 1 - cargo_load * 0.018 * cargo_drag)
	var target := (-basis.z * thrust * (0.2 if thrust < 0 else 1.0) + basis.x * strafe * 0.65).limit_length() * SPEED * speed_multiplier * load_factor
	velocity = dash_direction * DASH_SPEED if dash_remaining > 0 else velocity.move_toward(target, delta * 100)
	boundary_warning = position.length() > 185
	if boundary_warning:
		external_force -= position.normalized() * (35 + maxf(0, position.length() - 185) * 8)
	gravity_velocity = gravity_velocity * exp(-delta * 1.8) + external_force * delta
	external_force = Vector3.ZERO
	# Preserve the player's commanded velocity separately from environmental drift.
	var commanded := velocity
	velocity += gravity_velocity
	move_and_slide()
	velocity -= gravity_velocity
	if get_slide_collision_count() == 0:
		velocity = commanded
	if position.length() > 210:
		position = position.normalized() * 210
		velocity -= position.normalized() * maxf(0, velocity.dot(position.normalized()))

func hit(origin: Vector3 = Vector3.ZERO) -> void:
	if not active or invulnerability > 0 or dash_remaining > 0:
		return
	damage_origin = origin
	health -= 1
	invulnerability = 1.6
	damaged.emit()
	if health <= 0:
		active = false
		destroyed.emit()
