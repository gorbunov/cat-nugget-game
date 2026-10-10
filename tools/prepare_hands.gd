extends SceneTree
## Convert the approved AI source into aligned, palette-limited 64x48 frames.

const SOURCE := "res://art_sources/hands_v001.png"
const DESTINATION := "res://assets/hands_ai.png"
const ANCHORS := [Vector2i(208, 530), Vector2i(720, 530), Vector2i(1188, 536)]
const PALETTE := [
	Color("423044"), Color("80505a"), Color("b66f60"), Color("d88f72"),
	Color("efad84"), Color("ffc99b"), Color("ffe2b6"),
	Color("385960"), Color("527f7b"), Color("749f98"), Color("9ab9a7"),
	Color("b6a47c"), Color("dcc99e"), Color("fff0cd"),
]

func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	if source == null:
		push_error("Missing generated source: " + SOURCE)
		quit(1)
		return
	print("Source: %s; corner=%s; background=%s; skin=%s" % [source.get_size(), source.get_pixel(0, 0), source.get_pixel(300, 300), source.get_pixel(300, 500)])
	var sheet := Image.create(192, 48, false, Image.FORMAT_RGBA8)
	for frame in range(3):
		# Anchor each wrist to (22,30), sampling one output pixel per 8 source pixels.
		for y in range(48):
			for x in range(64):
				var sample: Vector2i = ANCHORS[frame] + (Vector2i(x, y) - Vector2i(22, 30)) * 8 + Vector2i(4, 4)
				if sample.x < frame * 512 or sample.x >= (frame + 1) * 512 or sample.y < 0 or sample.y >= source.get_height():
					continue
				var pixel := source.get_pixelv(sample)
				# Discard the model's translucent halo; all game pixels use hard alpha.
				if pixel.a < 0.9:
					continue
				var nearest: Color = PALETTE[0]
				var distance := INF
				for color in PALETTE:
					var candidate := Vector3(pixel.r - color.r, pixel.g - color.g, pixel.b - color.b).length_squared()
					if candidate < distance:
						distance = candidate
						nearest = color
				sheet.set_pixel(frame * 64 + x, y, nearest)
	var error := sheet.save_png(DESTINATION)
	if error != OK:
		push_error(error_string(error))
		quit(1)
		return
	var preview := Image.create(192, 48, false, Image.FORMAT_RGBA8)
	preview.fill(Color("c9d9c6"))
	preview.blend_rect(sheet, Rect2i(0, 0, 192, 48), Vector2i.ZERO)
	preview.resize(1152, 288, Image.INTERPOLATE_NEAREST)
	preview.save_png("res://art_sources/hands_v001_pixel_preview.png")
	print("Prepared " + DESTINATION + " and art_sources/hands_v001_pixel_preview.png")
	quit()
