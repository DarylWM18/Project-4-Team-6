extends SceneTree
## Automated tests for Leaderboard, Level Ranking, and Return from Death integration.
## Run with: godot --headless --path . --script tests/leaderboard_ranking_test.gd

var failures: Array[String] = []
var game: Node

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	print("--- Running Leaderboard and Level Ranking Test Suite ---")
	test_rank_enumeration()
	test_rank_reward_values()
	test_rank_thresholds_all_rooms()
	await test_gameplay_integration()
	
	if failures.is_empty():
		print("PASS: all leaderboard, level ranking, reward values, and next-level non-stacking tests passed!")
	else:
		print("FAILED: %d checks failed" % failures.size())
		for f in failures:
			print("  - ", f)
	quit(0 if failures.is_empty() else 1)

func test_rank_enumeration() -> void:
	# Award one of 8 ranks: SSS, SS, S, A, B, C, D, F.
	check(TrialRules.RANKS.size() == 8, "exactly 8 ranks defined")
	var expected_ranks := ["SSS", "SS", "S", "A", "B", "C", "D", "F"]
	for i in expected_ranks.size():
		check(TrialRules.RANKS[i] == expected_ranks[i], "rank %d is %s" % [i, expected_ranks[i]])
		check(TrialRules.rank_name(i) == expected_ranks[i], "rank_name(%d) is %s" % [i, expected_ranks[i]])

func test_rank_reward_values() -> void:
	# Apply next-level Return from Death durations:
	# SSS = 7.5 seconds, SS = 7.0, S = 6.5, A = 6.0, B = 5.5, C/D/F = 5.0 seconds.
	check(TrialRules.BASE_REVIVAL_SECONDS == 5.0, "baseline revival duration is 5.0s")
	check(TrialRules.REVIVAL_SECONDS.size() == 8, "8 reward values mapped to 8 ranks")
	var expected_rewards := [7.5, 7.0, 6.5, 6.0, 5.5, 5.0, 5.0, 5.0]
	var rank_names := ["SSS", "SS", "S", "A", "B", "C", "D", "F"]
	for i in rank_names.size():
		var rank: String = rank_names[i]
		var expected: float = expected_rewards[i]
		check(is_equal_approx(TrialRules.REVIVAL_SECONDS[i], expected), "index %d reward is %.1fs" % [i, expected])
		check(is_equal_approx(TrialRules.reward_for_rank(rank), expected), "rank %s reward is %.1fs" % [rank, expected])
		check(is_equal_approx(TrialRules.reward_for_index(i), expected), "reward_for_index(%d) is %.1fs" % [i, expected])

func test_rank_thresholds_all_rooms() -> void:
	# Fixed rank thresholds appropriate for each level and preserving team agreements
	check(TrialRules.ROOM_TARGETS.size() == 3, "3 room targets defined")
	check(TrialRules.ROOM_TARGETS[0] == 60.0, "room 0 target is 60.0s")
	check(TrialRules.ROOM_TARGETS[1] == 80.0, "room 1 target is 80.0s")
	check(TrialRules.ROOM_TARGETS[2] == 90.0, "room 2 target is 90.0s")

	# Test each room with boundary conditions for all 8 ranks
	for room_idx in 3:
		var target: float = TrialRules.ROOM_TARGETS[room_idx]
		
		# SSS: <= 0.5 * T
		check(TrialRules.rank_index(0.0, target) == 0, "room %d: 0.0s is SSS" % room_idx)
		check(TrialRules.rank_index(target * 0.5, target) == 0, "room %d: exactly at SSS boundary is SSS" % room_idx)
		
		# SS: <= (2.0/3.0) * T
		check(TrialRules.rank_index(target * 0.5 + 0.01, target) == 1, "room %d: just over SSS boundary is SS" % room_idx)
		check(TrialRules.rank_index(target * (2.0 / 3.0), target) == 1, "room %d: exactly at SS boundary is SS" % room_idx)
		
		# S: <= (5.0/6.0) * T
		check(TrialRules.rank_index(target * (2.0 / 3.0) + 0.01, target) == 2, "room %d: just over SS boundary is S" % room_idx)
		check(TrialRules.rank_index(target * (5.0 / 6.0), target) == 2, "room %d: exactly at S boundary is S" % room_idx)
		
		# A: <= 1.0 * T
		check(TrialRules.rank_index(target * (5.0 / 6.0) + 0.01, target) == 3, "room %d: just over S boundary is A" % room_idx)
		check(TrialRules.rank_index(target * 1.0, target) == 3, "room %d: exactly at A boundary is A" % room_idx)
		
		# B: <= 1.25 * T
		check(TrialRules.rank_index(target * 1.0 + 0.01, target) == 4, "room %d: just over A boundary is B" % room_idx)
		check(TrialRules.rank_index(target * 1.25, target) == 4, "room %d: exactly at B boundary is B" % room_idx)
		
		# C: <= 1.5 * T
		check(TrialRules.rank_index(target * 1.25 + 0.01, target) == 5, "room %d: just over B boundary is C" % room_idx)
		check(TrialRules.rank_index(target * 1.5, target) == 5, "room %d: exactly at C boundary is C" % room_idx)
		
		# D: <= 2.0 * T
		check(TrialRules.rank_index(target * 1.5 + 0.01, target) == 6, "room %d: just over C boundary is D" % room_idx)
		check(TrialRules.rank_index(target * 2.0, target) == 6, "room %d: exactly at D boundary is D" % room_idx)
		
		# F: > 2.0 * T
		check(TrialRules.rank_index(target * 2.0 + 0.01, target) == 7, "room %d: just over D boundary is F" % room_idx)
		check(TrialRules.rank_index(target * 5.0, target) == 7, "room %d: slow run is F" % room_idx)
		check(TrialRules.RANKS[TrialRules.rank_index(target * 5.0, target)] == "F", "room %d: slow run rank label is F" % room_idx)

