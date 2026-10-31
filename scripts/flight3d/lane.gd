class_name FlightLane
extends Area3D
## Shared volumetric meteor/beam warning and damage volume.
signal warned
signal deflected(point: Vector3, points: int)
var pilot: FlightPilot
var lane_start := Vector3.ZERO
var lane_end := Vector3.ZERO
var warning := 0.0
var firing := 0.0
var cycle := 4.0
var meteor := true
var enabled := true
var visual: MeshInstance3D
var shape: CollisionShape3D
var model: Node3D
func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	visual = FlightVisuals.cylinder(self, 4, Color(1, 0.67, 0.3, 0.16))
	shape = CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 4
	cylinder.height = 1
	shape.shape = cylinder
	add_child(shape)
	model = ModelAssets.model("meteor")
	model.scale = Vector3.ONE * 2.8
	add_child(model)
	visual.visible = false
	model.visible = false
func begin(start: Vector3, finish: Vector3) -> void:
	if not enabled:
		return
	lane_start = start
	lane_end = finish
	warning = 1.4
	firing = 0
	cycle = 6
	FlightVisuals.aim_cylinder(visual, start, finish)
	shape.transform = visual.transform
	warned.emit()
func _physics_process(delta: float) -> void:
	if not enabled:
		warning = 0
		firing = 0
	cycle -= delta
	if warning > 0:
		warning = maxf(0, warning - delta)
		if warning == 0:
			firing = 0.6
	elif firing > 0:
		firing = maxf(0, firing - delta)
		for body in get_overlapping_bodies():
			if body == pilot and pilot.position.length() > 20:
				if meteor and pilot.dash_remaining > 0:
					deflected.emit(pilot.position, 100)
					firing = 0
				else:
					pilot.hit(lane_start)
	elif meteor and enabled and cycle <= 0:
		var direction := Vector3(1, 0.15, -0.45).normalized()
		var target := pilot.position
		if target.length() < 25:
			target += Vector3(0, 35, -30)
		begin(target - direction * 180, target + direction * 180)
	visual.visible = warning > 0 or firing > 0
	visual.material_override.albedo_color = Color(1, 0.67, 0.3, 0.18) if warning > 0 else Color(1, 0.3, 0.18, 0.85)
	model.visible = meteor and firing > 0
	if model.visible:
		model.position = lane_start.lerp(lane_end, 1 - firing / 0.6)
func receive_pulse(origin: Vector3, reach: float) -> void:
	if meteor and firing > 0 and model.position.distance_to(origin) < reach + 4:
		firing = 0
		deflected.emit(model.position, 100)
