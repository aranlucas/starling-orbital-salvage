class_name OrbitPresenter
extends Node2D
## A render-only mirror. Actor identity and all collisions stay in the 2D world.
const SCALE := 25.0
var viewport: SubViewport
var world_3d: Node3D
var camera: Camera3D
var mirrors: Dictionary = {}
var dock: Node3D
var bank_ring: MeshInstance3D
var station: Node3D
var display_ship: Node3D
var hub_root: Node3D
var flight_root: Node3D
var telegraphs: Node3D
var frame_shown := ""
var elapsed := 0.0
var hub := true
var reduced_motion := false
var profile: FlightProfile
var sim: Node2D
var pilot: Pilot
var bank_progress := 0.0
var navigation := Vector2.ZERO
var overlay: Node2D

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var texture := TextureRect.new()
	texture.texture = viewport.get_texture()
	texture.size = Vector2(1280, 800)
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(texture)
	world_3d = Node3D.new()
	viewport.add_child(world_3d)
	camera = Camera3D.new()
	camera.fov = 38
	camera.far = 300
	world_3d.add_child(camera)
	camera.position = Vector3(0, 46, 38)
	camera.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_color = Color("dbe9ff")
	light.light_energy = 1.1
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 140
	world_3d.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 145, 0)
	fill.light_color = Color("78cbbf")
	fill.light_energy = 0.35
	world_3d.add_child(fill)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_texture := ModelAssets.sky_texture()
	if sky_texture:
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = sky_texture
		sky.sky_material = panorama
	else:
		var procedural := ProceduralSkyMaterial.new()
		procedural.sky_top_color = Color("020612")
		procedural.sky_horizon_color = Color("173145")
		procedural.ground_horizon_color = Color("173145")
		procedural.ground_bottom_color = Color("040b18")
		sky.sky_material = procedural
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7596b0")
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Godot 4.7 Compatibility supports glow; retain the portable renderer.
	environment.glow_enabled = true
	environment.glow_intensity = 0.28
	env.environment = environment
	world_3d.add_child(env)
	flight_root = Node3D.new()
	world_3d.add_child(flight_root)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(49, 25)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.material_override = ModelAssets.material(Color("102332"))
	floor_node.material_override.roughness = 1.0
	floor_node.material_override.metallic_specular = 0.0
	floor_node.position.y = -0.55
	flight_root.add_child(floor_node)
	for x in range(-24, 25, 4):
		_line(flight_root, Vector3(x, -0.5, -12), Vector3(x, -0.5, 12), Color("203645"), 0.015)
	for z in range(-12, 13, 4):
		_line(flight_root, Vector3(-24, -0.5, z), Vector3(24, -0.5, z), Color("203645"), 0.015)
	for z in [-12.0, 12.0]:
		_line(flight_root, Vector3(-24, -0.48, z), Vector3(24, -0.48, z), Color("78a8b1"), 0.035)
	for x in [-24.0, 24.0]:
		_line(flight_root, Vector3(x, -0.48, -12), Vector3(x, -0.48, 12), Color("78a8b1"), 0.035)
	dock = ModelAssets.model("dock_beacon", "energy_core")
	dock.scale = Vector3.ONE * 1.1
	flight_root.add_child(dock)
	bank_ring = _ring(2.5, Color("78f5dd"))
	bank_ring.position.y = 0.15
	flight_root.add_child(bank_ring)
	telegraphs = Node3D.new()
	flight_root.add_child(telegraphs)
	hub_root = Node3D.new()
	hub_root.scale = Vector3.ONE * 0.9
	world_3d.add_child(hub_root)
	station = ModelAssets.model("roost_station", "drone")
	hub_root.add_child(station)
	overlay = Node2D.new()
	overlay.set_script(load("res://scripts/projection_overlay.gd"))
	overlay.presenter = self
	add_child(overlay)

static func map_position(point: Vector2, height: float = 0.0) -> Vector3:
	return Vector3((point.x - 640) / SCALE, height, (point.y - 431) / SCALE)

func project(point: Vector2, height: float = 0.3) -> Vector2:
	return camera.unproject_position(map_position(point, height))

func _ring(radius: float, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.035
	mesh.outer_radius = radius + 0.035
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = ModelAssets.material(color, true)
	return node

func _line(parent: Node3D, start: Vector3, finish: Vector3, color: Color, width: float = 0.06) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, start.distance_to(finish))
	node.mesh = mesh
	node.material_override = ModelAssets.material(color, true)
	parent.add_child(node)
	node.position = (start + finish) * 0.5
	if start.distance_to(finish) > 0.001:
		node.look_at(finish, Vector3.UP)
	return node

func _actor_model(actor: Node) -> Node3D:
	var id := "asteroid"
	var factor := 1.0
	if actor is Pilot:
		id = "ship" if actor.frame == "starling" else actor.frame
		factor = 0.8
	elif actor is SalvageCore:
		id = "energy_core"
		factor = 0.72
	elif actor is Debris:
		id = ["asteroid", "asteroid_b", "asteroid_c"][actor.get_instance_id() % 3]
		factor = actor.radius / 28.0 * 0.65
	elif actor is SentryDrone:
		id = "drone"
		factor = 0.8
	elif actor is SalvageWing:
		id = "salvage_wing"
		factor = 0.8
	elif actor is MeteorStorm:
		id = "meteor"
		factor = 0.7
	var wrapper := Node3D.new()
	var model := ModelAssets.model(id, "ship" if actor is Pilot else "asteroid")
	model.name = "Model"
	model.scale = Vector3.ONE * factor
	wrapper.add_child(model)
	return wrapper

