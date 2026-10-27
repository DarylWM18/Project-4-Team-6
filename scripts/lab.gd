class_name LabLevel
extends Node3D
## Deterministic, editable blockout. World coordinates also seed the AI grid.

var game: Node
var grid := AStarGrid2D.new()
var obstacles: Array[Rect2] = []
var gates: Array[Node3D] = []
var gate_open := [false, false]
var panel_mat := WorldArt.material(Color("b9c4bc"), 0.25)
var dark_mat := WorldArt.material(Color("1b2b32"), 0.35)
var floor_mat := WorldArt.material(Color("34464c"), 0.35)
var floor_alt := WorldArt.material(Color("3b5055"), 0.3)
var brass := WorldArt.material(Color("aa8750"), 0.7)
var wood := WorldArt.material(Color("513a2d"), 0.1)
var cyan := WorldArt.material(Color("75d9dd"), 0.2, 1.8)
var amber := WorldArt.material(Color("e5ae63"), 0.1, 1.5)
var red := WorldArt.material(Color("ed6a4e"), 0.1, 1.6)

func _ready() -> void:
	_environment()
	_room(0, 0, 18, 20, "NEURAL RECOVERY", "01", false)
	_room(1, -25, 22, 22, "CONTAINMENT", "02", true)
	_room(2, -50, 18, 20, "TRANSIT LOCK", "03", true)
	_corridor(-12)
	_corridor(-38)
	_create_gate(-10)
	_create_gate(-36)
	_furnish_recovery()
	_furnish_containment()
	_furnish_transit()
	_build_grid()
	_spawn_subjects()
	_batch_static_boxes()

func _environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101a22")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8aabb9")
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("21333b")
	env.fog_density = 0.009
	world.environment = env
	add_child(world)

func _room(index: int, center: float, width: int, depth: int, title: String,
		number: String, south_open: bool) -> void:
	var half_w := width * 0.5
	var north := center - depth * 0.5
	var south := center + depth * 0.5
	WorldArt.box(self, Vector3(0, -0.25, center), Vector3(width, 0.5, depth), floor_mat, true)
	for x in range(-width / 2, width / 2, 2):
		for z in range(int(north), int(south), 2):
			WorldArt.box(self, Vector3(x + 0.99, 0.006, z + 0.99), Vector3(1.95, 0.015, 1.95),
				floor_alt if (x + z) % 4 == 0 else floor_mat)
	WorldArt.box(self, Vector3(0, 5.2, center), Vector3(width, 0.3, depth), dark_mat, true)
	for side in [-1.0, 1.0]:
		var wall_x: float = side * half_w
		WorldArt.box(self, Vector3(wall_x, 2.5, center), Vector3(0.45, 5, depth), dark_mat, true)
		for z in range(int(north + 2), int(south), 4):
			WorldArt.box(self, Vector3(wall_x - side * 0.26, 2.6, z), Vector3(0.08, 2.7, 3.65), panel_mat)
			WorldArt.box(self, Vector3(wall_x - side * 0.28, 0.85, z), Vector3(0.1, 1.25, 3.65), wood)
			WorldArt.box(self, Vector3(wall_x - side * 0.35, 1.55, z), Vector3(0.13, 0.06, 3.8), brass)
			WorldArt.box(self, Vector3(wall_x - side * 0.45, 2.5, z - 1.95), Vector3(0.45, 5, 0.25), dark_mat)
		WorldArt.box(self, Vector3(side * (half_w - 0.45), 0.05, center), Vector3(0.08, 0.03, depth - 1), cyan)
		for z in [center - 5, center + 5]:
			WorldArt.box(self, Vector3(side * 4.5, 4.96, z), Vector3(0.28, 0.08, 3.8), cyan if index != 2 else amber)
			WorldArt.lamp(self, Vector3(side * 4.5, 3.8, z), Color("a5d7df") if index != 2 else Color("f2c48e"), 2.0, 11.0)
	_wall_end(north, width, true)
	_wall_end(south, width, south_open)
	# Overhead ribs and recessed services give the blockout a strong silhouette.
	for z in range(int(north + 2), int(south), 4):
		WorldArt.box(self, Vector3(0, 4.75, z), Vector3(width, 0.32, 0.22), dark_mat)
	for x in [-1.4, 1.4]:
		var pipe := WorldArt.cylinder(self, Vector3(x, 4.7, center), 0.11, depth, brass)
		pipe.rotation_degrees.x = 90
	WorldArt.box(self, Vector3(0, 3.75, north + 0.27), Vector3(6.6, 1.1, 0.16), dark_mat)
	WorldArt.text(self, Vector3(0, 3.87, north + 0.38), number + " / " + title, 42)
	WorldArt.text(self, Vector3(0, 3.42, north + 0.38), "AEGIS   /   BIOLOGICAL RESEARCH DIVISION", 17, Color("ba9d6b"))
	# A worn central guidance line leads toward each room's lock.
	for z in range(int(north + 2), int(south - 2), 3):
		WorldArt.box(self, Vector3(0, 0.025, z), Vector3(0.06, 0.025, 1.1), brass)

