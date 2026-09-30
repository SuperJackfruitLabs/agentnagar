## The station computer's apps (Part B's Task 6): Terminal, Logs, Files,
## Health and Changes, each the city-styled counterpart of an AgentPod
## console tab. Each is tested against Sample station and against a stub
## source whose every answer the test scripts (station_stubs.gd), so each
## failure kind can be shown. Chat and Work have their own files.
extends "res://tests/station_stubs.gd"


# ---- The computer makes the apps ----

## The dock opens each app as its own class.
func test_the_computer_makes_each_app_as_its_own_class() -> void:
	var expected := {
		"terminal": TerminalApp, "chat": ChatApp, "logs": LogsApp, "files": FilesApp, "health": HealthApp,
		"changes": ChangesApp, "work": WorkApp,
	}
	for id in expected:
		var app := ComputerScreen.make_app(id)
		assert_true(is_instance_of(app, expected[id]), "%s is its own app" % id)
		app.free()
	for id in ["terminal", "chat"]:
		var app := ComputerScreen.make_app(id)
		assert_true(app.takes_typing, "%s takes typing" % id)
		app.free()


## The computer hands its settings to the app it opens, and passes an
## app's "Sign in again" on as its own.
func test_the_computer_passes_settings_in_and_sign_in_out() -> void:
	var stack := ScreenStack.new()
	stack.router = InputRouter.new()
	runner.root.add_child(stack.router)
	stack.ui = UiTheme.from_style({})
	runner.root.add_child(stack)
	var source := StubSource.new()
	var c := ComputerScreen.new()
	c.settings = fresh_settings()
	c.glyphs = InputGlyphs.new()
	c.platform = "desktop"
	c.touch = false
	stack.push(c)
	c.open({"target": "seat:w2", "kind": "workstation", "binding": {}}, source)
	source.reply("list_stations", {"stats": {}, "agents": [station_row()]})
	c.choose(0)
	c.open_app("health")
	assert_eq(c.app.settings, c.settings, "the app has the settings")
	var asked := []
	c.sign_in_requested.connect(func(): asked.append(true))
	source.refuse("health", "signed_out")
	assert_eq(c.app.error_text(), StationApp.SIGNED_OUT, "the app says the sign-in has ended")
	c.app.press_error_button()
	assert_eq(asked, [true], "and Sign in again reaches the computer")
	var router := stack.router
	stack.free()
	router.free()


# ---- Terminal ----

## The key table, in both cursor modes: printable text, Enter, Backspace,
## Tab and Shift-Tab, Esc, the arrows, Home and End, PgUp and PgDn, Delete,
## F1 to F12, Ctrl-letter, and Alt as an Esc prefix.
func test_the_terminal_encodes_keys_in_both_cursor_modes() -> void:
	var both := [
		[key(KEY_A, 0x61), "a"],
		[key(KEY_A, 0x41, false, false, true), "A"],
		[key(KEY_2, 0x40, false, false, true), "@"],
		[key(KEY_SPACE, 0x20), " "],
		[key(KEY_ENTER), "\r"],
		[key(KEY_KP_ENTER), "\r"],
		[key(KEY_BACKSPACE), "\u007f"],
		[key(KEY_TAB), "\t"],
		[key(KEY_TAB, 0, false, false, true), ESC + "[Z"],
		[key(KEY_ESCAPE), ESC],
		[key(KEY_PAGEUP), ESC + "[5~"],
		[key(KEY_PAGEDOWN), ESC + "[6~"],
		[key(KEY_DELETE), ESC + "[3~"],
		[key(KEY_INSERT), ESC + "[2~"],
		[key(KEY_F1), ESC + "OP"],
		[key(KEY_F2), ESC + "OQ"],
		[key(KEY_F3), ESC + "OR"],
		[key(KEY_F4), ESC + "OS"],
		[key(KEY_F5), ESC + "[15~"],
		[key(KEY_F6), ESC + "[17~"],
		[key(KEY_F7), ESC + "[18~"],
		[key(KEY_F8), ESC + "[19~"],
		[key(KEY_F9), ESC + "[20~"],
		[key(KEY_F10), ESC + "[21~"],
		[key(KEY_F11), ESC + "[23~"],
		[key(KEY_F12), ESC + "[24~"],
		[key(KEY_C, 0, true), "\u0003"],
		[key(KEY_D, 0, true), "\u0004"],
		[key(KEY_Z, 0, true), "\u001a"],
		[key(KEY_A, 0, true), "\u0001"],
		[key(KEY_BRACKETLEFT, 0, true), ESC],
		[key(KEY_X, 0x78, false, true), ESC + "x"],
		[key(KEY_B, 0, true, true), ESC + "\u0002"],
		[key(KEY_BACKSPACE, 0, false, true), ESC + "\u007f"],
		[key(KEY_UP, 0, true), ESC + "[1;5A"],
		[key(KEY_RIGHT, 0, false, false, true), ESC + "[1;2C"],
		[key(KEY_SHIFT), ""],
		[key(KEY_CTRL, 0, true), ""],
	]
	var normal := [
		[key(KEY_UP), ESC + "[A"], [key(KEY_DOWN), ESC + "[B"],
		[key(KEY_RIGHT), ESC + "[C"], [key(KEY_LEFT), ESC + "[D"],
		[key(KEY_HOME), ESC + "[H"], [key(KEY_END), ESC + "[F"],
	]
	var application := [
		[key(KEY_UP), ESC + "OA"], [key(KEY_DOWN), ESC + "OB"],
		[key(KEY_RIGHT), ESC + "OC"], [key(KEY_LEFT), ESC + "OD"],
		[key(KEY_HOME), ESC + "OH"], [key(KEY_END), ESC + "OF"],
	]
	for mode in [false, true]:
		for pair in both + (application if mode else normal):
			var event: InputEventKey = pair[0]
			assert_eq(TerminalApp.encode_key(event, mode).c_escape(), String(pair[1]).c_escape(),
				"%s (ctrl %s, alt %s, shift %s), application cursor %s" % [
					OS.get_keycode_string(event.keycode), event.ctrl_pressed, event.alt_pressed, event.shift_pressed, mode])


## Ctrl-Space and Ctrl-@ send NUL, which a String cannot carry, so it goes
## as a byte.
func test_ctrl_space_and_ctrl_at_send_nul() -> void:
	var source := StubSource.new()
	var app: TerminalApp = open("terminal", source, station_row())
	var shell: StubTerminal = source.terminals[0]
	shell.open()
	assert_true(TerminalApp.is_nul_key(key(KEY_SPACE, 0, true)), "Ctrl-Space")
	assert_true(TerminalApp.is_nul_key(key(KEY_2, 0, true, false, true)), "Ctrl-@ (Ctrl-Shift-2)")
	assert_true(TerminalApp.is_nul_key(key(KEY_AT, 0, true)), "Ctrl-@ where @ is its own key")
	assert_true(not TerminalApp.is_nul_key(key(KEY_SPACE, 0x20)), "not a plain space")
	app.view.gui_input.emit(key(KEY_SPACE, 0, true))
	app.view.gui_input.emit(key(KEY_2, 0, true, false, true))
	assert_eq(shell.bytes_sent, PackedByteArray([0, 0]), "two NULs")
	assert_eq(shell.inputs, [], "and nothing as text")
	close(app)


