extends SceneTree
## Reuse the palette-indexed happy cat for the native and Web startup artwork.

func _initialize() -> void:
	var appearance = preload("res://scripts/cat_appearance.gd").new()
	if appearance.load_assets() != OK:
		quit(1)
		return
	var image: Image = appearance.texture_for_palette(0).get_image().get_region(Rect2i(appearance.frame_rect(4)))
	image.resize(192, 192, Image.INTERPOLATE_NEAREST)
	var error := image.save_png("res://assets/boot_splash.png")
	if error != OK:
		push_error(error_string(error))
		quit(1)
		return
	print("Prepared assets/boot_splash.png from the happy ginger cat.")
	quit()
