extends Node2D
## Round orchestration and custom drawing on a fixed 640x360 logical canvas.
## Audio owns playback; ScreenLayout owns interactive geometry; Nugget owns flight state.

const ROUND_LENGTH := 60.0
const HAND_RELEASE_TIME := 0.72
const HAND_LIFETIME := 1.15
const CATCH_RADIUS := 18.0
const CAT_MIN := Vector2(20, 62)
const CAT_MAX := Vector2(620, 326)
const TOUCH_MOUTH_OFFSET := Vector2(0, -64)
const CHOMP_INTERVAL := 0.20
const BURNT_COOLDOWN := 2.0
const BOSS_BITES := 40
const BOSS_BONUS := 500
const BOSS_SIZE := 96.0
const BOSS_MOUTH_RADIUS := 6.0
const BOSS_DURATION := 15.0
const BOSS_WARNING := 3.0
const THROW_WIND_DOWN := 4.0
const BOSS_BOUNDS := Rect2(56, 142, 528, 108)
const BOSS_VELOCITY := Vector2(110, 55)
enum RoundPhase { CATCHING, BOSS, CELEBRATING }
var round_phase := RoundPhase.CATCHING
var boss_hp := BOSS_BITES
var boss_age := 0.0
var boss_pos := Vector2(320, 190)
var boss_contact := 0.0
var boss_gap := 0.0
var boss_bite_progress := 0.0
var boss_defeated := false
var celebration_time := 0.0
var boss_warning_second := 4
const BIG_GOLD_ROUND_CHANCE := 0.18
const SECOND_BIG_GOLD_CHANCE := 0.005
const NUGGET_TYPES := {
	"regular": {"frame": 0, "hp": 1, "size": 20.0, "points": 10, "radius": 18.0, "chance": 70, "unlock": 0},
	"big": {"frame": 2, "hp": 3, "size": 35.0, "points": 30, "radius": 25.0, "chance": 15, "unlock": 4},
	"burnt": {"frame": 3, "hp": 1, "size": 21.0, "points": 0, "radius": 16.0, "chance": 11, "unlock": 8},
	"golden": {"frame": 4, "hp": 1, "size": 23.0, "points": 20, "radius": 19.0, "chance": 4, "unlock": 12},
	"big_golden": {"frame": 5, "hp": 3, "size": 38.0, "points": 100, "radius": 27.0, "chance": BIG_GOLD_ROUND_CHANCE * 100},
}
const HAND_GRIPS := [Vector2(17, -5), Vector2(12, -15), Vector2(24, -9)]
const INK := Color("423044")
const CREAM := Color("fff0cd")
const GOLD := Color("ffc568")
const PINK := Color("ed91a5")
const MINT := Color("9bd2bc")
const SAVE_PATH := "user://snack_save.cfg"
const SOUND_CREDITS := [
	{"title": "SMALL CROWD REACTIONS", "author": "IENBA", "use": "BURNT / FIRST 2 SECONDS", "id": "488472"},
	{"title": "YAY.MP3", "author": "ZUT50", "use": "GOLDEN / FULL CLIP", "id": "162395"},
	{"title": "GULPCARTOONY.MP3", "author": "GARY_IN_WV", "use": "BIG REGULAR / FULL CLIP", "id": "449868"},
]
const CAT_NAMES := [
	"MOCHI", "BISCUIT", "WAFFLES", "DUMPLING", "NOODLE", "PUDDING", "PICKLES",
	"PEBBLE", "BUTTONS", "MAPLE", "MISO", "BEAN", "SPROUT", "PUMPKIN", "PIP",
	"TOFU", "MUFFIN", "POPPY", "BOBA", "TATER",
]
const TRACKS := [
	{"name": "SNACK TIME", "mood": "THE ORIGINAL BOUNCY CHIPTUNE", "file": "snack_time", "panic": "panic"},
	{"name": "SUNNY SIDE UP", "mood": "SUNNY BELLS AND BREEZY GROOVES", "file": "sunny_side_up", "panic": "sunny_side_up_panic"},
	{"name": "GOOFY WHISKERS", "mood": "FUNNY HOPS AND WOBBLY BASS", "file": "goofy_whiskers", "panic": "goofy_whiskers_panic"},
	{"name": "NUGGET QUEST", "mood": "A TINY CAT. A GRAND ADVENTURE.", "file": "nugget_quest", "panic": "nugget_quest_panic"},
	{"name": "NUGGET BATTLE", "mood": "BOSS-FIGHT DRUMS AND DRIVING BASS", "file": "nugget_battle", "panic": "nugget_battle_panic"},
]
const CatAppearance := preload("res://scripts/cat_appearance.gd")
const Nugget := preload("res://scripts/nugget.gd")
const Difficulty := preload("res://scripts/difficulty.gd")
const GameAudio := preload("res://scripts/game_audio.gd")
const ScreenLayout := preload("res://scripts/screen_layout.gd")
const Screen := ScreenLayout.Screen
const RoomBackground := preload("res://scripts/room_background.gd")
const PlatformPolicy := preload("res://scripts/platform_policy.gd")
const DisplayLayout := preload("res://scripts/display_layout.gd")
var display_layout := DisplayLayout.new()
var platform := PlatformPolicy.new()
var browser_audio_started := false

# Assets and appearance (the chosen cat persists through pause and results).
var cat_art := CatAppearance.new()
var dance_art := CatAppearance.new()
var disgust_art := CatAppearance.new()
var disgust_tex: Texture2D
var dance_tex: Texture2D
var boss_masks: Array[BitMap] = []
var room := RoomBackground.new()
var cat_palettes: Array[Dictionary] = []
var cat_tex: Texture2D
var nugget_tex: Texture2D = preload("res://assets/nuggets.png")
var nugget_bite_tex: Texture2D = preload("res://assets/nugget_bites.png")
var hand_tex: Texture2D = preload("res://assets/hands_ai.png")
var font: Font = preload("res://assets/pixel_font.fnt")
var cat_palette := 0
var cat_name_index := -1
var title_cat_selected := false
var title_snack_rng := RandomNumberGenerator.new()
var title_snack_wait := 5.5
var title_snack: Nugget

# Screen navigation and presentation time.
var state: ScreenLayout.Screen = Screen.TITLE
var previous_state: ScreenLayout.Screen = Screen.TITLE
var clock := 0.0
var results_time := 0.0
var volume_drag := -1

# Mouth position and visual feedback. `cat` is the catch anchor, not sprite origin.
var cat := Vector2(320, 180)
var cat_previous := cat
var cat_velocity := Vector2.ZERO
var touch_mode := false
var active_touch := -1
var touch_target := cat
var tilt := 0.0
var expression := 0.0
var offended := 0.0
var disgust := 0.0
var banner := ""
var banner_time := 0.0
var particles: Array[Dictionary] = []
var popups: Array[Dictionary] = []

# Round state. _start_round resets these before simulation advances.
var remaining := ROUND_LENGTH
var spawn_in := 0.9
var last_second := 60
var score := 0
var catches := 0
var misses := 0
var throws := 0
var burnt_eaten := 0
var golden_bonus := 0
var rare_spawn_times: Array[float] = []
var sweep_pending := false
var sweep_time := 0.0
var sweep_origin := Vector2.ZERO
var streak := 0
var longest := 0
var old_best := 0
var nuggets: Array[Nugget] = []
var hands: Array[Dictionary] = []
var random := RandomNumberGenerator.new()

# Persisted preferences and window restoration state.
var best := 0
var master_volume := 1.0
var music_volume := 0.55
var sfx_volume := 0.7
var selected_track := 0
var shuffle_music := true
var fullscreen := false
var windowed_size := Vector2i(1280, 720)
var windowed_position := Vector2i.ZERO

# Harnesses set this before entering the tree; previews may temporarily enable audio.
var test_mode := false:
	set(value):
		test_mode = value
		if is_instance_valid(audio):
			audio.playback_enabled = not value

