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
	await _capture("roost")
	_test_meta()
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
	_prepare_offer("hull")
	await _dock()
	_check(game.state == "upgrade" and not game.pilot.active and game.run.last_bonus > 0, "Sector delivery stops play and offers upgrades with a landing bonus")
	await _capture("upgrades")
	var sector_score: int = game.run.score
	await _key(KEY_ENTER)
	game.choose_upgrade("invalid")
	_check(game.state == "upgrade" and game.run.sector_index == 0, "Enter and invalid choices cannot skip an upgrade")
	await _key(KEY_1 + game.run.upgrade_offers().find("hull"))
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
	_prepare_offer("pulse")
	await _dock()
	_check(game.state == "upgrade", "Second sector reaches the next upgrade dock")
	await _key(KEY_1 + game.run.upgrade_offers().find("pulse"))
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
	_check(game.profile.victories == 1 and game.profile.runs == 1 and game.profile.best == game.run.score and game.profile.owns("charts"), "Victory updates local expedition records")
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
	await _test_expansion()
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
	expedition.cached_offers.clear()
	var offered := expedition.upgrade_offers()
	var chosen := offered[0]
	_check(expedition.advance(chosen) and chosen in expedition.upgrade_offers(), "The next dock offers specialization of the chosen build")
	var configured := Pilot.new()
	configured.configure({"magnet": 2, "dash": 2, "hull": 2, "pulse": 2}, 99)
	_check(configured.max_health == 5 and configured.health == 5 and configured.magnet_radius == 175 and configured.cooldown_max < 0.8 and configured.speed_multiplier > 1.1, "Stacked upgrade builds apply and clamp hull correctly")
	configured.free()


func _freeze_hazards() -> void:
	for actor in game.world.get_children():
		if actor is Debris or actor is SentryDrone or actor is MeteorStorm or actor is Leviathan:
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


func _key(code: int) -> void:
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
	for i in 3:
		await process_frame
		RenderingServer.force_draw()
	# macOS can stop normal draws for an occluded window; force this capture.
	RenderingServer.force_draw()
	var path := "/tmp/starling-v2-%s.png" % label
	root.get_texture().get_image().save_png(path)
	print("SCREENSHOT: " + path)


func _prepare_offer(id: String) -> void:
	for seed_value in 100:
		game.run.rng.seed = seed_value
		game.run.cached_offers.clear()
		if id in game.run.upgrade_offers():
			return


