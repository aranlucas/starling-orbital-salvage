extends Node2D
## Project effects, vent targets and navigation through the exact render camera.
var presenter: OrbitPresenter
var effects: FlightEffects
func _draw() -> void:
	if presenter.hub or not presenter.visible:
		return
	if effects:
		for particle in effects.particles:
			draw_circle(presenter.project(particle.point), 2, Color(particle.color, particle.life / 0.7))
		for wave in effects.waves:
			var points := PackedVector2Array()
			var progress: float = 1 - wave.life / 0.6
			var radius: float = wave.radius if presenter.reduced_motion else lerpf(12, wave.radius, progress)
			for i in 65:
				points.append(presenter.project(wave.point + Vector2.from_angle(i * TAU / 64) * radius))
			draw_polyline(points, Color(wave.color, 1 - progress), 2, true)
		var occupied: Array[Rect2] = []
		for callout in effects.callouts:
			var point := presenter.project(callout.point) - Vector2(0, 24)
			var width := ThemeDB.fallback_font.get_string_size(callout.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			point.x = clampf(point.x, 44, 1236 - width)
			var bounds := Rect2(point - Vector2(0, 17), Vector2(width, 22))
			for attempt in 8:
				var overlaps := false
				for previous in occupied:
					if previous.intersects(bounds):
						overlaps = true
				if not overlaps:
					break
				bounds.position.y -= 24
			bounds.position.y = maxf(150, bounds.position.y)
			occupied.append(bounds)
			draw_string(ThemeDB.fallback_font, bounds.position + Vector2(0, 17), callout.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, callout.color)
	if presenter.bank_progress > 0:
		draw_arc(presenter.project(Vector2(640, 431)), 36, -PI / 2, -PI / 2 + TAU * presenter.bank_progress, 64, Color("78f5dd"), 4, true)
	var dock_point := presenter.project(Vector2(640, 431))
	draw_string(ThemeDB.fallback_font, dock_point + Vector2(-32, 48), "SAFE DOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("78f5dd"))
	if presenter.navigation != Vector2.ZERO and is_instance_valid(presenter.pilot):
		var start := presenter.project(presenter.pilot.position)
		var end := presenter.project(presenter.navigation)
		if start.distance_to(end) > 75:
			var direction := start.direction_to(end)
			var tip := start + direction * 36
			draw_polyline(PackedVector2Array([tip - direction * 7 + direction.orthogonal() * 4, tip, tip - direction * 7 - direction.orthogonal() * 4]), Color("f3c77b"), 2, true)
	for actor in presenter.sim.get_children():
		if actor is MeteorStorm and actor.warning > 0:
			var point := presenter.project(actor.lane_start.lerp(actor.lane_end, 0.14))
			draw_string(ThemeDB.fallback_font, point + Vector2(-20, -18), "!  METEOR LANE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffc780"))