@onready var audio: GameAudio = $Audio


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frame_layer := CanvasLayer.new()
	frame_layer.layer = 10
	add_child(frame_layer)
	frame_layer.add_child(display_layout)
	get_viewport().size_changed.connect(_update_display_layout)
	_update_display_layout()
	random.randomize()
	title_snack_rng.randomize()
	title_snack_wait = title_snack_rng.randf_range(5.0, 6.0)
	room.choose_next()
	var smoke_requested := "--smoke-test" in OS.get_cmdline_user_args()
	test_mode = test_mode or smoke_requested
	platform.detect_browser_features()
	_load_settings()
	# Browser fullscreen requires a fresh user gesture, never a saved preference.
	if platform.web or not platform.supports_fullscreen():
		fullscreen = false
	if cat_art.load_assets() != OK:
		get_tree().quit(1)
		return
	if dance_art.load_assets(null, "res://assets/cat_dance_sprite.json") != OK:
		get_tree().quit(1)
		return
	if disgust_art.load_assets(null, "res://assets/cat_disgust_sprite.json") != OK:
		get_tree().quit(1)
		return
	for stage in range(1, 4):
		var texture := nugget_tex if stage == 3 else nugget_bite_tex
		var mask := BitMap.new()
		mask.create_from_image_alpha(texture.get_image().get_region(Rect2i(_nugget_region("big", 0, stage))))
		boss_masks.append(mask)
	cat_palettes = cat_art.palettes
	_select_cat(_random_choice(-1, cat_palettes.size()))
	windowed_size = get_window().size
	windowed_position = get_window().position
	if fullscreen and not test_mode:
		get_window().mode = Window.MODE_FULLSCREEN
	_setup_audio()
	if smoke_requested:
		load("res://tools/test_smoke.gd").run.call_deferred(self)
	queue_redraw()

func _setup_audio() -> void:
	audio.playback_enabled = not test_mode and not platform.web
	_set_volumes()
	_select_track(_random_choice(-1, TRACKS.size()) if shuffle_music else selected_track)

func _random_choice(current: int, count: int) -> int:
	# Every other choice is equally likely; no immediate repeats.
	if count == 1:
		return 0
	if current < 0:
		return random.randi_range(0, count - 1)
	return (current + random.randi_range(1, count - 1)) % count

func _select_cat(index: int) -> void:
	cat_palette = index
	cat_tex = cat_art.texture_for_palette(index)
	dance_tex = dance_art.texture_for_palette(index)
	disgust_tex = disgust_art.texture_for_palette(index)
	cat_name_index = _random_choice(cat_name_index, CAT_NAMES.size())

func _select_track(index: int) -> void:
	selected_track = posmod(index, TRACKS.size())
	var rate := _difficulty_at(ROUND_LENGTH - remaining).music_rate if state in [Screen.PLAYING, Screen.PAUSED] else 1.0
	audio.select_track(TRACKS[selected_track], rate, state == Screen.PAUSED)

func _difficulty_at(elapsed: float) -> Difficulty:
	return Difficulty.at_time(elapsed)

func _set_music_rate(rate: float) -> void:
	audio.set_rate(rate)

func _start_panic_music() -> void:
	audio.start_finale()

# ---- Window and screen transitions. ----

func _update_display_layout() -> void:
	var size := get_viewport_rect().size
	display_layout.configure(size, DisplayLayout.device_safe_rect(size))
	position = display_layout.play_rect.position
	scale = Vector2.ONE * (display_layout.play_rect.size.x / 640)
	if state == Screen.PLAYING:
		_pause()
	else:
		active_touch = -1
		volume_drag = -1
	queue_redraw()

func _toggle_fullscreen() -> void:
	if not platform.supports_fullscreen():
		return
	var window := get_window()
	fullscreen = window.mode not in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	# A resize changes pointer coordinates; pause first to avoid accidental catches.
	if state == Screen.PLAYING:
		_pause()
	if fullscreen:
		windowed_size = window.size
		windowed_position = window.position
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		if not platform.web:
			window.size = windowed_size
			window.position = windowed_position
	_save_settings()

func _change_screen(next_screen: ScreenLayout.Screen) -> void:
	state = next_screen
	volume_drag = -1
	active_touch = -1
	touch_target = cat
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if state == Screen.PLAYING else Input.MOUSE_MODE_VISIBLE
	queue_redraw()


func _open_overlay(screen: ScreenLayout.Screen) -> void:
	previous_state = state
	_change_screen(screen)
	if screen == Screen.SETTINGS:
		_set_music_rate(1.0)
		audio.resume_music()
		audio.stop_finale()


func _close_overlay() -> void:
	_change_screen(previous_state)
	_set_music_rate(_difficulty_at(ROUND_LENGTH - remaining).music_rate if state == Screen.PAUSED else 1.0)
	if state == Screen.PAUSED:
		audio.pause()
	else:
		audio.resume_music()
	_save_settings()

func _sound(key: String, pitch: float = 1.0) -> void:
	audio.play_effect(key, pitch)

func _set_volumes() -> void:
	audio.set_volumes(master_volume, music_volume, sfx_volume)

# ---- Persistence. Test mode never reads or writes the player's save. ----

func _load_settings(path: String = SAVE_PATH) -> void:
	if test_mode and path == SAVE_PATH:
		return
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		best = maxi(0, int(cfg.get_value("game", "best", 0)))
		master_volume = clampf(float(cfg.get_value("audio", "master", 1.0)), 0, 1)
		music_volume = clampf(float(cfg.get_value("audio", "music", 0.55)), 0, 1)
		sfx_volume = clampf(float(cfg.get_value("audio", "effects", 0.7)), 0, 1)
		selected_track = clampi(int(cfg.get_value("audio", "track", 0)), 0, TRACKS.size() - 1)
		shuffle_music = bool(cfg.get_value("audio", "shuffle", true))
		fullscreen = bool(cfg.get_value("display", "fullscreen", false))

func _save_settings(path: String = SAVE_PATH) -> void:
	if test_mode and path == SAVE_PATH:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", best)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "effects", sfx_volume)
	cfg.set_value("audio", "track", selected_track)
	cfg.set_value("audio", "shuffle", shuffle_music)
	cfg.set_value("display", "fullscreen", fullscreen)
	var error := cfg.save(path)
	if error != OK:
		push_warning("Could not save settings: %s" % error_string(error))

# ---- Input and UI actions. ----

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == Screen.PLAYING:
		_pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_settings()

func _input(event: InputEvent) -> void:
	# Touch has its own offset and UI routing; synthetic mouse events must not
	# double-activate buttons or pull the mouth back underneath the finger.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if platform.web and not browser_audio_started and (
			(event is InputEventMouseButton and event.pressed)
			or (event is InputEventKey and event.pressed and not event.echo)
			or (event is InputEventScreenTouch and event.pressed)):
		browser_audio_started = true
		audio.playback_enabled = not test_mode
		audio.restart_music()
	if display_layout.portrait:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch(make_input_local(event))
		return
	if event is InputEventMouse:
		if active_touch >= 0:
			return
		if (event is InputEventMouseMotion and not event.relative.is_zero_approx()) or (event is InputEventMouseButton and event.pressed):
			touch_mode = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and volume_drag >= 0:
			volume_drag = -1
			_save_settings()
			return
		if event.pressed and state == Screen.SETTINGS:
			for i in range(3):
				if _volume_slider_rect(i).grow(5).has_point(get_local_mouse_position()):
					volume_drag = i
					_drag_volume(get_local_mouse_position().x)
					return
	if event is InputEventMouseMotion and volume_drag >= 0:
		_drag_volume(get_local_mouse_position().x)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("toggle_fullscreen", false, true):
			if not platform.web or event.keycode != KEY_F11:
				_toggle_fullscreen()
		elif event.is_action_pressed("back", false, true):
			if state == Screen.TITLE:
				_handle_action("quit")
			elif state == Screen.PLAYING:
				_pause()
			elif state == Screen.PAUSED:
				_resume()
			elif state in [Screen.SETTINGS, Screen.GUIDE, Screen.SOURCES]:
				_close_overlay()
		elif event.is_action_pressed("confirm", false, true):
			if state in [Screen.TITLE, Screen.RESULTS]:
				_start_round()
			elif state == Screen.PAUSED:
				_resume()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_activate_button_at(get_local_mouse_position())

