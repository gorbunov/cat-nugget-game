extends Node2D
## All simulation uses a fixed 640x360 logical canvas; assets are original.

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
const HAND_GRIPS := [Vector2(17, -5), Vector2(12, -15), Vector2(24, -9)]
const INK := Color("423044")
const CREAM := Color("fff0cd")
const GOLD := Color("ffc568")
const PINK := Color("ed91a5")
const MINT := Color("9bd2bc")
const SAVE_PATH := "user://snack_save.cfg"
const CAT_NAMES := ["MOCHI", "BISCUIT", "WAFFLES", "DUMPLING", "NOODLE", "PUDDING", "PICKLES", "PEBBLE", "BUTTONS", "MAPLE", "MISO", "BEAN", "SPROUT", "PUMPKIN", "PIP", "TOFU", "MUFFIN", "POPPY", "BOBA", "TATER"]
const TRACKS := [
	{"name": "SNACK TIME", "mood": "THE ORIGINAL BOUNCY CHIPTUNE", "file": "snack_time", "panic": "panic"},
	{"name": "SUNNY SIDE UP", "mood": "SUNNY BELLS AND BREEZY GROOVES", "file": "sunny_side_up", "panic": "sunny_side_up_panic"},
	{"name": "GOOFY WHISKERS", "mood": "FUNNY HOPS AND WOBBLY BASS", "file": "goofy_whiskers", "panic": "goofy_whiskers_panic"},
	{"name": "NUGGET QUEST", "mood": "A TINY CAT. A GRAND ADVENTURE.", "file": "nugget_quest", "panic": "nugget_quest_panic"},
	{"name": "NUGGET BATTLE", "mood": "BOSS-FIGHT DRUMS AND DRIVING BASS", "file": "nugget_battle", "panic": "nugget_battle_panic"},
]
const CAT_PALETTES := [
	{"name": "GINGER", "fur": Color("f0974a"), "light": Color("ffc370"), "belly": Color("ffe7b8"), "eyes": Color("82c98f")},
	{"name": "SNOW", "fur": Color("bccbd6"), "light": Color("edf3ef"), "belly": Color("ffffff"), "eyes": Color("77bde8")},
	{"name": "SILVER", "fur": Color("68768b"), "light": Color("a4b1c6"), "belly": Color("e2e7ef"), "eyes": Color("75d2c5")},
	{"name": "COCOA", "fur": Color("946348"), "light": Color("c49370"), "belly": Color("f3d8b5"), "eyes": Color("e9b85c")},
	{"name": "LAVENDER", "fur": Color("9981bf"), "light": Color("cbb3ea"), "belly": Color("ede0fa"), "eyes": Color("edc96b")},
	{"name": "MINT", "fur": Color("64aa98"), "light": Color("a6dcc0"), "belly": Color("e1f4d6"), "eyes": Color("69aade")},
	{"name": "CHARCOAL", "fur": Color("30333d"), "light": Color("575b68"), "belly": Color("9295a0"), "eyes": Color("eec55e")},
]

var cat_tex: Texture2D = preload("res://assets/cat.png")
var nugget_tex: Texture2D = preload("res://assets/nugget.png")
var hand_tex: Texture2D = preload("res://assets/hands_ai.png")
var font: Font = preload("res://assets/pixel_font.fnt")
var music: AudioStreamPlayer
var panic_music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var state := "title"
var previous_state := "title"
var clock := 0.0
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
var streak := 0
var longest := 0
var best := 0
var old_best := 0
var music_volume := 0.55
var sfx_volume := 0.7
var selected_track := 0
var shuffle_music := true
var cat_palette := 0
var cat_name_index := -1
var title_cat_selected := false
var cat_textures: Array[Texture2D] = []
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
	_build_cat_palettes()
	_select_cat(_random_choice(-1, CAT_PALETTES.size()))
	windowed_size = get_window().size
	windowed_position = get_window().position
	if fullscreen and not test_mode:
		get_window().mode = Window.MODE_FULLSCREEN
	_setup_audio()
	if smoke_requested:
		_run_smoke_test.call_deferred()
	queue_redraw()

