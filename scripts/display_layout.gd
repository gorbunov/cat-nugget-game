extends Node2D
## Screen-space framing; gameplay remains in a fixed 640x360 local canvas.

const CANVAS := Vector2(640, 360)
const FONT := preload("res://assets/pixel_font.fnt")
const SURROUND := Color("302735")
const TRIM := Color("806271")
const LIP := Color("ba9680")
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
	var unit := play_rect.size.x / CANVAS.x
	if portrait:
		unit = minf(screen_size.x / 340, screen_size.y / 440)
	for region in regions:
		if region.has_area():
			draw_rect(region, SURROUND)
	if not portrait:
		for i in range(regions.size()):
			_draw_margin_accents(regions[i], unit, i)
	if not portrait:
		# Recessed room surround: stepped shadow, plum molding and warm lip.
		# All substantial trim sits OUTSIDE gameplay, including the bottom drag area.
		for step in range(9, 2, -1):
			draw_rect(play_rect.grow(step * unit), Color(0.08, 0.05, 0.09, (10 - step) * 0.035), false, 2 * unit)
		draw_rect(play_rect.grow(3 * unit), SURROUND.darkened(0.28), false, 4 * unit)
		draw_rect(play_rect.grow(2 * unit), TRIM, false, unit)
		draw_rect(play_rect.grow(0.5 * unit), LIP, false, unit)
		return
	var factor := minf(safe_rect.size.x / 340, safe_rect.size.y / 440)
	var panel := Rect2(safe_rect.get_center() + Vector2(-152, -162) * factor, Vector2(304, 240) * factor)
	var portrait_margins: Array[Rect2] = [
		Rect2(0, 0, screen_size.x, panel.position.y),
		Rect2(0, panel.end.y, screen_size.x, screen_size.y - panel.end.y),
		Rect2(0, panel.position.y, panel.position.x, panel.size.y),
		Rect2(panel.end.x, panel.position.y, screen_size.x - panel.end.x, panel.size.y),
	]
	for i in range(portrait_margins.size()):
		_draw_margin_accents(portrait_margins[i], factor, i)
	draw_set_transform(safe_rect.get_center(), 0, Vector2.ONE * factor)
	draw_rect(Rect2(-152, -162, 304, 240), Color("302332"))
	draw_rect(Rect2(-149, -159, 298, 234), Color("806271"), false, 1)
	draw_rect(Rect2(-62, -95, 124, 72), Color("ed91a5"), false, 4)
	draw_rect(Rect2(-50, -83, 94, 48), Color("423044"))
	draw_rect(Rect2(50, -65, 4, 12), Color("fff0cd"))
	_centered("NUGGET CAT", -128, 16, Color("ffc568"))
	_centered("ROTATE TO LANDSCAPE", 18, 8, Color("fff0cd"))
	_centered("MORE ROOM FOR SNACKS!", 42, 8, Color("9bd2bc"))
	draw_set_transform(Vector2.ZERO)

func _draw_margin_accents(region: Rect2, unit: float, side: int) -> void:
	# A loose, finite arrangement: bigger silhouettes at the sides, no tile/grid.
	if minf(region.size.x, region.size.y) < 28 * unit:
		return
	var horizontal := region.size.x > region.size.y
	var fractions := [0.10, 0.24, 0.40, 0.59, 0.76, 0.90]
	var across := [0.48, 0.61, 0.40, 0.57, 0.43, 0.52]
	for i in range(fractions.size()):
		var fraction: float = fractions[i]
		var cross_position: float = across[(i + side) % across.size()]
		var location := region.position + region.size * (Vector2(fraction, cross_position) if horizontal else Vector2(cross_position, fraction))
		var accent_unit := unit * (1.2 if horizontal else 2.2) * (0.7 if i % 3 == 1 else 1.0)
		var space := Rect2(location - Vector2.ONE * 10 * accent_unit, Vector2.ONE * 20 * accent_unit)
		if region.encloses(space):
			_accent(location.round(), accent_unit, (i + side) % 2)
	# Fine stepped corner brackets decorate the margin edges without entering play.
	var inset := region.grow(-7 * unit)
	var length := minf(14 * unit, minf(inset.size.x, inset.size.y) / 3)
	var edge_color := SURROUND.lerp(TRIM, 0.20)
	for x in [-1, 1]:
		for y in [-1, 1]:
			var corner := inset.get_center() + inset.size * Vector2(x, y) / 2
			draw_line(corner, corner - Vector2(x * length, 0), edge_color, unit)
			draw_line(corner, corner - Vector2(0, y * length), edge_color, unit)
			draw_rect(Rect2(corner - Vector2(x * 3, y * 3) * unit - Vector2.ONE * unit, Vector2.ONE * 2 * unit), edge_color)

func _accent(origin: Vector2, unit: float, kind: int) -> void:
	var color := SURROUND.lerp(TRIM, 0.25)
	if kind == 0:
		# Small paw: one pad and four staggered toes.
		for rect in [Rect2(-3, 0, 6, 4), Rect2(-5, -3, 2, 3), Rect2(-2, -5, 2, 3), Rect2(1, -5, 2, 3), Rect2(4, -3, 2, 3)]:
			draw_rect(Rect2(origin + rect.position * unit, rect.size * unit), color)
	else:
		# A glint with two crumbs, rather than another large icon.
		draw_rect(Rect2(origin + Vector2(-1, -4) * unit, Vector2(2, 8) * unit), color)
		draw_rect(Rect2(origin + Vector2(-4, -1) * unit, Vector2(8, 2) * unit), color)
		draw_rect(Rect2(origin + Vector2(7, 4) * unit, Vector2(2, 2) * unit), color)

func _centered(text: String, y: float, size: int, color: Color) -> void:
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(FONT, Vector2(-width / 2, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