func _test_meta() -> void:
	var cli_output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "tests/preview_flag.gd", "--", "--unlock-all"], cli_output, true)
	_check(exit_code == 0 and "PREVIEW FLAG: PASS" in str(cli_output), "The actual --unlock-all CLI flag isolates the save in a child engine process")
	var p := FlightProfile.new()
	p.path = test_path + "-meta"
	_check(p.payout(30, 3, true, "survey") == 510 and p.payout(5, 0, false, "survey") == 40, "Scrap pays the exact Survey win and early-loss formulas")
	_check(p.payout(42, 4, true, "deep") == 808, "Deep Orbit applies its 1.25 payout multiplier with nearest-integer rounding")
	_check(not p.purchase("chain") and not p.purchase("missing"), "Unaffordable and unknown purchases are rejected")
	p.scrap = 1000
	_check(p.purchase("chain") and p.scrap == 880 and not p.purchase("chain"), "Purchasing deducts the cost exactly once")
	var loaded := FlightProfile.new()
	loaded.path = p.path
	loaded.load_profile()
	_check(loaded.scrap == 880 and loaded.owns("chain"), "Workshop balance and ownership survive reload")
	_check(not p.purchase("broker2") and p.purchase("broker1") and p.purchase("broker2") and p.broker_level() == 2 and p.payout(30, 3, true, "survey") == 663, "Broker levels require their predecessor and multiply Scrap correctly")
	var real_before := FileAccess.get_file_as_bytes("user://starling.cfg") if FileAccess.file_exists("user://starling.cfg") else PackedByteArray()
	var preview := FlightProfile.new()
	preview.enable_preview()
	preview.save()
	var preview_loaded := ConfigFile.new()
	preview_loaded.load(preview.path)
	_check(preview.path != "user://starling.cfg" and preview.scrap == 5000 and preview.owned.size() == FlightProfile.ITEMS.size() and preview_loaded.get_value("workshop", "scrap") == 5000, "Unlock-all uses a separate temporary profile with every item and 5000 Scrap")
	var real_after := FileAccess.get_file_as_bytes("user://starling.cfg") if FileAccess.file_exists("user://starling.cfg") else PackedByteArray()
	_check(real_before == real_after, "Saving the unlock-all profile never modifies the real save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(preview.path))
	var legacy_winner := ConfigFile.new()
	legacy_winner.set_value("mission", "victories", 2)
	legacy_winner.save(p.path)
	loaded.load_profile()
	_check(loaded.victories == 2 and loaded.owns("charts"), "Legacy Survey victories receive their free Deep Orbit Charts")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p.path))
	_check(game.profile.scrap == 0 and game.profile.owned.is_empty() and not game.profile.view_3d, "Legacy saves without meta keys load safe defaults")
	var a := Expedition.new()
	var b := Expedition.new()
	a.configure(preview, 571)
	b.configure(preview, 571)
	_check(a.upgrades == b.upgrades and a.upgrades.values().count(1) == 1, "Launch Rig seeds one random unlocked card deterministically")
	_check(a.upgrade_offers() == b.upgrade_offers() and a.upgrade_offers() == a.upgrade_offers(), "Fixed seeds produce stable deterministic offers")
	var distinct := true
	var owned_rule := true
	var locked_rule := true
	for seed_value in 80:
		var draft := Expedition.new()
		draft.rng.seed = seed_value
		draft.upgrades.dash = 1
		var offers := draft.upgrade_offers()
		distinct = distinct and offers.size() == 3 and offers[0] != offers[1] and offers[0] != offers[2] and offers[1] != offers[2]
		owned_rule = owned_rule and "dash" in offers
		for id in offers:
			locked_rule = locked_rule and id in ["magnet", "dash", "hull", "pulse"]
		draft.upgrades.dash = 2
		draft.cached_offers.clear()
		locked_rule = locked_rule and not "dash" in draft.upgrade_offers()
	_check(distinct and owned_rule and locked_rule, "Drafts are distinct, include an owned card when possible, exclude locked and maxed cards across 80 seeds")
	var cards := Expedition.new()
	cards.upgrades.chain = 2
	for i in 12:
		cards.collect()
	_check(cards.chain_window() == 7.5 and cards.multiplier() == 5, "Chain Battery extends the window and unlocks x5 at level two")
	cards.upgrades.ballast = 2
	cards.upgrades.chrono = 2
	_check(is_equal_approx(cards.bank_seconds(), 0.3) and cards.sector_seconds() == 81, "Ballast reduces bank time per level and Chronometer extends sector clocks")
	cards.upgrades.overdrive = 1
	_check(cards.free_pulse_due(), "Overdrive level one pulses every sixth linked pickup")
	cards.upgrades.overdrive = 2
	_check(cards.free_pulse_due(), "Overdrive level two pulses every fourth linked pickup")
	for id in FlightProfile.FRAMES:
		var ship := Pilot.new()
		ship.configure(cards.upgrades, 99, id)
		var data: Dictionary = FlightProfile.FRAMES[id]
		_check(ship.max_health == data.hull and ship.health == data.hull and ship.speed_multiplier == data.speed and ship.cooldown_max == data.recharge and ship.magnet_radius == data.magnet and ship.hit_radius == data.radius, "%s applies every frame stat" % id.to_upper())
		ship.configure({"ram": 2, "ballast": 1}, 99, id, true)
		_check(ship.max_health == int(data.hull) + 1 and is_equal_approx(ship.dash_duration, 0.38) and ship.cargo_drag == 0, "%s combines permanent plating, Ram immunity and Ballast drag removal" % id.to_upper())
		ship.free()
	var heavy := Pilot.new()
	heavy.configure({}, 4, "albatross")
	_check(heavy.cargo_drag == 0.5, "Albatross halves cargo slowdown")
	heavy.free()
	cards.route = "deep"
	cards.score = 18000
	_check(cards.rank() == "S", "Deep Orbit uses its own rank thresholds")