func _handle_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.canceled or not event.pressed:
			if event.index == active_touch:
				active_touch = -1
				if volume_drag >= 0:
					volume_drag = -1
					_save_settings()
			return
		var in_game := Rect2(0, 0, 640, 360).has_point(event.position)
		var in_drag_margin := state == Screen.PLAYING and display_layout.bottom_drag_contains(event.position)
		if active_touch >= 0 or not (in_game or in_drag_margin):
			return
		touch_mode = true
		active_touch = event.index
		if state == Screen.SETTINGS:
			for i in range(3):
				if _volume_slider_rect(i).grow(5).has_point(event.position):
					volume_drag = i
					_drag_volume(event.position.x)
					return
		var action := ScreenLayout.action_at(state, event.position, platform.can_quit(), platform.supports_fullscreen())
		if not action.is_empty():
			_handle_action(action)
		elif state == Screen.PLAYING:
			touch_target = (event.position + TOUCH_MOUTH_OFFSET).clamp(CAT_MIN, CAT_MAX)
	elif event is InputEventScreenDrag and event.index == active_touch:
		if volume_drag >= 0:
			_drag_volume(event.position.x)
		elif state == Screen.PLAYING:
			touch_target = (event.position + TOUCH_MOUTH_OFFSET).clamp(CAT_MIN, CAT_MAX)


func _cat_input_position() -> Vector2:
	return touch_target if touch_mode else get_local_mouse_position().clamp(CAT_MIN, CAT_MAX)


func _update_cat_motion(delta: float) -> void:
	cat_previous = cat
	cat = _cat_input_position()
	var velocity := (cat - cat_previous) / maxf(delta, 0.001)
	cat_velocity = cat_velocity.lerp(velocity, 1.0 - exp(-12 * delta))
	tilt = lerpf(tilt, clampf(cat_velocity.x / 2200, -0.24, 0.24), 1.0 - exp(-14 * delta))


func _activate_button_at(pointer: Vector2) -> void:
	var action := ScreenLayout.action_at(state, pointer, platform.can_quit(), platform.supports_fullscreen())
	if not action.is_empty():
		_handle_action(action)


func _handle_action(action: String) -> void:
	if not platform.allows_action(action):
		return
	_sound("catch", 0.8)
	match action:
		"start": _start_round()
		"resume": _resume()
		"pause": _pause()
		"home":
			_change_screen(Screen.TITLE)
			_set_music_rate(1.0)
			title_cat_selected = false
			audio.stop_finale()
			audio.resume_music()
		"cat_shuffle":
			if state == Screen.TITLE:
				_select_cat(_random_choice(cat_palette, cat_palettes.size()))
				title_cat_selected = true
				expression = 0.42
		"settings":
			_open_overlay(Screen.SETTINGS)
		"guide":
			_open_overlay(Screen.GUIDE)
		"sources":
			_open_overlay(Screen.SOURCES)
		"source_488472", "source_162395", "source_449868":
			if not test_mode:
				OS.shell_open("https://freesound.org/s/" + action.trim_prefix("source_") + "/")
		"source_license":
			if not test_mode:
				OS.shell_open("https://creativecommons.org/publicdomain/zero/1.0/")
		"back": _close_overlay()
		"fullscreen": _toggle_fullscreen()
		"track_prev", "track_next":
			shuffle_music = false
			_select_track(selected_track + (1 if action == "track_next" else -1))
		"shuffle":
			shuffle_music = not shuffle_music
			if shuffle_music:
				_select_track(_random_choice(selected_track, TRACKS.size()))
		"master_down": master_volume = maxf(0, master_volume - 0.1)
		"master_up": master_volume = minf(1, master_volume + 0.1)
		"music_down": music_volume = maxf(0, music_volume - 0.1)
		"music_up": music_volume = minf(1, music_volume + 0.1)
		"sfx_down": sfx_volume = maxf(0, sfx_volume - 0.1)
		"sfx_up": sfx_volume = minf(1, sfx_volume + 0.1)
		"quit":
			_save_settings()
			get_tree().quit()
	if action in ["master_down", "master_up", "music_down", "music_up", "sfx_down", "sfx_up"]:
		_set_volumes()
	queue_redraw()

func _volume_slider_rect(index: int) -> Rect2:
	return ScreenLayout.volume_slider_rect(index)

func _drag_volume(pointer_x: float) -> void:
	var slider := _volume_slider_rect(volume_drag)
	var value := clampf((pointer_x - slider.position.x) / slider.size.x, 0, 1)
	match volume_drag:
		0: master_volume = value
		1: music_volume = value
		2: sfx_volume = value
	_set_volumes()
	queue_redraw()

# ---- Round lifecycle and simulation. ----

func _start_round() -> void:
	_change_screen(Screen.PLAYING)
	round_phase = RoundPhase.CATCHING
	boss_hp = BOSS_BITES
	boss_age = 0.0
	boss_pos = Vector2(320, 190)
	boss_contact = 0.0
	boss_gap = 0.0
	boss_bite_progress = 0.0
	boss_defeated = false
	celebration_time = 0.0
	boss_warning_second = 4
	room.choose_next()
	remaining = ROUND_LENGTH
	_set_music_rate(1.0)
	if not title_cat_selected:
		_select_cat(_random_choice(cat_palette, cat_palettes.size()))
	title_cat_selected = false
	if shuffle_music:
		_select_track(_random_choice(selected_track, TRACKS.size()))
	score = 0
	catches = 0
	misses = 0
	throws = 0
	burnt_eaten = 0
	golden_bonus = 0
	sweep_pending = false
	sweep_time = 0.0
	_plan_rare_spawns()
	streak = 0
	longest = 0
	old_best = best
	spawn_in = 0.25
	expression = 0
	offended = 0
	disgust = 0
	nuggets.clear()
	hands.clear()
	particles.clear()
	popups.clear()
	touch_target = Vector2(320, 180)
	cat = _cat_input_position()
	cat_previous = cat
	cat_velocity = Vector2.ZERO
	banner = "FOLLOW YOUR APPETITE!"
	banner_time = 2.0
	last_second = 60
	audio.stop_finale()
	audio.resume_music()
	if not shuffle_music:
		audio.restart_music()

func _pause() -> void:
	_change_screen(Screen.PAUSED)
	audio.pause()

func _resume() -> void:
	_change_screen(Screen.PLAYING)
	_set_music_rate(_difficulty_at(ROUND_LENGTH - remaining).music_rate)
	cat = _cat_input_position()
	cat_previous = cat
	audio.resume_music()
	if round_phase == RoundPhase.BOSS:
		_start_panic_music()

func _finish_round() -> void:
	_change_screen(Screen.RESULTS)
	results_time = 0.0
	expression = 0.0
	remaining = 0
	best = maxi(best, score)
	_save_settings()
	audio.stop_finale()
	_set_music_rate(1.0)
	_sound("finish")

func _process(delta: float) -> void:
	if test_mode:
		return
	if platform.web:
		var actual_fullscreen := get_window().mode == Window.MODE_FULLSCREEN
		if actual_fullscreen != fullscreen:
			fullscreen = actual_fullscreen
			if state == Screen.PLAYING:
				_pause()
	clock += delta
	if state == Screen.PLAYING:
		_update_cat_motion(delta)
		_step(delta)
	elif state == Screen.TITLE:
		expression = maxf(0, expression - delta)
		_update_title_snack(delta)
	elif state == Screen.RESULTS:
		results_time += delta
	queue_redraw()

func _step(delta: float) -> void:
	if state != Screen.PLAYING:
		return
	if round_phase == RoundPhase.CELEBRATING:
		celebration_time += delta
		_update_effects(delta)
		if celebration_time >= 3.0:
			_finish_round()
		return
	# Split exactly at the phase boundary, including long frames.
	if round_phase == RoundPhase.CATCHING and remaining - delta <= BOSS_DURATION:
		var ordinary_time := maxf(0.0, remaining - BOSS_DURATION)
		if ordinary_time > 0:
			_step_catching(ordinary_time)
		remaining = minf(remaining, BOSS_DURATION)
		_start_boss()
		_step(maxf(0.0, delta - ordinary_time))
		return
	if round_phase == RoundPhase.BOSS:
		_step_boss(delta)
		return
	_step_catching(delta)

func _step_catching(delta: float) -> void:
	remaining = maxf(0, remaining - delta)
	if remaining <= 0:
		_finish_round()
		return
	var difficulty := _difficulty_at(ROUND_LENGTH - remaining)
	_set_music_rate(difficulty.music_rate)
	_update_round_feedback(delta)
	_update_spawning(delta, difficulty.throw_interval)
	_update_hands(delta)
	_update_nuggets(delta)
	# Collection must run after collision iteration to avoid invalidating indices.
	if sweep_pending:
		_collect_flying_nuggets()
	_update_effects(delta)


