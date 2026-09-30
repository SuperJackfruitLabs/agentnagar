## The city client: steps the world, turns projections into changes, and
## renders them through whichever style pack is active. A plain launch
## opens on the title: the city runs behind it with nobody joined, and
## Explore joins (asking how, the first time) and flies the camera down into
## play; Quit to title leaves the world and returns. Play arguments go
## straight to play, joining at launch. Input reaches the player through
## the router, its steering is predicted every frame, and each tick's steps
## go to the core just before the tick is stepped. The play HUD sits at the
## bottom of the screen stack, menus open over it, and the developer panel
## (F3) holds the harness controls when developer tools are on. The map
## opens over play (M), the game menu (Map) or the title (Map & read); its
## Go walks a player there by the core's rules, or moves a spectator's view.
## The player rides the tram: on a platform A waits for it or boards it,
## aboard A steps off at a stop, and the prompt says what is happening;
## overhead the view follows the tram, and first person sits at a window.
## Joining by tram, the view frames the Square's stop while the player waits
## to ride in, and the prompt counts down to its tram.
## Everything else the player acts on goes one way (see Interact): the
## prompt names the target's first verb, E or Y shows the next, and A does
## the verb shown; Inspect opens the overlay (PanelScreen), and Read opens it
## once the core has the player reading, closing it when the reading ends.
## Displays draw their panels in the world at the detail their distance
## allows (Surfaces), and the map's List tab lists them as text.
## Using a workstation's computer opens the station computer
## (ComputerScreen) once the core confirms it, the camera settled behind the
## chair; leaving it stands the player up, and the core moving or releasing
## the player closes it. "Look at screen" opens it in watch mode.
extends Node

const FPV_2D_NOTE := "First-person view is available in the 3D styles."
## How long a spectator's view glides to a place the map's Go chose; calm
## mode cuts.
const MAP_FLIGHT_S := 0.6
const BUILD_HINT := "The city extension is not built.\nRun: city/scripts/build-godot.sh\nthen reopen this project."
## A test run's settings file, so the suite never touches the player's own
## (tests/run_all.gd deletes it as the run starts).
const TEST_SETTINGS_PATH := "user://settings_test.cfg"
## A tool's settings file (see boot_for_tool), emptied at every tool boot.
const TOOL_SETTINGS_PATH := "user://settings_tool.cfg"
## The test run's station credential, so no test touches the player's.
const TEST_CREDENTIAL_PATH := "user://station_credential_test.json"
## The test run's station links (which agent works at each station), so
## no test touches the player's (tests/run_all.gd deletes it as the run
## starts).
const TEST_LINKS_PATH := "user://station_links_test.cfg"
## What the computer says while the browser has the sign-in.
const SIGNING_IN := "Finish signing in in your browser."
const DISCONNECTING := "Finish disconnecting in your browser."

var driver := WorldDriver.new()
var model := SceneModel.new()
var motion := Motion.new()
var host := StyleHost.new()
## The player's saved settings, loaded in `boot` from `settings_path`.
var settings := Settings.new()
## Where the settings live. Tests may set it before `boot`; a test run that
## leaves it alone uses TEST_SETTINGS_PATH instead.
var settings_path := Settings.PATH
## Which device was touched last, for the HUD's key and button labels.
var glyphs := InputGlyphs.new()
## The open screens: the play HUD at the bottom, menus over it.
var stack := ScreenStack.new()
var hud := PlayHud.new()
## The developer panel, shown with F3 when developer tools are on.
var dev := DevPanel.new()
## The interface skin, rebuilt from the style on every activation.
var ui: UiTheme
var router := InputRouter.new()
var player := Player.new()
## The walkable grid the player's prediction steps on.
var nav: NavQuery
var manifest := {}
## The feed the world starts from: the district's own when empty. The
## bench's tram scene sets it before booting, to add its riders.
var feed_jsonl := ""
## The manifest the world starts from, as JSON: the district's own when
## empty. A test sets it before booting, to a fixture of its own (a desk
## bound to a station, which the district's hot desks never are).
var fixture_manifest := ""
var options := {}
var styles: Array = []
var booted := false
## What the player can act on, and how (see Interact); built from the
## layout at boot.
var interact: Interact
## The interaction orchestration Interact's targets and verbs go through:
## what the player acts on now, the overlay, the read that follows a walk
## (see InteractionController). Wired in boot, once nav, interact and
## trams are ready.
var interaction := InteractionController.new()
## The title screen while it is shown, else null.
var _title: TitleScreen
## Booted by a tool (the bench, captures, the audit), which never shows
## the title.
var _for_tool := false
## The occupant a Quit to title left behind, walking out; a new join waits
## until they are gone, since the core refuses a second arrival for one
## still present. "" when there is none.
var _departing := ""
## Explore asked to join while `_departing` was still walking out.
var _join_waiting := false
## The tick `_departing` was last looked for.
var _waited_tick := -1
## Explore's flight waits for the player's first place in the city.
var _fly_waiting := false
## The map while it is open, else null or freed.
var _map: MapScreen
## The latest projection of the viewer shown, for the map's counts of
## people inside.
var _last_projection := {}
## When the next tram comes, and the lines' stops, from the layout and the
## projections shown.
var trams := TramTimes.new()
## Whether first person aboard has turned the eye to look out on the
## platform side yet (once a ride, and again each time first person is
## entered).
var _seat_faced := false
## The platform room the player last stepped onto from a tram (joining, or
## getting off), where the tram is not offered until it has stood still
## there OFFER_AFTER_S seconds; "" once it has, or has left that room.
var _stepped_onto := ""
## Seconds the player has stood still on `_stepped_onto`.
var _stood_s := 0.0
## Whether the player was on the ground as of the last projection.
var _on_ground := false
## How long a player stands still on the platform it stepped onto before
## the tram is offered there.
const OFFER_AFTER_S := 5.0
## The notice when the world steps the player off the rails, having stood
## in a tram's way five ticks.
const STEPPED_ASIDE_NOTICE := "You stepped off the tracks for the tram"
## What "Look at screen" says where the player may not watch.
const WATCH_REFUSED := "You can't see this screen."

## Overridable for tests.
var class_exists := func(n: String) -> bool: return ClassDB.class_exists(n)
## The station computer while it is open, else null or freed.
var computer: ComputerScreen
## What every workstation's screen shows in the city: idle, in use, or
## the player's own computer (see StationMonitor).
var monitor := StationMonitor.new()
## Where the station computer's stations come from, as last chosen: the
## live source while live mode is on and the player is signed in, else
## Sample station, made once and kept so it remembers what the player did
## to it. With live mode off it is always the sample, and nothing live is
## made.
var station_source: StationSource
## The player's AgentPod sign-in, made only once live mode is on.
var station_credential: StationCredential
## Where the credential is kept; a test run uses TEST_CREDENTIAL_PATH.
var credential_path := StationCredential.PATH
## Opens the sign-in page in the system browser; tests script one.
var open_browser := StationCredential.open_in_system_browser
var _sample_source: SampleSource
var _live_source: LiveSource
## The settings screen while it is open, for its Disconnect row.
var _settings_screen: SettingsScreen
## How the last Disconnect went, for whichever screen shows it: its line,
## and whether the console is offered (a device not revoked).
var _station_note := ""
var _station_console_hint := false
## A replaced credential whose cancelled flow has yet to say how it ended.
var _retiring_credential: StationCredential
## The view the computer's backdrop replaced (see StylePack.settle_view).
var _view_before_computer: Variant = null
## Watch mode's hold: where the watcher stood and who sat at the desk
## watched, as it opened; {} when not watching.
var _watching := {}


func _ready() -> void:
	_boot_from_command_line.call_deferred()


## Boots from the launch options unless something (a test) already booted.
func _boot_from_command_line() -> void:
	if not booted:
		boot(OS.get_cmdline_user_args())


