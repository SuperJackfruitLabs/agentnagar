//! Per-viewer projections: the only world data a client receives.

use crate::index::{TrackGeometry, round_div};
use crate::presence::is_expired;
use crate::transit::{sign, slot_along};
use city_contracts::{
    Arrivals, Badge, CityId, Clock, Direction, HumanTier, Line, Location, OccupantKind,
    OccupantState, OccupantView, PlaceId, PlatformWait, Point, Projection, QueueSpot, Room,
    RoomView, SCHEMA_VERSION, SeatView, Snapshot, Tick, VehicleSpec, VehicleState, VehicleStatus,
    VehicleView, Viewer, Weather,
};
use std::collections::BTreeMap;

/// Whether an occupant of this kind takes shared capacity and seats. Only
/// occupants every viewer can see do, so nothing hidden can shape what the
/// public sees: no full-looking room, no taken-looking seat, no queue.
/// Private personal agents and anonymous observers are present as overlays.
pub fn shares_capacity(kind: &OccupantKind) -> bool {
    !matches!(
        kind,
        OccupantKind::PersonalAgent { .. }
            | OccupantKind::Human {
                tier: HumanTier::Observer
            }
    )
}

/// Whether `viewer` may see `occ` at all. A private personal agent does not
/// exist for anyone but its owner and the people it is shared with, and an
/// anonymous observer is hidden from everyone but themselves (the RD03
/// default until that decision is made).
pub fn visible(viewer: &Viewer, occ: &OccupantState) -> bool {
    let person = match viewer {
        Viewer::Operator => return true,
        Viewer::Public => None,
        Viewer::Person { id } => Some(id),
    };
    match &occ.profile.kind {
        OccupantKind::PersonalAgent { owner } => {
            person.is_some_and(|p| p == owner || occ.profile.shared_with.contains(p))
        }
        OccupantKind::Human {
            tier: HumanTier::Observer,
        } => person.is_some_and(|p| *p == occ.profile.id),
        _ => true,
    }
}

fn summary(viewer: &Viewer, occ: &OccupantState, tick: u64) -> Option<String> {
    let task = occ.presence.task.as_ref()?;
    if is_expired(&task.stamp, tick) {
        return None;
    }
    let owner_views = match (&occ.profile.kind, viewer) {
        (OccupantKind::PersonalAgent { owner }, Viewer::Person { id }) => owner == id,
        _ => false,
    };
    let allowed = matches!(viewer, Viewer::Operator) || owner_views || task.value.summary_public;
    if allowed {
        task.value.summary.clone()
    } else {
        None
    }
}

fn view(viewer: &Viewer, occ: &OccupantState, tick: u64, seats: &SeatAnchors) -> OccupantView {
    let seat = match &occ.location {
        Location::InRoom { seat, .. } => seat.clone(),
        _ => None,
    };
    let badge = match occ.profile.kind {
        OccupantKind::GuildAgent
        | OccupantKind::CityRoleAgent
        | OccupantKind::PersonalAgent { .. } => Some(Badge::Ai),
        OccupantKind::SimCitizen => Some(Badge::Simulation),
        OccupantKind::Human { .. } => None,
    };
    OccupantView {
        id: occ.profile.id.clone(),
        kind: occ.profile.kind.clone(),
        display_name: occ.profile.display_name.clone(),
        role: occ.profile.role.clone(),
        badge,
        appearance: occ.profile.appearance.clone(),
        seat,
        presence: occ.shown,
        task_summary: summary(viewer, occ, tick),
        pos: occ.pos,
        facing: occ.facing,
        moving: occ.walk.is_some(),
        path_ahead: occ
            .walk
            .as_ref()
            .map(|w| w.path.iter().take(PATH_AHEAD).copied().collect())
            .unwrap_or_default(),
        trail: occ.trail.clone(),
        queue: None,
        vehicle: None,
        slot: None,
        waiting_for: match &occ.location {
            Location::WaitingFor { stop, direction } => Some(PlatformWait {
                stop: stop.clone(),
                direction: *direction,
            }),
            _ => None,
        },
        using: crate::interact::shown_using(occ, &|seat| {
            seats.get(seat).copied().unwrap_or_default()
        }),
    }
}

