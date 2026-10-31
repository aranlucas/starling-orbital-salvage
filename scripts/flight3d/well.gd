class_name FlightWell
extends Area3D
signal consumed(core: FlightCore)
signal inverted
var pilot: FlightPilot
var radius := 110.0
var horizon := 12.0
var inversion := 0.0
var ring: MeshInstance3D
func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	FlightVisuals.sphere_shape(self, horizon)
	var model := ModelAssets.model("gravity_well")
	model.scale = Vector3.ONE * 3
	add_child(model)
	for i in 4:
		var orbit := FlightVisuals.ring(self, 16 + i * 9, Color("8076b6"))
		orbit.rotation_degrees = Vector3(12, 0, 18)
	ring = FlightVisuals.ring(self, 13, Color("b1a0ff"))
func force_at(point: Vector3) -> Vector3:
	var offset := position - point
	return offset.normalized() * 44 * maxf(0, 1 - offset.length() / radius) * (-1 if inversion > 0 else 1)
func _physics_process(delta: float) -> void:
	inversion = maxf(0, inversion - delta)
	pilot.external_force += force_at(pilot.position)
	for body in get_overlapping_bodies():
		if body == pilot:
			var normal := position.direction_to(pilot.position)
			if normal.length() < 0.01:
				normal = Vector3.RIGHT
			pilot.hit(position)
			pilot.position = position + normal * (horizon + pilot.hit_radius + 2)
			pilot.gravity_velocity = normal * 85
	for actor in get_parent().get_children():
		if actor is FlightCore and not actor.taken:
			actor.position += force_at(actor.position) * delta * 0.24
			if actor.position.distance_to(position) < horizon:
				actor.taken = true
				consumed.emit(actor)
				actor.queue_free()
	ring.material_override.albedo_color = Color("78f5dd") if inversion > 0 else Color("b1a0ff")
func receive_pulse(origin: Vector3, reach: float) -> void:
	if position.distance_to(origin) < reach + horizon:
		inversion = 1.5
		inverted.emit()