## The grid's mode decides the arrows: keys through the view reach the
## shell in normal mode, then in application mode once the shell asks.
func test_the_terminal_sends_keys_in_the_mode_the_grid_is_in() -> void:
	var source := StubSource.new()
	var app: TerminalApp = open("terminal", source, station_row())
	var shell: StubTerminal = source.terminals[0]
	shell.open()
	app.view.gui_input.emit(key(KEY_L, 0x6c))
	app.view.gui_input.emit(key(KEY_UP))
	shell.data.emit((ESC + "[?1h").to_utf8_buffer())
	app.refresh()
	app.view.gui_input.emit(key(KEY_UP))
	app.view.gui_input.emit(key(KEY_ENTER))
	assert_eq(shell.sent().c_escape(), ("l" + ESC + "[A" + ESC + "OA\r").c_escape(), "normal, then application mode")
	close(app)


## Ctrl-Shift-V and the middle button paste, wrapped in bracketed paste
## when the grid asks for it; newlines go as Enter does.
func test_the_terminal_pastes_bracketed_when_the_grid_asks() -> void:
	var source := StubSource.new()
	var app: TerminalApp = open("terminal", source, station_row())
	var shell: StubTerminal = source.terminals[0]
	shell.open()
	var asked := []
	app.read_clipboard = func(primary: bool) -> String:
		asked.append(primary)
		return "echo one\necho two"
	app.view.gui_input.emit(key(KEY_V, 0, true, false, true))
	assert_eq(shell.sent().c_escape(), "echo one\recho two".c_escape(), "a plain paste")
	shell.inputs.clear()
	shell.data.emit((ESC + "[?2004h").to_utf8_buffer())
	app.refresh()
	app.view.gui_input.emit(click(MOUSE_BUTTON_MIDDLE))
	assert_eq(shell.sent().c_escape(), (ESC + "[200~echo one\recho two" + ESC + "[201~").c_escape(), "bracketed")
	assert_eq(asked, [false, true], "Ctrl-Shift-V reads the clipboard, the middle button the selection")
	for crafted in ["rm -rf /" + ESC + "[201~oops", "ls" + ESC + "[20" + ESC + "[201~" + "1~rm -rf ~\r"]:
		shell.inputs.clear()
		app.paste(crafted)
		var sent := shell.sent()
		assert_eq(sent.count(ESC + "[201~"), 1, "exactly one end marker: %s" % sent.c_escape())
		assert_true(sent.ends_with(ESC + "[201~"), "the closing one: %s" % sent.c_escape())
		assert_eq(sent.trim_prefix(ESC + "[200~").trim_suffix(ESC + "[201~").count(ESC), 0,
			"every Esc inside is taken out, so none can be rebuilt: %s" % sent.c_escape())
	close(app)


## The hub opens at 80×24 and expects a resize at once: the terminal sends
## one when the stream opens, and again on every size change. It is never
## smaller than 80×24, shrinking its face instead, and fills the app area.
func test_the_terminal_resizes_on_open_and_on_every_size_change() -> void:
	var source := StubSource.new()
	var app: TerminalApp = open("terminal", source, station_row())
	var shell: StubTerminal = source.terminals[0]
	await settle(1)
	assert_eq(shell.resizes, [], "nothing before the stream opens")
	shell.open()
	assert_eq(shell.resizes.size(), 1, "one resize when it opens")
	var first: Vector2i = shell.resizes[0]
	assert_true(first.x >= 80 and first.y >= 24, "at least 80×24: %s" % first)
	assert_eq(app.grid.size(), first, "the grid is the size sent")
	var used := Vector2(first) * app.cell_size
	assert_true(used.x <= app.view.size.x + 0.5 and used.y <= app.view.size.y + 0.5, "it fits the view: %s in %s" % [used, app.view.size])
	assert_true(app.view.size.x - used.x < app.cell_size.x + 0.5, "and fills its width")

	app.size = Vector2(1600, 900)
	await settle(1)
	assert_eq(shell.resizes.size(), 2, "a bigger window sends another")
	var bigger: Vector2i = shell.resizes[1]
	assert_true(bigger.x > first.x and bigger.y > first.y, "bigger: %s after %s" % [bigger, first])
	assert_eq(app.grid.size(), bigger, "and the grid follows")

	app.size = Vector2(400, 200)
	await settle(1)
	var small: Vector2i = shell.resizes.back()
	assert_true(small.x >= 80 and small.y >= 24 and small.x < first.x, "a small window still gets 80×24 or more: %s" % small)
	var fitted := Vector2(small) * app.cell_size
	assert_true(fitted.x <= app.view.size.x + 0.5 and fitted.y <= app.view.size.y + 0.5, "in a smaller face: %s in %s" % [fitted, app.view.size])
	var count := shell.resizes.size()
	# A width that still holds the same whole cells.
	app.size = Vector2(ceilf(small.x * app.cell_size.x) + 1.0, 200)
	await settle(1)
	assert_eq(shell.resizes.size(), count, "no resize when the cells do not change: %s, cell %s, view %s" % [shell.resizes, app.cell_size, app.view.size])
	close(app)


## A stream that is already open when the terminal takes it is sized at
## once too; a view with no height yet is not fitted.
func test_the_terminal_sizes_a_stream_already_open() -> void:
	var source := OpenTerminalSource.new()
	var app: TerminalApp = open("terminal", source, station_row())
	var shell: StubTerminal = source.terminals[0]
	assert_eq(shell.resizes.size(), 1, "sized on opening: %s" % [shell.resizes])
	app.size = Vector2(1200, 0)
	await settle(1)
	app.fit()
	assert_eq(app.grid.size(), shell.resizes.back(), "a zero-height view keeps the size it had")
	close(app)


