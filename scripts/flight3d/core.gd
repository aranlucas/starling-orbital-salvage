class_name FlightCore
extends Area3D
signal collected(core: FlightCore)
var pilot: FlightPilot
var taken := false
var pull_boost := 0.0
var model: Node3D
func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	FlightVisuals.sphere_shape(self, 2.1)
	model = ModelAssets.model("energy_core")
	model.scale = Vector3.ONE * 1.7
	add_child(model)
	var halo := FlightVisuals.ring(self, 2.3, Color("f3c77b"))
	halo.rotation.x = PI / 2
	body_entered.connect(func(body: Node3D) -> void:
		if body == pilot:
			collect())
func _physics_process(delta: float) -> void:
	if taken or not pilot.active:
		return
	pull_boost = maxf(0, pull_boost - delta)
	if position.distance_to(pilot.position) < pilot.magnet_radius or pull_boost > 0:
		position = position.move_toward(pilot.position, delta * 52)
	model.rotate_y(delta * 0.7)
	for body in get_overlapping_bodies():
		if body == pilot:
			collect()
func collect() -> void:
	if taken or not pilot.active:
		return
	taken = true
	collected.emit(self)
	queue_free()
func receive_pulse(origin: Vector3, reach: float) -> void:
	if position.distance_to(origin) < reach:
		pull_boost = 0.8
