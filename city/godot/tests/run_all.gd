## Headless test runner: loads every res://tests/test_*.gd, calls each
## method whose name starts with test_, and exits 0 only if all pass.
## godot --headless --path city/godot --script res://tests/run_all.gd
extends SceneTree

var failures: Array[String] = []
var passed := 0
var current := ""
## Assertions made by the current test; a test that makes none has failed,
## usually because a script error cut it short.
var asserted := 0
## Errors logged while the current test ran; any fails it.
var errors: Array[String] = []


func _init() -> void:
	var watch = load("res://tests/error_watch.gd").new()
	watch.runner = self
	OS.add_logger(watch)
	# No test opens a real browser, whatever it forgot to script: every
	# station page goes through this seam. (A method, not a lambda: a lambda
	# of this script's left in another script's static crashes the exit.)
	SystemBrowser.opener = _open_no_browser
	# The client's settings file and station links for this run (see
	# main.gd's TEST_SETTINGS_PATH and TEST_LINKS_PATH): every run starts
	# from the defaults.
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings_test.cfg"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://station_links_test.cfg"))
	# Start the scene tree first, so every test runs with nodes inside it:
	# viewports, cameras and screen positions work as in the client.
	await process_frame
	var dir := DirAccess.open("res://tests")
	var files: Array[String] = []
	# Arguments after `--` narrow the run to files whose names contain one.
	var only := OS.get_cmdline_user_args()
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and (only.is_empty() or Array(only).any(func(o): return o in f)):
			files.append(f)
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			current = f
			fail("does not compile")
			continue
		var suite = script.new()
		suite.set("runner", self)
		var names: Array[String] = []
		for m in suite.get_method_list():
			if m.name.begins_with("test_"):
				names.append(m.name)
		names.sort()
		for n in names:
			current = f + ":" + n
			asserted = 0
			errors.clear()
			var before := failures.size()
			# A test may await frames; awaiting one that does not is harmless.
			await suite.call(n)
			for e in errors:
				fail("error while running: " + e)
			if asserted == 0:
				fail("no assertions ran (a script error may have stopped the test)")
			if failures.size() == before:
				passed += 1
		if suite is Node:
			suite.free()
		current = ""
	for line in failures:
		print("FAIL ", line)
	print("PASS %d, FAIL %d" % [passed, failures.size()])
	SystemBrowser.opener = Callable()
	quit(0 if failures.is_empty() else 1)


func fail(message: String) -> void:
	failures.append(current + ": " + message)


## The test run's system browser: it opens nothing.
func _open_no_browser(_url: String) -> void:
	pass