## Only the rows that changed are redrawn, each row one drawing (never a
## label per cell); inverse is applied, and default colours are the skin's.
func test_the_terminal_redraws_only_changed_rows() -> void:
	var source := StubSource.new()
	var app: TerminalApp = open("terminal", source, station_row())
	var shell: StubTerminal = source.terminals[0]
	shell.open()
	await settle(1)
	app.refresh()
	shell.data.emit("hello\r\n".to_utf8_buffer())
	var before := app.rows_redrawn
	app.refresh()
	assert_eq(app.rows_redrawn - before, 1, "one row changed, one redrawn")
	assert_true(app.row_text(0).begins_with("hello"), "and it reads: %s" % app.row_text(0))
	before = app.rows_redrawn
	app.refresh()
	assert_eq(app.rows_redrawn, before, "nothing new, nothing redrawn")
	assert_eq(app.view.find_children("*", "Label", true, false).size(), 0, "no label per cell")
	assert_eq(app.row_views.size(), app.grid.size().y, "one drawing a row")

	var ink := app.ui.colour("ink")
	var paper := app.ui.colour("panel")
	var plain := {"fg": Color(0, 0, 0, 0), "bg": Color(0, 0, 0, 0), "inverse": false}
	assert_eq(TerminalApp.run_colours(plain, ink, paper), [ink, paper], "default colours are the skin's")
	var inverse := {"fg": Color(0, 0, 0, 0), "bg": Color(0, 0, 0, 0), "inverse": true}
	assert_eq(TerminalApp.run_colours(inverse, ink, paper), [paper, ink], "inverse swaps them")
	var red := {"fg": Color8(205, 0, 0), "bg": Color(0, 0, 0, 0), "inverse": true}
	assert_eq(TerminalApp.run_colours(red, ink, paper), [paper, Color8(205, 0, 0)], "and a colour it carries")
	var navy := Color("#0E1A2E")
	assert_true(UiTheme.contrast(StationApp.legible(Color8(0, 0, 238), navy), navy) >= 3.0, "ANSI blue is lifted to read on a dark paper")
	assert_eq(StationApp.legible(ink, paper), ink, "a colour that reads is left alone")
	shell.data.emit((ESC + "[7mX" + ESC + "[0m").to_utf8_buffer())
	app.refresh()
	var drawn: Array = app.row_views[1].runs
	assert_eq(drawn[0]["fg"], paper, "the drawn run is inverted: %s" % [drawn[0]])
	assert_eq(drawn[0]["bg"], ink, "on the ink")
	close(app)


## Wide characters (emoji, CJK) take two cells as vt100 says: every run is
## drawn at the grid's own column for it, a run with a character beyond
## ASCII is drawn a glyph a cell, and the cursor lands on the grid's column.
func test_the_terminal_places_wide_characters_on_the_grid() -> void:
	var source := StubSource.new()
	var app: TerminalApp = open("terminal", source, station_row())
	var shell: StubTerminal = source.terminals[0]
	shell.open()
	await settle(1)
	var expected := []
	var colour := 1
	for piece in ["$ ", "🚀", " ok ", "✅", "❌", "⚡", "☕", " ", "漢字", " done", "é"]:
		app.refresh()
		# Where vt100 will put this piece: the cursor's column before it.
		expected.append([piece, app.grid.cursor().x])
		shell.data.emit((ESC + "[3%dm" % colour + piece).to_utf8_buffer())
		colour = colour % 7 + 1
	app.refresh()
	var drawn: TerminalApp.RowView = app.row_views[0]
	var runs: Array = drawn.runs
	for pair in expected:
		var run: Dictionary = {}
		for r in runs:
			if r["col"] == pair[1]:
				run = r
		assert_true(not run.is_empty(), "a run starts at column %d for %s: %s" % [pair[1], pair[0], [runs]])
		if run.is_empty():
			continue
		# A wide or non-ASCII cell is a run of its own, so a run may hold only
		# the piece's first cell.
		var text: String = run["text"]
		assert_true(text.begins_with(pair[0]) or (not text.strip_edges().is_empty() and pair[0].begins_with(text)),
			"column %d holds %s: %s" % [pair[1], pair[0], text])
	for glyph in drawn.layout:
		assert_true(is_equal_approx(fmod(glyph["x"] / app.cell_size.x, 1.0), 0.0) or is_equal_approx(fmod(glyph["x"] / app.cell_size.x, 1.0), 1.0),
			"%s is drawn on a cell's edge: %s" % [glyph["text"], glyph["x"] / app.cell_size.x])
	for run in runs:
		var laid: Array = drawn.layout.filter(func(g): return g["run"] == runs.find(run))
		assert_true(not laid.is_empty() or run["text"].strip_edges().is_empty(), "%s is drawn" % run["text"])
		if not laid.is_empty():
			assert_true(is_equal_approx(laid[0]["x"], run["col"] * app.cell_size.x), "%s starts at its column" % run["text"])
		var beyond_ascii := false
		for i in run["text"].length():
			beyond_ascii = beyond_ascii or run["text"].unicode_at(i) > 0x7E
		if beyond_ascii and not run["text"].strip_edges().is_empty():
			assert_true(laid.size() >= 1 and laid.all(func(g): return g["text"].strip_edges().length() <= 2),
				"%s is drawn a glyph a cell: %s" % [run["text"], laid])
	var last: int = expected.back()[1]
	assert_eq(app.grid.cursor().x, last + 1, "the cursor after é")
	assert_true(is_equal_approx(app.cursor_view.position.x, app.grid.cursor().x * app.cell_size.x), "and drawn there")
	# Read from the script, not an instance: an app made and never freed
	# leaks its node, and its canvas item, at the run's exit.
	var methods: Array = load("res://core/station/apps/terminal_app.gd").get_script_method_list()
	assert_true(not "cells_of" in methods.map(func(m): return m["name"]), "no width table of its own")
	close(app)


## A large burst of output (about 200 KB, in small writes) is taken
## promptly: bytes are gathered and fed once a frame, and only changed rows
## are drawn.
func test_the_terminal_takes_a_large_burst_promptly() -> void:
	var source := StubSource.new()
	var app: TerminalApp = open("terminal", source, station_row())
	var shell: StubTerminal = source.terminals[0]
	shell.open()
	await settle(1)
	var line := ""
	for i in 20:
		line += ESC + "[3%dm%04d" % [i % 8, i] + ESC + "[0m "
	var chunk := (line + "\r\n").to_utf8_buffer()
	var total := 0
	var started := Time.get_ticks_usec()
	var frames := 0
	while total < 200 * 1024:
		shell.data.emit(chunk)
		total += chunk.size()
		# A frame for every 64 writes, as a live stream spreads them.
		if (total / chunk.size()) % 64 == 0:
			app.refresh()
			frames += 1
	app.refresh()
	var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
	var budget_ms := 400.0 * machine_factor()
	print("terminal burst: %d KB in %.1f ms over %d frames (budget %.0f ms)" % [total / 1024, elapsed_ms, frames, budget_ms])
	assert_true(elapsed_ms < budget_ms, "%d KB took %.1f ms (budget %.0f ms)" % [total / 1024, elapsed_ms, budget_ms])
	assert_true(app.row_text(app.grid.size().y - 2).contains("0019"), "the last line is on screen: %s" % app.row_text(app.grid.size().y - 2))
	close(app)


