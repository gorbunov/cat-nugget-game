extends Node2D
## Round orchestration and custom drawing on a fixed 640x360 logical canvas.
## Audio owns playback; ScreenLayout owns interactive geometry; Nugget owns flight state.

const ROUND_LENGTH := 60.0
const HAND_RELEASE_TIME := 0.72
const HAND_LIFETIME := 1.15
const CATCH_RADIUS := 18.0
const CHOMP_INTERVAL := 0.20
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

# Assets and appearance (the chosen cat persists through pause and results).
var cat_art := CatAppearance.new()
var cat_palettes: Array[Dictionary] = []
var cat_tex: Texture2D
var nugget_tex: Texture2D = preload("res://assets/nuggets.png")
var hand_tex: Texture2D = preload("res://assets/hands_ai.png")
var font: Font = preload("res://assets/pixel_font.fnt")
var cat_palette := 0
var cat_name_index := -1
var title_cat_selected := false

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
var tilt := 0.0
var expression := 0.0
var offended := 0.0
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
	random.randomize()
	var smoke_requested := "--smoke-test" in OS.get_cmdline_user_args()
	test_mode = test_mode or smoke_requested
	_load_settings()
	if cat_art.load_assets() != OK:
		get_tree().quit(1)
		return
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

func _toggle_fullscreen() -> void:
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
		window.size = windowed_size
		window.position = windowed_position
	_save_settings()

func _change_screen(next_screen: ScreenLayout.Screen) -> void:
	state = next_screen
	volume_drag = -1
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and volume_drag >= 0:
			volume_drag = -1
			_save_settings()
			return
		if event.pressed and state == Screen.SETTINGS:
			for i in range(3):
				if _volume_slider_rect(i).grow(5).has_point(get_global_mouse_position()):
					volume_drag = i
					_drag_volume(get_global_mouse_position().x)
					return
	if event is InputEventMouseMotion and volume_drag >= 0:
		_drag_volume(get_global_mouse_position().x)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("toggle_fullscreen", false, true):
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
		_activate_button_at(get_global_mouse_position())

func _activate_button_at(pointer: Vector2) -> void:
	var action := ScreenLayout.action_at(state, pointer)
	if not action.is_empty():
		_handle_action(action)


func _handle_action(action: String) -> void:
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
	nuggets.clear()
	hands.clear()
	particles.clear()
	popups.clear()
	cat = get_global_mouse_position().clamp(Vector2(20, 62), Vector2(620, 326))
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
	cat = get_global_mouse_position().clamp(Vector2(20, 62), Vector2(620, 326))
	cat_previous = cat
	audio.resume_music()
	if remaining <= 10:
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
	clock += delta
	if state == Screen.PLAYING:
		cat_previous = cat
		cat = get_global_mouse_position().clamp(Vector2(20, 62), Vector2(620, 326))
		var velocity := (cat - cat_previous) / maxf(delta, 0.001)
		cat_velocity = cat_velocity.lerp(velocity, 1.0 - exp(-12 * delta))
		tilt = lerpf(tilt, clampf(cat_velocity.x / 2200, -0.24, 0.24), 1.0 - exp(-14 * delta))
		_step(delta)
	elif state == Screen.TITLE:
		expression = maxf(0, expression - delta)
	elif state == Screen.RESULTS:
		results_time += delta
	queue_redraw()

func _step(delta: float) -> void:
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
	banner_time = maxf(0, banner_time - delta)
	sweep_time = maxf(0, sweep_time - delta)
	if remaining <= 10 and last_second > 10:
		banner = "SNACK PANIC!"
		banner_time = 1.6
		_start_panic_music()
	if ceili(remaining) < last_second:
		last_second = ceili(remaining)
		if remaining <= 10:
			_sound("tick", 1.0 + (10 - remaining) * 0.025)


