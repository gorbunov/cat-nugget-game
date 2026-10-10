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
	checks.append(_check_rooms)
	checks.append(_check_platform_controls)
	checks.append(_check_touch_controls)
	checks.append(_check_display_layout)
	checks.append(_check_golden_club)
	for check in checks:
		if not check.call(game):
			game.get_tree().quit(1)
			return
	print("SMOKE TEST PASSED: gameplay, pacing, music, 48 randomized rounds, palettes, cached textures, animation frames, manual selection, saved preferences and navigation.")
	game.get_tree().quit(0)

static func _check_golden_club(game: Game) -> bool:
	game._change_screen(Game.Screen.TITLE)
	assert(not game.golden_club_enabled)
	assert(game._action_at(Vector2(43, 42)).is_empty())
	game._handle_action("golden_feast")
	assert(game.state == Game.Screen.TITLE)
	var nose := Game.ScreenLayout.title_nose_rect(game._title_mouth()).get_center()
	for i in range(6):
		game._activate_button_at(nose)
	assert(not game.golden_club_enabled and game.state == Game.Screen.TITLE)
	_touch(game, 0, nose, true)
	_touch(game, 0, nose, false)
	assert(not game.golden_club_enabled)
	assert(game.state == Game.Screen.GOLDEN_CLUB)
	assert(game._action_at(nose).is_empty()) # No title controls through the panel.
	game._handle_action("back")
	assert(game.state == Game.Screen.TITLE and not game.golden_club_enabled)
	for i in range(6):
		game._activate_button_at(nose)
	assert(game.state == Game.Screen.TITLE)
	game._activate_button_at(nose)
	assert(game.state == Game.Screen.GOLDEN_CLUB)
	game._handle_action("golden_feast")
	assert(game.state == Game.Screen.PLAYING and game.golden_club_enabled)
	for elapsed in [0.0, 10.0, 25.0, 40.0]:
		game.remaining = Game.ROUND_LENGTH - elapsed
		for i in range(100):
			assert(game._next_nugget_kind() in ["golden", "big_golden"])
	game._start_boss()
	assert(game.banner == "THE BIG GOLDEN CHOMP!")
	for hp in [40, 20, 10]:
		game.boss_hp = hp
		assert(game._boss_contains_mouth(game.boss_pos))
	var normal_best := game.best
	game.score = normal_best + 1000
	game._finish_round()
	assert(game.best == normal_best and game.golden_best >= game.score)
	game._handle_action("start") # Results replay always starts a normal round.
	assert(not game.golden_club_enabled and game.old_best == normal_best)
	var club_best := game.golden_best
	if not OS.has_feature("standalone"):
		var path := "res://build/test_save.cfg"
		game._save_settings(path)
		var cfg := ConfigFile.new()
		assert(cfg.load(path) == OK)
		assert(not cfg.has_section_key("club", "unlocked"))
		assert(not cfg.has_section_key("club", "enabled"))
		# Older saves must not restore the previous sticky mode.
		cfg.set_value("club", "unlocked", true)
		cfg.set_value("club", "enabled", true)
		assert(cfg.save(path) == OK)
		game.golden_best = 0
		game._load_settings(path)
		assert(not game.golden_club_enabled and game.golden_best == club_best)
		DirAccess.remove_absolute(path)
	game._handle_action("home")
	for i in range(7):
		game._activate_button_at(nose)
	game._handle_action("golden_feast")
	assert(game.golden_club_enabled)
	game._pause()
	game._resume()
	assert(game.golden_club_enabled)
	game._handle_action("home")
	assert(not game.golden_club_enabled)
	game._start_round()
	assert(game.old_best == normal_best)
	game.remaining = Game.ROUND_LENGTH
	for i in range(50):
		assert(game._next_nugget_kind() == "regular")
	print("GOLDEN CLUB CHECK: seven-tap entry, one-round feast, normal replay, gold-only spawns, boss masks and score-only persistence.")
	return true

