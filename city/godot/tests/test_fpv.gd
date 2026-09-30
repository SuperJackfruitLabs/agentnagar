## The first-person camera: eye height on the avatar, clamped pitch, free
## yaw, and a crosshair that resolves to a seat, a building or the ground.
extends TestSuite


func test_the_eye_follows_the_avatar_at_eye_height() -> void:
	var cam := FpvCamera.new()
	cam.follow(Vector2(3, -4))
	assert_eq(cam.position, Vector3(3, FpvCamera.EYE_HEIGHT, -4), "eye 160 cm over the avatar")
	cam.free()


func test_pitch_is_clamped_and_yaw_is_free() -> void:
	var cam := FpvCamera.new()
	cam.look(0.0, 200.0)
	assert_eq(cam.pitch, 80.0, "no looking past straight up")
	cam.look(0.0, -500.0)
	assert_eq(cam.pitch, -80.0, "nor past straight down")
	cam.look(725.0, 0.0)
	assert_true(absf(cam.yaw - 5.0) < 0.001, "yaw wraps: %f" % cam.yaw)
	cam.free()


func test_forward_follows_the_view_on_the_ground() -> void:
	var cam := FpvCamera.new()
	assert_true(cam.forward().distance_to(Vector2(0, -1)) < 0.001, "starts looking north")
	cam.look(90.0, -30.0)
	assert_true(cam.forward().distance_to(Vector2(-1, 0)) < 0.001, "a quarter turn left looks west: %s" % cam.forward())
	cam.free()


func test_mouse_motion_turns_the_view_only_while_captured() -> void:
	var cam := FpvCamera.new()
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(100, 0)
	cam.handle(move)
	assert_eq(cam.yaw, 0.0, "a free mouse does not turn the view")
	cam.captured = true
	cam.handle(move)
	assert_true(cam.yaw < 0.0, "moving right turns right (yaw decreases)")
	cam.free()


func test_the_crosshair_finds_a_seat_then_a_building_then_the_ground() -> void:
	var cam := FpvCamera.new()
	cam.follow(Vector2(0, 0))
	# Looking north and down 20°, the ray meets the ground ~4.4 m ahead.
	cam.look(0.0, -20.0)
	var seats := [{"id": "seat:a", "pos": Vector2(0.2, -4.3)}, {"id": "seat:far", "pos": Vector2(0, -9)}]
	var buildings := [{"id": "facility:hall", "footprint": Rect2(-2, -12, 4, 4)}]
	var hit := cam.aim(seats, buildings)
	assert_eq(hit["kind"], "anchor", "the seat under the crosshair")
	assert_eq(hit["id"], "seat:a", "the nearer seat")
	cam.look(0.0, 12.0)
	hit = cam.aim(seats, buildings)
	assert_eq(hit["kind"], "building", "further out, the hall's footprint: %s" % hit)
	cam.look(0.0, 60.0)
	hit = cam.aim(seats, buildings)
	assert_eq(hit["kind"], "none", "looking up at the sky targets nothing")
	cam.look(90.0, -90.0)
	hit = cam.aim(seats, buildings)
	assert_eq(hit["kind"], "ground", "looking down at open ground")
	cam.free()


func test_indoors_the_crosshair_finds_the_seat_not_the_room_around_you() -> void:
	var cam := FpvCamera.new()
	cam.follow(Vector2(0, 0))
	cam.look(0.0, -35.0)
	var seats := [{"id": "seat:desk", "pos": Vector2(0, -2.2)}]
	var buildings := [{"id": "facility:hall", "footprint": Rect2(-5, -5, 10, 10), "height": 5.2}]
	var hit := cam.aim(seats, buildings)
	assert_eq(hit["kind"], "anchor", "standing inside the hall, the seat ahead: %s" % hit)
	cam.look(0.0, 35.0)
	cam.look(0.0, -12.0)
	hit = cam.aim(seats, buildings)
	assert_eq(hit["kind"], "ground", "or the floor further on, not the hall: %s" % hit)
	cam.free()


## Standing in a building, the crosshair reaches no further than its
## walls: the floor beyond them is aimed at where the wall meets it, marked
## as inside the building, and nothing past the walls is aimed at.
func test_inside_a_building_the_crosshair_stops_at_its_walls() -> void:
	var cam := FpvCamera.new()
	cam.follow(Vector2(0, 0))
	cam.look(0.0, -5.0)
	var buildings := [{"id": "facility:hall", "footprint": Rect2(-5, -5, 10, 10), "height": 4.0},
		{"id": "facility:shed", "footprint": Rect2(-1, -12, 2, 2), "height": 4.0}]
	var hit := cam.aim([], buildings, [{"id": "someone", "pos": Vector2(0, -8)}])
	assert_eq(hit["kind"], "ground", "the floor, not the shed or the person beyond the wall: %s" % hit)
	assert_true(hit["point"].distance_to(Vector2(0, -5)) < 0.01, "where the wall meets it, 18 m short of the open ground: %s" % hit)
	assert_eq(hit.get("inside"), "facility:hall", "inside the hall")
	cam.look(0.0, 5.0)
	hit = cam.aim([], buildings)
	assert_eq(hit["kind"], "none", "level, nothing through the wall: %s" % hit)
	cam.look(0.0, -40.0)
	hit = cam.aim([], buildings)
	assert_eq(hit["kind"], "ground", "the floor within: %s" % hit)
	assert_eq(hit.get("inside"), "facility:hall", "inside the hall too")
	cam.follow(Vector2(0, 20))
	cam.look(0.0, -60.0)
	hit = cam.aim([], buildings)
	assert_eq(hit["kind"], "ground", "open ground outside")
	assert_true(not hit.has("inside"), "in no building: %s" % hit)
	cam.free()


func test_a_seated_rider_s_eye_is_the_one_the_trams_windows_are_built_round() -> void:
	# Aboard, first person sits at FpvCamera.SEATED_EYE over the tram's
	# floor; every kit's side windows run from below that eye to above it
	# (tools/styles/shared/tram_checks.py), measured from the shared
	# layout's seated eye, so the two must agree.
	var layout := StylePack.tram_layout()
	assert_true(layout.has("seated_eye_cm"), "the shared tram layout gives a seated rider's eye")
	assert_eq(FpvCamera.SEATED_EYE * 100.0, float(layout.get("seated_eye_cm", -1)), "the first-person seated eye is the layout's")
