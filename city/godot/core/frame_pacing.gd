## How the client paces its frames: vsync at the display's own rate, high
## refresh included, so movement is as smooth as the panel allows. On a
## healthy 360 Hz desktop every style holds 360 fps (worst frame 4-6.5 ms).
## Periodic 40-80 ms stalls seen earlier came from a degraded desktop
## session (compositor and driver state; they appeared with the scene
## hidden, on either GPU, under X11 and Wayland alike) and went with a
## restart; a frame-rate cap did not prevent them. `--fps` sets a cap
## (without vsync) instead, or 0 for the display's own rate.
extends RefCounted
class_name FramePacing

## {vsync, max_fps} for a display of `refresh_hz` (negative if unknown) and
## an `--fps` request: -1 unset, 0 the display's own rate with vsync, N a
## cap of N frames a second.
static func policy(refresh_hz: float, requested: int) -> Dictionary:
	if requested == 0:
		return {"vsync": true, "max_fps": 0}
	if requested > 0:
		return {"vsync": false, "max_fps": requested}
	return {"vsync": true, "max_fps": 0}


## Applies the policy for an `--fps` request to the main window.
static func apply(requested: int) -> Dictionary:
	var p := policy(DisplayServer.screen_get_refresh_rate(), requested)
	apply_policy(p)
	return p


## Applies a `{vsync, max_fps}` policy (from `policy` or
## `Settings.frame_policy`) to the main window.
static func apply_policy(p: Dictionary) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if p["vsync"] else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = p["max_fps"]
