extends SceneTree
## Offline activation of the retained API candidate; mirror edges for exact tiling.

func _initialize() -> void:
	var source := Image.load_from_file("res://art_sources/wallpaper_v002.png")
	if source == null:
		quit(1)
		return
	source.resize(256, 256, Image.INTERPOLATE_NEAREST)
	source.convert(Image.FORMAT_RGB8)
	var tile := Image.create(512, 512, false, Image.FORMAT_RGB8)
	for y in range(512):
		for x in range(512):
			var sx := x if x < 256 else 511 - x
			var sy := y if y < 256 else 511 - y
			tile.set_pixel(x, y, source.get_pixel(sx, sy))
	var error := tile.save_png("res://assets/wallpaper.png")
	if error != OK:
		push_error(error_string(error))
		quit(1)
		return
	print("Prepared seamless wallpaper: 512x512 mirrored tile from wallpaper_v002.png")
	quit()
