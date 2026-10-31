class_name FlightScanner
extends Node2D
## Camera-projected navigation, threat directions and height-aware scanner.
var flight: DeepFlight
var blip_count := 0
var edge_count := 0
var behind_warning := false
var damage_left := 0.0
var damage_origin := Vector3.ZERO
const GOLD := Color("f3c77b")
const MINT := Color("78f5dd")
const RED := Color("ff9887")
const RADAR := Vector2(640, 655)
var occupied_markers: Array[Rect2] = []
var font: Font
func _ready() -> void:
	font = ThemeDB.fallback_font
func _process(delta: float) -> void:
	damage_left = maxf(0, damage_left - delta)
	queue_redraw()
func label_at(point: Vector2, text: String, color: Color, size_px: int = 11) -> void:
	draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
func marker(point: Vector3, text: String, color: Color, force_label: bool = false) -> void:
	var camera := flight.chase.camera
	var screen := camera.unproject_position(point)
	var behind := camera.is_position_behind(point)
	var bounds := Rect2(55, 200, 1170, 355)
	var on_screen := not behind and bounds.has_point(screen)
	if not on_screen:
		var relative := camera.to_local(point)
		var direction := Vector2(relative.x, -relative.y)
		if direction.length() < 0.01:
			direction = Vector2.DOWN
		direction = direction.normalized()
		var center := Vector2(640, 380)
		var extent := Vector2(568, 175)
		var factor := minf(extent.x / maxf(0.001, absf(direction.x)), extent.y / maxf(0.001, absf(direction.y)))
		screen = center + direction * factor
		var tangent := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([screen + direction * 9, screen - direction * 6 + tangent * 5, screen - direction * 6 - tangent * 5]), color)
		edge_count += 1
	else:
		draw_polyline(PackedVector2Array([screen + Vector2(0, -8), screen + Vector2(7, 0), screen + Vector2(0, 8), screen + Vector2(-7, 0), screen + Vector2(0, -8)]), color, 1.5, true)
	if not on_screen or force_label:
		var label_point := Vector2(clampf(screen.x + 13, 60, 1090), screen.y + 4)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var rect := Rect2(label_point - Vector2(0, 12), Vector2(width + 8, 16))
		for attempt in 10:
			var overlaps := false
			for previous in occupied_markers:
				if rect.intersects(previous):
					overlaps = true
			if not overlaps:
				break
			rect.position.y -= 18
		occupied_markers.append(rect)
		label_at(rect.position + Vector2(0, 12), text, color)
func _draw() -> void:
	if flight == null or not is_instance_valid(flight.pilot) or flight.game.state != "running":
		return
	var pilot := flight.pilot
	var camera := flight.chase.camera
	blip_count = 0
	edge_count = 0
	behind_warning = false
	occupied_markers.clear()
	# Thin nose reticle leaves the ship and forward corridor clear.
	draw_arc(Vector2(640, 350), 5, 0, TAU, 20, Color(MINT, 0.5), 1, true)
	draw_line(Vector2(629, 350), Vector2(633, 350), Color(MINT, 0.5))
	draw_line(Vector2(647, 350), Vector2(651, 350), Color(MINT, 0.5))
	var destination := flight.navigation_target()
	marker(Vector3.ZERO, ("DOCK  %d m / BANK" if destination == Vector3.ZERO else "DOCK  %d m") % pilot.position.length(), MINT, true)
	var cores := flight.cores()
	cores.sort_custom(func(a: FlightCore, b: FlightCore) -> bool: return a.position.distance_squared_to(pilot.position) < b.position.distance_squared_to(pilot.position))
	for i in mini(3, cores.size()):
		marker(cores[i].position, ("RECOVER %d m" if i == 0 and destination != Vector3.ZERO else "%d m") % pilot.position.distance_to(cores[i].position), GOLD, i == 0 and destination != Vector3.ZERO)
	if not cores.is_empty():
		var target: Vector3 = cores[0].position
		if not camera.is_position_behind(target):
			var point := camera.unproject_position(target)
			if Rect2(60, 145, 1160, 420).has_point(point):
				for side in [-1, 1]:
					for vertical in [-1, 1]:
						var corner := point + Vector2(side, vertical) * 18
						draw_line(corner, corner - Vector2(side * 8, 0), GOLD, 2)
						draw_line(corner, corner - Vector2(0, vertical * 8), GOLD, 2)
	for actor in flight.actors.get_children():
		var danger := false
		var source := Vector3.ZERO
		var message := ""
		if actor is FlightSentry and actor.windup > 0:
			danger = true
			source = actor.position
			message = "SENTRY LOCK"
		elif actor is FlightLane and (actor.warning > 0 or actor.firing > 0):
			danger = true
			source = actor.lane_start
			message = "METEOR LANE" if actor.meteor else "BEAM INBOUND"
		if danger:
			marker(source, message, Color("ffc780"), true)
			if camera.is_position_behind(source):
				behind_warning = true
		if actor is FlightLeviathan:
			for i in 3:
				if not actor.cracked[i] and not camera.is_position_behind(actor.vent_position(i)):
					var point := camera.unproject_position(actor.vent_position(i))
					if Rect2(60, 145, 1160, 420).has_point(point):
						draw_arc(point, 12, 0, TAU, 24, RED, 2, true)
						label_at(point + Vector2(17, 4), "VENT %d" % (i + 1), RED)
	if behind_warning:
		draw_arc(Vector2(640, 350), 212, 0.25, PI - 0.25, 48, Color(1, 0.65, 0.3, 0.7), 3, true)
		label_at(Vector2(546, 584), "!  THREAT BEHIND — EVADE", Color("ffc780"), 13)
	if pilot.boundary_warning:
		label_at(Vector2(500, 190), "LEAVING SALVAGE ZONE", RED, 17)
	if damage_left > 0:
		var relative := camera.to_local(damage_origin)
		var direction := Vector2(relative.x, -relative.y).normalized()
		if direction.length() < 0.01:
			direction = Vector2.DOWN
		var angle := direction.angle()
		draw_arc(Vector2(640, 365), 245, angle - 0.35, angle + 0.35, 24, Color(1, 0.3, 0.25, damage_left), 12, true)
	_draw_radar()
	label_at(Vector2(72, 664), "%03d m/s" % pilot.velocity.length(), MINT, 22)
	label_at(Vector2(72, 687), "ALT %+04d m   /   ZONE %03d m" % [pilot.position.y, pilot.position.length()], Color("8da9b6"))
	label_at(Vector2(1010, 664), "CHASE / FREE FLIGHT", Color("8da9b6"))
	label_at(Vector2(1010, 685), "Y: INVERTED" if pilot.invert_y else "Y: NORMAL", MINT)
	if flight.game.dock_progress > 0:
		draw_arc(Vector2(640, 350), 34, -PI / 2, -PI / 2 + TAU * flight.game.dock_progress, 48, MINT, 3, true)
		label_at(Vector2(585, 402), "BANKING CARGO", MINT)
