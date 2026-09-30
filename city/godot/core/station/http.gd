## One HTTP request from the station computer, over Godot's low-level
## `HTTPClient`, polled once a frame so it never blocks the game. A plain
## request answers once, with `finished`; a streaming one (the log tail's
## Server-Sent Events) hands over its body as it arrives.
##
## It keeps itself alive while it runs, so whoever started it may hold it
## only to cancel it. It logs nothing: its URL carries query strings and its
## headers a token, and neither may reach a log.
class_name StationHttp
extends RefCounted

## The whole answer: the status, the headers (their names in lower case)
## and the body. A streaming request answers this way only when its status
## is not a success, so the caller can read the error.
signal finished(status: int, headers: Dictionary, body: PackedByteArray)
## A streaming request succeeded and its body follows, in `chunk`s.
signal response_started(status: int, headers: Dictionary)
## A piece of a streaming request's body, as it arrived.
signal chunk(bytes: PackedByteArray)
## A streaming request's body ended: cleanly, or `lost` with its connection.
signal ended(lost: bool)
## The request never got an answer: the host could not be reached, the
## connection failed, or it took longer than `timeout_s`.
signal network_failed()

## The hosts plain `http://` may reach: this computer's.
const LOOPBACK_HOSTS := ["127.0.0.1", "::1", "localhost"]
## How long a plain request may take, and a streaming one to start, in
## seconds.
const TIMEOUT_S := 30.0
## The most of a body read in one frame; the rest waits for the next, so a
## fast stream never holds a frame.
const FRAME_BUDGET_BYTES := 1 << 20

var method: int
var streaming := false
var timeout_s := TIMEOUT_S
var frame_budget_bytes := FRAME_BUDGET_BYTES

var _client: HTTPClient
var _host := ""
var _port := 0
var _tls := false
var _target := ""
var _headers := PackedStringArray()
var _body := PackedByteArray()
var _requested := false
var _started := false
var _done := false
var _status := 0
var _response_headers := {}
var _received := PackedByteArray()
var _began_msec := 0

## The requests running now, held so a caller may let go of its own.
static var _running: Array[StationHttp] = []
static var _polling := false


## Starts `method` (an `HTTPClient.METHOD_*`) on `url`, with `headers` and
## `body`. It answers on a later frame, never inside this call.
static func start(method_: int, url: String, headers: PackedStringArray, body := PackedByteArray(),
		streaming_ := false) -> StationHttp:
	var request := StationHttp.new()
	request.method = method_
	request.streaming = streaming_
	request._begin(url, headers, body)
	return request


## Splits an `http://` or `https://` URL into [tls, host, port, target],
## where the target is the path with its query; [] when it is not one.
static func split_url(url: String) -> Array:
	var tls := false
	var rest := url
	if url.begins_with("https://"):
		tls = true
		rest = url.substr(8)
	elif url.begins_with("http://"):
		rest = url.substr(7)
	else:
		return []
	var slash := rest.find("/")
	var authority := rest if slash < 0 else rest.substr(0, slash)
	var target := "/" if slash < 0 else rest.substr(slash)
	var host := authority
	var port := 443 if tls else 80
	var colon := authority.rfind(":")
	if colon > 0 and not authority.ends_with("]"):
		host = authority.substr(0, colon)
		var digits := authority.substr(colon + 1)
		if not digits.is_valid_int():
			return []
		port = digits.to_int()
	if host == "":
		return []
	return [tls, host.trim_prefix("[").trim_suffix("]"), port, target]


## Whether `url` may carry a secret (the device credential, a token, a
## sign-in's code): `https://`, or plain `http://` only to this computer
## (127.0.0.1, [::1] or localhost), where nothing crosses a network. A hub
## or Superpipeline anywhere else must use TLS.
static func is_secure_or_loopback(url: String) -> bool:
	var parts := split_url(url)
	if parts.is_empty():
		return false
	return parts[0] or str(parts[1]).to_lower() in LOOPBACK_HOSTS