/// Which anchor of its furniture each seat is, by seat ID, for showing a
/// seated occupant's use.
type SeatAnchors = BTreeMap<PlaceId, u32>;

fn seat_anchors(snapshot: &Snapshot) -> SeatAnchors {
    snapshot
        .manifest
        .city
        .districts
        .iter()
        .flat_map(|d| &d.facilities)
        .flat_map(|f| &f.rooms)
        .flat_map(|r| &r.seats)
        .map(|s| {
            (
                s.id.clone(),
                crate::interact::seat_anchor(s.kind.as_deref(), s.anchor),
            )
        })
        .collect()
}

/// How many upcoming path points a projection carries: one tick of walking.
pub const PATH_AHEAD: usize = crate::world::STEPS_PER_TICK;

/// Minutes after midnight at `tick`.
pub fn time_of_day(clock: Clock, tick: Tick) -> u32 {
    let per_day = u64::from(clock.ticks_per_day.max(1));
    let minutes = u64::from(clock.start_minute) + tick % per_day * 1440 / per_day;
    (minutes % 1440) as u32
}

/// Minutes over which a rain spell rises to its peak and eases off.
pub const RAIN_RAMP: u32 = 20;

/// How hard it is raining at `tick`, 0 to 100 percent: the heaviest spell
/// under way, each rising over its first RAIN_RAMP minutes and easing off
/// over its last.
pub fn rain_at(clock: Clock, weather: &Weather, tick: Tick) -> u8 {
    let now = time_of_day(clock, tick);
    weather
        .rain
        .iter()
        .map(|s| {
            let length = (s.to + 1440 - s.from) % 1440;
            let into = (now + 1440 - s.from) % 1440;
            if into >= length {
                return 0;
            }
            let edge = into.min(length - into).min(RAIN_RAMP);
            (u32::from(s.peak) * edge / RAIN_RAMP) as u8
        })
        .max()
        .unwrap_or(0)
}

/// How far (cm) from the middle of a vehicle's width a rider's slot sits:
/// riders sit two across, their columns' middles a metre apart. It is fixed
/// rather than taken from the vehicle's width, because the style kits'
/// shared tram layout draws its seats at these points.
pub const SLOT_ACROSS: i64 = 50;

/// Where a rider in `slot` is drawn aboard a vehicle running `direction`
/// on `track` with its front at `front`: [`slot_along`] behind the front,
/// and [`SLOT_ACROSS`] to the left of the way it runs for an even slot, or
/// to the right for an odd one. A hidden rider's slot (`u32::MAX`) is the
/// middle of the vehicle.
pub fn slot_point(
    track: &TrackGeometry,
    spec: &VehicleSpec,
    front: i64,
    direction: Direction,
    slot: u32,
) -> Point {
    let along = front - sign(direction) * slot_along(spec, slot);
    let centre = track.point_extended(along);
    let length = track.segment_length_at(along, direction);
    if slot == u32::MAX || length == 0 {
        return centre;
    }
    let (tx, tz) = track.travel_at(along, direction);
    // With x east and z south, the left of (tx, tz) is (tz, -tx).
    let side = if slot.is_multiple_of(2) { 1 } else { -1 };
    Point {
        x: centre.x + round_div(side * tz * SLOT_ACROSS, length) as i32,
        z: centre.z + round_div(-side * tx * SLOT_ACROSS, length) as i32,
    }
}

/// A vehicle as every viewer sees it, on `track`, its own direction's
/// track. `pos` is its front's centre: a vehicle standing at a stop is
/// centred on the stop's `at`, so its front is half its length past it.
fn vehicle_view(tick: Tick, vehicle: &VehicleState, track: &TrackGeometry) -> VehicleView {
    let (status, stop, doors_open) = match &vehicle.status {
        VehicleStatus::Running => ("running", None, false),
        VehicleStatus::Standing {
            stop,
            doors_open_until,
        } => ("standing", Some(stop.clone()), tick < *doors_open_until),
        VehicleStatus::Held => ("held", None, false),
    };
    let front = i64::from(vehicle.along);
    VehicleView {
        id: vehicle.id.clone(),
        line: vehicle.line.clone(),
        direction: vehicle.direction,
        pos: track.point_extended(front),
        heading: track.heading_at(front, vehicle.direction),
        along: vehicle.along,
        trail: vehicle.trail.clone(),
        status: status.to_string(),
        doors_open,
        stop,
    }
}

