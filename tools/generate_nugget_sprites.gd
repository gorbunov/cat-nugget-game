extends SceneTree
## Local, chunky nugget sprites for playtesting when the image API is unavailable.
## Same six-frame layout as the requested AI sheet: two regular, big, burnt, gold, big gold.

const SHAPES := [
	[Vector2(4,11),Vector2(8,7),Vector2(13,6),Vector2(17,9),Vector2(22,7),Vector2(27,10),Vector2(29,15),Vector2(26,20),Vector2(21,24),Vector2(16,24),Vector2(13,21),Vector2(8,23),Vector2(4,19),Vector2(3,15)],
	[Vector2(9,6),Vector2(16,5),Vector2(22,8),Vector2(25,14),Vector2(29,18),Vector2(27,24),Vector2(23,26),Vector2(7,25),Vector2(3,21),Vector2(5,15),Vector2(7,11)],
	[Vector2(4,8),Vector2(11,5),Vector2(16,7),Vector2(24,4),Vector2(29,9),Vector2(27,15),Vector2(30,21),Vector2(26,27),Vector2(20,29),Vector2(13,26),Vector2(6,28),Vector2(2,23),Vector2(4,17),Vector2(2,12)],
	[Vector2(5,9),Vector2(10,6),Vector2(14,8),Vector2(21,6),Vector2(26,10),Vector2(25,15),Vector2(29,19),Vector2(25,25),Vector2(19,24),Vector2(15,27),Vector2(9,24),Vector2(4,24),Vector2(3,17)],
	[Vector2(4,11),Vector2(8,7),Vector2(13,6),Vector2(17,9),Vector2(22,7),Vector2(27,10),Vector2(29,15),Vector2(26,20),Vector2(21,24),Vector2(16,24),Vector2(13,21),Vector2(8,23),Vector2(4,19),Vector2(3,15)],
	[Vector2(3,12),Vector2(7,5),Vector2(12,9),Vector2(17,3),Vector2(21,8),Vector2(27,5),Vector2(29,13),Vector2(27,18),Vector2(30,23),Vector2(25,28),Vector2(17,27),Vector2(11,29),Vector2(4,25),Vector2(2,20)],
]

func _initialize() -> void:
	var sheet := Image.create(192, 32, false, Image.FORMAT_RGBA8)
	for frame in range(6):
		var mask := {}
		for y in range(32):
			for x in range(32):
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), PackedVector2Array(SHAPES[frame])):
					mask[Vector2i(x,y)] = true
		var palette := [Color("613e31"), Color("aa5c29"), Color("dc8b36"), Color("efb34e"), Color("ffe09a")]
		if frame == 3:
			palette = [Color("27222f"), Color("393340"), Color("514653"), Color("685762"), Color("bf6449")]
		elif frame >= 4:
			palette = [Color("74501e"), Color("bf851d"), Color("efbb32"), Color("ffe364"), Color("fff8c0")]
		for pixel: Vector2i in mask:
			var edge := false
			for neighbor in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if not mask.has(pixel + neighbor):
					edge = true
			var color: Color = palette[0] if edge else (palette[1] if pixel.y > 20 else palette[2])
			if not edge and pixel.y < 14:
				color = palette[3]
			sheet.set_pixel(frame * 32 + pixel.x, pixel.y, color)
		# Connected clusters suggest a coarse crispy crust, not potato eyes.
		for spot in [Vector2i(8,11),Vector2i(12,9),Vector2i(18,12),Vector2i(23,11),Vector2i(6,16),Vector2i(14,17),Vector2i(22,18),Vector2i(18,21)]:
			for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i(1,-1), Vector2i(2,-1)]:
				var p: Vector2i = spot + offset
				if mask.has(p) and mask.has(p + Vector2i.UP) and mask.has(p + Vector2i.DOWN):
					sheet.set_pixel(frame * 32 + p.x, p.y, palette[4] if frame != 3 or spot.x % 2 == 0 else palette[1])
		if frame >= 4:
			for p in [Vector2i(11,12),Vector2i(12,12),Vector2i(12,11),Vector2i(12,13),Vector2i(13,12)]:
				sheet.set_pixel(frame*32+p.x, p.y, Color("fffbea"))
	var error := sheet.save_png("res://assets/nuggets.png")
	if error != OK:
		push_error(error_string(error))
		quit(1)
		return
	var preview := Image.create(192,32,false,Image.FORMAT_RGBA8)
	preview.fill(Color("c9d9c6"))
	preview.blend_rect(sheet, Rect2i(0,0,192,32), Vector2i.ZERO)
	preview.resize(1152,192,Image.INTERPOLATE_NEAREST)
	preview.save_png("res://art_sources/nuggets_local_preview.png")
	print("Generated six local nugget frames and art_sources/nuggets_local_preview.png")
	quit()
