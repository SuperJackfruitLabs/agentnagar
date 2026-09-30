## The frame-time benchmark's scenes and arithmetic. Scenes are measured
## by tools/bench.gd (scripts/bench.sh) fullscreen at the display's native
## resolution, uncapped and then with vsync; a run at any other size fails
## (`size_breach`). A style that declares a "budget" in its style.json is
## gated on each scene (see `breaches`).
extends RefCounted
class_name Bench

## Normal play (the three overhead presets and first person, a crowd of 60,
## by day), the same with a screen open over it (the game menu over the
## diagonal view, the title with its drifting camera, and the map), and the
## heaviest scene (street view at night in rain, a crowd of 300). `tick`
## sets the district clock: 150 is 13:00, 330 is 20:12 in rain. `screen`,
## where given, is the screen open while the scene is sampled: "menu",
## "title" or "map". The tram scene (tram spec section 1, criterion 4) is
## the diagonal view at 13:38 with two trams in the district carrying
## `riders` each: TRAM_LOAD's riders ride in on them, and the scene starts
## once the second has entered (see TRAM_LOAD). Its `centre` (cm) moves the
## diagonal view, at the same angle and distance, to the middle of the
## boulevard, where both trams run in sight (see `aim`). It boots its own
## world in each style, since the others share one that the bench runs on.
const SCENES := [
	{"name": "topdown", "view": "topdown", "crowd": 60, "tick": 150, "heavy": false},
	{"name": "diagonal", "view": "diagonal", "crowd": 60, "tick": 150, "heavy": false},
	{"name": "street", "view": "street", "crowd": 60, "tick": 150, "heavy": false},
	{"name": "fpv", "view": "fpv", "crowd": 60, "tick": 150, "heavy": false},
	{"name": "menu", "view": "diagonal", "crowd": 60, "tick": 150, "heavy": false, "screen": "menu"},
	{"name": "title", "view": "diagonal", "crowd": 60, "tick": 150, "heavy": false, "screen": "title"},
	{"name": "map", "view": "diagonal", "crowd": 60, "tick": 150, "heavy": false, "screen": "map"},
	{"name": "tram", "view": "diagonal", "crowd": 60, "tick": 166, "heavy": false, "trams": 2, "riders": 40, "centre": Vector2(3500, 2050)},
	{"name": "street-night-rain-300", "view": "street", "crowd": 300, "tick": 330, "heavy": true},
]
## The tram scene's riders: `riders` public citizens arriving at tick `at`,
## bound for `rooms` in turn, just after the westbound tram of 136 has
## entered. Arrivals take turns at the two portals, so half ride in on the
## eastbound tram entering at tick 151 and half on the westbound one
## entering at 166. Those bound for the Avenue (east of the Square) ride
## the eastbound tram past the Square to the Avenue, where it stands at
## tick 176; those bound for the south lane ride the westbound one past
## the Avenue to the Square, at tick 189. From 166, when the westbound tram
## is in, to 175 both carry 40 (a slot the district's own arrivals take is
## still a rider). Which half goes which way depends on how many arrivals
## came before, so `tram_feed` tries the rooms in both orders and keeps the
## one that fills both trams.
const TRAM_LOAD := {"at": 137, "riders": 80, "rooms": ["room:avenue", "room:south-lane"]}
## How long each scene is sampled, and warmed up first.
const SAMPLE_S := 5.0
const WARMUP_FRAMES := 90
## The longest frame opening the map may take once it has been opened in
## the style before (map spec section 1).
const REOPEN_MAX_MS := 50.0


## Why a scene rendered at `rendered` does not count, or "" when it is the
## display's `native` size: a smaller window is a smaller picture, and
## measures a cheaper frame than players see.
static func size_breach(rendered: Vector2i, native: Vector2i) -> String:
	if rendered == native:
		return ""
	return "rendered %dx%d, not the display's native %dx%d" % [rendered.x, rendered.y, native.x, native.y]


## The nearest-rank `p`th percentile of `samples`.
static func percentile(samples: Array, p: float) -> float:
	if samples.is_empty():
		return 0.0
	var sorted := samples.duplicate()
	sorted.sort()
	var rank := int(ceil(p / 100.0 * sorted.size()))
	return float(sorted[clampi(rank - 1, 0, sorted.size() - 1)])


## One scene's result from its frame times in milliseconds.
static func summary(style: String, scene: String, frames_ms: Array) -> Dictionary:
	return {"style": style, "scene": scene, "frames": frames_ms.size(),
		"p50": percentile(frames_ms, 50.0), "p99": percentile(frames_ms, 99.0),
		"max": frames_ms.max() if not frames_ms.is_empty() else 0.0}


## The frames per second a style can be asked for on a `hz` display:
## `wanted`, or within 1% of the display's rate where that is lower.
static func target_fps(wanted: float, hz: float) -> float:
	return minf(float(wanted), hz * 0.99)


