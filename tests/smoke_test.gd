extends SceneTree
## Run with: godot --headless --path . --script tests/smoke_test.gd
## Isolates persistence in the test process; never overwrites a player's records.

var failures: Array[String] = []
var game: Node

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	# Ranking boundaries and revival escalation are gameplay contracts.
	check(TrialRules.rank_index(30, 60) == 0, "30s earns SSS on a 60s target")
	check(TrialRules.rank_index(40, 60) == 1, "40s earns SS")
	check(TrialRules.rank_index(50, 60) == 2, "50s earns S")
	check(TrialRules.rank_index(121, 60) == 7, "slow runs earn E")
	for i in 6:
		check(TrialRules.revival_requirement(i + 1) == [1, 2, 3, 5, 8, 13][i], "revival sequence %d" % i)
	game = load("res://scenes/main.tscn").instantiate()
	game.records_path = "user://smoke_trial_records.cfg"
	if FileAccess.file_exists(game.records_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.records_path))
	root.add_child(game)
	current_scene = game
	await process_frame
	check(game.player.item_id.is_empty(), "player spawns without equipment")
	check(get_nodes_in_group("enemies").size() == 25, "all Flow-compatible trial enemies are present")
	for room_index in TrialRules.ROOM_ENEMIES.size():
		var room_enemy_count := 0
		for enemy in get_nodes_in_group("enemies"):
			if enemy.room_index == room_index:
				room_enemy_count += 1
		check(room_enemy_count == TrialRules.ROOM_ENEMIES[room_index],
			"trial %d has its configured enemy count" % (room_index + 1))
	check(get_nodes_in_group("pickups").size() == 7, "all weapons are world pickups")
	check(paused, "menu holds the simulation")
	game.start_run()
	var active_enemy_count := 0
	for enemy in get_nodes_in_group("enemies"):
		if enemy.room_index == 0 and enemy.active:
			active_enemy_count += 1
		enemy.set_physics_process(false)
	check(active_enemy_count == game.MAX_ACTIVE_ENEMIES,
		"the enemy wave cap prevents the first trial from overwhelming the player")
	await physics_frame
	# Acquire the actual world item through the interaction ray.
	var wrench: Node3D = get_nodes_in_group("pickups")[0]
	game.player.camera.look_at(wrench.global_position)
	game.player._update_interaction()
	check(game.player.interact_target == wrench, "starting wrench is visible and within reach")
	if game.player.interact_target == wrench:
		game.player.interact_target.interact(game.player)
	await process_frame
	check(game.player.item_id == "wrench", "world pickup equips the wrench")
	# Exercise actual body movement, including a second airborne jump.
	game.player.pitch = 0
	game.player.position = Vector3(0, 0.1, 7)
	for i in 20:
		await physics_frame
	Input.action_press("move_right")
	for i in 20:
		await physics_frame
	Input.action_release("move_right")
	check(game.player.position.x > 1.5, "ground movement accelerates")
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	for i in 8:
		await physics_frame
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	check(game.player.jumps_used == 2 and game.player.velocity.y > 0, "second jump works in the air")
	# A real melee hit must connect in range, but never through geometry.
	var target: Node = null
	for enemy in get_nodes_in_group("enemies"):
		if enemy.room_index == 0 and enemy.active:
			target = enemy
			break
	check(target != null, "an active enemy is available for melee testing")
	game.player.position = Vector3(0, 0.1, -2)
	game.player.velocity = Vector3.ZERO
	target.position = Vector3(0, 0.1, -4)
	game.player.camera.rotation = Vector3.ZERO
	await physics_frame
	var before: float = target.health
	game.player._resolve_attack()
	check(target.health < before, "melee damages a visible enemy in reach")
	game.player.position = Vector3(-6.5, 0.1, 0.3)
	target.position = Vector3(-6.5, 0.1, -2.2)
	game.player.camera.position.y = 0.85
	await physics_frame
	before = target.health
	game.player._resolve_attack()
	check(target.health == before, "solid workbench occludes melee")
	game.player.camera.position.y = 1.62
	game.player.position = Vector3(0, 0.1, -2)
	target.position = Vector3(0, 0.1, -4)
	target.health = 150
	game.player.attack_cooldown = 0
	Input.action_press("attack")
	for i in 40:
		await physics_frame
	Input.action_release("attack")
	check(target.health <= 114 and target.health >= 78, "holding melee repeats within its cooldown")
	# Only a held item can block, and only against attacks in front.
	game.player.blocking = true
	game.player.invulnerability = 0
	game.player.health = 100
	game.player.integrity = 100
	game.player.receive_damage(20, game.player.position + Vector3.FORWARD)
	check(is_equal_approx(game.player.health, 93), "wrench blocks 65 percent of frontal damage")
	check(game.player.integrity == 82, "blocking consumes item integrity")
	game.player.invulnerability = 0
	game.player.receive_damage(20, game.player.position + Vector3.BACK)
	check(is_equal_approx(game.player.health, 73), "rear attacks bypass guard")
	game.player.invulnerability = 0
	game.player.integrity = 1
	game.player.receive_damage(20, game.player.position + Vector3.FORWARD)
	check(game.player.item_id.is_empty(), "depleted blocking equipment breaks")
	game.player.equip("pipe", 72)
	var pickup_count := get_nodes_in_group("pickups").size()
	game.player.drop_item()
	check(game.player.item_id.is_empty(), "dropping clears hands")
	check(get_nodes_in_group("pickups").size() == pickup_count + 1, "dropped equipment returns to the world")
	game.player.equip("wrench", 100)
	# Flow has five non-stacking movement and attack-speed stages.
	var flow_multipliers := [1.0, 1.1, 1.25, 1.45, 1.7, 2.0]
	game.flow_stage = 0
	game.flow_kills = 0
	game.flow_time = 0.0
	game._gain_flow(8)
	check(game.flow_stage == 2 and game.flow_kills == 1
		and is_equal_approx(game.flow_time, TrialRules.FLOW_WINDOWS[2]),
		"one oversized kill event carries excess progress through multiple stages")
	game.flow_stage = 0
	game.flow_kills = 0
	game.flow_time = 0.0
	for stage in TrialRules.FLOW_KILLS.size():
		var required: int = TrialRules.FLOW_KILLS[stage]
		for kill in required:
			game._gain_flow()
			if kill == 0:
				check(is_equal_approx(game.flow_time, TrialRules.FLOW_WINDOWS[stage]),
					"stage %d timer starts on its first kill" % (stage + 1))
		check(game.flow_stage == stage + 1 and game.flow_kills == 0 and game.flow_time == 0,
			"stage %d unlocks at its required kill count" % (stage + 1))
	check(game.flow_stage == 5, "all five Flow stages can be earned")
	game._process(20.0)
	check(game.flow_stage == 5, "stage 5 remains active without health damage")
	# Every stage multiplier applies to both normal movement and sprinting.
	for stage in flow_multipliers.size():
		game.flow_stage = stage
		check(is_equal_approx(game.player._movement_speed(false), LabPlayer.SPEED * flow_multipliers[stage]),
			"Flow stage %d applies its normal movement multiplier" % stage)
		check(is_equal_approx(game.player._movement_speed(true), LabPlayer.SPRINT_SPEED * flow_multipliers[stage]),
			"Flow stage %d applies its sprint multiplier" % stage)
	# The same replacement multiplier shortens cooldown, hit delay, and animation.
	for stage in flow_multipliers.size():
		game.flow_stage = stage
		game.player.attack_cooldown = 0.0
		game.player.attack_delay = -1.0
		game.player.begin_attack()
		var multiplier: float = flow_multipliers[stage]
		check(is_equal_approx(game.player.attack_cooldown, 0.42 / multiplier),
			"Flow stage %d applies its attack-speed multiplier" % stage)
		check(is_equal_approx(game.player.attack_delay, 0.1 / multiplier)
			and is_equal_approx(game.player.swing_duration, 0.28 / multiplier),
			"Flow stage %d keeps hit and animation timing synchronized" % stage)
	game.player.attack_cooldown = 0.0
	game.player.attack_delay = -1.0
	game.player.swing_time = 0.0
	# Expiration clears only progress toward the next stage.
	game.flow_stage = 2
	game.flow_kills = 0
	game.flow_time = 0.0
	game._gain_flow()
	game._process(TrialRules.FLOW_WINDOWS[2] + 0.1)
	check(game.flow_stage == 2 and game.flow_kills == 0 and game.flow_time == 0,
		"flow expiry keeps the earned stage and clears current progress")
	# Any real health loss resets all Flow, even when a guard reduces it.
	game.flow_stage = 5
	game.player.health = 100.0
	game.player.integrity = 100.0
	game.player.invulnerability = 0.0
	game.player.blocking = true
	game.player.receive_damage(20.0, game.player.position + Vector3.FORWARD)
	check(game.player.health < 100.0 and game.flow_stage == 0,
		"blocked health damage resets Flow to stage 0")
	game.flow_stage = 3
	game.player.health = 100.0
	game.player.invulnerability = 0.0
	game.player.blocking = false
	game.player.receive_damage(0.0, game.player.position + Vector3.BACK)
	check(game.player.health == 100.0 and game.flow_stage == 3,
		"an attack that causes no health damage preserves Flow")
	# Fatal damage enters the timed recovery mode; a kill restores health.
	game.player.invulnerability = 0
	game.player.health = 1
	game.player.blocking = false
	game.player.receive_damage(50, game.player.position + Vector3.BACK)
	check(game.reviving and game.revival_needed == 1 and game.flow_stage == 0,
		"fatal health damage resets Flow and begins first revival")
	game.flow_stage = 2
	game.player.invulnerability = 0.0
	var revival_health: float = game.player.health
	var signal_time: float = game.revival_time
	game.player.receive_damage(20.0, game.player.position + Vector3.BACK)
	check(game.player.health == revival_health and game.revival_time < signal_time and game.flow_stage == 2,
		"signal-time damage during revival does not count as health damage")
	var active_before_replacement := {}
	for enemy in get_nodes_in_group("enemies"):
		if enemy.room_index == 0 and enemy.active and not enemy.dead:
			active_before_replacement[enemy.get_instance_id()] = true
	target.dead = true
	game.enemy_defeated(target)
	check(not game.reviving and game.player.health == 55, "required revival kill restores life")
	active_enemy_count = 0
	for enemy in get_nodes_in_group("enemies"):
		if enemy.room_index == 0 and enemy.active and not enemy.dead:
			active_enemy_count += 1
	check(active_enemy_count == game.MAX_ACTIVE_ENEMIES,
		"a defeated enemy is immediately replaced from the waiting wave")
	var safe_replacement := false
	for enemy in get_nodes_in_group("enemies"):
		if (enemy.room_index == 0 and enemy.active and not enemy.dead
			and not active_before_replacement.has(enemy.get_instance_id())):
			safe_replacement = enemy.global_position.distance_to(game.player.global_position) >= 4.0
	check(safe_replacement, "newly activated enemies use a distant existing spawn position")
	game.begin_revival()
	check(game.revival_needed == 2, "second revival costs two kills")
	game.reviving = false
	# Room gates, required story file, ranking bonus, pause, and victory.
	game.room_time = 29
	for enemy in get_nodes_in_group("enemies"):
		if enemy.room_index == 0:
			enemy.dead = true
	game.flow_stage = 4
	game.flow_kills = 3
	game.flow_time = 4.0
	game._clear_room()
	check(game.lab.gate_open[0], "first trial releases first gate")
	check(game.revival_allowance == 16, "SSS grants 16 seconds next room")
	game._enter_room(1)
	check(game.flow_stage == 4 and game.flow_kills == 3 and game.flow_time > 0.0,
		"room completion and transition preserve Flow stage, progress, and timer")
	active_enemy_count = 0
	for enemy in get_nodes_in_group("enemies"):
		if enemy.room_index == 1 and enemy.active:
			active_enemy_count += 1
	check(active_enemy_count == game.MAX_ACTIVE_ENEMIES,
		"the next trial activates only one manageable enemy wave")
	for enemy in get_nodes_in_group("enemies"):
		if enemy.room_index == 1:
			enemy.dead = true
	game._clear_room()
	check(not game.lab.gate_open[1], "subject file gates the story reveal")
	game.interact_story("note")
	check(game.note_found and game.lab.gate_open[1], "reading the file releases containment")
	check(paused, "story reading freezes simulation")
	game.resume_run()
	game.pause_run()
	check(paused and game.hud.screen == "pause", "pause screen is functional")
	var paused_time: float = game.total_time
	for i in 10:
		await process_frame
	check(game.total_time == paused_time, "pausing freezes run timing")
	game.resume_run()
	game._enter_room(2)
	for enemy in get_nodes_in_group("enemies"):
		enemy.dead = true
	game._clear_room()
	game.interact_story("exit")
	check(game.state == "victory" and paused, "cleared transit and override complete the run")
	check(game.leaderboard.size() > 0, "completed run is recorded")
	# Persistence round trip and a separate revival timeout ending.
	game.leaderboard.clear()
	game._load_records()
	check(game.leaderboard.size() > 0, "leaderboard reloads from disk")
	game.state = "playing"
	game.reviving = true
	game.revival_time = 0.01
	game._process(0.1)
	check(game.state == "dead", "revival timeout ends the run")
	paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.records_path))
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	if failures.is_empty():
		print("PASS: gameplay smoke test (movement, pickups, melee, blocking, flow, revival, rooms, story, ranks, persistence, victory, death)")
	else:
		print("FAILED: %d checks" % failures.size())
	quit(0 if failures.is_empty() else 1)