func _update_spawning(delta: float, throw_interval: float) -> void:
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
		if _swept_catch(previous_position, nugget.pos, cat_previous, cat, NUGGET_TYPES[nugget.kind].radius):
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
		rare_spawn_times.append(random.randf_range(18, 42))
		if random.randf() < SECOND_BIG_GOLD_CHANCE:
			rare_spawn_times.append(random.randf_range(45, 53))

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
		offended = 1.0
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
	var rect := ScreenLayout.button_rect(state, action)
	var hover := rect.has_point(get_global_mouse_position())
	var color := GOLD if primary else Color("65536b")
	if hover:
		color = MINT if primary else Color("89718a")
	draw_rect(Rect2(rect.position + Vector2(0, 3), rect.size), Color("302636"))
	draw_rect(rect, color)
	draw_rect(Rect2(rect.position + Vector2(1, 1), rect.size - Vector2(2, 2)), CREAM if hover else color.lightened(0.18), false)
	_text(label, rect.position + Vector2(rect.size.x / 2, (rect.size.y - 8) / 2 - 1), 8, INK if primary else CREAM, true)

func _draw() -> void:
	if cat_tex == null:
		return
	_kitchen()
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

func _kitchen() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("c9d9c6"))
	for y in range(54, 299, 30):
		draw_line(Vector2(0, y), Vector2(640, y), Color("bacebe"))
		for x in range(-20 if int(y / 30.0) % 2 == 1 else 0, 640, 48):
			draw_line(Vector2(x, y), Vector2(x, y + 30), Color("bacebe"))
	# Window and sky.
	draw_rect(Rect2(245, 76, 150, 128), Color("829d91"))
	draw_rect(Rect2(249, 80, 142, 120), Color("f7e9cc"))
	draw_rect(Rect2(255, 86, 130, 108), Color("a9cecb"))
	draw_rect(Rect2(262, 107, 35, 7), Color("dce5d1"))
	draw_rect(Rect2(271, 102, 18, 15), Color("dce5d1"))
	draw_circle(Vector2(357, 107), 13, Color("f6dfa5"))
	draw_rect(Rect2(255, 159, 130, 35), Color("9cbaa9"))
	draw_rect(Rect2(316, 83, 6, 116), Color("f7e9cc"))
	draw_rect(Rect2(249, 137, 142, 6), Color("f7e9cc"))
	draw_rect(Rect2(239, 199, 162, 7), Color("ebdfc2"))
	# Shelves, jars, plant.
	draw_rect(Rect2(48, 132, 136, 7), Color("a79585"))
	draw_rect(Rect2(54, 139, 6, 12), Color("a79585"))
	draw_rect(Rect2(173, 139, 6, 12), Color("a79585"))
	for x in [67, 100, 133]:
		draw_rect(Rect2(x, 108, 21, 24), Color("dfd9b9"))
		draw_rect(Rect2(x-1, 105, 23, 5), Color("b39589"))
		draw_rect(Rect2(x+4, 115, 13, 9), Color("ede3c6"))
	draw_rect(Rect2(462, 144, 125, 7), Color("a79585"))
	draw_rect(Rect2(534, 122, 25, 22), Color("c79f88"))
	draw_line(Vector2(546, 124), Vector2(546, 92), Color("829d81"), 3)
	for p in [Vector2(535, 104), Vector2(551, 94), Vector2(552, 114)]:
		draw_rect(Rect2(p, Vector2(12, 6)), Color("8da989"))
	draw_rect(Rect2(480, 117, 24, 27), Color("e3dbc5"))
	draw_rect(Rect2(504, 122, 7, 13), Color("e3dbc5"), false, 3)
	# Counter and cupboard fronts.
	draw_rect(Rect2(0, 302, 640, 58), Color("91aaa0"))
	draw_rect(Rect2(0, 298, 640, 8), Color("eee0bf"))
	draw_rect(Rect2(0, 306, 640, 4), Color("738e87"))
	for x in range(8, 640, 106):
		draw_rect(Rect2(x, 318, 94, 39), Color("a7bdb0"), false, 2)
		draw_rect(Rect2(x+39, 326, 17, 3), Color("728e83"))
	# Dish towel.
	draw_rect(Rect2(564, 301, 30, 45), Color("e7d4b9"))
	for x in range(569, 594, 8):
		draw_rect(Rect2(x, 302, 2, 44), Color("c1a899"))

