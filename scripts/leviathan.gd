class_name Leviathan
extends Area2D
## Vents and beam lanes use the same simulation coordinates as every other actor.
signal vent_cracked(point: Vector2)
signal core_shed(point: Vector2)
signal silenced
signal beam_warned
var pilot: Pilot
var phase := 0.0
var cracked := [false, false, false]
var shed_clock := 8.0
var beam_clock := 6.0
var warning := 0.0
var beam := 0.0
var lane_start := Vector2.ZERO
var lane_end := Vector2.ZERO
var vent_offsets := [Vector2(-100, 0), Vector2(0, 0), Vector2(100, 0)]
var is_silenced := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	position = Vector2(640, 250)

func vent_position(index: int) -> Vector2:
	return position + vent_offsets[index]

func begin_beam() -> void:
	if is_silenced:
		return
	# The dock remains a safe refuge, as on the Survey route.
	var y := clampf(pilot.position.y, 185, 690)
	if absf(y - 431) < 85:
		y = 310 if y < 431 else 560
	lane_start = Vector2(45, y)
	lane_end = Vector2(1235, y)
	warning = 1.4
	beam_clock = 6.0
	beam_warned.emit()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(pilot) or not pilot.active:
		return
	phase += delta * 0.18
	position = Vector2(640 + sin(phase) * 300, 250 + cos(phase) * 40)
	shed_clock -= delta
	if shed_clock <= 0:
		shed_clock += 8.0
		core_shed.emit(position + Vector2(0, 75))
	if not is_silenced:
		beam_clock -= delta
	if warning > 0:
		warning = maxf(0, warning - delta)
		if warning == 0:
			beam = 0.6
	elif beam > 0:
		beam = maxf(0, beam - delta)
		if absf(pilot.position.y - lane_start.y) < 25 + pilot.hit_radius:
			pilot.hit()
	elif not is_silenced:
		if beam_clock <= 0:
			begin_beam()
	for i in 3:
		if not cracked[i] and pilot.dash_remaining > 0 and pilot.position.distance_to(vent_position(i)) < 34 + pilot.hit_radius:
			cracked[i] = true
			vent_cracked.emit(vent_position(i))
			if not false in cracked:
				is_silenced = true
				warning = 0
				beam = 0
				silenced.emit()
	# Resolve hull contact after vent checks; a dash can crack then bounce.
	var nearest := Vector2(clampf(pilot.position.x, position.x - 145, position.x + 145), position.y)
	if pilot.position.distance_to(nearest) < 38 + pilot.hit_radius:
		if pilot.dash_remaining <= 0:
			pilot.hit()
		var normal := nearest.direction_to(pilot.position)
		if normal.length() < 0.01:
			normal = Vector2.DOWN
		pilot.position = nearest + normal * (40 + pilot.hit_radius)
		pilot.velocity = normal * 400
		pilot.dash_remaining = 0
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-145, -38, 290, 76), Color("465765"))
	for i in 3:
		draw_circle(vent_offsets[i], 20, Color("78f5dd") if cracked[i] else Color("ffaaa0"))
	if warning > 0 or beam > 0:
		draw_line(lane_start - position, lane_end - position, Color("ffc780") if warning > 0 else Color("ff796e"), 3 if warning > 0 else 50)
