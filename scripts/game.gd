extends Node2D
## All simulation uses a fixed 640x360 logical canvas.

const ROUND_LENGTH := 60.0
# Elapsed seconds, throw interval, flight time to target, music playback rate.
const DIFFICULTY_STAGES := [
	Vector4(0, 0.82, 1.05, 1.00),
	Vector4(15, 0.64, 0.95, 1.04),
	Vector4(35, 0.48, 0.82, 1.09),
	Vector4(50, 0.36, 0.75, 1.14),
	Vector4(60, 0.30, 0.68, 1.20),
]
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
const CAT_NAMES := ["MOCHI", "BISCUIT", "WAFFLES", "DUMPLING", "NOODLE", "PUDDING", "PICKLES", "PEBBLE", "BUTTONS", "MAPLE", "MISO", "BEAN", "SPROUT", "PUMPKIN", "PIP", "TOFU", "MUFFIN", "POPPY", "BOBA", "TATER"]
const TRACKS := [
	{"name": "SNACK TIME", "mood": "THE ORIGINAL BOUNCY CHIPTUNE", "file": "snack_time", "panic": "panic"},
	{"name": "SUNNY SIDE UP", "mood": "SUNNY BELLS AND BREEZY GROOVES", "file": "sunny_side_up", "panic": "sunny_side_up_panic"},
	{"name": "GOOFY WHISKERS", "mood": "FUNNY HOPS AND WOBBLY BASS", "file": "goofy_whiskers", "panic": "goofy_whiskers_panic"},
	{"name": "NUGGET QUEST", "mood": "A TINY CAT. A GRAND ADVENTURE.", "file": "nugget_quest", "panic": "nugget_quest_panic"},
	{"name": "NUGGET BATTLE", "mood": "BOSS-FIGHT DRUMS AND DRIVING BASS", "file": "nugget_battle", "panic": "nugget_battle_panic"},
]
const CatAppearance := preload("res://scripts/cat_appearance.gd")

var cat_art := CatAppearance.new()
var cat_palettes: Array[Dictionary] = []
var cat_tex: Texture2D
var nugget_tex: Texture2D = preload("res://assets/nuggets.png")
var hand_tex: Texture2D = preload("res://assets/hands_ai.png")
var font: Font = preload("res://assets/pixel_font.fnt")
var music: AudioStreamPlayer
var panic_music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var reaction_voice: AudioStreamPlayer
var state := "title"
var previous_state := "title"
var clock := 0.0
var results_time := 0.0
var remaining := ROUND_LENGTH
var spawn_in := 0.9
var cat := Vector2(320, 180)
var cat_previous := cat
var cat_velocity := Vector2.ZERO
var tilt := 0.0
var expression := 0.0
var offended := 0.0
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
var best := 0
var old_best := 0
var master_volume := 1.0
var volume_drag := -1
var music_volume := 0.55
var sfx_volume := 0.7
var selected_track := 0
var shuffle_music := true
var cat_palette := 0
var cat_name_index := -1
var title_cat_selected := false
var fullscreen := false
var windowed_size := Vector2i(1280, 720)
var windowed_position := Vector2i.ZERO
var nuggets: Array[Dictionary] = []
var hands: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var popups: Array[Dictionary] = []
var buttons: Array[Dictionary] = []
var banner := ""
var banner_time := 0.0
var last_second := 60
var test_mode := false
var random := RandomNumberGenerator.new()

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
		_run_smoke_test.call_deferred()
	queue_redraw()

func _setup_audio() -> void:
	for sound in ["catch", "combo", "miss", "throw", "tick", "finish", "reaction_eww", "reaction_yay", "reaction_nom"]:
		sounds[sound] = load("res://assets/%s.wav" % sound)
	reaction_voice = AudioStreamPlayer.new()
	add_child(reaction_voice)
	music = AudioStreamPlayer.new()
	add_child(music)
	panic_music = AudioStreamPlayer.new()
	add_child(panic_music)
	for i in range(10):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	_set_volumes()
	_select_track(_random_choice(-1, TRACKS.size()) if shuffle_music else selected_track)

func _random_choice(current: int, count: int) -> int:
	# Every other choice is equally likely; no immediate repeats.
	if current < 0:
		return random.randi_range(0, count - 1)
	return (current + random.randi_range(1, count - 1)) % count

