class_name DeepFlight
extends Node3D
## Owns only Deep Orbit's world. Expedition and all menus remain shared.
var game: Node
var actors: Node3D
var pilot: FlightPilot
var chase: FlightCamera
var scanner: FlightScanner
var dressing: FlightDressing
var dock: Area3D
var dock_ring: MeshInstance3D
var pulse_ring: MeshInstance3D
var pulse_rings: Array[MeshInstance3D] = []
var pulse_origin := Vector3.ZERO
var pulse_left := 0.0
var boss: FlightLeviathan
func _ready() -> void:
	FlightVisuals.environment(self)
	actors = Node3D.new()
	add_child(actors)
func build() -> void:
	for actor in actors.get_children():
		actors.remove_child(actor)
		actor.queue_free()
	for child in [chase, scanner, dressing, dock]:
		if is_instance_valid(child):
			remove_child(child)
			child.queue_free()
	boss = null
	pilot = FlightPilot.new()
	pilot.configure(game.run.upgrades, game.carried_hull, game.run.frame, game.run.plating)
	pilot.reduced_motion = game.profile.reduced_motion
	pilot.invert_y = game.profile.invert_y
	pilot.position = Vector3(0, 3, 12)
	pilot.damaged.connect(_on_damage)
	pilot.destroyed.connect(func() -> void: game._finish(false, "The hull gave out before the cargo made it home."))
	pilot.dashed.connect(func() -> void: game.sound.play("dash"))
	pilot.pulse_fired.connect(pulse)
	actors.add_child(pilot)
	chase = FlightCamera.new()
	chase.pilot = pilot
	add_child(chase)
	scanner = FlightScanner.new()
	scanner.flight = self
	add_child(scanner)
	dressing = FlightDressing.new()
	dressing.pilot = pilot
	add_child(dressing)
	dock = Area3D.new()
	dock.collision_layer = 0
	dock.collision_mask = 1
	FlightVisuals.sphere_shape(dock, 10)
	add_child(dock)
	var beacon := ModelAssets.model("dock_beacon", "energy_core")
	beacon.scale = Vector3.ONE * 4
	dock.add_child(beacon)
	dock_ring = FlightVisuals.ring(dock, 10, Color("78f5dd"))
	var vertical := FlightVisuals.ring(dock, 10, Color("497e78"))
	vertical.rotation.z = PI / 2
	pulse_rings.clear()
	for i in 3:
		var ring := FlightVisuals.ring(actors, 1, Color("b1a0ff"))
		ring.rotation = Vector3(PI / 2 if i == 1 else 0.0, 0, PI / 2 if i == 2 else 0.0)
		ring.visible = false
		ring.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pulse_rings.append(ring)
	pulse_ring = pulse_rings[0]
	_build_features()
	var sector: Dictionary = game.run.sector()
	for i in (6 if game.run.sector_index == 3 else int(sector.quota)):
		spawn_core(safe_point())
	for i in int(sector.rocks):
		var rock := FlightRock.new()
		rock.pilot = pilot
		rock.position = safe_point()
		rock.radius = game.rng.randf_range(2.8, 5)
		rock.velocity = Vector3(game.rng.randf_range(-1, 1), game.rng.randf_range(-0.5, 0.5), game.rng.randf_range(-1, 1)).normalized() * game.rng.randf_range(6, 11)
		rock.shattered.connect(shatter)
		actors.add_child(rock)
	for i in int(sector.drones):
		var sentry := FlightSentry.new()
		sentry.pilot = pilot
		sentry.position = Vector3(-65 if i == 0 else 65, 15 if i == 0 else -25, -85)
		sentry.cycle += i * 1.7
		sentry.shattered.connect(shatter)
		actors.add_child(sentry)
	for i in int(game.run.upgrades.wing):
		var wing := FlightWing.new()
		wing.pilot = pilot
		wing.phase = i * PI
		actors.add_child(wing)
		wing._physics_process(0)
func _build_features() -> void:
	if game.run.sector_index == 1:
		for point in [Vector3(-65, 0, -65), Vector3(65, 0, -65), Vector3(-85, 0, 65), Vector3(85, 0, 65), Vector3(0, 0, -130)]:
			var spire := FlightSpire.new()
			spire.position = point
			actors.add_child(spire)
	elif game.run.sector_index == 2:
		var well := FlightWell.new()
		well.pilot = pilot
		well.position = Vector3(80, 0, -25)
		well.consumed.connect(func(_core: FlightCore) -> void: spawn_core.call_deferred(safe_point()))
		well.inverted.connect(func() -> void:
			game.sound.play("inversion")
			game.hud.notice("WELL INVERTED / 1.5s outward flow", Color("78f5dd"), 1.5))
		actors.add_child(well)
		var lane := FlightLane.new()
		lane.pilot = pilot
		lane.warned.connect(func() -> void:
			game.sound.play("warning")
			game.hud.notice("METEOR INBOUND / Leave the amber cylinder", Color("ffc780"), 1.4))
		lane.deflected.connect(shatter)
		actors.add_child(lane)
	elif game.run.sector_index == 3:
		boss = FlightLeviathan.new()
		boss.pilot = pilot
		boss.core_shed.connect(func(point: Vector3) -> void: spawn_core.call_deferred(point))
		boss.vent_cracked.connect(func(point: Vector3) -> void:
			game.run.score += 400
			game.sound.play("vent")
			game.hud.notice("VENT CRACKED / +400 · 3 CORES RELEASED", Color("78f5dd"), 2)
			for i in 3:
				spawn_core.call_deferred(point + Vector3((i - 1) * 7, 8, 0)))
		boss.silenced.connect(func() -> void:
			game.run.score += 1500
			game.sound.play("win")
			game.hud.notice("LEVIATHAN SILENCED / +1500 · Bring the light home", Color("78f5dd"), 5))
		actors.add_child(boss)
		boss.beam_lane.warned.connect(func() -> void:
			game.sound.play("beam")
			game.hud.notice("BEAM INBOUND / Leave the amber cylinder", Color("ffc780"), 1.4))
