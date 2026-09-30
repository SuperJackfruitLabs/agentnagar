## Interaction orchestration, owned by main.gd (interactions spec section
## 2): what the player acts on and how (see Interact, which owns
## targeting and the verbs themselves), the overlay it opens (Inspect or
## Read), and the read that follows a walk to its anchor.
##
## main.gd wires this once, from boot (see setup), then calls `frame`
## once a visual frame and reads `target` and `prompt`: Part A's final
## review found current_target() run twice a frame, once through choice()
## and once for the surface in focus, rebuilding the person list and
## walking the ray each time in first person. `choice()` and
## `current_target()` stay ordinary, always-fresh calls (tests, and the
## HUD's own direct refresh, call them straight); `frame()` is the one
## call site main.gd's own per-frame readers (the prompt, the surface's
## target) share, so a `_process()` that calls it once pays for the walk
## once, however many of those readers ask afterwards.
extends RefCounted
class_name InteractionController

## Fired once the core confirms a `Use` whose capability is neither `sit`
## nor `read` (a workstation's desk, from Task 5 on): the target now in
## use (see Interact.in_use), and its capability.
signal use_began(target: Dictionary, capability: String)
## Fired when the using use_began announced has ended: the player stood
## up, switched to sitting, or the core released or moved it. The target
## is the one use_began carried. main.gd closes the station computer on it.
signal use_ended(target: Dictionary)
## Fired when the player chooses "Look at screen" behind a workstation
## someone sits at (see Interact.candidate_of): the target, at its stand
## anchor. Nothing is sent to the core; main.gd opens watch mode from it.
signal watch_requested(target: Dictionary)

## Wired once, from main.gd's boot (see setup); never reassigned after,
## since none of these are themselves replaced once the city is running.
var host: StyleHost
var nav: NavQuery
var interact: Interact
var stack: ScreenStack
var driver: WorldDriver
var manifest: Dictionary
var trams: TramTimes
## Bound to main.gd's tram_prompt(): the tram's own state (the timetable,
## the vehicle under the player) stays main.gd's, since it owns `trams`
## and the rest of "the tram" section.
var tram_prompt_fn: Callable
## Bound to main.gd's _capture_mouse(): opening an overlay in first
## person lets go of the mouse, a concern wider than interaction.
var capture_mouse_fn: Callable
## Bound to main.gd's _may_watch(target): whether the player's station
## source lets it look at that desk's screen. "Look at screen" is offered
## only where it says so (Review Focus 5); unset, wherever Interact offers
## it.
var watch_gate: Callable

## The player this frame; main.gd hands it over each call to `frame`
## (Quit to title replaces it with a new one) and keeps it synced
## directly at that point too, so anything reached from a projection
## landing outside `frame` (see main.gd's _observe) never sees a stale
## or unset player.
var player := Player.new()

## This call's target and prompt (see current_target, choice), set by
## `frame` for main.gd's own per-frame readers to share.
var target: Dictionary = {}
var prompt: Dictionary = {}

## How many times current_target's own computation has run; a test hook
## for the once-a-frame guarantee above (nothing else reads this).
var target_calc_calls := 0

## The read the player asked for, until the core has it reading (the
## overlay then opens) or refuses; {} for none.
var _awaited_read := {}
## The overlay open now (Inspect or Read), else null or freed.
var _panel: PanelScreen
## The overlay opened for the reading the core confirmed: it closes when
## that reading ends. Else null or freed.
var _reading_panel: PanelScreen
## The using the player was last observed in, as "target|capability", for
## use_began's edge (fired only on a change to a new one outside sit and
## read); "" for none.
var _using_key := ""
## The target use_began last announced, until use_ended; {} for none.
var _began := {}
## The desk whose computer the player left while the core may still have
## it using that desk (its StopUsing refused, say): until the using ends,
## "Use computer" is offered there again and reopens the computer. ""
## for none.
var _reopen := ""


## Wires the controller to main.gd's collaborators, once, from boot().
func setup(host_: StyleHost, nav_: NavQuery, interact_: Interact, stack_: ScreenStack,
		driver_: WorldDriver, manifest_: Dictionary, trams_: TramTimes,
		tram_prompt_fn_: Callable, capture_mouse_fn_: Callable) -> void:
	host = host_
	nav = nav_
	interact = interact_
	stack = stack_
	driver = driver_
	manifest = manifest_
	trams = trams_
	tram_prompt_fn = tram_prompt_fn_
	capture_mouse_fn = capture_mouse_fn_