func _update_round_feedback(delta: float) -> void:
	expression = maxf(0, expression - delta)
	offended = maxf(0, offended - delta)
	disgust = maxf(0, disgust - delta)
	banner_time = maxf(0, banner_time - delta)
	sweep_time = maxf(0, sweep_time - delta)
	if round_phase == RoundPhase.CATCHING and remaining <= BOSS_DURATION + BOSS_WARNING:
		var warning_second := ceili(remaining - BOSS_DURATION)
		if warning_second > 0 and warning_second < boss_warning_second:
			boss_warning_second = warning_second
			_sound("combo", 0.65 + (3 - warning_second) * 0.15)
	if ceili(remaining) < last_second:
		last_second = ceili(remaining)
		if remaining <= 10:
			_sound("tick", 1.0 + (10 - remaining) * 0.025)


func _update_spawning(delta: float, throw_interval: float) -> void:
	if remaining <= BOSS_DURATION + THROW_WIND_DOWN:
		return
	spawn_in -= delta
	if spawn_in <= 0:
		_spawn_hand()
		# Preserve timer overshoot so cadence stays consistent across frame rates.
		spawn_in += throw_interval * random.randf_range(0.92, 1.08)


func _update_hands(delta: float) -> void:
	for i in range(hands.size() - 1, -1, -1):
		var hand: Dictionary = hands[i]
		hand.age += delta
		if hand.age >= HAND_RELEASE_TIME and not hand.released:
			hand.released = true
			_release(hand)
		if hand.age > HAND_LIFETIME:
			hands.remove_at(i)


func _update_nuggets(delta: float) -> void:
	for i in range(nuggets.size() - 1, -1, -1):
		var nugget: Nugget = nuggets[i]
		var previous_position := nugget.pos
		nugget.age += delta
		nugget.bite_wait = maxf(0, nugget.bite_wait - delta)
		nugget.vel.y += nugget.gravity * delta
		nugget.pos += nugget.vel * delta
		nugget.rotation += nugget.spin * delta
		# Swept relative motion prevents tunneling during fast mouse swipes.
		if (disgust <= 0 or nugget.kind == "burnt") and _swept_catch(previous_position, nugget.pos, cat_previous, cat, NUGGET_TYPES[nugget.kind].radius):
			if _chomp(nugget):
				nuggets.remove_at(i)
				_eat_nugget(nugget)
		elif nugget.pos.x < -24 or nugget.pos.x > 664 or nugget.pos.y > 390 or nugget.pos.y < -100:
			if nugget.kind != "burnt":
				_miss()
			nuggets.remove_at(i)


func _update_effects(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p.life -= delta
		p.vel.y += 100 * delta
		p.pos += p.vel * delta
		if p.life <= 0:
			particles.remove_at(i)
	for i in range(popups.size() - 1, -1, -1):
		popups[i].life -= delta
		popups[i].pos.y -= 20 * delta
		if popups[i].life <= 0:
			popups.remove_at(i)

func _swept_catch(nugget_before: Vector2, nugget_after: Vector2,
		mouth_before: Vector2, mouth_after: Vector2, radius: float = CATCH_RADIUS) -> bool:
	var start := nugget_before - mouth_before
	var end := nugget_after - mouth_after
	return Geometry2D.get_closest_point_to_segment(Vector2.ZERO, start, end).length_squared() <= radius * radius

func _plan_rare_spawns() -> void:
	rare_spawn_times.clear()
	if random.randf() < BIG_GOLD_ROUND_CHANCE:
		rare_spawn_times.append(random.randf_range(18, 34))
		if random.randf() < SECOND_BIG_GOLD_CHANCE:
			rare_spawn_times.append(random.randf_range(36, 38))

func _start_boss() -> void:
	round_phase = RoundPhase.BOSS
	nuggets.clear()
	hands.clear()
	rare_spawn_times.clear()
	sweep_pending = false
	sweep_time = 0.0
	popups.clear()
	banner = "BOSS NUGGET! HOLD YOUR MOUTH ON IT!"
	banner_time = 2.0
	_sound("combo", 0.65)
	_start_panic_music()

func _boss_position(age: float) -> Vector2:
	# Analytic reflected motion cannot overshoot a wall, even on a long frame.
	var travel := Vector2(320, 190) - BOSS_BOUNDS.position + BOSS_VELOCITY * age
	return BOSS_BOUNDS.position + Vector2(pingpong(travel.x, BOSS_BOUNDS.size.x), pingpong(travel.y, BOSS_BOUNDS.size.y))

func _step_boss(delta: float) -> void:
	var elapsed := 0.0
	# Small simulation slices integrate contact and bite speed independently of FPS.
	while elapsed < delta and round_phase == RoundPhase.BOSS:
		var dt := minf(1.0 / 240.0, minf(delta - elapsed, remaining))
		if dt <= 0.0:
			_finish_round()
			return
		elapsed += dt
		boss_age += dt
		boss_pos = _boss_position(boss_age)
		var mouth := cat_previous.lerp(cat, elapsed / delta)
		if disgust <= 0 and _boss_contains_mouth(mouth):
			boss_gap = 0.0
			var before := boss_contact
			boss_contact = minf(3.0, boss_contact + dt)
			boss_bite_progress += dt * (3.0 + 5.0 * (before + boss_contact) / 6.0)
			while boss_bite_progress >= 1.0 and boss_hp > 0:
				boss_bite_progress -= 1.0
				boss_hp -= 1
				expression = 0.42
				_sound("catch", 0.8 + boss_contact * 0.15)
				for i in range(3):
					particles.append({"pos": boss_pos, "vel": Vector2(random.randf_range(-65, 65), random.randf_range(-80, -20)), "life": 0.5, "size": 3, "color": GOLD})
		else:
			var old_gap := boss_gap
			boss_gap += dt
			boss_contact = maxf(0.0, boss_contact - 2.0 * (maxf(0.0, boss_gap - 0.25) - maxf(0.0, old_gap - 0.25)))
			boss_bite_progress = 0.0
		remaining = maxf(0.0, remaining - dt)
		_update_round_feedback(dt)
		_update_effects(dt)
		if boss_hp == 0:
			boss_defeated = true
			round_phase = RoundPhase.CELEBRATING
			score += BOSS_BONUS
			_sound("reaction_yay")
			banner_time = 0.0
		elif remaining <= 0.0:
			_finish_round()
			return
	_set_music_rate(_difficulty_at(ROUND_LENGTH - remaining).music_rate)

func _next_nugget_kind() -> String:
	var elapsed := ROUND_LENGTH - remaining
	if not rare_spawn_times.is_empty() and elapsed >= rare_spawn_times[0]:
		rare_spawn_times.remove_at(0)
		return "big_golden"
	var roll := random.randf()
	var threshold := 0.0
	for kind in ["big", "burnt", "golden"]:
		threshold += NUGGET_TYPES[kind].chance / 100.0
		if roll < threshold:
			return kind if elapsed >= NUGGET_TYPES[kind].unlock else "regular"
	return "regular"

func _spawn_hand() -> void:
	var edge := random.randi_range(0, 2)
	var position: Vector2
	var angle: float
	if edge == 0:
		position = Vector2(28, random.randf_range(120, 275))
		angle = 0
	elif edge == 1:
		position = Vector2(612, random.randf_range(120, 275))
		angle = PI
	else:
		position = Vector2(random.randf_range(120, 520), 66)
		angle = PI / 2
	var kind := _next_nugget_kind()
	hands.append({"pos": position, "angle": angle, "age": 0.0, "released": false, "edge": edge, "kind": kind, "variant": random.randi_range(0, 1) if kind == "regular" else 0})
	if kind == "big_golden":
		banner = "RARE BIG GOLDEN! THREE CHOMPS!"
		banner_time = 1.5
		_sound("combo", 0.85)

func _release(hand: Dictionary) -> void:
	throws += 1
	var origin: Vector2 = hand.pos + HAND_GRIPS[2].rotated(hand.angle)
	var kind: String = hand.get("kind", "regular")
	var target := Vector2(random.randf_range(210, 430), random.randf_range(160, 270))
	var flight := _difficulty_at(ROUND_LENGTH - remaining).flight_time
	if NUGGET_TYPES[kind].hp == 3:
		flight *= 1.18
	var gravity := 155.0
	var velocity := (target - origin) / flight - Vector2(0, gravity * flight * 0.5)
	nuggets.append(_make_nugget(kind, origin, velocity, gravity, hand.get("variant", 0)))
	_sound("throw", random.randf_range(0.85, 1.2))

func _make_nugget(kind: String, position: Vector2, velocity: Vector2 = Vector2.ZERO, gravity: float = 155.0, variant: int = 0) -> Nugget:
	return Nugget.new(kind, NUGGET_TYPES[kind].hp, position, velocity, gravity,
		variant, random.randf_range(-PI, PI), random.randf_range(-3, 3))

func _chomp(nugget: Nugget) -> bool:
	if disgust > 0 and nugget.kind != "burnt":
		return false
	if nugget.bite_wait > 0:
		return false
	nugget.hp -= 1
	if nugget.hp == 0:
		return true
	nugget.bite_wait = CHOMP_INTERVAL
	nugget.vel *= 0.72
	expression = 0.34
	_sound("catch", 0.7 + (3 - nugget.hp) * 0.1)
	popups.append({"pos": nugget.pos + Vector2(0, -29), "text": "%d CHOMPS LEFT" % nugget.hp, "life": 0.4, "color": CREAM})
	return false

func _eat_nugget(nugget: Nugget, allow_sweep: bool = true) -> void:
	var kind: String = nugget.kind
	if kind == "burnt":
		var penalty := mini(30, score)
		score -= penalty
		burnt_eaten += 1
		streak = 0
		golden_bonus = 0
		expression = 0
		disgust = BURNT_COOLDOWN
		offended = BURNT_COOLDOWN
		_sound("reaction_eww")
		popups.append({"pos": nugget.pos + Vector2(0, -28), "text": "YUCK! -%d" % penalty, "life": 1.0, "color": PINK})
		return
	_catch(nugget.pos, NUGGET_TYPES[kind].points)
	# The collection wave scores its catches silently on the vocal channel,
	# preserving the big golden's cheer rather than stacking a chorus.
	if allow_sweep:
		if kind in ["golden", "big_golden"]:
			_sound("reaction_yay")
		elif kind == "big":
			_sound("reaction_nom")
	if kind == "golden":
		golden_bonus = mini(4, golden_bonus + 1)
		banner = "GOLDEN BOOST! X%d" % _multiplier()
		banner_time = 1.3
		_sound("combo")
	elif kind == "big_golden" and allow_sweep:
		sweep_pending = true
		sweep_origin = nugget.pos

func _collect_flying_nuggets() -> void:
	# Deferred until the collision pass ends: never mutate the active iteration.
	# A burnt bite in the same pass delays an already-earned golden sweep.
	if disgust > 0:
		return
	sweep_pending = false
	sweep_time = 0.65
	for i in range(nuggets.size() - 1, -1, -1):
		if nuggets[i].kind != "burnt":
			var nugget: Nugget = nuggets[i]
			nuggets.remove_at(i)
			_eat_nugget(nugget, false)
	banner = "GOLDEN FEAST! EDIBLES COLLECTED!"
	banner_time = 1.8
	_sound("finish", 1.1)

func _multiplier() -> int:
	return mini(5, 1 + floori(streak / 5.0) + golden_bonus)

func _catch(position: Vector2, base_points: int = 10) -> void:
	var earned := base_points * _multiplier()
	score += earned
	catches += 1
	streak += 1
	longest = maxi(longest, streak)
	expression = 0.42
	offended = 0
	popups.append({"pos": position + Vector2(0, -27), "text": "+%d" % earned, "life": 0.7, "color": GOLD})
	_sound("catch", 1.0 + mini(streak, 20) * 0.018)
	for i in range(9):
		particles.append({"pos": position, "vel": Vector2(random.randf_range(-80, 80), random.randf_range(-100, 15)), "life": random.randf_range(0.25, 0.6), "color": GOLD if i % 2 == 0 else CREAM, "size": random.randi_range(2, 3)})
	if streak % 5 == 0:
		_sound("combo")
		var messages := ["EXCELLENT SNACKING!", "ABSOLUTE NUGGET UNIT!", "NO THOUGHTS. JUST NUGGETS.", "TRANSCENDENT CHICKEN!"]
		banner = messages[mini(3, floori(streak / 5.0) - 1)]
		banner_time = 1.4
		for i in range(12):
			particles.append({"pos": position, "vel": Vector2(random.randf_range(-110, 110), random.randf_range(-130, 20)), "life": 0.85, "color": PINK if i % 2 else MINT, "size": 4})

func _miss() -> void:
	misses += 1
	streak = 0
	golden_bonus = 0
	offended = 0.7
	_sound("miss", 0.95)

# ---- Presentation: a hand-drawn pixel kitchen, sprites, and bitmap UI. ----

func _text(value: String, position: Vector2, size: int = 8, color: Color = CREAM, centered: bool = false) -> void:
	var x := position.x
	if centered:
		x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2
	draw_string(font, Vector2(roundf(x), roundf(position.y + size)), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _panel(rect: Rect2, color: Color = INK) -> void:
	draw_rect(Rect2(rect.position + Vector2(0, 4), rect.size), Color("302636"))
	draw_rect(rect, color)
	draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), Color("fce8c4"), false, 1)