func boot(args: PackedStringArray, styles_root := "res://styles") -> void:
	booted = true
	options = CityArgs.parse(args)
	settings.path = _settings_path()
	settings.load_file()
	settings.changed.connect(_on_setting_changed)
	_apply_frame_pacing()
	_apply_display()
	# The project's input map is kept before the player's bindings go over it.
	RebindScreen.capture_defaults()
	RebindScreen.apply_bindings(settings)
	host.quality_low = settings.get_value("graphics", "quality") == "low"
	host.calm = settings.calm()
	host.look_scale = settings.get_value("controls", "mouse_sensitivity")
	host.stick_scale = settings.get_value("controls", "stick_sensitivity")
	host.invert_y = settings.get_value("controls", "invert_y")
	add_child(host)
	add_child(monitor)
	add_child(driver)
	add_child(router)
	add_child(stack)
	add_child(dev)
	stack.router = router
	stack.changed.connect(_on_screen_changed)
	hud.glyphs = glyphs
	ui = UiTheme.from_style({}, settings.text_scale())
	stack.set_theme(ui)
	stack.push(hud)
	_apply_developer()
	driver.class_exists = class_exists
	if not class_exists.call("CityWorld"):
		hud.show_error(BUILD_HINT)
		return
	var manifest_json := fixture_manifest if fixture_manifest != "" else CityPaths.district_manifest()
	manifest = JSON.parse_string(manifest_json) if manifest_json != "" else {}
	if manifest.is_empty():
		hud.show_error("The district fixture was not found under city/fixtures/district.")
		return
	driver.projected.connect(_on_projected)
	var feed := feed_jsonl if feed_jsonl != "" else CityPaths.district_feed()
	var r := driver.start(manifest_json, feed, options["seed"], options["crowd"], options["operator"])
	if not r.get("ok", false):
		hud.show_error("The world did not load:\n" + JSON.stringify(r, "  "))
		return
	# Its displays' sample panels are read beside the manifest.
	driver.world.set_fixture_dir(CityPaths.district_dir())
	# Packs get the places only, from the core: no roster, no reservations.
	manifest = JSON.parse_string(driver.world.layout_json())
	nav = NavQuery.from_layout(manifest)
	trams = TramTimes.from_layout(manifest)
	interact = Interact.from_layout(manifest, StylePack.kinds(), nav)
	interaction.setup(host, nav, interact, stack, driver, manifest, trams, tram_prompt, _capture_mouse)
	interaction.player = player
	interaction.use_began.connect(_on_use_began)
	interaction.use_ended.connect(_on_use_ended)
	interaction.watch_requested.connect(_on_watch_requested)
	interaction.watch_gate = _may_watch
	# Signed in with live mode on, the live source is made, and lists the
	# player's stations, now.
	_station_source()
	# Every style draws the displays' panels on their surfaces.
	host.surfaces = interaction.displays()
	var title := CityArgs.shows_title(options, _for_tool or _is_test_run())
	if not title and options["as"] != "none" and not _join():
		return
	styles = host.discover(styles_root)
	var viewers := driver.viewers()
	if player.id != "":
		viewers.push_front(player.id)
	dev.setup(styles.map(func(d): return {"dir": d, "name": host.style_name(d)}), viewers)
	dev.style_requested.connect(_activate)
	dev.viewer_requested.connect(_set_viewer)
	dev.pause_toggled.connect(func(p): driver.pause() if p else driver.resume())
	dev.step_requested.connect(func(): driver.step_once())
	dev.speed_changed.connect(func(x): driver.set_speed(x))
	dev.open_all_toggled.connect(func(on): host.open_all = on)
	dev.roofs_toggled.connect(func(on): host.set_roofs_on(on))
	dev.camera_requested.connect(_on_camera)
	dev.note.connect(func(text): hud.notify(text))
	_route_input()
	driver.set_speed(options["speed"])
	dev.speed = driver.speed
	host.set_names(settings.get_value("interface", "names"))
	if styles.is_empty():
		hud.show_error("No style packs were found under " + styles_root)
		return
	# The style asked for, else the one last chosen, else the first by order.
	var wanted: String = options["style"] if options["style"] != "" else str(settings.get_value("interface", "style"))
	var chosen: String = styles[0]
	for d in styles:
		if d.get_file() == wanted:
			chosen = d
	_activate(chosen)
	if options["camera"] != "":
		host.set_camera(options["camera"])
	if options["open_all"]:
		dev.toggle_open_all()
	if options["no_hud"]:
		hud.show_controls(false)
		dev.visible = false
	if options["viewer"] != "":
		_set_viewer(options["viewer"])
		dev.show_viewer(options["viewer"])
	for i in options["ticks"]:
		driver.step_once()
	if title:
		_show_title()
	elif options["fpv"]:
		_toggle_fpv()
	if options["open_menu"] and not title:
		_open_menu()
	if options["map"]:
		open_map(options["place"])
	if options["capture"] != "":
		_capture.call_deferred(options["capture"])


## Boots as `boot` does, on default settings in a throwaway file, so the
## bench, captures and audits never pick up what the player saved (name
## tags, text size, a frame cap).
func boot_for_tool(args: PackedStringArray, styles_root := "res://styles") -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TOOL_SETTINGS_PATH))
	settings_path = TOOL_SETTINGS_PATH
	_for_tool = true
	boot(args, styles_root)


## Every key, click and controller input arrives here as an intent. The
## developer panel's shortcuts reach it only with developer tools on (the
## router drops them otherwise).
func _route_input() -> void:
	router.walk_to.connect(_on_walk_to)
	router.names.connect(_toggle_names)
	router.open_all.connect(dev.toggle_open_all)
	router.roofs.connect(dev.toggle_roofs)
	router.camera.connect(dev.request_camera)
	router.pause.connect(dev.toggle_pause)
	router.step.connect(dev.request_step)
	router.speed.connect(dev.change_speed)
	router.viewer_step.connect(dev.step_viewer)
	router.style_pick.connect(dev.pick_style)
	router.style_step.connect(dev.step_style)
	router.zoom.connect(func(d): if host.pack: host.pack.zoom_step(d))
	router.interact.connect(_interact)
	router.interact_alt.connect(_next_verb)
	router.cancel.connect(_cancel)
	router.menu.connect(_on_menu)
	router.map.connect(_on_map_intent)
	router.dev_panel.connect(dev.toggle)
	router.toggle_fpv.connect(_toggle_fpv)
	router.cycle_look.connect(func():
		player.cycle_look()
		hud.set_player(player.status(), player.observer))


## The test run's own settings file unless a test chose one.
func _settings_path() -> String:
	if settings_path == Settings.PATH and _is_test_run():
		return TEST_SETTINGS_PATH
	return settings_path


static func _is_test_run() -> bool:
	return "res://tests/run_all.gd" in OS.get_cmdline_args()


## Applies a setting the moment it changes (in the settings screen, or by
## a shortcut such as N that saves what it toggles).
func _on_setting_changed(section: String, key: String) -> void:
	match section + "/" + key:
		"graphics/display":
			_apply_display()
		"graphics/vsync", "graphics/frame_cap":
			_apply_frame_pacing()
		"graphics/quality":
			host.set_quality_low(settings.get_value("graphics", "quality") == "low")
		"interface/text_size":
			_apply_skin()
		"interface/names":
			var on: bool = settings.get_value("interface", "names")
			if on != host.names_on:
				host.set_names(on)
		"accessibility/calm":
			host.set_calm(settings.calm())
			_drift()
		"developer/tools":
			_apply_developer()
		"station/hub_url", "station/client_id":
			_on_station_address_changed()
		"station/live", "station/superpipeline_url":
			_station_source()
		"controls/mouse_sensitivity", "controls/stick_sensitivity", "controls/invert_y":
			host.set_look(settings.get_value("controls", "mouse_sensitivity"),
				settings.get_value("controls", "stick_sensitivity"), settings.get_value("controls", "invert_y"))


## Vsync and the frame cap, unless `--fps` set them for this session.
func _apply_frame_pacing() -> void:
	FramePacing.apply_policy(Settings.frame_policy(settings, DisplayServer.screen_get_refresh_rate(), options.get("fps", -1)))


## Fullscreen or windowed, as saved; a headless run has no window.
func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var fullscreen: bool = settings.get_value("graphics", "display") == "fullscreen"
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## Developer tools from the settings or `--dev`: the panel's shortcuts,
## and F3; turned off, an open panel closes.
func _apply_developer() -> void:
	dev.enabled = settings.developer() or options.get("dev", false)
	router.dev_shortcuts = dev.enabled
	if not dev.enabled:
		dev.visible = false


## N: name tags on or off, remembered for the next launch.
func _toggle_names() -> void:
	var on := not host.names_on
	host.set_names(on)
	settings.set_value("interface", "names", on)


## Esc / Start: in first person with the mouse held, Esc frees the mouse
## and nothing else; otherwise it opens the game menu over the play view.
## Start frees the mouse and opens the menu on the one press: a player on a
## controller has no use for the mouse, and should not press twice.
func _on_menu() -> void:
	var from_pad := router.last_source.begins_with("joy:")
	if host.first_person and host.pack.fpv != null and host.pack.fpv.captured:
		_capture_mouse(false)
		if from_pad and stack.top() == hud:
			_open_menu()
	elif stack.top() == hud:
		_open_menu()
	# The same press must not reach the stack as a Back and close it again.
	if is_inside_tree():
		get_viewport().set_input_as_handled()