## The wheel scrolls back into history and forward again; the cursor hides
## while scrolled back; typing goes back to the live screen.
func test_the_terminal_scrolls_back_by_wheel() -> void:
	var source := StubSource.new()
	var app: TerminalApp = open("terminal", source, station_row())
	var shell: StubTerminal = source.terminals[0]
	shell.open()
	await settle(1)
	var text := ""
	for i in 200:
		text += "line %d\r\n" % i
	shell.data.emit(text.to_utf8_buffer())
	app.refresh()
	assert_true(app.cursor_view.visible, "the cursor shows on the live screen")
	var live_top := app.row_text(0)
	app.view.gui_input.emit(click(MOUSE_BUTTON_WHEEL_UP))
	assert_eq(app.scrollback, TerminalApp.WHEEL_LINES, "a notch back")
	assert_true(app.row_text(0) != live_top, "showing older lines")
	assert_true(not app.cursor_view.visible, "the cursor hides")
	for i in 200:
		app.view.gui_input.emit(click(MOUSE_BUTTON_WHEEL_UP))
	var deepest := app.scrollback
	assert_true(deepest > 0 and deepest < 200, "no further back than the history: %d" % deepest)
	assert_eq(app.row_text(0).strip_edges(), "line 0", "the first line")
	app.view.gui_input.emit(click(MOUSE_BUTTON_WHEEL_DOWN))
	assert_eq(app.scrollback, deepest - TerminalApp.WHEEL_LINES, "a notch forward from there, not from past it")
	app.view.gui_input.emit(key(KEY_A, 0x61))
	assert_eq(app.scrollback, 0, "typing goes back to the live screen")
	assert_eq(app.row_text(0), live_top, "as it was")
	assert_eq(shell.sent(), "a", "and is sent")
	close(app)


## "Session ended · Reconnect" when the shell exits; Reconnect opens a new
## terminal, on a fresh grid, and sizes it at once.
func test_the_terminal_says_the_session_ended_and_reconnects() -> void:
	var source := StubSource.new()
	var app: TerminalApp = open("terminal", source, station_row())
	var shell: StubTerminal = source.terminals[0]
	shell.open()
	shell.data.emit("bye\r\n".to_utf8_buffer())
	shell.exited.emit()
	shell.close()
	assert_eq(app.error_text(), TerminalApp.SESSION_ENDED, "the session ended")
	assert_eq(app.error_button.text, TerminalApp.RECONNECT, "with Reconnect")
	assert_true(app.text().contains("Session ended") and app.text().contains("Reconnect"), app.text())
	app.press_error_button()
	assert_eq(source.terminals.size(), 2, "a new terminal")
	var again: StubTerminal = source.terminals[1]
	again.open()
	assert_eq(again.resizes.size(), 1, "sized at once")
	app.refresh()
	assert_true(not app.row_text(0).contains("bye"), "on a fresh grid")
	assert_eq(app.error_text(), "", "the line is gone")
	close(app)


## The first terminal opened while live says, on one line, that it is a
## real shell on the station, and remembers that it said so; the sample
## never does.
func test_the_first_live_terminal_says_it_is_a_real_shell_once_a_run() -> void:
	TerminalApp.real_shell_notice_shown = false
	var settings := fresh_settings()
	var sample_app: TerminalApp = open("terminal", sample(), sample_row(), false, settings)
	assert_true(not sample_app.notice.visible, "not for the sample")
	close(sample_app)
	assert_true(not TerminalApp.real_shell_notice_shown, "which does not count")

	var live := StubSource.new()
	live.live = true
	var app: TerminalApp = open("terminal", live, station_row(), false, settings)
	assert_true(app.notice.visible, "the first live terminal says so")
	assert_true(app.notice.text.contains("real shell") and app.notice.text.contains("Build box"), app.notice.text)
	close(app)
	app = open("terminal", live, station_row(), false, settings)
	assert_true(not app.notice.visible, "the next, in the same run, does not")
	close(app)
	assert_true(not Settings.DEFAULTS["station"].has("first_shell_notice_shown"), "nothing is kept on disk for it")
	assert_true(not FileAccess.get_file_as_string(SETTINGS_FILE).contains("shell"), "nor written")
	# A new run starts without it.
	TerminalApp.real_shell_notice_shown = false
	app = open("terminal", live, station_row(), false, settings)
	assert_true(app.notice.visible, "a new run says so again")
	close(app)


## Against the sample: the recording's opening plays, and Enter through the
## view plays its first command.
func test_the_terminal_plays_the_sample() -> void:
	var app: TerminalApp = open("terminal", sample(), sample_row())
	assert_true(await until(func() -> bool: return app.screen_text().contains("synthetic recording")), "the banner: %s" % app.screen_text())
	await until(func() -> bool: return app.screen_text().strip_edges().ends_with("$"))
	app.view.gui_input.emit(key(KEY_ENTER))
	assert_true(await until(func() -> bool: return app.screen_text().contains("cargo build")), "Enter plays a command: %s" % app.screen_text())
	close(app)


## Watching, the terminal shows the shell but sends it nothing: no keys, no
## paste and no resize, and it takes no focus.
func test_a_watched_terminal_sends_nothing() -> void:
	var source := StubSource.new()
	var app: TerminalApp = open("terminal", source, station_row(), true)
	var shell: StubTerminal = source.terminals[0]
	shell.open()
	app.size = Vector2(1600, 900)
	await settle(1)
	app.view.gui_input.emit(key(KEY_A, 0x61))
	app.read_clipboard = func(_primary: bool) -> String: return "x"
	app.view.gui_input.emit(click(MOUSE_BUTTON_MIDDLE))
	app.paste("y")
	assert_eq(shell.inputs, [], "no input")
	assert_eq(shell.resizes, [], "no resize")
	assert_eq(app.view.focus_mode, Control.FOCUS_NONE, "no focus")
	shell.data.emit("watched\r\n".to_utf8_buffer())
	app.refresh()
	assert_true(app.row_text(0).begins_with("watched"), "but it shows the output")
	close(app)


## The monospace face is the style's `font_mono`, or the engine's own
## monospace when the style names none or one that does not load.
func test_the_terminal_face_falls_back_to_the_engines_monospace() -> void:
	var source := StubSource.new()
	var app: TerminalApp = open("terminal", source, station_row())
	assert_eq(app.mono_font(), StationApp.engine_mono_font(), "no font_mono: the engine's")
	assert_true(app.mono_font() is SystemFont and Array(app.mono_font().font_names).has("monospace"), "a monospace one")
	close(app)
	app = open("terminal", source, station_row(), false, null, Vector2(1200, 640), {"ui": {"font_mono": "res://missing.ttf"}})
	assert_eq(app.mono_font(), StationApp.engine_mono_font(), "a missing one: the engine's too")
	close(app)


# ---- Logs ----

## The sample's tail arrives line by line and the view follows it.
func test_logs_tail_the_sample() -> void:
	var app: LogsApp = open("logs", sample(), sample_row())
	assert_true(await until(func() -> bool: return app.line_count() >= 45), "the tail and then the follow: %d" % app.line_count())
	assert_true(app.line(0).contains("sample-harness"), "in order: %s" % app.line(0))
	var shown := app.lines_in_view()
	assert_true(not shown.is_empty() and shown.back() == app.line(app.line_count() - 1), "the view follows the newest line")
	close(app)


## The ring keeps the newest 5,000 lines.
func test_logs_keep_a_ring_of_5000_lines() -> void:
	var source := StubSource.new()
	var app: LogsApp = open("logs", source, station_row())
	var stream: StubLogs = source.log_streams[0]
	stream.open()
	for i in 6000:
		stream.line.emit("line %d" % i)
	assert_eq(LogsApp.RING_LINES, 5000, "5,000 lines")
	assert_eq(app.line_count(), 5000, "the ring is full")
	assert_eq(app.line(0), "line 1000", "the oldest kept")
	assert_eq(app.line(4999), "line 5999", "the newest")
	assert_eq(app.lines_in_view().back(), "line 5999", "in view")
	close(app)


