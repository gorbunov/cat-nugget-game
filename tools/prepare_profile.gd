extends SceneTree

## Prepare profile uploads from retained OpenAI originals. Run from repository root.
func _init() -> void:
	var output := "res://art_sources/itch_profile"
	DirAccess.make_dir_recursive_absolute(output)
	var banner := Image.load_from_file("res://art_sources/profile_banner_v001.png")
	var background := Image.load_from_file("res://art_sources/profile_background_v001.png")
	if banner == null or background == null:
		push_error("Generate both profile originals first.")
		quit(1)
		return
	var height := banner.get_width() / 3
	var crop := banner.get_region(Rect2i(0, (banner.get_height() - height) / 2, banner.get_width(), height))
	var error := crop.save_png(output + "/banner.png")
	if error != OK:
		quit(1)
		return
	# Guarantee a seamless transition into the page color even if the generated
	# original's edge color varies.
	background.convert(Image.FORMAT_RGB8)
	var base := Color("182331")
	for y in background.get_height():
		for x in background.get_width():
			var edge := mini(mini(x, background.get_width() - 1 - x), mini(y, background.get_height() - 1 - y))
			var blend := smoothstep(0.0, 100.0, float(edge))
			background.set_pixel(x, y, base.lerp(background.get_pixel(x, y), blend))
	error = background.save_png(output + "/background.png")
	if error != OK:
		quit(1)
		return
	# Estimate the original's slowly varying navy ground with a robust median.
	# Retain only illustration detail over a truly flat ground: edge fades alone
	# produce visible bands when the generated ground differs from the page color.
	var original := Image.load_from_file("res://art_sources/profile_background_v001.png")
	var ground := estimate_ground(original)
	var strip_width := 320
	var tile := Image.create(strip_width * 2, background.get_height(), false, Image.FORMAT_RGB8)
	for side in 2:
		var source_x := 0 if side == 0 else background.get_width() - strip_width
		for y in tile.get_height():
			for x in strip_width:
				var source := original.get_pixel(source_x + x, y)
				var local_ground := ground.get_pixel(source_x + x, y)
				var detail := Color(maxf(0.0, source.r - local_ground.r), maxf(0.0, source.g - local_ground.g), maxf(0.0, source.b - local_ground.b))
				var strength := maxf(detail.r, maxf(detail.g, detail.b))
				var edge := mini(mini(x, strip_width - 1 - x), mini(y, tile.get_height() - 1 - y))
				var blend := smoothstep(0.012, 0.04, strength) * smoothstep(0.0, 24.0, float(edge))
				tile.set_pixel(side * strip_width + x, y, Color(base.r + detail.r * blend, base.g + detail.g * blend, base.b + detail.b * blend))
	tile.resize(480, 768, Image.INTERPOLATE_NEAREST)
	error = tile.save_png(output + "/background-tile.png")
	if error != OK:
		quit(1)
		return
	for y in tile.get_height():
		assert(tile.get_pixel(0, y) == tile.get_pixel(tile.get_width() - 1, y))
	for x in tile.get_width():
		assert(tile.get_pixel(x, 0) == tile.get_pixel(x, tile.get_height() - 1))
	var preview := Image.create(tile.get_width() * 3, tile.get_height() * 2, false, Image.FORMAT_RGB8)
	for row in 2:
		for column in 3:
			preview.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(column * tile.get_width(), row * tile.get_height()))
	if preview.save_png(output + "/background-repeat-preview.png") != OK:
		quit(1)
		return
	print("Profile uploads saved to art_sources/itch_profile/")
	quit()


func estimate_ground(image: Image) -> Image:
	var spacing := 32
	var ground := Image.create(image.get_width() / spacing + 1, image.get_height() / spacing + 1, false, Image.FORMAT_RGB8)
	for gy in ground.get_height():
		for gx in ground.get_width():
			var reds: Array[float] = []
			var greens: Array[float] = []
			var blues: Array[float] = []
			for dy in range(-96, 97, 8):
				for dx in range(-96, 97, 8):
					var x := gx * spacing + dx
					var y := gy * spacing + dy
					if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
						continue
					var color := image.get_pixel(x, y)
					reds.append(color.r)
					greens.append(color.g)
					blues.append(color.b)
			reds.sort()
			greens.sort()
			blues.sort()
			var middle := reds.size() / 2
			ground.set_pixel(gx, gy, Color(reds[middle], greens[middle], blues[middle]))
	ground.resize(image.get_width(), image.get_height(), Image.INTERPOLATE_BILINEAR)
	return ground
