## Buildings open when you are inside, when the selected person is inside,
## when the camera is inside (with hysteresis), or when "open all" is on.
extends TestSuite

var facilities := {
	"facility:hall": {"rooms": ["room:workshop", "room:commons"], "rects": [Rect2(-3400, -1400, 1600, 2400)]},
	"facility:library": {"rooms": ["room:reading"], "rects": [Rect2(1800, -1200, 1800, 2000)]},
}
const FAR := Vector2(0, 0)


func test_closed_by_default() -> void:
	var r := CutawayRule.new()
	assert_eq(r.update(null, null, FAR, false, facilities), {}, "nothing open")


func test_open_when_the_avatar_or_selection_is_inside() -> void:
	var r := CutawayRule.new()
	assert_eq(r.update("room:commons", null, FAR, false, facilities), {"facility:hall": true}, "avatar inside")
	assert_eq(r.update(null, "room:reading", FAR, false, facilities), {"facility:library": true}, "selected inside")
	assert_eq(r.update("room:plaza", "room:park", FAR, false, facilities), {}, "outdoors opens nothing")


func test_open_all() -> void:
	var r := CutawayRule.new()
	assert_eq(r.update(null, null, FAR, true, facilities), {"facility:hall": true, "facility:library": true}, "all")


func test_camera_inside_with_hysteresis() -> void:
	var r := CutawayRule.new()
	var edge := Vector2(1800, 0)
	assert_eq(r.update(null, null, edge + Vector2(10, 0), false, facilities), {"facility:library": true}, "inside")
	for jitter in [-10.0, 10.0, -10.0, 10.0, -100.0]:
		assert_eq(r.update(null, null, edge + Vector2(jitter, 0), false, facilities), {"facility:library": true},
			"stays open across the edge (%s)" % jitter)
	assert_eq(r.update(null, null, edge + Vector2(-200, 0), false, facilities), {}, "closes beyond 150 cm")
	assert_eq(r.update(null, null, edge + Vector2(-100, 0), false, facilities), {}, "stays closed outside")


func test_no_camera_position_means_no_camera_rule() -> void:
	var r := CutawayRule.new()
	assert_eq(r.update(null, null, null, false, facilities), {}, "a 2D pack reports no camera position")


func test_facilities_come_from_buildings_only() -> void:
	var m: Dictionary = JSON.parse_string(CityPaths.district_manifest())
	var f := CutawayRule.facilities_of(m)
	var ids := f.keys()
	ids.sort()
	assert_eq(ids, ["facility:guild-hall", "facility:library"], "only facilities with a building kind")
	assert_eq(f["facility:guild-hall"]["rooms"], ["room:workshop", "room:commons"], "rooms listed")