func _select_cat(index: int) -> void:
	cat_palette = index
	cat_tex = cat_art.texture_for_palette(index)
	cat_name_index = _random_choice(cat_name_index, CAT_NAMES.size())

func _select_track(index: int) -> void:
	selected_track = posmod(index, TRACKS.size())
	music.stop()
	panic_music.stop()
	music.stream = _looped("res://assets/%s.wav" % TRACKS[selected_track].file)
	panic_music.stream = _looped("res://assets/%s.wav" % TRACKS[selected_track].panic)
	_set_music_rate(_difficulty_at(ROUND_LENGTH - remaining).z if state in ["playing", "paused"] else 1.0)
	if not test_mode:
		music.play()
		music.stream_paused = state == "paused"

func _difficulty_at(elapsed: float) -> Vector3:
	for i in range(1, DIFFICULTY_STAGES.size()):
		var previous: Vector4 = DIFFICULTY_STAGES[i - 1]
		var next: Vector4 = DIFFICULTY_STAGES[i]
		if elapsed <= next.x:
			var weight := smoothstep(previous.x, next.x, elapsed)
			return Vector3(previous.y, previous.z, previous.w).lerp(Vector3(next.y, next.z, next.w), weight)
	var last: Vector4 = DIFFICULTY_STAGES[-1]
	return Vector3(last.y, last.z, last.w)

func _set_music_rate(rate: float) -> void:
	# Speed and pitch rise together, like an arcade soundtrack. Both stems stay in tune.
	music.pitch_scale = rate
	panic_music.pitch_scale = rate

func _start_panic_music() -> void:
	if not test_mode:
		panic_music.stream_paused = false
		# The new arrangements have matching tempo, harmony and loop length.
		panic_music.play(fmod(music.get_playback_position(), panic_music.stream.get_length()))

func _toggle_fullscreen() -> void:
	var window := get_window()
	fullscreen = window.mode not in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	# A resize changes pointer coordinates; pause first to avoid accidental catches.
	if state == "playing":
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

func _close_settings() -> void:
	volume_drag = -1
	state = previous_state
	_set_music_rate(_difficulty_at(ROUND_LENGTH - remaining).z if state == "paused" else 1.0)
	music.stream_paused = state == "paused"
	_save_settings()
	buttons.clear()

func _looped(path: String) -> AudioStreamWAV:
	var stream := load(path).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream

func _sound(key: String, pitch: float = 1.0) -> void:
	if test_mode:
		return
	if key.begins_with("reaction_"):
		# One voice keeps rapid catches intelligible and cannot exhaust the SFX pool.
		reaction_voice.stream = sounds[key]
		reaction_voice.pitch_scale = pitch
		reaction_voice.play()
		return
	for voice in voices:
		if not voice.playing:
			voice.stream = sounds[key]
			voice.pitch_scale = pitch
			voice.play()
			return

func _set_volumes() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(0.0001, master_volume)))
	AudioServer.set_bus_mute(master_bus, master_volume <= 0)
	reaction_voice.volume_linear = sfx_volume * 0.55
	music.volume_linear = music_volume
	panic_music.volume_linear = music_volume * 0.18
	for voice in voices:
		voice.volume_linear = sfx_volume * 0.45

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

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "playing":
		_pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_settings()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and volume_drag >= 0:
			volume_drag = -1
			_save_settings()
			return
		if event.pressed and state == "settings":
			for i in range(3):
				if _volume_slider_rect(i).grow(5).has_point(get_global_mouse_position()):
					volume_drag = i
					_drag_volume(get_global_mouse_position().x)
					return
	if event is InputEventMouseMotion and volume_drag >= 0:
		_drag_volume(get_global_mouse_position().x)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			_toggle_fullscreen()
		elif event.keycode == KEY_ESCAPE:
			if state == "title":
				_action("quit")
			elif state == "playing":
				_pause()
			elif state == "paused":
				_resume()
			elif state in ["settings", "guide", "sources"]:
				_close_settings()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if state in ["title", "results"]:
				_start()
			elif state == "paused":
				_resume()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pointer := get_global_mouse_position()
		for button in buttons:
			if button.rect.has_point(pointer):
				_action(button.action)
				break