func _test_expansion() -> void:
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 800)
	game.return_to_roost()
	await _key(KEY_B)
	_check(game.hud.screens.hub_section == "workshop", "Keyboard opens the Workshop")
	game.profile.scrap = 5000
	game.hud.screens.workshop_index = FlightProfile.ITEMS.keys().find("kestrel")
	game._show_screen()
	await _key(KEY_SPACE)
	_check(game.profile.owns("kestrel") and game.profile.scrap == 4700, "Keyboard buys the selected Workshop item")
	game.hud.screens.workshop_index = FlightProfile.ITEMS.keys().find("wing")
	game._show_screen()
	await _click_button(game.hud.screens.hub_root.get_children().filter(func(n: Node) -> bool: return n is Button and "BUY" in n.text)[0])
	_check(game.profile.owns("wing"), "Mouse purchases a Workshop schematic")
	await _capture("workshop")
	await _key(KEY_L)
	await _key(KEY_F)
	_check(game.profile.selected_frame == "kestrel", "Keyboard cycles to the unlocked Kestrel frame")
	await process_frame
	_check(game.presenter.module_owned("Kestrel") and game.presenter.module_owned("Fabricator") and not game.presenter.module_owned("Albatross"), "Roost module ownership follows Workshop purchases")
	var kestrel_module := ModelAssets.part(game.presenter.station, "Module_Kestrel")
	var albatross_module := ModelAssets.part(game.presenter.station, "Module_Albatross")
	_check(kestrel_module != null and kestrel_module.visible and albatross_module != null and not albatross_module.visible, "Imported Roost module nodes show and hide by ownership")
	await _capture("roost-upgraded")
	await _key(KEY_T)
	_check(game.hud.screens.hub_section == "records" and game.profile.route_records.has("survey"), "Records section exposes the saved per-route flight log")
	await _key(KEY_L)
	game.profile.selected_route = "survey"
	game.profile.selected_frame = "starling"
	game.start_mission()
	_freeze_hazards()
	var old_view: bool = game.profile.view_3d
	await _key(KEY_F3)
	_check(game.presenter.visible and game.profile.view_3d != old_view and not game.stage.visible, "F3 toggles Survey to 3D and hides the 2D drawing")
	var loaded := FlightProfile.new()
	loaded.path = test_path
	loaded.load_profile()
	_check(loaded.view_3d == game.profile.view_3d, "Survey view preference persists")
	game.presenter.sync()
	var fallback_model := ModelAssets.model("missing-smoke-model", "missing-smoke-fallback")
	_check(fallback_model is MeshInstance3D, "Missing models fall back to a primitive without failing")
	fallback_model.free()
	_check(game.presenter.mirrors.size() == game.world.get_child_count(), "The presenter mirrors every simulation actor exactly once")
	var mapped := true
	for actor in game.world.get_children():
		var mirror: Node3D = game.presenter.mirrors[actor.get_instance_id()]
		var expected := OrbitPresenter.map_position(actor.position)
		mapped = mapped and Vector2(mirror.position.x - expected.x, mirror.position.z - expected.z).length() < 0.001
	_check(mapped, "Every mirrored actor maps simulation XY to world XZ within tolerance")
	var fits := true
	for point in [Vector2(40, 130), Vector2(1240, 130), Vector2(40, 736), Vector2(1240, 736)]:
		var projected: Vector2 = game.presenter.project(point)
		fits = fits and Rect2(0, 125, 1280, 620).has_point(projected)
	_check(fits, "Perspective camera keeps every playfield corner visible below the HUD")
	await _capture("survey-3d")
	var camera_position: Vector3 = game.presenter.camera.position
	game.pilot.position += Vector2(100, 100)
	await process_frame
	_check(game.presenter.camera.position == camera_position, "Reduced motion disables camera follow")
	await _key(KEY_F3)
	_check(not game.presenter.visible and game.stage.visible, "F3 returns to the original Survey presentation")
	game.profile.selected_route = "deep"
	game.start_mission()
	_freeze_hazards()
	await process_frame
	_check(game.presenter.visible and game.run.sectors().size() == 4 and _cores().size() == 9, "Deep Orbit starts The Shelf in forced 3D")
	await _key(KEY_F3)
	_check(game.presenter.visible, "Deep Orbit remains 3D after F3")
	await _capture("deep-shelf")
	await _collect_all()
	await _dock()
	game.choose_upgrade(game.run.upgrade_offers()[0])
	_freeze_hazards()
	var spires: Array = game.world.get_children().filter(func(n: Node) -> bool: return n is FoundrySpire)
	_check(spires.size() == 5 and game.run.sector_index == 1, "Foundry Spires introduces five solid towers")
	var spire: FoundrySpire = spires[0]
	var hp: int = game.pilot.health
	game.pilot.position = spire.position + Vector2(40, 0)
	Input.action_press("move_left")
	await create_timer(0.18).timeout
	Input.action_release("move_left")
	_check(game.pilot.position.distance_to(spire.position) >= spire.radius + game.pilot.hit_radius - 0.1 and game.pilot.health == hp, "Spire collision blocks and slides the pilot without damage")
	game.pilot.dash_remaining = 0.15
	game.pilot.position = spire.position
	await _physics_steps()
	_check(is_instance_valid(spire) and game.pilot.position.distance_to(spire.position) >= 46, "Dashing cannot destroy or enter a spire")
	var rock: Debris = _actors("Debris")[0]
	rock.position = spire.position + Vector2(40, 0)
	rock.velocity = Vector2(-60, 0)
	await _physics_steps()
	_check(rock.velocity.x > 0 and rock.position.distance_to(spire.position) >= spire.radius + rock.radius - 0.1, "Rocks bounce off solid spires")
	var clear := true
	for core in _cores():
		for tower in spires:
			clear = clear and core.position.distance_to(tower.position) > tower.radius + 20
	_check(clear, "Cores spawn clear of every spire")
	game.pilot.position = game.BEACON
	game.presenter.sync()
	_check(game.presenter.mirrors.size() == game.world.get_child_count(), "Deep Orbit hazards and sentries also receive exactly one mirror each")
	await _capture("deep-spires")
	await _collect_all()
	await _dock()
	game.choose_upgrade(game.run.upgrade_offers()[0])
	_freeze_hazards()
	var well: GravityWell = game.world.get_children().filter(func(n: Node) -> bool: return n is GravityWell)[0]
	game.pilot.position = well.position + Vector2(-170, 0)
	game.pilot.velocity = Vector2.ZERO
	game.pilot.gravity_velocity = Vector2.ZERO
	var distance: float = game.pilot.position.distance_to(well.position)
	await create_timer(0.35).timeout
	_check(game.pilot.position.distance_to(well.position) < distance - 2, "The well physically pulls an idle pilot toward its center")
	var loose: SalvageCore = _cores()[0]
	loose.position = well.position + Vector2(130, 0)
	var core_distance: float = loose.position.distance_to(well.position)
	await create_timer(0.1).timeout
	_check(loose.position.distance_to(well.position) < core_distance, "The well slowly drags loose cores")
	game.pilot.invulnerability = 0
	game.pilot.dash_remaining = 0
	game.pilot.position = well.position + Vector2(15, 0)
	hp = game.pilot.health
	await _physics_steps()
	_check(game.pilot.health == hp - 1 and game.pilot.gravity_velocity.x > 400 and game.pilot.position.distance_to(well.position) > well.horizon, "The horizon damages once and flings the ship outward")
	game.pilot.invulnerability = 999
	var count := _cores().size()
	loose.position = well.position
	await _physics_steps()
	await process_frame
	_check(not is_instance_valid(loose) and _cores().size() == count, "Consumed horizon cores respawn elsewhere without reducing the available haul")
	game.pilot.pulse_cooldown = 0
	await _action("pulse")
	_check(well.inversion > 1.4 and well.force_at(well.position + Vector2(120, 0)).x > 0, "Real ion pulse input inverts the well for 1.5 seconds")
	await _capture("deep-well")
	await create_timer(1.52).timeout
	_check(well.inversion == 0 and well.force_at(well.position + Vector2(120, 0)).x < 0, "Gravity resumes pulling when inversion expires")
	await _collect_all()
	game.pilot.gravity_velocity = Vector2.ZERO
	game.pilot.external_force = Vector2.ZERO
	await _dock()
	game.choose_upgrade(game.run.upgrade_offers()[0])
	_freeze_hazards()
	var boss: Leviathan = game.world.get_children().filter(func(n: Node) -> bool: return n is Leviathan)[0]
	_check(game.run.sector_index == 3 and _cores().size() == 6, "Leviathan sector begins with six loose cores")
	boss.set_physics_process(true)
	var boss_start: Vector2 = boss.position
	game.pilot.position = Vector2(640, 600)
	boss.begin_beam()
	_check(boss.warning > 1.3 and boss.beam == 0, "Leviathan telegraphs a beam before it can hurt the pilot")
	await _capture("deep-leviathan-beam")
	game.pilot.position = boss.lane_start.lerp(boss.lane_end, 0.5)
	game.pilot.invulnerability = 0
	hp = game.pilot.health
	await create_timer(1.48).timeout
	_check(boss.beam > 0 and game.pilot.health == hp - 1, "The warned beam becomes a damaging lane after 1.4 seconds")
	_check(boss.position.distance_to(boss_start) > 1, "Leviathan patrols its wide upper-band ellipse")
	game.pilot.invulnerability = 999
	boss.shed_clock = 0.01
	var available: int = _cores().size() + game.run.cargo
	await create_timer(0.05).timeout
	_check(_cores().size() + game.run.cargo == available + 1, "Leviathan periodically sheds a collectible core")
	game.pilot.invulnerability = 0
	game.pilot.dash_remaining = 0
	game.pilot.position = boss.position + Vector2(0, 30)
	hp = game.pilot.health
	await _physics_steps()
	_check(game.pilot.health == hp - 1 and game.pilot.position.distance_to(boss.position) > 40, "Hull contact damages and separates a ship that is not dashing")
	game.pilot.invulnerability = 999
	boss.set_physics_process(false)
	var before: int = game.run.score
	for i in 3:
		game.pilot.position = boss.vent_position(i)
		game.pilot.dash_remaining = 0.15
		boss._physics_process(0)
		await _physics_steps()
	_check(boss.cracked == [true, true, true] and game.run.score >= before + 2700 and boss.is_silenced and boss.warning == 0 and boss.beam == 0, "Dashing cracks three vents, awards 400 each and 1500 SILENCED, and stops beams")
	_check(_cores().size() + game.run.cargo + game.run.banked >= 15, "Cracked vents spill three cores apiece")
	boss.begin_beam()
	_check(boss.warning == 0, "A silenced Leviathan never starts another beam")
	await _capture("deep-leviathan-silenced")
	await _collect_all()
	game.pilot.gravity_velocity = Vector2.ZERO
	await _dock()
	_check(game.state == "won" and game.run.sectors_cleared == 4 and game.run.total_banked >= 42, "A full Deep Orbit run banks its final quota and wins")
	_check(game.profile.route_records.has("deep") and game.profile.last_scrap == game.profile.payout(game.run.total_banked, 4, true, "deep"), "Deep Orbit victory records its rank and pays the route multiplier")
	await _capture("deep-result-scrap")
	await _test_card_actors()