## The results over their style's budget: [{style, scene, ..., budget}].
## A budget in frame rates ({"normal_fps", "heavy_fps", "missed_pct"}) is
## what a player sees, measured with vsync at the display's rate: the
## scene's frames per second (heavy scenes' floor, normal play's target)
## and, in normal play, the share of refreshes missed. With a `baseline`
## (an empty scene's {fps, missed_pct} on the same display), normal play is
## held to what the display gives it: within 3% of its frames per second
## and at most `missed_pct` points more of its refreshes missed. A budget
## in frame times ({"normal_ms", "heavy_ms"}) gates the uncapped 99th
## percentile.
static func breaches(results: Array, budgets: Dictionary, baseline := {}) -> Array:
	var out := []
	for r in results:
		var b = budgets.get(r["style"])
		if b == null:
			continue
		var heavy: bool = r.get("heavy", false)
		if b.has("normal_fps"):
			var want := target_fps(float(b["heavy_fps"] if heavy else b["normal_fps"]), float(r.get("hz", 60.0)))
			var allowed_missed := float(b.get("missed_pct", 1.0))
			if not heavy and not baseline.is_empty():
				want = minf(want, float(baseline["fps"]) * 0.97)
				allowed_missed += float(baseline["missed_pct"])
			if float(r.get("fps", 0.0)) < want:
				out.append({"style": r["style"], "scene": r["scene"], "fps": r.get("fps", 0.0), "budget": want})
			elif not heavy and float(r.get("missed_pct", 0.0)) > allowed_missed:
				out.append({"style": r["style"], "scene": r["scene"], "missed_pct": r["missed_pct"], "budget": allowed_missed})
			continue
		var limit: float = float(b["heavy_ms"] if heavy else b["normal_ms"])
		if float(r["p99"]) > limit:
			out.append({"style": r["style"], "scene": r["scene"], "p99": r["p99"], "budget": limit})
	return out


## The map scenes whose second opening took a frame over REOPEN_MAX_MS:
## [{style, scene, reopen_worst_ms, budget}]. Every style is held to it,
## with a budget or without; the first opening is reported, not gated.
static func reopen_breaches(results: Array) -> Array:
	var out := []
	for r in results:
		if r.has("reopen_worst_ms") and float(r["reopen_worst_ms"]) > REOPEN_MAX_MS:
			out.append({"style": r["style"], "scene": r["scene"], "reopen_worst_ms": r["reopen_worst_ms"], "budget": REOPEN_MAX_MS})
	return out


## Moves `pack`'s view, in its scene's preset, so that the middle of the
## screen lies over the scene's `centre` (cm), where it has one.
static func aim(pack, scene: Dictionary) -> void:
	if not scene.has("centre") or pack == null or not pack.is_inside_tree():
		return
	var middle = pack.ground_at(pack.get_viewport().get_visible_rect().get_center())
	if middle != null:
		pack.shift_view(scene["centre"] - middle)


## Feed entries for `count` public citizens arriving at tick `at`, bound
## for `rooms` in turn: the tram scene's riders. They are numbered from
## `first`, so a second load's riders are new occupants.
static func rider_entries(at: int, count: int, rooms: Array, first := 0) -> Array:
	var out := []
	for i in count:
		var k := first + i
		var id := "bench:rider:%02d" % k
		out.append({"at": at, "fixture": true, "record": "entry", "command": {"type": "Arrive",
			"occupant": id, "room": rooms[i % rooms.size()],
			"profile": {"id": id, "kind": {"type": "SimCitizen"}, "display_name": "Rider %d" % (k + 1),
				"appearance": {"palette": str(k % 8), "hair": str(k % 4)}}}})
	return out


## `feed_jsonl` with `entries` joined in tick order: the header first, then
## every entry by its tick, the feed's own before `entries` at the same
## tick and each in its own order (a feed's ticks never go back).
static func with_entries(feed_jsonl: String, entries: Array) -> String:
	var header := ""
	var all := []
	for line in feed_jsonl.split("\n", false):
		if line.strip_edges() == "":
			continue
		var record = JSON.parse_string(line)
		if record is Dictionary and record.get("record") == "header":
			header = line
		elif record is Dictionary:
			all.append([int(record.get("at", 0)), all.size(), line])
	for e in entries:
		all.append([int(e.get("at", 0)), all.size(), JSON.stringify(e)])
	all.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var lines := [header] if header != "" else []
	for a in all:
		lines.append(a[2])
	return "\n".join(lines) + "\n"


## How many riders a projection shows aboard each vehicle, by vehicle ID.
static func riders_aboard(projection: Dictionary) -> Dictionary:
	var out := {}
	for r in projection.get("aboard", []):
		var v := str(r.get("vehicle", ""))
		out[v] = int(out.get(v, 0)) + 1
	return out


## How many vehicles a projection shows carrying at least `riders`.
static func full_trams(projection: Dictionary, riders: int) -> int:
	return riders_aboard(projection).values().filter(func(n): return n >= riders).size()


## The district feed with the tram scene's riders (TRAM_LOAD) joined in,
## their rooms in whichever order fills the scene's trams at its tick in a
## world built from `manifest_json`, `feed_jsonl`, `seed` and a crowd of
## `crowd`, tried on a world of its own; the first order when neither
## does (the bench reports what it got), and "" without the extension.
static func tram_feed(manifest_json: String, feed_jsonl: String, seed: int, crowd: int) -> String:
	if not ClassDB.class_exists("CityWorld"):
		return ""
	var scene := {}
	for s in SCENES:
		if s["name"] == "tram":
			scene = s
	var rooms: Array = TRAM_LOAD["rooms"]
	var orders := [rooms, rooms.duplicate()]
	orders[1].reverse()
	for order in orders:
		var feed := with_entries(feed_jsonl, rider_entries(int(TRAM_LOAD["at"]), int(TRAM_LOAD["riders"]), order))
		var world = ClassDB.instantiate("CityWorld")
		var loaded = JSON.parse_string(world.load(manifest_json, feed, seed, crowd))
		if not (loaded is Dictionary and loaded.get("ok", false)):
			continue
		while world.tick() < int(scene["tick"]):
			world.step()
		var p = JSON.parse_string(world.project_json("public"))
		if p is Dictionary and full_trams(p, int(scene["riders"])) >= int(scene["trams"]):
			return feed
	return with_entries(feed_jsonl, rider_entries(int(TRAM_LOAD["at"]), int(TRAM_LOAD["riders"]), rooms))
