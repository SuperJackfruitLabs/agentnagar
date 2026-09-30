## The station computer (spec sections 4 and 5, Part B's Task 5): the
## full-screen screen a workstation opens, with its bezel, desktop and dock;
## the rules for its focus and for leaving it; the hand-off from using a
## desk, and back; the station chooser; watch mode; and the settings'
## `station` section.
extends TestSuite

const SETTINGS_FILE := "user://test_computer_screen.cfg"


## A source that answers as the tests say, on the next frame, as a real one
## would: the stations it lists, or a failure of one kind.
class StubSource extends StationSource:
	var live := false
	var rows: Array = []
	var fail_kind := ""

	func _is_live() -> bool:
		return live

	func list_stations() -> int:
		var call_id := _new_call_id()
		var tree := Engine.get_main_loop() as SceneTree
		tree.process_frame.connect(func() -> void:
			if fail_kind != "":
				result.emit(call_id, false, StationSource.make_error(fail_kind, "refused"), 403)
				return
			stations.emit(rows.duplicate(true))
			result.emit(call_id, true, {"stats": {}, "agents": rows.duplicate(true)}, 200), CONNECT_ONE_SHOT)
		return call_id

	func health(_station_id: String) -> int:
		return _new_call_id()

	func files(_station_id: String, _path: String) -> int:
		return _new_call_id()

	func file(_station_id: String, _path: String, _max_bytes: int) -> int:
		return _new_call_id()

	func lifecycle(_station_id: String, _action: String) -> int:
		return _new_call_id()

	func changeset_status(_station_id: String, _base: String) -> int:
		return _new_call_id()

	func changeset_diff(_station_id: String, _side: String, _path: String) -> int:
		return _new_call_id()

	func open_logs(_station_id: String) -> StationStream.Logs:
		return null

	func open_terminal(_station_id: String) -> StationStream.Terminal:
		return null

	func open_chat(_station_id: String, _mode: String, _new_session := false) -> StationStream.Chat:
		return null

	func watch_chat(_station_id: String) -> StationStream.Chat:
		return null

	func end_chat(_session_id: String) -> int:
		return _new_call_id()

	func boards() -> int:
		return _new_call_id()

	func board(_board_id: String) -> StationStream.Board:
		return null

	func agents() -> int:
		return _new_call_id()

	func card_activities(_board_id: String, _card_id: String) -> int:
		return _new_call_id()

	func move_card(_board_id: String, _card_id: String, _to_stage: String) -> int:
		return _new_call_id()

	func resolve_gate(_board_id: String, _gate_id: String, _decision: String, _comment: String) -> int:
		return _new_call_id()

	func answer(_board_id: String, _elicitation_id: String, _option: String, _text: String) -> int:
		return _new_call_id()


## Passes a world's calls through, noting each command sent.
class Recorder:
	var world
	var sent: Array

	func _init(world_, sent_: Array) -> void:
		world = world_
		sent = sent_

	func command(json: String) -> String:
		sent.append(JSON.parse_string(json))
		return world.command(json)

	func leave() -> String:
		return world.leave()


## A `FleetAgent` of the protocol's shape.
static func station_row(id: String, capabilities: Array, name := "Build box") -> Dictionary:
	return {
		"stationId": id, "nodeId": "node_1", "nodeName": "node-one", "agentName": name, "harness": "claude-code",
		"kind": "leaf", "nodeStatus": "online", "agentVersion": "1.0.0", "latestVersion": "1.0.0",
		"updateAvailable": false, "capabilities": capabilities, "workspacePath": "/work/repo", "status": "running",
		"cpuPct": 1.0, "memBytes": 1000, "uptimeSec": 60,
	}


const EVERY_CAPABILITY := ["health", "logs", "fs.read", "terminal", "lifecycle", "acp", "changeset"]
const HOT_DESK := {"target": "seat:w2", "kind": "workstation", "binding": {}}


func fresh_settings() -> Settings:
	var s := Settings.new()
	s.path = SETTINGS_FILE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s.path))
	s.load_file()
	return s


## A stack with a router under it, as main has, skinned by default.
func stage() -> Array:
	var router := InputRouter.new()
	runner.root.add_child(router)
	var stack := ScreenStack.new()
	stack.router = router
	stack.ui = UiTheme.from_style({})
	runner.root.add_child(stack)
	return [stack, router]


func unstage(pair: Array) -> void:
	pair[0].free()
	pair[1].free()


func computer(stack: ScreenStack, desk: Dictionary, source: StationSource, watch := false, settings: Settings = null) -> ComputerScreen:
	var c := ComputerScreen.new()
	c.settings = settings if settings != null else fresh_settings()
	c.glyphs = InputGlyphs.new()
	c.platform = "desktop"
	c.touch = false
	stack.push(c)
	c.open(desk, source, watch)
	return c


func settle(n := 3) -> void:
	for f in n:
		await runner.process_frame


func key(code: int, pressed := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	if pressed and code >= KEY_A and code <= KEY_Z:
		e.unicode = code + 32
	return e


func pad(button: int, pressed := true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


## Presses and lets go of `code` through the window, as the player would.
func tap(code: int) -> void:
	runner.root.push_input(key(code))
	runner.root.push_input(key(code, false))


func focus_owner() -> Control:
	return runner.root.gui_get_focus_owner()


# ---- The hand-off, through play ----

func thing(main, id: String) -> Dictionary:
	for t in main.interact.things:
		if t["target"] == id:
			return t
	return {}


func frames(main, seconds: float) -> void:
	for f in int(round(seconds * 60.0)):
		main._process(1.0 / 60.0)
		main.driver.advance(1.0 / 60.0)


func tick(main) -> void:
	main.driver.step_once()
	frames(main, 0.05)


## Boots the lowpoly city, lets the player arrive, and has it use the
## reading room's first hot desk, as A on "Use computer" does: a Go to the
## seat, then a Use at its use anchor. Returns {main, sent (the player's
## commands from here on), desk}.
func at_the_computer() -> Dictionary:
	var main = load("res://main.gd").new()
	main.settings_path = SETTINGS_FILE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_FILE))
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=lowpoly_tropical"]))
	for i in 80:
		main.driver.step_once()
		if main.player.present and not main.player.view.get("moving", false):
			break
	assert_true(main.player.present, "arrived")
	var sent := []
	main.player.world = Recorder.new(main.player.world, sent)
	var desk := thing(main, "seat:rw1")
	main.interact.taken = {}
	var target: Dictionary = main.interact.candidate_of(desk, 1)
	assert_eq(main.interact.verbs(target)[0], "Use computer", "a free hot desk offers the computer")
	main.interaction._act(target, 0)
	# The overhead view as it was the frame before the computer opened.
	var rig: OrbitRig = main.host.pack.rig
	var pose := []
	for i in 300:
		if not main._computer_open():
			pose = [rig.position, rig.yaw, rig.pitch, rig.distance]
		tick(main)
		var using = main.player.view.get("using")
		if using is Dictionary and using.get("capability") == "use":
			break
	if not main._computer_open():
		pose = [rig.position, rig.yaw, rig.pitch, rig.distance]
	frames(main, 0.05)
	return {"main": main, "sent": sent, "desk": desk, "pose": pose}


