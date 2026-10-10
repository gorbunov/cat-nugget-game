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
			assert(game.rare_spawn_times[0] >= 18 and game.rare_spawn_times[0] <= 42)
		if game.rare_spawn_times.size() == 2:
			double_rounds += 1
			assert(game.rare_spawn_times[1] >= 45 and game.rare_spawn_times[1] <= 53)
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
	quit()
