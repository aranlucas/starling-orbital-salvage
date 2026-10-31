extends SceneTree
## Real input and physics-overlap integration; isolated saves. Native runs capture chase views.
const GameScene := preload("res://scenes/main.tscn")
var game: Node2D
var flight: DeepFlight
var pilot: FlightPilot
var checks := 0
var failures := 0
var profile_path := "user://starling-flight3d-%d.cfg" % OS.get_process_id()
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	game = GameScene.instantiate()
	game.profile.path = profile_path
	game.auto_pause = false
	root.add_child(game)
	await process_frame
	game.profile.muted = true
	game.sound.muted = true
	game.profile.owned.assign(FlightProfile.ITEMS.keys())
	game.profile.selected_route = "deep"
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_move_to_foreground()
		await create_timer(0.2).timeout
	game.rng.seed = 315
	game.start_mission()
	# A predictable starting build, without Launch Rig's random card.
	for id in game.run.upgrades:
		game.run.upgrades[id] = 0
	game._launch_sector()
	_sync()
	_freeze()
	await _steps(3)
	_check(pilot is CharacterBody3D and flight.cores().size() == 9 and game.world.get_child_count() == 0, "Deep Orbit has real 3D actors and no flat simulation")
	_check(not game.presenter.visible and flight.visible and flight.chase.camera.current, "Deep Orbit uses its own chase camera")
	_check(_captured(), "Active flight captures the mouse")
	var min_height := INF
	var max_height := -INF
	var shell := true
	for core in flight.cores():
		min_height = minf(min_height, core.position.y)
		max_height = maxf(max_height, core.position.y)
		shell = shell and core.position.length() >= 60 and core.position.length() <= 180.1
	_check(shell and max_height - min_height > 70, "Core shell fills a 3D volume with distinct heights")
	await _capture("shelf")
	var start := pilot.position
	await _hold(KEY_W, 0.5)
	_check(pilot.position.z < start.z - 7 and pilot.velocity.length() > 30, "W accelerates forward toward 38 m/s")
	await create_timer(0.5).timeout
	_check(pilot.velocity.length() < 0.1, "Light inertia settles promptly when thrust is released")
	start = pilot.position
	await _hold(KEY_D, 0.3)
	_check(pilot.position.x > start.x + 3, "D strafes independently of steering")
	await _hold(KEY_S, 0.35)
	_check(pilot.velocity.dot(pilot.basis.z) > 2, "S brakes then enables slow reverse")
	var yaw := pilot.yaw
	await _hold(KEY_RIGHT, 0.4)
	_check(pilot.yaw < yaw - 0.3, "Keyboard-only yaw steering works")
	await _hold(KEY_UP, 1.2)
	_check(pilot.pitch > deg_to_rad(65) and pilot.pitch <= deg_to_rad(75), "Pitch steers upward and clamps at +75 degrees")
	await _hold(KEY_DOWN, 2.0)
	_check(pilot.pitch >= deg_to_rad(-75) and pilot.pitch < deg_to_rad(-65), "Pitch also clamps at -75 degrees")
	await create_timer(0.65).timeout
	_check(absf(pilot.model.rotation.z) < 0.02 and is_zero_approx(pilot.rotation.z), "Cosmetic banking auto-levels without rolling the flight frame")
	# Regain native window focus before the mouse-only check. Other desktop apps
	# may take focus during the long keyboard sequence; production auto-pauses.
	await _key(KEY_P)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_move_to_foreground()
		await create_timer(0.1).timeout
	await _key(KEY_ESCAPE)
	pilot.pitch = 0
	pilot.yaw = 0
	pilot.steering = Vector2.ZERO
	pilot.mouse_rate = Vector2.ZERO
	# A drag spans several actual input/physics frames, as a human mouse does.
	for i in 8:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(9, -4)
		motion.screen_relative = motion.relative
		Input.parse_input_event(motion)
		await _steps(1)
	await _steps(8)
	_check(pilot.yaw < -0.05 and pilot.pitch > 0.01, "Real captured mouse motion steers smoothly (yaw %.3f, pitch %.3f)" % [pilot.yaw, pilot.pitch])
	await _key(KEY_I)
	var loaded := FlightProfile.new()
	loaded.path = profile_path
	loaded.load_profile()
	_check(pilot.invert_y and loaded.invert_y, "I toggles invert-Y and saves it")
	await _key(KEY_I)
	pilot.pitch = 0
	pilot.yaw = 0
	pilot.position = Vector3(198, 20, 0)
	pilot.velocity = Vector3.ZERO
	pilot.gravity_velocity = Vector3.ZERO
	await create_timer(0.5).timeout
	_check(pilot.boundary_warning and pilot.gravity_velocity.x < -10 and pilot.position.x < 198, "Outer boundary warns and softly pushes inward")
	pilot.position = Vector3(25, 0, 40)
	pilot.velocity = Vector3.ZERO
	pilot.gravity_velocity = Vector3.ZERO
	await create_timer(0.4).timeout
	pilot.cooldown = 0
	await _key(KEY_SPACE)
	_check(pilot.dash_remaining > 0 and pilot.velocity.length() > 100 and pilot.cooldown > 0, "Space starts a 110 m/s dash with cooldown")
	var health := pilot.health
	pilot.hit()
	_check(pilot.health == health, "Dash grants hull immunity")
	await _capture("dash")
	await create_timer(0.3).timeout
	pilot.position = Vector3(25, 0, 45)
	pilot.velocity = Vector3.ZERO
	pilot.gravity_velocity = Vector3.ZERO
	var rock: FlightRock = _actors(FlightRock)[0]
	var core := flight.cores()[0]
	rock.position = pilot.position + Vector3(14, 0, 0)
	core.position = pilot.position + Vector3(18, 0, 0)
	pilot.pulse_cooldown = 0
	await _key(KEY_E)
	_check(rock.velocity.length() >= 35 and core.pull_boost > 0.7 and pilot.pulse_cooldown > 0, "Ion sphere scatters rocks and attracts cores")
	await create_timer(0.4).timeout
	pilot.invulnerability = 0
	rock.position = pilot.position
	rock.velocity = Vector3.ZERO
	rock.set_physics_process(true)
	health = pilot.health
	await _steps(4)
	_check(pilot.health == health - 1 and flight.scanner.damage_left > 0, "Real rock/body overlap damages once and flashes its direction")
	pilot.invulnerability = 999
	pilot.cooldown = 0
	rock.position = pilot.position + Vector3(0, 0, -3)
	var score: int = game.run.score
	await _key(KEY_SPACE)
	await _steps(3)
	_check(not is_instance_valid(rock) and game.run.score >= score + 75, "Input-driven dash shatters an overlapping 3D rock")
	await _key(KEY_P)
	var clock: float = game.time_left
	start = pilot.position
	await create_timer(0.08).timeout
	_check(game.state == "paused" and game.time_left == clock and pilot.position == start and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Pause freezes flight and releases the mouse")
	await _key(KEY_ESCAPE)
	_check(game.state == "running" and _captured(), "Resume recaptures the mouse")
	game.auto_pause = true
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.auto_pause = false
	_check(game.state == "paused" and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Focus loss pauses and releases capture")
	await _key(KEY_P)
	await _key(KEY_F2)
	pilot.yaw = 0.6
	flight.chase.shake = 1
	await process_frame
	_check(flight.chase.camera.fov == 72 and flight.chase.quaternion.is_equal_approx(pilot.quaternion) and flight.chase.camera.h_offset == 0, "Reduced motion removes FOV kicks, shake and camera lag")
	await _key(KEY_F2)
	await _key(KEY_F3)
	_check(flight.visible and not game.presenter.visible, "F3 does not replace free flight with the Survey presenter")
	await _test_sentry()
	await _test_scanner()
	# A clean complete expedition: every collection uses physics overlaps.
	game.start_mission()
	for id in game.run.upgrades:
		game.run.upgrades[id] = 0
	game._launch_sector()
	_sync()
	_freeze()
	await _collect(2)
	_check(game.run.cargo == 2 and game.run.chain == 2 and game.run.banked == 0, "3D pickups use shared cargo and chain rules")
	pilot.position = Vector3.ZERO
	pilot.velocity = Vector3.ZERO
	await create_timer(0.15).timeout
	_check(game.dock_progress > 0 and game.run.cargo == 2, "3D docking takes time")
	pilot.position = Vector3(20, 0, 0)
	await _steps(2)
	_check(game.dock_progress == 0, "Leaving the 10m dock resets banking")
	await _dock()
	_check(game.run.banked == 2 and game.run.cargo == 0, "Partial 3D deliveries bank correctly")
	await _collect()
	await _dock()
	_check(game.state == "upgrade" and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Quota completion opens the shared draft and releases the mouse")
	await _advance()
	await _test_spires()
	await _collect()
	await _dock()
	await _advance()
	await _test_well()
	await _collect()
	pilot.gravity_velocity = Vector3.ZERO
	pilot.external_force = Vector3.ZERO
	await _dock()
	await _advance()
	await _test_boss()
	await _collect()
	await _dock()
	_check(game.state == "won" and game.run.sectors_cleared == 4 and game.run.total_banked >= 42, "Full 3D route through Leviathan wins with every quota delivered")
	_check(game.profile.last_scrap == game.profile.payout(game.run.total_banked, 4, true, "deep") and game.profile.route_records.has("deep"), "3D victory records rank and pays the exact shared Scrap formula")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Results release mouse capture")
	await _capture("victory")
	await _test_cards()
	await _measure_performance()
	game.return_to_roost()
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and game.presenter.visible and not flight.visible, "The Roost restores its presenter and visible mouse")
	game.profile.selected_route = "survey"
	game.start_mission()
	_check(game.pilot is Pilot and not is_instance_valid(game.flight), "Returning to Survey restores the original 2D pilot")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))
	print("STARLING FREE FLIGHT TEST: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
func _test_scanner() -> void:
	pilot.position = Vector3(0, 0, 50)
	pilot.pitch = 0
	pilot.yaw = 0
	pilot.steering = Vector2.ZERO
	pilot.velocity = Vector3.ZERO
	pilot.gravity_velocity = Vector3.ZERO
	var core := flight.cores()[0]
	core.position = Vector3(15, 22, 100)
	await _steps(4)
	await _capture("radar")
	if DisplayServer.get_name() != "headless":
		_check(flight.scanner.blip_count == flight.cores().size() + _actors(FlightRock).size() + _actors(FlightSentry).size() + 1, "Radar shows cores, rocks, sentries and dock with height stalks")
		_check(flight.scanner.edge_count > 0, "Off-screen targets receive screen-edge indicators")
	else:
		_check(flight.scanner.radar_contacts().size() == flight.cores().size() + _actors(FlightRock).size() + _actors(FlightSentry).size() + 1, "Radar contact model includes all live cores, hazards and dock")
		_check(flight.scanner.is_offscreen(core.position), "Radar navigation recognizes a target behind the camera")
func _test_spires() -> void:
	_check(_actors(FlightSpire).size() == 5, "Foundry sector contains five 150m solid spires")
	var spire: FlightSpire = _actors(FlightSpire)[0]
	pilot.position = spire.position + Vector3(9, 0, 0)
	pilot.yaw = 0
	pilot.pitch = 0
	pilot.steering = Vector2.ZERO
	pilot.velocity = Vector3.ZERO
	var health := pilot.health
	await _hold(KEY_A, 0.45)
	_check(pilot.position.x >= spire.position.x + 7.2 and pilot.health == health, "Spires block strafing and slide without hull damage")
	pilot.position = spire.position
	pilot.dash_remaining = 0.2
	await _steps(3)
	_check(is_instance_valid(spire) and Vector2(pilot.position.x - spire.position.x, pilot.position.z - spire.position.z).length() >= 7.2, "Dash cannot break or remain inside a spire")
	var rock: FlightRock = _actors(FlightRock)[0]
	rock.position = spire.position + Vector3(7, 0, 0)
	rock.velocity = Vector3(-10, 0, 0)
	await _steps(3)
	_check(rock.velocity.x > 0, "Drifting rocks bounce off spires")
	var clear := true
	for core in flight.cores():
		for tower in _actors(FlightSpire):
			clear = clear and Vector2(core.position.x - tower.position.x, core.position.z - tower.position.z).length() > 13
	_check(clear, "Cores spawn clear of spire cylinders")
	pilot.position = Vector3(10, 25, 75)
	pilot.dash_remaining = 0
	pilot.velocity = Vector3.ZERO
	flight.chase.reset()
	await _capture("spires")
func _test_well() -> void:
	var well: FlightWell = _actors(FlightWell)[0]
	pilot.position = well.position + Vector3(-45, 0, 0)
	pilot.velocity = Vector3.ZERO
	pilot.gravity_velocity = Vector3.ZERO
	var distance := pilot.position.distance_to(well.position)
	await create_timer(0.4).timeout
	_check(pilot.position.distance_to(well.position) < distance - 1, "The spherical well pulls an idle ship")
	var core := flight.cores()[0]
	core.position = well.position + Vector3(0, 45, 0)
	distance = core.position.distance_to(well.position)
	await create_timer(0.1).timeout
	_check(core.position.distance_to(well.position) < distance, "Well gravity drags cores vertically as well as horizontally")
	pilot.invulnerability = 0
	pilot.position = well.position + Vector3(5, 0, 0)
	var health := pilot.health
	await _steps(4)
	_check(pilot.health == health - 1 and pilot.gravity_velocity.length() > 65 and pilot.position.distance_to(well.position) > 12, "Real horizon overlap damages once and flings outward")
	pilot.invulnerability = 999
	var count := flight.cores().size()
	core.position = well.position
	await _steps(4)
	_check(not is_instance_valid(core) and flight.cores().size() == count, "Consumed cores respawn without reducing available salvage")
	pilot.position = well.position + Vector3(-28, 0, 0)
	pilot.velocity = Vector3.ZERO
	pilot.gravity_velocity = Vector3.ZERO
	pilot.pulse_cooldown = 0
	await _key(KEY_E)
	_check(well.inversion > 1.4 and well.force_at(well.position + Vector3(0, 35, 0)).y > 0, "A real E pulse reverses spherical gravity for 1.5 seconds")
	pilot.position = Vector3(-20, 12, 55)
	pilot.pitch = 0
	pilot.yaw = -0.55
	flight.chase.reset()
	await _capture("well")
	await create_timer(1.52).timeout
	_check(well.inversion == 0 and well.force_at(well.position + Vector3(35, 0, 0)).x < 0, "Gravity resumes when inversion expires")
	var lane: FlightLane = _actors(FlightLane)[0]
	lane.set_physics_process(true)
	pilot.position = Vector3(-40, 35, 70)
	pilot.velocity = Vector3.ZERO
	pilot.gravity_velocity = Vector3.ZERO
	lane.begin(pilot.position + Vector3(0, 0, 150), pilot.position - Vector3(0, 0, 150))
	_check(lane.warning == 1.4 and lane.firing == 0 and lane.shape.shape is CylinderShape3D, "Meteor telegraphs use a real volumetric cylinder")
	pilot.invulnerability = 0
	health = pilot.health
	well.set_physics_process(false)
	await _steps(92)
	print("METEOR SAMPLE: warning=", lane.warning, " fire=", lane.firing, " hp=", pilot.health, " expected=", health - 1, " position=", pilot.position, " overlap=", pilot in lane.get_overlapping_bodies())
	_check(lane.firing > 0 and pilot.health == health - 1, "Meteor warning becomes a damaging physics-overlap lane")
	pilot.invulnerability = 999
	lane.set_physics_process(false)
func _test_boss() -> void:
	var boss := flight.boss
	_check(boss != null and flight.cores().size() == 6 and flight.cores().all(func(core: FlightCore) -> bool: return core.position.distance_to(boss.position) >= 60), "Leviathan starts with six loose cores clear of its initial patrol position")
	_check(ModelAssets.part(boss.model, "Vent_0") != null and boss.vents.size() == 3 and boss.vent_position(0).distance_to(boss.position) > 5, "Vent targets come from imported Vent_0..2 child transforms")
	pilot.position = Vector3(32, 38, -15)
	pilot.yaw = 0
	pilot.pitch = 0.12
	pilot.velocity = Vector3.ZERO
	pilot.gravity_velocity = Vector3.ZERO
	flight.chase.reset()
	await _capture("leviathan")
	boss.set_physics_process(true)
	boss.beam_lane.set_physics_process(true)
	var original := boss.position
	pilot.position = Vector3(0, 35, 80)
	pilot.yaw = 0
	pilot.pitch = 0
	flight.chase.reset()
	boss.begin_beam()
	_check(boss.beam_lane.warning > 1.3 and boss.beam_lane.firing == 0, "Boss beams warn for 1.4 seconds before firing")
	# Look away: the incoming emitter is behind the camera.
	pilot.yaw = PI
	await create_timer(0.25).timeout
	await _capture("beam-behind")
	if DisplayServer.get_name() != "headless":
		_check(flight.scanner.behind_warning, "A beam from behind triggers the warning ring and edge label")
	pilot.invulnerability = 0
	var health := pilot.health
	await create_timer(1.22).timeout
	_check(boss.beam_lane.firing > 0 and pilot.health == health - 1, "Warned boss beam damages the ship through actual cylinder overlap")
	_check(boss.position.distance_to(original) > 1, "Leviathan patrols in three dimensions")
	pilot.invulnerability = 999
	var available: int = flight.cores().size() + game.run.cargo
	boss.shed_clock = 0.01
	await _steps(4)
	_check(flight.cores().size() + game.run.cargo == available + 1, "The hulk sheds a collectible every eight seconds")
	pilot.position = boss.position
	pilot.velocity = Vector3.ZERO
	pilot.gravity_velocity = Vector3.ZERO
	pilot.invulnerability = 0
	health = pilot.health
	await _steps(4)
	_check(pilot.health == health - 1 and pilot.position.distance_to(boss.position) > 8, "Hull contact damages and separates an undashing pilot")
	pilot.invulnerability = 999
	boss.set_physics_process(false)
	boss.beam_lane.set_physics_process(false)
	var before: int = game.run.score
	for i in 3:
		pilot.position = boss.vent_position(i) + Vector3(0, 0, 5)
		pilot.pitch = 0
		pilot.yaw = 0
		pilot.steering = Vector2.ZERO
		pilot.velocity = Vector3.ZERO
		pilot.gravity_velocity = Vector3.ZERO
		pilot.dash_remaining = 0
		pilot.cooldown = 0
		await _steps(3)
		boss.set_physics_process(true)
		await _key(KEY_SPACE)
		await _steps(3)
		boss.set_physics_process(false)
		_check(boss.cracked[i], "Input-driven dash cracks vent %d through a real 3D overlap" % i)
	_check(boss.is_silenced and boss.cracked == [true, true, true] and game.run.score >= before + 2700, "Three vents award 400 each plus 1500 SILENCED")
	_check(not boss.beam_lane.enabled and boss.beam_lane.warning == 0 and boss.beam_lane.firing == 0, "SILENCED cancels and permanently disables beams")
	_check(flight.cores().size() + game.run.cargo >= 15, "Each vent spills three recoverable cores")
	boss.begin_beam()
	_check(boss.beam_lane.warning == 0, "A silenced hulk cannot start a new beam")
	pilot.position = boss.position + Vector3(24, 18, 28)
	pilot.yaw = 0.55
	pilot.pitch = -0.15
	pilot.dash_remaining = 0
	pilot.velocity = Vector3.ZERO
	pilot.gravity_velocity = Vector3.ZERO
	flight.chase.reset()
	await _capture("leviathan-close-pass")
func _test_cards() -> void:
	game.start_mission()
	game.run.upgrades.wing = 2
	game.run.upgrades.overdrive = 1
	game.run.upgrades.ram = 2
	game.run.upgrades.ballast = 2
	game.run.upgrades.chrono = 2
	game.run.upgrades.magnet = 2
	game.run.upgrades.pulse = 2
	game._launch_sector()
	_sync()
	_freeze()
	_check(is_equal_approx(pilot.magnet_radius, 45.0 / 6.5 + 20) and pilot.pulse_radius == 56 and is_equal_approx(pilot.dash_duration, 0.45), "Cards convert to noticeable metre ranges and preserve Ram duration")
	_check(game.time_left > 80 and pilot.cargo_drag == 0 and is_equal_approx(game.run.bank_seconds(), 0.3), "Chronometer and Ballast retain their shared rule effects")
	var wings := _actors(FlightWing)
	_check(wings.size() == 2 and wings[0].position.distance_to(pilot.position) >= 10, "Two Salvage Wings orbit in a 3D volume about 11m out")
	pilot.position = Vector3(0, 0, 50)
	pilot.magnet_radius = 0
	await _steps(2)
	var core := flight.cores()[0]
	core.position = wings[0].position
	var cargo: int = game.run.cargo
	await _steps(4)
	_check(game.run.cargo == cargo + 1 and not is_instance_valid(core), "Wing/core Area3D overlap uses the shared collection path")
	for wing in wings:
		wing.set_physics_process(false)
	game.run.chain = 5
	pilot.pulse_cooldown = 4
	var rock: FlightRock = _actors(FlightRock)[0]
	rock.position = pilot.position + Vector3(20, 0, 0)
	core = flight.cores()[0]
	core.position = pilot.position
	await _steps(4)
	_check(rock.velocity.length() >= 35 and pilot.pulse_cooldown < 4 and game.run.chain == 6, "Overdrive's sixth pickup fires a free 3D pulse")
	rock.position = pilot.position + Vector3(0, 0, -3)
	rock.velocity = Vector3.ZERO
	rock.set_physics_process(true)
	pilot.cooldown = 0
	var clock: float = game.time_left
	await _key(KEY_SPACE)
	await _steps(3)
	_check(not is_instance_valid(rock) and game.time_left > clock + 2.7, "Ram Plating adds three seconds on a real dash-shatter")
	pilot.dash_remaining = 0
	pilot.velocity = Vector3.ZERO
	pilot.gravity_velocity = Vector3.ZERO
	game.run.cargo = 2
	pilot.position = Vector3.ZERO
	await create_timer(0.36).timeout
	_check(game.run.cargo == 0 and game.run.banked == 2, "Ballast level two banks in 0.3 seconds in 3D")
	for frame in FlightProfile.FRAMES:
		var ship := FlightPilot.new()
		ship.configure(game.run.upgrades, 99, frame, true)
		var data: Dictionary = FlightProfile.FRAMES[frame]
		_check(ship.max_health == int(data.hull) + 1 and is_equal_approx(ship.speed_multiplier, float(data.speed)) and is_equal_approx(ship.hit_radius, float(data.radius) / 10), "%s preserves frame hull, speed and hitbox in metres" % frame.to_upper())
		ship.free()
func _measure_performance() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Run the richest sector with VSync disabled; force draws if occluded on macOS.
	game.run.sector_index = 3
	game._launch_sector()
	_sync()
	pilot.invulnerability = 999
	pilot.position = Vector3(30, 35, -15)
	flight.chase.reset()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await create_timer(1).timeout
	var samples: Array[float] = []
	for i in 300:
		var begin := Time.get_ticks_usec()
		await process_frame
		RenderingServer.force_draw()
		samples.append((Time.get_ticks_usec() - begin) / 1000.0)
	samples.sort()
	var total := 0.0
	for value in samples:
		total += value
	print("FLIGHT PERFORMANCE: %.1f fps mean; %.2f ms p95 frame (%s, 1280x800, Compatibility)" % [1000.0 * samples.size() / total, samples[int(samples.size() * 0.95)], RenderingServer.get_video_adapter_name()])
	_check(total / samples.size() < 16.67 and samples[int(samples.size() * 0.95)] < 16.67, "Native flight sustains at least 60 fps mean and p95")
func _sync() -> void:
	flight = game.flight
	pilot = flight.pilot
func _actors(script: Script) -> Array:
	return flight.actors.get_children().filter(func(n: Node) -> bool: return n.get_script() == script)
func _freeze() -> void:
	for actor in flight.actors.get_children():
		if actor is FlightRock or actor is FlightSentry or actor is FlightLane or actor is FlightLeviathan:
			actor.set_physics_process(false)
	pilot.invulnerability = 999
func _collect(limit: int = 999) -> void:
	pilot.dash_remaining = 0
	pilot.velocity = Vector3.ZERO
	pilot.gravity_velocity = Vector3.ZERO
	pilot.external_force = Vector3.ZERO
	var index := 0
	for core in flight.cores():
		if index >= limit:
			break
		if is_instance_valid(core):
			pilot.position = core.position
			await _steps(4)
			pilot.gravity_velocity = Vector3.ZERO
			pilot.external_force = Vector3.ZERO
			index += 1
func _dock() -> void:
	pilot.dash_remaining = 0
	pilot.velocity = Vector3.ZERO
	pilot.gravity_velocity = Vector3.ZERO
	pilot.external_force = Vector3.ZERO
	pilot.position = Vector3.ZERO
	await create_timer(game.run.bank_seconds() + 0.09).timeout
func _advance() -> void:
	_check(game.state == "upgrade", "A completed sector opens the shared card draft")
	await _key(KEY_1)
	_sync()
	_freeze()
	_check(game.state == "running" and _captured(), "Keyboard draft choice launches the next 3D sector")
func _steps(count: int = 2) -> void:
	for i in count:
		await physics_frame
func _event_key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func _key(code: int) -> void:
	_event_key(code, true)
	await _steps(2)
	_event_key(code, false)
	await process_frame
func _hold(code: int, seconds: float) -> void:
	_event_key(code, true)
	await create_timer(seconds).timeout
	_event_key(code, false)
	await _steps(2)
func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 3:
		await process_frame
		RenderingServer.force_draw()
	var path := "/tmp/starling-flight3d-%s.png" % label
	root.get_texture().get_image().save_png(path)
	print("SCREENSHOT: " + path)

func _captured() -> bool:
	return pilot.mouse_captured and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

func _test_sentry() -> void:
	var sentry: FlightSentry = _actors(FlightSentry)[0]
	pilot.position = Vector3(35, 30, 45)
	pilot.velocity = Vector3.ZERO
	pilot.gravity_velocity = Vector3.ZERO
	pilot.dash_remaining = 0
	sentry.position = pilot.position + Vector3(20, 0, 0)
	sentry.anchor = sentry.position
	sentry.cycle = 0
	sentry.set_physics_process(true)
	await _steps(3)
	_check(sentry.windup > 0 and sentry.charging == 0 and sentry.laser.visible, "Sentry warns with a volumetric laser before lunging")
	var heading := sentry.heading
	pilot.position += Vector3(0, 15, 0)
	await _steps(3)
	_check(sentry.heading.is_equal_approx(heading), "Sentry locks its telegraphed direction so the lunge is avoidable")
	await create_timer(1.12).timeout
	_check(sentry.charging > 0 and sentry.position.x < 55, "The warned sentry performs a 3D lunge")
	sentry.position = pilot.position + Vector3(18, 0, 0)
	pilot.pulse_cooldown = 0
	await _key(KEY_E)
	_check(sentry.stunned > 3.8 and sentry.windup == 0 and sentry.charging == 0, "Ion pulse stuns a nearby sentry for four seconds")
	sentry.set_physics_process(false)
