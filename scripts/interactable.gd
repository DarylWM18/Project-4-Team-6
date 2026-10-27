class_name LabInteractable
extends StaticBody3D

var kind := "note"
var game: Node

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(1.1, 0.9, 0.25)
	shape.shape = bounds
	add_child(shape)
	WorldArt.box(self, Vector3.ZERO, bounds.size, WorldArt.material(Color("172a31"), 0.5))
	WorldArt.box(self, Vector3(0, 0, 0.14), Vector3(0.95, 0.72, 0.03),
		WorldArt.material(Color("26545a"), 0.0, 0.5))
	var title := "SUBJECT 06\nPERSONNEL FILE"
	if kind == "recording":
		title = "AUDIO LOG\nDR. H. VALE"
	elif kind == "exit":
		title = "SURFACE ACCESS\nOVERRIDE"
	WorldArt.text(self, Vector3(0, 0, 0.17), title, 25)

func prompt() -> String:
	match kind:
		"note": return "[E]  READ SUBJECT FILE"
		"recording": return "[E]  PLAY SCIENTIST RECORDING"
		"exit": return "[E]  OVERRIDE SURFACE LOCK"
	return ""

func interact(_player: Node) -> void:
	game.interact_story(kind)