func set_active(enabled: bool) -> void:
	pilot.active = enabled
	pilot.mouse_captured = enabled
	process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE
func _process(delta: float) -> void:
	if not is_instance_valid(pilot):
		return
	pulse_left = maxf(0, pulse_left - delta)
	for ring in pulse_rings:
		ring.visible = pulse_left > 0
		if pulse_left > 0:
			var size := pilot.pulse_radius if pilot.reduced_motion else lerpf(1, pilot.pulse_radius, 1 - pulse_left / 0.6)
			ring.mesh.inner_radius = size - 0.08
			ring.mesh.outer_radius = size + 0.08
			ring.position = pulse_origin
			ring.material_override.albedo_color = Color(0.69, 0.66, 1, pulse_left / 0.6)
	dock_ring.scale = Vector3.ONE * (1 + game.dock_progress * 0.08)
func update_dock(delta: float) -> void:
	if game.run.cargo > 0 and pilot.position.length() < 10:
		game.dock_progress = minf(1, game.dock_progress + delta / game.run.bank_seconds())
		if game.dock_progress >= 1:
			var count: int = game.run.bank_cargo()
			pilot.cargo_load = 0
			game.dock_progress = 0
			game.sound.play("dock")
			game.hud.notice("%d CORES BANKED / +%d" % [count, count * 50], Color("78f5dd"), 2)
			if game.run.quota_met():
				game._complete_sector()
	else:
		game.dock_progress = 0
func cores() -> Array[FlightCore]:
	var result: Array[FlightCore] = []
	for actor in actors.get_children():
		if actor is FlightCore and not actor.taken:
			result.append(actor)
	return result
func navigation_target() -> Vector3:
	if game.run.cargo >= 4 or game.run.cargo + game.run.banked >= int(game.run.sector().quota):
		return Vector3.ZERO
	var nearest := Vector3.ZERO
	var distance := INF
	for core in cores():
		var next := core.position.distance_squared_to(pilot.position)
		if next < distance:
			distance = next
			nearest = core.position
	return nearest
func safe_point() -> Vector3:
	for attempt in 100:
		var angle: float = game.rng.randf() * TAU
		var height: float = game.rng.randf_range(-70, 70)
		var distance: float = game.rng.randf_range(65, 165)
		var point := Vector3(cos(angle) * distance, height, sin(angle) * distance)
		if point.length() > 180:
			point = point.normalized() * 180
		var valid := true
		for actor in actors.get_children():
			if actor is FlightSpire and Vector2(point.x - actor.position.x, point.z - actor.position.z).length() < 13:
				valid = false
			elif actor is FlightWell and point.distance_to(actor.position) < 26:
				valid = false
			elif actor is FlightLeviathan and point.distance_to(actor.position) < 60:
				valid = false
		if valid:
			return point
	return Vector3(0, 60, 100)
func spawn_core(point: Vector3) -> void:
	var core := FlightCore.new()
	core.position = point
	core.pilot = pilot
	core.collected.connect(_on_core)
	actors.add_child(core)
func _on_core(_core: FlightCore) -> void:
	if game.state != "running":
		return
	game.run.collect()
	pilot.cargo_load = game.run.cargo
	game.sound.play("core", 1 + game.run.multiplier() * 0.08)
	if game.run.free_pulse_due():
		pulse()
	if game.first_pickup:
		game.first_pickup = false
		game.hud.notice("CARGO ABOARD / Chain pickups, then fly home to the mint dock", Color("f3c77b"), 3)
func pulse() -> void:
	pilot.invulnerability = maxf(pilot.invulnerability, 0.35)
	pulse_left = 0.6
	pulse_origin = pilot.position
	for actor in actors.get_children():
		if actor.has_method("receive_pulse"):
			actor.receive_pulse(pilot.position, pilot.pulse_radius)
	game.sound.play("pulse")
func shatter(_point: Vector3, points: int) -> void:
	if game.state != "running":
		return
	game.run.score += points
	if pilot.dash_remaining > 0:
		game.time_left += 1.5 * int(game.run.upgrades.ram)
	game.sound.play("shatter")
	game.hud.notice("+%d SHATTER" % points, Color("ffc780"), 1)
func _on_damage() -> void:
	game.run.break_chain()
	chase.shake = 1
	scanner.damage_left = 1
	scanner.damage_origin = pilot.damage_origin
	game.sound.play("hit")
	game.hud.notice("HULL HIT / Chain reset. Dash or pulse to make space", Color("ffaaa0"), 2)