## Pause stops the view scrolling while lines still arrive into the ring;
## Resume goes back to the newest.
func test_logs_pause_holds_the_view_while_lines_still_arrive() -> void:
	var source := StubSource.new()
	var app: LogsApp = open("logs", source, station_row())
	var stream: StubLogs = source.log_streams[0]
	stream.open()
	for i in 100:
		stream.line.emit("line %d" % i)
	app.pause_button.pressed.emit()
	assert_true(app.paused, "paused")
	assert_eq(app.pause_button.text, "Resume", "the button says Resume")
	var held := app.lines_in_view()
	for i in range(100, 150):
		stream.line.emit("line %d" % i)
	assert_eq(app.line_count(), 150, "lines still arrive")
	assert_eq(app.lines_in_view(), held, "the view holds")
	app.pause_button.pressed.emit()
	assert_true(not app.paused and app.pause_button.text == "Pause", "resumed")
	assert_eq(app.lines_in_view().back(), "line 149", "at the newest")
	close(app)


## Search highlights every match in view and jumps between them, round from
## either end; a jump holds the view there.
func test_logs_search_highlights_and_jumps_between_matches() -> void:
	var source := StubSource.new()
	var app: LogsApp = open("logs", source, station_row())
	var stream: StubLogs = source.log_streams[0]
	stream.open()
	for i in 300:
		stream.line.emit("line %d %s" % [i, "ERROR disk full" if i % 50 == 7 else "ok"])
	assert_true(StationApp.is_typing_target(app.search_field), "the search field takes typing, so Esc stays in it")
	app.search_field.text = "error"
	app.search_field.text_changed.emit("error")
	assert_eq(app.match_count(), 6, "case-insensitive matches")
	assert_eq(app.match_label.text, "6 of 6", "on the newest")
	assert_true(app.lines_in_view().has("line 257 ERROR disk full"), "in view")
	var marks := app.highlights()
	assert_true(marks.any(func(h): return h["line"] == "line 257 ERROR disk full" and h["col"] == 9 and h["length"] == 5 and h["current"]),
		"the current match is highlighted: %s" % [marks])
	app.next_button.pressed.emit()
	assert_eq(app.match_label.text, "1 of 6", "round to the first")
	assert_true(app.paused, "a jump holds the view")
	assert_true(app.lines_in_view().has("line 7 ERROR disk full"), "and shows it: %s" % [app.lines_in_view()])
	app.previous_button.pressed.emit()
	assert_eq(app.match_label.text, "6 of 6", "and back round to the last")
	app.previous_button.pressed.emit()
	assert_eq(app.match_label.text, "5 of 6", "then the one before")
	assert_true(app.lines_in_view().has("line 207 ERROR disk full"), "shown")
	stream.line.emit("late ERROR")
	assert_eq(app.match_count(), 7, "a new line's match counts")
	app.search_field.text_submitted.emit("error")
	assert_eq(app.match_label.text, "6 of 7", "Enter goes to the next")
	app.search_field.text_changed.emit("")
	assert_eq(app.match_count(), 0, "cleared")
	assert_eq(app.highlights(), [], "nothing highlighted")
	close(app)


## With the ring full and a search on, each new line costs about the same
## however many matches there are: the oldest matches fall off without the
## rest being copied.
func test_logs_search_keeps_up_with_a_full_ring() -> void:
	var source := StubSource.new()
	var app: LogsApp = open("logs", source, station_row())
	var stream: StubLogs = source.log_streams[0]
	stream.open()
	for i in LogsApp.RING_LINES:
		stream.line.emit("line %d: ok ok" % i)
	app.search_field.text_changed.emit("ok")
	assert_eq(app.match_count(), 2 * LogsApp.RING_LINES, "two matches a line")
	app.next_button.pressed.emit()
	var started := Time.get_ticks_usec()
	for i in range(LogsApp.RING_LINES, 5 * LogsApp.RING_LINES):
		stream.line.emit("line %d: ok ok" % i)
	var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
	var budget_ms := 1500.0 * machine_factor()
	print("logs: 20000 lines into a full ring with 10000 matches in %.0f ms (budget %.0f ms)" % [elapsed_ms, budget_ms])
	assert_true(elapsed_ms < budget_ms, "20000 lines took %.0f ms (budget %.0f ms)" % [elapsed_ms, budget_ms])
	assert_eq(app.match_count(), 2 * LogsApp.RING_LINES, "still two a kept line")
	assert_eq(app.line(0), "line 20000: ok ok", "the oldest kept")
	assert_eq(app.match_label.text, "1 of 10000", "the current match fell off: the oldest left is current")
	app.previous_button.pressed.emit()
	assert_eq(app.match_label.text, "10000 of 10000", "and round to the newest")
	assert_true(app.lines_in_view().has("line 24999: ok ok"), "shown")
	close(app)


# ---- Files ----

## The tree lists the workspace's top level, and a folder only when it is
## opened.
func test_files_list_lazily() -> void:
	var source := sample()
	var calls := []
	source.result.connect(func(call_id, _ok, _body, _status): calls.append(call_id))
	var app: FilesApp = open("files", source, sample_row())
	assert_true(await until(func() -> bool: return app.listed(".").size() == 3), "the top level: %s" % [app.listed(".")])
	assert_eq(app.listed("."), ["src", "tests", "Cargo.toml"], "folders first")
	assert_eq(calls.size(), 1, "one listing so far")
	app.expand("src")
	assert_true(await until(func() -> bool: return app.listed("src").size() == 2), "src when opened")
	assert_eq(app.listed("src"), ["lib.rs", "main.rs"], "its files")
	assert_eq(calls.size(), 2, "a second listing, for it alone")
	app.item_for("src").collapsed = true
	app.item_for("src").collapsed = false
	await settle()
	assert_eq(calls.size(), 2, "opened again, not asked again")
	close(app)


## A text file previews, read-only; a binary one shows its size and
## "Binary file". Selecting in the tree opens it.
func test_files_preview_text_and_say_binary() -> void:
	var app: FilesApp = open("files", sample(), sample_row())
	await until(func() -> bool: return app.listed(".").size() == 3)
	app.expand("src")
	await until(func() -> bool: return app.listed("src").size() == 2)
	app.item_for("src/lib.rs").select(0)
	assert_true(await until(func() -> bool: return app.preview.text.contains("split_whitespace")), "the preview: %s" % app.preview.text)
	assert_true(not app.preview.editable, "read-only")
	assert_true(not StationApp.is_typing_target(app.preview), "so Esc still leaves from it")
	assert_eq(app.note.text, "src/lib.rs", "the note names it")
	app.expand("tests")
	await until(func() -> bool: return app.listed("tests").size() == 2)
	app.expand("tests/fixtures")
	await until(func() -> bool: return app.listed("tests/fixtures").size() >= 1)
	app.open_file("tests/fixtures/latin1.txt")
	assert_true(await until(func() -> bool: return app.note.text.contains(FilesApp.BINARY)), "binary: %s" % app.note.text)
	assert_true(not app.preview.visible, "no preview")
	assert_true(app.note.text.contains(" B"), "with its size: %s" % app.note.text)
	close(app)