## A screen that shuts the world out takes the mouse too: a drag of the
## view held as it opens is let go, since its release will land on the
## screen and never reach the pack. Back in play in first person, the
## mouse is held again, however play resumed: the map closed or its Go,
## or Resume on the game menu (map spec section 4).
func _on_screen_changed(top: Screen) -> void:
	if not router.world_enabled and host.pack != null:
		host.pack.end_drag()
	if top == hud and host.first_person and host.pack != null and host.pack.fpv != null:
		_capture_mouse(true)


## The game menu open now, if any, whose header follows the player.
var _menu: GameMenu


func _open_menu() -> void:
	_menu = GameMenu.new()
	_menu.resume.connect(_close_screen.bind(_menu))
	_menu.open_map.connect(open_map)
	_menu.open_style.connect(_open_style_picker)
	_menu.open_settings.connect(_open_settings)
	_menu.open_about.connect(open_about)
	_menu.settings_available = true
	_menu.title_available = true
	_menu.quit_to_title.connect(quit_to_title)
	_menu.quit_game.connect(func(): get_tree().quit())
	stack.push(_menu)
	_menu.header.text = _who()


## Who the player is, for the game menu's header.
func _who() -> String:
	return hud.status_text if player.id != "" and hud.status_text != "" else "Watching"


## Pops `s` once the press that asked for it is over (its button is freed
## with it), and only if it is still on top.
func _close_screen(s: Screen) -> void:
	var close := func():
		if stack.top() == s:
			stack.pop()
	close.call_deferred()


## Opens the settings, at `page` when one is named.
func _open_settings(page := "") -> void:
	var screen := SettingsScreen.new()
	screen.settings = settings
	screen.start_page = page
	screen.open_look.connect(_open_look)
	screen.disconnect_requested.connect(_disconnect_station)
	screen.console_requested.connect(_open_console_home)
	_settings_screen = screen
	stack.push(screen)
	_show_station_account()


## The About screen: the version, the licence, the source and the
## third-party notices.
func open_about() -> AboutScreen:
	var screen := AboutScreen.new()
	stack.push(screen)
	return screen


func _open_style_picker() -> void:
	var picker := StylePicker.new()
	picker.styles = styles.map(func(d): return {"dir": d, "name": host.style_name(d)})
	picker.current = host.pack_dir
	picker.chosen.connect(_choose_style.bind(picker))
	stack.push(picker)


## A card chosen in the style picker: the style switches live, every open
## screen reskins, the picker keeps its focus, and the choice is saved.
func _choose_style(dir: String, picker: StylePicker) -> void:
	_activate(dir)
	picker.current = host.pack_dir
	if host.pack_dir == dir:
		settings.set_value("interface", "style", dir.get_file())


## Joins as the local player, who is then the viewer; false (with the
## reason shown) if the world refuses.
func _join() -> bool:
	var r := player.join(driver.world, options["as"], options["look"])
	if player.id == "":
		hud.show_error("Could not join as %s: %s" % [options["as"], JSON.stringify(r.get("error", r))])
		return false
	host.set_avatar(player.id)
	if not player.used.is_connected(interaction.on_used):
		player.used.connect(interaction.on_used)
	# Anything a player before this one left untaken is not this one's.
	if driver.world.has_method("take_player_events"):
		driver.world.take_player_events()
	if not driver.about_to_step.is_connected(_submit_player_tick):
		driver.about_to_step.connect(_submit_player_tick)
	if host.pack == null:
		_set_viewer(player.id)
	else:
		_follow_view(player.id)
	return true


## Each tick's steered steps go to the core just before it is stepped.
func _submit_player_tick() -> void:
	player.submit_tick()


## Watches `v`'s view in the style shown now, without rebuilding it: the
## title's public view and the player's own differ only by the player, so
## the next projection's changes bring the player in or take them out, and
## the camera stays where the title's drift left it.
func _follow_view(v: String) -> void:
	host.viewer = v
	if host.pack != null:
		host.pack.viewer = v
	driver.set_viewer(v)


# ---- The title ----

## Shows the title over the hidden HUD, the camera drifting behind it.
func _show_title() -> void:
	hud.visible = false
	_title = TitleScreen.new()
	_title.explore.connect(_explore)
	_title.map_and_read.connect(open_map)
	_title.open_settings.connect(_open_settings)
	_title.open_about.connect(open_about)
	_title.quit_game.connect(func(): get_tree().quit())
	stack.push(_title)
	_drift()


## Behind the title the camera drifts, except in calm mode.
func _drift() -> void:
	if _title != null and host.pack != null:
		host.pack.title_drift(not settings.calm())


## Explore: how to enter as last chosen, or, on a first launch, the Join
## screen asks.
func _explore() -> void:
	var as_: String = settings.get_value("interface", "join_as")
	if as_ != "":
		_enter(as_, settings.get_value("interface", "look"))
		return
	var j := _join_screen(false)
	j.done.connect(_on_join_chosen.bind(j))
	stack.push(j)


func _join_screen(look_only: bool) -> JoinScreen:
	var j := JoinScreen.new()
	j.look_only = look_only
	var as_: String = settings.get_value("interface", "join_as")
	j.join_as = as_ if as_ != "" else "registered"
	j.set_look(settings.get_value("interface", "look"))
	j.pack = host.pack
	return j


## The Join screen's answer, remembered for later launches.
func _on_join_chosen(as_: String, look: String, j: JoinScreen) -> void:
	settings.set_value("interface", "join_as", as_)
	settings.set_value("interface", "look", look)
	stack.remove(j)
	_enter(as_, look)


## Settings' Look row: the Join screen's look step alone.
func _open_look() -> void:
	var j := _join_screen(true)
	j.done.connect(_on_look_chosen.bind(j))
	stack.push(j)


func _on_look_chosen(_as: String, look: String, j: JoinScreen) -> void:
	settings.set_value("interface", "look", look)
	stack.remove(j)


## From the title into play: joins as `as_` in `look` (nobody for "none"),
## shows the HUD, and flies the camera down to the player once they have
## a place, or to the square when watching.
func _enter(as_: String, look: String) -> void:
	options["as"] = as_
	options["look"] = look
	if host.pack != null:
		host.pack.title_drift(false)
	stack.remove(_title)
	_title = null
	hud.visible = true
	hud.show_hints()
	_fly_waiting = false
	if as_ == "none":
		_fly_down(square_centre())
		return
	# By tram the player rides in to the Square's stop: the view waits
	# there, and follows the tram once the player is aboard (see _ride).
	var stop := arrival_platform()
	if stop != "":
		_fly_down(room_centre(stop))
	if _departing != "" and _still_here(_departing):
		_join_waiting = true
		_fly_waiting = stop == ""
	else:
		_departing = ""
		var joined := _join()
		_fly_waiting = joined and stop == ""
		if not joined and stop == "":
			_fly_down(square_centre())


## Flies the camera to `ground_cm`; calm mode cuts.
func _fly_down(ground_cm: Vector2) -> void:
	if host.pack != null:
		host.pack.fly_to(ground_cm, 0.0 if settings.calm() else StylePack.FLIGHT_S)


## Joins once the visit a Quit to title left behind has walked out, looking
## once a tick.
func _join_when_gone() -> void:
	var tick: int = driver.world.tick()
	if tick == _waited_tick:
		return
	_waited_tick = tick
	if _still_here(_departing):
		return
	_join_waiting = false
	_departing = ""
	if not _join():
		_fly_waiting = false
		_fly_down(square_centre())


## Whether occupant `id` is still in the city, as their own view shows.
func _still_here(id: String) -> bool:
	var p = JSON.parse_string(driver.world.project_json(id))
	return p is Dictionary and not Player.own_view(p, id).is_empty()


## Quit to title: the player leaves the world (walking out, as anyone
## does), every screen over the HUD closes, and the title returns with the
## camera drifting behind it.
func quit_to_title() -> void:
	if host.first_person:
		_leave_fpv()
	if player.id != "":
		driver.world.leave()
		_departing = player.id
	player = Player.new()
	interaction.player = player
	_on_ground = false
	_stepped_onto = ""
	_join_waiting = false
	_fly_waiting = false
	host.set_avatar("")
	host.set_selected("")
	hud.status_text = ""
	hud.show_crosshair(false)
	hud.dismiss_notices()
	_set_prompt("")
	if driver.viewer != "public":
		_follow_view("public")
	while stack.top() != null and stack.top() != hud:
		stack.remove(stack.top())
	_show_title()