## Using a workstation's computer pushes the computer, the camera settled
## behind the chair; F10 leaves it, which sends StopUsing through the
## normal path, so the player stands up, and the camera goes back.
## Review Focus 3: W, A, S, D, E, Space, Tab, M and Esc typed into the
## terminal never reach the game.
func test_the_hand_off_pushes_the_computer_and_leaving_stands_the_player_up() -> void:
	var run := at_the_computer()
	var main = run["main"]
	var sent: Array = run["sent"]
	var rig: OrbitRig = main.host.pack.rig
	var using = main.player.view.get("using")
	assert_true(using is Dictionary and using.get("target") == "seat:rw1", "the core has the player using the desk: %s" % [using])
	var c = main.stack.top()
	assert_true(c is ComputerScreen, "the computer is on top: %s" % [c])
	if not c is ComputerScreen:
		main.free()
		return
	assert_eq(c.desk.get("target"), "seat:rw1", "for that desk")
	assert_true(not c.watch, "to use, not to watch")
	assert_true(c.source is SampleSource, "the sample, with live mode off")
	assert_true(main.router.computer_focus and not main.router.world_enabled, "the router is in computer mode")
	var chair: Vector2 = run["desk"]["anchors"][0]["pos"]
	assert_true(Vector2(rig.position.x, rig.position.z).distance_to(chair / 100.0) < 0.01, "the camera looks at the chair: %s" % rig.position)
	assert_true(rig.distance < 5.0, "from close behind it: %s" % rig.distance)

	await settle()
	assert_eq(c.chooser_names(), ["Sample station"], "a hot desk: the chooser, with the sample's one station")
	c.choose(0)
	c.open_app("terminal")
	var typing: Control = c.app.typing_target
	typing.grab_focus()
	var fired := []
	for intent in ["interact", "interact_alt", "map", "menu", "names", "cancel", "toggle_fpv"]:
		main.router.connect(intent, func(): fired.append(intent))
	main.router.steer.connect(func(v): fired.append(["steer", v]))
	sent.clear()
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_E, KEY_SPACE, KEY_TAB, KEY_M, KEY_ESCAPE]:
		tap(code)
		frames(main, 1.0 / 60.0)
	assert_eq(fired, [], "no game intent fired")
	assert_eq(sent, [], "nothing sent to the core")
	assert_eq(main.router.steering, Vector2.ZERO, "no steering")
	assert_eq(main.stack.top(), c, "Esc in the terminal did not leave, nor M open the map")
	assert_eq(focus_owner(), typing, "the terminal kept the keys, Tab too")
	# With the dock focused instead, the keys the dock leaves go nowhere.
	c.dock_button("files").grab_focus()
	for code in [KEY_W, KEY_E, KEY_M, KEY_N]:
		tap(code)
	assert_eq(fired, [], "nor with the dock focused")
	assert_eq(main.stack.top(), c, "still at the computer")

	tap(KEY_F10)
	assert_true(not main.stack.screens.has(c), "F10 left")
	assert_eq(sent.map(func(s): return s["type"]), ["StopUsing"], "leaving stands the player up")
	assert_true(not main.router.computer_focus and main.router.world_enabled, "the world has the keys again")
	assert_true(Vector2(rig.position.x, rig.position.z).distance_to(chair / 100.0) > 1.0, "the camera went back")
	assert_eq([rig.position, rig.yaw, rig.pitch, rig.distance], run["pose"], "exactly as it was: position, yaw, pitch and distance")
	tick(main)
	assert_eq(main.player.view.get("using"), null, "up")
	main.free()


## Moved by the core (a Go it walks, which the screen did not send), the
## computer closes, and sends nothing more.
func test_being_moved_by_the_core_pops_the_computer() -> void:
	var run := at_the_computer()
	var main = run["main"]
	var sent: Array = run["sent"]
	assert_true(main.stack.top() is ComputerScreen, "at the computer")
	var world = main.player.world.world
	world.command(JSON.stringify({"type": "Go", "occupant": main.player.id, "to": {"type": "Room", "room": "room:plaza"}}))
	sent.clear()
	for i in 5:
		tick(main)
	assert_true(not main.stack.top() is ComputerScreen, "moved: the computer closed")
	assert_eq(sent, [], "and sent nothing of its own")
	assert_true(main.router.world_enabled, "the world has the keys again")
	main.free()


## Released by the core (a StopUsing the screen did not send), the
## computer closes, sends nothing more, and the camera goes back.
func test_being_released_by_the_core_pops_the_computer() -> void:
	var run := at_the_computer()
	var main = run["main"]
	var sent: Array = run["sent"]
	var rig: OrbitRig = main.host.pack.rig
	assert_true(main.stack.top() is ComputerScreen, "at the computer")
	var world = main.player.world.world
	world.command(JSON.stringify({"type": "StopUsing", "occupant": main.player.id}))
	sent.clear()
	for i in 3:
		tick(main)
	assert_true(not main.stack.top() is ComputerScreen, "released: the computer closed")
	assert_eq(sent, [], "and sent nothing of its own")
	assert_eq(main.player.view.get("using"), null, "the player is up")
	assert_eq([rig.position, rig.yaw, rig.pitch, rig.distance], run["pose"], "the camera is back")
	main.free()


## Passes a world's calls through, refusing every StopUsing as a core
## that will not let the player up would.
class Refuser extends Recorder:
	func command(json: String) -> String:
		var c = JSON.parse_string(json)
		sent.append(c)
		if c["type"] == "StopUsing":
			return JSON.stringify({"error": {"code": "refused", "message": "not now"}})
		return world.command(json)


## A StopUsing that is refused, or that the player would not send, never
## strands the player seated with no computer: one the player's state
## would have held back is sent anyway, and after a refusal, "Use
## computer" is offered again and reopens the computer without sending
## anything.
func test_a_refused_or_held_back_stop_never_strands_the_player() -> void:
	var run := at_the_computer()
	var main = run["main"]
	var sent := []
	main.player.world = Refuser.new(main.player.world.world, sent)
	tap(KEY_F10)
	assert_true(not main._computer_open(), "F10 left")
	assert_eq(sent.map(func(c): return c["type"]), ["StopUsing"], "and asked to stand")
	tick(main)
	var using = main.player.view.get("using")
	assert_true(using is Dictionary and using.get("capability") == "use", "refused: still using: %s" % [using])
	var target: Dictionary = main.interaction.current_target()
	var verbs: Array = main.interact.verbs(target)
	assert_true(verbs.has("Use computer"), "Use computer is offered again: %s" % [verbs])
	sent.clear()
	main.interaction._act(target, verbs.find("Use computer"))
	frames(main, 0.05)
	assert_true(main._computer_open() and not main.computer.watch, "and reopens the computer")
	assert_eq(sent, [], "sending nothing: the core already has the player using it")
	assert_true(not main.interact.verbs(main.interaction.current_target()).has("Use computer"), "once open, not offered again")

	# A state that would hold the StopUsing back (the player not shown as
	# present for a moment) still sends it.
	var recorded := []
	main.player.world = Recorder.new(main.player.world.world, recorded)
	main.player.present = false
	tap(KEY_F10)
	assert_eq(recorded.map(func(c): return c["type"]), ["StopUsing"], "sent even so")
	tick(main)
	assert_eq(main.player.view.get("using"), null, "and the player is up")
	main.free()


func walk_to(main, pos: Vector2) -> void:
	main.player.go_point(pos)
	for i in 80:
		tick(main)
		if not main.player.view.get("moving", false) and not main.player.following:
			break


func until_ticks(main, done: Callable, most: int) -> bool:
	for i in most:
		if done.call():
			return true
		tick(main)
	return done.call()


func last_notice(main) -> String:
	return str(main.hud.notices[-1].get_meta("text")) if not main.hud.notices.is_empty() else ""


## When Kai leaves his desk in the watch test: a Depart the test's own feed
## sends at a tick it names, not the fixture's schedule, so the test does
## not change when the district's story does.
const KAI_LEAVES_AT := 120


## The district's feed with Kai's departure at KAI_LEAVES_AT instead of
## wherever the fixture has it.
static func feed_with_kai_leaving() -> String:
	var lines := CityPaths.district_feed().strip_edges().split("\n")
	var depart := JSON.stringify({"at": KAI_LEAVES_AT, "command": {"type": "Depart", "occupant": "agent:kai"},
		"fixture": true, "record": "entry"})
	var out := PackedStringArray([lines[0]])
	for i in range(1, lines.size()):
		var entry: Dictionary = JSON.parse_string(lines[i])
		if entry["command"]["type"] == "Depart" and entry["command"].get("occupant") == "agent:kai":
			continue
		if depart != "" and int(entry["at"]) > KAI_LEAVES_AT:
			out.append(depart)
			depart = ""
		out.append(lines[i])
	if depart != "":
		out.append(depart)
	return "\n".join(out) + "\n"