## Once a visual frame, from main.gd's _process: `player` for this call
## (see the field above), then the prompt (see choice), computed fresh,
## with `target` read back out of it (choice's own "seen") rather than
## asking current_target() a second time. Fires use_began when the core
## has newly confirmed a using outside sit and read.
func frame(_delta: float, view_state: Dictionary) -> void:
	player = view_state.get("player", player)
	prompt = choice()
	target = prompt.get("seen", {})
	_check_use_began()


# ---- Targeting and the prompt (see Interact) ----

## What the player acts on besides the tram: what it uses now; else in
## first person what the crosshair rests on; else the target ahead within
## reach (Interact.targets); {} for nothing. Always freshly computed.
func current_target() -> Dictionary:
	target_calc_calls += 1
	var using = player.view.get("using")
	if not using is Dictionary and player.view.get("seat") != null:
		using = {"target": player.view["seat"], "capability": "sit", "anchor": -1}
	if using is Dictionary:
		var in_use := interact.in_use(using)
		if _reopen != "" and in_use["target"] == _reopen and in_use.get("using") == "use":
			in_use["reopen"] = true
		return in_use
	if host.first_person:
		var hit := fpv_target()
		return {} if hit["type"] == "none" else _gate_watch(hit)
	var ahead := interact.targets({"view": "overhead", "at": nav.centre(player.cell), "facing": _facing_now()})
	return _gate_watch(ahead[0]) if not ahead.is_empty() else {}


## What a tap at `ground` (cm) acts on (see Interact.targets' touch), {}
## for nothing: gated as the prompt's target is, so a tap offers "Look at
## screen" only where the prompt would.
func tap_target(ground: Vector2) -> Dictionary:
	var tapped := interact.targets({"view": "touch", "tap": ground})
	return _gate_watch(tapped[0]) if not tapped.is_empty() else {}


## `target` without "Look at screen" where watch_gate refuses it: Interact
## offers it behind any occupied desk, but only the player's station
## source knows whether the player may see that screen.
func _gate_watch(target: Dictionary) -> Dictionary:
	var capabilities: Array = target.get("capabilities", [])
	if capabilities.has("watch") and watch_gate.is_valid() and not watch_gate.call(target):
		capabilities.erase("watch")
	return target


## current_target(), guarded as choice() has always guarded it: {} while
## waiting or with no player or catalogue yet.
func _computed_target() -> Dictionary:
	if player.present and not player.waiting and interact != null:
		return current_target()
	return {}


## The way the player faces on the ground: the way it walks, else the way
## the core has it face.
func _facing_now() -> Vector2:
	if player.heading != Vector2.ZERO:
		return player.heading
	var facing := deg_to_rad(float(player.view.get("facing", 0)))
	return Vector2(sin(facing), -cos(facing))


## What the crosshair rests on, as a target (see Interact.targets): a
## placement or seat within reach, a building, the ground or a person;
## {"type": "none"} for nothing.
func fpv_target() -> Dictionary:
	if host.pack == null or host.pack.fpv == null or interact == null:
		return {"type": "none"}
	var people := []
	for id in host.pack.nodes:
		if id != player.id and host.pack.nodes[id] is Node3D:
			var n: Node3D = host.pack.nodes[id]
			var at := n.global_position if n.is_inside_tree() else n.position
			people.append({"id": id, "pos": Vector2(at.x, at.z)})
	var hit := interact.targets({"view": "first_person", "camera": host.pack.fpv, "people": people})
	return hit[0] if not hit.is_empty() else {"type": "none"}


## What A does now, as the prompt says it: {text, action ("interact", or
## "" when the prompt only says what is happening), more (the target has
## other verbs), seen (what the player faces: the crosshair's rest in
## first person, else the target ahead; {} for nothing)}, with either
## `target` and `verb` (which of its verbs is shown), or `tram` (see
## main.gd's tram_prompt), and for a tram to board, `target` the tram.
## - Something the player uses, or can use, comes first, as a seat did;
## - else the tram's prompt, when _tram_first says so;
## - else the target's verb (Inspect, Go in, Walk here);
## - else the tram's prompt, if any.
## Always freshly computed (see current_target); `frame()` calls it once
## a visual frame and caches the result as `prompt` and `target`.
func choice() -> Dictionary:
	var tram: Dictionary = tram_prompt_fn.call() if tram_prompt_fn.is_valid() else {}
	return _build_choice(_computed_target(), tram)


