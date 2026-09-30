## Where the station computer's apps get a station and its work from. Two
## sources implement it: `SampleSource` plays the bundled recording, and the
## live source asks AgentPod's hub and Superpipeline as the player. Both
## answer with the protocols' own shapes, field for field, so an app never
## asks which source it has.
##
## Every call answers later, never inside the call: calls return an ID and
## answer through `result`, and streams through their own signals. Bodies
## are the routes' bodies, parsed from JSON. A failure's body is a
## normalised error, `{kind, message}` (see `make_error`).
@abstract
class_name StationSource
extends RefCounted

## The stations the player can open: `FleetAgent` dictionaries. Emitted
## after `list_stations` succeeds, just before its `result`.
signal stations(list: Array)

## The answer to one call. `ok` says whether it succeeded; `body` is the
## route's body when it did and an error, `{kind, message}`, when it did
## not; `status` is the HTTP status the route answered with.
signal result(call_id: int, ok: bool, body: Variant, status: int)

## What a failure can be, whatever the route: the sign-in was refused, the
## player may not see this, the station's node is unreachable, it does not
## exist, it conflicts with the current state (a full stage, a settled
## gate), or anything else.
const ERROR_KINDS := ["signed_out", "no_access", "offline", "not_found", "conflict", "failed"]

## What `watch_chat` fails with when the station has no session to watch.
const NO_SESSION := "No session"

## How many network objects any source has made, through
## `new_network_object`. Tests read it to show that a path made none.
static var network_objects_created := 0

## Told where each connection goes, "host:port", as it is made (see
## `note_destination`); tests set it to check that the station computer
## connects nowhere but its hub, Superpipeline and its own sign-in. Unset
## in play, where nothing is noted.
static var connecting := Callable()

## Whether this source reaches a real station. The station computer shows
## "Live" and asks before real operations when it does.
var LIVE: bool:
	get:
		return _is_live()

var _next_call_id := 0


## Makes a network object (`HTTPClient`, `WebSocketPeer`, `TCPServer`, ...).
## Every one a source makes goes through here, and is counted, so a test
## can check that the sample, or live mode switched off, makes none.
static func new_network_object(type_name: String) -> Object:
	network_objects_created += 1
	return ClassDB.instantiate(type_name)


## Notes a connection's destination for `connecting`, when set. Called
## where each connection is made: `StationHttp` and `LiveSocket`.
static func note_destination(host: String, port: int) -> void:
	if connecting.is_valid():
		connecting.call("%s:%d" % [host, port])


## A normalised error. `kind` is one of ERROR_KINDS; `message` is one line
## for the player and never a response body.
static func make_error(kind: String, message: String) -> Dictionary:
	assert(kind in ERROR_KINDS, "an unknown error kind")
	return {"kind": kind, "message": message}


