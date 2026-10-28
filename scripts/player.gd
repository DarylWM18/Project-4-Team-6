class_name LabPlayer
extends CharacterBody3D
## Fast grounded movement, air steering, double jump, and directional item blocking.

const SPEED := 9.0
const SPRINT_SPEED := 12.5
const JUMP_SPEED := 7.2
const GRAVITY := 22.0
const ACCELERATION := 48.0
const AIR_ACCELERATION := 17.0

var game: Node
var camera: Camera3D
var hand: Node3D
var held_model: Node3D
var flashlight: SpotLight3D
var item_id := ""
var integrity := 0.0
var health := 100.0
var stamina := 100.0
var blocking := false
var attack_cooldown := 0.0
var attack_delay := -1.0
var swing_time := 0.0
var invulnerability := 0.0
var jumps_used := 0
var pitch := 0.0
var bob_time := 0.0
var recoil := 0.0
var interact_target: Object
var jump_buffer := 0.0
var coyote_time := 0.0
var sensitivity := 0.0022

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2
	floor_snap_length = 0.3
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.33
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.fov = 91.0
	camera.near = 0.06
	add_child(camera)
	camera.current = true
	hand = Node3D.new()
	camera.add_child(hand)
	hand.position = Vector3(0.44, -0.52, -0.72)
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color("b5d7df")
	flashlight.light_energy = 2.8
	flashlight.spot_range = 24.0
	flashlight.spot_angle = 36.0
	flashlight.spot_attenuation = 0.75
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)
	flashlight.position = Vector3(0.2, -0.12, -0.1)
	_build_hand()

func _unhandled_input(event: InputEvent) -> void:
	if game.state != "playing":
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensitivity)
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.4, 1.4)
	if event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
	if event.is_action_pressed("drop"):
		drop_item()
	if event.is_action_pressed("interact") and is_instance_valid(interact_target):
		interact_target.interact(self)

func _physics_process(delta: float) -> void:
	if game.state != "playing":
		return
	attack_cooldown = maxf(0, attack_cooldown - delta)
	invulnerability = maxf(0, invulnerability - delta)
	stamina = minf(100.0, stamina + delta * (12.0 if blocking else 30.0))
	blocking = Input.is_action_pressed("block") and not item_id.is_empty() and stamina > 8.0 and attack_cooldown <= 0.1
	if Input.is_action_pressed("attack"):
		begin_attack()
	if attack_delay >= 0.0:
		attack_delay -= delta
		if attack_delay < 0.0:
			_resolve_attack()
	_update_movement(delta)
	_update_view(delta)
	_update_interaction()
	if global_position.y < -8.0:
		game.finish(false)

func _update_movement(delta: float) -> void:
	if is_on_floor():
		jumps_used = 0
		coyote_time = 0.1
	else:
		coyote_time = maxf(0, coyote_time - delta)
		velocity.y -= GRAVITY * delta
	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.12
	else:
		jump_buffer = maxf(0, jump_buffer - delta)
	if jump_buffer > 0.0 and (is_on_floor() or coyote_time > 0.0 or jumps_used < 2):
		if not is_on_floor() and coyote_time <= 0.0:
			jumps_used = maxi(1, jumps_used)
		velocity.y = JUMP_SPEED if jumps_used == 0 else JUMP_SPEED * 0.92
		jumps_used += 1
		jump_buffer = 0.0
		coyote_time = 0.0
		game.audio.tone(260.0 if jumps_used == 1 else 420.0, 0.08, 0.12)
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	var speed: float = SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	speed *= TrialRules.FLOW_SPEED[game.flow_stage]
	if blocking:
		speed *= 0.65
	var acceleration: float = ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	move_and_slide()

