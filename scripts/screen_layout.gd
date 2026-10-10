extends RefCounted
## Shared geometry for drawing and hit testing; drawing never registers controls.

enum Screen { TITLE, PLAYING, PAUSED, RESULTS, SETTINGS, GUIDE, SOURCES }

const PAUSE_BUTTON := Rect2(588, 11, 34, 27)
const BUTTONS := {
	Screen.TITLE: {
		"fullscreen": Rect2(568, 29, 26, 26),
		"cat_shuffle": Rect2(415, 74, 159, 146),
		"start": Rect2(100, 247, 245, 36),
		"settings": Rect2(366, 252, 105, 26),
		"quit": Rect2(483, 252, 78, 26),
		"sources": Rect2(169, 308, 110, 18),
		"guide": Rect2(366, 293, 195, 24),
	},
	Screen.PLAYING: {"pause": PAUSE_BUTTON},
	Screen.PAUSED: {
		"resume": Rect2(240, 141, 160, 30),
		"settings": Rect2(240, 181, 160, 26),
		"guide": Rect2(240, 215, 160, 26),
		"home": Rect2(240, 249, 160, 26),
	},
	Screen.RESULTS: {
		"start": Rect2(146, 270, 210, 34),
		"home": Rect2(375, 274, 118, 26),
	},
	Screen.SETTINGS: {
		"shuffle": Rect2(215, 58, 210, 18),
		"track_prev": Rect2(153, 100, 32, 26),
		"track_next": Rect2(455, 100, 32, 26),
		"master_down": Rect2(221, 153, 28, 26),
		"master_up": Rect2(405, 153, 28, 26),
		"music_down": Rect2(221, 189, 28, 26),
		"music_up": Rect2(405, 189, 28, 26),
		"sfx_down": Rect2(221, 225, 28, 26),
		"sfx_up": Rect2(405, 225, 28, 26),
		"fullscreen": Rect2(153, 264, 202, 26),
		"back": Rect2(251, 302, 138, 28),
	},
	Screen.GUIDE: {"back": Rect2(240, 306, 160, 26)},
	Screen.SOURCES: {
		"source_488472": Rect2(440, 91, 98, 26),
		"source_162395": Rect2(440, 151, 98, 26),
		"source_449868": Rect2(440, 211, 98, 26),
		"source_license": Rect2(160, 308, 150, 24),
		"back": Rect2(330, 308, 150, 24),
	},
}


static func button_rect(screen: Screen, action: String) -> Rect2:
	# The paused playfield still draws its HUD beneath the overlay.
	if action == "pause":
		return PAUSE_BUTTON
	return BUTTONS[screen][action]


static func action_at(screen: Screen, position: Vector2, can_quit: bool = true, supports_fullscreen: bool = true) -> String:
	for action: String in BUTTONS[screen]:
		if (action == "quit" and not can_quit) or (action == "fullscreen" and not supports_fullscreen):
			continue
		var rect: Rect2 = BUTTONS[screen][action]
		if rect.has_point(position):
			return action
	return ""


static func volume_slider_rect(index: int) -> Rect2:
	return Rect2(263, 161 + index * 36, 128, 12)
