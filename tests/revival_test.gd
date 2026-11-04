extends SceneTree
## Deterministic revival rules plus real guard input, world queries and knockback.

var failures: Array[String] = []
var game: Node

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func close_to(actual: float, expected: float, message: String) -> void:
	check(is_equal_approx(actual, expected), "%s (got %.3f, expected %.3f)" % [message, actual, expected])

func _new_run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.records_path = "user://revival_test_records.cfg"
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await process_frame
	game.start_run()

func _dispose_run() -> void:
	paused = false
	if FileAccess.file_exists(game.records_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.records_path))
	game.queue_free()
	await process_frame
	await process_frame

func _fresh_guard() -> void:
	Input.action_release("block")
	game.player._update_guard(0.01)
	Input.action_press("block")
	game.player.stamina = 100
	game.player.attack_cooldown = 0
	game.player._update_guard(0.01)
	game.player.invulnerability = 0

func _run() -> void:
	for rank in 8:
		check(TrialRules.revival_seconds(rank) >= 10 and TrialRules.revival_seconds(rank) <= 13,
			"all rank allowances remain within 10-13 seconds")
	close_to(TrialRules.revival_seconds(0), 13, "SSS gives the maximum bonus")
	close_to(TrialRules.revival_seconds(7), 10, "E retains the full baseline")
	await _new_run()
	var subjects := get_nodes_in_group("enemies")
	var player: Node = game.player
	# Six activations ordinarily cost 13 kills; only the three current-room subjects count.
	game.revival_uses = 5
	player.health = 1
	player.receive_damage(50, player.position + Vector3.BACK)
	check(game.reviving and game.revival_needed == 3, "quota is capped to available current-room enemies")
	close_to(game.revival_time, 10, "initial recovery starts at the baseline")
	check(player.item_id.is_empty() and get_nodes_in_group("pickups").size() == 7,
		"revival never creates or grants equipment")
	var first_guide: LabPickup = game.revival_pickup
	check(is_instance_valid(first_guide) and first_guide.revival_marker.visible,
		"unarmed revival highlights an actual world pickup")
	check(game.lab.room_for_position(first_guide.global_position) == 0,
		"weapon guide excludes equipment behind later trial locks")
	check(game.lab.environment.ambient_light_color == Color("91b7ef"), "revival changes lab lighting")
	var player_pos: Vector3 = player.position
	var enemy_pos: Vector3 = subjects[0].position
	player.velocity = Vector3.RIGHT * 8
	player._physics_process(0.1)
	subjects[0]._physics_process(0.1)
	game._process(0.1)
	check(player.position == player_pos and subjects[0].position == enemy_pos,
		"impact beat holds player and enemy physics")
	close_to(game.revival_time, 10, "impact beat holds the countdown")
	close_to(game.total_time, 0, "impact beat holds the trial clocks")
	game.pause_run()
	var intro_before: float = game.revival_intro_time
	game.set_process(true)
	for i in 10:
		await process_frame
	close_to(game.revival_intro_time, intro_before, "menu pause preserves the pending impact beat")
	game.set_process(false)
	game.resume_run()
	game._process(game.revival_intro_time)
	check(game.revival_intro_time == 0 and game.reviving, "countdown becomes active after the impact beat")
	# Move near the other room-zero tool and verify selection is refreshed, then cleared on pickup.
	player.position = Vector3(-6.5, 0.1, -0.8)
	game.refresh_revival_pickup()
	var nearest: LabPickup = game.revival_pickup
	check(nearest != first_guide and not first_guide.revival_marker.visible,
		"only the nearest usable pickup is highlighted as the player moves")
	nearest.interact(player)
	check(player.item_id == "tray" and game.revival_pickup == null and not nearest.revival_marker.visible,
		"taking highlighted equipment clears its guide")
	player.invulnerability = 0
	player.blocking = true
	player.integrity = 1
	player.receive_damage(20, player.position + Vector3.FORWARD)
	check(player.item_id.is_empty() and is_instance_valid(game.revival_pickup),
		"a broken guard immediately restores the scavenging guide")
	player.equip("wrench", 100)
	player.position = Vector3(0, 0.1, -3)
	player.rotation = Vector3.ZERO
	# A fresh, directional press earns one reward. Holding and expired timing do not.
	game.revival_time = 5
	_fresh_guard()
	player.receive_damage(20, player.position + Vector3.FORWARD)
	close_to(game.revival_time, 5.5, "perfect block restores half a second")
	check(not player.perfect_block_available, "one guard press rewards at most one incoming hit")
	player.invulnerability = 0
	player._update_guard(0.01)
	player.receive_damage(20, player.position + Vector3.FORWARD)
	close_to(game.revival_time, 5.5, "ordinary held guard has no extra time penalty or reward")
	_fresh_guard()
	player._update_guard(TrialRules.PERFECT_BLOCK_WINDOW + 0.01)
	player.receive_damage(20, player.position + Vector3.FORWARD)
	close_to(game.revival_time, 5.5, "late block cannot earn the timing reward")
	_fresh_guard()
	player.receive_damage(20, player.position + Vector3.BACK)
	close_to(game.revival_time, 4.0, "rear attacks bypass timed guard and cost signal time")
	_fresh_guard()
	game.revival_time = 9.9
	player.receive_damage(20, player.position + Vector3.FORWARD)
	close_to(game.revival_time, 10, "perfect-block reward is capped at the starting window")
	Input.action_release("block")
	player._update_guard(0.01)
	game.revival_time = 5
	subjects[0].take_damage(999, Vector3.FORWARD)
	close_to(game.revival_time, 6.5, "non-final kill restores one and a half seconds")
	check(game.revival_kills == 1 and game.reviving, "partial kills keep the recovery trial active")
	game._process(2)
	close_to(game.revival_time, 4.5, "countdown continues between rewards")
	game.revival_time = 9.6
	subjects[1].take_damage(999, Vector3.FORWARD)
	close_to(game.revival_time, 10, "kill reward cannot exceed the starting window")
	player.stamina = 2
	var integrity_before: float = player.integrity
	subjects[2].take_damage(999, Vector3.FORWARD)
	check(not game.reviving and player.health == 55 and player.stamina == 100,
		"completing the capped quota restores health and all guard stamina")
	close_to(player.integrity, integrity_before, "recovery preserves scavenged equipment condition")
	close_to(player.invulnerability, TrialRules.REVIVAL_PROTECTION, "recovery retains protection")
	check(game.lab.environment.ambient_light_color == Color("8aabb9") and game.revival_pickup == null,
		"recovery restores normal lighting and removes scavenging markers")
	check(game.room_cleared and game.lab.gate_open[0], "last-enemy recovery releases the room normally")
	await _dispose_run()
	# A live lunge is interrupted and pushed away; geometry shields another nearby subject.
	await _new_run()
	player = game.player
	subjects = get_nodes_in_group("enemies")
	player.equip("wrench", 81)
	player.position = Vector3(-6.5, 0.1, 1.2)
	subjects[0].position = Vector3(-4, 0.1, 1.2)
	subjects[1].position = Vector3(-7.8, 0.1, 1.2)
	subjects[2].position = Vector3(-6.5, 0.1, -2.2)
	for i in [1, 2]:
		subjects[i].state = "lunge"
		subjects[i].timer = 0.2
		subjects[i].hit_this_lunge = false
	await physics_frame
	await physics_frame
	player.health = 1
	player.receive_damage(50, player.position + Vector3.BACK)
	game._process(game.revival_intro_time)
	subjects[0].take_damage(999, Vector3.FORWARD)
	check(subjects[1].state == "recover" and subjects[1].stagger > 0 and subjects[1].push.length() > 0,
		"recovery pulse interrupts an exposed nearby lunge and applies knockback")
	check(subjects[2].state == "lunge" and subjects[2].stagger == 0,
		"solid furniture blocks the recovery pulse")
	check(subjects[1].health == 85, "recovery pulse deals no damage")
	check(game.lab.get_node_or_null("RecoveryPulse") != null, "recovery creates the visible expanding pulse")
	var distance_before: float = player.position.distance_to(subjects[1].position)
	subjects[1].set_physics_process(true)
	await physics_frame
	await physics_frame
	subjects[1].set_physics_process(false)
	check(player.position.distance_to(subjects[1].position) > distance_before,
		"pulse knockback moves the enemy through real collision physics")
	player.receive_damage(999, subjects[1].position)
	close_to(player.health, 55, "post-recovery protection prevents immediate death")
	# A cleared-room fatal hit cannot create an impossible zero-target countdown.
	for enemy in subjects:
		if enemy.room_index == 0:
			enemy.dead = true
	player.invulnerability = 0
	player.health = 1
	player.receive_damage(50, player.position + Vector3.BACK)
	check(game.revival_needed == 0 and game.reviving, "empty encounter uses an automatic signal reboot")
	game._process(game.revival_intro_time)
	check(not game.reviving and player.health == 55, "zero-target reboot finishes after the impact beat")
	# Failure still ends the run cleanly with no global slow-motion state to reset.
	subjects[1].dead = false
	player.invulnerability = 0
	player.health = 1
	player.receive_damage(50, player.position + Vector3.BACK)
	game._process(game.revival_intro_time)
	game.revival_time = 0.01
	game._process(0.1)
	check(game.state == "dead" and paused, "signal timeout still produces the death screen")
	check(game.revival_pickup == null and Engine.time_scale == 1.0,
		"death clears the guide and leaves the engine clock unchanged")
	await _dispose_run()
	await create_timer(0.25).timeout
	if failures.is_empty():
		print("PASS: revival quotas, scavenging guides, impact pause, perfect guards, capped rewards, rank timing, recovery pulse and failure")
	else:
		print("FAILED: %d revival checks" % failures.size())
	quit(0 if failures.is_empty() else 1)