## "Look at screen" through play: refused where no agent sits, with the
## notice; behind the desk Kai sits at, the computer opens in watch mode,
## and leaving it sends no StopUsing. Watch mode closes by itself when the
## watcher is moved off the stand anchor, and when the desk's occupant
## leaves, at the tick the test's feed has him depart.
func test_look_at_screen_opens_watch_mode_only_where_allowed_and_closes_by_itself() -> void:
	var main = load("res://main.gd").new()
	main.feed_jsonl = feed_with_kai_leaving()
	main.settings_path = SETTINGS_FILE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_FILE))
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=lowpoly_tropical"]))
	for i in 80:
		main.driver.step_once()
		if main.player.present and not main.player.view.get("moving", false):
			break
	var sent := []
	main.player.world = Recorder.new(main.player.world, sent)
	var empty := thing(main, "seat:w3")
	main._on_watch_requested(main.interact.candidate_of(empty, 3))
	assert_true(not main._computer_open(), "no agent at the desk: refused")
	assert_eq(last_notice(main), "You can't see this screen.", "with the notice")

	assert_true(until_ticks(main, func(): return main.player.taken_anchors().has("seat:w1#0"), 200), "Kai sits at his desk")
	var desk := thing(main, "seat:w1")
	var stand: Vector2 = desk["anchors"][2]["pos"]
	walk_to(main, stand)
	main.player.view["facing"] = 0
	frames(main, 0.05)
	sent.clear()
	main._interact()
	assert_true(main._computer_open() and main.computer.watch, "Look at screen: watch mode")
	assert_eq(main.computer.desk.get("target"), "seat:w1", "at Kai's desk")
	tap(KEY_F10)
	assert_true(not main._computer_open(), "F10 leaves watch mode")
	assert_eq(sent, [], "and sends nothing: no StopUsing")

	# Moved off the stand anchor, by the core: watch mode closes.
	main._interact()
	assert_true(main._computer_open() and main.computer.watch, "watching again")
	var aside := stand + Vector2(0, 200)
	main.player.world.world.command(JSON.stringify({"type": "Go", "occupant": main.player.id,
		"to": {"type": "Point", "pos": {"x": int(aside.x), "z": int(aside.y)}}}))
	var watched_from: Vector2i = main.player.cell
	for i in 10:
		tick(main)
	assert_true(main.player.cell != watched_from, "the core moved the watcher")
	assert_true(not main._computer_open(), "moved away: watch mode closed")

	# Back behind the desk, watching until Kai leaves it.
	if main.player.taken_anchors().has("seat:w1#0"):
		walk_to(main, stand)
		main.player.view["facing"] = 0
		frames(main, 0.05)
		main._interact()
		assert_true(main._computer_open() and main.computer.watch, "watching once more: %s" % main.interaction.choice().get("text"))
		assert_true(main.driver.world.tick() < KAI_LEAVES_AT, "before Kai's departure")
		assert_true(until_ticks(main, func(): return main.driver.world.tick() >= KAI_LEAVES_AT - 1, KAI_LEAVES_AT), "the tick before his")
		assert_true(main._computer_open() and main.player.taken_anchors().has("seat:w1#0"), "still watching him at it")
		assert_true(until_ticks(main, func(): return not main.player.taken_anchors().has("seat:w1#0"), 3), "Kai leaves on his tick")
		frames(main, 0.05)
		assert_true(not main._computer_open(), "the occupant left: watch mode closed")
	else:
		assert_true(false, "Kai left before he could be watched again")
	assert_eq(sent.filter(func(c): return c["type"] == "StopUsing"), [], "watching never stood anyone up")
	main.free()


## In first person the eye turns to face the desk the way its sitter
## faces, and turns back when the computer closes; a pack with no camera
## to move keeps its view.
func test_in_first_person_the_view_faces_the_desk_and_comes_back() -> void:
	var pack := StylePack.new()
	assert_eq(pack.settle_view(Vector2(100, 200), 90), null, "no camera to move: nothing saved")
	pack.fpv = FpvCamera.new()
	pack.fpv.look(30.0, -10.0)
	var saved = pack.settle_view(Vector2(100, 200), 90)
	assert_true(pack.fpv.forward().distance_to(Vector2(1, 0)) < 0.001, "facing east, as the chair does: %s" % pack.fpv.forward())
	assert_eq(pack.fpv.pitch, 0.0, "level")
	pack.restore_view(saved)
	assert_true(is_equal_approx(pack.fpv.yaw, 30.0) and is_equal_approx(pack.fpv.pitch, -10.0), "back as it was")
	pack.fpv.free()
	pack.free()


# ---- Focus and leaving ----

## F10 and a half-second B hold leave even while a screen the computer
## opened (Settings, from "Connect your AgentPod") is on top of it with a
## text field focused, and take that screen away too. A B hold begun on
## the computer does not go on counting once it is covered.
func test_f10_and_the_b_hold_leave_from_a_screen_the_computer_opened() -> void:
	var pair := stage()
	var stack: ScreenStack = pair[0]
	var source := SampleSource.new()
	var settings := fresh_settings()
	for how in ["f10", "b"]:
		var c := computer(stack, HOT_DESK, source, false, settings)
		var left := []
		c.left.connect(func(): left.append(true))
		c.settings_requested.connect(func(page):
			var sc := SettingsScreen.new()
			sc.settings = settings
			sc.start_page = page
			stack.push(sc))
		await settle()
		c.choose(0)
		c.connect_button.pressed.emit()
		assert_true(stack.top() is SettingsScreen, "Settings over the computer")
		var field: LineEdit = stack.top().value_control("hub_url")
		field.grab_focus()
		if how == "f10":
			tap(KEY_F10)
		else:
			runner.root.push_input(pad(JOY_BUTTON_B))
			c._process(0.3)
			c._process(0.25)
			runner.root.push_input(pad(JOY_BUTTON_B, false))
		assert_eq(left.size(), 1, how + ": left")
		assert_true(not stack.screens.has(c), how + ": the computer closed")
		assert_true(not stack.top() is SettingsScreen, how + ": and the Settings it opened")

	# A hold begun on the computer, then covered: it stops counting.
	var c := computer(stack, HOT_DESK, source, false, settings)
	var left := []
	c.left.connect(func(): left.append(true))
	await settle()
	c.choose(0)
	runner.root.push_input(pad(JOY_BUTTON_B))
	c._process(0.3)
	var over := SettingsScreen.new()
	over.settings = settings
	stack.push(over)
	c._process(1.0)
	assert_true(left.is_empty() and stack.screens.has(c), "covered, the old hold does not leave")
	stack.pop()
	c._process(1.0)
	assert_true(left.is_empty() and stack.screens.has(c), "nor once uncovered")
	runner.root.push_input(pad(JOY_BUTTON_B, false))
	unstage(pair)


## The footer takes the addresses set in Settings as soon as the computer
## is uncovered again.
func test_the_footer_refreshes_when_the_computer_is_uncovered() -> void:
	var pair := stage()
	var stack: ScreenStack = pair[0]
	var settings := fresh_settings()
	var live := StubSource.new()
	live.live = true
	live.rows = [station_row("stn_a", EVERY_CAPABILITY)]
	var c := computer(stack, HOT_DESK, live, false, settings)
	await settle()
	c.choose(0)
	assert_true(c.console_button.disabled and c.superpipeline_button.disabled, "no addresses yet")
	var sc := SettingsScreen.new()
	sc.settings = settings
	stack.push(sc)
	settings.set_value("station", "console_url", "https://console.example")
	settings.set_value("station", "superpipeline_url", "https://pipeline.example")
	stack.pop()
	assert_true(not c.console_button.disabled and not c.superpipeline_button.disabled, "set in Settings, they work at once")
	unstage(pair)

## The router's computer mode: nothing it would emit fires, and the world
## stays disabled whatever else asks for it, until the computer lets go.
func test_the_router_emits_nothing_in_computer_mode() -> void:
	var router := InputRouter.new()
	runner.root.add_child(router)
	var fired := []
	for intent in ["interact", "interact_alt", "map", "menu", "names", "cancel", "dev_panel"]:
		router.connect(intent, func(): fired.append(intent))
	router.steer.connect(func(v): fired.append(["steer", v]))
	router.computer_focus = true
	assert_true(not router.world_enabled, "computer mode shuts the world out")
	router.world_enabled = true
	assert_true(not router.world_enabled, "and keeps it out")
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_E, KEY_SPACE, KEY_M, KEY_N, KEY_ESCAPE, KEY_F3]:
		router.handle(key(code))
		router.handle(key(code, false))
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 1.0
	router.handle(stick)
	assert_eq(fired, [], "nothing fired")
	assert_eq(router.looking, Vector2.ZERO, "nothing looked")
	router.computer_focus = false
	router.world_enabled = true
	router.handle(key(KEY_M))
	assert_eq(fired, ["map"], "out of computer mode, keys reach the world again")
	router.free()


