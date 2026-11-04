extends SceneTree
## Real physics test: pursue around a workbench, telegraph, strike, block, recover.

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.records_path = "user://enemy_test_records.cfg"
	root.add_child(game)
	current_scene = game
	await process_frame
	game.start_run()
	game.player.set_physics_process(false)
	game.player.position = Vector3(0, 0.05, 6)
	game.player.equip("tray", 150)
	game.player.blocking = true
	var subject: Node = get_nodes_in_group("enemies")[0]
	for enemy in get_nodes_in_group("enemies"):
		enemy.active = enemy == subject
	subject.position = Vector3(0, 0.05, 0)
	var saw_windup := false
	var saw_lunge := false
	var saw_recovery := false
	var routed_around_bench := false
	for frame in 900:
		game.player.look_at(Vector3(subject.position.x, game.player.position.y, subject.position.z))
		await physics_frame
		if subject.position.z > 2.4 and subject.position.z < 4.6 and absf(subject.position.x) > 1.7:
			routed_around_bench = true
		saw_windup = saw_windup or subject.state == "windup"
		saw_lunge = saw_lunge or subject.state == "lunge"
		saw_recovery = saw_recovery or subject.state == "recover"
		if saw_recovery:
			break
	check(routed_around_bench, "AI navigates around the solid workbench")
	check(saw_windup and saw_lunge and saw_recovery, "AI completes windup, lunge and recovery states")
	check(game.player.health < 100 and game.player.health > 95, "a frontal tray block mitigates the real AI attack")
	check(game.player.integrity == 132, "the real AI attack consumes guard integrity once")
	check(game.state == "playing", "trial remains playable")
	# Real player physics and a timed input must reward an actual AI lunge.
	game.player.health = 0
	game.begin_revival()
	game.player.set_physics_process(true)
	game.player.block_was_held = false
	Input.action_release("block")
	var raised_guard := false
	var perfect_blocked := false
	var signal_before := 0.0
	for frame in 360:
		game.player.look_at(Vector3(subject.position.x, game.player.position.y, subject.position.z))
		if not raised_guard and game.revival_intro_time <= 0 and game.player.invulnerability <= 0 and subject.state == "windup" and subject.timer <= 0.12:
			Input.action_press("block")
			raised_guard = true
			signal_before = game.revival_time
		await physics_frame
		if game.hud.perfect_flash > 0:
			perfect_blocked = true
			break
	Input.action_release("block")
	check(perfect_blocked, "a timed guard input perfectly blocks the real AI lunge")
	check(game.revival_time > signal_before + 0.2, "the real perfect block increases remaining signal time")
	Input.action_press("attack")
	for frame in 240:
		game.player.look_at(Vector3(subject.position.x, game.player.position.y, subject.position.z))
		await physics_frame
		if not game.reviving:
			break
	Input.action_release("attack")
	check(subject.dead and not game.reviving and game.player.health == 55,
		"real melee input kills the subject and completes the recovery loop")
	check(game.player.stamina == 100 and game.player.invulnerability > 0,
		"physics-triggered recovery grants full stamina and protection")
	paused = false
	game.queue_free()
	await process_frame
	await process_frame
	# Allow the audio mixer to release its last playback references on shutdown.
	await create_timer(0.25).timeout
	if failures.is_empty():
		print("PASS: pursuit, obstacle routing, lunge, timed guard, melee and the complete revival loop")
	quit(0 if failures.is_empty() else 1)