/// Whether `occ` is an arrival queued at a portal, riding in: not in the
/// city yet, so no one sees it until it is aboard. In tram mode such an
/// arrival is `Arriving` with no position, no walk and no place in the
/// admission queue (invariant 23); no other arrival is all three.
fn riding_in(snapshot: &Snapshot, id: &CityId, occ: &OccupantState) -> bool {
    snapshot.manifest.city.arrivals == Arrivals::Tram
        && matches!(occ.location, Location::Arriving { .. })
        && occ.pos.is_none()
        && occ.walk.is_none()
        && !snapshot.admission_queue.contains(id)
}

/// The platform room a waiter stands on: its stop's platform for its
/// direction, or, with none, whichever of the two it stands in.
fn platform_room<'a>(
    snapshot: &'a Snapshot,
    rooms: &BTreeMap<PlaceId, (PlaceId, &Room)>,
    stop: &PlaceId,
    direction: Option<Direction>,
    pos: Option<Point>,
) -> Option<&'a PlaceId> {
    let platforms = &snapshot
        .manifest
        .lines
        .iter()
        .flat_map(|l| &l.stops)
        .find(|s| &s.id == stop)?
        .platforms;
    if let Some(d) = direction {
        return Some(&platforms[d.index()]);
    }
    let stands_in = |room: &PlaceId| {
        let rect = rooms.get(room).and_then(|(_, r)| r.rect);
        matches!((rect, pos), (Some(r), Some(p))
            if (r.x..r.x + r.w).contains(&p.x) && (r.z..r.z + r.d).contains(&p.z))
    };
    platforms
        .iter()
        .find(|r| stands_in(r))
        .or(platforms.first())
}

/// The world as `viewer` may see it.
///
/// - Vehicles are seen by everyone, in vehicle order, with no rider count.
/// - Riders are listed in `aboard`, vehicle by vehicle in slot order (hidden
///   riders last, in boarding order), each at its slot's point; they follow
///   the usual visibility rules.
/// - A platform waiter stands among its platform room's occupants, marked
///   `waiting_for`.
/// - An arrival queued at a portal is seen by no one until it boards.
pub fn project(snapshot: &Snapshot, viewer: &Viewer) -> Projection {
    let seat_anchors = seat_anchors(snapshot);
    let mut facility_of = BTreeMap::new();
    for d in &snapshot.manifest.city.districts {
        for f in &d.facilities {
            for r in &f.rooms {
                facility_of.insert(r.id.clone(), (f.id.clone(), r));
            }
        }
    }
    let waits_on = |o: &OccupantState| match &o.location {
        Location::WaitingFor { stop, direction } => {
            platform_room(snapshot, &facility_of, stop, *direction, o.pos)
        }
        _ => None,
    };
    let visible_views = |pred: &dyn Fn(&CityId, &OccupantState) -> bool| -> Vec<OccupantView> {
        snapshot
            .occupants
            .iter()
            .filter(|(id, o)| pred(id, o) && visible(viewer, o))
            .map(|(_, o)| view(viewer, o, snapshot.tick, &seat_anchors))
            .collect()
    };
    let mut rooms = Vec::new();
    for (id, (facility, room)) in &facility_of {
        let pods: BTreeMap<_, _> = room.pods.iter().map(|p| (&p.id, &p.department)).collect();
        let mut seats: Vec<SeatView> = room
            .seats
            .iter()
            .map(|s| SeatView {
                id: s.id.clone(),
                pod: s.pod.clone(),
                department: s
                    .pod
                    .as_ref()
                    .and_then(|p| pods.get(p).and_then(|d| (*d).clone())),
                reserved: s.reserved_for.is_some(),
            })
            .collect();
        seats.sort_by(|a, b| a.id.cmp(&b.id));
        rooms.push(RoomView {
            id: id.clone(),
            name: room.name.clone(),
            facility: facility.clone(),
            capacity: room.capacity,
            seats,
            occupants: visible_views(&|_, o| match &o.location {
                Location::InRoom { room, .. } => room == id,
                Location::WaitingFor { .. } => waits_on(o) == Some(id),
                _ => false,
            }),
            waiting: snapshot.rooms[id]
                .waitlist
                .iter()
                .enumerate()
                .map(|(k, o)| (k, &snapshot.occupants[o]))
                .filter(|(_, o)| visible(viewer, o))
                .map(|(k, o)| OccupantView {
                    queue: Some(QueueSpot {
                        room: id.clone(),
                        position: k as u32 + 1,
                    }),
                    ..view(viewer, o, snapshot.tick, &seat_anchors)
                })
                .collect(),
        });
    }
    let (vehicles, aboard) = vehicles_and_riders(snapshot, viewer);
    Projection {
        schema_version: SCHEMA_VERSION,
        tick: snapshot.tick,
        fixture: snapshot.fixture,
        viewer: viewer.clone(),
        rooms,
        in_transit: visible_views(&|id, o| match o.location {
            Location::Arriving { .. } => !riding_in(snapshot, id, o),
            Location::InTransit { .. } | Location::Leaving { .. } => true,
            _ => false,
        }),
        time_of_day: snapshot
            .manifest
            .clock
            .map(|c| time_of_day(c, snapshot.tick)),
        rain: match (snapshot.manifest.clock, &snapshot.manifest.weather) {
            (Some(c), Some(w)) => Some(rain_at(c, w, snapshot.tick)),
            _ => None,
        },
        vehicles,
        aboard,
        grid_changes: snapshot.grid_changes.clone(),
    }
}