func test_gameplay_integration() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.records_path = "user://test_leaderboard_ranking.cfg"
	if FileAccess.file_exists(game.records_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.records_path))
	root.add_child(game)
	current_scene = game
	await process_frame
	
	# Baseline Return from Death before any levels cleared: 5.0s
	check(is_equal_approx(game.revival_allowance, 5.0), "starting revival allowance is base 5.0s")
	
	# Start run
	game.start_run()
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await physics_frame
	
	# Test initial level death duration: exactly 5.0 seconds
	game.begin_revival()
	check(is_equal_approx(game.revival_duration, 5.0), "initial revival duration is 5.0s")
	check(is_equal_approx(game.revival_time, 5.0), "initial revival time is 5.0s")
	game.reviving = false
	
	# Clear Room 0 with SSS (28.0s <= 30.0s threshold)
	game.room_time = 28.0
	for enemy in get_nodes_in_group("enemies"):
		if enemy.room_index == 0:
			enemy.dead = true
	game._clear_room()
	
	# Verify Room 0 results
	check(game.room_results.size() == 1, "room 0 result recorded")
	var r0: Dictionary = game.room_results[0]
	check(r0.room == 0, "result 0 room is 0")
	check(is_equal_approx(r0.seconds, 28.0), "result 0 completion time is 28.0s")
	check(r0.rank == "SSS", "result 0 rank is SSS")
	check(is_equal_approx(TrialRules.reward_for_rank(r0.rank), 7.5), "result 0 survival reward is 7.5s")
	check(is_equal_approx(game.revival_allowance, 7.5), "allowance updated to 7.5s for next room")
	check(is_equal_approx(game.best_times[0], 28.0), "room 0 personal best recorded as 28.0s")
	
	# Enter Room 1: next-level reward applied
	game._enter_room(1)
	check(is_equal_approx(game.revival_allowance, 7.5), "room 1 has 7.5s survival reward active")
	game.begin_revival()
	check(is_equal_approx(game.revival_duration, 7.5), "room 1 revival uses 7.5s duration from SSS rank")
	game.reviving = false
	
	# Clear Room 1 with B (95.0s: target 80.0s * 1.0 = 80s < 95s <= 100s = 80 * 1.25 -> rank B)
	game.room_time = 95.0
	for enemy in get_nodes_in_group("enemies"):
		if enemy.room_index == 1:
			enemy.dead = true
	game._clear_room()
	
	# Verify Room 1 results and non-stacking next-level reward
	check(game.room_results.size() == 2, "room 1 result recorded")
	var r1: Dictionary = game.room_results[1]
	check(r1.room == 1, "result 1 room is 1")
	check(is_equal_approx(r1.seconds, 95.0), "result 1 completion time is 95.0s")
	check(r1.rank == "B", "result 1 rank is B")
	check(is_equal_approx(TrialRules.reward_for_rank(r1.rank), 5.5), "result 1 survival reward is 5.5s")
	# Crucial: NOT 7.5 + 5.5 (13.0) and NOT 5.0 + 2.5 + 0.5 (8.0); exactly 5.5s!
	check(is_equal_approx(game.revival_allowance, 5.5), "room 1 B rank sets exactly 5.5s without stacking")
	
	# Enter Room 2: applies 5.5s
	game._enter_room(2)
	check(is_equal_approx(game.revival_allowance, 5.5), "room 2 has 5.5s survival reward active")
	game.begin_revival()
	check(is_equal_approx(game.revival_duration, 5.5), "room 2 revival uses 5.5s duration")
	game.reviving = false
	
	# Test next-level-only expiration: if a hypothetical room 3 is entered without room 2 clear,
	# allowance reverts to base 5.0s and does NOT retain 5.5s
	game._enter_room(3)
	check(is_equal_approx(game.revival_allowance, 5.0), "unearned level resets to base 5.0s (bonus applied only to immediate next level)")
	
	# Return to Room 2 and clear with F rank (200.0s > 180s = 90 * 2.0 -> rank F)
	game.room = 2
	game.room_cleared = false
	game.room_time = 200.0
	for enemy in get_nodes_in_group("enemies"):
		if enemy.room_index == 2:
			enemy.dead = true
	game._clear_room()
	check(game.room_results.size() == 3, "room 2 result recorded")
	var r2: Dictionary = game.room_results[2]
	check(r2.rank == "F", "slow room 2 earns F")
	check(is_equal_approx(TrialRules.reward_for_rank(r2.rank), 5.0), "rank F awards base 5.0s survival")
	
	# Complete run with victory override
	game.total_time = 150.0
	game.interact_story("exit")
	check(game.state == "victory", "victory reached")
	check(game.leaderboard.size() == 1, "run recorded on leaderboard")
	check(is_equal_approx(game.leaderboard[0].seconds, 150.0), "leaderboard stores escape total time")
	
	# Verify results screen display labels and HUD data
	check(game.hud.screen == "victory", "results screen displayed on victory")
	check(game.room_results.size() == 3, "all 3 level results present")
	for i in 3:
		var res: Dictionary = game.room_results[i]
		check(res.has("seconds"), "room %d result has completion time" % i)
		check(res.has("rank"), "room %d result has rank" % i)
		var rank_str: String = res.rank
		var expected_reward: float = TrialRules.reward_for_rank(rank_str)
		check(expected_reward > 0.0, "room %d rank %s maps to reward %.1fs" % [i, rank_str, expected_reward])
	
	# Verify leaderboard sorting and capacity (top 5)
	# Add faster and slower runs to test sorting
	game.state = "playing"
	game.total_time = 120.0
	game.finish(true)
	check(game.leaderboard.size() == 2, "second run recorded")
	check(game.leaderboard[0].seconds <= game.leaderboard[1].seconds, "leaderboard sorted ascending")
	
	for time in [90.0, 250.0, 80.0, 300.0]:
		game.state = "playing"
		game.total_time = time
		game.finish(true)
	
	check(game.leaderboard.size() == 5, "leaderboard preserves top 5 escapes")
	for i in range(1, game.leaderboard.size()):
		check(game.leaderboard[i - 1].seconds <= game.leaderboard[i].seconds, "leaderboard entry %d is <= entry %d" % [i - 1, i])
	check(is_equal_approx(game.leaderboard[0].seconds, 80.0), "fastest run (80.0s) is #1 on leaderboard")
	
	# Verify persistence round-trip
	game.leaderboard.clear()
	game.best_times = [0.0, 0.0, 0.0]
	game._load_records()
	check(game.leaderboard.size() == 5, "records reloaded from disk with 5 entries")
	check(is_equal_approx(game.leaderboard[0].seconds, 80.0), "reloaded #1 is 80.0s")
	check(is_equal_approx(game.best_times[0], 28.0), "reloaded room 0 personal best is 28.0s")
	
	# Cleanup
	paused = false
	if FileAccess.file_exists(game.records_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.records_path))
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