## Parses a route's JSON body, or null when it is not JSON. Godot reads
## every JSON number as a float; this makes the whole ones ints, so a `seq`,
## a `pid` or a count compares and keys as the integer it is, from either
## source. It parses quietly: `JSON.parse_string` logs a failure, and a
## live body that is not JSON (a proxy's error page) is expected, not a bug.
static func parse_json(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return _whole_numbers_as_ints(json.data)


## Whether `bytes` is text: valid UTF-8 with no NUL, as the node decides
## between sending text and base64. Checked by hand, because decoding bad
## UTF-8 logs an error.
static func is_utf8(bytes: PackedByteArray) -> bool:
	var i := 0
	while i < bytes.size():
		var lead := bytes[i]
		var extra := 0
		if lead == 0:
			return false
		elif lead < 0x80:
			extra = 0
		elif lead >= 0xC2 and lead <= 0xDF:
			extra = 1
		elif lead >= 0xE0 and lead <= 0xEF:
			extra = 2
		elif lead >= 0xF0 and lead <= 0xF4:
			extra = 3
		else:
			return false
		if i + extra >= bytes.size() and extra > 0:
			return false
		for k in range(1, extra + 1):
			if bytes[i + k] & 0xC0 != 0x80:
				return false
		i += extra + 1
	return true


static func _whole_numbers_as_ints(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floorf(value) and absf(value) < 9007199254740992.0:
		return int(value)
	if value is Dictionary:
		for key in value:
			value[key] = _whole_numbers_as_ints(value[key])
	elif value is Array:
		for i in value.size():
			value[i] = _whole_numbers_as_ints(value[i])
	return value


## "Sample" or "Live", for the bezel's badge.
func label() -> String:
	return "Live" if LIVE else "Sample"


## Whether this source is live; see `LIVE`.
@abstract func _is_live() -> bool


## A new call's ID, unique within this source.
func _new_call_id() -> int:
	_next_call_id += 1
	return _next_call_id


# --- Stations (AgentPod) ---

## Lists the player's stations, `GET /api/fleet/agents`. The body is
## `{stats, agents}`, and `stations` carries the agents.
@abstract func list_stations() -> int

## The station's `StationHealth`.
@abstract func health(station_id: String) -> int

## The `FsEntry[]` listing of `path`, relative to the station's workspace.
@abstract func files(station_id: String, path: String) -> int

## Reads one file. The body is `{text, truncated}` for text and
## `{bytes, truncated}` for anything else. `max_bytes` of 0 or less keeps
## the node's own limit.
@abstract func file(station_id: String, path: String, max_bytes: int) -> int

## Starts, stops or restarts the station's agent (`start`, `stop`,
## `restart`). The body is the `StationHealth` after it.
@abstract func lifecycle(station_id: String, action: String) -> int

## The workspace's `ChangesetStatus` against `base`, or the default base
## when `base` is empty.
@abstract func changeset_status(station_id: String, base: String) -> int

## The `ChangesetDiff` of one side (`uncommitted` or `committed`), of one
## file when `path` is not empty.
@abstract func changeset_diff(station_id: String, side: String, path: String) -> int

## Opens the station's log tail.
@abstract func open_logs(station_id: String) -> StationStream.Logs

## Opens the station's shell.
@abstract func open_terminal(station_id: String) -> StationStream.Terminal

## Opens the agent's console session: the player's open one when there is
## one, else a new one in `mode`; always a new one with `new_session` (the
## Chat app's "New session", after ending the one open).
@abstract func open_chat(station_id: String, mode: String, new_session := false) -> StationStream.Chat

## Attaches to the agent's console session without ever starting one, for
## watch mode: the newest of the station's sessions that has not ended
## (`GET /api/stations/:id/acp/sessions`). With none, the stream fails with
## `not_found` ("No session") and closes. It never POSTs a session.
@abstract func watch_chat(station_id: String) -> StationStream.Chat

## Ends a console session for good, as `DELETE /api/acp/sessions/:id` does:
## a waiting permission request is answered as cancelled, the session's
## `state` becomes `ended`, and its chats close. The body is empty. Ending
## one already ended succeeds. The next `open_chat` then opens a new one.
@abstract func end_chat(session_id: String) -> int


# --- Work (Superpipeline) ---

## The player's boards, `{boards: [{id, name}]}`.
@abstract func boards() -> int

## Opens a board's push channel, which starts with its snapshot.
@abstract func board(board_id: String) -> StationStream.Board

## The workspace's agents, `{agents: [...]}`.
@abstract func agents() -> int

## Whether the player may see `station_id`, as far as this source knows
## without asking. The live source says yes only for a station its last
## list held, and no while it does not know (Review Focus 5); a source with
## no stations of the player's own (the sample) has nothing to hide.
func may_see(_station_id: String) -> bool:
	return true

## The Superpipeline agent that works at `station_id` when the source
## already knows it, else "". No route links a station to its agent, so the
## Work app asks the player; a source with its own link (the sample's is
## built in) answers here and spares the question.
func built_in_agent_link(_station_id: String) -> String:
	return ""

## A card's history, `{activities, handoff, gates}`.
@abstract func card_activities(board_id: String, card_id: String) -> int

## Moves a card to another stage. The body is `{card}`.
@abstract func move_card(board_id: String, card_id: String, to_stage: String) -> int

## Resolves a gate: `approve`, `request_changes` or `reject`, with an
## optional comment. The body is `{card}`.
@abstract func resolve_gate(board_id: String, gate_id: String, decision: String, comment: String) -> int

## Answers an agent's question with one of its options, some text, or
## both; an empty one is left out. The body is `{card, elicitation}`.
@abstract func answer(board_id: String, elicitation_id: String, option: String, text: String) -> int
