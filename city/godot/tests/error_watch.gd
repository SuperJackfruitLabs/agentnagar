## Fails the running test on any script or engine error, so a test that
## crashes after its first assertion cannot pass.
extends Logger

var runner


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING or runner == null or runner.current == "":
		return
	var what := rationale if rationale != "" else code
	runner.errors.append("%s (%s:%d in %s)" % [what, file.get_file(), line, function])


func _log_message(_message: String, _error: bool) -> void:
	pass
