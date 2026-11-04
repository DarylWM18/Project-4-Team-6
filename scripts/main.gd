extends Node3D
## Owns a single run. UI pauses the tree; story reading never consumes trial time.

var state := "menu"
var player: LabPlayer
var lab: LabLevel
var hud: LabHUD
var audio: LabAudio
var room := 0
var room_time := 0.0
var total_time := 0.0
var room_cleared := false
var room_results: Array[Dictionary] = []
var flow_stage := 0
var flow_kills := 0
var flow_time := 0.0
var reviving := false
var revival_uses := 0
var revival_kills := 0
var revival_needed := 1
var revival_time := 0.0
var revival_allowance := TrialRules.REVIVAL_BASE_SECONDS
var revival_duration := TrialRules.REVIVAL_BASE_SECONDS
var revival_intro_time := 0.0
var revival_heartbeat_time := 0.0
var revival_pickup: LabPickup
var note_found := false
var recording_found := false
var kills := 0
var message_text := ""
var notification_time := 0.0
var leaderboard: Array = []
var best_times := [0.0, 0.0, 0.0]
var records_path := "user://trial_records.cfg"

func _enter_tree() -> void:
	_install_inputs()

func _ready() -> void:
	_load_records()
	audio = LabAudio.new()
	add_child(audio)
	lab = LabLevel.new()
	lab.game = self
	add_child(lab)
	player = LabPlayer.new()
	player.game = self
	add_child(player)
	player.position = Vector3(0, 0.1, 6.8)
	player.pitch = -0.12
	player.camera.rotation.x = player.pitch
	hud = LabHUD.new()
	hud.game = self
	add_child(hud)
	hud.show_screen("menu")
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if state != "playing":
		return
	if revival_intro_time > 0.0:
		# Hold combat and gameplay clocks for the impact beat. Menus still use
		# SceneTree pause, so resuming a file cannot skip this transition.
		var intro_step := minf(delta, revival_intro_time)
		revival_intro_time = maxf(0.0, revival_intro_time - intro_step)
		delta -= intro_step
		if revival_intro_time <= 0.0 and revival_needed == 0:
			_complete_revival()
		if delta <= 0.0:
			return
	total_time += delta
	if not room_cleared:
		room_time += delta
	notification_time = maxf(0.0, notification_time - delta)
	if flow_time > 0.0:
		flow_time = maxf(0.0, flow_time - delta)
		if flow_time <= 0.0:
			flow_kills = 0
			notify("Flow window expired. Unlocked stages retained.", 2.0)
	if reviving:
		revival_time -= delta
		if revival_time <= 0.0:
			finish(false)
			return
		revival_heartbeat_time -= delta
		if revival_heartbeat_time <= 0.0:
			audio.heartbeat()
			hud.neural_beat = 1.0
			revival_heartbeat_time = lerpf(0.4, 0.9, clampf(revival_time / revival_duration, 0, 1))
	refresh_revival_pickup()
	if room == 0 and room_cleared and player.position.z < -14.4:
		_enter_room(1)
	elif room == 1 and room_cleared and player.position.z < -40.4:
		_enter_room(2)

func start_run() -> void:
	state = "playing"
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_screen("")
	_activate_room()
	notify("Experiment 06. Containment failed. Find equipment on the workbench.", 6.0)

func pause_run() -> void:
	if state != "playing":
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_screen("pause")

func resume_run() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_screen("")

func restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _enter_room(index: int) -> void:
	room = index
	room_cleared = false
	room_time = 0.0
	if not reviving:
		player.health = maxf(player.health, 65.0)
	flow_kills = 0
	flow_time = 0.0
	_activate_room()
	if index == 1:
		notify("Warning. Subjects have escaped containment. Read your subject file.", 6.0)
	else:
		notify("The exit is ahead. Clear the transit lock and reach the override.", 5.0)

func _activate_room() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.active = enemy.room_index == room and not enemy.dead

func remaining_enemies() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.room_index == room and not enemy.dead:
			count += 1
	return count

func enemy_defeated(enemy: Node) -> void:
	kills += 1
	_gain_flow()
	if reviving and enemy.room_index == room:
		revival_kills += 1
		add_revival_time(TrialRules.REVIVAL_KILL_BONUS, "ELIMINATION")
		if revival_kills >= revival_needed:
			_complete_revival()
	if remaining_enemies() == 0:
		_clear_room()

