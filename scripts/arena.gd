extends Node2D
## Atmospheric field and dock display, separate from mission simulation.

const BACKDROP := preload("res://assets/art/arena_backdrop.png")
const FIELD := Rect2(40, 130, 1200, 606)
const BEACON := Vector2(640, 431)
var accent := Color("78f5dd")
var elapsed := 0.0
var cargo := 0
var dock_progress := 0.0
var pilot_position := BEACON
var destination := Vector2.ZERO
var reduced_motion := false


func _draw() -> void:
	draw_texture_rect(BACKDROP, FIELD, false, Color(0.65, 0.7, 0.8))
	draw_rect(FIELD, Color(0.01, 0.025, 0.045, 0.34))
	for x in range(40, 1241, 60):
		draw_line(Vector2(x, 130), Vector2(x, 736), Color(0.3, 0.5, 0.65, 0.045))
	for y in range(136, 737, 60):
		draw_line(Vector2(40, y), Vector2(1240, y), Color(0.3, 0.5, 0.65, 0.045))
	draw_rect(FIELD, Color(accent, 0.25), false, 1)
	for corner in [Vector2(40, 130), Vector2(1240, 130), Vector2(40, 736), Vector2(1240, 736)]:
		var direction := Vector2(1 if corner.x == 40 else -1, 1 if corner.y == 130 else -1)
		draw_line(corner, corner + Vector2(18 * direction.x, 0), accent, 2)
		draw_line(corner, corner + Vector2(0, 18 * direction.y), accent, 2)
	var pulse := 0.0 if reduced_motion else sin(elapsed * 2) * 2
	draw_circle(BEACON, 77, Color(accent, 0.055))
	draw_circle(BEACON, 54, Color(accent, 0.035))
	draw_arc(BEACON, 54 + pulse, 0, TAU, 80, Color(accent, 0.55 if cargo > 0 else 0.25), 1.4, true)
	for i in 4:
		var offset := Vector2.from_angle(PI * 0.25 + i * PI / 2) * 32
		draw_line(BEACON + offset * 0.7, BEACON + offset, Color(accent, 0.7), 3, true)
	if dock_progress > 0:
		draw_arc(BEACON, 62, -PI / 2, -PI / 2 + TAU * dock_progress, 80, accent, 4, true)
	var caption := "DOCK TO BANK %02d" % cargo if cargo > 0 else "SAFE DOCK"
	draw_string(ThemeDB.fallback_font, BEACON + Vector2(-52, 91), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, accent)
	# A small navigation chevron helps locate the final core or the home dock.
	if destination != Vector2.ZERO and pilot_position.distance_to(destination) > 120:
		var direction := pilot_position.direction_to(destination)
		var tip := pilot_position + direction * 43
		var side := direction.orthogonal() * 4
		var color := accent if destination == BEACON else Color("f3c77b")
		draw_polyline(PackedVector2Array([tip - direction * 6 + side, tip, tip - direction * 6 - side]), Color(color, 0.8), 1.5, true)
