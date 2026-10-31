extends SceneTree
## Integration checks use a separate profile. Omit --headless for UI captures.

const GameScene := preload("res://scenes/main.tscn")
var checks := 0
var failures := 0
var game: Node2D
var test_path := "user://starling-smoke-%d.cfg" % OS.get_process_id()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var legacy := ConfigFile.new()
	legacy.set_value("mission", "best", 1234)
	legacy.save(test_path)
	game = GameScene.instantiate()
	game.profile.path = test_path
	game.auto_pause = false
	root.add_child(game)
	await process_frame
	game.profile.muted = true
	game.sound.muted = true
	_check(game.state == "menu" and game.profile.best == 1234, "Title screen loads an existing legacy best score")
	await _capture("title")
	_test_rules()
	game.rng.seed = 20261030
	await _click_button(game.hud.screens.button)
	_freeze_hazards()
	await physics_frame
	_check(game.state == "running" and _cores().size() == 8, "A routed mouse click launches sector one with eight cores")
	_check(game.pilot.health == 3 and game.pilot.active, "New expedition starts with a fresh ship")
	var start: Vector2 = game.pilot.position
	Input.action_press("move_right")
	await create_timer(0.15).timeout
	Input.action_release("move_right")
	_check(game.pilot.position.x > start.x + 10, "Movement input advances the ship")
	game.pilot.position.x = 5000
	await _physics_steps()
	_check(game.pilot.position.x <= 1222, "Ship stays inside the arena")
	game.pilot.position = Vector2(300, 400)
	await _action("dash")
	_check(game.pilot.dash_remaining > 0 and game.pilot.cooldown > 0, "Dash input activates the ability and recharge")
	game.pilot.hit()
	_check(game.pilot.health == 3, "Dash protects the hull")
	await create_timer(0.23).timeout
	await _action("dash")
	_check(game.pilot.dash_remaining == 0, "An uncharged dash cannot be activated again")
	game.pilot.position = Vector2(300, 400)
	var rock: Debris = _actors("Debris")[0]
	rock.position = Vector2(365, 400)
	var core: SalvageCore = _cores()[0]
	core.position = Vector2(440, 400)
	await _action("pulse")
	_check(game.pilot.pulse_cooldown > 0 and rock.velocity.length() > 200 and core.pull_boost > 0, "Pulse scatters debris and pulls nearby cargo")
	await _capture("pulse")
	await create_timer(0.4).timeout
	rock.position = game.pilot.position
	rock.velocity = Vector2.ZERO
	rock.set_physics_process(true)
	await create_timer(0.08).timeout
	_check(game.pilot.health == 2, "A real debris overlap damages the hull")
	game.pilot.hit()
	_check(game.pilot.health == 2, "Recovery shield prevents repeated damage")
	var before_shatter: int = game.run.score
	var shatters := [0]
	rock.shattered.connect(func(_point: Vector2) -> void: shatters[0] += 1)
	game.pilot.dash_remaining = 0.15
	await _physics_steps()
	_check(not is_instance_valid(rock) and shatters[0] == 1 and game.run.score >= before_shatter + 75, "Dashing through debris destroys it and awards points once")
	await _key(KEY_P)
	var frozen_time: float = game.time_left
	var frozen_position: Vector2 = game.pilot.position
	var frozen_pulse: float = game.pilot.pulse_cooldown
	var frozen_chain: float = game.run.chain_left
	await create_timer(0.08).timeout
	_check(game.state == "paused" and game.time_left == frozen_time and game.pilot.position == frozen_position and game.pilot.pulse_cooldown == frozen_pulse and game.run.chain_left == frozen_chain, "Keyboard pause freezes the entire simulation")
	await _capture("pause")
	await _key(KEY_ESCAPE)
	_check(game.state == "running" and game.pilot.active, "Escape resumes gameplay")
	game.auto_pause = true
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.auto_pause = false
	_check(game.state == "paused", "Switching away from the game automatically pauses it")
	var logical_enter := InputEventKey.new()
	logical_enter.keycode = KEY_ENTER
	logical_enter.pressed = true
	Input.parse_input_event(logical_enter)
	await process_frame
	logical_enter = logical_enter.duplicate()
	logical_enter.pressed = false
	Input.parse_input_event(logical_enter)
	await process_frame
	_check(game.state == "running", "Logical-only Enter events resume the game")
	game.start_mission()
	_freeze_hazards()
	game.pilot.invulnerability = 999
	var first_two := _cores().slice(0, 2)
	for item in first_two:
		game.pilot.position = item.position
		await create_timer(0.05).timeout
	_check(game.run.cargo == 2 and game.run.banked == 0, "Collected cargo remains aboard until docked")
	game.pilot.position = game.BEACON
	await create_timer(0.18).timeout
	_check(game.dock_progress > 0 and game.run.cargo == 2, "Docking visibly takes time")
	game.pilot.position += Vector2(110, 0)
	await process_frame
	await process_frame
	_check(game.dock_progress == 0, "Leaving the dock cancels delivery progress")
	await _dock()
	_check(game.run.banked == 2 and game.run.cargo == 0 and game.state == "running", "Partial delivery banks cargo without ending the sector")
	await _collect_all()
	_check(game.run.banked + game.run.cargo == 8 and game.state == "running", "Every core is collected once and returning home is still required")
	game.pilot.health = 1
	await _dock()
	_check(game.state == "upgrade" and not game.pilot.active and game.run.last_bonus > 0, "Sector delivery stops play and offers upgrades with a landing bonus")
	await _capture("upgrades")
	var sector_score: int = game.run.score
	await _key(KEY_ENTER)
	game.choose_upgrade("invalid")
	_check(game.state == "upgrade" and game.run.sector_index == 0, "Enter and invalid choices cannot skip an upgrade")
	await _key(KEY_3)
	_freeze_hazards()
	_check(game.state == "running" and game.run.sector_index == 1 and game.run.score == sector_score and game.run.upgrades.hull == 1, "Keyboard upgrade choice advances the expedition and preserves score")
	_check(game.pilot.max_health == 4 and game.pilot.health == 3, "Hull upgrade adds capacity and repairs damage at the jump")
	_check(_actors("SentryDrone").size() == 2 and _cores().size() == 10, "Sector two introduces sentries and a larger quota")
	game.pilot.invulnerability = 999
	var drone: SentryDrone = _actors("SentryDrone")[0]
	game.pilot.position = drone.position + Vector2(70, 0)
	await _action("pulse")
	_check(drone.stunned > 3.5, "Ion pulse stuns a nearby sentry")
	drone.stunned = 0
	drone.cycle = 0
	drone.set_physics_process(true)
	await _physics_steps()
	_check(drone.windup > 0 and drone.charging == 0, "Sentry warns before committing to a lunge")
	var locked: Vector2 = drone.heading
	game.pilot.position += Vector2(0, 100)
	await create_timer(0.12).timeout
	_check(drone.heading == locked, "Sentry locks its direction so the attack can be dodged")
	await _capture("sentries")
	await create_timer(1.05).timeout
	_check(drone.charging > 0, "Warned sentry attack becomes a charge")
	drone.set_physics_process(false)
	await _collect_all()
	await _dock()
	_check(game.state == "upgrade", "Second sector reaches the next upgrade dock")
	await _key(KEY_1)
	_freeze_hazards()
	_check(game.run.sector_index == 2 and game.run.upgrades.pulse == 1 and game.pilot.pulse_radius == 265 and game.pilot.pulse_cooldown_max == 6, "Ion resonator applies its range and recharge improvements")
	_check(_cores().size() == 12 and _actors("MeteorStorm").size() == 1, "Final sector includes twelve cores and a meteor storm")
	var storm: MeteorStorm = _actors("MeteorStorm")[0]
	storm.begin_warning()
	_check(storm.warning > 0 and storm.flight == 0, "Meteor lane warns before becoming dangerous")
	await _capture("storm-warning")
	storm.set_physics_process(true)
	game.pilot.position = game.BEACON
	await create_timer(1.7).timeout
	_check(storm.flight > 0 and game.pilot.health > 0, "Warned meteor crosses its lane while the home dock stays safe")
	game.pilot.invulnerability = 999
	game.pilot.position = storm.meteor_position + Vector2(0, 65)
	await _action("pulse")
	_check(storm.flight == 0, "Pulse deflects a nearby live meteor")
	storm.set_physics_process(false)
	await _collect_all()
	await _dock()
	_check(game.state == "won" and game.run.total_banked == 30 and not game.pilot.active, "Full three-sector expedition banks thirty cores and wins")
	_check(game.profile.victories == 1 and game.profile.runs == 1 and game.profile.best == game.run.score, "Victory updates local expedition records")
	var loaded := FlightProfile.new()
	loaded.path = test_path
	loaded.load_profile()
	_check(loaded.best == game.run.score and loaded.victories == 1 and loaded.muted, "Best score, victories, and settings persist across profile reloads")
	await _capture("victory")
	await _key(KEY_R)
	_freeze_hazards()
	_check(game.run.sector_index == 0 and game.run.score == 0 and game.pilot.health == 3 and game.run.upgrades.hull == 0 and game.run.total_banked == 0, "Restart clears the expedition and temporary upgrades")
	await _capture("gameplay")
	await _key(KEY_F2)
	game.shake = 6
	await process_frame
	_check(game.profile.reduced_motion and game.stage.position == Vector2.ZERO, "Reduced-motion option disables camera shake")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(960, 600)
		await _capture("small-window")
	game.time_left = 0.001
	await create_timer(0.03).timeout
	_check(game.state == "lost" and game.profile.runs == 2, "An expired clock ends and records the run exactly once")
	game.start_mission()
	_freeze_hazards()
	for i in 3:
		game.pilot.invulnerability = 0
		game.pilot.hit()
	_check(game.state == "lost" and game.pilot.health == 0 and game.profile.runs == 3, "Three unshielded hits end a fresh expedition")
	await _capture("loss")
	game.start_mission()
	await _key(KEY_P)
	game.hud.screens.secondary.pressed.emit()
	_check(game.state == "lost" and game.profile.runs == 4, "Ending an expedition from pause returns to a result screen")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("STARLING EXPEDITION TEST: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)


func _test_rules() -> void:
	var expedition := Expedition.new()
	var points := 0
	for i in 9:
		points += expedition.collect()
	_check(expedition.multiplier() == 4 and expedition.peak_multiplier == 4 and points > 900, "Linked pickups grow to a capped x4 multiplier")
	expedition.tick(Expedition.CHAIN_WINDOW + 0.1)
	_check(expedition.chain == 0 and expedition.multiplier() == 1, "An expired chain returns the multiplier to x1")
	expedition.bank_cargo()
	_check(expedition.advance("dash") and "dash" in expedition.upgrade_offers() and "pulse" in expedition.upgrade_offers(), "The next dock offers specialization of the chosen build or pulse control")
	var configured := Pilot.new()
	configured.configure({"magnet": 2, "dash": 2, "hull": 2, "pulse": 2}, 99)
	_check(configured.max_health == 5 and configured.health == 5 and configured.magnet_radius == 175 and configured.cooldown_max < 0.8 and configured.speed_multiplier > 1.1, "Stacked upgrade builds apply and clamp hull correctly")
	configured.free()


func _freeze_hazards() -> void:
	for actor in game.world.get_children():
		if actor is Debris or actor is SentryDrone or actor is MeteorStorm:
			actor.set_physics_process(false)


func _actors(type: String) -> Array:
	var result: Array = []
	for actor in game.world.get_children():
		if (type == "Debris" and actor is Debris) or (type == "SentryDrone" and actor is SentryDrone) or (type == "MeteorStorm" and actor is MeteorStorm):
			result.append(actor)
	return result


func _cores() -> Array[SalvageCore]:
	var result: Array[SalvageCore] = []
	for actor in game.world.get_children():
		if actor is SalvageCore and not actor.taken:
			result.append(actor)
	return result


func _collect_all() -> void:
	game.pilot.invulnerability = 999
	for item in _cores():
		if is_instance_valid(item):
			game.pilot.position = item.position
			await create_timer(0.05).timeout
	_freeze_hazards()


func _dock() -> void:
	game.pilot.velocity = Vector2.ZERO
	game.pilot.position = game.BEACON
	await create_timer(game.DOCK_SECONDS + 0.08).timeout


func _physics_steps() -> void:
	await physics_frame
	await physics_frame


func _action(action: String) -> void:
	Input.action_press(action)
	await _physics_steps()
	Input.action_release(action)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _click_button(button: Button) -> void:
	# parse_input_event receives window coordinates, including viewport scaling.
	var point := root.get_final_transform() * button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


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
	await process_frame
	# macOS can stop normal draws for an occluded window; force this capture.
	RenderingServer.force_draw()
	var path := "/tmp/starling-v2-%s.png" % label
	root.get_texture().get_image().save_png(path)
	print("SCREENSHOT: " + path)
