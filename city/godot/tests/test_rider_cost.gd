## The rule for hiding a tram's riders (Pack3D.riders_seen): they are
## drawn only where they could be seen. The costs they are spared aboard
## (shadows, animation, the near body far off) are tested with the trams in
## test_vehicles.gd.
extends TestSuite


## Whether a tram's riders could be seen: always with its roof faded,
## otherwise near enough to see in anyhow, or through its side windows from
## a view that is not looking down on its roof, and not so far off that
## they would be specks.
func test_riders_are_seen_with_the_roof_faded_near_or_through_the_windows() -> void:
	assert_true(Pack3D.riders_seen(0.0, 80.0, 89.0), "the roof faded: seen from anywhere")
	assert_true(Pack3D.riders_seen(0.5, 80.0, 89.0), "the roof fading: seen")
	assert_true(Pack3D.riders_seen(1.0, 20.0, 89.0), "near: seen")
	assert_true(Pack3D.riders_seen(1.0, 66.0, 36.0), "the diagonal view: seen through the windows")
	assert_true(not Pack3D.riders_seen(1.0, 90.0, 85.0), "looking down on the roof from afar: hidden")
	assert_true(not Pack3D.riders_seen(1.0, 200.0, 20.0), "specks far off: hidden")
	assert_eq(Pack3D.RIDER_SEEN_M, 45.0, "as far as the roof cuts away overhead")