## The platform a player joining by tram steps off onto, as the bridge
## picks it (the tram stop, where it is a line's platform), or "" when
## players do not arrive by tram.
func arrival_platform() -> String:
	if str(manifest.get("city", {}).get("arrivals", "direct")) != "tram":
		return ""
	var first := ""
	for d in manifest.get("city", {}).get("districts", []):
		for f in d.get("facilities", []):
			for r in f.get("rooms", []):
				if trams.platform(str(r["id"])).is_empty():
					continue
				if str(r.get("template", "")) == "tram-stop":
					return str(r["id"])
				if first == "":
					first = str(r["id"])
	return first


## Room `id`'s centre, in centimetres (the square's without a rectangle).
func room_centre(id: String) -> Vector2:
	var r := CityGeometry.room_of(manifest, id)
	if r.get("rect") == null:
		return square_centre()
	return CityGeometry.rect_m(r["rect"]).get_center() * 100.0


## The square's centre, in centimetres: where Just watch looks.
func square_centre() -> Vector2:
	var rooms := []
	for d in manifest.get("city", {}).get("districts", []):
		for f in d.get("facilities", []):
			rooms.append_array(f.get("rooms", []))
	for r in rooms:
		if r["id"] == "room:plaza" and r.get("rect") != null:
			return CityGeometry.rect_m(r["rect"]).get_center() * 100.0
	return CityGeometry.extent(manifest).get_center() * 100.0


## In play, a projection lands over frames (see WorldDriver.frame), one
## stage a frame after it arrives: the model takes it, the scene takes the
## changes, views refresh, the player observes.
var _due: Variant = null
var _changes_due: Variant = null
var _views_due: Variant = null
var _player_due: Variant = null


## Where in the tick the scene is shown: held at the end of the last one
## until a new tick's changes are in the scene.
func shown_time() -> float:
	return 1.0 if _due != null or _changes_due != null else driver.shown_time()


func _on_projected(p: Dictionary) -> void:
	_last_projection = p
	# Placement commands change the core's grid: prediction follows it from
	# this tick on. The first projection lands before the grid is loaded,
	# and the loaded grid already holds its changes.
	if nav != null:
		nav.apply_changes(p.get("grid_changes", []))
	if _map_open():
		_map.projection = p
	# An older projection still landing goes first, whole, so ticks reach
	# the scene once each and in order.
	_drain()
	if driver.staged:
		_due = p
		return
	host.apply_changes(model.apply(p), motion)
	_refresh(p)


## Lands whatever of earlier projections is still on its way, now, in
## order.
func _drain() -> void:
	if _due != null:
		_changes_due = [model.apply(_due), _due]
		_due = null
	if _changes_due != null:
		host.apply_changes(_changes_due[0], motion)
		_views_due = _changes_due[1]
		_changes_due = null
	if _views_due != null:
		host.refresh_views(model)
		_player_due = _views_due
		_views_due = null
	if _player_due != null:
		_observe(_player_due)
		_player_due = null


## Forgets projections still on their way (a new viewer's world replaces
## them).
func _drop_landing() -> void:
	_due = null
	_changes_due = null
	_views_due = null
	_player_due = null


func _refresh(p: Dictionary) -> void:
	host.refresh_views(model)
	_observe(p)


func _observe(p: Dictionary) -> void:
	trams.observe(p)
	monitor.occupy(_occupied_desks(p))
	if player.id != "":
		# The player always reads its own view, whoever is watching.
		var own = p if p.get("viewer", {}).get("id") == player.id else JSON.parse_string(driver.world.project_json(player.id))
		player.observe(own, nav)
		if interact != null:
			interact.taken = player.taken_anchors()
		if not player.aboard:
			_seat_faced = false
		if player.present and not _on_ground:
			# Just stepped onto the ground: from a tram, or joining.
			_stepped_onto = nav.room_at(player.cell)
			_stood_s = 0.0
		_on_ground = player.present
		hud.set_player(player.status(), player.observer)
		_take_player_events()
		interaction._follow_reading()
		_follow_watch(own)
		if _fly_waiting and player.present:
			_fly_waiting = false
			_fly_down(Motion.point(player.view["pos"]))
	_show_status(int(p.get("tick", 0)))


## The developer panel's status line, and the HUD's clock and weather.
func _show_status(tick: int) -> void:
	dev.set_status(tick, model.time, driver.viewer, host.style_name(host.pack_dir))
	hud.set_clock(model.time, host.rain)


func _activate(dir: String) -> void:
	var was_first_person := host.first_person
	if host.activate(dir, manifest, model, motion, driver.tick_time):
		dev.show_style(dir)
		# An open Join screen dresses its figure in the style shown now.
		for s in stack.screens:
			if s is JoinScreen:
				s.set_pack(host.pack)
		_apply_skin()
		_drift()
		_show_status(driver.world.tick() if driver.world else 0)
		if was_first_person and not host.first_person:
			_leave_fpv()
			hud.notify(FPV_2D_NOTE, "Switch to low-poly", _to_lowpoly_first_person)
	else:
		hud.show_error("That style could not be shown: " + host.last_error)


## Reskins every open screen in the style now shown.
func _apply_skin() -> void:
	ui = UiTheme.from_style(host.pack.style if host.pack != null else {}, settings.text_scale())
	stack.set_theme(ui)


## A new viewer sees a different set of occupants, so the scene is rebuilt
## from their projection alone.
func _set_viewer(v: String) -> void:
	_drop_landing()
	host.viewer = v
	model = SceneModel.new()
	motion = Motion.new()
	if driver.set_viewer(v) and host.pack_dir != "":
		host.activate(host.pack_dir, manifest, model, motion, driver.tick_time)


func _process(delta: float) -> void:
	if _join_waiting and driver.world != null:
		_join_when_gone()
	# One stage of a landing tick a frame, latest first.
	if _player_due != null:
		_observe(_player_due)
		_player_due = null
	if _views_due != null:
		host.refresh_views(model)
		_player_due = _views_due
		_views_due = null
	if _changes_due != null:
		host.apply_changes(_changes_due[0], motion)
		_views_due = _changes_due[1]
		_changes_due = null
	if _due != null:
		_changes_due = [model.apply(_due), _due]
		_due = null
	host.tick_frame(shown_time(), motion, 0.0 if driver.paused else float(driver.speed), delta)
	_show_screens(delta)
	trams.speed = 0.0 if driver.paused else float(driver.speed)
	if host.pack and router.looking != Vector2.ZERO:
		host.pack.orbit(router.looking, delta)
	# Buildings open as the avatar steps in, before the core admits it.
	var avatar_room = null
	if player.present:
		_show_avatar(delta)
		var room := nav.room_at(player.cell)
		avatar_room = room if room != "" else null
		_settle_on_platform(room, delta)
	elif player.aboard:
		_ride(delta)
	# Everyone is placed for the frame, the player too: plants part round them.
	host.sway(delta)
	host.update_cutaway(avatar_room, _room_of(host.pack.selected if host.pack else ""))
	# What the player acts on now (see InteractionController.frame),
	# computed once here: the prompt and the surface in focus both read
	# it below, rather than asking current_target() again each.
	_update_prompt(delta)
	host.update_surfaces(_surface_focus(), interaction._panel.target if interaction._panel_open() else "", interaction._surface_target())
	# The world keeps running behind the game menu: its header keeps up.
	if is_instance_valid(_menu):
		_menu.header.text = _who()
	# And behind the map, where "you are here" moves live.
	if _map_open():
		_map.you = _you()
		_map.you_facing = _you_facing()
		_map.model.trams.speed = trams.speed


## Moves the prediction on a frame, steering by the router in screen
## terms, and draws the avatar where it shows.
func _show_avatar(delta: float) -> void:
	player.speed = 0.0 if driver.paused else float(driver.speed)
	var steer := Vector2.ZERO
	if host.pack and router.steering != Vector2.ZERO:
		steer = fpv_steer(router.steering) if host.first_person else host.pack.ground_direction(router.steering)
	var trail = motion.sample(player.id, shown_time()) if motion.has(player.id) else null
	var at := player.predict(delta, steer, nav, trail["pos"] if trail != null else null)
	_notice_turned_away()
	var dir: Vector2 = trail["dir"] if player.following and trail != null else player.heading
	# It walks while it is shown moving: along the replayed trail when
	# following, else while the prediction steps.
	var walking := motion.pace(player.id) > 0.0 if player.following else player.walking
	var stride := motion.pace(player.id) * player.speed if player.following else StylePack.WALK_CM_S * player.speed
	var rest: String = model.occupants.get(player.id, {}).get("pose", "standing")
	host.place_avatar(at, dir, "walking" if walking else ("standing" if rest == "walking" else rest), stride)
	if walking and host.pack and not host.first_person:
		host.pack.keep_in_view(at, delta)
	hud.set_player(player.status(), player.observer)
	if host.first_person:
		host.pack.fpv_follow(at)


