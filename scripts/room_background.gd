extends RefCounted
## Quiet, pixel-aligned scenery. Only choose_next consumes randomness, never draw.

const NAMES := ["SAGE KITCHEN", "STRAWBERRY CAFE", "SUNROOM", "MOONLIT STUDY"]
# Wall, wall detail, wood, wood shadow, trim, sky, distant scenery, upholstery.
const PALETTES := [
	["cedbca", "bdcebb", "adb8a0", "859886", "f2e6cd", "b8d7d5", "9bb9a5", "d5b8a1"],
	["e3c9c5", "d5b9b6", "bc9f98", "9d8584", "f7e4cf", "d4d7dd", "b5bac6", "b8c7ba"],
	["dce0c7", "ccd2b9", "b7b89a", "939b80", "f3e9cc", "c2dcd7", "9fbea8", "d7c59f"],
	["bfc4d5", "adb4c9", "9e9db5", "7f819c", "ded9d9", "8e9bb9", "7d8faa", "b6a6ba"],
]

var index := -1
var variation := 0
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func choose_next() -> void:
	index = rng.randi_range(0, NAMES.size() - 1) if index < 0 else (index + rng.randi_range(1, NAMES.size() - 1)) % NAMES.size()
	variation = rng.randi_range(0, 3)

func draw(c: CanvasItem) -> void:
	var p: Array = PALETTES[maxi(index, 0)]
	_rect(c, 0, 0, 640, 360, p[0])
	# Wallpaper stays low contrast so flying food remains easy to read.
	if index == 0:
		for y in range(56, 290, 28):
			_rect(c, 0, y, 640, 1, p[1])
			for x in range(-24 if y % 56 == 0 else 0, 640, 48):
				_rect(c, x, y, 1, 28, p[1])
	elif index == 1:
		for x in range(0, 640, 24):
			_rect(c, x, 52, 8, 240, p[1])
	else:
		for x in range(16, 640, 32):
			for y in range(68, 278, 32):
				_rect(c, x, y, 2, 3, p[1])
	# Picture rail, wainscoting and floor give every room depth.
	_rect(c, 0, 50, 640, 3, p[4])
	_rect(c, 0, 254, 640, 48, p[2])
	for x in range(12, 640, 52):
		c.draw_rect(Rect2(x, 264, 40, 28), Color(p[3]), false, 1)
	_rect(c, 0, 250, 640, 5, p[4])
	_rect(c, 0, 300, 640, 60, p[2])
	_rect(c, 0, 300, 640, 4, p[3])
	for y in range(318, 360, 18):
		_rect(c, 0, y, 640, 1, p[3])
		for x in range(30 if y % 36 == 12 else 90, 640, 120):
			_rect(c, x, y - 17, 1, 17, p[3])
	match index:
		0:
			_window(c, 248, 77, 144, 130, p)
			_shelf(c, 46, 139, 139, p)
			for i in range(3):
				_jar(c, 61 + i * 38, 110, p, i)
			_shelf(c, 458, 146, 129, p)
			_plant(c, 546, 145, p, 1)
			_jar(c, 478, 117, p, variation)
			_picture(c, 94, 181, p)
			_counter(c, p)
		1:
			_window(c, 65, 79, 146, 131, p)
			# Scalloped cafe awning and a framed menu illustration.
			for x in range(59, 211, 19):
				_rect(c, x, 75, 19, 18, p[7] if x % 2 == 0 else p[4])
				_rect(c, x + 2, 93, 15, 4, p[7] if x % 2 == 0 else p[4])
			_rect(c, 446, 85, 111, 106, p[3])
			_rect(c, 451, 90, 101, 96, p[2])
			for i in range(4):
				_rect(c, 465, 105 + i * 18, 12, 7, p[4])
				_rect(c, 486, 107 + i * 18, 49 - i * 7, 2, p[4])
			_sofa(c, 420, 255, p)
			_table(c, 86, 272, p)
			_plant(c, 114, 272, p, 0)
		2:
			_window(c, 207, 69, 226, 153, p)
			_shelf(c, 36, 131, 132, p)
			_plant(c, 64, 130, p, 0)
			_plant(c, 133, 130, p, 1)
			_shelf(c, 470, 173, 130, p)
			_plant(c, 498, 172, p, 1)
			_plant(c, 570, 172, p, 0)
			_plant(c, 63, 310, p, 2)
			_sofa(c, 429, 267, p)
			_rect(c, 213, 316, 214, 27, p[7])
			for x in range(219, 424, 10):
				_rect(c, x, 319, 2, 21, p[4])
		3:
			_window(c, 259, 74, 133, 142, p)
			# Full bookcase with varied muted book spines.
			_rect(c, 41, 78, 135, 226, p[3])
			_rect(c, 47, 84, 123, 214, p[2])
			for row in range(4):
				for book in range(9):
					var h := 24 + (book * 7 + row * 3 + variation * 5) % 15
					var x := 54 + book * 12
					var y := 128 + row * 51 - h
					_rect(c, x, y, 9, h, p[[0, 4, 7][(book + row) % 3]])
					_rect(c, x + 2, y + 5, 5, 2, p[2])
				_shelf(c, 44, 128 + row * 51, 129, p)
			_sofa(c, 433, 257, p)
			_rect(c, 572, 174, 4, 128, p[3])
			_rect(c, 554, 301, 39, 4, p[3])
			_rect(c, 554, 153, 40, 28, p[4])
			_rect(c, 559, 146, 30, 8, p[4])

