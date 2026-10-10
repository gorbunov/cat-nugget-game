extends SceneTree

func _init() -> void:
	var output := "res://art_sources/itch_profile/"
	var tile := Image.load_from_file("res://art_sources/profile_stars_v001.png")
	var banner := Image.load_from_file(output + "banner-v002.png")
	if tile == null or banner == null:
		quit(1)
		return
	tile.convert(Image.FORMAT_RGBA8)
	tile.resize(768, 512, Image.INTERPOLATE_NEAREST)
	# Keep stars subdued against the same page color as the banner palette.
	var base := Color("121f2e")
	var histogram := {}
	var dominant := ""
	var count := 0
	for y in tile.get_height():
		for x in tile.get_width():
			var hex := tile.get_pixel(x, y).to_html(false)
			histogram[hex] = histogram.get(hex, 0) + 1
			if histogram[hex] > count:
				count = histogram[hex]
				dominant = hex
	var ground := Color(dominant)
	for y in tile.get_height():
		for x in tile.get_width():
			var color := tile.get_pixel(x, y)
			tile.set_pixel(x, y, Color(base.r + (color.r - ground.r) * 0.6, base.g + (color.g - ground.g) * 0.6, base.b + (color.b - ground.b) * 0.6))
	if tile.save_png(output + "background-stars-v001.png") != OK:
		quit(1)
		return
	var preview := Image.create(2304, 1536, false, Image.FORMAT_RGBA8)
	for row in 3:
		for column in 3:
			preview.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(column * 768, row * 512))
	if preview.save_png(output + "background-stars-repeat-preview-v001.png") != OK:
		quit(1)
		return
	preview = preview.get_region(Rect2i(Vector2i.ZERO, banner.get_size()))
	preview.blend_rect(banner, Rect2i(Vector2i.ZERO, banner.get_size()), Vector2i.ZERO)
	if preview.save_png(output + "banner-stars-preview-v001.png") != OK:
		quit(1)
		return
	print("Saved sparse star tile, repeat preview and banner integration preview.")
	quit()
