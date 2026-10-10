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
	await _capture(game, "title")
	if "--nuggets" in OS.get_cmdline_user_args():
		game._action("guide")
		await _capture(game, "nugget_guide")
		game._action("back")
	game._start()
	game.cat = Vector2(340, 210)
	game.cat_previous = game.cat
	for i in range(330):
		game._step(1.0 / 60.0)
	game._catch(Vector2(340, 210))
	await _capture(game, "gameplay")
	if "--nuggets" in OS.get_cmdline_user_args():
		game.hands.clear()
		game.nuggets.clear()
		game.particles.clear()
		game.popups.clear()
		game.cat = Vector2(320, 275)
		var types := ["regular", "big", "burnt", "golden", "big_golden"]
		for i in range(types.size()):
			var nugget: Dictionary = game._make_nugget(types[i], Vector2(110 + i * 105, 172), Vector2.ZERO, 0)
			nugget.rotation = 0.2
			game.nuggets.append(nugget)
		await _capture(game, "nugget_types")
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
	game._action("settings")
	game._select_track(1)
	await _capture(game, "settings")
	if "--cat-colors" in OS.get_cmdline_user_args():
		for i in range(game.cat_palettes.size()):
			game.state = "title"
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
	game._finish()
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
	print("Rendered five preview screens in build/previews.")
	quit()

func _check_settings(game: Node2D) -> void:
	# Toggle through both shortcuts using the actual window, without saving test preferences.
	var original_size := root.size
	game._start()
	var event := InputEventKey.new()
	event.keycode = KEY_F11
	event.pressed = true
	game._input(event)
	await create_timer(1.2).timeout
	assert(root.mode == Window.MODE_FULLSCREEN and game.state == "paused")
	await _capture(game, "fullscreen")
	event.keycode = KEY_ENTER
	event.alt_pressed = true
	game._input(event)
	await create_timer(1.2).timeout
	print("Window restore: mode=%d size=%s expected=%s" % [root.mode, root.size, original_size])
	assert(root.mode == Window.MODE_WINDOWED and root.size == original_size)
	# Preview music from pause, then return to a paused game.
	game.remaining = 8
	game._action("settings")
	for i in range(game.TRACKS.size()):
		game._select_track(i)
		game.music.play()
		await create_timer(0.15).timeout
		assert(game.music.playing and game.music.get_playback_position() > 0)
		assert(is_equal_approx(game.music.pitch_scale, 1.0))
		game._action("back")
		assert(game.state == "paused" and game.music.stream_paused)
		assert(game.music.pitch_scale > 1.14)
		game._action("settings")
		assert(not game.music.stream_paused)
	game._action("back")
	game.remaining = 8
	game.test_mode = false
	game._resume()
	assert(game.panic_music.playing)
	assert(is_equal_approx(game.panic_music.pitch_scale, game.music.pitch_scale))
	game.test_mode = true
	game._pause()
	game.music.stop()
	game.panic_music.stop()
	await create_timer(0.1).timeout
	print("SETTINGS CHECK PASSED: F11 fullscreen, Alt+Enter window restore, pause safety, %d audio previews, paused return, finale audio after track change." % game.TRACKS.size())

func _capture(game: Node2D, label: String) -> void:
	game.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	image.save_png("res://build/previews/%s.png" % label)