func _build_choice(for_target: Dictionary, tram: Dictionary) -> Dictionary:
	var out := {"text": "", "seen": for_target}
	var verbs: Array = [] if interact == null else interact.verbs(for_target)
	if not verbs.is_empty() and not _tram_first(tram, for_target):
		var i := interact.shown_verb(for_target)
		out.merge({"text": interact.prompt_text(for_target, verbs[i]), "action": "interact", "more": verbs.size() > 1,
			"target": for_target, "verb": i}, true)
		return out
	if tram.is_empty():
		return out
	out.merge({"text": tram["text"], "action": "interact" if tram["act"] != "" else "", "tram": tram}, true)
	if tram["act"] == "board":
		out["target"] = _tram_target()
	return out


## The tram to board from the platform the player stands on, as a target
## of Interact's shape: its line, boarded at the tram kind's enter anchor.
func _tram_target() -> Dictionary:
	var at := trams.platform(nav.room_at(player.cell))
	return {"type": "tram", "target": str(at.get("line", "")), "kind": "tram", "anchor": 0,
		"capabilities": ["board"], "pos": player.shown}


## Whether the tram's prompt `tram` is what A does, over `target`:
## something the player uses or can use comes first (as a seat's action
## always did), except that a tram standing with its doors open ("Board")
## outranks a passive use, under way or offered: sitting on a perch (a
## shelter's bench) or reading. Boarding ends it, and the tram leaves
## while the bench stays. A room seat keeps Stand up first (seated, no
## tram is offered). Otherwise aboard, waiting, or with a tram's doors
## open, always; "Wait for the tram" only while the target is not a
## building or ground off the platform, where A goes instead.
func _tram_first(tram: Dictionary, target: Dictionary) -> bool:
	if tram.is_empty():
		return false
	var doors_open: bool = tram["act"] == "board" and tram["text"] != "Wait for the tram"
	if doors_open and _passive(target):
		return true
	if target.get("type") in ["placement", "seat"] and (target.has("using") or Interact.usable(target)):
		return false
	if tram["text"] != "Wait for the tram":
		return true
	match str(target.get("type")):
		"building":
			return false
		"ground":
			return nav.room_at(nav.cell_of(target["pos"])) == nav.room_at(player.cell)
	return true


## Whether `target` is a passive use of a placement, under way or offered
## first: sitting on a perch (a room seat is a "seat") or reading.
static func _passive(target: Dictionary) -> bool:
	if target.get("type") != "placement":
		return false
	if target.has("using"):
		return target["using"] in ["sit", "read"]
	return Interact.usable(target) and target["capabilities"][0] in ["sit", "read"]


## Where in play's own per-frame flow main.gd's surfaces read the target
## in focus (see main.gd's update_surfaces call): the cache `frame()` set,
## not a fresh current_target() call.
func _surface_target() -> String:
	return str(target.get("target", ""))


# ---- Acting (see Interact.action) ----

## Does `target`'s verb `verb`: a walk, standing up or stopping, the
## overlay, looking at a screen (watch_requested), or a Use, after a Go to
## the anchor when it is out of reach.
## Reading opens the overlay once the core confirms it (see
## _follow_reading); reading what the player already reads opens it again
## with nothing sent.
func _act(target: Dictionary, verb: int) -> void:
	var act := interact.action(target, verb, player.cell)
	_awaited_read = {}
	match act.get("do"):
		"walk":
			player.go_point(act["pos"])
		"stop":
			player.stop_using()
		"inspect":
			_open_panel(target)
		"watch":
			watch_requested.emit(target)
		"use":
			var use: Dictionary = act["use"]
			if target.get("reopen", false) and use["capability"] == target.get("using"):
				# The core has the player using it still: nothing to send.
				_reopen = ""
				_began = target
				use_began.emit(target, "use")
				return
			if act["overlay"] and target.get("using") == "read":
				_reading_panel = _open_panel(target, true)
			elif act["go"] != null:
				var thing: Dictionary = target["thing"]
				var anchor := int(use["anchor"])
				player.go_then_use(act["go"], use, func(c: Vector2i) -> bool: return interact.at_anchor(thing, anchor, c))
			else:
				player.use(use["target"], use["capability"], int(use["anchor"]))
				if act["overlay"]:
					_awaited_read = target


## A Use sent as the walk to its anchor ended: a read waits for the core.
## Connected to the player's `used` signal from main.gd's _join.
func on_used(use: Dictionary) -> void:
	if use.get("capability") == "read" and interact != null:
		_awaited_read = interact.in_use(use)