func _button(label: String, action: String, primary: bool = false) -> void:
	if not platform.allows_action(action):
		return
	var rect := ScreenLayout.button_rect(state, action)
	var hover := rect.has_point(get_local_mouse_position())
	var color := GOLD if primary else Color("65536b")
	if hover:
		color = MINT if primary else Color("89718a")
	draw_rect(Rect2(rect.position + Vector2(0, 3), rect.size), Color("302636"))
	draw_rect(rect, color)
	draw_rect(Rect2(rect.position + Vector2(1, 1), rect.size - Vector2(2, 2)), CREAM if hover else color.lightened(0.18), false)
	_text(label, rect.position + Vector2(rect.size.x / 2, (rect.size.y - 8) / 2 - 1), 8, INK if primary else CREAM, true)

func _fullscreen_button() -> void:
	if not platform.supports_fullscreen():
		return
	_button("", "fullscreen")
	var center := ScreenLayout.button_rect(state, "fullscreen").get_center()
	# Four pixel corners point outward to expand, inward to restore the window.
	for x in [-1, 1]:
		for y in [-1, 1]:
			var corner := center + Vector2(x, y) * (3 if fullscreen else 7)
			var direction := 1 if fullscreen else -1
			draw_polyline(PackedVector2Array([
				corner + Vector2(x * direction * 5, 0),
				corner,
				corner + Vector2(0, y * direction * 5),
			]), CREAM, 2)

func _draw() -> void:
	if cat_tex == null:
		return
	room.draw(self)
	if state == Screen.TITLE:
		_title()
	elif state == Screen.RESULTS:
		_results()
	elif state == Screen.SETTINGS:
		_settings()
	elif state == Screen.GUIDE:
		_nugget_guide()
	elif state == Screen.SOURCES:
		_sources()
	else:
		_playfield()
		if state == Screen.PAUSED:
			draw_rect(Rect2(0, 0, 640, 360), Color(0.16, 0.12, 0.20, 0.7))
			_panel(Rect2(206, 63, 228, 258))
			_text("SNACK BREAK", Vector2(320, 85), 16, GOLD, true)
			_text("YOUR NUGGETS CAN WAIT.", Vector2(320, 115), 8, CREAM, true)
			_button("KEEP MUNCHING", "resume", true)
			_button("SETTINGS", "settings")
			_button("NUGGET GUIDE", "guide")
			_button("BACK TO TITLE", "home")
			_text("ESC TO RESUME", Vector2(320, 299), 8, MINT, true)

func _cat_sprite(position: Vector2, frame: int, scale_factor: float = 1.5, angle: float = 0.0, pose_scale: Vector2 = Vector2.ONE, reacting: bool = false) -> void:
	var stretch := 1.0 + minf(cat_velocity.length() / 10000, 0.14) if state == Screen.PLAYING else 1.0
	if expression > 0.30:
		stretch += 0.10
	draw_set_transform(position, angle, Vector2(scale_factor / stretch, scale_factor * stretch) * pose_scale)
	# Atlas and mouth anchor come from sprite metadata; catch position stays stable.
	if reacting:
		draw_texture_rect_region(disgust_tex, disgust_art.draw_rect(), disgust_art.frame_rect(_disgust_frame()))
	else:
		draw_texture_rect_region(cat_tex, cat_art.draw_rect(), cat_art.frame_rect(frame))
	draw_set_transform(Vector2.ZERO)

func _disgust_frame() -> int:
	# Two wince/spit/recovery cycles during the cooldown; simulation time freezes
	# on pause and a fresh burnt bite restarts the reaction at its first pose.
	var elapsed := clampf(BURNT_COOLDOWN - disgust, 0, BURNT_COOLDOWN)
	return mini(floori(elapsed * 8.0), 15) % disgust_art.frame_count