## Stops the request; it emits nothing more.
func cancel() -> void:
	if _done:
		return
	_done = true
	_client.close()
	_running.erase(self)


## Whether it has answered, failed or been cancelled.
func is_done() -> bool:
	return _done


func _begin(url: String, headers: PackedStringArray, body: PackedByteArray) -> void:
	_client = StationSource.new_network_object("HTTPClient")
	_headers = headers
	_body = body
	_began_msec = Time.get_ticks_msec()
	var parts := split_url(url)
	_running.append(self)
	_ensure_polling()
	if parts.is_empty():
		_fail_later()
		return
	_tls = parts[0]
	_host = parts[1]
	_port = parts[2]
	_target = parts[3]
	var tls_options: TLSOptions = TLSOptions.client() if _tls else null
	StationSource.note_destination(_host, _port)
	if _client.connect_to_host(_host, _port, tls_options) != OK:
		_fail_later()


## Fails on the next frame, so nothing answers inside the call.
func _fail_later() -> void:
	_done = true
	_running.erase(self)
	(Engine.get_main_loop() as SceneTree).process_frame.connect(network_failed.emit, CONNECT_ONE_SHOT)


static func _ensure_polling() -> void:
	if _polling:
		return
	_polling = true
	(Engine.get_main_loop() as SceneTree).process_frame.connect(_poll_all)


static func _poll_all() -> void:
	for request in _running.duplicate():
		request._poll()
	if _running.is_empty():
		_polling = false
		(Engine.get_main_loop() as SceneTree).process_frame.disconnect(_poll_all)


func _poll() -> void:
	if _done:
		return
	_client.poll()
	var status := _client.get_status()
	match status:
		HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_REQUESTING:
			pass
		HTTPClient.STATUS_CONNECTED:
			if not _requested:
				_requested = true
				if _client.request_raw(method, _target, _headers, _body) != OK:
					_network_failed()
					return
			elif _client.has_response():
				_read_head()
				_body_ended(false)
				return
		HTTPClient.STATUS_BODY:
			_read_head()
			# What has arrived, not one chunk a frame (a large body would take a
			# frame per 64 KiB), up to the frame's budget.
			var read := 0
			while _client.get_status() == HTTPClient.STATUS_BODY and not _done and read < frame_budget_bytes:
				var piece := _client.read_response_body_chunk()
				if piece.is_empty():
					break
				read += piece.size()
				if _streaming_success():
					chunk.emit(piece)
				else:
					_received.append_array(piece)
				_client.poll()
			if _client.get_status() != HTTPClient.STATUS_BODY and not _done:
				_body_ended(false)
				return
		HTTPClient.STATUS_DISCONNECTED:
			# A body read to the connection's end has ended there.
			if _started:
				_body_ended(false)
			else:
				_network_failed()
			return
		_:
			# Could not resolve or connect, a TLS failure, or the connection
			# broke: a lost stream if it had started, else no answer at all.
			if _started and _streaming_success():
				_body_ended(true)
			else:
				_network_failed()
			return
	if not _done and (not _started or not streaming) and Time.get_ticks_msec() - _began_msec > int(timeout_s * 1000.0):
		_network_failed()


func _streaming_success() -> bool:
	return streaming and _status >= 200 and _status < 300


## Reads the status and headers once the response has begun.
func _read_head() -> void:
	if _started:
		return
	_started = true
	_status = _client.get_response_code()
	for line in _client.get_response_headers():
		var colon := line.find(":")
		if colon > 0:
			_response_headers[line.substr(0, colon).strip_edges().to_lower()] = line.substr(colon + 1).strip_edges()
	if _streaming_success():
		response_started.emit(_status, _response_headers)


func _body_ended(lost: bool) -> void:
	if _done:
		return
	_done = true
	_client.close()
	_running.erase(self)
	if _streaming_success():
		ended.emit(lost)
	else:
		finished.emit(_status, _response_headers, _received)


func _network_failed() -> void:
	if _done:
		return
	_done = true
	_client.close()
	_running.erase(self)
	network_failed.emit()