func _wall_end(z: float, width: float, opening: bool) -> void:
	if not opening:
		WorldArt.box(self, Vector3(0, 2.5, z), Vector3(width, 5, 0.45), panel_mat, true)
		return
	var segment := (width - 5.0) * 0.5
	for side in [-1.0, 1.0]:
		WorldArt.box(self, Vector3(side * (2.5 + segment * 0.5), 2.5, z), Vector3(segment, 5, 0.45), panel_mat, true)
	WorldArt.box(self, Vector3(0, 4.3, z), Vector3(5, 1.4, 0.45), dark_mat, true)
	for side in [-1.0, 1.0]:
		WorldArt.box(self, Vector3(side * 2.55, 1.8, z + 0.3), Vector3(0.2, 3.6, 0.25), brass)

func _corridor(z: float) -> void:
	WorldArt.box(self, Vector3(0, -0.2, z), Vector3(5, 0.4, 4.4), dark_mat, true)
	WorldArt.box(self, Vector3(0, 4.0, z), Vector3(5, 0.3, 4.4), dark_mat, true)
	for side in [-1.0, 1.0]:
		WorldArt.box(self, Vector3(side * 2.6, 2, z), Vector3(0.3, 4, 4.4), wood, true)
		WorldArt.box(self, Vector3(side * 2.4, 0.3, z), Vector3(0.08, 0.1, 4), cyan)
	WorldArt.lamp(self, Vector3(0, 3, z), Color("d8ba8c"), 1.3, 6)

func _create_gate(z: float) -> void:
	var gate := Node3D.new()
	add_child(gate)
	gate.position.z = z
	WorldArt.box(gate, Vector3(0, 1.8, 0), Vector3(4.8, 3.6, 0.35), dark_mat, true)
	for side in [-1.0, 1.0]:
		WorldArt.box(gate, Vector3(side * 1.15, 1.8, 0.21), Vector3(2.1, 3.2, 0.12), wood)
		WorldArt.box(gate, Vector3(side * 0.12, 1.8, 0.32), Vector3(0.06, 2.8, 0.05), red)
	WorldArt.text(gate, Vector3(0, 2.5, 0.33), "TRIAL LOCK", 35, Color("eeb779"))
	WorldArt.text(gate, Vector3(0, 1.9, 0.33), "CLEAR ALL SUBJECTS", 20)
	gates.append(gate)

func open_gate(index: int) -> void:
	if index >= gates.size() or gate_open[index]:
		return
	gate_open[index] = true
	_disable_collision(gates[index])
	var tween := create_tween()
	tween.tween_property(gates[index], "position:y", 4.2, 1.2).set_trans(Tween.TRANS_CUBIC)
	_build_grid()

func _disable_collision(root: Node) -> void:
	if root is CollisionObject3D:
		root.set_deferred("collision_layer", 0)
	for child in root.get_children():
		_disable_collision(child)

func _obstacle(pos: Vector3, size: Vector3, mat: Material) -> void:
	WorldArt.box(self, pos, size, mat, true)
	obstacles.append(Rect2(Vector2(pos.x - size.x * 0.5 - 0.4, pos.z - size.z * 0.5 - 0.4), Vector2(size.x + 0.8, size.z + 0.8)))

func _table(pos: Vector3, width: float = 3.0) -> void:
	_obstacle(pos + Vector3(0, 0.6, 0), Vector3(width, 1.2, 1.2), dark_mat)
	WorldArt.box(self, pos + Vector3(0, 1.23, 0), Vector3(width + 0.1, 0.08, 1.3), panel_mat)
	WorldArt.box(self, pos + Vector3(0, 0.85, 0.62), Vector3(width - 0.2, 0.04, 0.03), brass)