func _cat_frame() -> int:
	if disgust > 0:
		return 5
	# Rapid boss bites reset `expression` before its closed-mouth threshold.
	# Follow the bite phase instead so both poses remain visible at 8 chomps/sec.
	if round_phase == RoundPhase.BOSS and boss_contact > 0 and boss_gap == 0:
		return 2 if boss_bite_progress >= 0.5 else 3
	if expression > 0.26:
		return 6 if streak >= 10 else 2
	if expression > 0:
		return 3
	if offended > 0:
		return 5
	if fmod(clock, 4.2) < 0.15:
		return 1
	return 6 if streak >= 15 else 0

func _nugget_region(kind: String, variant: int = 0, hp: int = 3) -> Rect2:
	if kind in ["big", "big_golden"] and hp < 3:
		var bite_frame := (2 if kind == "big_golden" else 0) + (2 - clampi(hp, 1, 2))
		return Rect2(bite_frame * 32, 0, 32, 32)
	var frame: int = NUGGET_TYPES[kind].frame + (variant if kind == "regular" else 0)
	return Rect2(frame * 32, 0, 32, 32)

func _golden_glitter(n: Nugget, size: float) -> void:
	# Staggered glints grow and shrink in whole pixels. Simulation age freezes
	# them on pause, and deterministic phases leave gameplay randomness alone.
	var big: bool = n.kind == "big_golden"
	var count := 5 if big else 3
	for i in range(count):
		var phase := fposmod(float(n.age) * 1.7 + i * 0.37 + float(n.spin) * 0.13, 1.0)
		var pulse := maxf(0.0, 1.0 - absf(phase - 0.5) / 0.36)
		if pulse <= 0:
			continue
		var angle := i * 2.4 + float(n.rotation)
		var radius := size * (0.24 if i % 2 == 0 else 0.51)
		var center: Vector2 = (n.pos + Vector2.RIGHT.rotated(angle) * radius).round()
		var arm := 1 + floori(pulse * (4 if big else 3))
		var warm := Color(1.0, 0.76, 0.22, pulse * 0.85)
		var shine := Color(1.0, 0.98, 0.78, pulse)
		# Gold shoulders and a cream-white cross keep the shine crisp at 1x.
		draw_rect(Rect2(center - Vector2(2, 2), Vector2(5, 5)), warm)
		draw_rect(Rect2(center - Vector2(arm, 0), Vector2(arm * 2 + 1, 1)), shine)
		draw_rect(Rect2(center - Vector2(0, arm), Vector2(1, arm * 2 + 1)), shine)
		if pulse > 0.7:
			draw_rect(Rect2(center - Vector2.ONE, Vector2(3, 3)), shine)

func _draw_flying_nugget(n: Nugget) -> void:
	var kind: String = n.kind
	var spec: Dictionary = NUGGET_TYPES[kind]
	var size: float = spec.size
	var golden := kind in ["golden", "big_golden"]
	var texture := nugget_bite_tex if spec.hp == 3 and n.hp < 3 else nugget_tex
	var sprite_rect := Rect2(Vector2.ONE * (-size / 2), Vector2.ONE * size)
	var region := _nugget_region(kind, n.variant, n.hp)
	if golden:
		draw_circle(n.pos, size * 0.65, Color(1, 0.85, 0.25, 0.18))
	# The shadow loses the same chunks as the sprite, rather than filling its bite holes.
	draw_set_transform(n.pos + Vector2(3, 7), n.rotation)
	draw_texture_rect_region(texture, sprite_rect, region, Color(0.25, 0.22, 0.25, 0.12))
	draw_set_transform(n.pos, n.rotation)
	draw_texture_rect_region(texture, sprite_rect, region)
	draw_set_transform(Vector2.ZERO)
	if golden:
		_golden_glitter(n, size)
	if spec.hp == 3:
		for i in range(3):
			var dot: Vector2 = n.pos + Vector2((i - 1) * 7, -size / 2 - 5)
			draw_rect(Rect2(dot - Vector2(2, 2), Vector2(5, 5)), INK)
			draw_rect(Rect2(dot - Vector2.ONE, Vector2(3, 3)), GOLD if i < n.hp else Color("756475"))
	elif kind == "burnt":
		for i in range(2):
			var smoke: Vector2 = n.pos + Vector2(sin(clock * 4 + i) * 4, -14 - fmod(clock * 12 + i * 8, 17))
			draw_rect(Rect2(smoke, Vector2(3, 3)), Color(0.35, 0.28, 0.32, 0.45))
		_text("X", n.pos + Vector2(10, -18), 8, INK, true)
		_text("X", n.pos + Vector2(10, -19), 8, PINK, true)

func _playfield() -> void:
	for hand in hands:
		var age: float = hand.age
		var direction := Vector2.RIGHT.rotated(hand.angle)
		var slide := clampf(age / 0.18, 0, 1) * clampf((HAND_LIFETIME - age) / 0.2, 0, 1)
		var pos: Vector2 = hand.pos - direction * (1.0 - slide) * 58
		draw_set_transform(pos, hand.angle)
		var frame := 0 if age < 0.4 else (1 if age < HAND_RELEASE_TIME else 2)
		if not hand.released:
			var kind: String = hand.get("kind", "regular")
			var held_size := 24.0 if NUGGET_TYPES[kind].hp == 3 else 16.0
			draw_texture_rect_region(nugget_tex, Rect2(HAND_GRIPS[frame] - Vector2.ONE * held_size / 2, Vector2.ONE * held_size), _nugget_region(kind, hand.get("variant", 0)))
		draw_texture_rect_region(hand_tex, Rect2(-32, -24, 64, 48), Rect2(frame * 64, 0, 64, 48))
		draw_set_transform(Vector2.ZERO)
		if not hand.released and age > 0.3:
			_text("!", pos + direction * 43 + Vector2(0, -8), 16, INK, true)
	for n in nuggets:
		_draw_flying_nugget(n)
	if round_phase == RoundPhase.BOSS:
		_draw_boss()
	if sweep_time > 0:
		var progress := 1.0 - sweep_time / 0.65
		draw_arc(sweep_origin, lerpf(12, 650, progress), 0, TAU, 64, Color(1, 0.88, 0.4, (1 - progress) * 0.7), 3)
	# Ground shadow and trailing paws communicate motion without input lag.
	var shadow_x := 320.0 if round_phase == RoundPhase.CELEBRATING else cat.x
	draw_set_transform(Vector2(shadow_x, 294), 0, Vector2(1, 0.25))
	draw_circle(Vector2.ZERO, 22, Color(0.2, 0.25, 0.23, 0.13))
	draw_set_transform(Vector2.ZERO)
	if round_phase == RoundPhase.CELEBRATING:
		_belly_dance(Vector2(320, 285), celebration_time, 2.0)
		draw_rect(Rect2(185, 64, 270, 28), INK)
		_text("BOSS DEVOURED! +500", Vector2(320, 70), 16, GOLD, true)
	else:
		_cat_sprite(cat, _cat_frame(), 1.5, tilt, Vector2.ONE, disgust > 0)
	# Mouth targeting belongs to gameplay, not the centered victory dance.
	if round_phase != RoundPhase.CELEBRATING:
		for sign_x in [-1, 1]:
			for sign_y in [-1, 1]:
				var p := cat + Vector2(sign_x * 12, sign_y * 9)
				draw_line(p, p + Vector2(-sign_x * 3, 0), Color(1, 0.96, 0.79, 0.65))
	for p in particles:
		draw_rect(Rect2(p.pos, Vector2.ONE * p.size), p.color)
	for popup in popups:
		_text(popup.text, popup.pos + Vector2(1, 1), 8, INK, true)
		_text(popup.text, popup.pos, 8, popup.color, true)
	_hud()
	var warning := round_phase == RoundPhase.CATCHING and remaining <= BOSS_DURATION + BOSS_WARNING and remaining > BOSS_DURATION
	if banner_time > 0 or warning:
		var message := "BOSS IN %d... FINISH YOUR SNACKS!" % ceili(remaining - BOSS_DURATION) if warning else banner
		var width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 28
		draw_rect(Rect2(320 - width / 2, 64, width, 22), INK)
		_text(message, Vector2(320, 70), 8, PINK if warning or round_phase == RoundPhase.BOSS else GOLD, true)