## A read asks for 1 MiB, and a truncated one says "Truncated".
func test_files_preview_up_to_1_mib_and_say_truncated() -> void:
	var source := StubSource.new()
	var app: FilesApp = open("files", source, station_row())
	source.reply("files", [{"name": "big.log", "path": "big.log", "type": "file", "size": 5 << 20, "modified": "2026-09-29T00:00:00.000Z"}])
	app.open_file("big.log")
	assert_eq(source.last("file")["args"], ["stn_a", "big.log", 1 << 20], "up to 1 MiB")
	source.reply("file", {"text": "start of it", "truncated": true})
	assert_eq(app.preview.text, "start of it", "the text")
	assert_true(app.note.text.contains(FilesApp.TRUNCATED), "and the note: %s" % app.note.text)
	app.open_file("big.log")
	source.reply("file", {"bytes": PackedByteArray([0, 1, 2]), "truncated": true})
	assert_true(app.note.text.contains("Binary file") and app.note.text.contains("5.0 MiB"), "the listed size: %s" % app.note.text)
	var first: int = source.last("file")["id"]
	app.open_file("big.log")
	source.result.emit(first, true, {"text": "stale", "truncated": false}, 200)
	assert_true(app.preview.text != "stale", "a stale answer is dropped")
	close(app)


## A 1 MiB preview never stalls a frame: it is placed a slice a frame, and
## ends whole.
func test_a_1_mib_preview_is_placed_without_stalling_a_frame() -> void:
	var line := "    let counts = tally::count(&text); // a line of source code, about eighty chars\n"
	var body := line.repeat((1 << 20) / line.length())
	var budget_ms := 16.0 * machine_factor()
	for id in ["files", "changes"]:
		var source := StubSource.new()
		var app := open(id, source, station_row())
		var edit: TextEdit
		var started := Time.get_ticks_usec()
		if id == "files":
			source.reply("files", [{"name": "big.rs", "path": "big.rs", "type": "file", "size": body.length(), "modified": "2026-09-29T00:00:00.000Z"}])
			app.open_file("big.rs")
			started = Time.get_ticks_usec()
			source.reply("file", {"text": body, "truncated": false})
			edit = app.preview
		else:
			source.reply("changeset_status", {"repo": {"branch": "b", "head": "abc", "detached": false},
				"base": {"ref": "origin/main", "sha": "def", "reason": "upstream"},
				"uncommitted": {"files": [{"path": "big.rs", "oldPath": null, "status": "added", "insertions": 12000, "deletions": 0, "binary": false}], "insertions": 12000, "deletions": 0},
				"committed": {"files": [], "insertions": 0, "deletions": 0, "commits": []}, "truncatedFiles": false})
			started = Time.get_ticks_usec()
			source.reply("changeset_diff", {"content": body, "truncated": false, "binary": false})
			edit = app.diff
		var worst := (Time.get_ticks_usec() - started) / 1000.0
		var frames := 1
		while app.filling() and frames < 1000:
			var t := Time.get_ticks_usec()
			app.fill_step()
			worst = maxf(worst, (Time.get_ticks_usec() - t) / 1000.0)
			frames += 1
		print("%s: 1 MiB placed over %d frames, the worst %.1f ms (budget %.0f ms)" % [id, frames, worst, budget_ms])
		assert_true(worst < budget_ms, "%s: the worst frame took %.1f ms (budget %.0f ms)" % [id, worst, budget_ms])
		assert_true(frames > 1, "%s: over more than one frame" % id)
		assert_eq(edit.text, body, "%s: the whole text, in order" % id)
		close(app)


## A new preview replaces one still being placed.
func test_a_new_preview_replaces_one_being_placed() -> void:
	var source := StubSource.new()
	var app: FilesApp = open("files", source, station_row())
	source.reply("files", [])
	app.open_file("a.txt")
	source.reply("file", {"text": "x\n".repeat(200000), "truncated": false})
	assert_true(app.filling(), "the first is being placed")
	app.open_file("b.txt")
	source.reply("file", {"text": "small", "truncated": false})
	assert_true(not app.filling(), "the second replaced it")
	for i in 5:
		app.fill_step()
	assert_eq(app.preview.text, "small", "and nothing of the first comes back")
	close(app)


## A failure belongs to its request: a preview that works does not hide a
## listing that failed, and that listing's success clears only its own.
func test_files_keep_each_requests_failure_apart() -> void:
	var source := StubSource.new()
	var app: FilesApp = open("files", source, station_row())
	source.reply("files", [{"name": "src", "path": "src", "type": "dir", "size": null, "modified": "2026-09-29T00:00:00.000Z"},
		{"name": "a.txt", "path": "a.txt", "type": "file", "size": 1, "modified": "2026-09-29T00:00:00.000Z"}])
	app.expand("src")
	source.refuse("files", "offline")
	assert_eq(app.error_text(), "Station offline", "the listing failed")
	app.open_file("a.txt")
	source.reply("file", {"text": "a", "truncated": false})
	assert_eq(app.error_text(), "Station offline", "a preview that works leaves it")
	app.press_error_button()
	source.reply("files", [])
	assert_eq(app.error_text(), "", "the retried listing clears it")
	close(app)


# ---- Health ----

## The sample's health: running, cpu, memory, disk, uptime and the node.
func test_health_shows_the_sample() -> void:
	var app: HealthApp = open("health", sample(), sample_row())
	assert_true(await until(func() -> bool: return app.value("status") == "Running"), "running: %s" % app.value("status"))
	assert_eq(app.value("cpu"), "3.1%", "cpu")
	assert_eq(app.value("memory"), "84.5 MiB", "memory")
	assert_eq(app.value("disk"), "40.0 MiB", "disk")
	assert_eq(app.value("uptime"), "21 min", "uptime")
	assert_eq(app.value("node"), "Online", "the node, from the station list")
	close(app)


## It refreshes every 5 s while it shows, and not while hidden; the node
## follows the station list.
func test_health_refreshes_every_5_s_while_visible() -> void:
	var source := StubSource.new()
	var app: HealthApp = open("health", source, station_row())
	assert_eq(source.calls_to("health").size(), 1, "asked on opening")
	source.reply("health", {"running": true, "pid": 7, "cpuPct": 2.0, "memBytes": 1 << 30, "diskBytes": null,
		"uptimeSec": 7300, "lastActivity": null, "note": null})
	assert_eq(app.value("memory"), "1.0 GiB", "memory")
	assert_eq(app.value("disk"), "—", "no disk reading")
	assert_eq(app.value("uptime"), "2 h 1 min", "uptime")
	app._process(4.0)
	assert_eq(source.calls_to("health").size(), 1, "not before 5 s")
	app._process(1.1)
	assert_eq(source.calls_to("health").size(), 2, "at 5 s")
	app._process(6.0)
	assert_eq(source.calls_to("health").size(), 2, "not while one is waiting")
	source.reply("health", {"running": false, "pid": null, "cpuPct": null, "memBytes": null, "diskBytes": 10,
		"uptimeSec": null, "lastActivity": null, "note": null})
	assert_eq(app.value("status"), "Stopped", "the new reading")
	app.visible = false
	app._process(10.0)
	assert_eq(source.calls_to("health").size(), 2, "not while hidden")
	app.visible = true
	app._process(5.1)
	assert_eq(source.calls_to("health").size(), 3, "again when shown")
	source.stations.emit([station_row(EVERY_CAPABILITY, "offline")])
	assert_eq(app.value("node"), "Offline", "the node follows the list")
	close(app)


