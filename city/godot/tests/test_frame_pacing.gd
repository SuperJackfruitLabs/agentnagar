## Frame pacing: the client presents at the display's own rate with vsync,
## high refresh included (measured on a healthy 360 Hz desktop: 360 fps in
## every style, worst frame 4-6.5 ms). `--fps` sets a cap instead.
extends TestSuite


func test_ordinary_displays_keep_vsync() -> void:
	assert_eq(FramePacing.policy(60.0, -1), {"vsync": true, "max_fps": 0}, "60 Hz")
	assert_eq(FramePacing.policy(165.0, -1), {"vsync": true, "max_fps": 0}, "165 Hz")


func test_very_high_refresh_keeps_vsync_at_its_own_rate() -> void:
	assert_eq(FramePacing.policy(360.0, -1), {"vsync": true, "max_fps": 0}, "360 Hz")
	assert_eq(FramePacing.policy(240.0, -1), {"vsync": true, "max_fps": 0}, "240 Hz")


func test_an_unknown_refresh_rate_keeps_vsync() -> void:
	assert_eq(FramePacing.policy(-1.0, -1), {"vsync": true, "max_fps": 0}, "unknown")


func test_fps_option_overrides() -> void:
	assert_eq(CityArgs.parse(PackedStringArray(["--fps=90"]))["fps"], 90, "--fps")
	assert_eq(CityArgs.parse(PackedStringArray())["fps"], -1, "unset by default")
	assert_eq(FramePacing.policy(360.0, 90), {"vsync": false, "max_fps": 90}, "a cap of 90")
	assert_eq(FramePacing.policy(60.0, 0), {"vsync": true, "max_fps": 0}, "0: the display's own rate")
