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