## After a refusal that asking again cannot fix (signed out, no access),
## Health stops asking every 5 s.
func test_health_stops_polling_after_signed_out_or_no_access() -> void:
	for kind in ["signed_out", "no_access"]:
		var source := StubSource.new()
		var app: HealthApp = open("health", source, station_row())
		source.refuse("health", kind)
		app._process(20.0)
		assert_eq(source.calls_to("health").size(), 1, "%s: no more readings" % kind)
		close(app)
	var source := StubSource.new()
	var app: HealthApp = open("health", source, station_row())
	source.refuse("health", "offline")
	app._process(5.1)
	assert_eq(source.calls_to("health").size(), 2, "offline: it keeps trying")
	close(app)


## Start, Stop and Restart each ask first, naming the station; the answer's
## health shows. Cancel sends nothing.
func test_health_lifecycle_asks_first_and_shows_the_result() -> void:
	var app: HealthApp = open("health", sample(), sample_row())
	await until(func() -> bool: return app.value("status") == "Running")
	app.stop_button.pressed.emit()
	assert_true(app.confirm_box.visible, "Stop asks")
	assert_eq(app.confirm_label.text, "Stop Sample station?", "naming the station")
	assert_true(not app.confirm_label.text.contains("real"), "the sample is not real")
	app.cancel_button.pressed.emit()
	assert_true(not app.confirm_box.visible, "cancelled")
	await settle()
	assert_eq(app.value("status"), "Running", "nothing sent")
	app.stop_button.pressed.emit()
	app.confirm_button.pressed.emit()
	assert_true(await until(func() -> bool: return app.value("status") == "Stopped"), "the returned health shows")
	assert_eq(app.value("cpu"), "—", "no cpu when stopped")
	app.start_button.pressed.emit()
	assert_eq(app.confirm_label.text, "Start Sample station?", "Start asks too")
	app.confirm_button.pressed.emit()
	assert_true(await until(func() -> bool: return app.value("status") == "Running"), "started")
	app.restart_button.pressed.emit()
	assert_eq(app.confirm_label.text, "Restart Sample station?", "Restart asks too")
	close(app)


## Live, Stop and Restart say they are real; the station must offer
## lifecycle; watching offers none of it.
func test_health_says_stop_and_restart_are_real_when_live() -> void:
	var source := StubSource.new()
	source.live = true
	var app: HealthApp = open("health", source, station_row())
	app.stop_button.pressed.emit()
	assert_true(app.confirm_label.text.begins_with("Stop Build box?") and app.confirm_label.text.contains("real"), app.confirm_label.text)
	assert_eq(source.calls_to("lifecycle"), [], "nothing until confirmed")
	app.confirm_button.pressed.emit()
	assert_eq(source.last("lifecycle")["args"], ["stn_a", "stop"], "then stop")
	source.reply("lifecycle", {"running": false, "pid": null, "cpuPct": null, "memBytes": null, "diskBytes": null,
		"uptimeSec": null, "lastActivity": null, "note": null})
	assert_eq(app.value("status"), "Stopped", "the post-action health")
	app.restart_button.pressed.emit()
	assert_true(app.confirm_label.text.contains("real"), "restart is real: %s" % app.confirm_label.text)
	app.start_button.pressed.emit()
	assert_true(app.confirm_label.text.begins_with("Start Build box?") and app.confirm_label.text.contains("real"),
		"start is real too: %s" % app.confirm_label.text)
	close(app)
	app = open("health", source, station_row(["health"]))
	assert_true(app.stop_button.disabled and app.stop_button.tooltip_text != "", "no lifecycle: greyed out, with why")
	close(app)
	app = open("health", source, station_row(), true)
	assert_true(not app.stop_button.is_visible_in_tree() and not app.start_button.is_visible_in_tree(), "watching: no lifecycle")
	close(app)


# ---- Changes ----

## The branch, head and base, both sides' files with their counts, and the
## selected file's diff with added and removed lines coloured from the
## palette.
func test_changes_show_the_sample() -> void:
	var app: ChangesApp = open("changes", sample(), sample_row())
	assert_true(await until(func() -> bool: return app.summary.text.contains("count-tabs")), "the branch: %s" % app.summary.text)
	assert_true(app.summary.text.contains("48b0821"), "the head: %s" % app.summary.text)
	assert_true(app.summary.text.contains("origin/main") and app.summary.text.contains("upstream"), "the base and why: %s" % app.summary.text)
	assert_eq(app.listed("uncommitted"), ["src/lib.rs  +1 −1"], "uncommitted")
	assert_eq(app.listed("committed"), ["src/main.rs  +2 −1", "tests/count.rs  +17 −0"], "committed")
	assert_true(await until(func() -> bool: return app.diff.text.contains("diff --git a/src/lib.rs")), "the first file's diff: %s" % app.diff.text)
	app.select_file("committed", "src/main.rs")
	assert_true(await until(func() -> bool: return app.diff.text.contains("wc")), "another: %s" % app.diff.text)
	assert_true(not app.diff.editable, "read-only")
	var colours := ChangesApp.diff_colours(app.ui)
	var added := -1
	var removed := -1
	for i in app.diff.get_line_count():
		var l := app.diff.get_line(i)
		if l.begins_with("+") and not l.begins_with("+++"):
			added = i
		elif l.begins_with("-") and not l.begins_with("---"):
			removed = i
	assert_true(added >= 0 and removed >= 0, "added and removed lines")
	assert_eq(app.line_colour(added), colours["added"], "added lines in the added colour")
	assert_eq(app.line_colour(removed), colours["removed"], "removed in the removed colour")
	assert_true(colours["added"] != colours["removed"], "two colours")
	var styled := ChangesApp.diff_colours(UiTheme.from_style({"ui": {"colours": {"added": "#00FF00", "removed": "#FF00FF"}}}))
	assert_eq([styled["added"], styled["removed"]], [Color("#00FF00"), Color("#FF00FF")], "a style's own")
	for style in ["neon_noir", "lowpoly_tropical"]:
		var ui := UiTheme.from_style(JSON.parse_string(FileAccess.get_file_as_string("res://styles/%s/style.json" % style)))
		var derived := ChangesApp.diff_colours(ui)
		for which in ["added", "removed"]:
			assert_true(UiTheme.contrast(derived[which], Color(ui.colour("panel"), 1.0)) >= 3.0, "%s %s is legible on its panel" % [style, which])
	close(app)


# ---- Errors, in every app ----