func _hud() -> void:
	draw_rect(Rect2(0, 0, 640, 49), INK)
	draw_rect(Rect2(0, 49, 640, 3), Color("725866"))
	_text("SNACK SCORE", Vector2(16, 8), 8, MINT)
	_text("%05d" % score, Vector2(16, 23), 16)
	_text("COMBO", Vector2(173, 8), 8, MINT)
	if golden_bonus > 0:
		_text("G+%d" % golden_bonus, Vector2(220, 10), 8, GOLD)
	_text("X%d" % _multiplier(), Vector2(173, 24), 16, GOLD)
	for i in range(5):
		draw_rect(Rect2(219 + i * 7, 31, 5, 5), GOLD if i < streak % 5 or _multiplier() == 5 else Color("725866"))
	_text("%02d" % ceili(remaining), Vector2(320, 15), 24, PINK if remaining <= 10 else CREAM, true)
	_text("BEST %05d" % best, Vector2(398, 11), 8, MINT)
	_text("%d CAUGHT" % catches, Vector2(398, 28), 8)
	_button("II", "pause")
	# Bottom prompt sits on the counter.
	_text("DRAG BELOW THE CAT" if touch_mode else "MOUSE TO MUNCH", Vector2(12, 345), 8, INK)
	_text("%s / %s" % [CAT_NAMES[cat_name_index], cat_palettes[cat_palette].name], Vector2(320, 345), 8, INK, true)
	_text("ESC: SNACK BREAK", Vector2(522, 345), 8, INK, true)

func _title_mouth() -> Vector2:
	return Vector2(495, 151 + sin(clock * 2.5) * 4)

func _update_title_snack(delta: float) -> void:
	title_snack_wait -= delta
	if title_snack_wait <= 0 and title_snack == null:
		var kinds := ["regular", "big", "golden", "big_golden"]
		var kind: String = kinds[title_snack_rng.randi_range(0, kinds.size() - 1)]
		var angle := title_snack_rng.randf_range(0.0, TAU)
		var origin := _title_mouth() + Vector2(cos(angle) * 57, sin(angle) * 45)
		title_snack = Nugget.new(kind, 1, origin, Vector2.ZERO, 0,
			title_snack_rng.randi_range(0, 1) if kind == "regular" else 0, 0, angle)
		title_snack_wait = title_snack_rng.randf_range(5.0, 6.0)
	elif title_snack != null:
		title_snack.age += delta
		if title_snack.age >= 1.0:
			title_snack = null
			expression = 0.42
			_sound("catch", 0.95)

func _title() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.21, 0.20, 0.24, 0.16))
	_panel(Rect2(20, 20, 600, 320), Color("423747"))
	_text("A VERY IMPORTANT FEEDING MISSION", Vector2(224, 38), 8, MINT, true)
	_fullscreen_button()
	_text("NUGGET", Vector2(224, 70), 40, GOLD, true)
	_text("CAT", Vector2(224, 119), 40, CREAM, true)
	_text("NO THOUGHTS. JUST CHICKEN.", Vector2(224, 173), 8, PINK, true)
	# Cat portrait on a warm little stage.
	var portrait := ScreenLayout.button_rect(state, "cat_shuffle")
	var hovered := portrait.has_point(get_local_mouse_position())
	draw_rect(portrait, Color("675367"))
	draw_rect(Rect2(422, 81, 145, 132), MINT if hovered else Color("806678"), false, 2)
	var frame := 1 if fmod(clock, 4) < 0.15 else 0
	if title_snack != null and title_snack.age > 0.55:
		frame = 2
	elif expression > 0:
		frame = 2 if expression > 0.26 else 3
	_cat_sprite(_title_mouth(), frame, 2.8, sin(clock * 1.8) * 0.06)
	_text(CAT_NAMES[cat_name_index], Vector2(495, 223), 8, GOLD, true)
	_text("CLICK TO MEET ANOTHER CAT", Vector2(495, 237), 8, MINT if hovered else CREAM, true)
	if title_snack != null:
		# Give the little spawn burst a moment before the food flies inward.
		var progress := smoothstep(0.18, 1.0, title_snack.age)
		var position := title_snack.pos.lerp(_title_mouth(), progress) + Vector2(0, -sin(progress * PI) * 12)
		var size := 26.0 * smoothstep(0.0, 0.12, title_snack.age) * (1.0 - smoothstep(0.8, 1.0, title_snack.age))
		if title_snack.age < 0.4:
			var burst := title_snack.age / 0.4
			for i in range(8):
				var direction := Vector2.RIGHT.rotated(title_snack.spin + i * TAU / 8)
				var spark := (title_snack.pos + direction * (14 + burst * 12)).round()
				var color: Color = [GOLD, PINK, MINT, CREAM][i % 4]
				color.a = 1.0 - burst
				draw_rect(Rect2(spark - Vector2.ONE, Vector2(2, 2)), color)
				if burst < 0.6 and i % 2 == 0:
					draw_line(spark - Vector2(3, 0), spark + Vector2(3, 0), color)
					draw_line(spark - Vector2(0, 3), spark + Vector2(0, 3), color)
		draw_set_transform(position, title_snack.age * 2)
		draw_texture_rect_region(nugget_tex, Rect2(-size / 2, -size / 2, size, size), _nugget_region(title_snack.kind, title_snack.variant))
		draw_set_transform(Vector2.ZERO)
	_text("MOUSE OR TOUCH. CATCH THE NUGGETS.", Vector2(224, 205), 8, CREAM, true)
	_text("60 SECONDS. ONE VERY HUNGRY CAT.", Vector2(224, 221), 8, MINT, true)
	_button("LET'S EAT!", "start", true)
	_button("SETTINGS", "settings")
	_button("QUIT", "quit")
	_text("BEST SNACK SCORE: %05d" % best, Vector2(224, 290), 8, GOLD, true)
	_button("SOURCES", "sources")
	_button("NUGGET GUIDE + ODDS", "guide")
	var shortcuts := "ENTER: START"
	if platform.can_quit():
		shortcuts += "  /  ESC: QUIT"
	if platform.supports_fullscreen():
		shortcuts += "  /  ALT+ENTER: FULLSCREEN" if platform.web else "  /  F11: FULLSCREEN"
	_text(shortcuts, Vector2(320, 348), 8, INK, true)

func _boss_stage() -> int:
	return 3 if boss_hp > 27 else (2 if boss_hp > 13 else 1)

func _boss_size() -> float:
	return BOSS_SIZE + (4.0 if expression > 0.35 else 0.0)

func _boss_contains_mouth(mouth: Vector2) -> bool:
	# Test the visible sprite, with a small mouth-sized margin, not a hidden
	# central target. The same rotation, scale and damage stage drive rendering.
	var local := (mouth - boss_pos).rotated(-sin(boss_age * 1.2) * 0.12) * 32.0 / _boss_size() + Vector2(16, 16)
	var radius := BOSS_MOUTH_RADIUS * 32.0 / _boss_size()
	var mask := boss_masks[_boss_stage() - 1]
	for y in range(maxi(0, floori(local.y - radius)), mini(32, ceili(local.y + radius))):
		for x in range(maxi(0, floori(local.x - radius)), mini(32, ceili(local.x + radius))):
			if mask.get_bit(x, y):
				var nearest := local.clamp(Vector2(x, y), Vector2(x + 1, y + 1))
				if local.distance_squared_to(nearest) <= radius * radius:
					return true
	return false

func _draw_boss() -> void:
	var stage := _boss_stage()
	var texture := nugget_tex if stage == 3 else nugget_bite_tex
	var size := _boss_size()
	draw_set_transform(boss_pos, sin(boss_age * 1.2) * 0.12)
	draw_texture_rect_region(texture, Rect2(-size / 2, -size / 2, size, size), _nugget_region("big", 0, stage))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(200, 307, 240, 9), INK)
	draw_rect(Rect2(202, 309, 236.0 * boss_hp / BOSS_BITES, 5), GOLD)
	draw_rect(Rect2(135, 319, 370, 15), INK)
	_text("BOSS: %d BITES LEFT / %d CHOMPS PER SEC" % [boss_hp, roundi(3 + boss_contact * 5 / 3)], Vector2(320, 322), 8, CREAM, true)