func _furnish_recovery() -> void:
	_table(Vector3(0, 0, 3.5), 2.8)
	spawn_pickup("wrench", Vector3(0, 1.55, 3.85))
	WorldArt.text(self, Vector3(0, 2.15, 3.6), "MAINTENANCE / TAKE EQUIPMENT [E]", 21, Color("e9bc76"))
	_table(Vector3(-6.5, 0, -1), 3.0)
	spawn_pickup("tray", Vector3(-6.5, 1.55, -0.8))
	# Empty recovery bed and the player's broken pod.
	_obstacle(Vector3(6.2, 0.5, 4), Vector3(2.1, 1, 4), dark_mat)
	WorldArt.box(self, Vector3(6.2, 1.1, 4), Vector3(1.7, 0.25, 3.7), panel_mat)
	WorldArt.box(self, Vector3(6.2, 1.35, 2.5), Vector3(1.5, 0.3, 0.6), wood)
	WorldArt.text(self, Vector3(0, 3.1, 9.72), "EXPERIMENT 06\nCONTAINMENT FAILED", 45, Color("f2bb7d")).rotation_degrees.y = 180
	for x in [-7.5, 7.5]:
		_obstacle(Vector3(x, 1.1, -6.8), Vector3(1.3, 2.2, 1.3), dark_mat)
		WorldArt.box(self, Vector3(x, 1.8, -6.1), Vector3(1.0, 0.3, 0.03), cyan)
	_interactable("recording", Vector3(-6.5, 1.85, -1.7))

func _furnish_containment() -> void:
	_table(Vector3(-5.5, 0, -17.5), 4.0)
	_interactable("note", Vector3(-5.5, 1.85, -18))
	WorldArt.text(self, Vector3(-5.5, 2.8, -18), "SUBJECT ARCHIVE / 06", 27, Color("e9bc76"))
	spawn_pickup("pipe", Vector3(5.0, 0.4, -18))
	spawn_pickup("tray", Vector3(-8, 0.4, -29))
	for x in [-7.0, 7.0]:
		for z in [-24.0, -31.0]:
			_chamber(Vector3(x, 0, z))
	var warning := WorldArt.text(self, Vector3(10.65, 2.7, -25), "WARNING\nSUBJECTS HAVE ESCAPED CONTAINMENT", 26, Color("f0b275"))
	warning.rotation_degrees.y = -90

func _chamber(pos: Vector3) -> void:
	_obstacle(pos + Vector3(0, 0.3, 0), Vector3(2.4, 0.6, 2.4), dark_mat)
	WorldArt.cylinder(self, pos + Vector3(0, 0.63, 0), 1.15, 0.15, brass)
	WorldArt.cylinder(self, pos + Vector3(0, 3.6, 0), 1.15, 0.28, dark_mat)
	for x in [-0.9, 0.9]:
		WorldArt.box(self, pos + Vector3(x, 2.1, -0.7), Vector3(0.12, 2.9, 0.12), brass)
	WorldArt.box(self, pos + Vector3(0, 2.1, -0.95), Vector3(1.7, 2.8, 0.05), WorldArt.material(Color("29484e"), 0.65))
	# Uneven opaque glass shards retain the low-poly silhouette without sorting artifacts.
	for side in [-1.0, 1.0]:
		var shard := WorldArt.box(self, pos + Vector3(side * 0.8, 1.0, 0.8), Vector3(0.4, 0.7, 0.05), WorldArt.material(Color("6c9da4"), 0.5))
		shard.rotation_degrees.z = side * 23
	WorldArt.lamp(self, pos + Vector3(0, 2.8, 0), Color("b5e8df"), 0.8, 5)
	for i in range(5):
		var shard := WorldArt.box(self, pos + Vector3(sin(i * 2.3) * 1.7, 0.08, 1.3 + cos(i) * 0.7), Vector3(0.2, 0.04, 0.4), panel_mat)
		shard.rotation_degrees.y = i * 37

func _furnish_transit() -> void:
	_table(Vector3(5.8, 0, -43), 3.0)
	spawn_pickup("baton", Vector3(5.8, 1.55, -42.8))
	spawn_pickup("pipe", Vector3(-6.5, 0.4, -47))
	spawn_pickup("wrench", Vector3(7, 0.4, -54))
	for x in [-4.7, 4.7]:
		_obstacle(Vector3(x, 0.75, -51), Vector3(1.5, 1.5, 3), wood)
		WorldArt.box(self, Vector3(x, 1.52, -51), Vector3(1.6, 0.08, 3.1), brass)
	# Final door is deliberately sealed; only the override after the trial opens it.
	WorldArt.box(self, Vector3(0, 1.8, -60), Vector3(4.8, 3.6, 0.5), dark_mat, true)
	WorldArt.box(self, Vector3(0, 1.8, -59.7), Vector3(4.2, 3.2, 0.05), wood)
	WorldArt.text(self, Vector3(0, 3.95, -59.65), "SURFACE / EGRESS", 47, Color("e8bb77"))
	_interactable("exit", Vector3(0, 1.65, -59.5))
	WorldArt.text(self, Vector3(0, 2.9, -59.5), "THE EXIT IS AHEAD", 23)
	var body := WorldArt.mutant(self)
	body.position = Vector3(-3.2, 0.35, -57.5)
	body.rotation_degrees.z = 90
	WorldArt.text(self, Vector3(-3.2, 1.3, -58.7), "SUBJECT 05 / SIGNAL LOST", 20, Color("d49978"))
	WorldArt.lamp(self, Vector3(-3, 2, -57), Color("ed825c"), 1.5, 7)