func _test_card_actors() -> void:
	game.profile.selected_route = "survey"
	game.start_mission()
	game.run.upgrades.wing = 2
	game.run.upgrades.overdrive = 1
	game.run.upgrades.ram = 2
	game.run.upgrades.ballast = 2
	game.run.upgrades.chrono = 2
	game._launch_sector()
	_check(game.time_left > 80, "Chronometer applies its extra time when a later sector actually launches")
	_freeze_hazards()
	var wings: Array = game.world.get_children().filter(func(n: Node) -> bool: return n is SalvageWing)
	_check(wings.size() == 2 and is_equal_approx(wings[0].position.distance_to(game.pilot.position), 70), "Salvage Wing level two creates two orbiting collectors")
	var wing: SalvageWing = wings[0]
	game.pilot.position = Vector2(500, 500)
	wing._physics_process(0)
	var core: SalvageCore = _cores()[0]
	core.position = wing.position
	var cargo: int = game.run.cargo
	await _physics_steps()
	_check(game.run.cargo == cargo + 1 and not is_instance_valid(core), "Salvage Wing collects cores through the normal pickup path")
	for actor in wings:
		actor.set_physics_process(false)
	game.run.chain = 5
	game.pilot.pulse_cooldown = 4
	var rock: Debris = _actors("Debris")[0]
	rock.position = game.pilot.position + Vector2(100, 0)
	core = _cores()[0]
	core.position = game.pilot.position
	await _physics_steps()
	_check(rock.velocity.length() > 200 and game.pilot.pulse_cooldown < 4, "Overdrive triggers a real free pulse without consuming the ability recharge")
	game.pilot.dash_remaining = 0.3
	rock.position = game.pilot.position
	rock.set_physics_process(true)
	var clock: float = game.time_left
	await _physics_steps()
	_check(not is_instance_valid(rock) and game.time_left > clock + 2.8, "Ram Plating adds 1.5 seconds per level for an actual dash-shatter")
	game.run.cargo = 2
	game.pilot.dash_remaining = 0
	game.pilot.position = game.BEACON
	game.pilot.velocity = Vector2.ZERO
	await create_timer(0.36).timeout
	_check(game.run.cargo == 0 and game.run.banked == 2, "Ballast level two banks cargo in 0.3 seconds")
