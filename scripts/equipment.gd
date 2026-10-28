class_name Equipment
extends RefCounted
## Found equipment only. New items need a definition and a model in WorldArt.

const ITEMS := {
	"wrench": {"name": "SERVICE WRENCH", "damage": 36.0, "reach": 2.7, "cooldown": 0.42,
		"block": 0.65, "durability": 100.0, "color": Color("bfa77c")},
	"pipe": {"name": "PRESSURE PIPE", "damage": 52.0, "reach": 3.25, "cooldown": 0.65,
		"block": 0.55, "durability": 110.0, "color": Color("9aadb0")},
	"tray": {"name": "SPECIMEN TRAY", "damage": 24.0, "reach": 2.55, "cooldown": 0.34,
		"block": 0.92, "durability": 150.0, "color": Color("84c6c9")},
	"baton": {"name": "SECURITY BATON", "damage": 43.0, "reach": 2.9, "cooldown": 0.36,
		"block": 0.75, "durability": 120.0, "color": Color("dba85d")},
}

static func definition(id: String) -> Dictionary:
	return ITEMS.get(id, {})