func _interactable(kind: String, pos: Vector3) -> void:
	var terminal := LabInteractable.new()
	terminal.kind = kind
	terminal.game = game
	add_child(terminal)
	terminal.position = pos

func spawn_pickup(id: String, pos: Vector3, remaining: float = -1.0) -> LabPickup:
	var item := LabPickup.new()
	item.item_id = id
	item.durability = remaining
	add_child(item)
	item.position = pos
	return item

func _spawn_subjects() -> void:
	var positions := [
		[Vector3(-5, 0.1, -4), Vector3(5, 0.1, -4), Vector3(0, 0.1, -7)],
		[Vector3(-2, 0.1, -23), Vector3(3, 0.1, -24), Vector3(-4, 0.1, -28), Vector3(4, 0.1, -32), Vector3(0, 0.1, -33)],
		[Vector3(-5, 0.1, -47), Vector3(4, 0.1, -47), Vector3(0, 0.1, -50), Vector3(-6, 0.1, -54), Vector3(5, 0.1, -56), Vector3(0, 0.1, -57)]
	]
	for room in positions.size():
		for pos in positions[room]:
			var enemy := LabEnemy.new()
			enemy.game = game
			enemy.room_index = room
			add_child(enemy)
			enemy.position = pos

func _walkable(point: Vector2) -> bool:
	return Rect2(-8.35, -9.4, 16.7, 18.8).has_point(point) or Rect2(-10.35, -35.4, 20.7, 20.8).has_point(point) or Rect2(-8.35, -59.4, 16.7, 18.8).has_point(point) or Rect2(-1.85, -41.0, 3.7, 32.0).has_point(point)

func _build_grid() -> void:
	grid.region = Rect2i(-12, -62, 25, 74)
	grid.cell_size = Vector2.ONE
	grid.offset = Vector2(0.5, 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(-12, 13):
		for z in range(-62, 12):
			var point := Vector2(x + 0.5, z + 0.5)
			var solid := not _walkable(point)
			for obstacle in obstacles:
				if obstacle.has_point(point):
					solid = true
			for i in gates.size():
				if not gate_open[i] and absf(point.y - gates[i].position.z) < 0.8:
					solid = true
			grid.set_point_solid(Vector2i(x, z), solid)

func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var start := _nearest_cell(Vector2i(floori(from.x), floori(from.z)))
	var end := _nearest_cell(Vector2i(floori(to.x), floori(to.z)))
	var result := PackedVector3Array()
	if start == Vector2i(999, 999) or end == Vector2i(999, 999):
		return result
	var points := grid.get_id_path(start, end, true)
	for i in range(1, points.size()):
		result.append(Vector3(points[i].x + 0.5, 0.1, points[i].y + 0.5))
	return result

func _nearest_cell(cell: Vector2i) -> Vector2i:
	for radius in range(4):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var candidate := cell + Vector2i(x, y)
				if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate):
					return candidate
	return Vector2i(999, 999)

func _batch_static_boxes() -> void:
	# Share a unit cube for static geometry. Chunk by room so lights and culling
	# remain local. Original nodes keep their colliders; moving items stay separate.
	var groups: Dictionary = {}
	_collect_boxes(self, groups)
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	for key in groups:
		var group: Dictionary = groups[key]
		var batch := MultiMeshInstance3D.new()
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = cube
		instances.instance_count = group.transforms.size()
		for i in group.transforms.size():
			instances.set_instance_transform(i, group.transforms[i])
		batch.multimesh = instances
		batch.material_override = group.material
		batch.name = "StaticBatch_" + str(key)
		add_child(batch)

func _collect_boxes(node: Node, groups: Dictionary) -> void:
	if node is LabPickup or node is LabEnemy:
		return
	if node is Node3D and node in gates:
		return
	if node is MeshInstance3D and node.mesh is BoxMesh:
		var local: Transform3D = global_transform.affine_inverse() * node.global_transform
		var chunk := 0 if local.origin.z >= -12 else (1 if local.origin.z >= -38 else 2)
		var key := "%d_%d" % [chunk, node.material_override.get_instance_id()]
		if not groups.has(key):
			groups[key] = {"material": node.material_override, "transforms": []}
		var dimensions: Vector3 = node.mesh.size
		groups[key].transforms.append(local * Transform3D(Basis.from_scale(dimensions), Vector3.ZERO))
		node.visible = false
	for child in node.get_children():
		_collect_boxes(child, groups)
