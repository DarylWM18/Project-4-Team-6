class_name WorldArt
extends RefCounted
## Original primitive art: faceted forms, dark enamel, ivory panels and brass.

static func material(color: Color, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.65
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material,
		collision: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = mat
	parent.add_child(mesh)
	mesh.position = pos
	if collision:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var collider := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collider.shape = box_shape
		body.add_child(collider)
		mesh.add_child(body)
	return mesh

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float,
		mat: Material, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius if top_radius < 0.0 else top_radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 8
	shape.rings = 1
	mesh.mesh = shape
	mesh.material_override = mat
	parent.add_child(mesh)
	mesh.position = pos
	return mesh

static func text(parent: Node3D, pos: Vector3, words: String, size: int = 46,
		color: Color = Color("c5dadd")) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.font_size = size
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_size = 0
	parent.add_child(label)
	label.position = pos
	return label

static func lamp(parent: Node3D, pos: Vector3, color: Color, power: float = 1.7,
		radius: float = 10.0) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = power
	light.omni_range = radius
	light.omni_attenuation = 1.4
	parent.add_child(light)
	light.position = pos
	return light

static func equipment_model(id: String) -> Node3D:
	var root := Node3D.new()
	var steel := material(Color("8c9c9d"), 0.75)
	var grip := material(Color("233237"))
	var brass := material(Color("b69860"), 0.7)
	match id:
		"wrench":
			box(root, Vector3.ZERO, Vector3(0.12, 0.65, 0.12), steel)
			box(root, Vector3(0, -0.12, 0), Vector3(0.15, 0.28, 0.15), grip)
			box(root, Vector3(0, 0.38, 0), Vector3(0.32, 0.16, 0.15), brass)
			box(root, Vector3(-0.14, 0.49, 0), Vector3(0.09, 0.2, 0.15), steel)
			box(root, Vector3(0.14, 0.46, 0), Vector3(0.09, 0.14, 0.15), steel)
		"pipe":
			cylinder(root, Vector3(0, 0.15, 0), 0.065, 1.25, steel)
			cylinder(root, Vector3(0, 0.62, 0), 0.11, 0.16, brass)
			box(root, Vector3(0.12, 0.78, 0), Vector3(0.34, 0.12, 0.13), steel)
			cylinder(root, Vector3(0, -0.28, 0), 0.077, 0.3, grip)
		"tray":
			box(root, Vector3(0, 0.22, 0), Vector3(0.65, 0.9, 0.07), steel)
			for x in [-0.32, 0.32]:
				box(root, Vector3(x, 0.22, -0.04), Vector3(0.05, 0.9, 0.09), brass)
			for y in [-0.21, 0.65]:
				box(root, Vector3(0, y, -0.04), Vector3(0.65, 0.05, 0.09), brass)
			box(root, Vector3(0, 0.1, 0.08), Vector3(0.22, 0.08, 0.11), grip)
		"baton":
			cylinder(root, Vector3(0, 0.18, 0), 0.065, 0.95, grip)
			cylinder(root, Vector3(0, 0.4, 0), 0.075, 0.42, brass)
			box(root, Vector3(0, 0.63, 0), Vector3(0.12, 0.08, 0.12),
				material(Color("73e6e2"), 0.3, 2.0))
	return root

static func mutant(parent: Node3D, variant: int = 0) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var flesh := material(Color("555f68") if variant == 0 else Color("6c505b"), 0.15)
	var dark := material(Color("17222a"), 0.2)
	var bone := material(Color("c6bda1"))
	var glow := material(Color("f17d62"), 0.0, 2.5)
	cylinder(root, Vector3(0, 0.9, 0), 0.36, 0.85, flesh, 0.22)
	var head := box(root, Vector3(0, 1.58, -0.04), Vector3(0.38, 0.43, 0.36), dark)
	head.rotation_degrees.z = -12
	box(root, Vector3(0, 1.63, -0.23), Vector3(0.32, 0.055, 0.035), glow)
	for side in [-1.0, 1.0]:
		var leg := cylinder(root, Vector3(side * 0.21, 0.32, 0), 0.105, 0.67, dark, 0.15)
		leg.rotation_degrees.z = side * -12
		var arm := cylinder(root, Vector3(side * 0.47, 0.88, -0.05), 0.09, 0.9, flesh, 0.16)
		arm.rotation_degrees.z = side * 22
		cylinder(root, Vector3(side * 0.61, 0.38, -0.1), 0.09, 0.33, bone, 0.01)
		var spike := cylinder(root, Vector3(side * 0.31, 1.37, 0.12), 0.13, 0.5, bone, 0.0)
		spike.rotation_degrees.z = side * -36
	return root
