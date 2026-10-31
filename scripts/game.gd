extends Node2D
## Coordinates the expedition, world actors, and screens. Rules live in Expedition.

const PilotScript := preload("res://scripts/pilot.gd")
const CoreScript := preload("res://scripts/core.gd")
const DebrisScript := preload("res://scripts/debris.gd")
const DroneScript := preload("res://scripts/drone.gd")
const StormScript := preload("res://scripts/meteor_storm.gd")
const ArenaScript := preload("res://scripts/arena.gd")
const HudScript := preload("res://scripts/hud.gd")
const SoundScript := preload("res://scripts/sound.gd")
const BEACON := Vector2(640, 431)
const DOCK_SECONDS := 0.7

var presenter: OrbitPresenter
var state := "menu"
var run := Expedition.new()
var profile := FlightProfile.new()
var time_left := 65.0
var dock_progress := 0.0
var carried_hull := 3
var elapsed := 0.0
var shake := 0.0
var stage: Node2D
var world: Node2D
var pilot: Pilot
var arena: Node2D
var effects: FlightEffects
var hud: CanvasLayer
var sound: Node
var rng := RandomNumberGenerator.new()
var visual_rng := RandomNumberGenerator.new()
var first_pickup := true
var auto_pause := true


func _ready() -> void:
	_setup_input()
	rng.randomize()
	if "--unlock-all" in OS.get_cmdline_user_args():
		profile.enable_preview()
	profile.load_profile()
	stage = Node2D.new()
	add_child(stage)
	arena = ArenaScript.new()
	stage.add_child(arena)
	world = Node2D.new()
	stage.add_child(world)
	effects = FlightEffects.new()
	effects.reduced_motion = profile.reduced_motion
	stage.add_child(effects)
	sound = SoundScript.new()
	add_child(sound)
	sound.muted = profile.muted
	presenter = OrbitPresenter.new()
	add_child(presenter)
	presenter.profile = profile
	presenter.sim = world
	presenter.overlay.effects = effects
	hud = HudScript.new()
	add_child(hud)
	hud.screens.hub_changed.connect(_show_screen)
	hud.screens.purchased.connect(func() -> void: sound.play("purchase"))
	hud.screens.roost_pressed.connect(return_to_roost)
	hud.screens.primary_pressed.connect(_primary_action)
	hud.screens.upgrade_selected.connect(choose_upgrade)
	hud.screens.sound_toggled.connect(_toggle_sound)
	hud.screens.motion_toggled.connect(_toggle_motion)
	hud.screens.abandon_pressed.connect(func() -> void: _finish(false, "You returned the ship to port."))
	_build_world()
	_show_screen()


func _setup_input() -> void:
	var bindings := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "dash": [KEY_SPACE], "pulse": [KEY_E]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)


func _build_world() -> void:
	for child in world.get_children():
		world.remove_child(child)
		child.queue_free()
	effects.clear()
	var sector := run.sector()
	pilot = PilotScript.new()
	pilot.configure(run.upgrades, carried_hull, run.frame, run.plating)
	pilot.reduced_motion = profile.reduced_motion
	pilot.position = BEACON
	pilot.damaged.connect(_on_damage)
	pilot.destroyed.connect(func() -> void: _finish(false, "The hull gave out before the cargo made it home."))
	pilot.dashed.connect(func() -> void: sound.play("dash"))
	pilot.pulse_fired.connect(_on_pulse)
	world.add_child(pilot)
	presenter.pilot = pilot
	if run.route == "deep":
		_build_deep_features()
	for i in (6 if run.route == "deep" and run.sector_index == 3 else int(sector.quota)):
		var core := CoreScript.new()
		var angle := TAU * float(i) / int(sector.quota) + rng.randf_range(-0.11, 0.11)
		core.position = BEACON + Vector2(cos(angle) * rng.randf_range(345, 510), sin(angle) * rng.randf_range(165, 242))
		core.position = _safe_core_position(core.position)
		core.pilot = pilot
		core.collected.connect(_on_core_collected)
		world.add_child(core)
	for i in int(sector.rocks):
		_spawn_debris()
	for i in int(sector.drones):
		var drone := DroneScript.new()
		drone.position = Vector2(310 if i == 0 else 970, 300 if i == 0 else 565)
		drone.pilot = pilot
		drone.cycle += i * 1.7
		drone.shattered.connect(_on_shattered.bind(150))
		world.add_child(drone)
	if sector.storm:
		var storm := StormScript.new()
		storm.pilot = pilot
		storm.rng.seed = rng.randi()
		storm.warned.connect(func() -> void:
			hud.notice("METEOR INBOUND  /  Move clear of the amber lane", Color("ffc780"), 2.0)
			sound.play("warning"))
		storm.deflected.connect(_on_shattered.bind(100))
		world.add_child(storm)
	for i in int(run.upgrades.wing):
		var wing := SalvageWing.new()
		wing.pilot = pilot
		wing.orbit = i * PI
		wing.position = pilot.position + Vector2.from_angle(i * PI) * 70
		world.add_child(wing)
	arena.accent = sector.color
	presenter.sync()
	_set_active(state == "running")


