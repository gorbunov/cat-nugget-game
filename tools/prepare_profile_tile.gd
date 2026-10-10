extends SceneTree

## Prepare the newly generated seamless texture without joining or fading strips.
func _init() -> void:
	var tile := Image.load_from_file("res://art_sources/profile_background_v002.png")
	if tile == null:
		quit(1)
		return
	tile.resize(768, 512, Image.INTERPOLATE_NEAREST)
	var output := "res://art_sources/itch_profile/"
	if tile.save_png(output + "background-tile-v002.png") != OK:
		quit(1)
		return
	# Lower motif contrast uniformly, preserving all positions and tile boundaries.
	var base := Color("121f2e")
	for y in tile.get_height():
		for x in tile.get_width():
			tile.set_pixel(x, y, base.lerp(tile.get_pixel(x, y), 0.5))
	if tile.save_png(output + "background-tile-muted-v003.png") != OK:
		quit(1)
		return
	var preview := Image.create(2304, 1536, false, Image.FORMAT_RGB8)
	for row in 3:
		for column in 3:
			preview.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(column * 768, row * 512))
	if preview.save_png(output + "background-repeat-preview-muted-v003.png") != OK:
		quit(1)
		return
	print("Saved new tile and 3 by 3 repeat preview.")
	quit()
