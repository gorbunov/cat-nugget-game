extends SceneTree
## Integration checks for multi-chomp food, hazards, buffs and rare screen collection.

func _initialize() -> void:
	_run.call_deferred()

func _reset(game: Node2D) -> void:
	game._start_round()
	game.spawn_in = 1000
	game.rare_spawn_times.clear()
	game.remaining = 40
	game.cat = Vector2(320, 180)
	game.cat_previous = game.cat

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.random.seed = 71428
	if not _check_bite_art(game):
		quit(1)
		return
	_reset(game)
	var big = game._make_nugget("big", game.cat, Vector2.ZERO, 0)
	game.nuggets.append(big)
	game._step(0.016)
	assert(big.hp == 2 and game.catches == 0 and game.score == 0)
	game._step(0.08)
	assert(big.hp == 2) # No frame-rate-dependent instant eating.
	game.cat = Vector2(20, 300)
	game.cat_previous = game.cat
	game._step(0.25)
	assert(big.hp == 2) # Partial progress is retained, but no remote chomps.
	game.cat = big.pos
	game.cat_previous = game.cat
	game._step(0.01)
	assert(big.hp == 1 and game.catches == 0)
	game._step(0.21)
	assert(game.nuggets.is_empty() and game.catches == 1 and game.score == 30)

	game.nuggets.append(game._make_nugget("burnt", Vector2(670, 100), Vector2.ZERO, 0))
	game._step(0.02)
	assert(game.misses == 0 and game.streak == 1 and game.burnt_eaten == 0)
	game.score = 80
	game.streak = 7
	game.golden_bonus = 2
	game.nuggets.append(game._make_nugget("burnt", game.cat, Vector2.ZERO, 0))
	game._step(0.02)
	assert(game.score == 50 and game.streak == 0 and game.golden_bonus == 0 and game.burnt_eaten == 1)
	game.score = 10
	game._eat_nugget(game._make_nugget("burnt", game.cat))
	assert(game.score == 0 and game.catches == 1)

	_reset(game)
	game.nuggets.append(game._make_nugget("golden", game.cat, Vector2.ZERO, 0))
	game._step(0.02)
	assert(game.score == 20 and game.catches == 1 and game.streak == 1 and game._multiplier() == 2)
	for i in range(10):
		game._eat_nugget(game._make_nugget("golden", game.cat))
	assert(game._multiplier() == 5)
	game._miss()
	assert(game._multiplier() == 1 and game.golden_bonus == 0)

	_reset(game)
	game.nuggets.append(game._make_nugget("big_golden", game.cat, Vector2.ZERO, 0))
	game.nuggets.append(game._make_nugget("regular", Vector2(100, 100), Vector2.ZERO, 0))
	game.nuggets.append(game._make_nugget("big", Vector2(520, 180), Vector2.ZERO, 0))
	game.nuggets.append(game._make_nugget("golden", Vector2(400, 100), Vector2.ZERO, 0))
	game.nuggets.append(game._make_nugget("burnt", Vector2(40, 80), Vector2.ZERO, 0))
	game._step(0.016)
	game._step(0.21)
	assert(game.catches == 0 and game.nuggets.size() == 5)
	game._step(0.21)
	assert(game.nuggets.size() == 1 and game.nuggets[0].kind == "burnt")
	assert(game.catches == 4 and game.score == 200 and game.golden_bonus == 1)
	assert(not game.sweep_pending and game.sweep_time > 0 and game.burnt_eaten == 0)
	# A second rare nugget collected by the sweep cannot recurse or double-score.
	_reset(game)
	game.nuggets.append(game._make_nugget("big_golden", Vector2(100, 100)))
	game.nuggets.append(game._make_nugget("burnt", Vector2(40, 80)))
	game._eat_nugget(game._make_nugget("big_golden", game.cat))
	game._collect_flying_nuggets()
	assert(game.score == 200 and game.catches == 2 and game.nuggets.size() == 1 and not game.sweep_pending)

	var rare_rounds := 0
	var double_rounds := 0
	for i in range(20000):
		game._plan_rare_spawns()
		assert(game.rare_spawn_times.size() <= 2)
		if game.rare_spawn_times.size() > 0:
			rare_rounds += 1
			assert(game.rare_spawn_times[0] >= 18 and game.rare_spawn_times[0] <= 34)
		if game.rare_spawn_times.size() == 2:
			double_rounds += 1
			assert(game.rare_spawn_times[1] >= 36 and game.rare_spawn_times[1] <= 38)
	assert(rare_rounds > 3100 and rare_rounds < 4100 and double_rounds > 0 and double_rounds < 45)
	game.rare_spawn_times.clear()
	game.remaining = 30
	var counts := {"regular": 0, "big": 0, "burnt": 0, "golden": 0}
	for i in range(20000):
		counts[game._next_nugget_kind()] += 1
	assert(absf(counts.regular / 20000.0 - 0.70) < 0.02)
	assert(absf(counts.big / 20000.0 - 0.15) < 0.02)
	assert(absf(counts.burnt / 20000.0 - 0.11) < 0.02)
	assert(absf(counts.golden / 20000.0 - 0.04) < 0.01)
	game.remaining = 59
	for i in range(100):
		assert(game._next_nugget_kind() == "regular")
	game._start_round()
	assert(game.burnt_eaten == 0 and game.golden_bonus == 0 and game.sweep_time == 0)
	print("SPECIAL NUGGET TEST PASSED: three chomps, retained progress, burnt avoidance/penalty, golden tiers, safe sweep, double-rare safety, warm-up and replay.")
	print("ODDS CHECK (20,000 samples): ordinary throws=%s; rare rounds=%d; double-rare rounds=%d" % [counts, rare_rounds, double_rounds])
	_check_boss(game)
	quit()