static func _touch(game: Game, index: int, position: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = game.get_global_transform_with_canvas() * position
	event.pressed = pressed
	event.canceled = canceled
	game._input(event)

static func _check_display_layout(game: Game) -> bool:
	var layout := game.display_layout
	for size in [Vector2(1280, 720), Vector2(1024, 768), Vector2(852, 393)]:
		var safe := Rect2(Vector2.ZERO, size)
		layout.configure(size, safe)
		assert(safe.encloses(layout.play_rect))
		assert(layout.play_rect.get_center().is_equal_approx(safe.get_center()))
		assert(is_equal_approx(layout.play_rect.size.aspect(), 640.0 / 360))
		assert(not layout.portrait)
	var notched := Rect2(44, 0, 764, 372)
	layout.configure(Vector2(852, 393), notched)
	assert(notched.encloses(layout.play_rect))
	assert(layout.play_rect.get_center().is_equal_approx(notched.get_center()))
	layout.configure(Vector2(1024, 768), Rect2(0, 0, 1024, 768))
	game._start_round()
	_touch(game, 0, Vector2(320, 395), true)
	game._update_cat_motion(1.0 / 60)
	assert(game.touch_mode and game.cat.is_equal_approx(Vector2(320, 326)))
	_touch(game, 0, Vector2(320, 395), false)
	game._pause()
	_touch(game, 0, Vector2(320, 395), true)
	assert(game.active_touch == -1 and game.state == Game.Screen.PAUSED)
	layout.configure(Vector2(393, 852), Rect2(0, 44, 393, 774))
	assert(layout.portrait)
	_touch(game, 0, Game.ScreenLayout.button_rect(Game.Screen.PAUSED, "resume").get_center(), true)
	assert(game.state == Game.Screen.PAUSED)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	game._input(enter)
	assert(game.state == Game.Screen.PAUSED)
	game._update_display_layout()
	print("LAYOUT CHECK: proportional fit, 4:3/wide margins, safe areas, bottom-margin dragging and portrait input blocking.")
	return true


static func _drag(game: Game, index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = game.get_global_transform_with_canvas() * position
	game._input(event)


static func _check_touch_controls(game: Game) -> bool:
	assert(not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"))
	game._change_screen(Game.Screen.TITLE)
	_touch(game, 0, Game.ScreenLayout.button_rect(Game.Screen.TITLE, "start").get_center(), true)
	assert(game.state == Game.Screen.PLAYING and game.touch_mode)
	assert(game.cat == Vector2(320, 180)) # Start tap must not move the cat.
	_touch(game, 0, Vector2(320, 280), false)
	_touch(game, 2, Vector2(250, 260), true)
	game._update_cat_motion(1.0 / 60)
	assert(game.cat.is_equal_approx(Vector2(250, 196)) and game.cat_previous == Vector2(320, 180), "Touch mapped to %s; transform %s" % [game.cat, game.transform])
	_drag(game, 2, Vector2(400, 300))
	game._update_cat_motion(1.0 / 60)
	assert(game.cat.is_equal_approx(Vector2(400, 236)) and game.cat_previous.is_equal_approx(Vector2(250, 196)))
	# A second finger cannot move the cat, release the first finger or hit Pause.
	_touch(game, 7, Game.ScreenLayout.button_rect(Game.Screen.PLAYING, "pause").get_center(), true)
	_drag(game, 7, Vector2(100, 100))
	_touch(game, 7, Vector2(100, 100), false)
	game._update_cat_motion(1.0 / 60)
	assert(game.cat.is_equal_approx(Vector2(400, 236)) and game.active_touch == 2 and game.state == Game.Screen.PLAYING)
	_touch(game, 2, Vector2(400, 300), false)
	var synthetic := InputEventMouseMotion.new()
	synthetic.device = InputEvent.DEVICE_ID_EMULATION
	synthetic.relative = Vector2(10, 10)
	game._input(synthetic)
	game._update_cat_motion(1.0 / 60)
	assert(game.cat.is_equal_approx(Vector2(400, 236)) and game.cat_previous == game.cat and game.touch_mode)
	_touch(game, 1, Vector2(100, 150), true)
	_drag(game, 1, Vector2(-100, -100))
	game._update_cat_motion(1.0 / 60)
	assert(game.cat == Game.CAT_MIN)
	_drag(game, 1, Vector2(800, 500))
	game._update_cat_motion(1.0 / 60)
	assert(game.cat == Game.CAT_MAX)
	_touch(game, 1, Vector2(800, 500), false, true)
	_drag(game, 1, Vector2(300, 200))
	game._update_cat_motion(1.0 / 60)
	assert(game.cat == Game.CAT_MAX and game.active_touch == -1)
	# Focus loss ends dragging; resuming preserves the mouth and requires a fresh touch.
	_touch(game, 3, Vector2(300, 250), true)
	game._update_cat_motion(1.0 / 60)
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(game.state == Game.Screen.PAUSED and game.active_touch == -1)
	_touch(game, 4, Game.ScreenLayout.button_rect(Game.Screen.PAUSED, "resume").get_center(), true)
	_drag(game, 3, Vector2(100, 100))
	game._update_cat_motion(1.0 / 60)
	assert(game.state == Game.Screen.PLAYING and game.cat.is_equal_approx(Vector2(300, 186)))
	_touch(game, 4, Vector2.ZERO, false)
	_touch(game, 0, Game.ScreenLayout.button_rect(Game.Screen.PLAYING, "pause").get_center(), true)
	assert(game.state == Game.Screen.PAUSED)
	game._handle_action("settings")
	var slider := game._volume_slider_rect(0)
	_touch(game, 0, slider.get_center(), true)
	assert(is_equal_approx(game.master_volume, 0.5))
	_drag(game, 0, slider.end)
	assert(is_equal_approx(game.master_volume, 1.0))
	_touch(game, 0, slider.end, false)
	assert(game.volume_drag == -1)
	_touch(game, 0, Game.ScreenLayout.button_rect(Game.Screen.SETTINGS, "back").get_center(), true)
	assert(game.state == Game.Screen.PAUSED)
	game._resume()
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(1, 0)
	game._input(mouse)
	game._update_cat_motion(1.0 / 60)
	assert(not game.touch_mode and game.cat == game.get_local_mouse_position().clamp(Game.CAT_MIN, Game.CAT_MAX))
	print("TOUCH CHECK: offset drag, swept movement, release/cancel, edge clamps, extra fingers, focus loss, menu taps, sliders and mouse handoff.")
	return true


static func _check_platform_controls(game: Game) -> bool:
	var original := game.platform
	game.platform = Game.PlatformPolicy.new()
	game.platform.web = true
	game.platform.mobile = false
	game.platform.web_fullscreen_available = false
	game._change_screen(Game.Screen.TITLE)
	assert(not game.platform.can_quit() and not game.platform.supports_fullscreen())
	for action in ["quit", "fullscreen"]:
		var position := Game.ScreenLayout.button_rect(Game.Screen.TITLE, action).get_center()
		assert(Game.ScreenLayout.action_at(Game.Screen.TITLE, position, false, false).is_empty())
		game._activate_button_at(position)
		assert(game.state == Game.Screen.TITLE)
	game._handle_action("quit") # Must not terminate the browser application.
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	assert(game.state == Game.Screen.TITLE and game.browser_audio_started)
	assert(not game.audio.playback_enabled) # Test mode still protects audio/saves.
	game._handle_action("settings")
	game._input(escape)
	assert(game.state == Game.Screen.TITLE)
	game.platform.web_fullscreen_available = true
	assert(game.platform.supports_fullscreen())
	var fullscreen_position := Game.ScreenLayout.button_rect(Game.Screen.TITLE, "fullscreen").get_center()
	assert(Game.ScreenLayout.action_at(Game.Screen.TITLE, fullscreen_position, false, true) == "fullscreen")
	game.platform.web = false
	game.platform.mobile = true
	assert(not game.platform.can_quit() and not game.platform.supports_fullscreen())
	game.platform.mobile = false
	assert(game.platform.can_quit() and game.platform.supports_fullscreen())
	game.platform = original
	print("PLATFORM CHECK: browser/mobile omit Quit, unsupported fullscreen cannot be clicked, overlay Escape works, audio waits for a gesture.")
	return true


static func _check_rooms(game: Game) -> bool:
	game.room.rng.seed = 4621
	var seen := {}
	for i in range(32):
		var previous := game.room.index
		game._start_round()
		var chosen := game.room.index
		var detail := game.room.variation
		assert(chosen != previous and chosen >= 0 and chosen < game.room.NAMES.size())
		seen[chosen] = true
		game._pause()
		game._handle_action("settings")
		game._handle_action("back")
		game._resume()
		game._finish_round()
		assert(game.room.index == chosen and game.room.variation == detail)
	assert(seen.size() == game.room.NAMES.size())
	var gameplay_rng_state := game.random.state
	game.room.choose_next()
	assert(game.random.state == gameplay_rng_state)
	print("ROOM CHECK: all four rooms, no consecutive repeats, stable through navigation/results, independent scenery randomness.")
	return true


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
	assert(throw_buckets[0] >= 24 and throw_buckets[1] > throw_buckets[0])
	assert(throw_buckets[2] >= 1 and throw_buckets[2] < 6) # Throws stop at 41s, boss starts at 45s.
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
	for art in [game.cat_art, game.dance_art, game.disgust_art]:
		var role_examples := {}
		for pixel in range(art.indices.size()):
			role_examples[art.indices[pixel]] = Vector2i(pixel % art.image_size.x, pixel / art.image_size.x)
		assert(role_examples.size() == art.roles.size())
		for palette_index in range(game.cat_palettes.size()):
			var texture: Texture2D = art.texture_for_palette(palette_index)
			assert(texture == art.texture_for_palette(palette_index))
			var image := texture.get_image()
			assert(image.get_size() == art.image_size and image.get_pixelv(role_examples[0]).a == 0)
			for role in range(1, art.roles.size()):
				var expected := Color(str(game.cat_palettes[palette_index].colors[art.roles[role]]))
				assert(image.get_pixelv(role_examples[role]).to_rgba32() == expected.to_rgba32())
			for frame in range(art.frame_count):
				assert(image.get_region(Rect2i(art.frame_rect(frame))).get_used_rect().has_area())
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