## A camera preset is an overhead view: asking for one leaves first person.
func _on_camera(preset: String) -> void:
	if host.first_person:
		_leave_fpv()
	host.set_camera(preset)


## Every frame: what A does now (see InteractionController.frame, which
## this calls) on the prompt, the overhead reticle on the target it acts
## on, and in first person the name tag of whoever the crosshair rests
## on. `delta` is passed on to `frame`; callers off the per-frame path
## (a test asking for the prompt right after changing something) may
## leave it out.
func _update_prompt(delta := 0.0) -> void:
	if host.pack == null:
		return
	interaction.frame(delta, {"player": player})
	var now := interaction.prompt
	var target: Dictionary = now.get("target", {})
	var marked = null
	if not host.first_person and target.get("type") in ["placement", "seat"] and not target.has("using"):
		marked = target["pos"]
	host.pack.show_reticle(marked)
	_set_prompt(now["text"], now.get("action", ""), now.get("more", false))
	if host.first_person:
		var seen: Dictionary = now.get("seen", {})
		_look_at(str(seen["target"]) if seen.get("type") == "person" else "")


## The last prompt given to the HUD, so it changes only when its text,
## button, "more" hint or device does.
var _prompt_shown := ""


## What the act button does now, on the HUD; not with `--no-hud`. With no
## `action` the prompt only says what is happening; `more` shows the hint
## that E or Y cycles the target's other verbs.
func _set_prompt(text: String, action := "interact", more := false) -> void:
	if options.get("no_hud", false):
		return
	var shown := "%s|%s|%s|%s" % [text, action, more, glyphs.device]
	if shown == _prompt_shown:
		return
	_prompt_shown = shown
	hud.set_prompt(action, text, more)


## Keeps the tram from being offered on the platform the player stepped
## onto (`_stepped_onto`) until it has stood still there OFFER_AFTER_S
## seconds; leaving that room ends the wait at once, so walking back onto
## it, or onto any other platform, offers the tram straight away.
func _settle_on_platform(room: String, delta: float) -> void:
	if _stepped_onto == "":
		return
	if room != _stepped_onto:
		_stepped_onto = ""
	elif player.walking or player.following:
		_stood_s = 0.0
	else:
		_stood_s += delta
		if _stood_s >= OFFER_AFTER_S:
			_stepped_onto = ""


# ---- The tram ----

## Whether the player is waiting to ride in: its join queued at a portal
## (the core shows no one there), or the last visit still leaving.
func _joining() -> bool:
	return _join_waiting or player.id != "" and player.view.is_empty() and not player.aboard


## While the player waits to ride in (see _joining), what the HUD says:
## "Your tram reaches the Square in N s", N by the timetable
## (TramTimes.ticks_to_ride_in); "" when players do not arrive by tram.
func join_prompt() -> String:
	var at := trams.platform(arrival_platform())
	if at.is_empty():
		return ""
	var n := trams.seconds_to_ride_in(at["line"], at["stop"], driver.tick_time)
	var name := trams.stop_name(at["line"], at["stop"])
	return "Your tram reaches the %s in %d s" % [name, n] if n >= 0 else "Your tram is on its way to the %s" % name


## What the tram means for the act button now (tram spec section 5):
## {text, act}, where `act` is what A does ("board" or "alight"), or ""
## when the prompt only says what is happening; {} when the player is
## nowhere near a tram.
## - on a platform with a stop ahead: "Board" while a tram stands there
##   with its doors open, else "Wait for the tram"; both send Board. Not
##   on the platform just stepped onto from a tram, until the player has
##   stood still there a while (see _settle_on_platform);
## - on a platform with no stop ahead (the line's last, that way): which
##   platform the trams on leave from ("Trams west leave from the other
##   platform"), sending nothing;
## - waiting: "Waiting — tram in N s";
## - aboard, standing with the doors open: "Get off here", sending Alight;
## - aboard, running: "Next: <stop>";
## - waiting to ride in: "Your tram reaches the Square in N s" (see
##   join_prompt).
func tram_prompt() -> Dictionary:
	if _joining():
		var text := join_prompt()
		return {} if text == "" else {"text": text, "act": ""}
	if player.id == "":
		return {}
	if player.aboard:
		var v := trams.vehicle(player.view.get("vehicle"))
		if v.get("doors_open", false):
			return {"text": "Get off here", "act": "alight"}
		var next := trams.next_stop(v)
		return {} if next.is_empty() else {"text": "Next: " + str(next.get("name", "")), "act": ""}
	if not player.present or player.view.get("seat") != null:
		return {}
	if player.waiting:
		var wait: Dictionary = player.view["waiting_for"]
		var stop := str(wait.get("stop", ""))
		var n := trams.seconds_until(trams.line_of_stop(stop), stop, 1 if wait.get("direction") == "west" else 0, driver.tick_time)
		return {"text": "Waiting — tram in %d s" % n if n >= 0 else "Waiting for the tram", "act": ""}
	var room := nav.room_at(player.cell)
	var at := trams.platform(room)
	if at.is_empty() or room == _stepped_onto:
		return {}
	if not trams.runs_on(at["line"], at["stop"], at["direction"]):
		var other := 1 - int(at["direction"])
		if trams.runs_on(at["line"], at["stop"], other):
			return {"text": "Trams %s leave from the other platform" % TramTimes.DIRECTIONS[other], "act": ""}
		return {}
	if not trams.standing_open(at["line"], at["stop"], at["direction"]).is_empty():
		return {"text": "Board", "act": "board"}
	return {"text": "Wait for the tram", "act": "board"}


## Where the player rides now: {pos (cm, over the ground), dir (the way
## its tram runs), heading (degrees clockwise from north), vehicle (the
## tram's view)}, the tram eased along its track as it is drawn; {} when
## not aboard a tram seen.
func _rider_place() -> Dictionary:
	var vehicle_id = player.view.get("vehicle")
	var v := trams.vehicle(vehicle_id)
	if not player.aboard or v.is_empty():
		return {}
	var front := Motion.point(v.get("pos", {}))
	var dir := Vector2.ZERO
	if motion.has(vehicle_id):
		var s := motion.sample(vehicle_id, shown_time())
		front = s["pos"]
		dir = s["dir"]
	if dir == Vector2.ZERO:
		var h := deg_to_rad(float(v.get("heading", 90)))
		dir = Vector2(sin(h), -cos(h))
	var spec: Dictionary = trams.lines.get(v.get("line"), {}).get("vehicle", {})
	var local := CityGeometry.slot_local(spec, player.view.get("slot"))
	var left := Vector2(dir.y, -dir.x)
	return {"pos": front + dir * local.x + left * local.y, "dir": dir,
		"heading": fposmod(rad_to_deg(atan2(dir.x, -dir.y)), 360.0), "vehicle": v}


## Where the player rides over the ground now (cm), or zero when not
## aboard.
func rider_ground() -> Vector2:
	var place := _rider_place()
	return place["pos"] if not place.is_empty() else Vector2.ZERO


## Aboard a tram, a frame: overhead the view keeps the tram in sight; in
## first person the eye sits at the player's seat, turning with the tram,
## and on first sitting looks out on the platform side (the anime TRANSIT
## view). Nothing walks: steering is not the rider's.
func _ride(delta: float) -> void:
	if host.pack == null:
		return
	var place := _rider_place()
	if place.is_empty():
		return
	if not host.first_person:
		host.pack.keep_in_view(place["pos"], delta)
		return
	host.pack.fpv_seat(_seat_eye(place), place["heading"])
	if not _seat_faced:
		_seat_faced = true
		var v: Dictionary = place["vehicle"]
		var stop := trams.next_stop(v)
		var direction := 1 if v.get("direction") == "west" else 0
		var side := trams.platform_side(str(v.get("line", "")), str(stop.get("id", "")), direction, place["pos"], place["dir"])
		var dir: Vector2 = place["dir"]
		var out := Vector2(dir.y, -dir.x) * side
		var fpv: FpvCamera = host.pack.fpv
		fpv.look(FpvCamera.yaw_along(out) - fpv.yaw, -fpv.pitch)


## The first-person eye aboard (metres): over the player's drawn body in
## its slot, at a seated or a standing eye height as it is posed; over its
## ground place where the body is not drawn in 3D.
func _seat_eye(place: Dictionary) -> Vector3:
	var body = host.pack.nodes.get(player.id)
	if body is Node3D and body.is_inside_tree():
		var sitting: bool = host.pack.poses.get(player.id) == "sitting"
		return body.global_position + Vector3.UP * (FpvCamera.SEATED_EYE if sitting else FpvCamera.EYE_HEIGHT)
	var at: Vector2 = place["pos"] / 100.0
	return Vector3(at.x, FpvCamera.EYE_HEIGHT, at.y)


