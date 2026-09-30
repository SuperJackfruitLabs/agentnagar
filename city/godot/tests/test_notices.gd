## The notices for full rooms (spec §6, "Full rooms"): a steered entry
## refused at a full room's door, a Go queued for one, first in line or
## behind others, and a Go let into the next room of the overflow chain.
## Each names its rooms as the layout does.
extends TestSuite


func booted():
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack"]), "res://tests/fixtures")
	assert_true(not main.hud.error_label.visible, "booted: " + main.hud.error_label.text)
	return main


func test_each_full_room_event_has_its_notice() -> void:
	var main = booted()
	for case in [
		[{"type": "Rejected", "command": "Steer", "reason": {"RoomFull": {"room": "room:workshop"}}},
			"The Workshop is full — choose Go in to queue."],
		[{"type": "Waitlisted", "room": "room:workshop", "position": 1},
			"You're next in line for the Workshop."],
		[{"type": "Waitlisted", "room": "room:reading", "position": 3},
			"You're in line for the Reading room."],
		[{"type": "Overflowed", "from": "room:workshop", "to": "room:commons"},
			"The Workshop is full; you've been let into the Commons."],
	]:
		main.hud.dismiss_notices()
		main._notice_events([{"occupant": main.player.id, "kind": case[0]}])
		assert_eq(main.hud.notices.size(), 1, "%s: one notice" % case[0]["type"])
		if main.hud.notices.size() == 1:
			assert_eq(main.hud.notices[0].get_meta("text"), case[1], "%s" % case[0])
	# A step refused for any other reason is still the prediction's to
	# correct, not the player's to read.
	main.hud.dismiss_notices()
	main._notice_events([{"occupant": main.player.id, "kind": {"type": "Rejected", "command": "Steer", "reason": "BlockedStep"}}])
	assert_eq(main.hud.notices.size(), 0, "no notice for a blocked step")
	main.free()


## The prediction refuses the step onto a full room's door span itself, as
## the core would, so no refusal comes back: turned away there, the player
## reads the same notice, once until it steps elsewhere; a refusal from
## the core for the same door is not repeated.
func test_being_turned_away_at_a_full_room_s_door_says_so_once() -> void:
	var main = booted()
	main.hud.dismiss_notices()
	main.player.turned_away = "room:workshop"
	main._notice_turned_away()
	main._notice_turned_away()
	assert_eq(main.hud.notices.size(), 1, "one notice")
	if main.hud.notices.size() == 1:
		assert_eq(main.hud.notices[0].get_meta("text"), "The Workshop is full — choose Go in to queue.")
	main.hud.dismiss_notices()
	main.player.turned_away = ""
	main._notice_turned_away()
	main._notice_events([{"occupant": main.player.id, "kind": {"type": "Rejected", "command": "Steer", "reason": {"RoomFull": {"room": "room:commons"}}}}])
	main.player.turned_away = "room:commons"
	main._notice_turned_away()
	assert_eq(main.hud.notices.size(), 1, "the core's refusal, not repeated by the prediction")
	main.free()