func _draw_radar() -> void:
	var outline := PackedVector2Array()
	for i in 65:
		outline.append(RADAR + Vector2(cos(i * TAU / 64) * 140, sin(i * TAU / 64) * 45))
	draw_colored_polygon(outline, Color(0.015, 0.04, 0.065, 0.87))
	draw_polyline(outline, Color("355968"), 1, true)
	draw_line(RADAR - Vector2(139, 0), RADAR + Vector2(139, 0), Color("294550"))
	draw_line(RADAR - Vector2(0, 44), RADAR + Vector2(0, 44), Color("294550"))
	label_at(RADAR + Vector2(-70, 63), "SCANNER  /  ±200 m", Color("89a6b3"), 10)
	radar_blip(Vector3.ZERO, MINT, 4)
	for actor in flight.actors.get_children():
		if actor is FlightCore and not actor.taken:
			radar_blip(actor.position, GOLD, 2.5)
		elif actor is FlightRock:
			radar_blip(actor.position, Color("758693"), 2)
		elif actor is FlightSentry:
			radar_blip(actor.position, RED, 3)
		elif actor is FlightWell:
			radar_blip(actor.position, Color("b1a0ff"), 5)
		elif actor is FlightLeviathan:
			radar_blip(actor.position, RED, 6)
	draw_colored_polygon(PackedVector2Array([RADAR + Vector2(0, -5), RADAR + Vector2(-4, 4), RADAR + Vector2(4, 4)]), MINT)
func radar_blip(point: Vector3, color: Color, radius: float) -> void:
	var offset := (point - flight.pilot.position).rotated(Vector3.UP, -flight.pilot.yaw)
	var plane := Vector2(offset.x, offset.z).limit_length(200)
	var base := RADAR + Vector2(plane.x * 0.65, plane.y * 0.2)
	var tip := base - Vector2(0, clampf(offset.y * 0.25, -27, 27))
	draw_line(base, tip, Color(color, 0.7), 1, true)
	draw_circle(base, 1, Color(color, 0.45))
	draw_circle(tip, radius, color)
	blip_count += 1

func radar_contacts() -> Array[Vector3]:
	var contacts: Array[Vector3] = [Vector3.ZERO]
	for actor in flight.actors.get_children():
		if (actor is FlightCore and not actor.taken) or actor is FlightRock or actor is FlightSentry or actor is FlightWell or actor is FlightLeviathan:
			contacts.append(actor.position)
	return contacts

func is_offscreen(point: Vector3) -> bool:
	return flight.chase.camera.is_position_behind(point) or not Rect2(55, 200, 1170, 355).has_point(flight.chase.camera.unproject_position(point))