## The player's own events since the last projection: notices for the
## tram's.
func _take_player_events() -> void:
	if driver.world == null or not driver.world.has_method("take_player_events"):
		return
	var events = JSON.parse_string(driver.world.take_player_events())
	if events is Array and not events.is_empty():
		_notice_events(events)


## Notices for the player's own events: a full tram leaving it behind
## ("The tram is full — next one in N s"), being stepped off the rails for
## a tram it stood in the way of, and each refusal of a Board or an
## Alight (or a Use boarding); a Use refused because the anchor is taken,
## reserved or out of reach, or a room seat's Go refused so with a Use
## waiting on it; and for full rooms, a steered step refused at
## a full room's door, a Go queued for one, and a Go let into the next room
## of the overflow chain. Other refusals (a steered step the core would not
## take) are the prediction's to correct.
func _notice_events(events: Array) -> void:
	for e in events:
		var kind: Dictionary = e.get("kind", {}) if e is Dictionary else {}
		match kind.get("type"):
			"LeftBehind":
				var stop := str(kind.get("stop", ""))
				# The way the player waits: its own wait, else its platform's.
				var wait = player.view.get("waiting_for")
				var direction := int(trams.platform(nav.room_at(player.cell)).get("direction", 0))
				if wait is Dictionary and wait.get("direction") != null:
					direction = 1 if wait["direction"] == "west" else 0
				var n := trams.seconds_until(trams.line_of_stop(stop), stop, direction, driver.tick_time)
				hud.notify("The tram is full — next one in %d s" % n if n >= 0 else "The tram is full — wait for the next one")
			"SteppedAside":
				hud.notify(STEPPED_ASIDE_NOTICE)
			"Waitlisted":
				var room := _room_name(str(kind.get("room", "")))
				if int(kind.get("position", 1)) == 1:
					hud.notify("You're next in line for the %s." % room)
				else:
					hud.notify("You're in line for the %s." % room)
			"Overflowed":
				hud.notify("The %s is full; you've been let into the %s." % [_room_name(str(kind.get("from", ""))), _room_name(str(kind.get("to", "")))])
			"Rejected":
				var reason = kind.get("reason")
				var command := str(kind.get("command", ""))
				if command == "Use":
					# A read refused never opens its overlay.
					interaction.clear_awaited_read()
				# A use waiting on a refused walk will not happen. A room seat
				# is reached by Go {Seat} first, so the loser of a race for
				# it hears here why its sit never came.
				var seat_lost := ""
				if command == "Go":
					if player.use_waiting() and str(reason) in ["SeatTaken", "NotYourSeat"]:
						seat_lost = "AnchorTaken" if str(reason) == "SeatTaken" else "NotYourSeat"
					player.forget_use()
				if seat_lost != "":
					hud.notify(use_notice(seat_lost))
				elif command in ["Board", "Alight"] or command == "Use" and player.last_use == "board":
					hud.notify(tram_notice(str(kind.get("reason", ""))))
				elif reason is Dictionary and reason.has("RoomFull"):
					_turned_away_told = str(reason["RoomFull"].get("room", ""))
					hud.notify(room_full_notice(_room_name(_turned_away_told)))
				elif command == "Use" and use_notice(str(reason)) != "":
					# Sent from short of an anchor someone holds: the core
					# checks where the player stands first, but the reason is
					# the one holding it.
					var why := "AnchorTaken" if player.last_use_held and str(reason) == "NotAtAnchor" else str(reason)
					hud.notify(use_notice(why))


## The room the player was last told it was turned away from at the door,
## by the core or by its own prediction: each turning away is told once.
var _turned_away_told := ""


## The notice for a Use the core refused, by its reason; "" for a refusal
## the player need not read.
static func use_notice(reason: String) -> String:
	match reason:
		"AnchorTaken":
			return "Someone is already there."
		"NotYourSeat":
			return "That seat is reserved for someone else."
		"NotAtAnchor":
			return "Step up to it to use it."
	return ""


## Tells the player when its steering is turned away at a full room's door.
## The prediction refuses that step as the core would, so no refusal comes
## back from the core to raise the notice.
func _notice_turned_away() -> void:
	if player.turned_away == _turned_away_told:
		return
	_turned_away_told = player.turned_away
	if _turned_away_told != "":
		hud.notify(room_full_notice(_room_name(_turned_away_told)))


## The notice for a steered step refused at the door of `room` (its name).
static func room_full_notice(room: String) -> String:
	return "The %s is full — choose Go in to queue." % room


## A room's name as the layout gives it, or its ID when the layout has no
## such room.
func _room_name(id: String) -> String:
	for d in manifest.get("city", {}).get("districts", []):
		for f in d.get("facilities", []):
			for r in f.get("rooms", []):
				if str(r.get("id", "")) == id:
					return str(r.get("name", id))
	return id


## The notice for a Board or an Alight the core refused, by its reason.
static func tram_notice(reason: String) -> String:
	match reason:
		"NotOnPlatform":
			return "Stand on a tram platform to wait for the tram."
		"VehicleFull":
			return "This tram is full — wait here for the next one."
		"NotYourDirection":
			return "No tram runs on from this platform — cross to the other one."
		"NotStanding":
			return "The doors are shut — get off at the next stop."
		"NotAboard":
			return "You are not on a tram."
	return "The tram could not do that."


# ---- The map ----

## Opens the map over whatever is on top (play, the game menu or the
## title), with `place_id` (a facility or a room) selected when given. It
## shows the latest projection's counts and where the player, or the
## viewer followed, is now.
func open_map(place_id := "") -> void:
	if host.pack == null or manifest.is_empty() or _map_open():
		return
	if host.first_person:
		_capture_mouse(false)
	_map = MapScreen.new()
	_map.model = MapModel.from_layout(manifest)
	_map.model.add_things(host.surfaces)
	_map.host = host
	_map.glyphs = glyphs
	_map.theme_map = MapTheme.from_style(host.pack.style)
	_map.projection = _last_projection
	_map.you = _you()
	_map.you_facing = _you_facing()
	_map.go.connect(_on_map_go)
	_map.read.connect(_read_from_map)
	# Pushed before it opens: opening stops the main view's 3D, and only a
	# map in the tree has a view to stop.
	stack.push(_map)
	_map.open(place_id)


func _map_open() -> bool:
	return is_instance_valid(_map) and stack.screens.has(_map)


## M or the left-stick press in play opens the map. The press is used up
## here, so it cannot reach the map it opened and close it again.
func _on_map_intent() -> void:
	if stack.top() == hud:
		open_map()
	if is_inside_tree():
		get_viewport().set_input_as_handled()


## "You are here", in metres: the player where they show, else the viewer
## followed, else no one.
func _you():
	if player.present:
		return player.shown / 100.0
	if player.aboard:
		var place := _rider_place()
		if not place.is_empty():
			return place["pos"] / 100.0
	var v := driver.viewer
	if v != "" and v != "public" and motion.has(v):
		return (motion.sample(v, shown_time())["pos"] as Vector2) / 100.0
	return null


## Which way "you" face: the way the player walks, or at rest the way they
## face; the viewer followed's direction of travel; zero for no one.
func _you_facing() -> Vector2:
	if player.aboard:
		return _rider_place().get("dir", Vector2.ZERO)
	if player.present:
		if player.heading != Vector2.ZERO:
			return player.heading
		var facing := deg_to_rad(float(player.view.get("facing", 0)))
		return Vector2(sin(facing), -cos(facing))
	var v := driver.viewer
	if v != "" and v != "public" and motion.has(v):
		return motion.sample(v, shown_time())["dir"]
	return Vector2.ZERO


## The map's Go for `place_id` (a facility). The map closes, and the game
## menu under it. A player walks to its first room by the core's rules,
## a refusal shown as a notice; first person stays first person. Watching,
## the view glides there keeping its heading, out of first person first.
## From the title nobody joins: the title's camera goes there, stops
## drifting, and the title stays.
func _on_map_go(place_id: String) -> void:
	var place := _map.model.place(place_id)
	stack.remove(_map)
	if is_instance_valid(_menu) and stack.top() == _menu:
		stack.remove(_menu)
	if place.is_empty():
		return
	var centre_cm: Vector2 = (place["centre"] as Vector2) * 100.0
	var seconds := 0.0 if settings.calm() else MAP_FLIGHT_S
	if _title != null:
		host.pack.title_drift(false)
		host.pack.fly_to(centre_cm, seconds, true)
		return
	if player.id == "":
		if host.first_person:
			_leave_fpv()
		host.pack.fly_to(centre_cm, seconds, true)
		return
	var rooms: Array = place.get("rooms", [])
	if rooms.is_empty():
		return
	if player.aboard:
		# A ride can't be left between stops.
		hud.notify("Get off the tram first: A at the next stop.")
		return
	if player.present and player.view.get("seat") != null:
		player.stop_using()
	var r := player.go_room(_go_room(rooms))
	if r.has("error") or r.get("ok") == false:
		hud.notify("Can't go there: " + _reason(r.get("error")))