func _action(action: String) -> void:
	_sound("catch", 0.8)
	match action:
		"start": _start()
		"resume": _resume()
		"pause": _pause()
		"home":
			state = "title"
			_set_music_rate(1.0)
			title_cat_selected = false
			panic_music.stop()
			music.stream_paused = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		"cat_shuffle":
			if state == "title":
				_select_cat(_random_choice(cat_palette, cat_palettes.size()))
				title_cat_selected = true
				expression = 0.42
		"settings":
			previous_state = state
			state = "settings"
			_set_music_rate(1.0)
			music.stream_paused = false
			panic_music.stop()
		"guide", "sources":
			previous_state = state
			state = action
		"source_488472", "source_162395", "source_449868":
			if not test_mode:
				OS.shell_open("https://freesound.org/s/" + action.trim_prefix("source_") + "/")
		"source_license":
			if not test_mode:
				OS.shell_open("https://creativecommons.org/publicdomain/zero/1.0/")
		"back": _close_settings()
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
	_set_volumes()
	buttons.clear()
	queue_redraw()

func _volume_slider_rect(index: int) -> Rect2:
	return Rect2(263, 161 + index * 36, 128, 12)

func _drag_volume(pointer_x: float) -> void:
	var slider := _volume_slider_rect(volume_drag)
	var value := clampf((pointer_x - slider.position.x) / slider.size.x, 0, 1)
	match volume_drag:
		0: master_volume = value
		1: music_volume = value
		2: sfx_volume = value
	_set_volumes()
	queue_redraw()

func _start() -> void:
	state = "playing"
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
	buttons.clear()
	cat = get_global_mouse_position().clamp(Vector2(20, 62), Vector2(620, 326))
	cat_previous = cat
	cat_velocity = Vector2.ZERO
	banner = "FOLLOW YOUR APPETITE!"
	banner_time = 2.0
	last_second = 60
	panic_music.stop()
	music.stream_paused = false
	if not test_mode and not shuffle_music:
		music.play()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _pause() -> void:
	state = "paused"
	music.stream_paused = true
	panic_music.stream_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	buttons.clear()

func _resume() -> void:
	state = "playing"
	_set_music_rate(_difficulty_at(ROUND_LENGTH - remaining).z)
	cat = get_global_mouse_position().clamp(Vector2(20, 62), Vector2(620, 326))
	cat_previous = cat
	music.stream_paused = false
	if remaining <= 10:
		_start_panic_music()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	buttons.clear()

func _finish() -> void:
	state = "results"
	results_time = 0.0
	expression = 0.0
	remaining = 0
	best = maxi(best, score)
	_save_settings()
	panic_music.stop()
	_set_music_rate(1.0)
	_sound("finish")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	buttons.clear()

func _process(delta: float) -> void:
	if test_mode:
		return
	clock += delta
	if state == "playing":
		cat_previous = cat
		cat = get_global_mouse_position().clamp(Vector2(20, 62), Vector2(620, 326))
		var velocity := (cat - cat_previous) / maxf(delta, 0.001)
		cat_velocity = cat_velocity.lerp(velocity, 1.0 - exp(-12 * delta))
		tilt = lerpf(tilt, clampf(cat_velocity.x / 2200, -0.24, 0.24), 1.0 - exp(-14 * delta))
		_step(delta)
	elif state == "title":
		expression = maxf(0, expression - delta)
	elif state == "results":
		results_time += delta
	queue_redraw()

func _step(delta: float) -> void:
	remaining = maxf(0, remaining - delta)
	if remaining <= 0:
		_finish()
		return
	var difficulty := _difficulty_at(ROUND_LENGTH - remaining)
	_set_music_rate(difficulty.z)
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
	spawn_in -= delta
	if spawn_in <= 0:
		_spawn_hand()
		# Preserve timer overshoot so cadence stays consistent across frame rates.
		spawn_in += difficulty.x * random.randf_range(0.92, 1.08)
	for i in range(hands.size() - 1, -1, -1):
		var hand: Dictionary = hands[i]
		hand.age += delta
		if hand.age >= 0.72 and not hand.released:
			hand.released = true
			_release(hand)
		if hand.age > 1.15:
			hands.remove_at(i)
	for i in range(nuggets.size() - 1, -1, -1):
		var n: Dictionary = nuggets[i]
		var before: Vector2 = n.pos
		n.age += delta
		n.bite_wait = maxf(0, n.bite_wait - delta)
		n.vel.y += n.gravity * delta
		n.pos += n.vel * delta
		n.rotation += n.spin * delta
		# Swept relative motion prevents tunneling during fast mouse swipes.
		if _swept_catch(before, n.pos, cat_previous, cat, NUGGET_TYPES[n.kind].radius):
			if _chomp(n):
				nuggets.remove_at(i)
				_eat_nugget(n)
		elif n.pos.x < -24 or n.pos.x > 664 or n.pos.y > 390 or n.pos.y < -100:
			if n.kind != "burnt":
				_miss()
			nuggets.remove_at(i)
	if sweep_pending:
		_collect_flying_nuggets()
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

