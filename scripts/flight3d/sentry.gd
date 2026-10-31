class_name FlightSentry
extends Area3D
signal shattered(point: Vector3, points: int)
var pilot: FlightPilot
var cycle := 3.0
var anchor := Vector3.ZERO
var phase := 0.0
var windup := 0.0
var charging := 0.0
var stunned := 0.0
var heading := Vector3.FORWARD
var lock_point := Vector3.ZERO
var laser: MeshInstance3D
var gone := false
func _ready() -> void:
	anchor = position
	collision_layer = 0
	collision_mask = 1
	FlightVisuals.sphere_shape(self, 2.6)
	var model := ModelAssets.model("drone")
	model.scale = Vector3.ONE * 2
	add_child(model)
	laser = FlightVisuals.cylinder(self, 0.13, Color(1, 0.45, 0.3, 0.75))
	laser.visible = false
func _physics_process(delta: float) -> void:
	phase += delta
	if stunned > 0:
		stunned = maxf(0, stunned - delta)
	elif windup > 0:
		windup = maxf(0, windup - delta)
		if windup == 0:
			charging = 0.85
	elif charging > 0:
		charging = maxf(0, charging - delta)
		position += heading * delta * 64
		if charging == 0:
			anchor = position
	else:
		position = anchor + Vector3(cos(phase * 0.9) * 5, sin(phase * 1.1) * 3, sin(phase * 0.7) * 4)
		cycle -= delta
		if cycle <= 0 and position.distance_to(pilot.position) < 180:
			lock_point = pilot.position
			heading = position.direction_to(lock_point)
			windup = 1.1
			cycle = 4.8
	position = position.limit_length(185)
	if position.length() < 23:
		position = position.normalized() * 23.1
	laser.visible = windup > 0
	if laser.visible:
		FlightVisuals.aim_cylinder(laser, position, lock_point)
	for body in get_overlapping_bodies():
		if body == pilot and stunned <= 0 and not gone:
			if pilot.dash_remaining > 0:
				gone = true
				shattered.emit(position, 150)
				queue_free()
			else:
				pilot.hit(position)
func receive_pulse(origin: Vector3, reach: float) -> void:
	if position.distance_to(origin) < reach + 3:
		stunned = 4
		windup = 0
		charging = 0
		cycle = 2