func _gain_flow() -> void:
	if flow_stage >= TrialRules.FLOW_KILLS.size():
		return
	if flow_kills == 0:
		flow_time = TrialRules.FLOW_WINDOWS[flow_stage]
	flow_kills += 1
	if flow_kills >= TrialRules.FLOW_KILLS[flow_stage]:
		flow_stage += 1
		flow_kills = 0
		flow_time = 0.0
		notify("FLOW %02d / movement amplified +%d%%" % [flow_stage, roundi((TrialRules.FLOW_SPEED[flow_stage] - 1) * 100)], 3.0)
		audio.tone(420.0 + flow_stage * 180, 0.22, 0.2)

func flow_interrupted() -> void:
	# A hit breaks the current chain; earned stages survive damage and timeouts.
	flow_kills = 0
	flow_time = 0.0

func begin_revival() -> void:
	if reviving:
		return
	revival_uses += 1
	# Only living subjects in the current trial can be demanded. A cleared
	# room automatically restores the signal after the impact beat.
	revival_needed = mini(TrialRules.revival_requirement(revival_uses), remaining_enemies())
	revival_kills = 0
	revival_time = revival_allowance
	revival_duration = revival_allowance
	reviving = true
	revival_intro_time = TrialRules.REVIVAL_INTRO_SECONDS
	revival_heartbeat_time = 0.0
	player.attack_delay = -1.0
	player.blocking = false
	player.perfect_block_available = false
	player.invulnerability = 1.0
	lab.set_neural_lighting(true)
	player.flashlight.light_color = Color("a8c8ff")
	hud.neural_beat = 1.0
	refresh_revival_pickup()
	notify("RETURN FROM DEATH / eliminate %d subject(s) before signal loss" % revival_needed, 4.0)
	audio.tone(95.0, 0.6, 0.3, true)

func next_revival_requirement() -> int:
	return mini(TrialRules.revival_requirement(revival_uses + 1), remaining_enemies())

func add_revival_time(seconds: float, reason: String) -> float:
	if not reviving or revival_intro_time > 0.0 or revival_time <= 0.0:
		return 0.0
	var gained := minf(seconds, maxf(0.0, revival_duration - revival_time))
	revival_time += gained
	if gained > 0.0:
		hud.show_revival_reward("%s  +%.1fs" % [reason, gained])
	return gained

func refresh_revival_pickup() -> void:
	var nearest: LabPickup = null
	var distance := INF
	if reviving and player.item_id.is_empty():
		for item in get_tree().get_nodes_in_group("pickups"):
			if item.is_queued_for_deletion() or item.durability <= 0.0 or lab.room_for_position(item.global_position) != room:
				continue
			var candidate: float = player.global_position.distance_squared_to(item.global_position)
			if candidate < distance:
				nearest = item
				distance = candidate
	if is_instance_valid(revival_pickup) and revival_pickup != nearest:
		revival_pickup.set_revival_highlight(false)
	revival_pickup = nearest
	if is_instance_valid(revival_pickup):
		revival_pickup.set_revival_highlight(true)

func _complete_revival() -> void:
	if not reviving:
		return
	reviving = false
	revival_intro_time = 0.0
	player.health = TrialRules.REVIVAL_HEALTH
	player.stamina = 100.0
	player.invulnerability = TrialRules.REVIVAL_PROTECTION
	lab.set_neural_lighting(false)
	player.flashlight.light_color = Color("b5d7df")
	refresh_revival_pickup()
	hud.recovery_flash = 0.6
	hud.neural_beat = 0.0
	hud.show_revival_reward("SIGNAL RESTORED / STAMINA REFILLED")
	# Interrupt nearby lunges without damaging subjects or reaching through walls.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.dead or not enemy.active or enemy.room_index != room:
			continue
		if player.global_position.distance_to(enemy.global_position) > TrialRules.REVIVAL_PULSE_RADIUS:
			continue
		var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP,
			enemy.global_position + Vector3.UP, 1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			enemy.apply_neural_pulse(player.global_position)
	lab.show_recovery_pulse(player.global_position, TrialRules.REVIVAL_PULSE_RADIUS)
	notify("RETURN COMPLETE / neural signal restored", 3.0)
	audio.tone(720.0, 0.28, 0.2)

