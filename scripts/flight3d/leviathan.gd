class_name FlightLeviathan
extends Area3D
signal vent_cracked(point: Vector3)
signal core_shed(point: Vector3)
signal silenced
var pilot: FlightPilot
var phase := 0.0
var cracked := [false, false, false]
var is_silenced := false
var shed_clock := 8.0
var beam_clock := 6.0
var beam_lane: FlightLane
var vents: Array[Area3D] = []
var model: Node3D
func _ready() -> void:
	# Match the patrol at phase zero before the coordinator places loose cores.
	position = Vector3(0, 26, -72)
	collision_layer = 0
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(22, 12, 85)
	collision.shape = box
	add_child(collision)
	model = ModelAssets.model("leviathan", "albatross")
	model.scale = Vector3.ONE * 3
	add_child(model)
	for i in 3:
		var vent := Area3D.new()
		vent.collision_layer = 0
		vent.collision_mask = 1
		add_child(vent)
		vent.position = model.transform * ModelAssets.part_position(model, "Vent_%d" % i, Vector3(0, 3, (i - 1) * 7.3))
		FlightVisuals.sphere_shape(vent, 4)
		var halo := FlightVisuals.ring(vent, 4.2, Color("ffbe80"))
		halo.rotation.x = PI / 2
		vents.append(vent)
	beam_lane = FlightLane.new()
	beam_lane.pilot = pilot
	beam_lane.meteor = false
	get_parent().add_child.call_deferred(beam_lane)
func vent_position(index: int) -> Vector3:
	return vents[index].global_position
func begin_beam() -> void:
	if is_silenced or not beam_lane.is_inside_tree():
		return
	var start := position
	var direction := start.direction_to(pilot.position)
	beam_lane.begin(start, start + direction * 380)
	beam_clock = 6
func _physics_process(delta: float) -> void:
	phase += delta * 0.1
	position = Vector3(sin(phase) * 85, 26 + sin(phase * 0.7) * 8, -92 + cos(phase) * 20)
	rotation.y = -phase * 0.35
	shed_clock -= delta
	if shed_clock <= 0:
		shed_clock = 8
		core_shed.emit(position + Vector3(22, 10, 0))
	if not is_silenced:
		beam_clock -= delta
		if beam_clock <= 0:
			begin_beam()
	for i in 3:
		if not cracked[i] and pilot.dash_remaining > 0 and pilot in vents[i].get_overlapping_bodies():
			cracked[i] = true
			vents[i].visible = false
			var part := ModelAssets.part(model, "Vent_%d" % i)
			if part:
				part.visible = false
			vent_cracked.emit(vent_position(i))
			if not false in cracked:
				is_silenced = true
				beam_lane.enabled = false
				beam_lane.warning = 0
				beam_lane.firing = 0
				silenced.emit()
	for body in get_overlapping_bodies():
		if body == pilot:
			pilot.hit(position)
			var normal := (pilot.position - position) / Vector3(11, 6, 42.5)
			# Push to nearest face, preserving a clear path to top-hull vents.
			var local := to_local(pilot.position)
			local.y = 8.5 if normal.y >= 0 else -8.5
			pilot.position = to_global(local)
			pilot.gravity_velocity = basis.y * (25 if normal.y >= 0 else -25)
			if pilot.dash_remaining > 0:
				pilot.dash_remaining = 0
				pilot.velocity = basis.y * (50 if normal.y >= 0 else -50)
