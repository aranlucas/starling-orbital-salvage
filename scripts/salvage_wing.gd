class_name SalvageWing
extends Area2D
var pilot: Pilot
var phase := 0.0
var orbit := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(pilot) or not pilot.active:
		return
	phase += delta * 1.5
	position = pilot.position + Vector2.from_angle(phase + orbit) * 70
	for actor in get_parent().get_children():
		if actor is SalvageCore and not actor.taken and actor.position.distance_to(position) < 26:
			actor._on_area_entered(pilot)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 9, Color("78f5dd"))
