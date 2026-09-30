## The in-world monitor (interactions spec sections 4 and 5.3): what every
## workstation's screen shows in the city, drawn by the style pack.
##
## - Every desk shows the style's dark "idle" screen, or its "in use" glow
##   while its seat is occupied, as the projection says. That is all any
##   viewer learns of a desk.
## - The player's own desk while seated at its computer, or a desk the
##   player watches from within WATCH_RANGE_M, is the player's own view
##   (`own_desk`). Where the pack can show a feed there (the 3D styles, 256
##   x 160), it shows the computer's own screen: a SubViewport that draws
##   the station computer's canvas, rendered FEED_HZ times a second while
##   the computer is on top of the screens, and at no other time. Where it
##   cannot (pixel art, whose screen is a handful of pixels), it shows the
##   glow.
## - While the station's chat works, that screen pulses: only there, since
##   only the player's own computer knows the chat's status
##   (ComputerScreen.chat_status).
##
## Nothing here leaves the client: the feed is the player's own computer,
## drawn again into a texture on the player's own screen.
extends Node
class_name StationMonitor

const IDLE := "idle"
const IN_USE := "in_use"
const LIVE := "live"
## How often the feed renders, a second.
const FEED_HZ := 10.0
## How far a watcher may stand from the screen and still see it live.
const WATCH_RANGE_M := 4.0
## One rise and fall of the activity pulse, in seconds.
const PULSE_S := 1.0

## The pack drawing the screens.
var pack: StylePack
## The station computer while it is open, else null.
var computer: ComputerScreen
## Where the player stands, metres (null when nowhere): a watcher farther
## than WATCH_RANGE_M from the screen sees no feed.
var viewer_at = null
## The player's own desk while there is one (see live_desk), else "", and
## its feed where the pack can show one there.
var own_desk := ""
var feed: SubViewport
## How many frames the feed was asked to render (the tests count them).
var renders := 0

## Desks whose seats are occupied, as of the last projection.
var _occupied := {}
## The canvas the feed draws: the computer's screen stack's.
var _canvas := RID()
## Time since the feed last rendered, and on the pulse's clock.
var _since := 0.0
var _clock := 0.0


## Whether a desk's screen is fed: always for the player's own (not
## `watching`), and for a watched one only when the viewer stands
## (`viewer`, metres) within WATCH_RANGE_M of its screen (`screen`).
static func feeds(watching: bool, viewer, screen) -> bool:
	if screen == null:
		return false
	if not watching:
		return true
	return viewer is Vector2 and (viewer as Vector2).distance_to(screen) <= WATCH_RANGE_M


## Draws on `pack_` from now on (a new style): the player's own desk
## starts over there, and every screen shows what the last projection
## said.
func set_pack(pack_: StylePack) -> void:
	_end_own()
	pack = pack_
	_show_all()


## Which desks are occupied (a set of seat and placement IDs, as `main`
## reads them from each projection: anyone seated at a workstation or
## using it). The monitor is given only that, never the world.
func occupy(desks: Dictionary) -> void:
	_occupied = desks.duplicate()
	_show_all()


## A frame: the player's own desk begins or ends as the computer and the
## viewer say (a desk whose pack takes no feed is remembered, not asked
## again each frame), its feed renders when due while the computer is on
## top, and it pulses while the chat works.
func advance(delta: float) -> void:
	var desk := live_desk()
	if desk != own_desk:
		_end_own()
		_begin_own(desk)
	if own_desk == "":
		return
	_clock += delta
	if feed != null:
		_since += delta
		var period := 1.0 / FEED_HZ
		# Six sixtieths of a second add up a hair under a tenth.
		if _since + 1e-6 >= period:
			# A long frame renders once, not to catch up.
			_since = _since - period if _since < 2.0 * period else 0.0
			# Covered by a screen of its own (Settings), the computer is
			# not what its screen shows: the feed holds its last frame.
			if computer.stack == null or computer.stack.top() == computer:
				_render()
		pack.show_screen(own_desk, LIVE, feed.get_texture(), pulse())
	else:
		pack.show_screen(own_desk, IN_USE, null, pulse())


## The player's own desk now, or "".
func live_desk() -> String:
	if not is_instance_valid(pack) or not is_instance_valid(computer) or not computer.is_inside_tree():
		return ""
	var id := str(computer.desk.get("target", ""))
	if not pack.screens.has(id) or not feeds(computer.watch, viewer_at, pack.screen_point(id)):
		return ""
	return id


## The activity pulse, 0 to 1: rising and falling once a PULSE_S while the
## chat works, else 0.
func pulse() -> float:
	if not is_instance_valid(computer) or computer.chat_status != "working":
		return 0.0
	return 0.5 - 0.5 * cos(TAU * _clock / PULSE_S)


## What desk `id` shows when it is not the player's own.
func state_of(id: String) -> String:
	return IN_USE if _occupied.has(id) else IDLE


func _show_all() -> void:
	if not is_instance_valid(pack):
		return
	for id in pack.screens:
		if id != own_desk:
			pack.show_screen(id, state_of(id))


## `desk` becomes the player's own: fed where the pack can show a feed
## there (a SubViewport of its size drawing the computer's canvas and
## nothing of its own, rendered only when asked), else glowing.
func _begin_own(desk: String) -> void:
	if desk == "":
		return
	own_desk = desk
	_since = 0.0
	_clock = 0.0
	var size := pack.screen_feed_size(desk)
	if size.x <= 0 or size.y <= 0:
		pack.show_screen(own_desk, IN_USE, null, pulse())
		return
	feed = SubViewport.new()
	feed.name = "Feed"
	feed.size = size
	feed.disable_3d = true
	feed.transparent_bg = false
	feed.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(feed)
	_canvas = computer.get_canvas()
	RenderingServer.viewport_attach_canvas(feed.get_viewport_rid(), _canvas)
	_render()
	pack.show_screen(own_desk, LIVE, feed.get_texture(), pulse())


## Ends the player's own desk: its feed goes, and it shows idle or in use
## again.
func _end_own() -> void:
	if feed != null:
		if _canvas.is_valid():
			RenderingServer.viewport_remove_canvas(feed.get_viewport_rid(), _canvas)
		feed.free()
		feed = null
	_canvas = RID()
	var desk := own_desk
	own_desk = ""
	if desk != "" and is_instance_valid(pack):
		pack.show_screen(desk, state_of(desk))


## One frame of the feed: the computer's screen fitted to it, drawn once.
func _render() -> void:
	var panel: Control = computer.screen_panel
	if panel != null:
		var rect := panel.get_global_rect()
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			var scale := Vector2(feed.size) / rect.size
			RenderingServer.viewport_set_canvas_transform(feed.get_viewport_rid(), _canvas,
				Transform2D(0.0, scale, 0.0, -rect.position * scale))
	feed.render_target_update_mode = SubViewport.UPDATE_ONCE
	renders += 1


func _exit_tree() -> void:
	_end_own()