/// Every vehicle, and the riders aboard them `viewer` may see.
fn vehicles_and_riders(
    snapshot: &Snapshot,
    viewer: &Viewer,
) -> (Vec<VehicleView>, Vec<OccupantView>) {
    let mut vehicles = Vec::new();
    let mut aboard = Vec::new();
    if snapshot.vehicles.is_empty() {
        return (vehicles, aboard);
    }
    let lines: BTreeMap<&PlaceId, (&Line, [TrackGeometry; 2])> = snapshot
        .manifest
        .lines
        .iter()
        .map(|l| {
            let tracks = std::array::from_fn(|d| TrackGeometry::of(&l.points, l.tracks[d]));
            (&l.id, (l, tracks))
        })
        .collect();
    for vehicle in &snapshot.vehicles {
        let Some((line, tracks)) = lines.get(&vehicle.line) else {
            continue;
        };
        let track = &tracks[vehicle.direction.index()];
        let shown = vehicle_view(snapshot.tick, vehicle, track);
        let mut riders: Vec<(u32, usize, &OccupantState)> = vehicle
            .riders
            .iter()
            .enumerate()
            .filter_map(|(order, id)| {
                let o = snapshot.occupants.get(id)?;
                match &o.location {
                    Location::Aboard { vehicle: v, slot } if *v == vehicle.id => {
                        Some((*slot, order, o))
                    }
                    _ => None,
                }
            })
            .filter(|(_, _, o)| visible(viewer, o))
            .collect();
        riders.sort_by_key(|(slot, order, _)| (*slot, *order));
        for (slot, _, o) in riders {
            let front = i64::from(vehicle.along);
            aboard.push(OccupantView {
                pos: Some(slot_point(
                    track,
                    &line.vehicle,
                    front,
                    vehicle.direction,
                    slot,
                )),
                facing: shown.heading,
                moving: false,
                path_ahead: Vec::new(),
                trail: Vec::new(),
                vehicle: Some(vehicle.id.clone()),
                slot: (slot != u32::MAX).then_some(slot),
                // Riders sit in no seat and use nothing.
                ..view(viewer, o, snapshot.tick, &SeatAnchors::new())
            });
        }
        vehicles.push(shown);
    }
    (vehicles, aboard)
}

#[cfg(test)]
mod weather_tests {
    use super::*;
    use city_contracts::{RainSpell, Weather};

