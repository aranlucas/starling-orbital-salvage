class_name FlightSpire
extends StaticBody3D
const RADIUS := 6.0
func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = 150
	shape.shape = cylinder
	add_child(shape)
	var model := ModelAssets.model("foundry_spire")
	model.scale = Vector3(4, 12.5, 4)
	add_child(model)
	model.position = -(model.basis * ModelAssets.bounds(model).get_center())
func _physics_process(_delta: float) -> void:
	for actor in get_parent().get_children():
		if actor is FlightRock or actor is FlightPilot:
			var offset: Vector3 = actor.position - position
			if absf(offset.y) > 75:
				continue
			offset.y = 0
			var reach: float = RADIUS + (actor.radius if actor is FlightRock else actor.hit_radius)
			if offset.length() < reach:
				var normal := offset.normalized() if offset.length() > 0.01 else Vector3.RIGHT
				actor.position += normal * (reach - offset.length() + 0.02)
				if actor.velocity.dot(normal) < 0:
					actor.velocity = actor.velocity.bounce(normal) if actor is FlightRock else actor.velocity.slide(normal)
