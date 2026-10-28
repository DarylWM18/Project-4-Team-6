class_name LabHUD
extends CanvasLayer
## Resolution-independent HUD and keyboard-accessible menu controls.

var game: Node
var canvas: Control
var buttons: Control
var screen := ""
var document_title := ""
var document_text := ""
var damage_flash := 0.0
var hit_flash := 0.0
var font: Font = ThemeDB.fallback_font
var pale := Color("dce8e5")
var muted := Color("8fa8ad")
var gold := Color("e7b46c")
var cyan := Color("8adce0")
var dark := Color("0c171eea")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.draw.connect(_draw_ui)
	buttons = Control.new()
	buttons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(buttons)

func _process(delta: float) -> void:
	damage_flash = maxf(0.0, damage_flash - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	canvas.queue_redraw()
	_layout_buttons()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if screen == "pause" or screen == "document":
			game.resume_run()
		elif screen.is_empty():
			game.pause_run()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("restart") and screen in ["dead", "victory"]:
		game.restart_run()

func show_screen(value: String) -> void:
	screen = value
	for child in buttons.get_children():
		buttons.remove_child(child)
		child.queue_free()
	match value:
		"menu":
			_button("BEGIN EXPERIMENT    →", Vector2(64, 470), game.start_run)
			_button("QUIT", Vector2(64, 535), _quit, true)
		"pause":
			_button("RESUME EXPERIMENT", Vector2(64, 385), game.resume_run)
			_button("AUDIO: ON" if game.audio.enabled else "AUDIO: OFF", Vector2(64, 450), _toggle_audio, true)
			_button("RESTART RUN", Vector2(64, 515), game.restart_run, true)
			_button("QUIT", Vector2(64, 580), _quit, true)
		"document":
			_button("CLOSE FILE    [ESC]", Vector2(130, 548), game.resume_run)
		"dead", "victory":
			_button("NEW EXPERIMENT    [R]", Vector2(64, 548), game.restart_run)
			_button("QUIT", Vector2(64, 613), _quit, true)
	if buttons.get_child_count() > 0:
		buttons.get_child(0).grab_focus()

func _button(title: String, pos: Vector2, callback: Callable, secondary: bool = false) -> void:
	var button := Button.new()
	button.text = title
	button.set_meta("design_position", pos)
	button.set_meta("design_size", Vector2(345, 49))
	button.add_theme_font_size_override("font_size", 17)
	for property in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(property, pale if secondary else Color("12242b"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("152932ef") if secondary else gold
	normal.border_color = Color("6a8b91")
	normal.set_border_width_all(1 if secondary else 0)
	normal.content_margin_left = 18
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("29434b") if secondary else Color("f4ce94")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(callback)
	buttons.add_child(button)
	_layout_buttons()

func _layout_buttons() -> void:
	var factor := get_viewport().get_visible_rect().size / Vector2(1280, 720)
	for button in buttons.get_children():
		button.position = button.get_meta("design_position") * factor
		button.size = button.get_meta("design_size") * factor
		button.add_theme_font_size_override("font_size", maxi(10, roundi(17 * factor.y)))

func _toggle_audio() -> void:
	game.audio.set_enabled(not game.audio.enabled)
	show_screen("pause")

func _quit() -> void:
	get_tree().quit()

func _draw_ui() -> void:
	var factor := get_viewport().get_visible_rect().size / Vector2(1280, 720)
	canvas.draw_set_transform(Vector2.ZERO, 0, factor)
	if screen.is_empty():
		_draw_gameplay()
	else:
		_draw_overlay()

func _label(pos: Vector2, words: String, size: int = 18, color: Color = Color("dce8e5")) -> void:
	canvas.draw_string(font, pos, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _line(y: float, start: float = 64, end: float = 590) -> void:
	canvas.draw_line(Vector2(start, y), Vector2(end, y), Color("45616a"), 1)

func _bar(pos: Vector2, width: float, ratio: float, color: Color, height: float = 5) -> void:
	canvas.draw_rect(Rect2(pos, Vector2(width, height)), Color("233a42"))
	canvas.draw_rect(Rect2(pos, Vector2(width * clampf(ratio, 0, 1), height)), color)

func _draw_gameplay() -> void:
	var player: Node = game.player
	canvas.draw_rect(Rect2(24, 24, 530, 86), dark)
	canvas.draw_rect(Rect2(24, 24, 3, 86), gold)
	_label(Vector2(43, 49), "AEGIS  /  " + TrialRules.ROOM_NAMES[game.room], 16, muted)
	_label(Vector2(43, 80), game.objective(), 17, pale)
	canvas.draw_rect(Rect2(1040, 24, 216, 104), dark)
	_label(Vector2(1058, 48), "TRIAL TIME", 13, muted)
	_label(Vector2(1058, 83), "%05.1f" % game.room_time, 30)
	var rank: int = TrialRules.rank_index(game.room_time, TrialRules.ROOM_TARGETS[game.room])
	_label(Vector2(1190, 83), TrialRules.RANKS[rank], 25, gold)
	_label(Vector2(1058, 111), "PERSONAL BEST  " + ("--" if game.best_times[game.room] <= 0 else "%.1fs" % game.best_times[game.room]), 12, muted)
	# Four short reticle strokes preserve a clear center for melee aiming.
	var reticle: Color = gold if is_instance_valid(player.interact_target) else pale
	for side in [-1, 1]:
		canvas.draw_line(Vector2(640 + side * 6, 360), Vector2(640 + side * 12, 360), reticle, 1.5)
		canvas.draw_line(Vector2(640, 360 + side * 6), Vector2(640, 360 + side * 12), reticle, 1.5)
	if hit_flash > 0:
		for x in [-1, 1]:
			for y in [-1, 1]:
				canvas.draw_line(Vector2(640 + x * 17, 360 + y * 17), Vector2(640 + x * 25, 360 + y * 25), gold, 2)
	if is_instance_valid(player.interact_target):
		canvas.draw_rect(Rect2(340, 415, 600, 38), dark)
		_label(Vector2(360, 440), player.interact_target.prompt(), 16, gold)
	if game.notification_time > 0:
		canvas.draw_rect(Rect2(240, 147, 800, 43), Color("0d1c24e8"))
		_label(Vector2(259, 174), game.message_text, 16, pale)
	# Bottom-left biometrics.
	canvas.draw_rect(Rect2(24, 577, 288, 119), dark)
	_label(Vector2(43, 604), "SUBJECT 06  /  VITAL SIGNAL", 13, muted)
	_label(Vector2(43, 650), "%03d" % ceili(player.health), 35, gold if game.reviving else pale)
	_label(Vector2(123, 649), "HP", 13, muted)
	_bar(Vector2(43, 668), 246, player.health / 100.0, gold if game.reviving else cyan, 6)
	_bar(Vector2(43, 683), 246, player.stamina / 100.0, muted, 3)
	# Flow stage is persistent, the active streak window is not.
	canvas.draw_rect(Rect2(448, 614, 384, 82), dark)
	_label(Vector2(468, 641), "FLOW %02d" % game.flow_stage, 18, cyan)
	_label(Vector2(657, 641), "SPEED +%d%%" % roundi((TrialRules.FLOW_SPEED[game.flow_stage] - 1) * 100), 14, muted)
	var flow_text := "MAXIMUM ADAPTATION"
	if game.flow_stage < 3:
		flow_text = "%d / %d KILLS" % [game.flow_kills, TrialRules.FLOW_KILLS[game.flow_stage]]
		flow_text += "   /   %.1fs" % game.flow_time if game.flow_time > 0 else "   /   FIRST KILL STARTS WINDOW"
	_label(Vector2(468, 670), flow_text, 12)
	# Current equipment and its block integrity.
	canvas.draw_rect(Rect2(902, 577, 354, 119), dark)
	_label(Vector2(923, 603), "FOUND EQUIPMENT", 13, muted)
	_label(Vector2(923, 633), "EMPTY HANDS" if player.item_id.is_empty() else Equipment.definition(player.item_id).name, 20, gold)
	_label(Vector2(923, 659), "[E] TAKE / SWAP   [Q] DROP   [F] LIGHT", 12, muted)
	if not player.item_id.is_empty():
		_bar(Vector2(923, 678), 310, player.integrity / float(Equipment.definition(player.item_id).durability), gold)
	_label(Vector2(448, 601), "WASD MOVE   SHIFT SPRINT   SPACE DOUBLE JUMP", 12, pale)
	if player.blocking:
		_label(Vector2(570, 478), "GUARD ACTIVE", 17, cyan)
	if game.reviving:
		canvas.draw_rect(Rect2(350, 215, 580, 95), Color("561c25ed"))
		_label(Vector2(373, 246), "RETURN FROM DEATH", 20, Color("ffc4ac"))
		_label(Vector2(373, 279), "%d / %d KILLS    /    SIGNAL LOSS IN %.1fs" % [game.revival_kills, game.revival_needed, game.revival_time], 20)
		_bar(Vector2(373, 293), 530, game.revival_time / game.revival_duration, gold, 4)
	if damage_flash > 0:
		var color := Color(0.7, 0.08, 0.05, damage_flash * 0.5)
		canvas.draw_rect(Rect2(0, 0, 1280, 12), color)
		canvas.draw_rect(Rect2(0, 708, 1280, 12), color)
		canvas.draw_rect(Rect2(0, 0, 12, 720), color)
		canvas.draw_rect(Rect2(1268, 0, 12, 720), color)

func _draw_overlay() -> void:
	canvas.draw_rect(Rect2(0, 0, 1280, 720), Color("07131a9c"))
	canvas.draw_rect(Rect2(0, 0, 655, 720), Color("0a171ff5"))
	canvas.draw_rect(Rect2(0, 0, 6, 720), gold)
	_label(Vector2(64, 66), "AEGIS / RESEARCH DIVISION", 15, gold)
	_label(Vector2(1014, 678), "E06 / BASEGAME PROTOTYPE", 13, muted)
	match screen:
		"menu":
			_label(Vector2(60, 166), "EXPERIMENT", 58)
			_label(Vector2(60, 260), "06", 100, gold)
			_label(Vector2(65, 310), "C O N T A I N M E N T", 23, muted)
			_line(342)
			_multiline(Vector2(64, 381), "Wake up. Scavenge. Keep moving.\nThe laboratory is ranking your escape.", 20, pale, 30)
			_label(Vector2(64, 638), "WASD / MOVE     MOUSE / LOOK     SPACE / DOUBLE JUMP", 12, muted)
			_label(Vector2(64, 663), "LMB / MELEE     RMB / BLOCK     E / SCAVENGE", 12, muted)
		"pause":
			_label(Vector2(64, 168), "SIGNAL HELD", 46)
			_label(Vector2(64, 211), "Experiment paused.  [ESC] to resume.", 18, muted)
			_line(243)
			_multiline(Vector2(64, 280), "SHIFT / sprint      SPACE / jump, then jump again\nLMB / melee      RMB / hold item in front to block\nE / take or swap      Q / drop      F / flashlight", 16, pale, 29)
		"document":
			canvas.draw_rect(Rect2(88, 170, 1104, 448), Color("10232bf9"))
			_label(Vector2(130, 220), "ARCHIVE / RECOVERED RECORD", 14, gold)
			_label(Vector2(130, 266), document_title, 29)
			_line(287, 130, 1140)
			_multiline(Vector2(130, 326), document_text, 21, pale, 29)
		"dead":
			_label(Vector2(64, 166), "EXPERIMENT", 53)
			_label(Vector2(64, 232), "FAILED.", 64, Color("ed9877"))
			_line(273)
			_multiline(Vector2(64, 316), "Neural signal lost.\nScavenge equipment, block the windup,\nand use speed to stay out of reach.", 20, pale, 32)
			_label(Vector2(64, 463), "TIME %.1fs    /    %d SUBJECTS ELIMINATED" % [game.total_time, game.kills], 16, gold)
		"victory":
			_label(Vector2(64, 157), "SIGNAL FREE", 53)
			_label(Vector2(64, 201), "You escaped the laboratory.", 24, gold)
			_line(232)
			_label(Vector2(64, 274), "TOTAL TIME  %.2fs" % game.total_time, 27)
			for i in game.room_results.size():
				var result: Dictionary = game.room_results[i]
				_label(Vector2(64, 316 + i * 34), "%s    /    %.1fs    /    %s" % [TrialRules.ROOM_NAMES[i], result.seconds, result.rank], 17, pale)
			_label(Vector2(64, 455), "%d SUBJECTS ELIMINATED  /  FLOW %02d" % [game.kills, game.flow_stage], 16, gold)
			_label(Vector2(64, 488), "Trial records saved on this device.", 16, muted)
			canvas.draw_rect(Rect2(746, 209, 460, 368), Color("0a1b23ec"))
			_label(Vector2(775, 249), "LOCAL LEADERBOARD / TOP 5 ESCAPES", 17, gold)
			_line(269, 775, 1177)
			for i in mini(5, game.leaderboard.size()):
				_label(Vector2(775, 311 + i * 51), "%02d    SUBJECT 06    /    %.2fs" % [i + 1, game.leaderboard[i].seconds], 19, pale)
	# Right-hand information card also leaves a view into the actual 3D lab.
	if screen in ["menu", "pause"]:
		canvas.draw_rect(Rect2(865, 323, 337, 271), Color("0a1b23e8"))
		_label(Vector2(889, 356), "PROTOCOL / ESCAPE", 14, gold)
		_line(375, 889, 1176)
		_multiline(Vector2(889, 403), "01  SCAVENGE\nEvery weapon is found in the lab.\n\n02  ADAPT\nChain kills to amplify movement.\n\n03  RETURN\nFatal damage starts a final trial.", 16, pale, 23)

func _multiline(pos: Vector2, words: String, size: int, color: Color, spacing: float) -> void:
	var lines := words.split("\n")
	for i in lines.size():
		_label(pos + Vector2(0, i * spacing), lines[i], size, color)
