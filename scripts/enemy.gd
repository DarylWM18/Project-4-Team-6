class_name LabEnemy
extends CharacterBody3D
## Room-local pathfinding, readable windup, lunge, recovery, and knockback.

var game: Node
var room_index := 0
var active := false
var dead := false
var health := 85.0
var speed := 4.4
var damage := 23.0
var model: Node3D
var state := "chase"
var timer := 0.0
var repath := 0.0
var path := PackedVector3Array()
var push := Vector3.ZERO
var lunge_direction := Vector3.ZERO
var hit_this_lunge := false
var age := 0.0
var stagger := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | 8
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	model = WorldArt.mutant(self, room_index % 2)
	add_to_group("enemies")
	speed += room_index * 0.5
	health += room_index * 6.0

func _physics_process(delta: float) -> void:
	if dead or not active or game.state != "playing":
		return
	age += delta
	stagger = maxf(0.0, stagger - delta)
	var player: Node3D = game.player
	var offset: Vector3 = player.global_position - global_position
	offset.y = 0
	var distance := offset.length()
	if distance > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-offset.x, -offset.z), delta * 9.0)
	var direction := Vector3.ZERO
	timer -= delta
	match state:
		"chase":
			repath -= delta
			if repath <= 0.0:
				repath = 0.5 + float(get_instance_id() % 4) * 0.08
				path = game.lab.find_path(global_position, player.global_position)
			if path.size() > 0:
				if global_position.distance_to(path[0]) < 0.65:
					path.remove_at(0)
				if path.size() > 0:
					direction = global_position.direction_to(path[0])
			else:
				direction = offset.normalized()
			if distance < 2.65 and _can_see_player():
				state = "windup"
				timer = 0.6
				game.audio.tone(180.0, 0.12, 0.08, true)
		"windup":
			model.rotation.x = -0.28
			model.scale = Vector3(1.08, 0.92, 1.08)
			if timer <= 0.0:
				state = "lunge"
				timer = 0.24
				lunge_direction = offset.normalized()
				hit_this_lunge = false
		"lunge":
			direction = lunge_direction * 2.8
			if not hit_this_lunge and distance < 2.0 and absf(player.global_position.y - global_position.y) < 1.6 and _can_see_player():
				hit_this_lunge = true
				player.receive_damage(damage, global_position)
			if timer <= 0.0:
				state = "recover"
				timer = 0.8
		"recover":
			model.rotation.x = lerpf(model.rotation.x, 0, delta * 8)
			model.scale = model.scale.lerp(Vector3.ONE, delta * 8)
			if timer <= 0.0:
				state = "chase"
	if stagger > 0.0:
		direction = Vector3.ZERO
	velocity.x = direction.x * speed + push.x
	velocity.z = direction.z * speed + push.z
	push = push.move_toward(Vector3.ZERO, delta * 22)
	velocity.y -= 22.0 * delta
	move_and_slide()
	if state == "chase":
		model.position.y = sin(age * 11.0) * 0.035

func _can_see_player() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP,
		game.player.global_position + Vector3.UP, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func take_damage(amount: float, direction: Vector3) -> void:
	if dead:
		return
	health -= amount
	push = direction * 9.0
	stagger = 0.2
	if health <= 0.0:
		dead = true
		collision_layer = 0
		collision_mask = 0
		game.enemy_defeated(self)
		var tween := create_tween()
		tween.tween_property(model, "rotation:z", 1.5, 0.2)
		tween.parallel().tween_property(model, "position:y", -0.45, 0.25)
		tween.tween_interval(1.4)
		tween.tween_property(model, "scale", Vector3.ONE * 0.01, 0.4)
		tween.tween_callback(queue_free)
