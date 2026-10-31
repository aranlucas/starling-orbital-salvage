class_name MeteorStorm
extends Node2D
## A readable environmental hazard: warn first, then cross the marked lane.

signal warned
signal deflected(point: Vector2)

const TEXTURE := preload("res://assets/art/asteroid.png")
var pilot: Pilot
var rng := RandomNumberGenerator.new()
var cooldown := 5.0
var warning := 0.0
var flight := 0.0
var lane_start := Vector2.ZERO
var lane_end := Vector2.ZERO
var meteor_position := Vector2.ZERO


func _physics_process(delta: float) -> void:
	if warning > 0:
		warning = maxf(0, warning - delta)
		if warning == 0:
			flight = 1.5
	elif flight > 0:
		flight = maxf(0, flight - delta)
		meteor_position = lane_start.lerp(lane_end, 1 - flight / 1.5)
		if is_instance_valid(pilot) and pilot.position.distance_to(meteor_position) < 32:
			pilot.hit()
	else:
		cooldown -= delta
		if cooldown <= 0:
			begin_warning()
	queue_redraw()


func begin_warning() -> void:
	var y := rng.randf_range(190, 290) if rng.randf() > 0.5 else rng.randf_range(575, 665)
	lane_start = Vector2(45, y)
	lane_end = Vector2(1235, y + rng.randf_range(-25, 25))
	if rng.randf() > 0.5:
		var swap := lane_start
		lane_start = lane_end
		lane_end = swap
	meteor_position = lane_start
	warning = 1.6
	cooldown = 5.5
	warned.emit()
	queue_redraw()


func receive_pulse(origin: Vector2, reach: float) -> void:
	if flight > 0 and meteor_position.distance_to(origin) < reach + 22:
		flight = 0
		deflected.emit(meteor_position)


func _draw() -> void:
	var amber := Color("ffc780")
	if warning > 0:
		var alpha := 0.35 + sin(warning * 16) * 0.15
		draw_line(lane_start, lane_end, Color(amber, 0.04), 48, true)
		for i in 40:
			var start := lane_start.lerp(lane_end, float(i) / 40)
			var end := lane_start.lerp(lane_end, (float(i) + 0.5) / 40)
			draw_line(start, end, Color(amber, alpha), 2, true)
		draw_string(ThemeDB.fallback_font, lane_start.lerp(lane_end, 0.4) + Vector2(0, -16), "!  METEOR LANE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, amber)
	if flight > 0:
		var direction := lane_start.direction_to(lane_end)
		for i in 10:
			draw_circle(meteor_position - direction * i * 9, 16 - i, Color(amber, 0.3 * (1 - float(i) / 10)))
		draw_texture_rect(TEXTURE, Rect2(meteor_position - Vector2(25, 25), Vector2(50, 50)), false, Color("ffcb98"))
