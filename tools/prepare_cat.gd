extends SceneTree
## Offline art preparation only: classify source colors into semantic roles.
## The game never compares RGB colors or paints eyes by coordinates.

const CatAppearance := preload("res://scripts/cat_appearance.gd")
const SOURCE := "res://art_sources/cat_v001.png"
const ANCHORS := [
	Vector2i(192, 288), Vector2i(576, 289), Vector2i(960, 292), Vector2i(1344, 302),
	Vector2i(192, 753), Vector2i(576, 771), Vector2i(960, 764), Vector2i(1344, 757),
]
const SCALE := 7

func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	if source == null:
		push_error("Missing generated cat source.")
		quit(1)
		return
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CatAppearance.SPRITE_PATH))
	var roles := PackedStringArray(metadata.roles)
	var atlas := Image.create(512, 64, false, Image.FORMAT_RGBA8)
	var role_counts := {}
	for frame in range(8):
		var cell := Rect2i((frame % 4) * 384, (frame / 4) * 512, 384, 512)
		for y in range(64):
			for x in range(64):
				var sample: Vector2i = ANCHORS[frame] + (Vector2i(x, y) - Vector2i(32, 35)) * SCALE
				if not cell.has_point(sample):
					continue
				var role := _role(source.get_pixelv(sample))
				var index := roles.find(role)
				if index < 0:
					push_error("Missing role: " + role)
					quit(1)
					return
				role_counts[role] = int(role_counts.get(role, 0)) + 1
				if index > 0:
					atlas.set_pixel(frame * 64 + x, y, Color8(index, 0, 0, 255))
	var error := atlas.save_png("res://assets/cat_indexed.png")
	if error != OK:
		push_error(error_string(error))
		quit(1)
		return
	var appearance := CatAppearance.new()
	if appearance.load_assets(atlas) != OK:
		quit(1)
		return
	var board := Image.create(512, 64 * appearance.palettes.size(), false, Image.FORMAT_RGBA8)
	board.fill(Color("c9d9c6"))
	for i in range(appearance.palettes.size()):
		board.blend_rect(appearance.texture_for_palette(i).get_image(), Rect2i(0, 0, 512, 64), Vector2i(0, i * 64))
	board.resize(1024, board.get_height() * 2, Image.INTERPOLATE_NEAREST)
	board.save_png("res://art_sources/cat_v001_palette_preview.png")
	var icon := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	icon.fill(Color("678b83"))
	icon.blend_rect(appearance.texture_for_palette(0).get_image(), Rect2i(0, 0, 64, 64), Vector2i.ZERO)
	icon.resize(128, 128, Image.INTERPOLATE_NEAREST)
	icon.save_png("res://assets/cat_icon.png")
	print("Prepared indexed cat atlas, icon and palette preview. Role pixel counts: %s" % role_counts)
	quit()

func _role(color: Color) -> String:
	if color.a < 0.90:
		return "transparent"
	var hue := color.h
	var saturation := color.s
	var value := color.v
	if value < 0.29:
		return "outline"
	if saturation < 0.13 and minf(color.r, minf(color.g, color.b)) > 0.9:
		return "white"
	if hue > 0.38 and hue < 0.64 and saturation > 0.28:
		if value < 0.50:
			return "outline"
		return "iris_light" if value > 0.83 else "iris"
	if (hue > 0.88 or hue < 0.035) and saturation > 0.20:
		return "accent" if value > 0.78 else "accent_shadow"
	if hue >= 0.035 and hue < 0.19 and saturation > 0.13:
		return "belly" if value > 0.84 else "belly_shadow"
	var brightness := color.get_luminance()
	if brightness < 0.42:
		return "fur_shadow"
	return "fur_light" if brightness > 0.65 else "fur"
