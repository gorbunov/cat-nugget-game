extends SceneTree
## Offline conversion of individual high-quality sources to native-canvas rooms.
## Preserve material colors and fine detail; never shrink to half-resolution or
## force unrelated materials into a tiny shared palette.

const SOURCES := [
	"res://art_sources/room_kitchen_v002.png",
	"res://art_sources/room_cafe_v002.png",
	"res://art_sources/room_sunroom_v002.png",
	"res://art_sources/room_study_v002.png",
]

func _initialize() -> void:
	var atlas := Image.create(1280, 720, false, Image.FORMAT_RGB8)
	for room in range(SOURCES.size()):
		var tile := Image.load_from_file(SOURCES[room])
		if tile == null or tile.get_size() != Vector2i(1536, 1024):
			push_error("Expected a 1536x1024 individual room: " + SOURCES[room])
			quit(1)
			return
		# One high-quality resample directly to the 640x360 game canvas. Runtime
		# integer scaling stays nearest-neighbor, with no extra pixel doubling.
		tile.resize(640, 360, Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(tile, Rect2i(0, 0, 640, 360), Vector2i((room % 2) * 640, (room / 2) * 360))
	var error := atlas.save_png("res://assets/rooms.png")
	if error != OK:
		push_error(error_string(error))
		quit(1)
		return
	print("Prepared assets/rooms.png: four native 640x360 rooms, preserved source colors and detail.")
	quit()
