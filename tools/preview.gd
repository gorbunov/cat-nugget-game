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
	game._start()
	game.cat = Vector2(340, 210)
	game.cat_previous = game.cat
	for i in range(330):
		game._step(1.0 / 60.0)
	game._catch(Vector2(340, 210))
	await _capture(game, "gameplay")
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
		for i in range(game.CAT_PALETTES.size()):
			game.state = "title"
			game._select_cat(i)
			await _capture(game, "cat_" + game.CAT_PALETTES[i].name.to_lower())
		var palette_sheet := Image.create(384, 48 * game.CAT_PALETTES.size(), false, Image.FORMAT_RGBA8)
		palette_sheet.fill(Color("c9d9c6"))
		for i in range(game.CAT_PALETTES.size()):
			palette_sheet.blend_rect(game.cat_textures[i].get_image(), Rect2i(0, 0, 384, 48), Vector2i(0, i * 48))
		palette_sheet.resize(768, 96 * game.CAT_PALETTES.size(), Image.INTERPOLATE_NEAREST)
		palette_sheet.save_png("res://build/previews/cat_palette_sheet.png")
	if "--check-settings" in OS.get_cmdline_user_args():
		await _check_settings(game)
	game.score = 1540
	game.catches = 58
	game.misses = 9
	game.longest = 23
	game._finish()
	await _capture(game, "results")
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