func _spawn_debris() -> void:
	var debris := DebrisScript.new()
	var point := Vector2.ZERO
	for attempt in 100:
		point = Vector2(rng.randf_range(100, 1180), rng.randf_range(185, 680))
		if point.distance_to(pilot.position) > 185 and point.distance_to(BEACON) > 145:
			break
	debris.position = point
	debris.radius = rng.randf_range(19, 33)
	debris.velocity = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(40, 76) * float(run.sector().speed)
	debris.spin = rng.randf_range(-0.6, 0.6)
	debris.active = true
	debris.shattered.connect(_on_shattered.bind(75))
	world.add_child(debris)


func start_mission() -> void:
	run = Expedition.new()
	run.configure(profile, rng.randi())
	carried_hull = int(FlightProfile.FRAMES[run.frame].hull) + (1 if run.plating else 0) + int(run.upgrades.hull)
	first_pickup = true
	_launch_sector()


func _launch_sector() -> void:
	state = "running"
	time_left = run.sector_seconds()
	dock_progress = 0
	shake = 0
	_build_world()
	_show_screen()
	hud.notice("SECTOR %d / %d  ·  %s  ·  Recover and bank %d cores" % [run.sector_index + 1, run.sectors().size(), run.sector().name, run.sector().quota], run.sector().color, 4.0)


func _process(delta: float) -> void:
	if state != "paused":
		elapsed += delta
		effects.tick(delta)
	if state == "running":
		time_left = maxf(0, time_left - delta)
		run.tick(delta)
		if time_left <= 0:
			_finish(false, "The sector clock expired before the last delivery.")
		else:
			_update_dock(delta)
	_update_view()
	presenter.bank_progress = dock_progress
	presenter.navigation = _navigation_target() if state == "running" else Vector2.ZERO
	shake = maxf(0, shake - delta * 18)
	stage.position = Vector2.ZERO
	if shake > 0 and not profile.reduced_motion and state == "running" and not presenter.visible:
		stage.position = Vector2(visual_rng.randf_range(-shake, shake), visual_rng.randf_range(-shake, shake))
	arena.elapsed = elapsed
	arena.cargo = run.cargo
	arena.dock_progress = dock_progress
	arena.pilot_position = pilot.position
	arena.destination = _navigation_target() if state == "running" else Vector2.ZERO
	arena.reduced_motion = profile.reduced_motion
	arena.queue_redraw()
	hud.render(run, pilot, time_left, profile, delta if state != "paused" else 0.0)


func _update_dock(delta: float) -> void:
	if run.cargo > 0 and pilot.position.distance_to(BEACON) < 54:
		dock_progress = minf(1, dock_progress + delta / run.bank_seconds())
		if dock_progress >= 1:
			var count := run.bank_cargo()
			pilot.cargo_load = 0
			dock_progress = 0
			effects.wave(BEACON, 110, Color("78f5dd"))
			effects.callout(BEACON + Vector2(-50, -65), "%d BANKED  +%d" % [count, count * 50], Color("78f5dd"))
			sound.play("dock")
			if run.quota_met():
				_complete_sector()
	else:
		dock_progress = 0


func _complete_sector() -> void:
	run.complete_sector(time_left, pilot.health)
	carried_hull = pilot.health
	if run.sector_index == run.sectors().size() - 1:
		_finish(true)
	else:
		state = "upgrade"
		_set_active(false)
		sound.play("win")
		_show_screen()