func _check_boss(game: Node2D) -> void:
	_reset(game)
	game.remaining = game.BOSS_DURATION + 0.01
	game.nuggets.append(game._make_nugget("burnt", Vector2(50, 50)))
	game.sweep_pending = true
	game.cat = Vector2(-500, -500)
	game.cat_previous = game.cat
	game._step(0.02)
	assert(game.round_phase == game.RoundPhase.BOSS)
	assert(game.nuggets.is_empty() and game.hands.is_empty() and not game.sweep_pending)
	assert(game.misses == 0 and game.burnt_eaten == 0)
	game._step(game.BOSS_DURATION + 1)
	assert(game.state == game.Screen.RESULTS and not game.boss_defeated and game.score == 0)
	for fps in [30, 60, 144]:
		_reset(game)
		game.remaining = game.BOSS_DURATION
		game._start_boss()
		var dt: float = 1.0 / fps
		var duration := 0.0
		while not game.boss_defeated and duration < 9:
			game.cat_previous = game._boss_position(game.boss_age)
			game.cat = game._boss_position(game.boss_age + dt)
			game._step(dt)
			duration += dt
		assert(game.boss_defeated and game.boss_hp == 0 and game.score == 500)
		assert(absf(duration - 5.9375) < 0.05)
		var frozen: float = game.remaining
		game._pause()
		game._step(4)
		assert(game.celebration_time == 0 and game.remaining == frozen)
		game._resume()
		game._step(2.9)
		assert(game.state == game.Screen.PLAYING and game.score == 500 and game.remaining == frozen)
		game._step(0.11)
		assert(game.state == game.Screen.RESULTS and game.boss_defeated)
	_reset(game)
	game.remaining = game.BOSS_DURATION
	game._start_boss()
	game.cat = game.boss_pos
	game.cat_previous = game.cat
	game._step(0.2)
	assert(game.boss_hp == 40 and game.boss_contact > 0.19)
	game.cat = Vector2(-500, -500)
	game.cat_previous = game.cat
	game._step(0.2)
	assert(game.boss_contact > 0.19 and game.boss_bite_progress == 0)
	game._step(0.4)
	assert(game.boss_contact == 0 and game.boss_hp == 40)
	game._start_round()
	assert(not game.boss_defeated and game.boss_hp == 40 and game.round_phase == game.RoundPhase.CATCHING)
	_check_boss_wind_down(game)
	_check_boss_silhouette(game)
	print("BOSS CHECK: clean transition, timeout, 30/60/144 FPS bite ramp, single bonus, pause, celebration, cooling and replay.")