func _swept_catch(n0: Vector2, n1: Vector2, c0: Vector2, c1: Vector2, radius: float = CATCH_RADIUS) -> bool:
	var start := n0 - c0
	var end := n1 - c1
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
	var flight := _difficulty_at(ROUND_LENGTH - remaining).y
	if NUGGET_TYPES[kind].hp == 3:
		flight *= 1.18
	var gravity := 155.0
	var velocity := (target - origin) / flight - Vector2(0, gravity * flight * 0.5)
	nuggets.append(_make_nugget(kind, origin, velocity, gravity, hand.get("variant", 0)))
	_sound("throw", random.randf_range(0.85, 1.2))

func _make_nugget(kind: String, position: Vector2, velocity: Vector2 = Vector2.ZERO, gravity: float = 155.0, variant: int = 0) -> Dictionary:
	return {"kind": kind, "variant": variant, "hp": NUGGET_TYPES[kind].hp, "bite_wait": 0.0,
		"pos": position, "vel": velocity, "gravity": gravity, "age": 0.0,
		"rotation": random.randf_range(-PI, PI), "spin": random.randf_range(-3, 3)}

func _chomp(nugget: Dictionary) -> bool:
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

func _eat_nugget(nugget: Dictionary, allow_sweep: bool = true) -> void:
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
			var nugget: Dictionary = nuggets[i]
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

func _button(label: String, rect: Rect2, action: String, primary: bool = false) -> void:
	var hover := rect.has_point(get_global_mouse_position())
	var color := GOLD if primary else Color("65536b")
	if hover:
		color = MINT if primary else Color("89718a")
	draw_rect(Rect2(rect.position + Vector2(0, 3), rect.size), Color("302636"))
	draw_rect(rect, color)
	draw_rect(Rect2(rect.position + Vector2(1, 1), rect.size - Vector2(2, 2)), CREAM if hover else color.lightened(0.18), false)
	_text(label, rect.position + Vector2(rect.size.x / 2, (rect.size.y - 8) / 2 - 1), 8, INK if primary else CREAM, true)
	buttons.append({"rect": rect, "action": action})

func _draw() -> void:
	if cat_tex == null:
		return
	buttons.clear()
	_kitchen()
	if state == "title":
		_title()
	elif state == "results":
		_results()
	elif state == "settings":
		_settings()
	elif state == "guide":
		_nugget_guide()
	elif state == "sources":
		_sources()
	else:
		_playfield()
		if state == "paused":
			draw_rect(Rect2(0, 0, 640, 360), Color(0.16, 0.12, 0.20, 0.7))
			_panel(Rect2(206, 63, 228, 258))
			_text("SNACK BREAK", Vector2(320, 85), 16, GOLD, true)
			_text("YOUR NUGGETS CAN WAIT.", Vector2(320, 115), 8, CREAM, true)
			_button("KEEP MUNCHING", Rect2(240, 141, 160, 30), "resume", true)
			_button("SETTINGS", Rect2(240, 181, 160, 26), "settings")
			_button("NUGGET GUIDE", Rect2(240, 215, 160, 26), "guide")
			_button("BACK TO TITLE", Rect2(240, 249, 160, 26), "home")
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
	var stretch := 1.0 + minf(cat_velocity.length() / 10000, 0.14) if state == "playing" else 1.0
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

func _golden_glitter(n: Dictionary, size: float) -> void:
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

