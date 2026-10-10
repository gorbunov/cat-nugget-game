extends "res://tools/prepare_cat.gd"
## Companion atlas; preserve gameplay frames and their palette-role IDs.

const DISGUST_SOURCE := "res://art_sources/cat_disgust_v001.png"
const DISGUST_METADATA := "res://assets/cat_disgust_sprite.json"

func _initialize() -> void:
	var source := Image.load_from_file(DISGUST_SOURCE)
	if source == null:
		quit(1)
		return
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DISGUST_METADATA))
	var roles := PackedStringArray(metadata.roles)
	var atlas := Image.create(512, 64, false, Image.FORMAT_RGBA8)
	for frame in range(8):
		# Common face anchor within each row avoids body jitter during the reaction.
		var anchor := Vector2i(192 + (frame % 4) * 384, 292 if frame < 4 else 758)
		var cell := Rect2i((frame % 4) * 384, (frame / 4) * 512, 384, 512)
		for y in range(64):
			for x in range(64):
				var sample := anchor + (Vector2i(x, y) - Vector2i(32, 35)) * SCALE
				if not cell.has_point(sample):
					continue
				var role := roles.find(_role(source.get_pixelv(sample)))
				if role < 0:
					quit(1)
					return
				if role > 0:
					atlas.set_pixel(frame * 64 + x, y, Color8(role, 0, 0, 255))
	if atlas.save_png("res://assets/cat_disgust_indexed.png") != OK:
		quit(1)
		return
	var appearance := CatAppearance.new()
	if appearance.load_assets(atlas, DISGUST_METADATA) != OK:
		quit(1)
		return
	var preview := Image.create(512, 64 * appearance.palettes.size(), false, Image.FORMAT_RGBA8)
	preview.fill(Color("c9d9c6"))
	for i in range(appearance.palettes.size()):
		preview.blend_rect(appearance.texture_for_palette(i).get_image(), Rect2i(0, 0, 512, 64), Vector2i(0, i * 64))
	preview.resize(1024, preview.get_height() * 2, Image.INTERPOLATE_NEAREST)
	preview.save_png("res://art_sources/cat_disgust_v001_palette_preview.png")
	print("Prepared eight-frame disgust atlas and all-palette preview.")
	quit()
