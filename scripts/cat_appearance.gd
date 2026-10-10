extends RefCounted
## One indexed sheet + editable role palettes. Colors are resolved once per palette,
## from byte lookup tables; no pixel coordinates, source-RGB matching, or per-frame work.

const SPRITE_PATH := "res://assets/cat_sprite.json"
const PALETTES_PATH := "res://assets/cat_palettes.json"

var palettes: Array[Dictionary] = []
var roles: PackedStringArray
var frame_size := Vector2i.ZERO
var frame_count := 0
var draw_size := Vector2.ZERO
var mouth_anchor := Vector2.ZERO
var image_size := Vector2i.ZERO
var indices := PackedByteArray()
var _lookups: Array[PackedByteArray] = []
var _textures: Dictionary = {}

func load_assets(source: Image = null, sprite_path: String = SPRITE_PATH) -> Error:
	palettes.clear()
	_lookups.clear()
	_textures.clear()
	var sprite: Variant = JSON.parse_string(FileAccess.get_file_as_string(sprite_path))
	var definitions: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALETTES_PATH))
	if not sprite is Dictionary or not definitions is Dictionary:
		return _invalid("Cat sprite/palette JSON must contain objects.")
	for field in ["texture", "frame_size", "frame_count", "draw_size", "mouth_anchor", "roles"]:
		if not sprite.has(field):
			return _invalid("Missing sprite field: " + field)
	frame_size = Vector2i(int(sprite.frame_size[0]), int(sprite.frame_size[1]))
	frame_count = int(sprite.frame_count)
	draw_size = Vector2(float(sprite.draw_size[0]), float(sprite.draw_size[1]))
	mouth_anchor = Vector2(float(sprite.mouth_anchor[0]), float(sprite.mouth_anchor[1]))
	roles = PackedStringArray(sprite.roles)
	if frame_size.x <= 0 or frame_size.y <= 0 or frame_count != 8 or roles.size() < 2 or roles.size() > 256:
		return _invalid("Invalid cat sheet dimensions, frame count or role table.")
	if source == null:
		var texture := load(str(sprite.texture)) as Texture2D
		if texture == null:
			return _invalid("Cannot load the indexed cat texture.")
		source = texture.get_image()
	if source.is_compressed() and source.decompress() != OK:
		return _invalid("Cannot decode indexed cat texture.")
	source.convert(Image.FORMAT_RGBA8)
	image_size = source.get_size()
	if image_size != Vector2i(frame_size.x * frame_count, frame_size.y):
		return _invalid("Cat atlas dimensions do not match cat_sprite.json.")
	var raw := source.get_data()
	indices.resize(image_size.x * image_size.y)
	for pixel in range(indices.size()):
		# Ignore hidden RGB in transparent pixels (texture importers may bleed edges).
		var role := int(raw[pixel * 4]) if raw[pixel * 4 + 3] > 0 else 0
		if role >= roles.size() or (role == 0) != (raw[pixel * 4 + 3] == 0):
			return _invalid("Unknown role or inconsistent transparency in cat index map.")
		indices[pixel] = role
	var defaults: Dictionary = definitions.get("defaults", {})
	var names := {}
	for definition in definitions.get("palettes", []):
		var name := str(definition.get("name", "")).strip_edges().to_upper()
		if name.is_empty() or names.has(name):
			return _invalid("Cat palettes need unique nonempty names.")
		names[name] = true
		var colors: Dictionary = defaults.duplicate()
		colors.merge(definition.get("colors", {}), true)
		var lookup := PackedByteArray()
		lookup.resize(roles.size() * 4)
		for role in range(1, roles.size()):
			var html := str(colors.get(roles[role], ""))
			if not Color.html_is_valid(html):
				return _invalid("Palette %s has no valid color for %s." % [name, roles[role]])
			var color := Color(html)
			lookup[role * 4] = color.r8
			lookup[role * 4 + 1] = color.g8
			lookup[role * 4 + 2] = color.b8
			lookup[role * 4 + 3] = 255
		palettes.append({"name": name, "colors": colors})
		_lookups.append(lookup)
	if palettes.size() < 2:
		return _invalid("Provide at least two cat palettes for no-repeat randomization.")
	return OK

func texture_for_palette(index: int) -> Texture2D:
	if _textures.has(index):
		return _textures[index]
	var rgba := PackedByteArray()
	rgba.resize(indices.size() * 4)
	var lookup := _lookups[index]
	for pixel in range(indices.size()):
		var color_offset := indices[pixel] * 4
		var output_offset := pixel * 4
		rgba[output_offset] = lookup[color_offset]
		rgba[output_offset + 1] = lookup[color_offset + 1]
		rgba[output_offset + 2] = lookup[color_offset + 2]
		rgba[output_offset + 3] = lookup[color_offset + 3]
	var image := Image.create_from_data(image_size.x, image_size.y, false, Image.FORMAT_RGBA8, rgba)
	var texture := ImageTexture.create_from_image(image)
	_textures[index] = texture
	return texture

func frame_rect(frame: int) -> Rect2:
	return Rect2(frame * frame_size.x, 0, frame_size.x, frame_size.y)

func draw_rect() -> Rect2:
	return Rect2(-mouth_anchor * draw_size / Vector2(frame_size), draw_size)

func _invalid(message: String) -> Error:
	push_error(message)
	return ERR_INVALID_DATA
