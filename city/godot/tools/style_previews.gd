extends SceneTree
## Generates the style picker's preview cards, one per style, on a display:
##   godot --path city/godot --resolution 1920x1080 --script res://tools/style_previews.gd
## For each style it boots the client (60 people, no player), pauses at tick
## 150 (10:00), takes the diagonal view with the HUD hidden, and saves the
## frame, cropped to 16:9 about its centre and scaled to 480 x 270, as
## res://styles/<dir>/assets/preview.png. Arguments after `--` narrow it to
## the styles named.
const SIZE := Vector2i(480, 270)
## Frames given to the scene to settle (shadows, fades, walkers' poses)
## before the capture.
const SETTLE_FRAMES := 40


func _init() -> void:
	await process_frame
	var only := OS.get_cmdline_user_args()
	var host := StyleHost.new()
	var dirs: Array = host.discover("res://styles")
	host.free()
	for dir in dirs:
		var style: String = dir.get_file()
		if only.is_empty() or style in only:
			await _preview(style, dir)
	quit()


func _preview(style: String, dir: String) -> void:
	var main = load("res://main.gd").new()
	root.add_child(main)
	main.boot_for_tool(PackedStringArray(["--crowd=60", "--style=" + style, "--as=none"]))
	main.driver.pause()
	main.hud.visible = false
	while main.driver.world.tick() < 150:
		main.driver.step_once()
	main.host.set_camera("diagonal")
	for f in SETTLE_FRAMES:
		main._process(1.0 / 60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	var shot := root.get_viewport().get_texture().get_image()
	var card := _card(shot)
	var out := ProjectSettings.globalize_path(dir.path_join("assets/preview.png"))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	card.save_png(out)
	print("preview %s from a %dx%d frame -> %s" % [style, shot.get_width(), shot.get_height(), out])
	main.free()
	await process_frame


## The frame cut to 16:9 about its centre (the window may not open at the
## size asked for), then scaled down to SIZE with Lanczos filtering.
@warning_ignore("integer_division")
static func _card(frame: Image) -> Image:
	var w := frame.get_width()
	var h := frame.get_height()
	var crop := Rect2i(0, 0, w, h)
	if w * SIZE.y > h * SIZE.x:
		var cw := int(round(h * float(SIZE.x) / SIZE.y))
		crop = Rect2i((w - cw) / 2, 0, cw, h)
	elif w * SIZE.y < h * SIZE.x:
		var ch := int(round(w * float(SIZE.y) / SIZE.x))
		crop = Rect2i(0, (h - ch) / 2, w, ch)
	var card := frame.get_region(crop)
	card.convert(Image.FORMAT_RGB8)
	card.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	return card
