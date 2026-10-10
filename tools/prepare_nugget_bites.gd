extends SceneTree
## Cut actual transparent bites from the active big sprites; retain their crust art.
## Separate atlas: big (one/two bites), big golden (one/two bites).

func _initialize() -> void:
	var source := Image.load_from_file("res://assets/nuggets.png")
	if source == null or source.get_size() != Vector2i(192, 32):
		push_error("Expected the six-frame 32px nugget atlas.")
		quit(1)
		return
	var atlas := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	for kind in range(2):
		var original := source.get_region(Rect2i((2 if kind == 0 else 5) * 32, 0, 32, 32))
		for bites in range(1, 3):
			var tile := original.duplicate() as Image
			for y in range(32):
				for x in range(32):
					if original.get_pixel(x, y).a < 0.5:
						continue
					var distance := _bite_distance(Vector2(x, y), bites)
					if distance <= 0:
						tile.set_pixel(x, y, Color.TRANSPARENT)
					elif distance < 1.2:
						tile.set_pixel(x, y, Color("985226" if kind == 0 else "a96e19"))
					elif distance < 4:
						# Pale chicken interior with a few warm crumb pixels.
						var crumb := (x * 3 + y * 7) % 11 < 2
						tile.set_pixel(x, y, Color("efb953" if crumb else "ffe9b8") if kind == 0 else Color("edc034" if crumb else "fffbea"))
			atlas.blit_rect(tile, Rect2i(0, 0, 32, 32), Vector2i((kind * 2 + bites - 1) * 32, 0))
	var error := atlas.save_png("res://assets/nugget_bites.png")
	if error != OK:
		push_error(error_string(error))
		quit(1)
		return
	print("Prepared assets/nugget_bites.png: visible missing chunks and exposed centers for both big kinds.")
	quit()

func _bite_distance(pixel: Vector2, bites: int) -> float:
	# Overlapping round tooth marks make a scalloped edge, not a straight crop.
	var distance := minf(pixel.distance_to(Vector2(25, 4)) - 9, pixel.distance_to(Vector2(31, 12)) - 10)
	if bites == 2:
		distance = minf(distance, pixel.distance_to(Vector2(29, 21)) - 14)
		distance = minf(distance, pixel.distance_to(Vector2(25, 29)) - 12)
	return distance