func sync() -> void:
	if not is_instance_valid(sim):
		return
	var live: Dictionary = {}
	for actor in sim.get_children():
		var key := actor.get_instance_id()
		live[key] = true
		if not mirrors.has(key):
			var node := _actor_model(actor)
			flight_root.add_child(node)
			mirrors[key] = node
		var mirror: Node3D = mirrors[key]
		mirror.position = map_position(actor.position, 0.3)
		mirror.visible = true
		if actor is Pilot:
			var desired: float = -actor.heading.angle() - PI / 2
			var previous := mirror.rotation.y
			mirror.rotation.y = lerp_angle(previous, desired, 0.25)
			mirror.rotation.z = 0 if reduced_motion else clampf(angle_difference(previous, desired) * 0.2, -0.25, 0.25)
		elif actor is SalvageCore:
			mirror.position.y = 0.55 + (0.0 if reduced_motion else sin(elapsed * 2 + actor.position.x) * 0.15)
			mirror.rotation.y = elapsed * 0.65
			mirror.visible = not actor.taken
		elif actor is Debris:
			mirror.rotation = Vector3(actor.rotation * 0.7, actor.rotation, actor.rotation * 0.4)
		elif actor is SalvageWing:
			mirror.rotation.y = -actor.phase - actor.orbit
		elif actor is SentryDrone:
			mirror.rotation.y = -actor.heading.angle() - PI / 2
		elif actor is MeteorStorm:
			mirror.visible = actor.flight > 0
			mirror.position = map_position(actor.meteor_position, 0.6)

	for key in mirrors.keys():
		if not live.has(key):
			mirrors[key].queue_free()
			mirrors.erase(key)

func _process(delta: float) -> void:
	if not visible or profile == null:
		return
	elapsed += delta
	reduced_motion = profile.reduced_motion
	hub_root.visible = hub
	flight_root.visible = not hub
	if hub:
		camera.fov = 40
		camera.position = Vector3(15, 12, 21)
		camera.look_at(Vector3(0, 0, 0))
		# Shift the station into the right half of the screen.
		camera.h_offset = -6.6
		station.rotation.y = 0 if reduced_motion else sin(elapsed * 0.12) * 0.12
		for module in ["Charts", "Kestrel", "Albatross", "Fabricator", "Plating", "Broker", "Rig"]:
			var node := ModelAssets.part(station, "Module_" + module)
			if node:
				node.visible = module_owned(module)
		for i in 6:
			var indicator := ModelAssets.part(station, "Fabricator indicator %d" % i)
			if indicator:
				indicator.visible = profile.owns(["chain", "ballast", "chrono", "ram", "wing", "overdrive"][i])
		if frame_shown != profile.selected_frame:
			if display_ship:
				display_ship.queue_free()
			frame_shown = profile.selected_frame
			display_ship = ModelAssets.model("ship" if frame_shown == "starling" else frame_shown, "ship")
			hub_root.add_child(display_ship)
		var pad := ModelAssets.part(station, "Pad")
		display_ship.global_position = pad.to_global(Vector3(0, 0.7, -7)) if pad else Vector3(0, 1.8, 0)
		display_ship.rotation.y = 0 if reduced_motion else elapsed * 0.24
	else:
		camera.fov = 38
		camera.h_offset = 0
		var follow := Vector3.ZERO
		if is_instance_valid(pilot) and not reduced_motion:
			follow = map_position(pilot.position) * 0.025
		camera.position = Vector3(0, 46, 38) + follow
		camera.look_at(Vector3(0, 0, 0) + follow)
		sync()
		bank_ring.scale = Vector3.ONE * (1 + bank_progress * 0.15)
		bank_ring.visible = bank_progress > 0
		_update_telegraphs()
	overlay.queue_redraw()

func module_owned(module: String) -> bool:
	for id in FlightProfile.ITEMS:
		if FlightProfile.ITEMS[id].module == module and profile.owns(id):
			return true
	return false

func _update_telegraphs() -> void:
	for child in telegraphs.get_children():
		child.free()
	for actor in sim.get_children():
		if actor is MeteorStorm:
			var warning: float = actor.warning
			var danger: float = actor.flight
			if warning > 0 or danger > 0:
				var color := Color("ffc780") if warning > 0 else Color("ff796e")
				var a := map_position(actor.lane_start, 0.13)
				var b := map_position(actor.lane_end, 0.13)
				_line(telegraphs, a, b, color, 0.06 if warning > 0 else 1.5)
				for side in [-1, 1]:
					_line(telegraphs, a + Vector3(0, 0, side), b + Vector3(0, 0, side), color, 0.03)
		elif actor is SentryDrone and actor.windup > 0:
			_line(telegraphs, map_position(actor.position, 0.4), map_position(actor.position + actor.heading * 220, 0.4), Color("ffaaa0"), 0.06)
