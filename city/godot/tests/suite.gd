## Base class for test suites: small assertions that report to the runner.
extends RefCounted
class_name TestSuite

var runner


## How long the bench machine (the laptop the timing budgets were set on)
## takes over `machine_work_us`, in microseconds, fastest of its runs.
const BENCH_MACHINE_WORK_US := 1420.0

## The machine factor, measured once a run.
static var _machine_factor := -1.0


## How much slower than the bench machine this machine runs a fixed piece
## of GDScript work, and never less than 1: a timing test multiplies its
## budget, set on the bench machine, by this, so a slower machine (a shared
## CI runner) is held to the same code, not the same clock.
static func machine_factor() -> float:
	if _machine_factor < 0.0:
		_machine_factor = maxf(1.0, machine_work_us() / BENCH_MACHINE_WORK_US)
	return _machine_factor


## A fixed piece of GDScript work of the kind the timed code does (vector
## arithmetic, distances, packed-array writes), timed here: the fastest of
## five runs, in microseconds.
static func machine_work_us() -> float:
	var best := INF
	var out := PackedFloat32Array()
	out.resize(1024)
	for run in 5:
		var t0 := Time.get_ticks_usec()
		var p := Vector2(0.5, 0.25)
		for i in 20000:
			var q := Vector2(float(i % 97) * 0.1, float(i % 89) * 0.1)
			var d := p.distance_squared_to(q)
			if d < 25.0:
				p = p.lerp(q, 0.01)
			out[i & 1023] = d
		best = minf(best, float(Time.get_ticks_usec() - t0))
	return best


func assert_true(cond: bool, message := "expected true") -> void:
	runner.asserted += 1
	if not cond:
		runner.fail(message)


func assert_eq(a, b, message := "") -> void:
	runner.asserted += 1
	if a != b:
		runner.fail("%s: %s != %s" % [message, str(a), str(b)])


## Whether any tram's body lies within one tram length of the district's
## Square stop, either side, in `world`: standing there, or running in or
## out. The district's arrivals step off there among the tram's other
## riders, beside its tracks; tests that start from a player's arrival
## step on until none is (the client does not see trams yet). Lengths and
## stops come from the layout's lines, positions from the public view.
static func tram_by_the_square(world) -> bool:
	var lines := {}
	for l in JSON.parse_string(world.layout_json()).get("lines", []):
		lines[l["id"]] = l
	var p = JSON.parse_string(world.project_json("public"))
	for v in p.get("vehicles", []):
		var line: Dictionary = lines[v["line"]]
		var length := float(line["vehicle"]["length"])
		var front := float(v["along"])
		# An eastbound tram's body trails west of its front, a westbound's east.
		var back := front - length if v["direction"] == "east" else front + length
		for stop in line["stops"]:
			if stop["id"] != "stop:square":
				continue
			var at := float(stop["at"])
			if maxf(front, back) > at - length and minf(front, back) < at + length:
				return true
	return false