func choose_upgrade(id: String) -> void:
	if state != "upgrade" or not run.advance(id):
		return
	carried_hull = mini(carried_hull + 1 + (1 if id == "hull" else 0), int(FlightProfile.FRAMES[run.frame].hull) + (1 if run.plating else 0) + int(run.upgrades.hull))
	sound.play("upgrade")
	_launch_sector()


func _on_core_collected(core: SalvageCore) -> void:
	if state != "running":
		return
	var points := run.collect()
	if run.free_pulse_due():
		_on_pulse()
	pilot.cargo_load = run.cargo
	effects.burst(core.position, Color("f3c77b"))
	effects.callout(core.position + Vector2(8, -20), "+%d  x%d" % [points, run.multiplier()], Color("f3c77b"))
	sound.play("core", 1.0 + run.multiplier() * 0.08)
	if first_pickup:
		first_pickup = false
		hud.notice("CARGO ABOARD  /  Chain more pickups, then return to the safe dock", Color("f3c77b"), 4)
	if (run.cargo + run.banked) % 4 == 0 and run.cargo + run.banked < int(run.sector().quota):
		_reinforcement.call_deferred()


func _reinforcement() -> void:
	if state == "running":
		_spawn_debris()


func _on_damage() -> void:
	run.break_chain()
	shake = 6
	effects.burst(pilot.position, Color("ff8e8e"), 24)
	hud.notice("HULL HIT  /  Pickup chain reset. Dash or pulse to make space.", Color("ffaaa0"), 2.5)
	sound.play("hit")


func _on_pulse() -> void:
	pilot.invulnerability = maxf(pilot.invulnerability, 0.35)
	effects.wave(pilot.position, pilot.pulse_radius, Color("b0a9ff"))
	for child in world.get_children():
		if child.has_method("receive_pulse"):
			child.receive_pulse(pilot.position, pilot.pulse_radius)
		elif child is SalvageCore and child.position.distance_to(pilot.position) < pilot.pulse_radius:
			child.pull_boost = 0.8
	sound.play("pulse")


func _on_shattered(point: Vector2, points: int) -> void:
	if state != "running":
		return
	run.score += points
	if pilot.dash_remaining > 0:
		time_left += 1.5 * int(run.upgrades.ram)
	effects.burst(point, Color("ffbd8f"), 24)
	effects.callout(point, "+%d SHATTER" % points, Color("ffbd8f"))
	sound.play("shatter")
	shake = 2.5


func _navigation_target() -> Vector2:
	if run.cargo >= 4 or run.cargo + run.banked >= int(run.sector().quota):
		return BEACON
	var closest := Vector2.ZERO
	var distance := INF
	for child in world.get_children():
		if child is SalvageCore and not child.taken:
			var next_distance := pilot.position.distance_squared_to(child.position)
			if next_distance < distance:
				distance = next_distance
				closest = child.position
	return closest


func _finish(won: bool, reason: String = "") -> void:
	if not state in ["running", "paused"]:
		return
	state = "won" if won else "lost"
	_set_active(false)
	profile.record_run(run.score, won, run.route, run.total_banked, run.sectors_cleared, run.rank())
	if won:
		effects.burst(BEACON, Color("78f5dd"), 80)
	sound.play("win" if won else "lose")
	hud.screens.present(state, run, profile, reason)


func _set_active(enabled: bool) -> void:
	pilot.active = enabled
	world.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED


func _show_screen() -> void:
	hud.screens.present(state, run, profile)
	_update_view()


func _primary_action() -> void:
	if state == "paused":
		_toggle_pause()
	elif state in ["menu", "won", "lost"]:
		start_mission()


func _toggle_pause() -> void:
	if not state in ["running", "paused"]:
		return
	state = "running" if state == "paused" else "paused"
	_set_active(state == "running")
	_show_screen()


func _toggle_sound() -> void:
	profile.muted = not profile.muted
	sound.muted = profile.muted
	profile.save()


