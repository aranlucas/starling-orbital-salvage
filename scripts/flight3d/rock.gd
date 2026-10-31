class_name FlightRock
extends Area3D
signal shattered(point: Vector3, points: int)
var pilot: FlightPilot
var radius := 3.5
var velocity := Vector3.ZERO
var spin := Vector3(0.15, 0.2, 0.1)
var gone := false
func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	FlightVisuals.sphere_shape(self, radius)
	var model := ModelAssets.model(["asteroid", "asteroid_b", "asteroid_c"][get_instance_id() % 3])
	model.scale = Vector3.ONE * radius
	add_child(model)
func _physics_process(delta: float) -> void:
	position += velocity * delta
	rotation += spin * delta
	if position.length() > 195 - radius:
		velocity = velocity.bounce(position.normalized())
		position = position.normalized() * (194 - radius)
	if position.length() < radius + 20:
		position = position.normalized() * (radius + 20.1)
		velocity = position.normalized() * maxf(8, velocity.length())
	for body in get_overlapping_bodies():
		if body == pilot and not gone:
			if pilot.dash_remaining > 0:
				gone = true
				shattered.emit(position, 75)
				queue_free()
			else:
				pilot.hit(position)
func receive_pulse(origin: Vector3, reach: float) -> void:
	if position.distance_to(origin) < reach + radius:
		velocity = origin.direction_to(position) * 36