func _update_view(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	bob_time += delta * horizontal_speed * 1.25
	var bob := sin(bob_time) * 0.025 if is_on_floor() else 0.0
	camera.position.y = lerpf(camera.position.y, 1.62 + bob, delta * 15.0)
	recoil = move_toward(recoil, 0.0, delta * 4.0)
	camera.rotation.x = pitch + recoil * 0.025
	camera.rotation.z = lerpf(camera.rotation.z, -Input.get_axis("move_left", "move_right") * 0.018, delta * 8.0)
	var target_fov: float = 91.0 + clampf(horizontal_speed - SPEED, 0.0, 9.0) * 1.3
	camera.fov = lerpf(camera.fov, target_fov, delta * 5.0)
	swing_time = maxf(0.0, swing_time - delta)
	var swing := sin((1.0 - swing_time / 0.28) * PI) if swing_time > 0.0 else 0.0
	hand.position = hand.position.lerp(Vector3(0.05, -0.29, -0.54) if blocking else Vector3(0.44 - swing * 0.48, -0.52 + bob + swing * 0.12, -0.72 - swing * 0.2), delta * 20.0)
	hand.rotation = Vector3(-0.45, 0, -1.15) if blocking else Vector3(-0.2 + swing * 0.6, -swing * 0.8, 0.18 - swing * 1.6)

func begin_attack() -> void:
	if attack_cooldown > 0.0 or blocking:
		return
	if item_id.is_empty():
		game.notify("Find equipment. Everything you use comes from the lab.")
		return
	attack_cooldown = Equipment.definition(item_id).cooldown
	attack_delay = 0.1
	swing_time = 0.28
	game.audio.tone(110.0, 0.09, 0.16, true)

func _resolve_attack() -> void:
	if item_id.is_empty():
		return
	var data := Equipment.definition(item_id)
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var best: Node = null
	var best_distance := float(data.reach)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.dead or not enemy.active:
			continue
		var offset: Vector3 = enemy.global_position + Vector3.UP - origin
		var distance := offset.length()
		if distance > best_distance or forward.dot(offset.normalized()) < 0.72:
			continue
		var query := PhysicsRayQueryParameters3D.create(origin, enemy.global_position + Vector3.UP, 1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			best = enemy
			best_distance = distance
	if best != null:
		best.take_damage(float(data.damage) * (1.3 if game.reviving else 1.0), forward)
		game.hud.hit_flash = 0.18
		recoil = 0.5
		game.audio.tone(75.0, 0.13, 0.27, true)

func receive_damage(amount: float, source: Vector3) -> void:
	if invulnerability > 0.0 or game.state != "playing":
		return
	var direction := (source - global_position).normalized()
	var front := -global_basis.z
	var blocked := blocking and front.dot(direction) > 0.25
	if blocked:
		var data := Equipment.definition(item_id)
		amount *= 1.0 - float(data.block)
		integrity -= 18.0
		stamina = maxf(0, stamina - 28.0)
		recoil = 1.3
		game.audio.tone(480.0, 0.12, 0.22, true)
		game.notify("BLOCKED  /  keep the threat in front of you", 1.0)
		if integrity <= 0.0:
			item_id = ""
			blocking = false
			_build_hand()
			game.notify("Equipment broken. Scavenge a replacement.")
	else:
		game.flow_interrupted()
		game.audio.tone(62.0, 0.22, 0.3, true)
		game.hud.damage_flash = 0.65
	invulnerability = 0.35
	if game.reviving:
		game.revival_time = maxf(0.0, game.revival_time - (0.5 if blocked else 1.5))
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		game.begin_revival()

func equip(id: String, remaining: float) -> void:
	if not item_id.is_empty():
		drop_item()
	item_id = id
	integrity = remaining
	_build_hand()
	game.notify(Equipment.definition(id).name + " acquired.  LMB attack / RMB block")
	game.audio.tone(640.0, 0.12, 0.15)

func drop_item() -> void:
	if item_id.is_empty():
		return
	# Drop at the player's feet: never project an item through a wall.
	game.lab.spawn_pickup(item_id, global_position + Vector3(0, 0.38, 0), integrity)
	item_id = ""
	attack_delay = -1.0
	blocking = false
	_build_hand()

func _build_hand() -> void:
	for child in hand.get_children():
		child.queue_free()
	var sleeve := WorldArt.material(Color("23454b"))
	var glove := WorldArt.material(Color("a6b6b0"))
	WorldArt.box(hand, Vector3(0, -0.35, 0.18), Vector3(0.17, 0.4, 0.19), sleeve)
	WorldArt.box(hand, Vector3(0, -0.13, 0.06), Vector3(0.19, 0.2, 0.19), glove)
	if not item_id.is_empty():
		held_model = WorldArt.equipment_model(item_id)
		hand.add_child(held_model)

func _update_interaction() -> void:
	interact_target = null
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 3.4, 1 | 4)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_method("interact"):
		interact_target = hit.collider