func _clear_room() -> void:
	if room_cleared:
		return
	room_cleared = true
	var rank := TrialRules.rank_index(room_time, TrialRules.ROOM_TARGETS[room])
	revival_allowance = TrialRules.revival_seconds(rank)
	room_results.append({"room": room, "seconds": room_time, "rank": TrialRules.RANKS[rank]})
	if best_times[room] <= 0.0 or room_time < best_times[room]:
		best_times[room] = room_time
	_save_records()
	if room == 0 or (room == 1 and note_found):
		lab.open_gate(room)
	var next_action := "Proceed to the next trial."
	if room == 1 and not note_found:
		next_action = "Read Subject 06's file to release the lock."
	elif room == 2:
		next_action = "Reach the surface override."
	notify("TRIAL CLEAR / %s / %.1fs / %s" % [TrialRules.RANKS[rank], room_time, next_action], 7.0)
	audio.tone(840, 0.3, 0.18)

func interact_story(kind: String) -> void:
	match kind:
		"note":
			note_found = true
			if room == 1 and room_cleared:
				lab.open_gate(1)
			hud.document_title = "SUBJECT 06 / NEURAL ADAPTATION"
			hud.document_text = "You are one of us. The experiment changed you.\n\nRapid locomotion. Cumulative neural acceleration.\nPost-mortem combat restoration.\n\nYou were never a member of staff.\nYou were the next trial."
		"recording":
			recording_found = true
			hud.document_title = "SCIENTIST RECORDING / 02:41 AM"
			hud.document_text = "We lost control. The subjects are getting stronger.\n\n[Emergency recording recovered from the workbench.]\n\nThe broken chambers in Containment were opened\nfrom the inside."
			audio.tone(330, 0.2, 0.18, true)
		"exit":
			if room != 2 or not room_cleared:
				notify("SURFACE LOCKED / clear all subjects in the transit trial")
				return
			if reviving:
				notify("OVERRIDE REJECTED / restore your neural signal first")
				return
			finish(true)
			return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_screen("document")

func objective() -> String:
	if player.item_id.is_empty():
		return "FIND EQUIPMENT / look for illuminated items"
	if not room_cleared:
		return "CLEAR THE TRIAL / %02d subjects remaining" % remaining_enemies()
	if room == 1 and not note_found:
		return "READ SUBJECT 06'S FILE / archive terminal"
	if room == 2:
		return "REACH THE SURFACE / use the override terminal"
	return "LOCK RELEASED / follow the floor guide"

func finish(escaped: bool) -> void:
	if state != "playing":
		return
	state = "victory" if escaped else "dead"
	revival_intro_time = 0.0
	if is_instance_valid(revival_pickup):
		revival_pickup.set_revival_highlight(false)
	revival_pickup = null
	if escaped:
		leaderboard.append({"seconds": total_time, "ranks": room_results.duplicate(true)})
		leaderboard.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.seconds < b.seconds)
		leaderboard = leaderboard.slice(0, 5)
		_save_records()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_screen(state)

func notify(message: String, seconds: float = 3.0) -> void:
	message_text = message
	notification_time = seconds

func _load_records() -> void:
	var config := ConfigFile.new()
	if config.load(records_path) == OK:
		var saved_times: Variant = config.get_value("records", "room_best", [0.0, 0.0, 0.0])
		if saved_times is Array and saved_times.size() == 3:
			for i in 3:
				if saved_times[i] is float or saved_times[i] is int:
					best_times[i] = maxf(0.0, saved_times[i])
		var saved_runs: Variant = config.get_value("records", "runs", [])
		if saved_runs is Array:
			for entry in saved_runs:
				if entry is Dictionary and entry.get("seconds") is float and entry.get("ranks") is Array:
					leaderboard.append(entry)

func _save_records() -> void:
	var config := ConfigFile.new()
	config.set_value("records", "room_best", best_times)
	config.set_value("records", "runs", leaderboard)
	var error := config.save(records_path)
	if error != OK:
		push_warning("Could not save local trial records: %s" % error_string(error))

func _install_inputs() -> void:
	var keys := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A,
		"move_right": KEY_D, "jump": KEY_SPACE, "sprint": KEY_SHIFT, "interact": KEY_E,
		"drop": KEY_Q, "flashlight": KEY_F, "pause": KEY_ESCAPE, "restart": KEY_R}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
	for action in ["attack", "block"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT if action == "attack" else MOUSE_BUTTON_RIGHT
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