## F10, and B held for half a second, always leave, even from the terminal;
## a short B press goes back to the desktop instead. Esc leaves, except
## from the terminal, where it is the terminal's.
func test_f10_and_a_half_second_b_hold_always_leave_and_esc_leaves_but_not_from_the_terminal() -> void:
	var pair := stage()
	var stack: ScreenStack = pair[0]
	var source := SampleSource.new()
	var c := computer(stack, HOT_DESK, source)
	var left := []
	c.left.connect(func(): left.append(true))
	await settle()
	c.choose(0)
	c.open_app("terminal")
	c.app.typing_target.grab_focus()
	tap(KEY_ESCAPE)
	assert_true(stack.screens.has(c) and left.is_empty(), "Esc in the terminal stays")
	# B pressed and let go before half a second: back to the desktop.
	runner.root.push_input(pad(JOY_BUTTON_B))
	c._process(0.3)
	runner.root.push_input(pad(JOY_BUTTON_B, false))
	assert_true(stack.screens.has(c) and left.is_empty(), "a short B stays")
	assert_eq(c.app, null, "and closes the app")
	c.open_app("terminal")
	c.app.typing_target.grab_focus()
	runner.root.push_input(pad(JOY_BUTTON_B))
	c._process(0.3)
	assert_true(stack.screens.has(c), "held 0.3 s: still there")
	c._process(0.25)
	assert_true(not stack.screens.has(c), "held 0.55 s: left")
	assert_eq(left.size(), 1, "left once")
	runner.root.push_input(pad(JOY_BUTTON_B, false))

	c = computer(stack, HOT_DESK, source)
	left.clear()
	c.left.connect(func(): left.append(true))
	await settle()
	c.choose(0)
	c.open_app("chat")
	c.app.typing_target.grab_focus()
	tap(KEY_F10)
	assert_true(not stack.screens.has(c) and left.size() == 1, "F10 leaves from a typing field")

	c = computer(stack, HOT_DESK, source)
	left.clear()
	c.left.connect(func(): left.append(true))
	await settle()
	c.choose(0)
	c.dock_button("files").grab_focus()
	tap(KEY_ESCAPE)
	assert_true(not stack.screens.has(c) and left.size() == 1, "Esc leaves from anywhere else")

	c = computer(stack, HOT_DESK, source)
	left.clear()
	c.left.connect(func(): left.append(true))
	await settle()
	c.stand_up_button.pressed.emit()
	assert_true(not stack.screens.has(c) and left.size() == 1, "Stand up leaves")
	unstage(pair)


# ---- Stations: the chooser, bound desks, the desktop and the dock ----

## A hot desk lists the stations to choose from: with the sample, just
## Sample station; with a live source, the ones it lists.
func test_a_hot_desk_shows_the_station_chooser() -> void:
	var pair := stage()
	var stack: ScreenStack = pair[0]
	var c := computer(stack, HOT_DESK, SampleSource.new())
	assert_eq(c.state, "loading", "asks for the stations first")
	await settle()
	assert_eq(c.state, "chooser", "then offers them")
	assert_eq(c.chooser_names(), ["Sample station"], "the sample's one station")
	assert_eq(focus_owner(), c.chooser_button(0), "focused, for the d-pad")
	stack.pop()
	var live := StubSource.new()
	live.live = true
	live.rows = [station_row("stn_a", EVERY_CAPABILITY, "Build box"), station_row("stn_b", ["logs"], "Docs box")]
	c = computer(stack, HOT_DESK, live)
	await settle()
	assert_eq(c.chooser_names(), ["Build box", "Docs box"], "the live source's stations")
	c.choose(1)
	assert_eq(c.state, "desktop", "choosing one opens it")
	assert_eq(c.station.get("stationId"), "stn_b", "the one chosen")
	unstage(pair)


## A bound desk opens its station when the source can see it, and says
## "You don't have access to this station" when it cannot, or when the
## source refuses; with the sample, every desk opens Sample station.
func test_a_bound_desk_opens_its_station_or_says_there_is_no_access() -> void:
	var pair := stage()
	var stack: ScreenStack = pair[0]
	var bound := {"target": "placement:desk", "kind": "workstation", "binding": {"source": "agentpod", "ref": "stn_mine"}}
	var live := StubSource.new()
	live.live = true
	live.rows = [station_row("stn_other", EVERY_CAPABILITY)]
	var c := computer(stack, bound, live)
	await settle()
	assert_eq(c.state, "message", "no desktop")
	assert_eq(c.message_text(), ComputerScreen.NO_ACCESS, "says so")
	assert_eq(ComputerScreen.NO_ACCESS, "You don't have access to this station", "in those words")
	stack.pop()
	live.rows.append(station_row("stn_mine", EVERY_CAPABILITY, "My box"))
	c = computer(stack, bound, live)
	await settle()
	assert_eq([c.state, c.station.get("stationId")], ["desktop", "stn_mine"], "its own station, when it can see it")
	stack.pop()
	var refused := StubSource.new()
	refused.live = true
	refused.fail_kind = "no_access"
	c = computer(stack, bound, refused)
	await settle()
	assert_eq(c.message_text(), ComputerScreen.NO_ACCESS, "a refusal says the same")
	stack.pop()
	refused.fail_kind = "offline"
	c = computer(stack, bound, refused)
	await settle()
	assert_eq(c.message_text(), "Station offline", "offline says so")
	stack.pop()
	c = computer(stack, bound, SampleSource.new())
	await settle()
	assert_eq([c.state, c.station.get("stationId")], ["desktop", "stn_sample"], "the sample opens Sample station at a bound desk too")
	unstage(pair)


## The desktop: the station's name, purpose, node, a status chip and the
## time; the dock's seven apps; the bezel's badge and name.
func test_the_desktop_shows_the_station_and_the_dock_its_seven_apps() -> void:
	var pair := stage()
	var stack: ScreenStack = pair[0]
	var c := computer(stack, HOT_DESK, SampleSource.new())
	await settle()
	c.choose(0)
	assert_eq(c.desk_name.text, "Sample station", "its name")
	assert_true(c.desk_purpose.text.contains("Sample agent"), "its purpose: %s" % c.desk_purpose.text)
	assert_true(c.desk_node.text.contains("sample-node"), "its node: %s" % c.desk_node.text)
	assert_eq(c.status_chip.text, "Running", "its status")
	assert_true(RegEx.create_from_string("^\\d\\d:\\d\\d$").search(c.clock.text) != null, "the time: %s" % c.clock.text)
	assert_eq(c.dock_names(), ["Terminal", "Chat", "Files", "Logs", "Health", "Changes", "Work"], "the dock")
	assert_eq(c.badge.text, "Sample", "the bezel's badge")
	assert_eq(c.station_label.text, "Sample station", "and the station's name on it")
	assert_true(c.stand_up_button.visible and c.stand_up_button.text == "Stand up", "and Stand up")
	for id in ComputerScreen.APP_IDS:
		assert_true(not c.dock_button(id).disabled, id + " is there for the sample, which has every capability")
		c.open_app(id)
		assert_eq(c.state, "app", id + " opens")
		assert_eq(c.app_title.text, c.dock_button(id).text, id + " is named over its window")
		if c.app.get_script() == StationApp:
			assert_true(c.app.text().contains(c.app.app_name), "a placeholder that names it: %s" % c.app.text())
		c.show_desktop()
	unstage(pair)


## An app whose station capability is missing is greyed out with the
## reason; Work needs none.
func test_missing_capabilities_grey_out_their_apps() -> void:
	var pair := stage()
	var stack: ScreenStack = pair[0]
	var live := StubSource.new()
	live.live = true
	live.rows = [station_row("stn_a", ["health", "logs"])]
	var c := computer(stack, HOT_DESK, live)
	await settle()
	c.choose(0)
	var greyed := []
	for id in ComputerScreen.APP_IDS:
		if c.dock_button(id).disabled:
			greyed.append(id)
			assert_true(c.dock_reason(id) != "", id + " says why")
	assert_eq(greyed, ["terminal", "chat", "files", "changes"], "the apps whose capability is missing")
	assert_true(c.dock_reason("terminal").contains("terminal"), "the reason names it: %s" % c.dock_reason("terminal"))
	c.open_app("terminal")
	assert_eq(c.state, "desktop", "a greyed app does not open")
	unstage(pair)


# ---- The footer: connecting, and the products' own apps ----

