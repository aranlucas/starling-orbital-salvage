class_name SentryDrone
extends Area2D
## Patrol, visibly lock a direction, then lunge. Dash through it to destroy it.

signal shattered(point: Vector2)

const TEXTURE := preload("res://assets/art/drone.png")
var pilot: Pilot
var anchor := Vector2.ZERO
var phase := 0.0
var cycle := 2.8
var windup := 0.0
var charging := 0.0
var stunned := 0.0
var heading := Vector2.DOWN


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	anchor = position
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(pilot) or not pilot.active:
		return
	phase += delta
	if stunned > 0:
		stunned -= delta
	elif windup > 0:
		windup = maxf(0, windup - delta)
		if windup == 0:
			charging = 0.7
	elif charging > 0:
		charging = maxf(0, charging - delta)
		position += heading * 390 * delta
		if charging == 0:
			anchor = position
	else:
		cycle -= delta
		position = anchor + Vector2(cos(phase * 0.9) * 36, sin(phase * 1.1) * 24)
		if cycle <= 0 and position.distance_to(pilot.position) < 600:
			heading = position.direction_to(pilot.position)
			windup = 1.1
			cycle = 3.8
	position = position.clamp(Vector2(90, 180), Vector2(1190, 688))
	if position.distance_to(Vector2(640, 431)) < 110:
		position = Vector2(640, 431) + (position - Vector2(640, 431)).normalized() * 111
	for area in get_overlapping_areas():
		if area is Pilot and stunned <= 0:
			if area.dash_remaining > 0:
				shattered.emit(position)
				queue_free()
				return
			area.hit()
	queue_redraw()


func receive_pulse(origin: Vector2, reach: float) -> void:
	if position.distance_to(origin) < reach + 20:
		stunned = 4.0
		windup = 0
		charging = 0
		cycle = 2.0
		queue_redraw()


func _draw() -> void:
	var color := Color("ff9c90") if stunned <= 0 else Color("a7a0ff")
	draw_circle(Vector2.ZERO, 33, Color(color, 0.07))
	if windup > 0:
		var distance := 220.0
		for i in 12:
			var start := heading * (30 + float(i) * distance / 12)
			draw_line(start, start + heading * 9, Color(color, 0.6), 2, true)
		draw_arc(Vector2.ZERO, 28, -PI / 2, -PI / 2 + TAU * (1 - windup / 1.1), 48, color, 2, true)
	draw_set_transform(Vector2.ZERO, heading.angle() + PI / 2)
	draw_texture_rect(TEXTURE, Rect2(-29, -29, 58, 58), false, Color(0.7, 0.7, 1.0) if stunned > 0 else Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	if stunned > 0:
		draw_arc(Vector2.ZERO, 26, phase * 2, phase * 2 + PI * 1.5, 32, color, 1.5, true)