func _setup_audio() -> void:
	for sound in ["catch", "combo", "miss", "throw", "tick", "finish"]:
		sounds[sound] = load("res://assets/%s.wav" % sound)
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

func _build_cat_palettes() -> void:
	var source := cat_tex.get_image()
	if source.is_compressed():
		source.decompress()
	for palette in CAT_PALETTES:
		var image := source.duplicate() as Image
		var replacements := {
			Color("f0974a").to_rgba32(): palette.fur,
			Color("ffc370").to_rgba32(): palette.light,
			Color("ffe7b8").to_rgba32(): palette.belly,
		}
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var pixel := source.get_pixel(x, y).to_rgba32()
				if replacements.has(pixel):
					image.set_pixel(x, y, replacements[pixel])
		_color_cat_eyes(image, palette.eyes)
		cat_textures.append(ImageTexture.create_from_image(image))

func _color_cat_eyes(image: Image, color: Color) -> void:
	# Paint only iris pixels inside the eye shapes, never shared outline colors.
	# Preserve the dark vertical pupil and the sprite's original white glints.
	for frame in [0, 2, 3, 4]:
		for center in [17, 32]:
			for y in range(22, 27):
				for dx in range(-2, 3):
					if dx != 0 and dx * dx / 4.0 + pow((y - 24) / 2.5, 2) <= 1:
						_iris_pixel(image, Vector2i(frame * 48 + center + dx, y), color)
	# Narrow, offended eyes stay below the angry eyebrows.
	for x in [15, 17, 31, 33]:
		for y in range(24, 27):
			_iris_pixel(image, Vector2i(5 * 48 + x, y), color)
	# Wild eyes have offset pupils; preserve the surrounding whites.
	for pupil in [Vector2i(18, 19), Vector2i(30, 21)]:
		for y in range(pupil.y + 1, pupil.y + 7):
			for dx in [-1, 1]:
				_iris_pixel(image, Vector2i(6 * 48 + pupil.x + dx, y), color)
	# Blink and sleeping frames intentionally have no visible irises.

func _iris_pixel(image: Image, position: Vector2i, color: Color) -> void:
	if image.get_pixelv(position).to_rgba32() == Color("422b3e").to_rgba32():
		image.set_pixelv(position, color)

func _select_cat(index: int) -> void:
	cat_palette = index
	cat_tex = cat_textures[index]
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
	for voice in voices:
		if not voice.playing:
			voice.stream = sounds[key]
			voice.pitch_scale = pitch
			voice.play()
			return

func _set_volumes() -> void:
	music.volume_db = linear_to_db(maxf(0.0001, music_volume * 0.45))
	panic_music.volume_db = linear_to_db(maxf(0.0001, music_volume * 0.10))
	for voice in voices:
		voice.volume_db = linear_to_db(maxf(0.0001, sfx_volume * 0.55))

func _load_settings(path: String = SAVE_PATH) -> void:
	if test_mode and path == SAVE_PATH:
		return
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		best = maxi(0, int(cfg.get_value("game", "best", 0)))
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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			_toggle_fullscreen()
		elif event.keycode == KEY_ESCAPE:
			if state == "playing":
				_pause()
			elif state == "paused":
				_resume()
			elif state == "settings":
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
				_select_cat(_random_choice(cat_palette, CAT_PALETTES.size()))
				title_cat_selected = true
				expression = 0.42
		"settings":
			previous_state = state
			state = "settings"
			_set_music_rate(1.0)
			music.stream_paused = false
			panic_music.stop()
		"back": _close_settings()
		"fullscreen": _toggle_fullscreen()
		"track_prev", "track_next":
			shuffle_music = false
			_select_track(selected_track + (1 if action == "track_next" else -1))
		"shuffle":
			shuffle_music = not shuffle_music
			if shuffle_music:
				_select_track(_random_choice(selected_track, TRACKS.size()))
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

