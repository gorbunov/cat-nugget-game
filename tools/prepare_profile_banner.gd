extends SceneTree

func _init() -> void:
	var output := "res://art_sources/itch_profile/"
	var background := Image.load_from_file(output + "background-tile-muted-v003.png")
	var histogram := {}
	for y in background.get_height():
		for x in background.get_width():
			var hex := background.get_pixel(x, y).to_html(false)
			histogram[hex] = histogram.get(hex, 0) + 1
	var most_common := ""
	var count := 0
	for hex: String in histogram:
		if histogram[hex] > count:
			most_common = hex
			count = histogram[hex]
	print("Most common background color: #", most_common, " (", count, " pixels)")
	if "--color-only" in OS.get_cmdline_user_args():
		quit()
		return
	var banner := Image.load_from_file("res://art_sources/profile_banner_blend_v002.png")
	if banner == null:
		quit(1)
		return
	print("Generated banner has transparency: ", banner.detect_alpha() != Image.ALPHA_NONE)
	if banner.detect_alpha() == Image.ALPHA_NONE:
		push_error("Expected a transparent banner.")
		quit(1)
		return
	# Fit all nontransparent artwork inside a wide canvas without cutting particles.
	var artwork := banner.get_region(banner.get_used_rect())
	var scale := minf(1408.0 / artwork.get_width(), 576.0 / artwork.get_height())
	artwork.resize(roundi(artwork.get_width() * scale), roundi(artwork.get_height() * scale), Image.INTERPOLATE_NEAREST)
	banner = Image.create(1536, 640, false, Image.FORMAT_RGBA8)
	banner.fill(Color.TRANSPARENT)
	banner.blit_rect(artwork, Rect2i(Vector2i.ZERO, artwork.get_size()), (banner.get_size() - artwork.get_size()) / 2)
	if banner.save_png(output + "banner-v002.png") != OK:
		quit(1)
		return
	var preview := Image.create(banner.get_width(), banner.get_height(), false, Image.FORMAT_RGBA8)
	for y in preview.get_height():
		for x in preview.get_width():
			preview.set_pixel(x, y, background.get_pixel(x % background.get_width(), y % background.get_height()))
	preview.blend_rect(banner, Rect2i(Vector2i.ZERO, banner.get_size()), Vector2i.ZERO)
	if preview.save_png(output + "banner-integration-preview-v002.png") != OK:
		quit(1)
		return
	quit()