func _cat_sprite(position: Vector2, frame: int, scale_factor: float = 1.5, angle: float = 0.0, pose_scale: Vector2 = Vector2.ONE) -> void:
	var stretch := 1.0 + minf(cat_velocity.length() / 10000, 0.14) if state == Screen.PLAYING else 1.0
	if expression > 0.30:
		stretch += 0.10
	draw_set_transform(position, angle, Vector2(scale_factor / stretch, scale_factor * stretch) * pose_scale)
	# Atlas and mouth anchor come from sprite metadata; catch position stays stable.
	draw_texture_rect_region(cat_tex, cat_art.draw_rect(), cat_art.frame_rect(frame))
	draw_set_transform(Vector2.ZERO)

func _cat_frame() -> int:
	if expression > 0.26:
		return 6 if streak >= 10 else 2
	if expression > 0:
		return 3
	if offended > 0:
		return 5
	if fmod(clock, 4.2) < 0.15:
		return 1
	return 6 if streak >= 15 else 0

func _nugget_region(kind: String, variant: int = 0) -> Rect2:
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
	var size: float = spec.size * (1.0 - (spec.hp - n.hp) * 0.08)
	var golden := kind in ["golden", "big_golden"]
	if golden:
		draw_circle(n.pos, size * 0.65, Color(1, 0.85, 0.25, 0.18))
	draw_circle(n.pos + Vector2(3, 7), size * 0.38, Color(0.25, 0.22, 0.25, 0.12))
	draw_set_transform(n.pos, n.rotation)
	draw_texture_rect_region(nugget_tex, Rect2(Vector2.ONE * (-size / 2), Vector2.ONE * size), _nugget_region(kind, n.variant))
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
	if sweep_time > 0:
		var progress := 1.0 - sweep_time / 0.65
		draw_arc(sweep_origin, lerpf(12, 650, progress), 0, TAU, 64, Color(1, 0.88, 0.4, (1 - progress) * 0.7), 3)
	# Ground shadow and trailing paws communicate motion without input lag.
	draw_set_transform(Vector2(cat.x, 294), 0, Vector2(1, 0.25))
	draw_circle(Vector2.ZERO, 22, Color(0.2, 0.25, 0.23, 0.13))
	draw_set_transform(Vector2.ZERO)
	_cat_sprite(cat, _cat_frame(), 1.5, tilt)
	# Quiet brackets mark the stable mouth target.
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
	if banner_time > 0:
		var width := font.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 28
		draw_rect(Rect2(320 - width / 2, 64, width, 22), INK)
		_text(banner, Vector2(320, 70), 8, GOLD if remaining > 10 else PINK, true)

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
	_text("MOUSE TO MUNCH", Vector2(12, 345), 8, INK)
	_text("%s / %s" % [CAT_NAMES[cat_name_index], cat_palettes[cat_palette].name], Vector2(320, 345), 8, INK, true)
	_text("ESC: SNACK BREAK", Vector2(522, 345), 8, INK, true)

