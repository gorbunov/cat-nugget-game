extends RefCounted
## Platform capabilities shared by input, drawing and hit testing.

var web := OS.has_feature("web")
var mobile := OS.has_feature("mobile")
var web_fullscreen_available := false

func detect_browser_features() -> void:
	if web:
		web_fullscreen_available = bool(JavaScriptBridge.eval("!!(document.fullscreenEnabled && document.documentElement.requestFullscreen)"))

func can_quit() -> bool:
	return not web and not mobile

func supports_fullscreen() -> bool:
	return web_fullscreen_available if web else not mobile

func allows_action(action: String) -> bool:
	if action == "quit":
		return can_quit()
	if action == "fullscreen":
		return supports_fullscreen()
	return true