func _start() -> void:
	state = "playing"
	remaining = ROUND_LENGTH
	_set_music_rate(1.0)
	if not title_cat_selected:
		_select_cat(_random_choice(cat_palette, CAT_PALETTES.size()))
	title_cat_selected = false
	if shuffle_music:
		_select_track(_random_choice(selected_track, TRACKS.size()))
	score = 0
	catches = 0
	misses = 0
	throws = 0
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
	cat = get_global_mouse_position().clamp(Vector2(20, 62), Vector2(620, 334))
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
	cat = get_global_mouse_position().clamp(Vector2(20, 62), Vector2(620, 334))
	cat_previous = cat
	music.stream_paused = false
	if remaining <= 10:
		_start_panic_music()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	buttons.clear()

func _finish() -> void:
	state = "results"
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
		cat = get_global_mouse_position().clamp(Vector2(20, 62), Vector2(620, 334))
		var velocity := (cat - cat_previous) / maxf(delta, 0.001)
		cat_velocity = cat_velocity.lerp(velocity, 1.0 - exp(-12 * delta))
		tilt = lerpf(tilt, clampf(cat_velocity.x / 2200, -0.24, 0.24), 1.0 - exp(-14 * delta))
		_step(delta)
	elif state == "title":
		expression = maxf(0, expression - delta)
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
		n.vel.y += n.gravity * delta
		n.pos += n.vel * delta
		n.rotation += n.spin * delta
		# Swept relative motion prevents tunneling during fast mouse swipes.
		if _swept_catch(before, n.pos, cat_previous, cat):
			_catch(n.pos)
			nuggets.remove_at(i)
		elif n.pos.x < -24 or n.pos.x > 664 or n.pos.y > 390 or n.pos.y < -100:
			_miss()
			nuggets.remove_at(i)
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

func _swept_catch(n0: Vector2, n1: Vector2, c0: Vector2, c1: Vector2) -> bool:
	var start := n0 - c0
	var end := n1 - c1
	return Geometry2D.get_closest_point_to_segment(Vector2.ZERO, start, end).length_squared() <= CATCH_RADIUS * CATCH_RADIUS

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
	hands.append({"pos": position, "angle": angle, "age": 0.0, "released": false, "edge": edge})

func _release(hand: Dictionary) -> void:
	throws += 1
	var origin: Vector2 = hand.pos + HAND_GRIPS[2].rotated(hand.angle)
	var target := Vector2(random.randf_range(210, 430), random.randf_range(160, 270))
	var flight := _difficulty_at(ROUND_LENGTH - remaining).y
	var gravity := 155.0
	var velocity := (target - origin) / flight - Vector2(0, gravity * flight * 0.5)
	nuggets.append({"pos": origin, "vel": velocity, "gravity": gravity, "age": 0.0, "rotation": random.randf_range(-PI, PI), "spin": random.randf_range(-5, 5)})
	_sound("throw", random.randf_range(0.85, 1.2))

func _multiplier() -> int:
	return mini(5, 1 + floori(streak / 5.0))

func _catch(position: Vector2) -> void:
	var earned := 10 * _multiplier()
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
	buttons.clear()
	_kitchen()
	if state == "title":
		_title()
	elif state == "results":
		_results()
	elif state == "settings":
		_settings()
	else:
		_playfield()
		if state == "paused":
			draw_rect(Rect2(0, 0, 640, 360), Color(0.16, 0.12, 0.20, 0.7))
			_panel(Rect2(206, 81, 228, 219))
			_text("SNACK BREAK", Vector2(320, 101), 16, GOLD, true)
			_text("YOUR NUGGETS CAN WAIT.", Vector2(320, 131), 8, CREAM, true)
			_button("KEEP MUNCHING", Rect2(240, 159, 160, 30), "resume", true)
			_button("SETTINGS", Rect2(240, 199, 160, 26), "settings")
			_button("BACK TO TITLE", Rect2(240, 235, 160, 26), "home")
			_text("ESC TO RESUME", Vector2(320, 278), 8, MINT, true)

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

func _cat_sprite(position: Vector2, frame: int, scale_factor: float = 1.5, angle: float = 0.0) -> void:
	var stretch := 1.0 + minf(cat_velocity.length() / 10000, 0.14) if state == "playing" else 1.0
	if expression > 0.30:
		stretch += 0.10
	draw_set_transform(position, angle, Vector2(scale_factor / stretch, scale_factor * stretch))
	# Frame mouth center is (24,31); rotation/scaling pivot stays at catch position.
	draw_texture_rect_region(cat_tex, Rect2(-24, -31, 48, 48), Rect2(frame * 48, 0, 48, 48))
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

