extends TestSuite


## Bytes like an asciicast's first "o" (output) events: a green shell
## prompt, a command, and an inverse-video status line, with the cursor
## left where it landed. `feed` takes raw terminal bytes, which is what a
## recording's `data` field carries once decoded (Task 4 owns the actual
## `terminal.cast` fixture and its asciicast parsing).
func _first_frames() -> PackedByteArray:
	return ("\u001b[32m$ \u001b[0mls\r\n" + "\u001b[1;7m README \u001b[0m\r\n").to_utf8_buffer()


func test_extension_loads() -> void:
	assert_true(ClassDB.class_exists("TermGrid"), "TermGrid is registered; run city/scripts/build-godot.sh")


func test_setup_reports_its_size() -> void:
	var t = ClassDB.instantiate("TermGrid")
	t.setup(80, 24)
	assert_eq(t.size(), Vector2i(80, 24), "cols, then rows")


func test_feeding_an_asciicasts_first_frames_reads_back_as_runs() -> void:
	var t = ClassDB.instantiate("TermGrid")
	t.setup(20, 3)
	t.feed(_first_frames())

	var prompt_runs: Array = t.row_runs(0)
	assert_true(prompt_runs.size() >= 2, "the coloured prompt and the reset split into runs: %s" % [prompt_runs])
	assert_true(
		prompt_runs[0].has_all(["text", "fg", "bg", "bold", "italic", "underline", "inverse"]),
		"a run carries every field"
	)
	assert_eq(prompt_runs[0]["text"], "$ ", "the prompt itself")
	assert_true(prompt_runs[0]["fg"] != Color(0, 0, 0, 0), "its own colour, not the default")

	var status_runs: Array = t.row_runs(1)
	var joined := ""
	for run in status_runs:
		joined += run["text"]
	assert_true(joined.strip_edges().begins_with("README"), "the status line: %s" % joined)
	assert_true(status_runs[0]["inverse"], "the status word is inverse video")


func test_changed_rows_are_reported_once_and_then_cleared() -> void:
	var t = ClassDB.instantiate("TermGrid")
	t.setup(10, 2)
	assert_eq(Array(t.changed_rows()), [0, 1], "the first paint is the whole blank screen")
	assert_eq(Array(t.changed_rows()), [], "nothing changed since the last read")

	t.feed("hi".to_utf8_buffer())
	assert_eq(Array(t.changed_rows()), [0], "only the row actually touched")


func test_cursor_visibility_and_the_osc_title() -> void:
	var t = ClassDB.instantiate("TermGrid")
	t.setup(10, 2)
	t.feed(_first_frames())
	assert_true(t.cursor_visible(), "visible by default")

	t.feed("\u001b]0;Station Shell\u0007".to_utf8_buffer())
	assert_eq(t.title(), "Station Shell")


func test_setup_and_resize_clamp_invalid_sizes_without_crashing() -> void:
	var t = ClassDB.instantiate("TermGrid")
	t.setup(0, 24)
	t.feed("hi".to_utf8_buffer())
	assert_true(t.size().x >= 1, "cols clamped to at least one")

	t = ClassDB.instantiate("TermGrid")
	t.setup(80, 0)
	t.feed("hi".to_utf8_buffer())
	assert_true(t.size().y >= 2, "rows clamped to at least two")

	t = ClassDB.instantiate("TermGrid")
	t.setup(70000, 24)
	t.feed("hi".to_utf8_buffer())
	assert_true(t.size().x <= 65535, "cols clamped to u16::MAX")

	t = ClassDB.instantiate("TermGrid")
	t.setup(10, 10)
	t.resize(0, 0)
	t.feed("more text than a single cell can hold".to_utf8_buffer())
	assert_true(t.size().x >= 1 and t.size().y >= 2, "resize clamps too")

	t = ClassDB.instantiate("TermGrid")
	t.setup(10, 10)
	t.resize(-5, -5)
	t.feed("more text than a single cell can hold".to_utf8_buffer())
	assert_true(t.size().x >= 1 and t.size().y >= 2, "a negative resize clamps too")


func test_row_runs_is_empty_for_a_row_far_out_of_range() -> void:
	var t = ClassDB.instantiate("TermGrid")
	t.setup(10, 2)
	t.feed("hi".to_utf8_buffer())

	assert_eq(t.row_runs(999999), [], "far beyond the grid's own row count")
	assert_eq(t.row_runs(2147483647), [], "i32::MAX, not just a large row")
	assert_eq(t.row_runs(-1), [], "still refused, as before")
	assert_true(t.row_runs(0).size() > 0, "an in-range row still works")


func test_resize_reports_its_new_size_and_keeps_content() -> void:
	var t = ClassDB.instantiate("TermGrid")
	t.setup(10, 2)
	t.feed("hi".to_utf8_buffer())
	t.resize(20, 4)
	assert_eq(t.size(), Vector2i(20, 4))
	var row: Array = t.row_runs(0)
	var joined := ""
	for run in row:
		joined += run["text"]
	assert_true(joined.begins_with("hi"), "the resize kept the row's content: %s" % joined)
