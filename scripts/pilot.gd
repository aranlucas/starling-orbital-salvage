class_name Pilot
extends Area2D
## Responsive acceleration, a short invulnerable dash, and a three-hit hull.

signal damaged
signal destroyed
signal dashed
signal pulse_fired

const SPEED := 290.0
const DASH_SPEED := 820.0
const DASH_DURATION := 0.18
const DASH_COOLDOWN := 1.3
const BOUNDS := Rect2(58, 148, 1164, 568)
const SHIP_TEXTURE := preload("res://assets/art/ship.png")

var frame := "starling"
var hit_radius := 13.0
var cargo_drag := 1.0
var dash_duration := DASH_DURATION
var external_force := Vector2.ZERO
var gravity_velocity := Vector2.ZERO
var health := 3
var max_health := 3
var speed_multiplier := 1.0
var cooldown_max := DASH_COOLDOWN
var pulse_cooldown_max := 7.0
var pulse_cooldown := 0.0
var pulse_radius := 200.0
var magnet_radius := 45.0
var cargo_load := 0
var reduced_motion := false
var active := false
var velocity := Vector2.ZERO
var heading := Vector2.UP
var dash_remaining := 0.0
var cooldown := 0.0
var invulnerability := 0.0
var trail: Array[Vector2] = []
var elapsed := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = hit_radius
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	elapsed += delta
	cooldown = maxf(0.0, cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	dash_remaining = maxf(0.0, dash_remaining - delta)
	pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
	if active:
		var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if direction.length_squared() > 0.0:
			heading = direction.normalized()
		if Input.is_action_just_pressed("dash") and cooldown <= 0.0:
			dash_remaining = dash_duration
			cooldown = cooldown_max
			dashed.emit()
		if Input.is_action_just_pressed("pulse") and pulse_cooldown <= 0.0:
			pulse_cooldown = pulse_cooldown_max
			invulnerability = maxf(invulnerability, 0.35)
			pulse_fired.emit()
		if dash_remaining > 0.0:
			velocity = heading * DASH_SPEED
		else:
			var load_factor := maxf(0.82, 1.0 - cargo_load * 0.018 * cargo_drag)
			velocity = velocity.move_toward(direction * SPEED * speed_multiplier * load_factor, 1450.0 * delta)
		gravity_velocity = gravity_velocity * exp(-delta * 1.8) + external_force * delta
		external_force = Vector2.ZERO
		position += (velocity + gravity_velocity) * delta
		position = position.clamp(BOUNDS.position, BOUNDS.end)
	else:
		velocity = Vector2.ZERO
	trail.push_front(position)
	if trail.size() > 12:
		trail.pop_back()
	queue_redraw()


func configure(upgrades: Dictionary, hull: int, frame_id: String = "starling", plating: bool = false) -> void:
	frame = frame_id
	var stats: Dictionary = FlightProfile.FRAMES[frame]
	max_health = int(stats.hull) + int(upgrades.get("hull", 0)) + (1 if plating else 0)
	health = clampi(hull, 1, max_health)
	speed_multiplier = float(stats.speed) + float(upgrades.get("dash", 0)) * 0.08
	cooldown_max = maxf(0.25, float(stats.recharge) - float(upgrades.get("dash", 0)) * 0.3)
	pulse_cooldown_max = 7.0 - float(upgrades.get("pulse", 0))
	pulse_radius = 200.0 + float(upgrades.get("pulse", 0)) * 65.0
	magnet_radius = float(stats.magnet) + float(upgrades.get("magnet", 0)) * 65.0
	hit_radius = float(stats.radius)
	cargo_drag = 0.0 if int(upgrades.get("ballast", 0)) > 0 else float(stats.drag)
	dash_duration = DASH_DURATION + 0.1 * int(upgrades.get("ram", 0))


func hit() -> void:
	if not active or invulnerability > 0.0 or dash_remaining > 0.0:
		return
	health -= 1
	invulnerability = 1.6
	damaged.emit()
	if health <= 0:
		active = false
		destroyed.emit()


func _draw() -> void:
	var cyan := Color("78f5dd")
	for i in range(1, trail.size()):
		var alpha := (1.0 - float(i) / 12.0) * 0.35
		draw_circle(trail[i] - position, 8.0 * (1.0 - float(i) / 14.0), Color(cyan, alpha))
	if invulnerability > 0.0 and not reduced_motion and sin(elapsed * 35.0) < 0.0:
		return
	var angle := heading.angle() + PI / 2.0
	if velocity.length() > 20.0:
		var flame := PackedVector2Array([
			Vector2(-5, 12), Vector2(0, 23 + sin(elapsed * 50) * 5), Vector2(5, 12)
		])
		for i in flame.size():
			flame[i] = flame[i].rotated(angle)
		draw_colored_polygon(flame, Color("efbd70"))
	draw_circle(Vector2.ZERO, 25, Color(cyan, 0.045))
	draw_set_transform(Vector2.ZERO, angle)
	draw_texture_rect(SHIP_TEXTURE, Rect2(-32, -32, 64, 64), false)
	draw_set_transform(Vector2.ZERO)
	if invulnerability > 0 and reduced_motion:
		draw_arc(Vector2.ZERO, 26, 0, TAU, 40, Color(cyan, 0.45), 1.5, true)
	if dash_remaining > 0.0:
		draw_arc(Vector2.ZERO, 26, 0, TAU, 40, Color(cyan, 0.8), 2, true)
