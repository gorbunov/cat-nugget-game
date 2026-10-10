extends SceneTree
## Render actual game screens to build/previews for visual inspection.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://main.tscn") as PackedScene
	var game = scene.instantiate()
	game.test_mode = true
	root.add_child(game)
	game.clock = 1.0
	DirAccess.make_dir_recursive_absolute("res://build/previews")
	if "--layouts" in OS.get_cmdline_user_args():
		await _preview_layouts(game)
		quit()
		return
	if "--disgust" in OS.get_cmdline_user_args():
		game._start_round()
		game.cat = Vector2(320, 200)
		game.cat_previous = game.cat
		game.banner_time = 0
		game.expression = 0
		game.cat_velocity = Vector2.ZERO
		game._select_cat(0)
		for frame in range(8):
			game.disgust = game.BURNT_COOLDOWN - (frame + 0.25) / 8.0
			await _capture(game, "disgust_%02d" % frame)
		quit()
		return
	await _capture(game, "title")
	if "--title-snacks" in OS.get_cmdline_user_args():
		game.title_snack_wait = 0
		game._update_title_snack(0)
		game._update_title_snack(0.12)
		await _capture(game, "title_snack_spawn")
		game._update_title_snack(0.58)
		await _capture(game, "title_snack_chomp")
		game._update_title_snack(0.3)
		await _capture(game, "title_snack_eaten")
	if "--check-title-fullscreen" in OS.get_cmdline_user_args():
		await _check_title_fullscreen(game)
	if "--sources" in OS.get_cmdline_user_args():
		game._handle_action("sources")
		assert(game.state == game.Screen.SOURCES)
		await _capture(game, "sources")
		game._handle_action("back")
		assert(game.state == game.Screen.TITLE)
		game._handle_action("sources")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		game._input(escape)
		assert(game.state == game.Screen.TITLE)
	if "--nuggets" in OS.get_cmdline_user_args():
		game._handle_action("guide")
		await _capture(game, "nugget_guide")
		game._handle_action("back")
	game._start_round()
	game.cat = Vector2(340, 210)
	game.cat_previous = game.cat
	for i in range(330):
		game._step(1.0 / 60.0)
	game._catch(Vector2(340, 210))
	await _capture(game, "gameplay")
	if "--boss" in OS.get_cmdline_user_args():
		game.remaining = game.BOSS_DURATION + 2.5
		await _capture(game, "boss_warning")
		game.remaining = game.BOSS_DURATION
		game._start_boss()
		game.cat = Vector2(245, 240)
		for hp in [40, 26, 12]:
			game.boss_hp = hp
			await _capture(game, "boss_%02d" % hp)
		game.boss_defeated = true
		game.round_phase = game.RoundPhase.CELEBRATING
		game.boss_hp = 0
		game.celebration_time = 0.7
		game.banner_time = 0
		await _capture(game, "boss_celebration")
		game._finish_round()
		for palette in range(game.cat_palettes.size()):
			game._select_cat(palette)
			game.results_time = palette * 0.13
			await _capture(game, "boss_dance_%02d" % palette)
		game._start_round()
	if "--rooms" in OS.get_cmdline_user_args():
		var check_fullscreen := "--check-title-fullscreen" in OS.get_cmdline_user_args()
		if check_fullscreen:
			game._toggle_fullscreen()
			await create_timer(1.2).timeout
		game.hands.clear()
		game.nuggets.clear()
		game.particles.clear()
		game.popups.clear()
		game.banner_time = 0
		game.cat = Vector2(320, 230)
		for kind in ["regular", "big", "burnt", "golden", "big_golden"]:
			var nugget = game._make_nugget(kind, Vector2(100 + game.nuggets.size() * 110, 135), Vector2.ZERO, 0)
			nugget.rotation = 0.2
			game.nuggets.append(nugget)
		var board := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
		for i in range(game.room.NAMES.size()):
			game._change_screen(game.Screen.PLAYING)
			game.room.index = i
			game.room.variation = i
			var rng_state: int = game.room.rng.state
			await _capture(game, "room_%02d" % i)
			assert(game.room.rng.state == rng_state)
			var screen := root.get_texture().get_image()
			screen.resize(640, 360, Image.INTERPOLATE_NEAREST)
			board.blit_rect(screen, Rect2i(0, 0, 640, 360), Vector2i((i % 2) * 640, (i / 2) * 360))
		board.save_png("res://build/previews/rooms.png")
		if check_fullscreen:
			game._toggle_fullscreen()
			await create_timer(1.2).timeout
	if "--nuggets" in OS.get_cmdline_user_args():
		game.hands.clear()
		game.nuggets.clear()
		game.particles.clear()
		game.popups.clear()
		game.cat = Vector2(320, 275)
		var types := ["regular", "big", "burnt", "golden", "big_golden"]
		for i in range(types.size()):
			var nugget = game._make_nugget(types[i], Vector2(110 + i * 105, 172), Vector2.ZERO, 0)
			nugget.rotation = 0.2
			game.nuggets.append(nugget)
		await _capture(game, "nugget_types")
		for frame in range(4):
			for nugget in game.nuggets:
				nugget.age = frame * 0.15
			await _capture(game, "nugget_glitter_%02d" % frame)
	if "--bites" in OS.get_cmdline_user_args():
		game.hands.clear()
		game.nuggets.clear()
		game.particles.clear()
		game.popups.clear()
		game.banner_time = 0
		game.cat = Vector2(320, 280)
		for row in range(2):
			for stage in range(3):
				var nugget = game._make_nugget("big" if row == 0 else "big_golden", Vector2(200 + stage * 120, 120 + row * 95), Vector2.ZERO, 0)
				nugget.hp = 3 - stage
				nugget.rotation = 0
				game.nuggets.append(nugget)
		for room in range(game.room.NAMES.size()):
			game._change_screen(game.Screen.PLAYING)
			game.room.index = room
			game.room.variation = 0
			await _capture(game, "bites_room_%02d" % room)
	if "--hands" in OS.get_cmdline_user_args():
		game.hands.clear()
		game.nuggets.clear()
		game.particles.clear()
		game.popups.clear()
		game.cat = Vector2(320, 278)
		for i in range(3):
			game.hands.append({"pos": Vector2(160 + i * 160, 165), "angle": 0.0, "age": [0.25, 0.55, 0.85][i], "released": i == 2, "edge": 0})
		await _capture(game, "hands_in_game")
	game._pause()
	await _capture(game, "pause")
	game._handle_action("settings")
	game._select_track(1)
	await _capture(game, "settings")
	if "--cat-colors" in OS.get_cmdline_user_args():
		for i in range(game.cat_palettes.size()):
			game._change_screen(game.Screen.TITLE)
			game._select_cat(i)
			game.expression = 0
			await _capture(game, "cat_" + game.cat_palettes[i].name.to_lower())
		var sheet_size: Vector2i = game.cat_art.image_size
		var palette_sheet := Image.create(sheet_size.x, sheet_size.y * game.cat_palettes.size(), false, Image.FORMAT_RGBA8)
		palette_sheet.fill(Color("c9d9c6"))
		for i in range(game.cat_palettes.size()):
			palette_sheet.blend_rect(game.cat_art.texture_for_palette(i).get_image(), Rect2i(Vector2i.ZERO, sheet_size), Vector2i(0, i * sheet_size.y))
		palette_sheet.resize(sheet_size.x * 2, palette_sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
		palette_sheet.save_png("res://build/previews/cat_palette_sheet.png")
	if "--check-settings" in OS.get_cmdline_user_args():
		await _check_settings(game)
	game.score = 1540
	game.catches = 58
	game.misses = 9
	game.longest = 23
	game._finish_round()
	await _capture(game, "results")
	if "--dance" in OS.get_cmdline_user_args():
		var board := Image.create(528, 246, false, Image.FORMAT_RGBA8)
		var times := [0.0, 0.18, 0.48, 0.81, 1.25, 1.72, 2.30, 3.10]
		for i in range(times.size()):
			game.results_time = times[i]
			await _capture(game, "dance_%02d" % i)
			var screen := root.get_texture().get_image()
			screen.resize(640, 360, Image.INTERPOLATE_NEAREST)
			board.blit_rect(screen, Rect2i(132, 65, 132, 123), Vector2i((i % 4) * 132, (i / 4) * 123))
		board.resize(1056, 492, Image.INTERPOLATE_NEAREST)
		board.save_png("res://build/previews/victory_dance.png")
	print("Rendered preview screens in build/previews.")
	quit()

func _check_title_fullscreen(game: Node2D) -> void:
	var original_size := root.size
	var chosen_room: int = game.room.index
	var button: Rect2 = game.ScreenLayout.button_rect(game.Screen.TITLE, "fullscreen")
	assert(game.ScreenLayout.action_at(game.Screen.TITLE, button.get_center()) == "fullscreen")
	game._activate_button_at(button.get_center())
	await create_timer(1.2).timeout
	assert(game.fullscreen and root.mode == Window.MODE_FULLSCREEN)
	assert(game.state == game.Screen.TITLE and game.room.index == chosen_room)
	await _capture(game, "title_fullscreen")
	game._activate_button_at(button.get_center())
	await create_timer(1.2).timeout
	assert(not game.fullscreen and root.mode == Window.MODE_WINDOWED and root.size == original_size)
	assert(game.state == game.Screen.TITLE)
	await _capture(game, "title_windowed")
	print("TITLE FULLSCREEN CHECK: button hit testing, fullscreen entry, window-size restoration, title/room preserved.")

func _check_settings(game: Node2D) -> void:
	# Toggle through both shortcuts using the actual window, without saving test preferences.
	var original_size := root.size
	game._start_round()
	var event := InputEventKey.new()
	event.keycode = KEY_F11
	event.pressed = true
	game._input(event)
	await create_timer(1.2).timeout
	assert(root.mode == Window.MODE_FULLSCREEN and game.state == game.Screen.PAUSED)
	await _capture(game, "fullscreen")
	event.keycode = KEY_ENTER
	event.alt_pressed = true
	game._input(event)
	await create_timer(1.2).timeout
	print("Window restore: mode=%d size=%s expected=%s" % [root.mode, root.size, original_size])
	assert(root.mode == Window.MODE_WINDOWED and root.size == original_size)
	# Preview music from pause, then return to a paused game.
	game.remaining = 8
	game._start_boss()
	game._handle_action("settings")
	for i in range(game.TRACKS.size()):
		game._select_track(i)
		game.audio.music.play()
		await create_timer(0.15).timeout
		assert(game.audio.music.playing and game.audio.music.get_playback_position() > 0)
		assert(is_equal_approx(game.audio.music.pitch_scale, 1.0))
		game._handle_action("back")
		assert(game.state == game.Screen.PAUSED and game.audio.music.stream_paused)
		assert(game.audio.music.pitch_scale > 1.14)
		game._handle_action("settings")
		assert(not game.audio.music.stream_paused)
	game._handle_action("back")
	game.remaining = 8
	game.test_mode = false
	game._resume()
	assert(game.audio.finale.playing)
	assert(is_equal_approx(game.audio.finale.pitch_scale, game.audio.music.pitch_scale))
	game.test_mode = true
	game._pause()
	game.audio.music.stop()
	game.audio.finale.stop()
	await create_timer(0.1).timeout
	print("SETTINGS CHECK PASSED: F11 fullscreen, Alt+Enter window restore, pause safety, %d audio previews, paused return, finale audio after track change." % game.TRACKS.size())

func _preview_layouts(game: Node2D) -> void:
	for item in [
		["tablet", Vector2i(1024, 768)],
		["phone_wide", Vector2i(852, 393)],
		["portrait", Vector2i(393, 700)],
		["desktop", Vector2i(1280, 720)],
	]:
		root.size = item[1]
		await create_timer(0.3).timeout
		game._change_screen(game.Screen.TITLE)
		await _capture(game, "layout_" + item[0])
		if not game.display_layout.portrait:
			game._start_round()
			game.touch_mode = true
			game.cat = Vector2(320, 240)
			game.cat_previous = game.cat
			game.banner_time = 0
			await _capture(game, "layout_" + item[0] + "_game")
	# Rotation must pause a live round and returning to landscape must keep it paused.
	game._start_round()
	root.size = Vector2i(393, 700)
	await create_timer(0.3).timeout
	assert(game.display_layout.portrait and game.state == game.Screen.PAUSED)
	root.size = Vector2i(1024, 768)
	await create_timer(0.3).timeout
	assert(not game.display_layout.portrait and game.state == game.Screen.PAUSED)
	await _capture(game, "layout_rotation_paused")
	print("LAYOUT PREVIEW: tablet, wide phone, portrait and desktop; rotation pauses until explicitly resumed.")

func _capture(game: Node2D, label: String) -> void:
	game.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	image.save_png("res://build/previews/%s.png" % label)