    fn clock() -> Clock {
        Clock {
            ticks_per_day: 1440,
            start_minute: 0,
        }
    }

    #[test]
    fn rain_ramps_in_and_out_over_twenty_minutes_and_crosses_midnight() {
        let w = Weather {
            rain: vec![RainSpell {
                from: 1380,
                to: 60,
                peak: 80,
            }],
        };
        assert_eq!(rain_at(clock(), &w, 1370), 0, "before the spell");
        assert_eq!(rain_at(clock(), &w, 1390), 40, "half way up the ramp");
        assert_eq!(rain_at(clock(), &w, 1400), 80, "at its peak");
        assert_eq!(rain_at(clock(), &w, 10), 80, "past midnight");
        assert_eq!(rain_at(clock(), &w, 50), 40, "easing off");
        assert_eq!(rain_at(clock(), &w, 60), 0, "over");
        assert_eq!(rain_at(clock(), &w, 1440 + 10), 80, "the next day too");
    }

    #[test]
    fn overlapping_spells_take_the_heavier_and_short_spells_never_reach_peak() {
        let w = Weather {
            rain: vec![
                RainSpell {
                    from: 600,
                    to: 700,
                    peak: 30,
                },
                RainSpell {
                    from: 650,
                    to: 670,
                    peak: 100,
                },
            ],
        };
        assert_eq!(
            rain_at(clock(), &w, 660),
            50,
            "ten minutes into a twenty-minute spell"
        );
        assert_eq!(rain_at(clock(), &w, 630), 30, "the lighter spell alone");
    }

    #[test]
    fn the_projection_carries_rain_only_with_a_clock_and_weather() {
        let mut m: city_contracts::Manifest =
            serde_json::from_str(include_str!("../../../fixtures/district/manifest.json")).unwrap();
        m.weather = Some(Weather {
            rain: vec![RainSpell {
                from: 420,
                to: 600,
                peak: 60,
            }],
        });
        let w = crate::World::new(
            m.clone(),
            crate::parse_feed(include_str!("../../../fixtures/district/feed.jsonl")).unwrap(),
            1,
        )
        .unwrap();
        let p = project(w.snapshot(), &Viewer::Public);
        assert_eq!(p.rain, Some(0), "the spell starts at 07:00: nothing yet");
        m.weather = None;
        let w = crate::World::new(
            m,
            crate::parse_feed(include_str!("../../../fixtures/district/feed.jsonl")).unwrap(),
            1,
        )
        .unwrap();
        assert_eq!(project(w.snapshot(), &Viewer::Public).rain, None);
    }
}

#[cfg(test)]
mod vehicle_tests {
    use super::*;
    use crate::{Feed, World};
    use city_contracts::{
        Command, Direction, FeedHeader, HumanTier, OccupantProfile, PlatformWait, Point,
        PresenceRecord, ShownPresence, VehicleStatus, VehicleView,
    };

    const EAST_1: &str = "vehicle:boulevard:east:1";
    const WEST_1: &str = "vehicle:boulevard:west:1";

    fn feed() -> Feed {
        Feed {
            header: FeedHeader {
                schema_version: 1,
                source: "fixture:test".into(),
                fixture: true,
                description: String::new(),
            },
            entries: Vec::new(),
        }
    }

    /// The one-stop tram street: eastbound track at z = 300, westbound at
    /// z = 600, `stop:mid` at 20 m, `room:north` and `room:south` its
    /// platforms. Vehicles are 12 m long and carry 40.
    fn street() -> World {
        World::new(crate::index::fixtures::tram_street(), feed(), 1).expect("valid")
    }

    fn run_to(w: &mut World, tick: Tick) {
        while w.snapshot().tick < tick {
            w.step();
        }
    }

