extends Node2D
## Screen-space framing; gameplay remains in a fixed 640x360 local canvas.

const CANVAS := Vector2(640, 360)
const FONT := preload("res://assets/pixel_font.fnt")
var screen_size := CANVAS
var safe_rect := Rect2(Vector2.ZERO, CANVAS)
var play_rect := safe_rect
var portrait := false

func configure(size: Vector2, safe: Rect2) -> void:
	screen_size = size
	safe_rect = safe
	portrait = safe.size.y > safe.size.x
	var factor := minf(safe.size.x / CANVAS.x, safe.size.y / CANVAS.y)
	play_rect = Rect2(safe.get_center() - CANVAS * factor / 2, CANVAS * factor)
	queue_redraw()

func bottom_drag_contains(local_pointer: Vector2) -> bool:
	var pointer := play_rect.position + local_pointer * (play_rect.size.x / CANVAS.x)
	return not portrait and safe_rect.has_point(pointer) and local_pointer.x >= 0 and local_pointer.x < CANVAS.x and local_pointer.y >= CANVAS.y

static func device_safe_rect(size: Vector2) -> Rect2:
	var whole := Rect2(Vector2.ZERO, size)
	if OS.has_feature("web"):
		var raw = JavaScriptBridge.eval("window.nuggetSafeInsets ? JSON.stringify(window.nuggetSafeInsets()) : '[0,0,0,0]'")
		var insets = JSON.parse_string(str(raw))
		if insets is Array and insets.size() == 4:
			# Insets are fractions of the CSS canvas, independent of device pixel ratio.
			return Rect2(Vector2(insets[3] * size.x, insets[0] * size.y),
				size - Vector2((insets[1] + insets[3]) * size.x, (insets[0] + insets[2]) * size.y))
	elif OS.has_feature("mobile"):
		var area := Rect2(DisplayServer.get_display_safe_area())
		area.position -= Vector2(DisplayServer.window_get_position())
		var clipped := whole.intersection(area)
		if clipped.has_area():
			return clipped
	return whole

func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, screen_size)
	var regions: Array[Rect2] = [
		Rect2(0, 0, screen_size.x, play_rect.position.y),
		Rect2(0, play_rect.end.y, screen_size.x, screen_size.y - play_rect.end.y),
		Rect2(0, play_rect.position.y, play_rect.position.x, play_rect.size.y),
		Rect2(play_rect.end.x, play_rect.position.y, screen_size.x - play_rect.end.x, play_rect.size.y),
	]
	if portrait:
		regions = [bounds]
	for region in regions:
		draw_rect(region, Color("2b2332"))
	# Quiet pixel diamonds, clipped to the margins rather than the game.
	var unit := maxf(1, minf(screen_size.x, screen_size.y) / 360)
	var spacing := 32 * unit
	for y in range(ceili(screen_size.y / spacing)):
		for x in range(ceili(screen_size.x / spacing)):
			var point := Vector2((x + 0.5 + 0.5 * (y % 2)) * spacing, (y + 0.5) * spacing)
			var mark := Rect2(point - Vector2.ONE * 3 * unit, Vector2.ONE * 6 * unit)
			for region in regions:
				if region.encloses(mark):
					draw_rect(Rect2(point - Vector2(unit, 3 * unit), Vector2(2 * unit, 6 * unit)), Color("3b2d40"))
					draw_rect(Rect2(point - Vector2(3 * unit, unit), Vector2(6 * unit, 2 * unit)), Color("3b2d40"))
	if not portrait:
		draw_rect(play_rect.grow(unit), Color("725866"), false, unit * 2)
		return
	var factor := minf(safe_rect.size.x / 340, safe_rect.size.y / 440)
	draw_set_transform(safe_rect.get_center(), 0, Vector2.ONE * factor)
	draw_rect(Rect2(-62, -95, 124, 72), Color("ed91a5"), false, 4)
	draw_rect(Rect2(-50, -83, 94, 48), Color("423044"))
	draw_rect(Rect2(50, -65, 4, 12), Color("fff0cd"))
	_centered("NUGGET CAT", -128, 16, Color("ffc568"))
	_centered("ROTATE TO LANDSCAPE", 18, 8, Color("fff0cd"))
	_centered("MORE ROOM FOR SNACKS!", 42, 8, Color("9bd2bc"))
	draw_set_transform(Vector2.ZERO)

func _centered(text: String, y: float, size: int, color: Color) -> void:
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(FONT, Vector2(-width / 2, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