func _check_boss_wind_down(game: Node2D) -> void:
	_reset(game)
	game.cat = Vector2(-500, -500)
	game.cat_previous = game.cat
	game.remaining = game.BOSS_DURATION + game.THROW_WIND_DOWN
	game.spawn_in = -1
	game._spawn_hand() # Last hand is allowed to finish its wind-up.
	for i in range(239):
		game._step(1.0 / 60.0)
		if i == 65:
			assert(game.boss_warning_second == 3 and game.throws == 1)
	assert(game.round_phase == game.RoundPhase.CATCHING)
	assert(game.nuggets.is_empty() and game.hands.is_empty() and game.throws == 1)
	assert(game.misses == 1)
	game._step(0.02)
	assert(game.round_phase == game.RoundPhase.BOSS)
	var age: float = game.boss_age
	game._pause()
	game._step(1)
	assert(game.boss_age == age)
	game._resume()
	# Check all four wall reflections stay bounded and preserve speed.
	var direction_changes := Vector2i.ZERO
	var previous_velocity := Vector2.ZERO
	for i in range(1, 1500):
		var before: Vector2 = game._boss_position((i - 1) * 0.01)
		var after: Vector2 = game._boss_position(i * 0.01)
		assert(game.BOSS_BOUNDS.grow(0.001).has_point(after))
		var velocity := after - before
		assert(velocity.length() <= game.BOSS_VELOCITY.length() * 0.01001)
		if previous_velocity.x * velocity.x < 0: direction_changes.x += 1
		if previous_velocity.y * velocity.y < 0: direction_changes.y += 1
		previous_velocity = velocity
	assert(direction_changes.x >= 2 and direction_changes.y >= 2)
	print("BOSS PACING: four-second throw wind-down, three-second warning, natural food exit, pause and wall reflections.")

func _check_boss_silhouette(game: Node2D) -> void:
	game.boss_pos = Vector2(320, 190)
	game.boss_age = 0
	game.expression = 0
	for hp in [40, 26, 12]:
		game.boss_hp = hp
		var mask: BitMap = game.boss_masks[game._boss_stage() - 1]
		var outer_hits := 0
		for y in range(32):
			for x in range(32):
				if mask.get_bit(x, y):
					var offset: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(16, 16)) * game.BOSS_SIZE / 32.0
					assert(game._boss_contains_mouth(game.boss_pos + offset))
					if offset.length() > 24: outer_hits += 1
		assert(outer_hits > 0) # Visible food beyond the old target is edible.
		assert(not game._boss_contains_mouth(game.boss_pos + Vector2(80, 0)))
		assert(not game._boss_contains_mouth(game.boss_pos + Vector2(47, 47)))
	print("BOSS SILHOUETTE: every visible pixel catches at all bite stages; empty space does not.")

func _check_bite_art(game: Node2D) -> bool:
	var full: Image = game.nugget_tex.get_image()
	var bitten: Image = game.nugget_bite_tex.get_image()
	assert(bitten.get_size() == Vector2i(128, 32))
	for kind in ["big", "big_golden"]:
		var original := full.get_region(Rect2i(game._nugget_region(kind)))
		var previous := original
		var full_area := _opaque_area(original)
		for hp in [2, 1]:
			var tile := bitten.get_region(Rect2i(game._nugget_region(kind, 0, hp)))
			var area := _opaque_area(tile)
			assert(area < _opaque_area(previous) * 0.9 and area > full_area * 0.25)
			var interior := false
			for y in range(32):
				for x in range(32):
					var pixel := tile.get_pixel(x, y)
					# A second bite cannot restore any previously eaten pixels.
					assert(pixel.a <= previous.get_pixel(x, y).a)
					if pixel.a > 0.5 and pixel.r > 0.95 and pixel.g > 0.85 and pixel.b > 0.65:
						interior = true
			assert(interior)
			previous = tile
	print("BITE ART CHECK: progressively missing silhouette, pale interiors, both big nugget kinds.")
	return true

func _opaque_area(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.5:
				count += 1
	return count
