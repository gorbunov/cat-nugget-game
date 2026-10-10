extends RefCounted
## API-derived pixel scenery. Selection alone consumes its independent RNG.

const NAMES := ["SAGE KITCHEN", "STRAWBERRY CAFE", "SUNROOM", "MOONLIT STUDY"]
const ATLAS := preload("res://assets/rooms.png")

var index := -1
var variation := 0
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func choose_next() -> void:
	index = rng.randi_range(0, NAMES.size() - 1) if index < 0 else (index + rng.randi_range(1, NAMES.size() - 1)) % NAMES.size()
	variation = rng.randi_range(0, 1)

func draw(c: CanvasItem) -> void:
	var selected := maxi(index, 0)
	# Alternate furniture placement without changing the approved colors/contrast.
	if variation % 2 == 1:
		c.draw_set_transform(Vector2(640, 0), 0, Vector2(-1, 1))
	c.draw_texture_rect_region(ATLAS, Rect2(0, 0, 640, 360), Rect2((selected % 2) * 640, (selected / 2) * 360, 640, 360))
	c.draw_set_transform(Vector2.ZERO)