## With the sample, the desktop offers "Connect your AgentPod": live mode
## off, it says what live mode is and opens Settings at "Station computer";
## on, on the desktop, it starts signing in; on the web and phones, it says
## sign-in needs the desktop app for now.
func test_connect_your_agentpod_follows_the_live_setting_and_the_platform() -> void:
	var pair := stage()
	var stack: ScreenStack = pair[0]
	var settings := fresh_settings()
	var c := computer(stack, HOT_DESK, SampleSource.new(), false, settings)
	await settle()
	c.choose(0)
	var pages := []
	var sign_ins := []
	c.settings_requested.connect(func(page): pages.append(page))
	c.sign_in_requested.connect(func(): sign_ins.append(true))
	assert_true(c.connect_button.visible, "offered")
	assert_eq(c.connect_button.text, "Connect your AgentPod", "in those words")
	assert_true(not c.console_button.visible and not c.superpipeline_button.visible, "no product links for the sample")
	c.connect_button.pressed.emit()
	assert_eq(pages, ["Station computer"], "live mode off: Settings, at its page")
	assert_true(c.notice.text.contains("your own AgentPod") and c.notice.text.contains("off"), "and what live mode is: %s" % c.notice.text)
	assert_eq(sign_ins, [], "nothing signs in")
	settings.set_value("station", "live", true)
	c.connect_button.pressed.emit()
	assert_eq(sign_ins, [true], "live mode on: signing in starts")
	for platform in ["web", "mobile"]:
		c.platform = platform
		c.connect_button.pressed.emit()
		assert_eq(c.notice.text, "Sign-in needs the desktop app for now.", platform + " says so")
	assert_eq(sign_ins, [true], "and does not sign in")
	unstage(pair)


## Live, the footer opens the AgentPod console and Superpipeline at the
## configured addresses, through the system browser.
func test_live_the_footer_opens_the_console_and_superpipeline() -> void:
	var pair := stage()
	var stack: ScreenStack = pair[0]
	var settings := fresh_settings()
	settings.set_value("station", "console_url", "https://console.example/")
	settings.set_value("station", "superpipeline_url", "https://pipeline.example")
	var live := StubSource.new()
	live.live = true
	live.rows = [station_row("stn_a", EVERY_CAPABILITY)]
	var c := computer(stack, HOT_DESK, live, false, settings)
	var opened := []
	c.open_url = func(url: String) -> void: opened.append(url)
	await settle()
	c.choose(0)
	assert_eq(c.badge.text, "Live", "the Live badge")
	assert_true(not c.connect_button.visible, "no Connect once live")
	assert_eq([c.console_button.text, c.superpipeline_button.text], ["Open in the AgentPod console", "Open in Superpipeline"], "both links")
	c.console_button.pressed.emit()
	c.superpipeline_button.pressed.emit()
	assert_eq(opened, ["https://console.example/nodes/node_1/stations/stn_a", "https://pipeline.example"], "at the configured addresses")
	unstage(pair)


## Live mode is off by default, and with it off nothing makes a network
## object: not the computer, its apps, nor Connect.
func test_the_live_toggle_is_off_by_default_and_off_nothing_touches_the_network() -> void:
	assert_eq(Settings.DEFAULTS["station"], {
		"live": false, "hub_url": "", "superpipeline_url": "", "console_url": "",
		"client_id": "agentnagar",
	}, "the station section")
	var settings := fresh_settings()
	assert_eq(settings.get_value("station", "live"), false, "off")
	var paths := ["res://core/station/computer_screen.gd", "res://core/station/app.gd"]
	for app_file in DirAccess.get_files_at("res://core/station/apps"):
		if app_file.ends_with(".gd"):
			paths.append("res://core/station/apps/" + app_file)
	assert_true(paths.size() >= 7, "the apps are checked too: %s" % [paths])
	for path in paths:
		var text := FileAccess.get_file_as_string(path)
		assert_true(not text.is_empty(), path + " reads")
		for name in ["HTTPClient", "HTTPRequest", "WebSocketPeer", "TCPServer", "StreamPeerTCP", "PacketPeerUDP", "new_network_object"]:
			assert_true(not text.contains(name), "%s never names %s" % [path.get_file(), name])
	var before := StationSource.network_objects_created
	var pair := stage()
	var stack: ScreenStack = pair[0]
	var c := computer(stack, HOT_DESK, SampleSource.new(), false, settings)
	await settle()
	c.choose(0)
	for id in ComputerScreen.APP_IDS:
		c.open_app(id)
		await settle(1)
	c.show_desktop()
	c.connect_button.pressed.emit()
	await settle()
	assert_eq(StationSource.network_objects_created, before, "no network object was made")
	unstage(pair)


## Through main, from boot: with live mode off no live source and no
## credential are made, and nothing makes a network object, not even
## "Connect your AgentPod" or a stray "Sign in again".
func test_live_off_boots_and_opens_the_computer_with_nothing_live() -> void:
	var before := StationSource.network_objects_created
	var run := at_the_computer()
	var main = run["main"]
	var c = main.stack.top()
	assert_true(c is ComputerScreen, "at the computer")
	await settle()
	c.choose(0)
	c.sign_in_requested.emit()
	c.connect_button.pressed.emit()
	await settle()
	assert_true(main.station_source is SampleSource, "the sample")
	assert_eq([main.station_credential, main._live_source], [null, null], "no credential and no live source")
	assert_eq(StationSource.network_objects_created, before, "no network object was made")
	main.free()


## Through main, with live mode on: "Connect your AgentPod" signs in
## against the fake hub (the scripted browser following the redirect), and
## the computer starts over on the live source, listing the hub's
## stations; "Disconnect" revokes the device, deletes the file, and brings
## the sample back. On the web, "Sign in again" only says it needs the
## desktop app.
func test_live_on_signing_in_turns_the_computer_live_and_disconnect_turns_it_back() -> void:
	var hub = FakeHub.new()
	hub.report = runner.fail
	hub.start()
	var run := at_the_computer()
	var main = run["main"]
	main.credential_path = MAIN_CREDENTIAL_FILE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAIN_CREDENTIAL_FILE))
	main.open_browser = func(url: String) -> void: follow(url)
	main.settings.set_value("station", "live", true)
	main.settings.set_value("station", "hub_url", hub.hub_url)
	main.settings.set_value("station", "superpipeline_url", hub.superpipeline_url)
	var c: ComputerScreen = main.stack.top()
	await settle()
	assert_true(c.source is SampleSource, "the sample before signing in")
	c.platform = "web"
	c.sign_in_requested.emit()
	assert_eq(c.notice.text, ComputerScreen.DESKTOP_ONLY_NOTE, "the web waits for the desktop app")
	c.platform = "desktop"
	c.connect_button.pressed.emit()
	assert_eq(c.notice.text, main.SIGNING_IN, "the browser has the sign-in")
	await until(func() -> bool: return c.source is LiveSource and c.state == "chooser", 10.0)
	assert_true(c.source is LiveSource, "live")
	assert_eq(c.chooser_names(), ["Build box", "Quiet box"], "the hub's stations")
	assert_eq(c.badge.text, "Live", "the Live badge")
	assert_true(c.disconnect_button.visible and not c.connect_button.visible, "Disconnect offered")
	assert_true(FileAccess.file_exists(MAIN_CREDENTIAL_FILE), "the credential is stored where main keeps it")
	var device_id: String = main.station_credential.device_id
	c.disconnect_button.pressed.emit()
	assert_true(c.source is SampleSource, "the sample again, at once")
	assert_true(not FileAccess.file_exists(MAIN_CREDENTIAL_FILE), "the credential forgotten at once")
	assert_eq(c.notice.text, main.DISCONNECTING, "the browser has the revoking")
	await until(func() -> bool: return c.notice.text == StationCredential.REVOKED, 10.0)
	assert_eq(c.notice.text, StationCredential.REVOKED, "then says it is revoked")
	assert_true(not c.console_hint_button.visible, "with nothing left to do in the console")
	assert_true(hub.devices[device_id]["revoked"], "the device is revoked")
	assert_eq(hub.violations, [], "the fake saw nothing it does not know")
	main.free()
	hub.stop()