func _playfield() -> void:
	for hand in hands:
		var age: float = hand.age
		var direction := Vector2.RIGHT.rotated(hand.angle)
		var slide := clampf(age / 0.18, 0, 1) * clampf((1.15 - age) / 0.2, 0, 1)
		var pos: Vector2 = hand.pos - direction * (1.0 - slide) * 58
		draw_set_transform(pos, hand.angle)
		var frame := 0 if age < 0.4 else (1 if age < 0.72 else 2)
		if not hand.released:
			draw_texture_rect(nugget_tex, Rect2(HAND_GRIPS[frame] - Vector2(8, 8), Vector2(16, 16)), false)
		draw_texture_rect_region(hand_tex, Rect2(-32, -24, 64, 48), Rect2(frame * 64, 0, 64, 48))
		draw_set_transform(Vector2.ZERO)
		if not hand.released and age > 0.3:
			_text("!", pos + direction * 43 + Vector2(0, -8), 16, INK, true)
	for n in nuggets:
		draw_circle(n.pos + Vector2(3, 7), 8, Color(0.25, 0.22, 0.25, 0.12))
		draw_set_transform(n.pos, n.rotation)
		draw_texture_rect(nugget_tex, Rect2(-10, -10, 20, 20), false)
		draw_set_transform(Vector2.ZERO)
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
	_text("X%d" % _multiplier(), Vector2(173, 24), 16, GOLD)
	for i in range(5):
		draw_rect(Rect2(219 + i * 7, 31, 5, 5), GOLD if i < streak % 5 or _multiplier() == 5 else Color("725866"))
	_text("%02d" % ceili(remaining), Vector2(320, 15), 24, PINK if remaining <= 10 else CREAM, true)
	_text("BEST %05d" % best, Vector2(398, 11), 8, MINT)
	_text("%d CAUGHT" % catches, Vector2(398, 28), 8)
	_button("II", Rect2(588, 11, 34, 27), "pause")
	# Bottom prompt sits on the counter.
	_text("MOUSE TO MUNCH", Vector2(12, 345), 8, INK)
	_text("%s / %s" % [CAT_NAMES[cat_name_index], CAT_PALETTES[cat_palette].name], Vector2(320, 345), 8, INK, true)
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
	_cat_sprite(Vector2(495, 162 + sin(clock * 2.5) * 4), 6 if expression > 0 or fmod(clock, 5) > 4 else (1 if fmod(clock, 4) < 0.15 else 0), 2.8, sin(clock * 1.8) * 0.06)
	_text(CAT_NAMES[cat_name_index], Vector2(495, 223), 8, GOLD, true)
	_text("CLICK TO MEET ANOTHER CAT", Vector2(495, 237), 8, MINT if hovered else CREAM, true)
	draw_set_transform(Vector2(558, 88 + sin(clock * 3) * 4), clock * 0.7)
	draw_texture_rect(nugget_tex, Rect2(-13, -13, 26, 26), false)
	draw_set_transform(Vector2.ZERO)
	_text("MOVE YOUR MOUSE. CATCH THE NUGGETS.", Vector2(224, 205), 8, CREAM, true)
	_text("60 SECONDS. ONE VERY HUNGRY CAT.", Vector2(224, 221), 8, MINT, true)
	_button("LET'S EAT!", Rect2(100, 247, 245, 36), "start", true)
	_button("SETTINGS", Rect2(366, 252, 105, 26), "settings")
	_button("QUIT", Rect2(483, 252, 78, 26), "quit")
	_text("BEST SNACK SCORE: %05d" % best, Vector2(320, 303), 8, GOLD, true)
	_text("ENTER: START  /  ESC: PAUSE  /  F11: FULLSCREEN", Vector2(320, 348), 8, INK, true)

