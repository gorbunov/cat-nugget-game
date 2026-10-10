extends "res://tools/prepare_cat.gd"
## Convert the retained dance candidate without changing the gameplay cat atlas.

const DANCE_SOURCE := "res://art_sources/cat_dance_v001.png"
const DANCE_METADATA := "res://assets/cat_dance_sprite.json"

func _initialize() -> void:
	var source := Image.load_from_file(DANCE_SOURCE)
	assert(source != null)
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DANCE_METADATA))
	var roles := PackedStringArray(metadata.roles)
	var tiles: Array[Image] = []
	var max_height := 1
	var max_width := 1
	for frame in range(8):
		var tile := source.get_region(Rect2i((frame % 4) * 384, (frame / 4) * 512, 384, 512))
		for y in range(512):
			for x in range(384):
				var c := tile.get_pixel(x, y)
				if c.a < 0.9:
					tile.set_pixel(x, y, Color.TRANSPARENT)
		var bounds := tile.get_used_rect()
		assert(bounds.has_area())
		tile = tile.get_region(bounds)
		max_height = maxi(max_height, tile.get_height())
		max_width = maxi(max_width, tile.get_width())
		tiles.append(tile)
	var scale := minf(88.0 / max_height, 88.0 / max_width)
	var atlas := Image.create(768, 96, false, Image.FORMAT_RGBA8)
	for frame in range(8):
		var tile := tiles[frame]
		tile.resize(roundi(tile.get_width() * scale), roundi(tile.get_height() * scale), Image.INTERPOLATE_NEAREST)
		var offset := Vector2i(frame * 96 + (96 - tile.get_width()) / 2, 92 - tile.get_height())
		for y in range(tile.get_height()):
			for x in range(tile.get_width()):
				var role := roles.find(_role(tile.get_pixel(x, y)))
				assert(role >= 0)
				if role > 0:
					atlas.set_pixelv(offset + Vector2i(x, y), Color8(role, 0, 0, 255))
	assert(atlas.save_png("res://assets/cat_dance_indexed.png") == OK)
	var appearance := CatAppearance.new()
	assert(appearance.load_assets(atlas, DANCE_METADATA) == OK)
	var preview := Image.create(768, 96 * appearance.palettes.size(), false, Image.FORMAT_RGBA8)
	preview.fill(Color("c9d9c6"))
	for i in range(appearance.palettes.size()):
		preview.blend_rect(appearance.texture_for_palette(i).get_image(), Rect2i(0, 0, 768, 96), Vector2i(0, i * 96))
	assert(preview.save_png("res://art_sources/cat_dance_v001_palette_preview.png") == OK)
	print("Prepared dance atlas and all-palette preview.")
	quit()
