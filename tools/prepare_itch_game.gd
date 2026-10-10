extends SceneTree
## Offline page artwork from active game sprites. No image API request.

const OUTPUT := "res://art_sources/itch_game"
const PLUM := Color("403547")
const DARK := Color("2b2332")
const CREAM := Color("ffedbd")
const GOLD := Color("ffc76b")
const PINK := Color("ee9aaa")
const MINT := Color("afd1ac")
var glyphs: Dictionary = {}
var font: Image
var cat: Image
var nuggets: Image

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	font = Image.load_from_file("res://assets/pixel_font.png")
	nuggets = Image.load_from_file("res://assets/nuggets.png")
	var appearance := preload("res://scripts/cat_appearance.gd").new()
	if appearance.load_assets(Image.load_from_file("res://assets/cat_indexed.png")) != OK:
		quit(1)
		return
	cat = appearance.texture_for_palette(0).get_image().get_region(Rect2i(256, 0, 64, 64))
	for line in FileAccess.get_file_as_string("res://assets/pixel_font.fnt").split("\n"):
		if not line.begins_with("char id="):
			continue
		var fields := {}
		for part in line.split(" ", false):
			var pair := part.split("=")
			if pair.size() == 2:
				fields[pair[0]] = int(pair[1])
		glyphs[fields.id] = fields
	var banner := canvas(480, 160, PLUM)
	banner.fill_rect(Rect2i(20, 20, 3, 115), GOLD)
	text(banner, "A VERY IMPORTANT FEEDING MISSION", Vector2i(36, 24), 1, MINT)
	text(banner, "NUGGET", Vector2i(34, 45), 5, DARK)
	text(banner, "NUGGET", Vector2i(34, 42), 5, GOLD)
	text(banner, "CAT", Vector2i(34, 91), 5, DARK)
	text(banner, "CAT", Vector2i(34, 88), 5, CREAM)
	text(banner, "NO THOUGHTS. JUST CHICKEN.", Vector2i(36, 136), 1, PINK)
	sprite(banner, cat, Vector2i(316, 23), 2)
	nugget(banner, Vector2i(263, 42), 1)
	nugget(banner, Vector2i(431, 20), 1, 4)
	spark(banner, Vector2i(307, 34), GOLD)
	spark(banner, Vector2i(454, 115), PINK)
	spark(banner, Vector2i(296, 108), CREAM)
	banner.resize(960, 320, Image.INTERPOLATE_NEAREST)
	save(banner, "banner.png")
	var cover := canvas(315, 250, PLUM)
	cover.fill_rect(Rect2i(12, 12, 291, 2), GOLD)
	cover.fill_rect(Rect2i(12, 236, 291, 2), GOLD)
	center_text(cover, "NUGGET CAT", 28, 4, GOLD)
	sprite(cover, cat, Vector2i(93, 77), 2)
	nugget(cover, Vector2i(30, 96), 1)
	nugget(cover, Vector2i(250, 146), 1, 4)
	spark(cover, Vector2i(68, 170), PINK)
	spark(cover, Vector2i(244, 87), CREAM)
	center_text(cover, "60 SECONDS. ONE HUNGRY CAT.", 219, 1, CREAM)
	cover.resize(630, 500, Image.INTERPOLATE_NEAREST)
	save(cover, "cover.png")
	# itch.io draws its own launch button over the center of this image.
	var embed := canvas(480, 270, PLUM)
	embed.fill_rect(Rect2i(20, 18, 440, 2), GOLD)
	embed.fill_rect(Rect2i(20, 250, 440, 2), GOLD)
	var muted_cat := silhouette_of(cat, Color("514255"))
	var muted_nugget := silhouette_of(nuggets.get_region(Rect2i(0, 0, 32, 32)), Color("514255"))
	sprite(embed, muted_cat, Vector2i(337, 107), 2)
	sprite(embed, muted_nugget, Vector2i(31, 115), 2)
	sprite(embed, muted_nugget, Vector2i(100, 194), 1)
	sprite(embed, muted_nugget, Vector2i(375, 44), 1)
	spark(embed, Vector2i(76, 72), Color("665069"))
	spark(embed, Vector2i(302, 57), Color("665069"))
	center_text(embed, "60 SECONDS. ONE VERY HUNGRY CAT.", 234, 1, CREAM)
	embed.resize(960, 540, Image.INTERPOLATE_NEAREST)
	save(embed, "embed-cover.png")
	var tile := canvas(160, 160, DARK)
	var silhouette := nuggets.get_region(Rect2i(0, 0, 32, 32))
	for y in silhouette.get_height():
		for x in silhouette.get_width():
			if silhouette.get_pixel(x, y).a > 0.0:
				silhouette.set_pixel(x, y, Color("382e3e"))
	sprite(tile, silhouette, Vector2i(20, 23), 1)
	sprite(tile, silhouette, Vector2i(100, 103), 1)
	spark(tile, Vector2i(114, 42), Color("453547"))
	spark(tile, Vector2i(40, 121), Color("453547"))
	tile.resize(320, 320, Image.INTERPOLATE_NEAREST)
	for x in tile.get_width():
		assert(tile.get_pixel(x, 0) == tile.get_pixel(x, 319))
	for y in tile.get_height():
		assert(tile.get_pixel(0, y) == tile.get_pixel(319, y))
	save(tile, "background.png")
	var preview := canvas(1200, 1560, DARK)
	for y in range(0, 1560, 320):
		for x in range(0, 1200, 320):
			preview.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(x, y))
	preview.fill_rect(Rect2i(120, 24, 960, 1512), PLUM)
	preview.blit_rect(banner, Rect2i(Vector2i.ZERO, banner.get_size()), Vector2i(120, 24))
	# Existing actual game capture, used only for the illustrative page layout.
	var gameplay := Image.load_from_file("res://build/previews/gameplay.png")
	if gameplay != null:
		gameplay.resize(960, 540, Image.INTERPOLATE_NEAREST)
		preview.blit_rect(gameplay, Rect2i(Vector2i.ZERO, gameplay.get_size()), Vector2i(120, 360))
	text(preview, "SIXTY SECONDS. ALL THE NUGGETS.", Vector2i(168, 942), 3, GOLD)
	text(preview, "CATCH SNACKS. BUILD COMBOS. DODGE THE BURNT BITS.", Vector2i(168, 998), 2, CREAM)
	text(preview, "THEN TAKE ON ONE VERY BIG BOSS NUGGET.", Vector2i(168, 1028), 2, CREAM)
	text(preview, "MOUSE TO MUNCH", Vector2i(168, 1100), 3, MINT)
	text(preview, "MOVE YOUR MOUSE. YOUR CAT DOES THE CHOMPING.", Vector2i(168, 1146), 2, CREAM)
	text(preview, "MADE TOGETHER", Vector2i(168, 1220), 3, GOLD)
	text(preview, "A PARENT-AND-CHILD PROJECT ABOUT MAKING,", Vector2i(168, 1266), 2, CREAM)
	text(preview, "LEARNING, AND FINISHING SOMETHING FUN.", Vector2i(168, 1296), 2, CREAM)
	preview.fill_rect(Rect2i(168, 1380, 280, 60), Color("a84865"))
	text(preview, "DOWNLOAD", Vector2i(216, 1400), 3, CREAM)
	text(preview, "LAYOUT CONCEPT - NOT A LIVE ITCH.IO CAPTURE", Vector2i(168, 1480), 1, MINT)
	save(preview, "page-preview.png")
	print("Game page theme saved to art_sources/itch_game/")
	quit()

