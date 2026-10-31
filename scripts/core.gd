class_name SalvageCore
extends Area2D
## An energy core is removed before emitting, so it can only be collected once.

signal collected(core: SalvageCore)

const CORE_TEXTURE := preload("res://assets/art/energy_core.png")

var elapsed := 0.0
var taken := false
var pilot: Pilot
var pull_boost := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area_entered)
	elapsed = position.x * 0.01


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _physics_process(delta: float) -> void:
	if taken or not is_instance_valid(pilot) or not pilot.active:
		return
	pull_boost = maxf(0, pull_boost - delta)
	var distance := position.distance_to(pilot.position)
	if distance < pilot.magnet_radius or pull_boost > 0:
		position = position.move_toward(pilot.position, 380 * delta)
	if position.distance_to(pilot.position) < 22:
		_on_area_entered(pilot)


func _on_area_entered(area: Area2D) -> void:
	if taken or not area is Pilot or not area.active:
		return
	taken = true
	collected.emit(self)
	queue_free()


func _draw() -> void:
	var gold := Color("f3c77b")
	var pulse := sin(elapsed * 3.0)
	draw_circle(Vector2.ZERO, 24 + pulse * 3, Color(gold, 0.045))
	draw_circle(Vector2.ZERO, 15 + pulse, Color(gold, 0.08))
	draw_texture_rect(CORE_TEXTURE, Rect2(-21, -21 + pulse * 2, 42, 42), false)
