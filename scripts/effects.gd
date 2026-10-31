class_name FlightEffects
extends Node2D
## Short-lived particles, shockwaves, and score callouts; capped to keep runs cheap.

var particles: Array[Dictionary] = []
var waves: Array[Dictionary] = []
var callouts: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var reduced_motion := false


func burst(point: Vector2, color: Color, count: int = 16) -> void:
	if reduced_motion:
		count = mini(count, 6)
	for i in mini(count, 300 - particles.size()):
		particles.append({"point": point, "velocity": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(35, 190), "life": 0.7, "color": color})


func wave(point: Vector2, radius: float, color: Color) -> void:
	waves.append({"point": point, "radius": radius, "life": 0.6, "color": color})


func callout(point: Vector2, text: String, color: Color) -> void:
	if callouts.size() < 24:
		callouts.append({"point": point, "text": text, "color": color, "life": 1.0})


func tick(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		particles[i].life -= delta
		particles[i].point += particles[i].velocity * delta
		if particles[i].life <= 0:
			particles.remove_at(i)
	for i in range(waves.size() - 1, -1, -1):
		waves[i].life -= delta
		if waves[i].life <= 0:
			waves.remove_at(i)
	for i in range(callouts.size() - 1, -1, -1):
		callouts[i].life -= delta
		callouts[i].point.y -= delta * 25
		if callouts[i].life <= 0:
			callouts.remove_at(i)
	queue_redraw()


func clear() -> void:
	particles.clear()
	waves.clear()
	callouts.clear()


func _draw() -> void:
	for particle in particles:
		draw_circle(particle.point, 2, Color(particle.color, particle.life / 0.7))
	for ring in waves:
		var progress: float = 1 - ring.life / 0.6
		var radius: float = ring.radius if reduced_motion else lerpf(12, ring.radius, progress)
		draw_arc(ring.point, radius, 0, TAU, 96, Color(ring.color, 1 - progress), 3, true)
	for text in callouts:
		draw_string(ThemeDB.fallback_font, text.point, text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(text.color, minf(1, text.life * 3)))
