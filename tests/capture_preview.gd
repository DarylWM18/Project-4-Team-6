extends SceneTree
## Render the real scene. Usage: godot --path . --script tests/capture_preview.gd

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var output := "res://tmp/previews"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("preview-menu.png"))
	game.start_run()
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	game.player.equip("wrench", 100)
	game.player.position = Vector3(3.5, 0.1, 7.0)
	game.player.rotation.y = 0.22
	game.player.pitch = -0.03
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("preview-gameplay.png"))
	game.player.position = Vector3(1, 0.1, -15.8)
	game.player.rotation.y = -0.24
	game.player.pitch = -0.02
	game.room = 1
	game.message_text = "Warning. Subjects have escaped containment."
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("preview-containment.png"))
	# Measure the running room after shader warmup, not the startup average.
	for i in 30:
		await RenderingServer.frame_post_draw
	var started := Time.get_ticks_msec()
	for i in 120:
		await RenderingServer.frame_post_draw
	var elapsed := Time.get_ticks_msec() - started
	print("STEADY_RENDER: %.1f FPS / %.0f draw calls" % [120000.0 / maxf(1, elapsed), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	game.interact_story("note")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("preview-archive.png"))
	game.resume_run()
	game.player.health = 0
	game.begin_revival()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("preview-revival.png"))
	game.reviving = false
	var sample_results: Array[Dictionary] = [
		{"room": 0, "seconds": 29.0, "rank": "SSS"},
		{"room": 1, "seconds": 49.5, "rank": "SS"},
		{"room": 2, "seconds": 68.1, "rank": "S"}]
	game.room_results = sample_results
	game.leaderboard = []
	for i in 5:
		game.leaderboard.append({"seconds": 150.0 + i * 10, "ranks": []})
	game.hud.show_screen("victory")
	paused = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("preview-results.png"))
	print("RENDER_STATS: ", Engine.get_frames_per_second(), " FPS / ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " draw calls")
	print("PREVIEW_DIRECTORY: ", ProjectSettings.globalize_path(output))
	paused = false
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	quit()