## A Disconnect whose browser never comes back (here, cancelled) says the
## device is not revoked, names it, and offers the AgentPod console.
func test_a_disconnect_not_revoked_offers_the_console() -> void:
	var hub = FakeHub.new()
	hub.report = runner.fail
	hub.start()
	var run := at_the_computer()
	var main = run["main"]
	main.credential_path = MAIN_CREDENTIAL_FILE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAIN_CREDENTIAL_FILE))
	main.open_browser = func(url: String) -> void: follow(url)
	for pair in [["live", true], ["hub_url", hub.hub_url], ["superpipeline_url", hub.superpipeline_url],
			["console_url", "https://console.example"]]:
		main.settings.set_value("station", pair[0], pair[1])
	var c: ComputerScreen = main.stack.top()
	var opened := []
	c.open_url = func(url: String) -> void: opened.append(url)
	c.connect_button.pressed.emit()
	await until(func() -> bool: return c.source is LiveSource and c.state == "chooser", 10.0)
	var device_name: String = main.station_credential.device_name
	main.open_browser = func(_url: String) -> void: pass
	main.station_credential.open_browser = main.open_browser
	c.disconnect_button.pressed.emit()
	assert_true(c.source is SampleSource and not FileAccess.file_exists(MAIN_CREDENTIAL_FILE), "forgotten at once")
	main.station_credential.cancel_browser()
	await until(func() -> bool: return c.console_hint_button.visible, 5.0)
	assert_eq(c.notice.text, StationCredential.not_revoked(device_name), "not revoked, and which device")
	assert_true(c.console_hint_button.visible, "the console offered")
	c.console_hint_button.pressed.emit()
	assert_eq(opened, ["https://console.example"], "at its address")
	main.free()
	hub.stop()


## Settings > Station computer offers Disconnect while live mode is on and
## a device is held; it is disabled while it runs, and then says how it
## went.
func test_settings_offer_disconnect() -> void:
	var hub = FakeHub.new()
	hub.report = runner.fail
	hub.start()
	var run := at_the_computer()
	var main = run["main"]
	main.credential_path = MAIN_CREDENTIAL_FILE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAIN_CREDENTIAL_FILE))
	main.open_browser = func(url: String) -> void: follow(url)
	main._open_settings("Station computer")
	var screen: SettingsScreen = main.stack.top()
	assert_true(not screen.disconnect_button.visible, "live mode off: no Disconnect")
	main.stack.remove(screen)
	for pair in [["live", true], ["hub_url", hub.hub_url], ["superpipeline_url", hub.superpipeline_url]]:
		main.settings.set_value("station", pair[0], pair[1])
	var c: ComputerScreen = main.stack.top()
	c.connect_button.pressed.emit()
	await until(func() -> bool: return c.source is LiveSource, 10.0)
	var device_id: String = main.station_credential.device_id
	main._open_settings("Station computer")
	screen = main.stack.top()
	assert_true(screen.disconnect_button.visible and not screen.disconnect_button.disabled, "Disconnect offered")
	assert_eq(screen.disconnect_button.text, "Disconnect", "in that word")
	assert_true(screen.disconnect_button.get_parent() == screen.pages[5] or screen.pages[5].is_ancestor_of(screen.disconnect_button),
		"on the Station computer page")
	screen.disconnect_button.pressed.emit()
	assert_true(screen.disconnect_button.disabled, "disabled while it runs")
	assert_eq(screen.disconnect_note.text, main.DISCONNECTING, "the browser has it")
	screen.disconnect_button.pressed.emit()
	await until(func() -> bool: return screen.disconnect_note.text == StationCredential.REVOKED, 10.0)
	assert_eq(screen.disconnect_note.text, StationCredential.REVOKED, "revoked")
	assert_true(hub.devices[device_id]["revoked"], "on the hub")
	assert_eq(hub.requests_to("DELETE /api/auth/devices/:id").size(), 1, "once, though pressed twice")
	assert_true(screen.disconnect_button.disabled, "nothing left to disconnect")
	main.free()
	hub.stop()


## Settings offer Disconnect whenever a credential file is held, even with
## live mode off, and it revokes at the hub the file names.
func test_settings_offer_disconnect_with_live_mode_off() -> void:
	var hub = FakeHub.new()
	hub.report = runner.fail
	hub.start()
	var run := at_the_computer()
	var main = run["main"]
	main.credential_path = MAIN_CREDENTIAL_FILE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAIN_CREDENTIAL_FILE))
	main.open_browser = func(url: String) -> void: follow(url)
	for pair in [["live", true], ["hub_url", hub.hub_url], ["superpipeline_url", hub.superpipeline_url]]:
		main.settings.set_value("station", pair[0], pair[1])
	var c: ComputerScreen = main.stack.top()
	c.connect_button.pressed.emit()
	await until(func() -> bool: return c.source is LiveSource, 10.0)
	var device_id: String = main.station_credential.device_id
	main.settings.set_value("station", "live", false)
	main.settings.set_value("station", "hub_url", "")
	main._open_settings("Station computer")
	var screen: SettingsScreen = main.stack.top()
	assert_true(screen.disconnect_button.visible and not screen.disconnect_button.disabled,
		"live mode off, a credential held: Disconnect offered")
	screen.disconnect_button.pressed.emit()
	assert_true(not FileAccess.file_exists(MAIN_CREDENTIAL_FILE), "forgotten at once")
	await until(func() -> bool: return screen.disconnect_note.text == StationCredential.REVOKED, 10.0)
	assert_eq(screen.disconnect_note.text, StationCredential.REVOKED, "revoked")
	assert_true(hub.devices[device_id]["revoked"], "at the hub the file named")
	main.free()
	hub.stop()


## Replacing the credential (its hub changed) cancels a Disconnect under
## way: it lands on "not revoked", never on a note left saying to finish in
## the browser.
func test_changing_the_hub_cancels_a_disconnect_under_way() -> void:
	var hub = FakeHub.new()
	hub.report = runner.fail
	hub.start()
	var run := at_the_computer()
	var main = run["main"]
	main.credential_path = MAIN_CREDENTIAL_FILE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAIN_CREDENTIAL_FILE))
	main.open_browser = func(url: String) -> void: follow(url)
	for pair in [["live", true], ["hub_url", hub.hub_url], ["superpipeline_url", hub.superpipeline_url]]:
		main.settings.set_value("station", pair[0], pair[1])
	var c: ComputerScreen = main.stack.top()
	c.connect_button.pressed.emit()
	await until(func() -> bool: return c.source is LiveSource, 10.0)
	var device_name: String = main.station_credential.device_name
	main.station_credential.open_browser = func(_url: String) -> void: pass
	main._open_settings("Station computer")
	var screen: SettingsScreen = main.stack.top()
	screen.disconnect_button.pressed.emit()
	assert_eq(screen.disconnect_note.text, main.DISCONNECTING, "under way")
	main.settings.set_value("station", "hub_url", "http://127.0.0.1:1")
	await until(func() -> bool: return screen.disconnect_note.text != main.DISCONNECTING, 5.0)
	assert_eq(screen.disconnect_note.text, StationCredential.not_revoked(device_name), "cancelled: not revoked")
	assert_true(screen.console_hint_button.visible, "the console offered")
	main.free()
	hub.stop()


const FakeHub := preload("res://tests/fake_hub/fake_hub.gd")
const MAIN_CREDENTIAL_FILE := "user://test_computer_screen_credential.json"


func until(done: Callable, most_s: float) -> bool:
	var began := Time.get_ticks_msec()
	while not done.call():
		if Time.get_ticks_msec() - began > int(most_s * 1000.0):
			return false
		await runner.process_frame
	return true


## A scripted browser: the hub's authorize page, then its redirect.
func follow(url: String) -> void:
	var location: String = (await fetch(url))["headers"].get("location", "")
	if location != "":
		await fetch(location)


func fetch(url: String) -> Dictionary:
	var request := StationHttp.start(HTTPClient.METHOD_GET, url, PackedStringArray())
	var done := {}
	request.finished.connect(func(status: int, headers: Dictionary, _body: PackedByteArray) -> void:
		done.merge({"status": status, "headers": headers}))
	request.network_failed.connect(func() -> void: done.merge({"status": 0, "headers": {}}))
	while done.is_empty():
		await runner.process_frame
	return done


# ---- Watch mode ----

