class_name ModelAssets
extends RefCounted
## All optional art enters here. Missing or not-yet-imported GLBs remain playable.
static func model(id: String, fallback: String = "asteroid") -> Node3D:
	for name in [id, fallback]:
		var path := "res://assets/models/%s.glb" % name
		if ResourceLoader.exists(path):
			var resource := load(path)
			if resource is PackedScene:
				return resource.instantiate() as Node3D
	var node := MeshInstance3D.new()
	node.mesh = SphereMesh.new()
	node.material_override = material(Color("78f5dd"))
	return node

static func part(root: Node, name: String) -> Node3D:
	var found := root.find_child(name, true, false)
	if found == null:
		found = root.find_child(name + "*", true, false)
	return found as Node3D

static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.65
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2
	return mat

static func sky_texture() -> Texture2D:
	var path := "res://assets/art/deep_orbit_sky.png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

static func bounds(root: Node3D) -> AABB:
	# GLTF empties can sit at (0,0,0) while their child meshes carry baked positions.
	var result := AABB()
	var first := true
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for mesh in meshes:
		var box: AABB = (root.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result

static func part_position(root: Node3D, name: String, fallback: Vector3) -> Vector3:
	var node := part(root, name)
	if node == null:
		return fallback
	return root.to_local(node.to_global(bounds(node).get_center()))
