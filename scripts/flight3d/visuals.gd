class_name FlightVisuals
extends RefCounted
## Reusable inexpensive geometry. Telegraph cylinders are allocated once.
static func sphere_shape(parent: Node3D, radius: float) -> void:
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	collision.shape = sphere
	parent.add_child(collision)

static func ring(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.09
	mesh.outer_radius = radius + 0.09
	mesh.rings = 48
	mesh.ring_segments = 8
	node.mesh = mesh
	node.material_override = ModelAssets.material(color, true)
	parent.add_child(node)
	return node

static func cylinder(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1
	mesh.radial_segments = 12
	node.mesh = mesh
	var mat := ModelAssets.material(color, true)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	parent.add_child(node)
	return node

static func aim_cylinder(node: MeshInstance3D, start: Vector3, finish: Vector3) -> void:
	var direction := finish - start
	node.global_position = (start + finish) * 0.5
	if direction.length() > 0.01:
		var up := Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
		node.look_at_from_position(node.global_position, finish, up)
		node.rotate_object_local(Vector3.RIGHT, PI / 2)
		node.scale = Vector3(1, direction.length(), 1)

static func environment(parent: Node3D) -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var panorama := ModelAssets.sky_texture()
	if panorama:
		var material := PanoramaSkyMaterial.new()
		material.panorama = panorama
		sky.sky_material = material
	else:
		var material := ProceduralSkyMaterial.new()
		material.sky_top_color = Color("020612")
		material.sky_horizon_color = Color("173145")
		sky.sky_material = material
	settings.sky = sky
	settings.sky_rotation = Vector3(deg_to_rad(-45), PI + 0.35, 0)
	settings.background_energy_multiplier = 0.6
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("91b7d1")
	settings.ambient_light_energy = 0.5
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings
	parent.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_color = Color("fff0da")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220
	parent.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(32, 145, 0)
	fill.light_color = Color("78cbbf")
	fill.light_energy = 0.35
	parent.add_child(fill)