## Watch mode: input is off, the bezel says "Watching", and with the sample
## it opens Sample station read-only, straight away.
func test_watch_mode_has_input_off() -> void:
	var pair := stage()
	var stack: ScreenStack = pair[0]
	var c := computer(stack, HOT_DESK, SampleSource.new(), true)
	await settle()
	assert_eq([c.state, c.station.get("stationId")], ["desktop", "stn_sample"], "Sample station, without the chooser")
	assert_true(c.watching_label.visible and c.watching_label.text == "Watching", "the bezel says Watching")
	assert_eq(c.badge.text, "Sample", "and Sample")
	assert_true(not c.input_enabled(), "input is off")
	assert_eq(c.stand_up_button.text, "Stop watching", "leaving is not standing up")
	c.open_app("terminal")
	assert_true(c.app.read_only, "the app is read-only")
	assert_eq(c.app.typing_target.focus_mode, Control.FOCUS_NONE, "and takes no typing")
	assert_true(not c.typing_note.visible, "so asks for no keyboard")
	unstage(pair)


## Where "Look at screen" may open: in sample mode, only at a desk where an
## agent sits; live, only at a bound desk (the computer then checks that the
## source can see its station).
func test_watch_mode_is_allowed_where_an_agent_sits_or_at_a_bound_desk() -> void:
	# As the core projects them: a seated occupant shows `using` its seat
	# (a sit); one still walking to a seat it has taken shows the seat and
	# no `using`.
	var projection := {"rooms": [{"id": "room:workshop", "occupants": [
		{"id": "agent:kai", "kind": {"type": "GuildAgent"}, "seat": "seat:w1",
			"using": {"target": "seat:w1", "capability": "sit", "anchor": 0}},
		{"id": "player:1", "kind": {"type": "Player"}, "seat": "seat:w2",
			"using": {"target": "seat:w2", "capability": "sit", "anchor": 0}},
		{"id": "agent:ivy", "kind": {"type": "GuildAgent"}, "using": {"target": "placement:desk", "capability": "use", "anchor": 1}},
		{"id": "agent:rowan", "kind": {"type": "GuildAgent"}, "seat": "seat:w4", "moving": true, "using": null},
	]}]}
	assert_true(InteractionController.agent_sits_at(projection, "seat:w1"), "an agent at w1")
	assert_true(not InteractionController.agent_sits_at(projection, "seat:w2"), "a player at w2")
	assert_true(not InteractionController.agent_sits_at(projection, "seat:w3"), "nobody at w3")
	assert_true(not InteractionController.agent_sits_at(projection, "seat:w4"), "an agent still walking to w4 does not sit there yet")
	assert_true(InteractionController.agent_sits_at(projection, "placement:desk"), "an agent using a placed desk")
	var sample := SampleSource.new()
	var live := StubSource.new()
	live.live = true
	var bound := {"target": "placement:desk", "binding": {"source": "agentpod", "ref": "stn_a"}}
	var hot := {"target": "seat:w1", "binding": {}}
	assert_true(ComputerScreen.may_watch(hot, sample, true), "sample: where an agent sits")
	assert_true(not ComputerScreen.may_watch(hot, sample, false), "sample: not where a player sits")
	assert_true(ComputerScreen.may_watch(bound, live, false), "live: at a bound desk")
	assert_true(not ComputerScreen.may_watch(hot, live, true), "live: not at a hot desk")


# ---- Controller and touch ----

## Every button is focusable, and the d-pad walks the dock. With only a
## controller, the terminal and the chat say typing needs a keyboard; on a
## touch screen, focusing a typing field brings up the system keyboard.
func test_controller_and_touch() -> void:
	var pair := stage()
	var stack: ScreenStack = pair[0]
	var c := computer(stack, HOT_DESK, SampleSource.new())
	await settle()
	c.choose(0)
	var buttons := c.find_children("*", "Button", true, false)
	assert_true(buttons.size() >= 10, "the dock, the bezel and the footer: %d" % buttons.size())
	for b in buttons:
		assert_true(b.focus_mode == Control.FOCUS_ALL, "%s is focusable" % b.name)
	await settle()
	c.dock_button("terminal").grab_focus()
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	runner.root.push_input(right)
	assert_eq(focus_owner(), c.dock_button("chat"), "right along the dock")

	c.glyphs.note(pad(JOY_BUTTON_A))
	for id in ["terminal", "chat", "files"]:
		c.open_app(id)
		assert_eq(c.typing_note.visible, id != "files", id + ": the keyboard note only where there is typing")
		if c.typing_note.visible:
			assert_eq(c.typing_note.text, "Typing needs a keyboard", "in those words")
	c.glyphs.note(key(KEY_A))
	assert_true(not c.typing_note.visible, "gone once a key is pressed")

	var shown := []
	c.touch = true
	c.show_keyboard = func() -> void: shown.append(true)
	c.open_app("terminal")
	c.app.typing_target.grab_focus()
	assert_eq(shown, [true], "the system keyboard, on touch")
	c.dock_button("files").grab_focus()
	assert_eq(shown, [true], "not for a button")
	unstage(pair)


# ---- The bezel ----

## The bezel comes from the style's `ui.bezel` block; a style without one
## gets the plain frame.
func test_the_bezel_reads_the_style_block_and_defaults_to_plain() -> void:
	var plain := UiTheme.from_style({}).bezel()
	assert_eq(plain["shape"], "plain", "the default is plain")
	for key_ in ["colour", "radius", "margin"]:
		assert_true(plain.has(key_), "with a " + key_)
	for style in ["pixel_art", "neon_noir"]:
		var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://styles/%s/style.json" % style))
		if not json.get("ui", {}).has("bezel"):
			assert_eq(UiTheme.from_style(json).bezel()["shape"], "plain", style + " without a bezel block gets the plain frame")
	var crt := UiTheme.from_style({"ui": {"bezel": {"shape": "crt", "colour": "#203040", "radius": 30, "margin": 40}}})
	assert_eq(crt.bezel(), {"shape": "crt", "colour": "#203040", "radius": 30, "margin": 40}, "the style's own")
	var partial := UiTheme.from_style({"ui": {"bezel": {"shape": "glass"}}})
	assert_eq(partial.bezel()["margin"], plain["margin"], "a partial block keeps the rest of the default")

	var pair := stage()
	var stack: ScreenStack = pair[0]
	stack.ui = crt
	var c := computer(stack, HOT_DESK, SampleSource.new())
	var box := c.bezel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_true(box != null, "a drawn frame")
	assert_eq(c.bezel_shape, "crt", "the shape")
	assert_eq(box.bg_color, Color("#203040"), "the colour")
	assert_eq(box.corner_radius_top_left, 30, "the radius")
	assert_eq(box.content_margin_left, 40.0, "the margin")
	stack.set_theme(UiTheme.from_style({}))
	box = c.bezel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(c.bezel_shape, "plain", "reskinned plain")
	assert_eq(box.bg_color, Color(plain["colour"]), "in the plain colour")
	unstage(pair)


# ---- Settings ----

## The `station` section survives a round trip through the file: a fresh
## Settings loading it reads back what was saved.
func test_the_station_settings_round_trip_through_the_file() -> void:
	var saved := fresh_settings()
	var values := {"live": true, "hub_url": "https://hub.example", "superpipeline_url": "https://pipeline.example",
		"console_url": "https://console.example", "client_id": "agentnagar-dev"}
	for key_ in values:
		saved.set_value("station", key_, values[key_])
	var loaded := Settings.new()
	loaded.path = saved.path
	loaded.load_file()
	for key_ in values:
		assert_eq(loaded.get_value("station", key_), values[key_], key_ + " read back")
	var text := FileAccess.get_file_as_string(saved.path)
	assert_true(text.contains("[station]"), "in its own section of the file")


## The `station` settings appear under "Station computer", the live toggle
## labelled for what it does, and the addresses as text; the page can be
## opened directly.
func test_the_station_settings_have_their_own_page() -> void:
	var sc := SettingsScreen.new()
	sc.settings = fresh_settings()
	sc.start_page = "Station computer"
	sc.ui = UiTheme.from_style({})
	runner.root.add_child(sc)
	sc.build()
	assert_eq(sc.page_names()[-1], "Station computer", "its page")
	assert_eq(sc.tabs.current_tab, sc.page_names().size() - 1, "opened at it")
	var live_row := sc.find_child("live", true, false)
	assert_true(live_row != null and live_row.is_visible_in_tree(), "the live row shows")
	assert_eq((live_row.get_node("Label") as Label).text, "Live mode (connects to your AgentPod)", "labelled")
	assert_true(sc.value_control("live") is CheckButton and not sc.value_control("live").button_pressed, "a switch, off")
	for key_ in ["hub_url", "superpipeline_url", "console_url", "client_id"]:
		assert_true(sc.value_control(key_) is LineEdit, key_ + " is text")
	assert_eq(sc.value_control("client_id").text, "agentnagar", "the client's ID")
	var hub: LineEdit = sc.value_control("hub_url")
	hub.text = "https://hub.example"
	hub.text_submitted.emit(hub.text)
	assert_eq(sc.settings.get_value("station", "hub_url"), "https://hub.example", "saved")
	sc.set_row("live", true)
	assert_eq(sc.settings.get_value("station", "live"), true, "the switch saves")
	sc.free()


