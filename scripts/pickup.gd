class_name LabPickup
extends StaticBody3D

var item_id := "wrench"
var durability := -1.0
var model: Node3D
var elapsed := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(0.8, 0.65, 0.8)
	shape.shape = bounds
	add_child(shape)
	model = WorldArt.equipment_model(item_id)
	add_child(model)
	model.scale = Vector3.ONE * 0.7
	model.rotation_degrees = Vector3(0, 22, 65)
	var color: Color = Equipment.definition(item_id).color
	WorldArt.cylinder(self, Vector3(0, -0.24, 0), 0.43, 0.018,
		WorldArt.material(color, 0.2, 1.0))
	WorldArt.lamp(self, Vector3(0, 0.35, 0), color, 0.35, 2.5)
	if durability < 0.0:
		durability = Equipment.definition(item_id).durability
	add_to_group("pickups")

func _process(delta: float) -> void:
	elapsed += delta
	model.position.y = sin(elapsed * 2.0) * 0.035

func prompt() -> String:
	var data := Equipment.definition(item_id)
	return "[E]  TAKE " + data.name + "  /  %d%% integrity" % roundi(durability / float(data.durability) * 100)

func interact(player: Node) -> void:
	player.equip(item_id, durability)
	queue_free()