func _draw_flying_nugget(n: Dictionary) -> void:
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
		var slide := clampf(age / 0.18, 0, 1) * clampf((1.15 - age) / 0.2, 0, 1)
		var pos: Vector2 = hand.pos - direction * (1.0 - slide) * 58
		draw_set_transform(pos, hand.angle)
		var frame := 0 if age < 0.4 else (1 if age < 0.72 else 2)
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
	_button("II", Rect2(588, 11, 34, 27), "pause")
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
	var portrait := Rect2(415, 74, 159, 146)
	var hovered := portrait.has_point(get_global_mouse_position())
	draw_rect(portrait, Color("675367"))
	draw_rect(Rect2(422, 81, 145, 132), MINT if hovered else Color("806678"), false, 2)
	buttons.append({"rect": portrait, "action": "cat_shuffle"})
	_cat_sprite(Vector2(495, 151 + sin(clock * 2.5) * 4), 6 if expression > 0 or fmod(clock, 5) > 4 else (1 if fmod(clock, 4) < 0.15 else 0), 2.8, sin(clock * 1.8) * 0.06)
	_text(CAT_NAMES[cat_name_index], Vector2(495, 223), 8, GOLD, true)
	_text("CLICK TO MEET ANOTHER CAT", Vector2(495, 237), 8, MINT if hovered else CREAM, true)
	draw_set_transform(Vector2(558, 88 + sin(clock * 3) * 4), clock * 0.7)
	draw_texture_rect_region(nugget_tex, Rect2(-13, -13, 26, 26), _nugget_region("regular"))
	draw_set_transform(Vector2.ZERO)
	_text("MOVE YOUR MOUSE. CATCH THE NUGGETS.", Vector2(224, 205), 8, CREAM, true)
	_text("60 SECONDS. ONE VERY HUNGRY CAT.", Vector2(224, 221), 8, MINT, true)
	_button("LET'S EAT!", Rect2(100, 247, 245, 36), "start", true)
	_button("SETTINGS", Rect2(366, 252, 105, 26), "settings")
	_button("QUIT", Rect2(483, 252, 78, 26), "quit")
	_text("BEST SNACK SCORE: %05d" % best, Vector2(224, 290), 8, GOLD, true)
	_button("SOURCES", Rect2(169, 308, 110, 18), "sources")
	_button("NUGGET GUIDE + ODDS", Rect2(366, 293, 195, 24), "guide")
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
	_button("ANOTHER HELPING", Rect2(146, 270, 210, 34), "start", true)
	_button("TITLE", Rect2(375, 274, 118, 26), "home")

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
	_button("READY TO SNACK", Rect2(240, 306, 160, 26), "back", true)

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
		_button("SOURCE", Rect2(440, y + 6, 98, 26), "source_" + credit.id)
	_text("TRIMMED / LEVELS BALANCED / EDGE FADES", Vector2(320, 272), 8, CREAM, true)
	_text("SOURCE AND LICENSE BUTTONS OPEN YOUR BROWSER", Vector2(320, 286), 8, MINT, true)
	_button("CC0 LICENSE", Rect2(160, 308, 150, 24), "source_license")
	_button("BACK", Rect2(330, 308, 150, 24), "back", true)

func _settings() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.2, 0.17, 0.23, 0.3))
	_panel(Rect2(120, 20, 400, 320))
	_text("MAKE YOURSELF AT HOME", Vector2(320, 38), 16, GOLD, true)
	_button("MUSIC: RANDOM EACH ROUND" if shuffle_music else "MUSIC: KEEP THIS TRACK", Rect2(215, 58, 210, 18), "shuffle")
	_text("MUSIC TRACK %d / %d" % [selected_track + 1, TRACKS.size()], Vector2(320, 79), 8, MINT, true)
	_button("<", Rect2(153, 100, 32, 26), "track_prev")
	_text(TRACKS[selected_track].name, Vector2(320, 106), 16, CREAM, true)
	_button(">", Rect2(455, 100, 32, 26), "track_next")
	_text(TRACKS[selected_track].mood, Vector2(320, 134), 8, PINK, true)
	for i in range(3):
		var y := 153 + i * 36
		var value: float = [master_volume, music_volume, sfx_volume][i]
		var key: String = ["master", "music", "sfx"][i]
		_text(["MASTER", "MUSIC", "SOUNDS"][i], Vector2(145, y + 8), 8)
		_button("-", Rect2(221, y, 28, 26), key + "_down")
		var slider := _volume_slider_rect(i)
		draw_rect(slider, Color("725866"))
		draw_rect(Rect2(slider.position, Vector2(slider.size.x * value, slider.size.y)), GOLD)
		draw_rect(Rect2(slider.position + Vector2(slider.size.x * value - 2, -3), Vector2(4, 18)), CREAM)
		_button("+", Rect2(405, y, 28, 26), key + "_up")
		_text("%d%%" % roundi(value * 100), Vector2(447, y + 8), 8, MINT)
	_button("FULLSCREEN: ON" if fullscreen else "FULLSCREEN: OFF", Rect2(153, 264, 202, 26), "fullscreen")
	_text("F11 / ALT+ENTER", Vector2(368, 273), 8, MINT)
	_button("ALL GOOD", Rect2(251, 302, 138, 28), "back", true)