## Ruling (final review): the hub and Superpipeline addresses must be
## `https://`, except on this computer (127.0.0.1, [::1] or localhost),
## so the device secret never crosses a network in cleartext. Settings
## refuses any other address with a one-line reason, keeping the one it
## had; an allowed one clears the reason. The console's address carries no
## secret, and is not checked.
func test_the_station_addresses_must_be_https_or_this_computer() -> void:
	var sc := SettingsScreen.new()
	sc.settings = fresh_settings()
	sc.start_page = "Station computer"
	sc.ui = UiTheme.from_style({})
	runner.root.add_child(sc)
	sc.build()
	for key_ in ["hub_url", "superpipeline_url"]:
		var field: LineEdit = sc.value_control(key_)
		for allowed in ["https://hub.example", "http://127.0.0.1:8080", "http://localhost:3000", "http://[::1]:9000", ""]:
			field.text = allowed
			field.text_submitted.emit(allowed)
			assert_eq(sc.settings.get_value("station", key_), allowed, "%s: %s saved" % [key_, allowed])
			assert_true(not sc.address_note.visible, "%s: %s, no reason shown" % [key_, allowed])
		sc.set_row(key_, "https://kept.example")
		field.text = "http://example.test"
		field.text_submitted.emit(field.text)
		assert_eq(sc.settings.get_value("station", key_), "https://kept.example", key_ + ": plain http refused, the old kept")
		assert_true(sc.address_note.is_visible_in_tree(), key_ + ": the reason shows")
		assert_eq(sc.address_note.text, SettingsScreen.NOT_HTTPS, key_ + ": in one line")
		assert_eq(sc.address_note.text.count("\n"), 0, "one line")
		field.text = "https://hub.example"
		field.text_submitted.emit(field.text)
		assert_true(not sc.address_note.visible, key_ + ": an allowed address clears it")
	sc.set_row("console_url", "http://console.example")
	assert_eq(sc.settings.get_value("station", "console_url"), "http://console.example", "the console's is not checked")
	sc.free()


# ---- Fitting the window ----

## The shown controls of `node` that lie outside `bounds`, as names.
func outside(node: Node, bounds: Rect2) -> Array:
	var out := []
	for child in node.get_children():
		if child is CanvasItem and not child.visible:
			continue
		if child is Control:
			var r: Rect2 = child.get_global_rect()
			if r.size.x > 0 and r.size.y > 0 and not bounds.grow(1.0).encloses(r):
				out.append("%s %s" % [child.name, r])
		if not (child is ScrollContainer):
			out.append_array(outside(child, bounds))
	return out


## The desktop and an open app fit the window in every style, at 1280 x
## 720 and in the narrow layout at 800 x 900, where the dock wraps.
func test_the_computer_fits_the_window_in_every_style() -> void:
	for size in [Vector2i(1280, 720), Vector2i(800, 900)]:
		for style in ["anime_cel", "solarpunk", "neon_noir", "pixel_art", "lowpoly_tropical", "voxel"]:
			var viewport := SubViewport.new()
			viewport.size = size
			runner.root.add_child(viewport)
			var stack := ScreenStack.new()
			stack.ui = UiTheme.from_style(JSON.parse_string(FileAccess.get_file_as_string("res://styles/%s/style.json" % style)))
			viewport.add_child(stack)
			var c := computer(stack, HOT_DESK, SampleSource.new())
			await settle()
			c.choose(0)
			await settle()
			var bounds := Rect2(Vector2.ZERO, Vector2(size))
			assert_eq(outside(c, bounds), [], "%s desktop at %s: every control on screen" % [style, size])
			for id in ["health", "terminal", "logs", "files", "changes", "chat", "work"]:
				c.open_app(id)
				await settle()
				assert_eq(outside(c, bounds), [], "%s %s at %s: every control on screen" % [style, id, size])
			viewport.free()


## An open app fills the bezel: at 1280 x 720 the desktop's header turns
## compact and the dock a slim strip, so the real Terminal draws its 80 x 24
## at a face of at least 14 px, in every style (pixel art's wide one too).
func test_an_open_app_fills_the_bezel_and_the_terminal_reads_at_14_px() -> void:
	for style in ["lowpoly_tropical", "pixel_art", "anime_cel", "solarpunk", "neon_noir", "voxel"]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280, 720)
		runner.root.add_child(viewport)
		var stack := ScreenStack.new()
		stack.ui = UiTheme.from_style(JSON.parse_string(FileAccess.get_file_as_string("res://styles/%s/style.json" % style)))
		viewport.add_child(stack)
		var c := computer(stack, HOT_DESK, SampleSource.new())
		await settle()
		c.choose(0)
		await settle()
		var dock_on_desktop: float = c.dock_button("terminal").size.y
		c.open_app("terminal")
		await settle()
		var terminal := c.app as TerminalApp
		assert_true(terminal != null, style + ": the real Terminal")
		if terminal == null:
			viewport.free()
			continue
		assert_true(terminal.font_size >= 14, "%s: a face of at least 14 px, not %d" % [style, terminal.font_size])
		assert_true(terminal.columns >= 80 and terminal.rows >= 24, "%s: at least 80 x 24: %d x %d" % [style, terminal.columns, terminal.rows])
		assert_true(terminal.cell_size.y * terminal.rows <= terminal.view.size.y + 0.5, "%s: every row shows" % style)
		assert_true(c.dock_button("terminal").size.y < dock_on_desktop, "%s: the dock slims to a strip (%s < %s)" % [style, c.dock_button("terminal").size.y, dock_on_desktop])
		assert_true(not c.desktop.visible, "%s: the desktop gives way to the app" % style)
		assert_true(c.app_window.size.y >= 0.6 * 720.0, "%s: the app has most of the height: %s" % [style, c.app_window.size.y])
		viewport.free()


## A credential replaced (the hub's address changed) is freed, its secret
## with it: main's connections to its signals name it by ID rather than
## holding it (a credential bound into its own connections kept itself
## alive), and the live source made for it goes with it.
func test_a_replaced_credential_is_freed() -> void:
	var hub = FakeHub.new()
	hub.report = runner.fail
	hub.start()
	var main = load("res://main.gd").new()
	main.settings_path = SETTINGS_FILE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_FILE))
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=lowpoly_tropical"]))
	main.credential_path = MAIN_CREDENTIAL_FILE
	var id: String = hub.serial("dev_")
	hub.devices[id] = {"secret": hub.serial("sec_"), "name": "Agentnagar on test-box", "revoked": false}
	var file := FileAccess.open(MAIN_CREDENTIAL_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"hub": hub.hub_url, "device_id": id, "secret": hub.devices[id]["secret"]}))
	file.close()
	main.settings.set_value("station", "live", true)
	main.settings.set_value("station", "hub_url", hub.hub_url)
	main.settings.set_value("station", "superpipeline_url", hub.superpipeline_url)
	assert_true(main._station_source() is LiveSource, "signed in: live")
	var credential_ref: WeakRef = weakref(main.station_credential)
	var source_ref: WeakRef = weakref(main._live_source)
	await until(func() -> bool: return not hub.requests_to("GET /api/fleet/agents").is_empty(), 5.0)
	await settle(5)
	var old_id: int = main.station_credential.get_instance_id()
	main.settings.set_value("station", "hub_url", "http://127.0.0.1:9")
	assert_true(main.station_credential.get_instance_id() != old_id, "a new credential for the new hub")
	await settle(3)
	assert_true(source_ref.get_ref() == null, "the old hub's live source is freed")
	assert_true(credential_ref.get_ref() == null, "the replaced credential is freed, its secret with it")
	main.free()
	hub.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAIN_CREDENTIAL_FILE))