## Each failure kind as every app shows it: offline with Retry, no access,
## signed out with "Sign in again", and anything else as one line without
## the body; Retry asks again.
func test_every_app_shows_each_failure_kind() -> void:
	# How each app's first request fails, and how many requests it has made.
	var first := {
		"terminal": func(source: StubSource, kind: String) -> void:
			source.terminals.back().failed.emit(StationSource.make_error(kind, "the node said no\nstack trace")),
		"logs": func(source: StubSource, kind: String) -> void:
			source.log_streams.back().failed.emit(StationSource.make_error(kind, "the node said no\nstack trace")),
		"files": func(source: StubSource, kind: String) -> void:
			source.refuse("files", kind, "the node said no\nstack trace"),
		"health": func(source: StubSource, kind: String) -> void:
			source.refuse("health", kind, "the node said no\nstack trace"),
		"changes": func(source: StubSource, kind: String) -> void:
			source.refuse("changeset_status", kind, "the node said no\nstack trace"),
		"chat": func(source: StubSource, kind: String) -> void:
			source.chats.back().failed.emit(StationSource.make_error(kind, "the node said no\nstack trace")),
		"work": func(source: StubSource, kind: String) -> void:
			source.refuse("boards", kind, "the node said no\nstack trace"),
	}
	var asked := {
		"terminal": func(source: StubSource) -> int: return source.terminals.size(),
		"logs": func(source: StubSource) -> int: return source.log_streams.size(),
		"files": func(source: StubSource) -> int: return source.calls_to("files").size(),
		"health": func(source: StubSource) -> int: return source.calls_to("health").size(),
		"changes": func(source: StubSource) -> int: return source.calls_to("changeset_status").size(),
		"chat": func(source: StubSource) -> int: return source.calls_to("open_chat").size(),
		"work": func(source: StubSource) -> int: return source.calls_to("boards").size(),
	}
	for id in first:
		for kind in ["offline", "no_access", "signed_out", "failed", "not_found", "conflict"]:
			var source := StubSource.new()
			# Work's station has its agent already, so its boards are asked for.
			source.built_in_links = {"stn_a": "agt_a"}
			var app := open(id, source, station_row())
			var signed := []
			app.sign_in_requested.connect(func(): signed.append(true))
			first[id].call(source, kind)
			var said := app.error_text()
			var what := "%s, %s" % [id, kind]
			# Work's failures are Superpipeline's, and say so.
			var superpipeline: bool = id == "work"
			match kind:
				"offline":
					assert_eq(said, WorkApp.UNREACHABLE if superpipeline else "Station offline", what)
					assert_eq(app.error_button.text, "Retry", what + ": Retry")
				"no_access":
					assert_eq(said, WorkApp.NO_BOARD_ACCESS if superpipeline else "You don't have access to this station", what)
					assert_true(not app.error_button.visible, what + ": nothing to press")
				"signed_out":
					if superpipeline:
						assert_eq(said, "Superpipeline did not accept this sign-in", what)
					assert_eq(app.error_button.text, "Sign in again", what)
					app.press_error_button()
					assert_eq(signed, [true], what + ": asks for sign-in")
				_:
					assert_eq(said, "the node said no", what + ": one line, not the body")
			if app.error_button.visible and app.error_button.text == "Retry":
				var before: int = asked[id].call(source)
				app.press_error_button()
				assert_eq(asked[id].call(source), before + 1, what + ": Retry asks again")
			close(app)


## An answer after the app has closed goes nowhere, even while the app
## itself is still about.
func test_an_answer_after_closing_goes_nowhere() -> void:
	var source := StubSource.new()
	var app: HealthApp = open("health", source, station_row())
	var call_id: int = source.last("health")["id"]
	app.closing()
	source.result.emit(call_id, true, {"running": true, "pid": 1, "cpuPct": 50.0, "memBytes": 1, "diskBytes": 1,
		"uptimeSec": 1, "lastActivity": null, "note": null}, 200)
	assert_eq(app.value("cpu"), HealthApp.NONE, "the answer changed nothing")
	app._process(20.0)
	assert_eq(source.calls_to("health").size(), 1, "and a closed app asks nothing more")
	app.free()


## Leaving the computer closes the open app's stream.
func test_leaving_the_computer_closes_the_apps_streams() -> void:
	for id in ["terminal", "logs"]:
		var stack := ScreenStack.new()
		stack.router = InputRouter.new()
		runner.root.add_child(stack.router)
		stack.ui = UiTheme.from_style({})
		runner.root.add_child(stack)
		var source := StubSource.new()
		var c := ComputerScreen.new()
		c.settings = fresh_settings()
		c.glyphs = InputGlyphs.new()
		c.platform = "desktop"
		c.touch = false
		stack.push(c)
		c.open({"target": "seat:w2", "kind": "workstation", "binding": {}}, source)
		source.reply("list_stations", {"stats": {}, "agents": [station_row()]})
		c.choose(0)
		c.open_app(id)
		var stream: StationStream = source.terminals[0] if id == "terminal" else source.log_streams[0]
		stream.open()
		c.leave()
		assert_true(not stack.screens.has(c), "%s: left" % id)
		assert_eq(stream.state, "closed", "%s: its stream is closed" % id)
		var router := stack.router
		stack.free()
		router.free()


# ---- Placing long text ----

## A single line longer than 4,000 characters is cut for display, so a
## minified 1 MiB file fills without a frame over budget.
func test_a_1_mib_single_line_is_cut_for_display() -> void:
	var body := "{\"k\":1234567},".repeat((1 << 20) / 14)
	var budget_ms := 16.0 * machine_factor()
	var source := StubSource.new()
	var app: FilesApp = open("files", source, station_row())
	source.reply("files", [{"name": "min.js", "path": "min.js", "type": "file", "size": body.length(), "modified": "2026-09-29T00:00:00.000Z"}])
	app.open_file("min.js")
	var started := Time.get_ticks_usec()
	source.reply("file", {"text": body + "\nshort line\n" + body, "truncated": false})
	var worst := (Time.get_ticks_usec() - started) / 1000.0
	var frames := 1
	while app.filling() and frames < 1000:
		var t := Time.get_ticks_usec()
		app.fill_step()
		worst = maxf(worst, (Time.get_ticks_usec() - t) / 1000.0)
		frames += 1
	print("files: two 1 MiB lines placed over %d frames, the worst %.1f ms (budget %.0f ms)" % [frames, worst, budget_ms])
	assert_true(worst < budget_ms, "the worst frame took %.1f ms (budget %.0f ms)" % [worst, budget_ms])
	assert_eq(app.preview.get_line_count(), 3, "three lines")
	assert_eq(app.preview.get_line(0), body.left(StationApp.LONGEST_LINE) + StationApp.LINE_CUT, "the first cut")
	assert_eq(app.preview.get_line(1), "short line", "a short line whole")
	assert_true(app.preview.get_line(2).ends_with(StationApp.LINE_CUT), "the last cut too")
	assert_eq(StationApp.LINE_CUT, "… (line cut)")
	assert_eq(StationApp.LONGEST_LINE, 4000)
	close(app)