func _rect(c: CanvasItem, x: float, y: float, w: float, h: float, color: String) -> void:
	c.draw_rect(Rect2(x, y, w, h), Color(color))

func _window(c: CanvasItem, x: int, y: int, w: int, h: int, p: Array) -> void:
	_rect(c, x - 3, y - 3, w + 8, h + 10, p[3])
	_rect(c, x, y, w, h, p[4])
	_rect(c, x + 6, y + 6, w - 12, h - 12, p[5])
	var sky_light: String = "eee5c9" if index != 3 else "dfdecd"
	c.draw_circle(Vector2(x + w - 30, y + 29), 11, Color(sky_light))
	if index == 3:
		c.draw_circle(Vector2(x + w - 25, y + 25), 10, Color(p[5]))
		for i in range(7):
			_rect(c, x + 13 + (i * 29) % (w - 28), y + 15 + (i * 17) % 49, 2, 2, sky_light)
	else:
		_rect(c, x + 16 + variation * 4, y + 30, 32, 5, p[4])
		_rect(c, x + 24 + variation * 4, y + 25, 17, 6, p[4])
	for i in range(5):
		var hill_x := x + 6 + i * (w - 12) / 5
		_rect(c, hill_x, y + h - 39 - (i % 3) * 6, (w - 12) / 5 + 1, 33 + (i % 3) * 6, p[6])
	_rect(c, x + w / 2 - 2, y, 5, h, p[4])
	_rect(c, x, y + h / 2, w, 5, p[4])
	_rect(c, x - 8, y + h, w + 16, 6, p[4])
	# Soft fabric curtains frame the view, leaving the center open.
	_rect(c, x - 12, y - 8, w + 24, 3, p[3])
	for edge in [x - 9, x + w - 8]:
		_rect(c, edge, y - 5, 17, h - 10, p[7])
		_rect(c, edge + 4, y - 3, 2, h - 14, p[4])
		_rect(c, edge, y + h - 31, 17, 4, p[3])

func _shelf(c: CanvasItem, x: int, y: int, w: int, p: Array) -> void:
	_rect(c, x, y, w, 5, p[4])
	_rect(c, x, y + 5, w, 3, p[3])
	_rect(c, x + 9, y + 8, 4, 9, p[2])
	_rect(c, x + w - 13, y + 8, 4, 9, p[2])

func _jar(c: CanvasItem, x: int, y: int, p: Array, style: int) -> void:
	_rect(c, x, y, 22, 27, p[7] if style % 2 == 0 else p[2])
	_rect(c, x - 1, y - 3, 24, 5, p[3])
	_rect(c, x + 4, y + 10, 14, 9, p[4])
	_rect(c, x + 3, y + 3, 2, 5, p[4])

func _plant(c: CanvasItem, x: int, y: int, p: Array, size: int) -> void:
	var height := 30 + size * 15
	_rect(c, x - 1, y - height - 16, 3, height, p[3])
	for i in range(4 + size):
		var side := -1 if i % 2 == 0 else 1
		var leaf_y := y - 23 - i * 8
		_rect(c, x - 15 if side < 0 else x + 2, leaf_y, 15, 6, p[6])
		_rect(c, x - 12 if side < 0 else x + 2, leaf_y - 3, 10, 3, p[6])
	_rect(c, x - 11, y - 19, 24, 19, p[7])
	_rect(c, x - 14, y - 21, 30, 5, p[4])
	_rect(c, x - 7, y - 13, 3, 10, p[4])

func _picture(c: CanvasItem, x: int, y: int, p: Array) -> void:
	_rect(c, x, y, 48, 47, p[3])
	_rect(c, x + 3, y + 3, 42, 41, p[4])
	_rect(c, x + 8, y + 8, 32, 30, p[5])
	_rect(c, x + 13, y + 24, 22, 14, p[6])
	c.draw_circle(Vector2(x + 29, y + 16), 5, Color(p[7]))

func _sofa(c: CanvasItem, x: int, y: int, p: Array) -> void:
	_rect(c, x + 7, y + 41, 7, 12, p[3])
	_rect(c, x + 116, y + 41, 7, 12, p[3])
	_rect(c, x + 3, y - 26, 124, 66, p[3])
	_rect(c, x + 7, y - 22, 116, 50, p[7])
	_rect(c, x + 11, y + 17, 108, 18, p[4])
	_rect(c, x, y, 12, 43, p[7])
	_rect(c, x + 118, y, 12, 43, p[7])
	_rect(c, x + 26 + variation * 17, y - 12, 24, 25, p[0])
	_rect(c, x + 30 + variation * 17, y - 8, 16, 17, p[1])

func _table(c: CanvasItem, x: int, y: int, p: Array) -> void:
	_rect(c, x + 12, y + 6, 6, 42, p[3])
	_rect(c, x + 90, y + 6, 6, 42, p[3])
	_rect(c, x, y, 109, 6, p[4])
	_rect(c, x + 4, y + 6, 101, 5, p[2])

func _counter(c: CanvasItem, p: Array) -> void:
	_rect(c, 0, 306, 640, 54, p[2])
	_rect(c, 0, 299, 640, 7, p[4])
	_rect(c, 0, 306, 640, 4, p[3])
	for x in range(8, 640, 106):
		c.draw_rect(Rect2(x, 318, 94, 39), Color(p[4]), false, 2)
		_rect(c, x + 39, 326, 17, 3, p[3])
	_rect(c, 560, 301, 32, 45, p[7])
	for x in range(564, 592, 8):
		_rect(c, x, 303, 2, 41, p[4])