## Each projection: the overlay opens once the core has the player reading
## what it asked to read, and the overlay of a reading closes once the
## player reads it no longer (it stepped away, stopped, or was moved).
## Called from main.gd's _observe.
func _follow_reading() -> void:
	var using = player.view.get("using")
	var reading := str(using.get("target", "")) if using is Dictionary and using.get("capability") == "read" else ""
	if not _awaited_read.is_empty() and reading == str(_awaited_read["target"]):
		var to_open := _awaited_read
		_awaited_read = {}
		_reading_panel = _open_panel(to_open, true)
	elif is_instance_valid(_reading_panel) and stack.screens.has(_reading_panel) and reading != _reading_panel.target:
		stack.remove(_reading_panel)
		_reading_panel = null


## A read's Use the core refused never opens its overlay. Called from
## main.gd's _notice_events on a refused Use.
func clear_awaited_read() -> void:
	_awaited_read = {}


## Opens the overlay on `target` (see Interact), read or inspected: its
## kind, and the panel its placement shows when it is bound to one.
func _open_panel(target: Dictionary, reading := false) -> PanelScreen:
	var id := str(target["target"])
	if host.first_person:
		capture_mouse_fn.call(false)
	var screen := PanelScreen.new()
	stack.push(screen)
	var panel := panel_of(id) if target.get("type") == "placement" else {}
	screen.open(id, panel, StylePack.kinds().get(target["kind"], {}), reading, source_of(id))
	_panel = screen
	return screen


## Whether the overlay `_open_panel` opened is still on top.
func _panel_open() -> bool:
	return is_instance_valid(_panel) and stack.screens.has(_panel)


## The panel placement `id` shows (see city-contracts Panel), or {} when it
## is bound to none (or the bridge cannot serve it).
func panel_of(id: String) -> Dictionary:
	if driver.world == null:
		return {}
	var shown = JSON.parse_string(driver.world.panel_json(id))
	return shown if shown is Dictionary and not shown.has("error") else {}


## Where placement `id`'s content comes from (its binding's source), or ""
## for one bound to none.
func source_of(id: String) -> String:
	for d in manifest.get("city", {}).get("districts", []):
		for p in d.get("placements", []):
			if p["id"] == id and p.get("binding") is Dictionary:
				return str(p["binding"].get("source", ""))
	return ""


## The displays, each with the panel it shows (see Surfaces.of_layout).
func displays() -> Array:
	var out: Array = Surfaces.of_layout(manifest, StylePack.kinds())
	for s in out:
		s["panel"] = panel_of(s["id"])
	return out


## Fires use_began the moment the core confirms a using whose capability
## is neither sit nor read (a workstation's): the target in use, and its
## capability. Only on the transition into a new one, not every call while
## it holds. When that using changes or ends, whoever ended it, fires
## use_ended first.
func _check_use_began() -> void:
	var using = player.view.get("using")
	var key := ""
	if using is Dictionary:
		key = "%s|%s" % [str(using.get("target", "")), str(using.get("capability", ""))]
	if key == _using_key:
		return
	_reopen = ""
	if not _began.is_empty():
		var ended := _began
		_began = {}
		use_ended.emit(ended)
	if using is Dictionary:
		var capability := str(using.get("capability", ""))
		if capability != "sit" and capability != "read":
			_began = interact.in_use(using)
			use_began.emit(_began, capability)
	_using_key = key


## The desk `target` is, for the station computer: {target, kind,
## binding}. A placed workstation carries its placement's binding; a room
## seat has none in the layout (the manifest's seats carry no binding), so
## it is a hot desk.
func desk_of(target: Dictionary) -> Dictionary:
	var id := str(target.get("target", ""))
	var binding := {}
	if target.get("type") == "placement":
		for d in manifest.get("city", {}).get("districts", []):
			for p in d.get("placements", []):
				if p["id"] == id and p.get("binding") is Dictionary:
					binding = p["binding"]
	return {"target": id, "kind": str(target.get("kind", "")), "binding": binding}


## After the player left the computer at desk `target`: should the core
## keep it using the desk (a StopUsing refused, or never sent), "Use
## computer" reopens the computer there, so the player is never left
## seated at a desk with no way back to its screen. The offer ends with
## the using.
func offer_reopen(target: String) -> void:
	_reopen = target
	_began = {}


## Whether an agent sits at, or uses, `target` in `projection`: where
## "Look at screen" opens Sample station (the amendment "Watch mode in
## sample mode").
static func agent_sits_at(projection: Dictionary, target: String) -> bool:
	return StylePack.occupant_key(occupant_at(projection, target)).ends_with("Agent")


## Who sits at, or uses, `target` in `projection` (their view), or {}:
## once sat there, not while walking to it (Player.users_by_target).
static func occupant_at(projection: Dictionary, target: String) -> Dictionary:
	return Player.users_by_target(projection).get(target, {})
