class_name FoundrySpire
extends Area2D
## Manual circle separation preserves the Area2D simulation and allows sliding.
var radius := 34.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0

func _physics_process(_delta: float) -> void:
	for actor in get_parent().get_children():
		if not (actor is Pilot or actor is Debris):
			continue
		var offset: Vector2 = actor.position - position
		var reach: float = radius + (actor.hit_radius if actor is Pilot else actor.radius)
		if offset.length() < reach:
			var normal := offset.normalized() if offset.length() > 0.01 else Vector2.RIGHT
			actor.position = position + normal * (reach + 0.01)
			if actor is Debris and actor.velocity.dot(normal) < 0:
				actor.velocity = actor.velocity.bounce(normal)
			elif actor.velocity.dot(normal) < 0:
				actor.velocity -= normal * actor.velocity.dot(normal)

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color("465765"))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color("ffb878"), 3)
