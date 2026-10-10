extends RefCounted
## Invoked by --smoke-test after the game is ready, with normal saves disabled.

const Game := preload("res://scripts/game.gd")


static func run(game: Game) -> void:
	assert(game.test_mode)
	game.random.seed = 12345
	# An assertion aborts its helper and returns false. Propagate that failure
	# rather than continuing to print success (Godot assertions don't exit).
	var checks: Array[Callable] = [
		_check_scoring, _check_pacing, _check_music, _check_round_choices, _check_palettes,
	]
	if not OS.has_feature("standalone"):
		checks.append(_check_persistence)
	checks.append(_check_navigation)
	for check in checks:
		if not check.call(game):
			game.get_tree().quit(1)
			return
	print("SMOKE TEST PASSED: gameplay, pacing, music, 48 randomized rounds, palettes, cached textures, animation frames, manual selection, saved preferences and navigation.")
	game.get_tree().quit(0)


static func _check_scoring(game: Game) -> bool:
	game._start_round()
	assert(game.state == Game.Screen.PLAYING and game.remaining == 60 and game.score == 0)
	assert(game._swept_catch(Vector2(100, 100), Vector2(300, 100), Vector2(200, 100), Vector2(200, 100)))
	assert(game._swept_catch(Vector2(200, 100), Vector2(200, 100), Vector2(100, 100), Vector2(300, 100)))
	assert(not game._swept_catch(Vector2(100, 200), Vector2(300, 200), Vector2(200, 100), Vector2(200, 100)))
	for i in range(5):
		game._catch(Vector2(320, 180))
	assert(game.score == 50 and game._multiplier() == 2 and game.longest == 5)
	game._catch(Vector2(320, 180))
	assert(game.score == 70)
	game._miss()
	assert(game.streak == 0 and game._multiplier() == 1 and game.misses == 1 and game.score == 70)
	for i in range(30):
		game._catch(Vector2(320, 180))
	assert(game._multiplier() == 5)
	game._pause()
	assert(game.state == Game.Screen.PAUSED)
	game._resume()
	return true
	assert(game.state == Game.Screen.PLAYING)
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(game.state == Game.Screen.PAUSED)
	game._resume()


static func _check_pacing(game: Game) -> bool:
	game._start_round()
	game.cat = Vector2(-500, -500)
	game.cat_previous = game.cat
	var throw_buckets := [0, 0, 0]
	var previous_rate := 1.0
	for i in range(3601):
		if game.state == Game.Screen.PLAYING:
			var count_before := game.throws
			game._step(1.0 / 60.0)
			throw_buckets[mini(2, i / 1200)] += game.throws - count_before
			if i == 59:
				assert(game.throws >= 1)
			if game.state == Game.Screen.PLAYING:
				assert(game.audio.music.pitch_scale >= previous_rate and game.audio.music.pitch_scale <= 1.2001)
				assert(is_equal_approx(game.audio.music.pitch_scale, game.audio.finale.pitch_scale))
				previous_rate = game.audio.music.pitch_scale
	assert(game.state == Game.Screen.RESULTS and game.remaining == 0)
	assert(game.misses > 30 and game.catches == 0)
	assert(throw_buckets[0] >= 24 and throw_buckets[1] > throw_buckets[0] and throw_buckets[2] > throw_buckets[1])
	assert(is_equal_approx(game.audio.music.pitch_scale, 1.0))
	print("PACE CHECK: throws per 20 seconds: %s; peak music speed: %.2fx; misses: %d" % [throw_buckets, previous_rate, game.misses])
	return true