func _run_smoke_test() -> void:
	# Deterministic behavioral checks; does not touch real save data.
	random.seed = 12345
	_start()
	assert(state == "playing" and remaining == 60 and score == 0)
	assert(_swept_catch(Vector2(100, 100), Vector2(300, 100), Vector2(200, 100), Vector2(200, 100)))
	assert(_swept_catch(Vector2(200, 100), Vector2(200, 100), Vector2(100, 100), Vector2(300, 100)))
	assert(not _swept_catch(Vector2(100, 200), Vector2(300, 200), Vector2(200, 100), Vector2(200, 100)))
	for i in range(5):
		_catch(Vector2(320, 180))
	assert(score == 50 and _multiplier() == 2 and longest == 5)
	_catch(Vector2(320, 180))
	assert(score == 70)
	_miss()
	assert(streak == 0 and _multiplier() == 1 and misses == 1 and score == 70)
	for i in range(30):
		_catch(Vector2(320, 180))
	assert(_multiplier() == 5)
	_pause()
	assert(state == "paused")
	_resume()
	assert(state == "playing")
	_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(state == "paused")
	_resume()
	_start()
	cat = Vector2(-500, -500)
	cat_previous = cat
	var throw_buckets := [0, 0, 0]
	var previous_rate := 1.0
	for i in range(3601):
		if state == "playing":
			var count_before := throws
			_step(1.0 / 60.0)
			throw_buckets[mini(2, i / 1200)] += throws - count_before
			if i == 59:
				assert(throws >= 1) # First nugget arrives in the first second.
			if state == "playing":
				assert(music.pitch_scale >= previous_rate and music.pitch_scale <= 1.2001)
				assert(is_equal_approx(music.pitch_scale, panic_music.pitch_scale))
				previous_rate = music.pitch_scale
	assert(state == "results" and remaining == 0)
	assert(misses > 30 and catches == 0)
	assert(throw_buckets[0] >= 24 and throw_buckets[1] > throw_buckets[0] and throw_buckets[2] > throw_buckets[1])
	assert(is_equal_approx(music.pitch_scale, 1.0))
	print("PACE CHECK: throws per 20 seconds: %s; peak music speed: %.2fx" % [throw_buckets, previous_rate])
	var simulated_misses := misses
	_start()
	assert(is_equal_approx(music.pitch_scale, 1.0))
	remaining = 8
	_step(0.01)
	var late_rate := music.pitch_scale
	assert(late_rate > 1.14)
	_pause()
	_action("settings")
	assert(is_equal_approx(music.pitch_scale, 1.0))
	_action("track_next")
	_action("back")
	assert(is_equal_approx(music.pitch_scale, late_rate))
	_resume()
	assert(is_equal_approx(panic_music.pitch_scale, late_rate))
	_action("home")
	assert(is_equal_approx(music.pitch_scale, 1.0))
	_start()
	assert(nuggets.is_empty() and hands.is_empty() and score == 0 and misses == 0)
	for i in range(TRACKS.size()):
		_select_track(i)
		assert(music.stream.get_length() > 25 and music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
		if i > 0:
			assert(is_equal_approx(music.stream.get_length(), panic_music.stream.get_length()))
	_select_track(-1)
	assert(selected_track == TRACKS.size() - 1)
	_action("track_next")
	assert(selected_track == 0)
	assert(not shuffle_music)
	_start()
	assert(selected_track == 0) # Manual selection survives a new round.
	_action("shuffle")
	assert(shuffle_music)
	var seen_tracks := {}
	var seen_cats := {}
	for i in range(48):
		var previous_track := selected_track
		var previous_cat := cat_palette
		_start()
		assert(selected_track != previous_track and cat_palette != previous_cat)
		seen_tracks[selected_track] = true
		seen_cats[cat_palette] = true
		var round_track := selected_track
		var round_cat := cat_palette
		_pause()
		_resume()
		assert(selected_track == round_track and cat_palette == round_cat)
	assert(seen_tracks.size() == TRACKS.size() and seen_cats.size() == cat_palettes.size())
	_action("home")
	var before_click := cat_palette
	var name_before_click := cat_name_index
	_action("cat_shuffle")
	assert(cat_palette != before_click and cat_name_index != name_before_click and state == "title")
	var clicked_color := cat_palette
	var clicked_name := cat_name_index
	_start()
	assert(cat_palette == clicked_color and cat_name_index == clicked_name and not title_cat_selected)
	_start()
	assert(cat_palette != clicked_color and cat_name_index != clicked_name) # Replay resumes normal randomization.
	var role_examples := {}
	for pixel in range(cat_art.indices.size()):
		role_examples[cat_art.indices[pixel]] = Vector2i(pixel % cat_art.image_size.x, pixel / cat_art.image_size.x)
	assert(role_examples.size() == cat_art.roles.size())
	for palette_index in range(cat_palettes.size()):
		var texture := cat_art.texture_for_palette(palette_index)
		assert(texture == cat_art.texture_for_palette(palette_index)) # Cached, not rebuilt.
		var image := texture.get_image()
		assert(image.get_size() == cat_art.image_size and image.get_pixelv(role_examples[0]).a == 0)
		for role in range(1, cat_art.roles.size()):
			var expected := Color(str(cat_palettes[palette_index].colors[cat_art.roles[role]]))
			assert(image.get_pixelv(role_examples[role]).to_rgba32() == expected.to_rgba32())
		for frame in range(cat_art.frame_count):
			assert(image.get_region(Rect2i(cat_art.frame_rect(frame))).get_used_rect().has_area())
	# Exercise actual persistence against a disposable project-local file.
	if not OS.has_feature("standalone"):
		DirAccess.make_dir_recursive_absolute("res://build")
		best = 1234
		master_volume = 0.6
		music_volume = 0.3
		sfx_volume = 0.8
		selected_track = 2
		shuffle_music = false
		fullscreen = true
		_save_settings("res://build/test_save.cfg")
		best = 0
		master_volume = 0
		music_volume = 0
		sfx_volume = 0
		selected_track = 0
		shuffle_music = true
		fullscreen = false
		_load_settings("res://build/test_save.cfg")
		assert(best == 1234 and is_equal_approx(music_volume, 0.3) and is_equal_approx(sfx_volume, 0.8))
		assert(is_equal_approx(master_volume, 0.6))
		var legacy := ConfigFile.new()
		assert(legacy.load("res://build/test_save.cfg") == OK)
		legacy.erase_section_key("audio", "master")
		assert(legacy.save("res://build/test_save.cfg") == OK)
		_load_settings("res://build/test_save.cfg")
		assert(is_equal_approx(master_volume, 1.0))
		volume_drag = 0
		_drag_volume(_volume_slider_rect(0).position.x - 10)
		assert(master_volume == 0 and AudioServer.is_bus_mute(0))
		_drag_volume(_volume_slider_rect(0).end.x + 10)
		assert(master_volume == 1 and not AudioServer.is_bus_mute(0))
		assert(is_equal_approx(music.volume_linear, music_volume))
		volume_drag = -1
		assert(selected_track == 2 and fullscreen and not shuffle_music)
		DirAccess.remove_absolute("res://build/test_save.cfg")
	print("SMOKE TEST PASSED: gameplay (%d misses), %d tracks, 48 randomized rounds, %d external cat palettes, indexed roles, cached textures, all animation frames, manual selection, saved preferences." % [simulated_misses, TRACKS.size(), cat_palettes.size()])
	get_tree().quit(0)