func _toggle_motion() -> void:
	profile.reduced_motion = not profile.reduced_motion
	pilot.reduced_motion = profile.reduced_motion
	effects.reduced_motion = profile.reduced_motion
	profile.save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and auto_pause and state == "running" and is_instance_valid(pilot):
		_toggle_pause()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match key:
		KEY_ENTER, KEY_KP_ENTER:
			_primary_action()
		KEY_R:
			if state in ["won", "lost"]:
				start_mission()
		KEY_ESCAPE, KEY_P:
			_toggle_pause()
		KEY_M:
			_toggle_sound()
		KEY_F2:
			_toggle_motion()
		KEY_F3:
			if run.route == "survey":
				profile.view_3d = not profile.view_3d
				profile.save()
				_update_view()
		KEY_H:
			if state in ["won", "lost"]:
				return_to_roost()
		KEY_L, KEY_B, KEY_T, KEY_Q, KEY_F, KEY_SPACE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
			if state == "menu":
				hud.screens.hub_key(key, profile)
		KEY_1, KEY_2, KEY_3:
			if state == "upgrade":
				var index: int = key - KEY_1
				var offers := run.upgrade_offers()
				if index < offers.size():
					choose_upgrade(offers[index])


func return_to_roost() -> void:
	state = "menu"
	_set_active(false)
	_show_screen()


func _update_view() -> void:
	presenter.hub = state == "menu"
	presenter.visible = state == "menu" or run.route == "deep" or profile.view_3d
	stage.visible = not presenter.visible
	hud.notice_panel.position.y = 690 if presenter.visible else 146
	# Effects have their own projection overlay in the presenter.


func _safe_core_position(point: Vector2) -> Vector2:
	var result := point.clamp(Vector2(90, 180), Vector2(1190, 690))
	for attempt in 100:
		var valid := true
		for actor in world.get_children():
			if actor is FoundrySpire and result.distance_to(actor.position) < actor.radius + 30:
				valid = false
			if actor is GravityWell and result.distance_to(actor.position) < actor.horizon + 40:
				valid = false
			if actor is Leviathan and absf(result.y - actor.position.y) < 85 and absf(result.x - actor.position.x) < 190:
				valid = false
		if valid:
			return result
		result = Vector2(rng.randf_range(100, 1180), rng.randf_range(185, 685))
	return Vector2(640, 620)


func spawn_core(point: Vector2) -> void:
	var core := SalvageCore.new()
	core.position = _safe_core_position(point)
	core.pilot = pilot
	core.collected.connect(_on_core_collected)
	world.add_child(core)


func _build_deep_features() -> void:
	if run.sector_index == 1:
		for point in [Vector2(290, 280), Vector2(980, 270), Vector2(320, 600), Vector2(950, 600), Vector2(640, 210)]:
			var spire := FoundrySpire.new()
			spire.position = point
			world.add_child(spire)
	elif run.sector_index == 2:
		var well := GravityWell.new()
		well.position = Vector2(960, 330)
		well.pilot = pilot
		well.consumed.connect(func(_core: SalvageCore) -> void: spawn_core.call_deferred(Vector2(rng.randf_range(130, 650), 620)))
		well.inverted.connect(func() -> void:
			sound.play("inversion")
			hud.notice("WELL INVERTED  /  1.5 seconds of outward flow", Color("78f5dd"), 1.5))
		world.add_child(well)
	elif run.sector_index == 3:
		var boss := Leviathan.new()
		boss.pilot = pilot
		boss.core_shed.connect(func(point: Vector2) -> void: spawn_core.call_deferred(point))
		boss.vent_cracked.connect(func(point: Vector2) -> void:
			run.score += 400
			sound.play("vent")
			effects.callout(point, "+400 VENT CRACKED", Color("78f5dd"))
			for i in 3:
				spawn_core.call_deferred(point + Vector2((i - 1) * 40, 95)))
		boss.silenced.connect(func() -> void:
			run.score += 1500
			hud.notice("LEVIATHAN SILENCED  /  +1500", Color("78f5dd"), 5)
			effects.callout(boss.position, "LEVIATHAN SILENCED +1500", Color("78f5dd")))
		boss.beam_warned.connect(func() -> void:
			sound.play("beam")
			hud.notice("BEAM INBOUND  /  Leave the amber lane", Color("ffc780"), 1.4))
		world.add_child(boss)
