class_name Debris
extends Area2D
## Drifting debris bounces off the arena walls and damages an overlapping pilot.

const ROCK_TEXTURE := preload("res://assets/art/asteroid.png")

signal shattered(point: Vector2)

var velocity := Vector2.ZERO
var radius := 23.0
var spin := 0.2
var active := false
var safe_center := Vector2(640, 431)
var cruise_speed := 60.0


func _ready() -> void:
	cruise_speed = maxf(45, velocity.length())
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius * 0.86
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	if not active:
		return
	position += velocity * delta
	velocity = velocity.move_toward(velocity.normalized() * cruise_speed, 130 * delta)
	# Keep the dock safe instead of letting a rock camp on the only exit.
	var from_dock := position - safe_center
	if from_dock.length() < 88 + radius:
		position = safe_center + from_dock.normalized() * (89 + radius)
		velocity = from_dock.normalized() * maxf(velocity.length(), 50)
	rotation += spin * delta
	if position.x < 50 + radius or position.x > 1230 - radius:
		velocity.x = -velocity.x
		position.x = clampf(position.x, 50 + radius, 1230 - radius)
	if position.y < 140 + radius or position.y > 726 - radius:
		velocity.y = -velocity.y
		position.y = clampf(position.y, 140 + radius, 726 - radius)
	# Poll overlaps so a ship cannot stay inside debris after its shield expires.
	for area in get_overlapping_areas():
		if area is Pilot:
			if area.dash_remaining > 0:
				shattered.emit(position)
				queue_free()
				return
			area.hit()
	queue_redraw()


func receive_pulse(origin: Vector2, reach: float) -> void:
	if position.distance_to(origin) < reach + radius:
		velocity = origin.direction_to(position) * 220


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 7, Color(0.95, 0.4, 0.38, 0.035))
	draw_texture_rect(ROCK_TEXTURE, Rect2(Vector2.ONE * -radius * 1.3, Vector2.ONE * radius * 2.6), false, Color("e1b9b6"))