    fn vehicle<'a>(p: &'a Projection, id: &str) -> &'a VehicleView {
        p.vehicles
            .iter()
            .find(|v| v.id.as_str() == id)
            .unwrap_or_else(|| panic!("{id} is not in the projection"))
    }

    fn at(x: i32, z: i32) -> Point {
        Point { x, z }
    }

    fn profile(id: &str, kind: OccupantKind) -> OccupantProfile {
        OccupantProfile {
            id: id.into(),
            kind,
            display_name: id.to_string(),
            role: String::new(),
            department: None,
            home: None,
            work: None,
            shared_with: Default::default(),
            appearance: Default::default(),
        }
    }

    fn public() -> OccupantKind {
        OccupantKind::Human {
            tier: HumanTier::Registered,
        }
    }

    fn personal_agent() -> OccupantKind {
        OccupantKind::PersonalAgent {
            owner: "person:owner".into(),
        }
    }

    fn observer() -> OccupantKind {
        OccupantKind::Human {
            tier: HumanTier::Observer,
        }
    }

    /// Puts `id` into `s` at `location`, standing at `pos`.
    fn plant(
        s: &mut Snapshot,
        id: &str,
        kind: OccupantKind,
        location: Location,
        pos: Option<Point>,
    ) {
        s.occupants.insert(
            id.into(),
            OccupantState {
                profile: profile(id, kind),
                location,
                presence: PresenceRecord::default(),
                shown: ShownPresence::default(),
                pos,
                facing: 0,
                walk: None,
                trail: vec![at(1, 1)],
                goal: None,
                using: None,
            },
        );
    }

    /// Puts `id` aboard `vehicle` in `slot`, boarding after those already
    /// aboard.
    fn board(s: &mut Snapshot, id: &str, kind: OccupantKind, vehicle: &str, slot: u32) {
        plant(
            s,
            id,
            kind,
            Location::Aboard {
                vehicle: vehicle.into(),
                slot,
            },
            None,
        );
        s.vehicles
            .iter_mut()
            .find(|v| v.id.as_str() == vehicle)
            .expect("the vehicle is on the line")
            .riders
            .push(id.into());
    }

    fn person(id: &str) -> Viewer {
        Viewer::Person { id: id.into() }
    }

    fn ids(views: &[OccupantView]) -> Vec<&str> {
        views.iter().map(|o| o.id.as_str()).collect()
    }

    #[test]
    fn vehicles_show_their_front_heading_trail_and_status() {
        let mut w = street();
        run_to(&mut w, 19);
        // West:1 entered at 15 and has just stopped centred on the stop at
        // 20 m, so its front (its west end) is half its length short of it.
        let p = project(w.snapshot(), &Viewer::Public);
        let west = vehicle(&p, WEST_1);
        assert_eq!(
            west.pos,
            at(1400, 600),
            "front centre on the westbound track"
        );
        assert_eq!(west.along, 1400);
        assert_eq!(west.heading, 270);
        assert_eq!(west.trail, vec![1900, 1400]);
        assert_eq!(west.status, "standing");
        assert!(west.doors_open);
        assert_eq!(west.stop, Some("stop:mid".into()));

        run_to(&mut w, 20);
        let p = project(w.snapshot(), &Viewer::Public);
        assert_eq!(vehicle(&p, WEST_1).trail, Vec::<i32>::new(), "stood still");

        run_to(&mut w, 30);
        let p = project(w.snapshot(), &Viewer::Public);
        let ids: Vec<&str> = p.vehicles.iter().map(|v| v.id.as_str()).collect();
        assert_eq!(ids, [EAST_1, WEST_1], "in vehicle order, east first");
        let east = vehicle(&p, EAST_1);
        assert_eq!(
            east.pos,
            at(0, 300),
            "just entered, its front at the portal"
        );
        assert_eq!(east.heading, 90);
        assert!(east.trail.is_empty(), "just entered: it has not moved");
        assert_eq!(east.status, "running");
        assert!(!east.doors_open);
        assert_eq!(east.stop, None);

        run_to(&mut w, 31);
        let p = project(w.snapshot(), &Viewer::Public);
        let east = vehicle(&p, EAST_1);
        assert_eq!((east.pos, east.trail.clone()), (at(700, 300), vec![0, 700]));

        run_to(&mut w, 34);
        let p = project(w.snapshot(), &Viewer::Public);
        let east = vehicle(&p, EAST_1);
        // Standing, centred on the stop's `at`: its front, its east end, is
        // half a length past it.
        assert_eq!(east.pos, at(2000 + 600, 300));
        assert_eq!(east.trail, vec![2100, 2600]);
        assert_eq!((east.status.as_str(), east.doors_open), ("standing", true));

        let mut held = w.snapshot().clone();
        held.vehicles[0].status = VehicleStatus::Held;
        assert_eq!(
            vehicle(&project(&held, &Viewer::Public), EAST_1).status,
            "held"
        );
    }

    #[test]
    fn a_vehicle_part_way_through_a_portal_is_on_its_track_extended() {
        let mut w = street();
        let mut beyond = 0;
        for _ in 0..120 {
            w.step();
            let p = project(w.snapshot(), &Viewer::Operator);
            for v in &p.vehicles {
                let z = if v.direction == Direction::East {
                    300
                } else {
                    600
                };
                // The track runs straight west to east, so x is `along`,
                // even past either end.
                assert_eq!(v.pos, at(v.along, z), "{} at tick {}", v.id, p.tick);
                if v.along < 0 || v.along > 4000 {
                    beyond += 1;
                }
            }
        }
        assert!(beyond > 0, "some vehicle's front passed a far portal");
    }

    #[test]
    fn riders_sit_in_their_slots_and_hidden_riders_show_only_to_who_may_see_them() {
        let mut w = street();
        run_to(&mut w, 31);
        let mut s = w.snapshot().clone();
        // East:1's front is at 7 m; it boards out of slot order.
        board(&mut s, "person:r3", public(), EAST_1, 3);
        board(&mut s, "pa:mine", personal_agent(), EAST_1, u32::MAX);
        board(&mut s, "person:r0", public(), EAST_1, 0);
        board(&mut s, "person:obs", observer(), EAST_1, u32::MAX);

        let p = project(&s, &Viewer::Public);
        assert_eq!(ids(&p.aboard), ["person:r0", "person:r3"], "by slot");
        let r0 = &p.aboard[0];
        // Row 0 of 20 is 30 cm behind the front; slot 0 on the left of the
        // way it runs (north, eastbound), half a metre off the track.
        assert_eq!(r0.pos, Some(at(700 - 30, 300 - 50)));
        assert_eq!(
            (r0.vehicle.clone(), r0.slot),
            (Some(EAST_1.into()), Some(0))
        );
        assert_eq!(r0.facing, 90, "riders face the way the vehicle runs");
        assert!(r0.trail.is_empty() && r0.path_ahead.is_empty() && !r0.moving);
        let r3 = &p.aboard[1];
        // Slot 3: row 1, 90 cm back, on the right.
        assert_eq!(r3.pos, Some(at(700 - 90, 300 + 50)));
        assert!(p.in_transit.is_empty() && p.rooms.iter().all(|r| r.occupants.is_empty()));

        let owner = project(&s, &person("person:owner"));
        assert_eq!(ids(&owner.aboard), ["person:r0", "person:r3", "pa:mine"]);
        let mine = &owner.aboard[2];
        assert_eq!(
            mine.pos,
            Some(at(700 - 600, 300)),
            "at the vehicle's centre"
        );
        assert_eq!(
            (mine.vehicle.clone(), mine.slot),
            (Some(EAST_1.into()), None)
        );

        let obs = project(&s, &person("person:obs"));
        assert_eq!(ids(&obs.aboard), ["person:r0", "person:r3", "person:obs"]);
        let all = project(&s, &Viewer::Operator);
        assert_eq!(
            ids(&all.aboard),
            ["person:r0", "person:r3", "pa:mine", "person:obs"],
            "hidden riders last, in boarding order"
        );

        // Nothing about a vehicle changes with its hidden riders: no count.
        let mut public_only = w.snapshot().clone();
        board(&mut public_only, "person:r3", public(), EAST_1, 3);
        board(&mut public_only, "person:r0", public(), EAST_1, 0);
        let without = project(&public_only, &Viewer::Public);
        assert_eq!(without.vehicles, p.vehicles);
        assert_eq!(
            serde_json::to_string(&without).unwrap(),
            serde_json::to_string(&p).unwrap(),
            "the public view is byte-identical with or without hidden riders"
        );
    }

    #[test]
    fn a_hidden_rider_in_a_public_view_breaks_invariant_three() {
        let mut w = street();
        run_to(&mut w, 31);
        let mut s = w.snapshot().clone();
        board(&mut s, "pa:mine", personal_agent(), EAST_1, u32::MAX);
        let mut p = project(&s, &Viewer::Public);
        assert!(crate::invariants::check_projection(&s, &Viewer::Public, &p).is_empty());
        p.aboard = project(&s, &Viewer::Operator).aboard;
        let violations = crate::invariants::check_projection(&s, &Viewer::Public, &p);
        assert!(
            violations.iter().any(|v| v.invariant == 3),
            "{violations:?}"
        );
    }

    #[test]
    fn waiters_stand_on_their_platform_marked_as_waiting() {
        let mut w = street();
        run_to(&mut w, 20);
        let mut s = w.snapshot().clone();
        let waiting = |direction| Location::WaitingFor {
            stop: "stop:mid".into(),
            direction: Some(direction),
        };
        plant(
            &mut s,
            "person:west",
            public(),
            waiting(Direction::West),
            Some(at(1012, 812)),
        );
        plant(
            &mut s,
            "pa:east",
            personal_agent(),
            waiting(Direction::East),
            Some(at(1012, 112)),
        );
        let room = |p: &Projection, id: &str| {
            p.rooms
                .iter()
                .find(|r| r.id.as_str() == id)
                .expect("room")
                .occupants
                .clone()
        };

        let p = project(&s, &Viewer::Public);
        let south = room(&p, "room:south");
        assert_eq!(ids(&south), ["person:west"]);
        assert_eq!(south[0].pos, Some(at(1012, 812)));
        assert_eq!(
            south[0].waiting_for,
            Some(PlatformWait {
                stop: "stop:mid".into(),
                direction: Some(Direction::West),
            })
        );
        assert!(
            room(&p, "room:north").is_empty(),
            "the hidden waiter is hidden"
        );
        assert!(p.in_transit.is_empty() && p.aboard.is_empty());

        let owner = project(&s, &person("person:owner"));
        let north = room(&owner, "room:north");
        assert_eq!(ids(&north), ["pa:east"]);
        assert_eq!(
            north[0].waiting_for.as_ref().map(|w| &w.direction),
            Some(&Some(Direction::East))
        );

        // One waiting for the next vehicle either way stands on whichever
        // platform it is on.
        plant(
            &mut s,
            "person:either",
            public(),
            Location::WaitingFor {
                stop: "stop:mid".into(),
                direction: None,
            },
            Some(at(3012, 812)),
        );
        let south = room(&project(&s, &Viewer::Public), "room:south");
        assert_eq!(ids(&south), ["person:either", "person:west"]);
        assert_eq!(
            south[0].waiting_for,
            Some(PlatformWait {
                stop: "stop:mid".into(),
                direction: None,
            })
        );
    }

    #[test]
    fn arrivals_queued_at_a_portal_are_not_seen_until_they_board() {
        let mut w = World::new(crate::index::fixtures::tram_arrivals(), feed(), 1).expect("valid");
        w.submit(Command::Arrive {
            occupant: "agent:e".into(),
            profile: Some(profile("agent:e", OccupantKind::GuildAgent)),
            room: Some("room:shop".into()),
            player: false,
        });
        let seen = |w: &World| {
            let p = project(w.snapshot(), &Viewer::Operator);
            let mut all: Vec<String> = p
                .rooms
                .iter()
                .flat_map(|r| r.occupants.iter().chain(&r.waiting))
                .chain(&p.in_transit)
                .chain(&p.aboard)
                .map(|o| o.id.to_string())
                .collect();
            all.sort();
            all
        };
        for _ in 0..29 {
            w.step();
            assert!(
                seen(&w).is_empty(),
                "queued at the east portal at tick {}",
                w.snapshot().tick
            );
        }
        w.step();
        let p = project(w.snapshot(), &Viewer::Public);
        assert_eq!(ids(&p.aboard), ["agent:e"], "aboard east:1 as it enters");
        assert_eq!(p.aboard[0].vehicle, Some(EAST_1.into()));
        assert_eq!(p.aboard[0].slot, Some(0));
    }
}
