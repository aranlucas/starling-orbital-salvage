class_name FlightCamera
extends Node3D
var pilot: FlightPilot
var camera: Camera3D
var arm: SpringArm3D
var shake := 0.0
func _ready() -> void:
	arm = SpringArm3D.new()
	arm.spring_length = 12
	arm.margin = 0.8
	arm.collision_mask = 2
	add_child(arm)
	camera = Camera3D.new()
	camera.fov = 72
	camera.near = 0.2
	camera.far = 2200
	camera.position.y = 3.4
	camera.rotation_degrees.x = -1.5
	arm.add_child(camera)
	camera.current = true
	reset()
func reset() -> void:
	global_position = pilot.global_position + Vector3.UP * 0.7
	quaternion = pilot.quaternion
func _process(delta: float) -> void:
	global_position = pilot.global_position + Vector3.UP * 0.7
	quaternion = pilot.quaternion if pilot.reduced_motion else quaternion.slerp(pilot.quaternion, 1 - exp(-delta * 8))
	var target_fov := 72.0 if pilot.reduced_motion else 72.0 + minf(1, pilot.velocity.length() / 38) * 5 + (9 if pilot.dash_remaining > 0 else 0)
	camera.fov = 72 if pilot.reduced_motion else lerpf(camera.fov, target_fov, 1 - exp(-delta * 8))
	shake = maxf(0, shake - delta * 2)
	camera.h_offset = 0 if pilot.reduced_motion else sin(Time.get_ticks_msec() * 0.073) * shake * 0.16
	camera.v_offset = 0 if pilot.reduced_motion else cos(Time.get_ticks_msec() * 0.091) * shake * 0.1