func _belly_dance(origin: Vector2, time: float, scale_factor: float) -> void:
	# Eight API-generated poses, palette-indexed offline; feet share a baseline.
	var frame := floori(time * 10.0) % dance_art.frame_count
	draw_set_transform(origin.round(), 0, Vector2.ONE * scale_factor)
	draw_texture_rect_region(dance_tex, dance_art.draw_rect(), dance_art.frame_rect(frame))
	draw_set_transform(Vector2.ZERO)

func _victory_dance() -> void:
	if boss_defeated:
		_belly_dance(Vector2(200, 170), results_time + celebration_time, 1.0)
		return
	var beat := results_time * 2.4
	var bounce := sin(fmod(beat, 1.0) * PI)
	var stretch := 1.0 + 0.07 * bounce - 0.09 * pow(1.0 - bounce, 4)
	var mirror := -1.0 if floori(beat / 4) % 2 == 1 else 1.0
	var position := Vector2(200 + sin(beat * PI * 0.5) * 6, 169 - 41 * stretch - bounce * 8)
	var frames := [4, 3, 4, 6, 4, 1, 4, 2]
	var frame: int = frames[floori(beat) % frames.size()]
	# Grounding shadow shrinks on each hop; the feet squash back onto the stage.
	draw_set_transform(Vector2(position.x, 171), 0, Vector2(1, 0.15))
	draw_circle(Vector2.ZERO, 21 - bounce * 5, Color("302636"))
	draw_set_transform(Vector2.ZERO)
	for i in range(4):
		var sparkle := Vector2(148 if i % 2 == 0 else 252, 111 + (i / 2) * 38)
		sparkle.y += sin(beat * PI + i) * 4
		var color := GOLD if i % 2 == 0 else MINT
		color.a = 0.35 + 0.65 * (sin(beat * PI + i * 1.7) * 0.5 + 0.5)
		draw_line(sparkle - Vector2(3, 0), sparkle + Vector2(3, 0), color, 2)
		draw_line(sparkle - Vector2(0, 3), sparkle + Vector2(0, 3), color, 2)
	_cat_sprite(position, frame, 2.0, sin(beat * PI) * 0.14, Vector2(mirror / stretch, stretch))

func _results() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.2, 0.17, 0.23, 0.3))
	_panel(Rect2(113, 25, 414, 309))
	_text("NEW BEST!" if score > old_best else "A CAT WELL FED.", Vector2(320, 43), 24, GOLD, true)
	_text("BOSS DEVOURED! BELLY DANCE!" if boss_defeated else "BOSS ESCAPED! STILL WELL FED.", Vector2(320, 77), 8, PINK, true)
	_victory_dance()
	_text(CAT_NAMES[cat_name_index], Vector2(200, 177), 8, MINT, true)
	_text("FINAL SCORE", Vector2(376, 102), 8, MINT, true)
	_text("%05d" % score, Vector2(376, 123), 32, CREAM, true)
	_text("BEST %05d" % best, Vector2(376, 164), 8, GOLD, true)
	draw_line(Vector2(145, 191), Vector2(495, 191), Color("796274"))
	for i in range(4):
		var x := 172 + i * 98
		_text(["CAUGHT", "MISSED", "BURNT", "STREAK"][i], Vector2(x, 205), 8, MINT, true)
		_text("%d" % [catches, misses, burnt_eaten, longest][i], Vector2(x, 225), 16, CREAM, true)
	_button("ANOTHER HELPING", "start", true)
	_button("TITLE", "home")

func _nugget_guide() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.2, 0.17, 0.23, 0.35))
	_panel(Rect2(75, 15, 490, 330))
	_text("KNOW YOUR NUGGETS", Vector2(320, 31), 16, GOLD, true)
	_text("BIG: HOLD MOUTH ON IT / POINTS X MULTIPLIER", Vector2(320, 60), 8, MINT, true)
	var rows := [
		["regular", "REGULAR", "10 POINTS", "PER THROW"],
		["big", "BIG REGULAR", "3 CHOMPS / 30 POINTS", "PER THROW"],
		["burnt", "BURNT", "-30 / COMBO RESET / 2S NO BITES", "PER THROW"],
		["golden", "GOLDEN", "20 POINTS + ONE MULTIPLIER TIER", "PER THROW"],
		["big_golden", "BIG GOLDEN", "3 CHOMPS / 100 + COLLECT EDIBLES", "PER ROUND"],
	]
	for i in range(rows.size()):
		var row: Array = rows[i]
		var y := 79 + i * 36
		var size := 32 if NUGGET_TYPES[row[0]].hp == 3 else 26
		draw_texture_rect_region(nugget_tex, Rect2(112 - size / 2.0, y + 13 - size / 2.0, size, size), _nugget_region(row[0]))
		_text(row[1], Vector2(145, y), 8, PINK if row[0] == "burnt" else GOLD)
		_text(row[2], Vector2(145, y + 14), 8, CREAM)
		_text("%d%%" % NUGGET_TYPES[row[0]].chance, Vector2(505, y), 8, GOLD, true)
		_text(row[3], Vector2(505, y + 14), 8, MINT, true)
	_text("THROW ODDS AFTER 12S / TWO BIG GOLDENS: %.2f%%" % (BIG_GOLD_ROUND_CHANCE * SECOND_BIG_GOLD_CHANCE * 100), Vector2(320, 263), 8, MINT, true)
	_text("FINAL 15S: BOSS / HOLD TO SPEED UP / 40 BITES", Vector2(320, 279), 8, GOLD, true)
	_text("FINISH: +500 AND A SPECIAL BELLY DANCE!", Vector2(320, 291), 8, CREAM, true)
	_button("READY TO SNACK", "back", true)

func _sources() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.2, 0.17, 0.23, 0.35))
	_panel(Rect2(75, 15, 490, 330))
	_text("SOUNDS + SOURCES", Vector2(320, 32), 16, GOLD, true)
	_text("MADE WITH GODOT / SOUNDS FROM FREESOUND", Vector2(320, 60), 8, MINT, true)
	for i in range(SOUND_CREDITS.size()):
		var credit: Dictionary = SOUND_CREDITS[i]
		var y := 85 + i * 60
		_text(credit.title, Vector2(100, y), 8, GOLD)
		_text("BY " + credit.author + " / CC0", Vector2(100, y + 15), 8, CREAM)
		_text(credit.use, Vector2(100, y + 30), 8, MINT)
		_button("SOURCE", "source_" + credit.id)
	_text("TRIMMED / LEVELS BALANCED / EDGE FADES", Vector2(320, 272), 8, CREAM, true)
	_text("SOURCE AND LICENSE BUTTONS OPEN YOUR BROWSER", Vector2(320, 286), 8, MINT, true)
	_button("CC0 LICENSE", "source_license")
	_button("BACK", "back", true)

func _settings() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.2, 0.17, 0.23, 0.3))
	_panel(Rect2(120, 20, 400, 320))
	_text("MAKE YOURSELF AT HOME", Vector2(320, 38), 16, GOLD, true)
	_button("MUSIC: RANDOM EACH ROUND" if shuffle_music else "MUSIC: KEEP THIS TRACK", "shuffle")
	_text("MUSIC TRACK %d / %d" % [selected_track + 1, TRACKS.size()], Vector2(320, 79), 8, MINT, true)
	_button("<", "track_prev")
	_text(TRACKS[selected_track].name, Vector2(320, 106), 16, CREAM, true)
	_button(">", "track_next")
	_text(TRACKS[selected_track].mood, Vector2(320, 134), 8, PINK, true)
	for i in range(3):
		var y := 153 + i * 36
		var value: float = [master_volume, music_volume, sfx_volume][i]
		var key: String = ["master", "music", "sfx"][i]
		_text(["MASTER", "MUSIC", "SOUNDS"][i], Vector2(145, y + 8), 8)
		_button("-", key + "_down")
		var slider := _volume_slider_rect(i)
		draw_rect(slider, Color("725866"))
		draw_rect(Rect2(slider.position, Vector2(slider.size.x * value, slider.size.y)), GOLD)
		draw_rect(Rect2(slider.position + Vector2(slider.size.x * value - 2, -3), Vector2(4, 18)), CREAM)
		_button("+", key + "_up")
		_text("%d%%" % roundi(value * 100), Vector2(447, y + 8), 8, MINT)
	_button("FULLSCREEN: ON" if fullscreen else "FULLSCREEN: OFF", "fullscreen")
	if platform.supports_fullscreen():
		_text("ALT+ENTER" if platform.web else "F11 / ALT+ENTER", Vector2(368, 273), 8, MINT)
	_button("ALL GOOD", "back", true)