## Which of a place's `rooms` the map's Go walks to: at a tram stop, the
## platform trams leave from, going on to another stop (at the Avenue, the
## westbound one); otherwise the first room.
func _go_room(rooms: Array) -> String:
	for r in rooms:
		var at := trams.platform(str(r["id"]))
		if not at.is_empty() and trams.runs_on(at["line"], at["stop"], at["direction"]):
			return str(r["id"])
	return str(rooms[0]["id"])


## A refusal's reason, in words.
static func _reason(error) -> String:
	if error is Dictionary:
		return str(error.get("message", error.get("code", "refused")))
	return str(error) if error != null else "refused"


# ---- First-person view ----

## F / View: into first person in a 3D style (a note in 2D), or out.
func _toggle_fpv() -> void:
	if host.first_person:
		_leave_fpv()
		return
	if not player.present and not player.aboard:
		hud.notify("Join as a player to walk in first person (launch with --as=registered).")
		return
	if host.pack == null or not host.pack.supports_fpv():
		# Per the --fpv-in-2d setting: offer the nearest 3D style, or stay.
		if options.get("fpv_in_2d", "offer") == "stay":
			hud.notify(FPV_2D_NOTE)
		else:
			hud.notify(FPV_2D_NOTE, "Switch to low-poly", _to_lowpoly_first_person)
		return
	var h := player.heading
	if host.set_fpv(true, rad_to_deg(atan2(-h.x, -h.y)) if h != Vector2.ZERO else 0.0):
		hud.dismiss_notices()
		hud.show_crosshair(true)
		host.pack.fpv_follow(player.shown)
		_capture_mouse(true)


func _leave_fpv() -> void:
	_seat_faced = false
	_capture_mouse(false)
	_look_at("")
	host.set_fpv(false)
	hud.show_crosshair(false)


func _to_lowpoly_first_person() -> void:
	for d in styles:
		if d.get_file() == "lowpoly_tropical":
			_activate(d)
			_toggle_fpv()
			return


func _capture_mouse(on: bool) -> void:
	if host.pack != null and host.pack.fpv != null:
		host.pack.fpv.captured = on
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	glyphs.note(event)
	# Looking round with the mouse is the world's, and stops with the rest
	# of it while a screen (the station computer above all) has the input.
	if not router.world_enabled:
		return
	if event is InputEventMouseMotion and host.first_person and host.pack != null and host.pack.fpv != null:
		host.pack.fpv.handle(event)


## A screen steer (x right, y down) as a ground direction in first
## person: up the screen walks where the eye faces, whatever its pitch.
func fpv_steer(screen_dir: Vector2) -> Vector2:
	var ahead: Vector2 = host.pack.fpv.forward()
	var right := Vector2(-ahead.y, ahead.x)
	return (right * screen_dir.x - ahead * screen_dir.y).normalized()


## Shows the name tag of whoever the first-person view rests on.
func _look_at(id: String) -> void:
	var pack: StylePack = host.pack
	if pack.hovered == id:
		return
	var was := pack.hovered
	pack.hovered = id
	pack.refresh_label(was)
	pack.refresh_label(id)


## A / Space, in every view, does what the prompt says (see
## InteractionController.choice): aboard, step off at a stop; on a
## platform, wait for the tram or board it; otherwise the verb shown for
## what the player uses or faces.
func _interact() -> void:
	# Waiting, A does nothing (the prompt asks for nothing): acting on the
	# crosshair would walk the player off the platform and end the wait.
	if player.waiting:
		return
	var now := interaction.choice()
	if now.get("tram", {}).get("act") == "alight":
		player.alight()
	elif now.has("target"):
		interaction._act(now["target"], int(now.get("verb", 0)))


## E / Y: the prompt shows the target's next verb.
func _next_verb() -> void:
	if interact != null and interaction.choice().has("verb"):
		interact.cycle()


## Where the displays' level of detail is measured from: the player where
## it shows, else the camera's point on the ground (null for none).
func _surface_focus():
	if player.present:
		return player.shown
	return host.pack.camera_ground_pos() if host.pack != null else null


## A display chosen on the map's List tab: its overlay, read, over the map.
func _read_from_map(id: String) -> void:
	var kind := ""
	for t in interact.things:
		if t["target"] == id:
			kind = t["kind"]
	interaction._open_panel({"type": "placement", "target": id, "kind": kind}, true)


## Backspace / B: stops a walk, and in first person frees the mouse too.
func _cancel() -> void:
	if host.first_person and host.pack.fpv != null and host.pack.fpv.captured:
		_capture_mouse(false)
	player.cancel()


func _room_of(id: String):
	if id == "" or not model.occupants.has(id):
		return null
	return model.occupants[id]["room"]


## A click (or a tap) on someone selects them; on a placement or seat
## (see Interact.targets' touch) that offers more than Inspect it acts
## with that target's first verb, so a free seat is sat on and a
## noticeboard read; elsewhere on the ground, and on something that offers
## only Inspect (a tree, a lamp, a block's lot: a click to walk past one
## must walk), it walks the player there (Go, not predicted). Inspect is
## the prompt's, on the thing ahead, or E's.
func _on_walk_to(screen_pos: Vector2) -> void:
	if host.pack == null:
		return
	if host.first_person:
		# In first person a click takes the mouse back; A / Space acts.
		_capture_mouse(true)
		return
	var who := host.pack.pick(screen_pos)
	host.set_selected(who)
	if who != "" or not player.present:
		return
	var ground = host.pack.ground_at(screen_pos)
	if ground == null:
		return
	var tapped := interaction.tap_target(ground)
	if not tapped.is_empty() and Interact.usable(tapped):
		interaction._act(tapped, 0)
	else:
		player.go_point(ground)


