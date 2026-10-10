extends SceneTree
## Turn the six-cell API candidate into the game's 32px nugget atlas.

const SOURCE := "res://art_sources/nuggets_v001.png"
const NORMAL := [Color("423044"), Color("70442c"), Color("985226"), Color("bd702d"), Color("de973f"), Color("efb953"), Color("ffd582"), Color("ffe9b8")]
const BURNT := [Color("27222f"), Color("393340"), Color("514653"), Color("685762"), Color("864f48"), Color("b2674d"), Color("947b77")]
const GOLDEN := [Color("6f471d"), Color("a96e19"), Color("d49b20"), Color("edc034"), Color("ffe16a"), Color("fff1a0"), Color("fffbea")]

func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	if source == null:
		push_error("Generate art_sources/nuggets_v001.png first.")
		quit(1)
		return
	var sheet := Image.create(192, 32, false, Image.FORMAT_RGBA8)
	for frame in range(6):
		var tile := source.get_region(Rect2i((frame % 3) * 512, (frame / 3) * 512, 512, 512))
		for y in range(tile.get_height()):
			for x in range(tile.get_width()):
				if tile.get_pixel(x, y).a < 0.90:
					tile.set_pixel(x, y, Color.TRANSPARENT)
		var bounds := tile.get_used_rect()
		if not bounds.has_area():
			push_error("Empty nugget cell %d" % frame)
			quit(1)
			return
		tile = tile.get_region(bounds)
		var scale := minf(30.0 / tile.get_width(), (29.0 if frame in [2, 5] else 26.0) / tile.get_height())
		tile.resize(maxi(1, roundi(tile.get_width() * scale)), maxi(1, roundi(tile.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
		var colors: Array = BURNT if frame == 3 else (GOLDEN if frame >= 4 else NORMAL)
		var offset := Vector2i(frame * 32 + (32 - tile.get_width()) / 2, (32 - tile.get_height()) / 2)
		for y in range(tile.get_height()):
			for x in range(tile.get_width()):
				var pixel := tile.get_pixel(x, y)
				if pixel.a < 0.5:
					continue
				var nearest: Color = colors[0]
				var distance := INF
				for color: Color in colors:
					var candidate := Vector3(pixel.r - color.r, pixel.g - color.g, pixel.b - color.b).length_squared()
					if candidate < distance:
						distance = candidate
						nearest = color
				sheet.set_pixelv(offset + Vector2i(x,y), nearest)
	var error := sheet.save_png("res://assets/nuggets.png")
	if error != OK:
		push_error(error_string(error))
		quit(1)
		return
	var preview := Image.create(192,32,false,Image.FORMAT_RGBA8)
	preview.fill(Color("c9d9c6"))
	preview.blend_rect(sheet, Rect2i(0,0,192,32), Vector2i.ZERO)
	preview.resize(1152,192,Image.INTERPOLATE_NEAREST)
	preview.save_png("res://art_sources/nuggets_v001_pixel_preview.png")
	print("Prepared assets/nuggets.png and art_sources/nuggets_v001_pixel_preview.png")
	quit()