func _results() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.2, 0.17, 0.23, 0.3))
	_panel(Rect2(113, 25, 414, 309))
	_text("A CAT WELL FED.", Vector2(320, 43), 24, GOLD, true)
	_text("NEW PERSONAL BEST!" if score > old_best else "A NOBLE DAY OF SNACKING.", Vector2(320, 77), 8, PINK, true)
	_cat_sprite(Vector2(200, 151), 3 if catches > 0 else 5, 2.1, sin(clock * 2) * 0.04)
	_text(CAT_NAMES[cat_name_index], Vector2(200, 177), 8, MINT, true)
	_text("FINAL SCORE", Vector2(376, 102), 8, MINT, true)
	_text("%05d" % score, Vector2(376, 123), 32, CREAM, true)
	_text("BEST %05d" % best, Vector2(376, 164), 8, GOLD, true)
	draw_line(Vector2(145, 191), Vector2(495, 191), Color("796274"))
	_text("CAUGHT", Vector2(185, 205), 8, MINT, true)
	_text("%d" % catches, Vector2(185, 225), 16, CREAM, true)
	_text("MISSED", Vector2(320, 205), 8, MINT, true)
	_text("%d" % misses, Vector2(320, 225), 16, CREAM, true)
	_text("BEST STREAK", Vector2(449, 205), 8, MINT, true)
	_text("%d" % longest, Vector2(449, 225), 16, CREAM, true)
	_button("ANOTHER HELPING", Rect2(146, 270, 210, 34), "start", true)
	_button("TITLE", Rect2(375, 274, 118, 26), "home")

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
	for i in range(2):
		var y := 164 + i * 39
		var value := music_volume if i == 0 else sfx_volume
		var key := "music" if i == 0 else "sfx"
		_text("MUSIC" if i == 0 else "SOUNDS", Vector2(180, y+8), 8)
		_button("-", Rect2(253, y, 28, 26), key + "_down")
		for j in range(10):
			draw_rect(Rect2(294 + j * 10, y+8, 7, 11), GOLD if j < roundi(value*10) else Color("725866"))
		_button("+", Rect2(410, y, 28, 26), key + "_up")
	_button("FULLSCREEN: ON" if fullscreen else "FULLSCREEN: OFF", Rect2(181, 252, 202, 26), "fullscreen")
	_text("F11 / ALT+ENTER", Vector2(396, 261), 8, MINT)
	_button("ALL GOOD", Rect2(251, 297, 138, 28), "back", true)

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
	assert(seen_tracks.size() == TRACKS.size() and seen_cats.size() == CAT_PALETTES.size())
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
	var original := cat_textures[0].get_image()
	for palette_index in range(cat_textures.size()):
		var image := cat_textures[palette_index].get_image()
		assert(image.get_size() == original.get_size() and image.get_pixel(0, 0).a == 0)
		assert(image.get_pixel(16, 24).to_rgba32() == CAT_PALETTES[palette_index].eyes.to_rgba32())
		assert(image.get_pixel(17, 24).to_rgba32() == Color("422b3e").to_rgba32())
		for frame in range(8):
			var feature := Vector2i(16, 22) if frame in [1, 5, 7] else Vector2i(15, 20)
			feature.x += frame * 48
			assert(image.get_pixelv(feature) == original.get_pixelv(feature))
	# Exercise actual persistence against a disposable project-local file.
	if not OS.has_feature("standalone"):
		DirAccess.make_dir_recursive_absolute("res://build")
		best = 1234
		music_volume = 0.3
		sfx_volume = 0.8
		selected_track = 2
		shuffle_music = false
		fullscreen = true
		_save_settings("res://build/test_save.cfg")
		best = 0
		music_volume = 0
		sfx_volume = 0
		selected_track = 0
		shuffle_music = true
		fullscreen = false
		_load_settings("res://build/test_save.cfg")
		assert(best == 1234 and is_equal_approx(music_volume, 0.3) and is_equal_approx(sfx_volume, 0.8))
		assert(selected_track == 2 and fullscreen and not shuffle_music)
		DirAccess.remove_absolute("res://build/test_save.cfg")
	print("SMOKE TEST PASSED: gameplay (%d misses), %d tracks, 48 randomized rounds without repeats, %d cat palettes, preserved eyes/transparency, manual selection, saved shuffle preference." % [simulated_misses, TRACKS.size(), CAT_PALETTES.size()])
	get_tree().quit(0)