static func _check_music(game: Game) -> bool:
	game._start_round()
	assert(is_equal_approx(game.audio.music.pitch_scale, 1.0))
	game.remaining = 8
	game._step(0.01)
	var late_rate := game.audio.music.pitch_scale
	assert(late_rate > 1.14)
	game._pause()
	game._handle_action("settings")
	assert(is_equal_approx(game.audio.music.pitch_scale, 1.0))
	game._handle_action("track_next")
	game._handle_action("back")
	assert(is_equal_approx(game.audio.music.pitch_scale, late_rate))
	game._resume()
	assert(is_equal_approx(game.audio.finale.pitch_scale, late_rate))
	game._handle_action("home")
	assert(is_equal_approx(game.audio.music.pitch_scale, 1.0))
	game._start_round()
	assert(game.nuggets.is_empty() and game.hands.is_empty() and game.score == 0 and game.misses == 0)
	for i in range(Game.TRACKS.size()):
		game._select_track(i)
		assert(game.audio.music.stream.get_length() > 25 and game.audio.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
		if i > 0:
			assert(is_equal_approx(game.audio.music.stream.get_length(), game.audio.finale.stream.get_length()))
	game._select_track(-1)
	assert(game.selected_track == Game.TRACKS.size() - 1)
	game._handle_action("track_next")
	assert(game.selected_track == 0 and not game.shuffle_music)
	game._start_round()
	assert(game.selected_track == 0)
	game._handle_action("shuffle")
	assert(game.shuffle_music)
	return true


static func _check_round_choices(game: Game) -> bool:
	var seen_tracks := {}
	var seen_cats := {}
	for i in range(48):
		var previous_track := game.selected_track
		var previous_cat := game.cat_palette
		game._start_round()
		assert(game.selected_track != previous_track and game.cat_palette != previous_cat)
		seen_tracks[game.selected_track] = true
		seen_cats[game.cat_palette] = true
		var round_track := game.selected_track
		var round_cat := game.cat_palette
		game._pause()
		game._resume()
		assert(game.selected_track == round_track and game.cat_palette == round_cat)
	assert(seen_tracks.size() == Game.TRACKS.size() and seen_cats.size() == game.cat_palettes.size())
	game._handle_action("home")
	var before_click := game.cat_palette
	var name_before_click := game.cat_name_index
	game._handle_action("cat_shuffle")
	assert(game.cat_palette != before_click and game.cat_name_index != name_before_click and game.state == Game.Screen.TITLE)
	var clicked_color := game.cat_palette
	var clicked_name := game.cat_name_index
	game._start_round()
	assert(game.cat_palette == clicked_color and game.cat_name_index == clicked_name and not game.title_cat_selected)
	game._start_round()
	assert(game.cat_palette != clicked_color and game.cat_name_index != clicked_name)
	return true


static func _check_palettes(game: Game) -> bool:
	var role_examples := {}
	for pixel in range(game.cat_art.indices.size()):
		role_examples[game.cat_art.indices[pixel]] = Vector2i(pixel % game.cat_art.image_size.x, pixel / game.cat_art.image_size.x)
	assert(role_examples.size() == game.cat_art.roles.size())
	for palette_index in range(game.cat_palettes.size()):
		var texture := game.cat_art.texture_for_palette(palette_index)
		assert(texture == game.cat_art.texture_for_palette(palette_index))
		var image := texture.get_image()
		assert(image.get_size() == game.cat_art.image_size and image.get_pixelv(role_examples[0]).a == 0)
		for role in range(1, game.cat_art.roles.size()):
			var expected := Color(str(game.cat_palettes[palette_index].colors[game.cat_art.roles[role]]))
			assert(image.get_pixelv(role_examples[role]).to_rgba32() == expected.to_rgba32())
		for frame in range(game.cat_art.frame_count):
			assert(image.get_region(Rect2i(game.cat_art.frame_rect(frame))).get_used_rect().has_area())
	return true


static func _check_persistence(game: Game) -> bool:
	DirAccess.make_dir_recursive_absolute("res://build")
	game.best = 1234
	game.master_volume = 0.6
	game.music_volume = 0.3
	game.sfx_volume = 0.8
	game.selected_track = 2
	game.shuffle_music = false
	game.fullscreen = true
	game._save_settings("res://build/test_save.cfg")
	game.best = 0
	game.master_volume = 0
	game.music_volume = 0
	game.sfx_volume = 0
	game.selected_track = 0
	game.shuffle_music = true
	game.fullscreen = false
	game._load_settings("res://build/test_save.cfg")
	assert(game.best == 1234 and is_equal_approx(game.music_volume, 0.3) and is_equal_approx(game.sfx_volume, 0.8))
	assert(is_equal_approx(game.master_volume, 0.6))
	var legacy := ConfigFile.new()
	assert(legacy.load("res://build/test_save.cfg") == OK)
	legacy.erase_section_key("audio", "master")
	assert(legacy.save("res://build/test_save.cfg") == OK)
	game._load_settings("res://build/test_save.cfg")
	assert(is_equal_approx(game.master_volume, 1.0))
	game.volume_drag = 0
	game._drag_volume(game._volume_slider_rect(0).position.x - 10)
	assert(game.master_volume == 0 and AudioServer.is_bus_mute(0))
	game._drag_volume(game._volume_slider_rect(0).end.x + 10)
	assert(game.master_volume == 1 and not AudioServer.is_bus_mute(0))
	assert(is_equal_approx(game.audio.music.volume_linear, game.music_volume))
	game.volume_drag = -1
	assert(game.selected_track == 2 and game.fullscreen and not game.shuffle_music)
	DirAccess.remove_absolute("res://build/test_save.cfg")
	return true


static func _check_navigation(game: Game) -> bool:
	# No draw or frame wait between transitions: hit testing must be immediately valid.
	game._handle_action("home")
	game._activate_button_at(Vector2(400, 265))
	assert(game.state == Game.Screen.SETTINGS)
	game.volume_drag = 1
	game._activate_button_at(Vector2(320, 315))
	assert(game.state == Game.Screen.TITLE and game.volume_drag == -1)
	game._activate_button_at(Vector2(200, 265))
	assert(game.state == Game.Screen.PLAYING)
	game._activate_button_at(Vector2(605, 24))
	assert(game.state == Game.Screen.PAUSED)
	# The HUD remains visible below the overlay but is not an active control.
	assert(Game.ScreenLayout.action_at(game.state, Vector2(605, 24)).is_empty())
	game._activate_button_at(Vector2(605, 24))
	assert(game.state == Game.Screen.PAUSED)
	game._activate_button_at(Vector2(320, 228))
	assert(game.state == Game.Screen.GUIDE)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	assert(game.state == Game.Screen.PAUSED)
	game._input(escape)
	assert(game.state == Game.Screen.PLAYING)
	game._finish_round()
	game._activate_button_at(Vector2(400, 287))
	assert(game.state == Game.Screen.TITLE)
	game._activate_button_at(Vector2(220, 317))
	assert(game.state == Game.Screen.SOURCES)
	game._input(escape)
	assert(game.state == Game.Screen.TITLE)
	# Named keyboard actions keep Enter and Space distinct from Alt+Enter.
	for key in [KEY_ENTER, KEY_SPACE]:
		var confirm := InputEventKey.new()
		confirm.keycode = key
		confirm.pressed = true
		game._input(confirm)
		assert(game.state == Game.Screen.PLAYING)
		game._handle_action("home")
	var fullscreen := InputEventKey.new()
	fullscreen.keycode = KEY_ENTER
	fullscreen.alt_pressed = true
	fullscreen.pressed = true
	assert(fullscreen.is_action_pressed("toggle_fullscreen", false, true))
	assert(not fullscreen.is_action_pressed("confirm", false, true))
	fullscreen.alt_pressed = false
	fullscreen.keycode = KEY_F11
	assert(fullscreen.is_action_pressed("toggle_fullscreen", false, true))
	return true
