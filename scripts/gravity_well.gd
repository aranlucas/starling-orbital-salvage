class_name GravityWell
extends Area2D
signal consumed(core: SalvageCore)
signal inverted
var pilot: Pilot
var radius := 330.0
var horizon := 40.0
var inversion := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0

func force_at(point: Vector2) -> Vector2:
	var offset := position - point
	return offset.normalized() * 260 * maxf(0, 1 - offset.length() / radius) * (-1 if inversion > 0 else 1)

func _physics_process(delta: float) -> void:
	inversion = maxf(0, inversion - delta)
	if not is_instance_valid(pilot) or not pilot.active:
		return
	# Apply after the pilot movement; the force remains until the next step.
	pilot.external_force += force_at(pilot.position)
	var offset := pilot.position - position
	if offset.length() < horizon + pilot.hit_radius:
		var direction := offset.normalized() if offset.length() > 0.01 else Vector2.RIGHT
		pilot.hit()
		pilot.position = position + direction * (horizon + pilot.hit_radius + 8)
		pilot.gravity_velocity = direction * 580
	for actor in get_parent().get_children():
		if actor is SalvageCore and not actor.taken:
			actor.position += force_at(actor.position) * delta * 0.24
			if actor.position.distance_to(position) < horizon:
				actor.taken = true
				consumed.emit(actor)
				actor.queue_free()
	queue_redraw()

func receive_pulse(_origin: Vector2, _reach: float) -> void:
	inversion = 1.5
	inverted.emit()

func _draw() -> void:
	var color := Color("78f5dd") if inversion > 0 else Color("a7a0ff")
	draw_circle(Vector2.ZERO, horizon, Color("070c18"))
	for ring in 5:
		draw_arc(Vector2.ZERO, horizon + ring * 40, 0, TAU, 64, Color(color, 0.6 / (ring + 1)), 2)