func canvas(width: int, height: int, color: Color) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image

func sprite(image: Image, source: Image, position: Vector2i, scale: int) -> void:
	var copy := source.duplicate() as Image
	copy.resize(copy.get_width() * scale, copy.get_height() * scale, Image.INTERPOLATE_NEAREST)
	image.blend_rect(copy, Rect2i(Vector2i.ZERO, copy.get_size()), position)

func silhouette_of(source: Image, color: Color) -> Image:
	var result := source.duplicate() as Image
	for y in result.get_height():
		for x in result.get_width():
			var alpha := source.get_pixel(x, y).a
			result.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return result

func nugget(image: Image, position: Vector2i, scale: int, frame: int = 0) -> void:
	sprite(image, nuggets.get_region(Rect2i(frame * 32, 0, 32, 32)), position, scale)

func spark(image: Image, position: Vector2i, color: Color) -> void:
	image.fill_rect(Rect2i(position - Vector2i(1, 4), Vector2i(2, 8)), color)
	image.fill_rect(Rect2i(position - Vector2i(4, 1), Vector2i(8, 2)), color)

func text_width(value: String, scale: int) -> int:
	var width := 0
	for character in value:
		width += int(glyphs.get(character.unicode_at(0), {"xadvance": 4}).xadvance) * scale
	return width

func center_text(image: Image, value: String, y: int, scale: int, color: Color) -> void:
	text(image, value, Vector2i((image.get_width() - text_width(value, scale)) / 2, y), scale, color)

func text(image: Image, value: String, position: Vector2i, scale: int, color: Color) -> void:
	for character in value:
		var code := character.unicode_at(0)
		if not glyphs.has(code):
			position.x += 4 * scale
			continue
		var glyph: Dictionary = glyphs[code]
		for y in int(glyph.height):
			for x in int(glyph.width):
				if font.get_pixel(glyph.x + x, glyph.y + y).a > 0.5:
					image.fill_rect(Rect2i(position + Vector2i(x, y) * scale, Vector2i.ONE * scale), color)
		position.x += int(glyph.xadvance) * scale

func save(image: Image, filename: String) -> void:
	if image.save_png(OUTPUT + "/" + filename) != OK:
		push_error("Cannot save " + filename)
		quit(1)