func _capture(path: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("captured ", path)
	get_tree().quit()


# ---- The station computer ----

## The station computer's source: live once signed in with live mode on,
## else Sample station. Called when something changes it (booting, the
## station settings, signing in, disconnecting) and as the computer opens;
## `station_source` keeps the answer for readers each frame (see
## _may_watch). A live source is made once per credential, and lists the
## player's stations as it is made, so "Look at screen" knows which bound
## desks it may offer (Review Focus 5).
func _station_source() -> StationSource:
	var credential := _station_credential()
	if credential != null and credential.is_signed_in():
		var made := _live_source == null or _live_source.credential != credential
		if made:
			_replace_live_source(LiveSource.new(credential))
		_live_source.hub_url = str(settings.get_value("station", "hub_url"))
		_live_source.superpipeline_url = str(settings.get_value("station", "superpipeline_url"))
		if made:
			_live_source.list_stations()
		station_source = _live_source
		return station_source
	if _sample_source == null:
		_sample_source = SampleSource.new()
	station_source = _sample_source
	return station_source


## Puts `next` (or nothing) in place of the live source, which forgets
## the stations it listed: another account's, or none now.
func _replace_live_source(next: LiveSource) -> void:
	if _live_source != null:
		_live_source.forget_stations()
	_live_source = next


## The sign-in, for the hub and client the settings name, made when live
## mode is on in a desktop build; null otherwise, so live mode off makes
## nothing that could connect.
func _station_credential() -> StationCredential:
	if not bool(settings.get_value("station", "live")) or ComputerScreen.current_platform() != "desktop":
		return null
	return _credential_object()


## The credential object for the hub and client the settings name, made or
## remade. Remaking it (the hub or client changed) cancels the browser flow
## the old one had under way, a Disconnect's included, which then lands on
## "not revoked"; the old one is kept until it has said so, and otherwise
## freed, its secret with it: its connections name it by instance ID, since
## a credential bound into its own connections would hold itself for good,
## and the live source made for it goes too.
func _credential_object() -> StationCredential:
	var hub := str(settings.get_value("station", "hub_url"))
	var client := str(settings.get_value("station", "client_id"))
	if station_credential == null or station_credential.hub_url != hub or station_credential.client_id != client:
		if station_credential != null and (station_credential.is_signing_in() or station_credential.is_disconnecting()):
			_retiring_credential = station_credential
			station_credential.cancel_browser()
		station_credential = StationCredential.new(hub, client, _credential_path())
		station_credential.open_browser = open_browser
		var credential_id := station_credential.get_instance_id()
		station_credential.sign_in_finished.connect(func(ok: bool, message: String) -> void:
			_on_sign_in_finished(ok, message, instance_from_id(credential_id) as StationCredential))
		station_credential.disconnect_finished.connect(func(revoked: bool, message: String) -> void:
			_on_disconnect_finished(revoked, message, instance_from_id(credential_id) as StationCredential))
		if _live_source != null and _live_source.credential != station_credential:
			_replace_live_source(null)
	return station_credential


## The hub or client changed: a credential made for the old ones is
## replaced now, so a flow it had under way ends at once.
func _on_station_address_changed() -> void:
	if station_credential != null:
		_credential_object()
	_station_source()
	_show_station_account()


## The test run's own credential file unless a test chose one.
func _credential_path() -> String:
	if credential_path == StationCredential.PATH and _is_test_run():
		return TEST_CREDENTIAL_PATH
	return credential_path


## "Connect your AgentPod" or "Sign in again": signing in starts, with live
## mode on and on a desktop.
func _on_sign_in_requested(screen: ComputerScreen) -> void:
	if not bool(settings.get_value("station", "live")):
		return
	if screen.platform != "desktop":
		screen.show_station_note(ComputerScreen.DESKTOP_ONLY_NOTE)
		return
	var credential := _station_credential()
	if credential == null or credential.is_signing_in() or credential.is_disconnecting():
		return
	screen.show_station_note(SIGNING_IN)
	credential.sign_in()


## Signing in ended: the computer starts over on the live source, or says
## why it could not. A device held before that could not be revoked is
## named, with the console offered.
func _on_sign_in_finished(ok: bool, message: String, credential: StationCredential) -> void:
	if credential == _retiring_credential:
		_retiring_credential = null
	_station_note = message
	_station_console_hint = credential.console_hint
	_show_station_account()
	if ok:
		# Maybe another account: a new source, which lists its own stations.
		_replace_live_source(null)
	_station_source()
	if ok and _computer_open():
		computer.open(computer.desk, station_source, computer.watch)


## "Disconnect", on the computer or in Settings: the credential is
## forgotten at once, so the computer starts over on Sample station, and
## the browser revokes the device; how that went is shown when it ends.
func _on_disconnect_requested(_screen: ComputerScreen) -> void:
	_disconnect_station()


## Disconnect works whenever a credential is held, with live mode off too:
## the player can always take the city's access away. (Where no browser
## flow can run, it is forgotten and named as not revoked.)
func _disconnect_station() -> void:
	var credential := _credential_object()
	if credential.is_disconnecting() or credential.device_id == "":
		return
	credential.disconnect_device()
	_replace_live_source(null)
	_station_source()
	_station_note = DISCONNECTING
	_station_console_hint = false
	_show_station_account()
	if _computer_open():
		computer.open(computer.desk, station_source, computer.watch)


func _on_disconnect_finished(revoked: bool, message: String, credential: StationCredential) -> void:
	if credential == _retiring_credential:
		_retiring_credential = null
	_station_note = message
	_station_console_hint = not revoked
	_show_station_account()


## Shows the sign-in's news on the computer and in Settings, whichever are
## open.
func _show_station_account() -> void:
	if _computer_open():
		computer.show_station_note(_station_note, _station_console_hint)
	if is_instance_valid(_settings_screen) and stack.screens.has(_settings_screen):
		# Read from the file, so live mode off makes nothing to show it.
		var held := StationCredential.holds_device(_credential_path())
		var running := station_credential != null and station_credential.is_disconnecting()
		_settings_screen.show_station_account(held, running, _station_note, _station_console_hint)


## The AgentPod console's own page, where a device can be revoked by hand.
func _open_console_home() -> void:
	var base := str(settings.get_value("station", "console_url")).rstrip("/")
	if base != "":
		open_browser.call(base)


## The core confirmed the player using a workstation's computer: the camera
## settles behind the chair and the computer opens.
func _on_use_began(target: Dictionary, capability: String) -> void:
	if capability != "use" or target.get("kind") != "workstation" or _computer_open():
		return
	var chair := _chair_of(target)
	_view_before_computer = host.pack.settle_view(chair["pos"], chair["facing"]) if host.pack != null else null
	open_computer(target, false)


## The using ended without the computer's Stand up: the core released or
## moved the player (or it switched to sitting). The computer closes and
## sends nothing more.
func _on_use_ended(target: Dictionary) -> void:
	if _computer_open() and not computer.watch and computer.desk.get("target") == str(target.get("target", "")):
		stack.remove(computer)


## "Look at screen": the computer in watch mode, where the source allows
## it (see _may_watch). The prompt offers it nowhere else, so the refusal
## is for a target chosen before the source changed.
func _on_watch_requested(target: Dictionary) -> void:
	if _computer_open():
		return
	var desk := interaction.desk_of(target)
	if not _may_watch(target):
		hud.notify(WATCH_REFUSED)
		return
	open_computer(target, true)
	_watching = {"cell": player.cell, "desk": desk["target"],
		"occupant": str(InteractionController.occupant_at(_last_projection, desk["target"]).get("id", ""))}


## Whether the player may look at the screen of `target`'s desk: in
## sample mode only where an agent sits, and live only at a desk bound to a
## station the player's source can see (Review Focus 5; see
## ComputerScreen.may_watch). The interaction controller asks it before
## offering "Look at screen".
func _may_watch(target: Dictionary) -> bool:
	if station_source == null:
		return false
	var desk := interaction.desk_of(target)
	var agent_sits := InteractionController.agent_sits_at(_last_projection, desk["target"])
	return ComputerScreen.may_watch(desk, station_source, agent_sits)


## Watch mode ends by itself, each projection: when the watcher is no
## longer where it stood (it walked or was moved), or the one it watched
## no longer sits at the desk.
func _follow_watch(own: Dictionary) -> void:
	if _watching.is_empty() or not _computer_open() or not computer.watch:
		return
	var occupant := str(InteractionController.occupant_at(own, _watching["desk"]).get("id", ""))
	if not player.present or player.cell != _watching["cell"] or occupant != _watching["occupant"]:
		stack.remove(computer)


## Opens the station computer on `target`'s desk, to use or to watch.
func open_computer(target: Dictionary, watch: bool) -> ComputerScreen:
	if host.first_person:
		_capture_mouse(false)
	computer = ComputerScreen.new()
	computer.settings = settings
	computer.glyphs = glyphs
	computer.links_path = TEST_LINKS_PATH if _is_test_run() else StationLinks.PATH
	computer.left.connect(_on_computer_left.bind(computer))
	computer.settings_requested.connect(_open_settings)
	computer.sign_in_requested.connect(_on_sign_in_requested.bind(computer))
	computer.disconnect_requested.connect(_on_disconnect_requested.bind(computer))
	computer.tree_exiting.connect(_on_computer_closed.bind(computer))
	stack.push(computer)
	computer.open(interaction.desk_of(target), _station_source(), watch)
	monitor.computer = computer
	return computer


## The player left the computer: using it, that is standing up, sent
## through the normal path; watching sent nothing to begin with.
func _on_computer_left(screen: ComputerScreen) -> void:
	if not screen.watch:
		player.stop_using()
		interaction.offer_reopen(str(screen.desk.get("target", "")))


## However the computer closed, the camera goes back.
func _on_computer_closed(screen: ComputerScreen) -> void:
	if screen != computer:
		return
	_watching = {}
	if is_instance_valid(host.pack) and _view_before_computer != null:
		host.pack.restore_view(_view_before_computer)
	_view_before_computer = null
	computer = null


## The seats and placements someone sits at or uses in `projection`, as a
## set: every screen shows in use there and idle elsewhere. A seat taken
## by someone still walking to it is not in use yet.
static func _occupied_desks(projection: Dictionary) -> Dictionary:
	var out := {}
	for target in Player.users_by_target(projection):
		out[target] = true
	return out


## The workstations' screens for the frame, on the pack shown now: the
## player's own computer fed to its desk while seated there or watching
## close by (StationMonitor).
func _show_screens(delta: float) -> void:
	if monitor.pack != host.pack:
		monitor.set_pack(host.pack)
	monitor.viewer_at = _you()
	monitor.advance(delta)


func _computer_open() -> bool:
	return is_instance_valid(computer) and stack.screens.has(computer)


## Where the chair is (cm) and the way its sitter faces (degrees clockwise
## from north), from a workstation target (see Interact.in_use).
static func _chair_of(target: Dictionary) -> Dictionary:
	var facing := 0
	var thing: Dictionary = target.get("thing", {})
	for a in thing.get("anchors", []):
		if a["type"] == "sit":
			facing = int(a["facing"])
			break
	return {"pos": target.get("pos", Vector2.ZERO), "facing": facing}
