class_name FlightDressing
extends Node3D
## Static landmarks and a single MultiMesh for camera-local parallax dust.
var pilot: FlightPilot
var dust: MultiMeshInstance3D
var points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()
func _ready() -> void:
	rng.seed = 19381
	var station := ModelAssets.model("roost_station", "dock_beacon")
	station.scale = Vector3.ONE * 9
	station.position = Vector3(-330, 80, -500)
	station.rotation_degrees = Vector3(12, -24, 14)
	add_child(station)
	var arc := ModelAssets.model("ring_arc", "dock_beacon")
	arc.scale = Vector3.ONE * 3
	arc.position = Vector3(75, -85, -180)
	arc.rotation_degrees = Vector3(18, 15, 32)
	add_child(arc)
	var fragments := ModelAssets.model("wreck_fragments", "asteroid_b")
	fragments.scale = Vector3.ONE * 4
	fragments.position = Vector3(-100, 20, -125)
	fragments.rotation_degrees = Vector3(10, 25, -20)
	add_child(fragments)
	# A handful of distant rocks anchor scale without filling the salvage volume.
	for i in 16:
		var rock := ModelAssets.model("asteroid_b", "asteroid")
		rock.scale = Vector3.ONE * rng.randf_range(5, 14)
		rock.position = Vector3(rng.randf_range(-400, 400), rng.randf_range(-180, -100), rng.randf_range(-450, 300))
		add_child(rock)
	dust = MultiMeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, 0.15)
	mesh.material = ModelAssets.material(Color("7899a6"), true)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = 180
	dust.multimesh = multi
	dust.custom_aabb = AABB(Vector3.ONE * -80, Vector3.ONE * 160)
	add_child(dust)
	for i in 180:
		points.append(Vector3(rng.randf_range(-55, 55), rng.randf_range(-40, 40), rng.randf_range(-65, 25)))
func _process(delta: float) -> void:
	global_position = Vector3.ZERO
	dust.global_transform = Transform3D(Basis.IDENTITY, pilot.global_position)
	var drift := pilot.velocity
	var streak_basis := Basis.looking_at(drift.normalized(), Vector3.RIGHT if absf(drift.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP) if drift.length() > 0.1 else Basis.IDENTITY
	var streak := 1.0 if pilot.reduced_motion else 1 + pilot.velocity.length() * 0.18
	for i in points.size():
		points[i] -= drift * delta
		points[i].x = wrapf(points[i].x, -55, 55)
		points[i].y = wrapf(points[i].y, -40, 40)
		points[i].z = wrapf(points[i].z, -65, 25)
		dust.multimesh.set_instance_transform(i, Transform3D(streak_basis.scaled(Vector3(1, 1, streak)), points[i]))
