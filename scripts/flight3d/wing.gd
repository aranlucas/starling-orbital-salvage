class_name FlightWing
extends Area3D
var pilot: FlightPilot
var phase := 0.0
func _ready() -> void:
	collision_layer = 0
	collision_mask = 8
	FlightVisuals.sphere_shape(self, 3.8)
	var model := ModelAssets.model("salvage_wing", "drone")
	model.scale = Vector3.ONE * 1.8
	add_child(model)
func _physics_process(delta: float) -> void:
	phase += delta * 1.5
	position = pilot.position + pilot.basis * Vector3(cos(phase) * 11, sin(phase * 1.3) * 3, sin(phase) * 11)
	rotation.y = pilot.yaw - phase
	for core in get_overlapping_areas():
		if core is FlightCore:
			core.collect()