func _title() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.21, 0.20, 0.24, 0.16))
	_panel(Rect2(20, 20, 600, 320), Color("423747"))
	_text("A VERY IMPORTANT FEEDING MISSION", Vector2(320, 38), 8, MINT, true)
	_text("NUGGET", Vector2(224, 70), 40, GOLD, true)
	_text("CAT", Vector2(224, 119), 40, CREAM, true)
	_text("NO THOUGHTS. JUST CHICKEN.", Vector2(224, 173), 8, PINK, true)
	# Cat portrait on a warm little stage.
	var portrait := ScreenLayout.button_rect(state, "cat_shuffle")
	var hovered := portrait.has_point(get_global_mouse_position())
	draw_rect(portrait, Color("675367"))
	draw_rect(Rect2(422, 81, 145, 132), MINT if hovered else Color("806678"), false, 2)
	_cat_sprite(Vector2(495, 151 + sin(clock * 2.5) * 4), 6 if expression > 0 or fmod(clock, 5) > 4 else (1 if fmod(clock, 4) < 0.15 else 0), 2.8, sin(clock * 1.8) * 0.06)
	_text(CAT_NAMES[cat_name_index], Vector2(495, 223), 8, GOLD, true)
	_text("CLICK TO MEET ANOTHER CAT", Vector2(495, 237), 8, MINT if hovered else CREAM, true)
	draw_set_transform(Vector2(558, 88 + sin(clock * 3) * 4), clock * 0.7)
	draw_texture_rect_region(nugget_tex, Rect2(-13, -13, 26, 26), _nugget_region("regular"))
	draw_set_transform(Vector2.ZERO)
	_text("MOVE YOUR MOUSE. CATCH THE NUGGETS.", Vector2(224, 205), 8, CREAM, true)
	_text("60 SECONDS. ONE VERY HUNGRY CAT.", Vector2(224, 221), 8, MINT, true)
	_button("LET'S EAT!", "start", true)
	_button("SETTINGS", "settings")
	_button("QUIT", "quit")
	_text("BEST SNACK SCORE: %05d" % best, Vector2(224, 290), 8, GOLD, true)
	_button("SOURCES", "sources")
	_button("NUGGET GUIDE + ODDS", "guide")
	_text("ENTER: START  /  ESC: QUIT  /  F11: FULLSCREEN", Vector2(320, 348), 8, INK, true)

func _victory_dance() -> void:
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
	_text("A CAT WELL FED.", Vector2(320, 43), 24, GOLD, true)
	_text("NEW PERSONAL BEST!" if score > old_best else "A NOBLE DAY OF SNACKING.", Vector2(320, 77), 8, PINK, true)
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
		["burnt", "BURNT", "AVOID! -30 AND COMBO RESET", "PER THROW"],
		["golden", "GOLDEN", "20 POINTS + ONE MULTIPLIER TIER", "PER THROW"],
		["big_golden", "BIG GOLDEN", "3 CHOMPS / 100 + COLLECT EDIBLES", "PER ROUND"],
	]
	for i in range(rows.size()):
		var row: Array = rows[i]
		var y := 82 + i * 40
		var size := 32 if NUGGET_TYPES[row[0]].hp == 3 else 26
		draw_texture_rect_region(nugget_tex, Rect2(112 - size / 2.0, y + 13 - size / 2.0, size, size), _nugget_region(row[0]))
		_text(row[1], Vector2(145, y), 8, PINK if row[0] == "burnt" else GOLD)
		_text(row[2], Vector2(145, y + 14), 8, CREAM)
		_text("%d%%" % NUGGET_TYPES[row[0]].chance, Vector2(505, y), 8, GOLD, true)
		_text(row[3], Vector2(505, y + 14), 8, MINT, true)
	_text("THROW ODDS AFTER 12S / TWO BIG GOLDENS: %.2f%%" % (BIG_GOLD_ROUND_CHANCE * SECOND_BIG_GOLD_CHANCE * 100), Vector2(320, 284), 8, MINT, true)
	_button("READY TO SNACK", "back", true)

func _sources() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.2, 0.17, 0.23, 0.35))
	_panel(Rect2(75, 15, 490, 330))
	_text("SOUNDS + SOURCES", Vector2(320, 32), 16, GOLD, true)
	_text("THANKS TO THE FREESOUND CREATORS!", Vector2(320, 60), 8, MINT, true)
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
	_text("F11 / ALT+ENTER", Vector2(368, 273), 8, MINT)
	_button("ALL GOOD", "back", true)
