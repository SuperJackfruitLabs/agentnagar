//! Checkers for the world's invariants, run after every tick in tests.
//!
//! Invariant 6 (same inputs, byte-identical log) is checked by running a
//! world twice; the rest are checked here against snapshots and events.

use crate::index::PlaceIndex;
use crate::nav::{Cell, NavGrid};
use crate::presence::is_expired;
use crate::project::{project, shares_capacity, visible};
use crate::transit::{Destination, Riders, body, centre_along, footprint, vehicle_key};
use crate::world::World;
use city_contracts::{
    Arrivals, CityId, Direction, Event, EventKind, Headline, HumanTier, Location, OccupantKind,
    PlaceId, Projection, ShownConnection, ShownProcess, ShownTask, Snapshot, Tick, Viewer,
};
use std::collections::{BTreeMap, BTreeSet};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Violation {
    /// 1 to 7 as numbered in the specification; 8 to 11 for movement, 12
    /// for steps, 13 for observers, 14 for queues standing outside, 15 to
    /// 18 for vehicles (order, progress, footprints, spacing), 19 to 22
    /// for riders (capacity and slots, one place each, doors open, no ground
    /// cells), 23 for waiters, destinations and arrivals by tram, 24 for
    /// seats walked across, 25 for uses held where they may not be; 0 for
    /// internal consistency.
    pub invariant: u8,
    pub tick: Tick,
    pub detail: String,
}

fn v(invariant: u8, s: &Snapshot, detail: String) -> Violation {
    Violation {
        invariant,
        tick: s.tick,
        detail,
    }
}

/// Invariant 0: Seat holders, room lists and occupant locations agree.
pub fn check_consistency(s: &Snapshot) -> Vec<Violation> {
    let mut out = Vec::new();
    for (room_id, room) in &s.rooms {
        for (seat, holder) in &room.seats {
            if let Some(h) = holder {
                let ok = matches!(&s.occupants.get(h).map(|o| &o.location),
                    Some(Location::InRoom { room, seat: Some(held) }) if room == room_id && held == seat);
                if !ok {
                    out.push(v(
                        0,
                        s,
                        format!("{seat} in {room_id} names {h}, who is not sitting there"),
                    ));
                }
            }
        }
        for o in &room.occupants {
            if !matches!(&s.occupants[o].location, Location::InRoom { room, .. } if room == room_id)
            {
                out.push(v(
                    0,
                    s,
                    format!("{o} is listed in {room_id} but is not there"),
                ));
            }
        }
        for o in &room.waitlist {
            if !matches!(&s.occupants[o].location, Location::Waitlisted { room } if room == room_id)
            {
                out.push(v(
                    0,
                    s,
                    format!("{o} is on {room_id}'s waitlist but not waiting"),
                ));
            }
        }
    }
    for (id, o) in &s.occupants {
        match &o.location {
            Location::InRoom { room, seat } => {
                let r = &s.rooms[room];
                if !r.occupants.contains(id) {
                    out.push(v(0, s, format!("{id} is in {room} but not in its list")));
                }
                if let Some(seat) = seat
                    && r.seats.get(seat) != Some(&Some(id.clone()))
                {
                    out.push(v(
                        0,
                        s,
                        format!("{id} sits in {seat}, which does not name them"),
                    ));
                }
            }
            Location::Waitlisted { room } if !s.rooms[room].waitlist.contains(id) => {
                out.push(v(
                    0,
                    s,
                    format!("{id} waits for {room} but is not on its waitlist"),
                ));
            }
            _ => {}
        }
    }
    out
}

fn capacity_of(s: &Snapshot) -> impl Iterator<Item = (&PlaceId, u32)> {
    s.manifest
        .city
        .districts
        .iter()
        .flat_map(|d| &d.facilities)
        .flat_map(|f| &f.rooms)
        .map(|r| (&r.id, r.capacity))
}

/// The platform room of `stop` for vehicles running `direction`, by the
/// manifest.
fn platform_in<'a>(s: &'a Snapshot, stop: &PlaceId, direction: Direction) -> Option<&'a PlaceId> {
    s.manifest
        .lines
        .iter()
        .flat_map(|l| &l.stops)
        .find(|x| &x.id == stop)
        .map(|x| &x.platforms[direction.index()])
}

/// How many of `room`'s places are taken: its occupants who share
/// capacity, and the public waiters on it as a platform.
fn load(s: &Snapshot, room: &PlaceId) -> u64 {
    let inside = s.rooms[room]
        .occupants
        .iter()
        .filter(|o| {
            s.occupants
                .get(*o)
                .is_none_or(|x| shares_capacity(&x.profile.kind))
        })
        .count();
    let waiting = s
        .occupants
        .values()
        .filter(|o| shares_capacity(&o.profile.kind))
        .filter(|o| {
            matches!(&o.location, Location::WaitingFor { stop, direction: Some(d) }
                if platform_in(s, stop, *d) == Some(room))
        })
        .count();
    (inside + waiting) as u64
}

/// Invariant 1, strictly: no room holds more occupants than its capacity.
/// Only occupants who share capacity count; hidden overlays do not. A
/// platform's waiters count towards it. The per-tick check is
/// [`check_capacity_over_tick`], which allows for riders stepping off.
pub fn check_capacity(s: &Snapshot) -> Vec<Violation> {
    capacity_of(s)
        .filter_map(|(id, cap)| {
            let n = load(s, id);
            (n > u64::from(cap)).then(|| v(1, s, format!("{id} holds {n}, capacity {cap}")))
        })
        .collect()
}

/// Invariant 1, over a tick: a room holds no more than its capacity (its
/// platform waiters included), except by riders stepping off into it, who
/// may whatever its load: onto a full platform, or, when a hold at the
/// last stop runs out, into the room nearest the doors. One over its
/// capacity never gains anyone but them: after a tick it holds at most the
/// larger of its capacity and what it held before, plus the public riders
/// who stepped off this tick and are in it now.
pub fn check_capacity_over_tick(
    before: &Snapshot,
    after: &Snapshot,
    events: &[Event],
) -> Vec<Violation> {
    let mut out = Vec::new();
    for (id, cap) in capacity_of(after) {
        let n = load(after, id);
        let cap = u64::from(cap);
        if n <= cap {
            continue;
        }
        let was = if before.rooms.contains_key(id) {
            load(before, id)
        } else {
            0
        };
        let stepped_off = events
            .iter()
            .filter(|e| matches!(e.kind, EventKind::Alighted { .. }))
            .filter_map(|e| after.occupants.get(e.occupant.as_ref()?))
            .filter(|o| shares_capacity(&o.profile.kind))
            .filter(|o| matches!(&o.location, Location::InRoom { room, .. } if room == id))
            .count() as u64;
        if n > was.max(cap) + stepped_off {
            out.push(v(
                1,
                after,
                format!("{id} holds {n}, capacity {cap}, and only {stepped_off} stepped off"),
            ));
        }
    }
    out
}

/// Invariant 2: A reserved seat is only ever held by its named occupant.
pub fn check_reserved(s: &Snapshot) -> Vec<Violation> {
    let mut out = Vec::new();
    for r in s
        .manifest
        .city
        .districts
        .iter()
        .flat_map(|d| &d.facilities)
        .flat_map(|f| &f.rooms)
    {
        for seat in &r.seats {
            if let Some(owner) = &seat.reserved_for
                && let Some(Some(holder)) = s.rooms[&r.id].seats.get(&seat.id)
                && holder != owner
            {
                out.push(v(
                    2,
                    s,
                    format!("{} is reserved for {owner} but held by {holder}", seat.id),
                ));
            }
        }
    }
    out
}

/// Invariant 3, for one projection: every personal agent shown belongs to or is shared
/// with the viewer, and every observer shown is the viewer.
pub fn check_projection(s: &Snapshot, viewer: &Viewer, p: &Projection) -> Vec<Violation> {
    let person = match viewer {
        Viewer::Operator => return Vec::new(),
        Viewer::Public => None,
        Viewer::Person { id } => Some(id),
    };
    let views = p
        .rooms
        .iter()
        .flat_map(|r| r.occupants.iter().chain(&r.waiting))
        .chain(&p.in_transit)
        .chain(&p.aboard);
    let mut out = Vec::new();
    for view in views {
        let shared = s
            .occupants
            .get(&view.id)
            .map(|o| o.profile.shared_with.clone())
            .unwrap_or_default();
        let allowed = match &view.kind {
            OccupantKind::PersonalAgent { owner } => {
                person.is_some_and(|p| p == owner || shared.contains(p))
            }
            OccupantKind::Human {
                tier: HumanTier::Observer,
            } => person.is_some_and(|p| *p == view.id),
            _ => true,
        };
        if !allowed {
            out.push(v(3, s, format!("{} is visible to {viewer:?}", view.id)));
        }
    }
    out
}

/// Invariant 3: No personal agent appears for a viewer who is neither owner nor grantee.
/// Checks the public view and every person the snapshot mentions.
pub fn check_privacy(s: &Snapshot) -> Vec<Violation> {
    let mut people: BTreeSet<CityId> = BTreeSet::new();
    for o in s.occupants.values() {
        if matches!(o.profile.kind, OccupantKind::Human { .. }) {
            people.insert(o.profile.id.clone());
        }
        if let OccupantKind::PersonalAgent { owner } = &o.profile.kind {
            people.insert(owner.clone());
        }
        people.extend(o.profile.shared_with.iter().cloned());
    }
    let mut viewers = vec![Viewer::Public];
    viewers.extend(people.into_iter().map(|id| Viewer::Person { id }));
    viewers
        .iter()
        .flat_map(|viewer| check_projection(s, viewer, &project(s, viewer)))
        .collect()
}

/// Invariant 3, by inference: nothing hidden from the public holds a seat or
/// a place in a queue, so no public view can reveal it by what looks taken.
pub fn check_inference(s: &Snapshot) -> Vec<Violation> {
    let mut out = Vec::new();
    for (room, r) in &s.rooms {
        for (seat, holder) in &r.seats {
            if let Some(h) = holder
                && !visible(&Viewer::Public, &s.occupants[h])
            {
                out.push(v(3, s, format!("hidden {h} holds {seat} in {room}")));
            }
        }
        for h in &r.waitlist {
            if !visible(&Viewer::Public, &s.occupants[h]) {
                out.push(v(3, s, format!("hidden {h} waits for {room}")));
            }
        }
    }
    out
}

/// Invariant 4: An observation past its expiry is never shown as its last value.
pub fn check_expiry(s: &Snapshot) -> Vec<Violation> {
    let mut out = Vec::new();
    for (id, o) in &s.occupants {
        if matches!(o.location, Location::Away) {
            continue;
        }
        let p = &o.presence;
        if p.connection
            .as_ref()
            .is_some_and(|x| is_expired(&x.stamp, s.tick))
            && o.shown.connection != ShownConnection::Stale
        {
            out.push(v(4, s, format!("{id} shows an expired connection")));
        }
        if p.process
            .as_ref()
            .is_some_and(|x| is_expired(&x.stamp, s.tick))
            && o.shown.process != ShownProcess::Stale
        {
            out.push(v(4, s, format!("{id} shows an expired process")));
        }
        if p.task
            .as_ref()
            .is_some_and(|x| is_expired(&x.stamp, s.tick))
            && o.shown.task != ShownTask::Stale
        {
            out.push(v(4, s, format!("{id} shows an expired task")));
        }
    }
    out
}

/// Invariant 5: A running process with no task observation is never shown as Working.
pub fn check_unknown_task(s: &Snapshot) -> Vec<Violation> {
    s.occupants
        .iter()
        .filter(|(_, o)| {
            o.shown.process == ShownProcess::Running
                && o.presence.task.is_none()
                && (o.shown.task == ShownTask::Working || o.shown.headline == Headline::Working)
        })
        .map(|(id, _)| {
            v(
                5,
                s,
                format!("{id} is shown Working with no task observation"),
            )
        })
        .collect()
}

/// Invariant 7: Every departure releases exactly the seat that was held: the seats an
/// occupant held at the start of the tick, plus any taken during it, are all
/// released by the time it departs, none twice, and none still names it.
pub fn check_release(before: &Snapshot, after: &Snapshot, events: &[Event]) -> Vec<Violation> {
    let mut out = Vec::new();
    let departed: BTreeSet<&CityId> = events
        .iter()
        .filter(|e| matches!(e.kind, EventKind::Departed { .. }))
        .filter_map(|e| e.occupant.as_ref())
        .collect();
    for id in departed {
        let mut holding: BTreeSet<PlaceId> = match before.occupants.get(id).map(|o| &o.location) {
            Some(Location::InRoom {
                seat: Some(seat), ..
            }) => [seat.clone()].into(),
            _ => BTreeSet::new(),
        };
        for e in events.iter().filter(|e| e.occupant.as_ref() == Some(id)) {
            match &e.kind {
                EventKind::Seated { seat, .. } => {
                    holding.insert(seat.clone());
                }
                // The guard removes the seat; a release of a held seat falls through to `_`.
                EventKind::SeatReleased { seat, .. } if !holding.remove(seat) => {
                    out.push(v(
                        7,
                        after,
                        format!("{id} released {seat}, which it did not hold"),
                    ));
                }
                EventKind::Departed { .. } if !holding.is_empty() => {
                    out.push(v(
                        7,
                        after,
                        format!("{id} departed still holding {holding:?}"),
                    ));
                }
                _ => {}
            }
        }
        for (room, r) in &after.rooms {
            for (seat, holder) in &r.seats {
                if holder.as_ref() == Some(id)
                    && matches!(after.occupants[id].location, Location::Away)
                {
                    out.push(v(
                        7,
                        after,
                        format!("{seat} in {room} still names departed {id}"),
                    ));
                }
            }
        }
    }
    out
}

/// Invariants 8 and 9: no two public occupants share a cell, and every
/// position is walkable. Riders are not on the ground, so they are left to
/// invariant 22.
pub fn check_cells(s: &Snapshot, nav: &NavGrid) -> Vec<Violation> {
    let mut out = Vec::new();
    let mut held: std::collections::BTreeMap<crate::nav::Cell, &CityId> = Default::default();
    for (id, o) in &s.occupants {
        let Some(p) = o.pos else { continue };
        if matches!(o.location, Location::Aboard { .. }) {
            continue;
        }
        if matches!(o.location, Location::Away) {
            out.push(v(9, s, format!("{id} is away but has a position")));
            continue;
        }
        let c = nav.cell_of(p);
        if !nav.walkable(c) {
            out.push(v(9, s, format!("{id} stands on an unwalkable cell {c:?}")));
        }
        if shares_capacity(&o.profile.kind)
            && let Some(other) = held.insert(c, id)
        {
            out.push(v(8, s, format!("{id} and {other} share {c:?}")));
        }
    }
    out
}

/// Invariant 10: no one moves more than five cells in a tick.
pub fn check_steps(before: &Snapshot, after: &Snapshot, nav: &NavGrid) -> Vec<Violation> {
    let limit = crate::world::STEPS_PER_TICK as i32;
    let mut out = Vec::new();
    for (id, o) in &after.occupants {
        let (Some(a), Some(b)) = (before.occupants.get(id).and_then(|x| x.pos), o.pos) else {
            continue;
        };
        let (ca, cb) = (nav.cell_of(a), nav.cell_of(b));
        let d = (ca.i - cb.i).abs().max((ca.j - cb.j).abs());
        if d > limit {
            out.push(v(10, after, format!("{id} moved {d} cells in one tick")));
        }
    }
    out
}

/// Invariant 12: every move in a tick, walked or steered, is at most five
/// steps, each one the grid allows from the last: adjacent, walkable,
/// between rooms only through a door span, never cutting a corner.
pub fn check_steer(before: &Snapshot, after: &Snapshot, nav: &NavGrid) -> Vec<Violation> {
    let limit = crate::world::STEPS_PER_TICK;
    let mut out = Vec::new();
    for (id, o) in &after.occupants {
        if o.trail.len() > limit {
            out.push(v(
                12,
                after,
                format!("{id} took {} cells in one tick", o.trail.len()),
            ));
        }
        let mut at = before
            .occupants
            .get(id)
            .and_then(|x| x.pos)
            .map(|p| nav.cell_of(p));
        for p in &o.trail {
            let next = nav.cell_of(*p);
            if let Some(prev) = at
                && !nav.can_step(prev, next)
            {
                out.push(v(
                    12,
                    after,
                    format!("{id} stepped from {prev:?} to {next:?}, which the grid forbids"),
                ));
            }
            at = Some(next);
        }
    }
    out
}

/// Invariant 14: entering a room means admission. Anyone queued for a room
/// stands outside it or in its doorway, never on its floor.
pub fn check_queued_outside(s: &Snapshot, nav: &NavGrid) -> Vec<Violation> {
    let mut out = Vec::new();
    for (id, o) in &s.occupants {
        let (Location::Waitlisted { room }, Some(p)) = (&o.location, o.pos) else {
            continue;
        };
        let c = nav.cell_of(p);
        if nav.room_at(c) == Some(room) && !nav.in_door_span(c) {
            out.push(v(
                14,
                s,
                format!("{id} is queued for {room} yet stands inside it at {c:?}"),
            ));
        }
    }
    out
}

/// Invariant 24: a seat is somewhere to sit, not a way through. A trail
/// enters a seat's cell only as its last cell, and only as the walk's
/// destination: nothing is left of the walk to go on with. One that set
/// off to leave after it got there (Depart comes after the walkers step)
/// has a fresh walk out, planned from the seat.
pub fn check_seat_trails(s: &Snapshot, nav: &NavGrid) -> Vec<Violation> {
    let mut out = Vec::new();
    for (id, o) in &s.occupants {
        let Some((last, before)) = o.trail.split_last() else {
            continue;
        };
        if let Some(p) = before.iter().find(|p| nav.is_seat_cell(nav.cell_of(**p))) {
            out.push(v(24, s, format!("{id} walked across the seat at {p:?}")));
        }
        let walks_on = o.walk.as_ref().is_some_and(|w| !w.path.is_empty())
            && !matches!(o.location, Location::Leaving { .. });
        if nav.is_seat_cell(nav.cell_of(*last)) && walks_on {
            out.push(v(
                24,
                s,
                format!("{id} stepped onto the seat at {last:?} on its way elsewhere"),
            ));
        }
    }
    out
}

/// Invariant 13: an anonymous observer never appears in the public
/// projection, and never holds a seat or a queue place. It holds no cell
/// either: cells are held only by occupants who share capacity.
pub fn check_observer_private(s: &Snapshot) -> Vec<Violation> {
    let observer = |o: &city_contracts::OccupantState| {
        matches!(
            o.profile.kind,
            OccupantKind::Human {
                tier: HumanTier::Observer
            }
        )
    };
    let mut out = Vec::new();
    let public = project(s, &Viewer::Public);
    let shown = public
        .rooms
        .iter()
        .flat_map(|r| r.occupants.iter().chain(&r.waiting))
        .chain(&public.in_transit)
        .chain(&public.aboard);
    for view in shown {
        if s.occupants.get(&view.id).is_some_and(observer) {
            out.push(v(
                13,
                s,
                format!("observer {} is in the public view", view.id),
            ));
        }
    }
    for (id, o) in s.occupants.iter().filter(|(_, o)| observer(o)) {
        if matches!(o.location, Location::InRoom { seat: Some(_), .. })
            || s.rooms
                .values()
                .any(|r| r.seats.values().any(|h| h.as_ref() == Some(id)))
        {
            out.push(v(13, s, format!("observer {id} holds a seat")));
        }
        if matches!(o.location, Location::Waitlisted { .. })
            || s.rooms.values().any(|r| r.waitlist.contains(id))
        {
            out.push(v(13, s, format!("observer {id} holds a queue place")));
        }
    }
    out
}

/// Whether `occ` may enter `room` in `s`: the admission rule, restated.
fn room_open(index: &PlaceIndex, s: &Snapshot, room: &PlaceId, occ: &CityId) -> bool {
    let info = &index.rooms[room];
    let state = &s.rooms[room];
    let present = load(s, room);
    let capacity = u64::from(info.capacity);
    if info.reserved.contains_key(occ) {
        return present < capacity;
    }
    let unclaimed = info
        .reserved
        .keys()
        .filter(|o| !state.occupants.contains(o))
        .count() as u64;
    present + unclaimed < capacity
}

/// Invariant 11: no capacity sits idle while a queue could use it. If a
/// queue's head could have entered a room of its chain at the end of one
/// tick and is still waiting after the next, that room admitted someone else
/// in the meantime (queues competing for one room are served in room-ID
/// order).
pub fn check_queues(
    before: &Snapshot,
    after: &Snapshot,
    events: &[Event],
    index: &PlaceIndex,
) -> Vec<Violation> {
    let mut out = Vec::new();
    for (room, r) in &before.rooms {
        let Some(head) = r.waitlist.first() else {
            continue;
        };
        let still = matches!(&after.occupants[head].location,
            Location::Waitlisted { room: w } if w == room);
        if !still {
            continue;
        }
        for c in &index.rooms[room].chain {
            let used = events
                .iter()
                .any(|e| matches!(&e.kind, EventKind::Admitted { room: a } if a == c));
            if room_open(index, before, c, head) && !used {
                out.push(v(
                    11,
                    after,
                    format!("{head} still waits for {room} while {c} stood open"),
                ));
            }
        }
    }
    out
}

/// Invariant 15: vehicles are kept in vehicle order (by line, direction,
/// then number, compared as a number), each once.
pub fn check_vehicle_order(s: &Snapshot) -> Vec<Violation> {
    s.vehicles
        .windows(2)
        .filter(|w| vehicle_key(&w[0]) >= vehicle_key(&w[1]))
        .map(|w| {
            v(
                15,
                s,
                format!("vehicle {} is listed before {}", w[0].id, w[1].id),
            )
        })
        .collect()
}

/// Invariant 18: vehicles on one track never overlap. Bodies are half-open
/// spans along the track, so a follower whose front is exactly at the rear
/// of the vehicle ahead does not overlap it.
pub fn check_vehicle_spacing(s: &Snapshot) -> Vec<Violation> {
    let mut out = Vec::new();
    for (k, a) in s.vehicles.iter().enumerate() {
        let Some(line) = s.manifest.lines.iter().find(|l| l.id == a.line) else {
            continue;
        };
        let length = i64::from(line.vehicle.length);
        let (a_from, a_to) = body(i64::from(a.along), length, a.direction);
        for b in s.vehicles[k + 1..]
            .iter()
            .filter(|b| b.line == a.line && b.direction == a.direction)
        {
            let (b_from, b_to) = body(i64::from(b.along), length, b.direction);
            if a_from < b_to && b_from < a_to {
                out.push(v(
                    18,
                    s,
                    format!(
                        "vehicles {} ({a_from}..{a_to}) and {} ({b_from}..{b_to}) overlap",
                        a.id, b.id
                    ),
                ));
            }
        }
    }
    out
}

/// Invariant 16: a vehicle's front only ever advances in its direction:
/// `along` never falls for an eastbound vehicle, nor rises for a westbound
/// one.
pub fn check_vehicle_progress(before: &Snapshot, after: &Snapshot) -> Vec<Violation> {
    let mut out = Vec::new();
    for now in &after.vehicles {
        let Some(then) = before.vehicles.iter().find(|x| x.id == now.id) else {
            continue;
        };
        let back = match now.direction {
            Direction::East => now.along < then.along,
            Direction::West => now.along > then.along,
        };
        if back {
            out.push(v(
                16,
                after,
                format!(
                    "vehicle {} went back from {} to {}",
                    now.id, then.along, now.along
                ),
            ));
        }
    }
    out
}

/// Invariant 17: no vehicle's footprint cell is held by a public walker.
/// Hidden occupants hold no cell, so they may be anywhere.
pub fn check_vehicle_footprints(s: &Snapshot, nav: &NavGrid, index: &PlaceIndex) -> Vec<Violation> {
    let mut out = Vec::new();
    if s.vehicles.is_empty() {
        return out;
    }
    let held: BTreeMap<Cell, &CityId> = s
        .occupants
        .iter()
        .filter(|(_, o)| !matches!(o.location, Location::Away))
        .filter(|(_, o)| shares_capacity(&o.profile.kind))
        .filter_map(|(id, o)| o.pos.map(|p| (nav.cell_of(p), id)))
        .collect();
    for vehicle in &s.vehicles {
        for c in footprint(index, nav, vehicle) {
            if let Some(who) = held.get(&c) {
                out.push(v(
                    17,
                    s,
                    format!("{who} holds {c:?} under vehicle {}", vehicle.id),
                ));
            }
        }
    }
    out
}

/// Invariants 19, 20 and 22, for riders and platform waiters.
///
/// - 19: a vehicle's public riders never exceed its capacity, each in a
///   slot of its own below it; hidden riders have no slot (`u32::MAX`).
/// - 20: each occupant is in exactly one place. Every rider a vehicle lists
///   is aboard that vehicle and listed once, by it alone; everyone aboard
///   names a vehicle that lists them; waiters wait at a stop of a line; and
///   neither riders nor waiters are queued for admission to a room.
/// - 22: riders hold no ground cell.
pub fn check_riders(s: &Snapshot) -> Vec<Violation> {
    let mut out = Vec::new();
    let mut listed: BTreeMap<&CityId, &CityId> = BTreeMap::new();
    for vehicle in &s.vehicles {
        let capacity = s
            .manifest
            .lines
            .iter()
            .find(|l| l.id == vehicle.line)
            .map_or(0, |l| l.vehicle.capacity);
        let mut slots = BTreeSet::new();
        for r in &vehicle.riders {
            if let Some(other) = listed.insert(r, &vehicle.id) {
                out.push(v(
                    20,
                    s,
                    format!("{r} is listed by {other} and {}", vehicle.id),
                ));
            }
            let Some(o) = s.occupants.get(r) else {
                out.push(v(20, s, format!("{} lists unknown {r}", vehicle.id)));
                continue;
            };
            let Location::Aboard { vehicle: on, slot } = &o.location else {
                out.push(v(
                    20,
                    s,
                    format!("{} lists {r}, who is {:?}", vehicle.id, o.location),
                ));
                continue;
            };
            if *on != vehicle.id {
                out.push(v(
                    20,
                    s,
                    format!("{} lists {r}, who rides {on}", vehicle.id),
                ));
            }
            if shares_capacity(&o.profile.kind) {
                if *slot >= capacity || !slots.insert(*slot) {
                    out.push(v(
                        19,
                        s,
                        format!(
                            "{r} rides {} in slot {slot} (capacity {capacity})",
                            vehicle.id
                        ),
                    ));
                }
            } else if *slot != u32::MAX {
                out.push(v(
                    19,
                    s,
                    format!("hidden {r} holds slot {slot} on {}", vehicle.id),
                ));
            }
        }
        if slots.len() as u64 > u64::from(capacity) {
            out.push(v(
                19,
                s,
                format!(
                    "{} carries {} public riders, capacity {capacity}",
                    vehicle.id,
                    slots.len()
                ),
            ));
        }
    }
    let stops: BTreeSet<&PlaceId> = s
        .manifest
        .lines
        .iter()
        .flat_map(|l| &l.stops)
        .map(|stop| &stop.id)
        .collect();
    for (id, o) in &s.occupants {
        match &o.location {
            Location::Aboard { vehicle, .. } => {
                if listed.get(id) != Some(&vehicle) {
                    out.push(v(
                        20,
                        s,
                        format!("{id} rides {vehicle}, which does not list them"),
                    ));
                }
                if o.pos.is_some() {
                    out.push(v(22, s, format!("{id} rides {vehicle} yet holds a cell")));
                }
            }
            Location::WaitingFor { stop, .. } if !stops.contains(stop) => {
                out.push(v(20, s, format!("{id} waits at {stop}, no line's stop")));
            }
            _ => {}
        }
        if matches!(
            o.location,
            Location::Aboard { .. } | Location::WaitingFor { .. }
        ) && s.admission_queue.contains(id)
        {
            out.push(v(
                20,
                s,
                format!("{id} is {:?} and queued for admission", o.location),
            ));
        }
    }
    out
}

/// Invariant 21: riders board and alight only on ticks when their vehicle
/// stands at a stop with its doors open (at the stop they step off at).
pub fn check_doors_open(after: &Snapshot, events: &[Event]) -> Vec<Violation> {
    let mut out = Vec::new();
    for e in events {
        let (vehicle, at) = match &e.kind {
            EventKind::Boarded { vehicle } => (vehicle, None),
            EventKind::Alighted { vehicle, stop } => (vehicle, Some(stop)),
            _ => continue,
        };
        let open = after.vehicles.iter().find(|x| &x.id == vehicle).is_some_and(|x| {
            matches!(&x.status, city_contracts::VehicleStatus::Standing { stop, doors_open_until }
                if e.tick < *doors_open_until && at.is_none_or(|at| at == stop))
        });
        if !open {
            out.push(v(
                21,
                after,
                format!(
                    "{:?} got on or off {vehicle} while its doors were shut",
                    e.occupant
                ),
            ));
        }
    }
    out
}

/// Invariant 23: waiters, destinations and arrivals by tram, against the
/// transit state the snapshot does not carry ([`Riders`]).
///
/// - Every waiter waits for a direction, has a place in line
///   (`waiting_since`), and, with a layout, stands on that direction's
///   platform; no one else has a place in line.
/// - Every rider and waiter has a destination: a stop ahead of it (for a
///   rider, ahead of its vehicle's centre, or the stop it stands at), or
///   the far portal. No one else has one but a player queued at a portal,
///   given the stop of the platform it joins for.
/// - Every arrival queued at a portal is arriving, off the ground and
///   walking nowhere, queued once and for admission nowhere, and bound for
///   a room; every arrival bound for a room is queued or aboard. In tram
///   mode the converse holds too: an arriving occupant off the ground,
///   walking nowhere and queued for admission nowhere is queued at a
///   portal.
/// - Every vehicle holding its doors open at the last stop stands there
///   with them open past the tick they were due to close.
pub fn check_waiters(s: &Snapshot, riders: &Riders, nav: Option<&NavGrid>) -> Vec<Violation> {
    let mut out = Vec::new();
    let stop_at = |stop: &PlaceId| -> Option<i64> {
        s.manifest
            .lines
            .iter()
            .flat_map(|l| &l.stops)
            .find(|x| &x.id == stop)
            .map(|x| i64::from(x.at))
    };
    let sign = |d: Direction| match d {
        Direction::East => 1,
        Direction::West => -1,
    };
    for (id, o) in &s.occupants {
        match &o.location {
            Location::WaitingFor { stop, direction } => {
                let Some(d) = direction else {
                    out.push(v(23, s, format!("{id} waits at {stop} for no direction")));
                    continue;
                };
                if !riders.waiting_since.contains_key(id) {
                    out.push(v(
                        23,
                        s,
                        format!("{id} waits at {stop} with no place in line"),
                    ));
                }
                if let Some(nav) = nav {
                    let on = o.pos.map(|p| nav.cell_of(p)).and_then(|c| nav.room_at(c));
                    if on.is_none() || on != platform_in(s, stop, *d) {
                        out.push(v(23, s, format!("{id} waits at {stop} off its platform")));
                    }
                }
                match riders.destinations.get(id) {
                    None => out.push(v(23, s, format!("{id} waits with no destination"))),
                    Some(Destination::Stop(to)) => {
                        let ahead = stop_at(to)
                            .zip(stop_at(stop))
                            .is_some_and(|(to, from)| sign(*d) * (to - from) > 0);
                        if !ahead {
                            out.push(v(
                                23,
                                s,
                                format!("{id} waits at {stop} bound for {to}, not ahead"),
                            ));
                        }
                    }
                    Some(Destination::RideOut) => {}
                }
            }
            Location::Aboard { vehicle, .. } => {
                let Some(x) = s.vehicles.iter().find(|x| &x.id == vehicle) else {
                    continue;
                };
                match riders.destinations.get(id) {
                    None => out.push(v(
                        23,
                        s,
                        format!("{id} rides {vehicle} with no destination"),
                    )),
                    Some(Destination::Stop(to)) => {
                        let length = s
                            .manifest
                            .lines
                            .iter()
                            .find(|l| l.id == x.line)
                            .map_or(0, |l| i64::from(l.vehicle.length));
                        let centre = centre_along(i64::from(x.along), length, x.direction);
                        let standing_there = matches!(&x.status,
                            city_contracts::VehicleStatus::Standing { stop, .. } if stop == to);
                        let ahead =
                            stop_at(to).is_some_and(|at| sign(x.direction) * (at - centre) > 0);
                        if !(ahead || standing_there) {
                            out.push(v(
                                23,
                                s,
                                format!("{id} rides {vehicle} bound for {to}, behind it"),
                            ));
                        }
                    }
                    Some(Destination::RideOut) => {}
                }
            }
            _ => {}
        }
    }
    for id in riders.waiting_since.keys() {
        if !matches!(
            s.occupants.get(id).map(|o| &o.location),
            Some(Location::WaitingFor { .. })
        ) {
            out.push(v(
                23,
                s,
                format!("{id} has a place in line but is not waiting"),
            ));
        }
    }
    let queued_at_portals: BTreeSet<&CityId> = riders.arrival_queues.values().flatten().collect();
    for (id, to) in &riders.destinations {
        let placed = matches!(
            s.occupants.get(id).map(|o| &o.location),
            Some(Location::WaitingFor { .. } | Location::Aboard { .. })
        );
        let joining = queued_at_portals.contains(id)
            && matches!(to, Destination::Stop(stop) if stop_at(stop).is_some());
        if !placed && !joining {
            out.push(v(
                23,
                s,
                format!("{id} has a destination but neither waits nor rides"),
            ));
        }
    }
    let mut queued = BTreeSet::new();
    for queue in riders.arrival_queues.values() {
        for id in queue {
            if !queued.insert(id) {
                out.push(v(23, s, format!("{id} is queued at a portal twice")));
            }
            let ok = s.occupants.get(id).is_some_and(|o| {
                matches!(o.location, Location::Arriving { .. })
                    && o.pos.is_none()
                    && o.walk.is_none()
            });
            if !ok || s.admission_queue.contains(id) || !riders.arrivals.contains_key(id) {
                out.push(v(23, s, format!("{id} is queued at a portal out of place")));
            }
        }
    }
    for (vehicle, due) in &riders.holds {
        let held = s.vehicles.iter().any(|x| {
            &x.id == vehicle
                && matches!(x.status, city_contracts::VehicleStatus::Standing { doors_open_until, .. }
                    if doors_open_until > *due)
        });
        if !held {
            out.push(v(
                23,
                s,
                format!("{vehicle} is held past {due} but not standing open"),
            ));
        }
    }
    for id in riders.arrivals.keys() {
        let aboard = matches!(
            s.occupants.get(id).map(|o| &o.location),
            Some(Location::Aboard { .. })
        );
        if !aboard && !queued.contains(id) {
            out.push(v(
                23,
                s,
                format!("{id} arrives by tram but is neither queued nor aboard"),
            ));
        }
    }
    if s.manifest.city.arrivals == Arrivals::Tram {
        for (id, o) in &s.occupants {
            let nowhere = matches!(o.location, Location::Arriving { .. })
                && o.pos.is_none()
                && o.walk.is_none()
                && !s.admission_queue.contains(id);
            if nowhere && !queued.contains(id) {
                out.push(v(
                    23,
                    s,
                    format!("{id} is arriving from nowhere: not on the ground, walking, or queued"),
                ));
            }
        }
    }
    out
}

/// Every per-tick check of `world`'s last tick, from the snapshot before
/// it and the tick's events: [`check_all_with_nav`] and the transit state
/// ([`check_waiters`]).
pub fn check_world(before: &Snapshot, world: &World, events: &[Event]) -> Vec<Violation> {
    let mut out = check_all_with_nav(before, world.snapshot(), events, world.nav(), world.index());
    out.extend(check_waiters(world.snapshot(), world.riders(), world.nav()));
    out.extend(check_using(world));
    out
}

/// Invariant 25: a use is held only where it may be. No one uses anything
/// while not in a room, so no one is both using and aboard or waiting; a use
/// names a target and anchor that still resolve, and its user stands where
/// that anchor asks (its cell, or a facing neighbour for reading and
/// using); a seat in use is held by its user; and no anchor has more public
/// users than it holds.
pub fn check_using(world: &World) -> Vec<Violation> {
    let s = world.snapshot();
    let mut out = Vec::new();
    for id in s.occupants.keys() {
        if let Err(why) = crate::interact::use_holds(world, id) {
            out.push(v(25, s, format!("{id} {why}")));
        }
    }
    for (target, anchor) in crate::interact::overfull_anchors(world) {
        out.push(v(
            25,
            s,
            format!("anchor {anchor} of {target} has more users than it holds"),
        ));
    }
    out
}

/// Every per-tick check, including movement when the world has a layout.
pub fn check_all_with_nav(
    before: &Snapshot,
    after: &Snapshot,
    events: &[Event],
    nav: Option<&NavGrid>,
    index: &PlaceIndex,
) -> Vec<Violation> {
    let mut out = check_all(before, after, events);
    if let Some(nav) = nav {
        out.extend(check_cells(after, nav));
        out.extend(check_vehicle_footprints(after, nav, index));
        out.extend(check_steps(before, after, nav));
        out.extend(check_steer(before, after, nav));
        out.extend(check_queued_outside(after, nav));
        out.extend(check_seat_trails(after, nav));
    }
    out.extend(check_queues(before, after, events, index));
    out
}

/// Every per-tick check at once.
pub fn check_all(before: &Snapshot, after: &Snapshot, events: &[Event]) -> Vec<Violation> {
    let mut out = check_consistency(after);
    out.extend(check_capacity_over_tick(before, after, events));
    out.extend(check_reserved(after));
    out.extend(check_privacy(after));
    out.extend(check_inference(after));
    out.extend(check_observer_private(after));
    out.extend(check_expiry(after));
    out.extend(check_unknown_task(after));
    out.extend(check_release(before, after, events));
    out.extend(check_vehicle_order(after));
    out.extend(check_vehicle_progress(before, after));
    out.extend(check_vehicle_spacing(after));
    out.extend(check_riders(after));
    out.extend(check_doors_open(after, events));
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{World, synth::synthetic};
    use city_contracts::CityId;

    fn run_to(ticks: u64) -> World {
        let (m, f) = synthetic(40, 2);
        let mut w = World::new(m, f, 2).unwrap();
        w.run(ticks);
        w
    }

    #[test]
    fn clean_synthetic_run_has_no_violations() {
        let (m, f) = synthetic(120, 5);
        let mut w = World::new(m, f, 5).unwrap();
        for _ in 0..100 {
            let before = w.snapshot().clone();
            let ev = w.step();
            let v = check_all(&before, w.snapshot(), &ev);
            assert!(v.is_empty(), "{v:?}");
        }
    }

    #[test]
    fn capacity_checker_catches_overfull_room() {
        let w = run_to(10);
        let mut s = w.snapshot().clone();
        let room = s.rooms.values_mut().next().unwrap();
        for i in 0..100 {
            room.occupants.push(CityId::from(format!("planted:{i}")));
        }
        assert!(check_capacity(&s).iter().any(|v| v.invariant == 1));
    }

    #[test]
    fn reserved_checker_catches_a_stranger() {
        let w = run_to(10);
        let mut s = w.snapshot().clone();
        let seat = {
            let room = &mut s.manifest.city.districts[0].facilities[0].rooms[0];
            room.seats[0].reserved_for = Some(CityId::from("agent:owner"));
            room.seats[0].id.clone()
        };
        let room_id = s.manifest.city.districts[0].facilities[0].rooms[0]
            .id
            .clone();
        *s.rooms
            .get_mut(&room_id)
            .unwrap()
            .seats
            .get_mut(&seat)
            .unwrap() = Some(CityId::from("agent:stranger"));
        assert!(check_reserved(&s).iter().any(|v| v.invariant == 2));
    }

    #[test]
    fn privacy_checker_catches_a_planted_personal_agent() {
        let w = run_to(25);
        let s = w.snapshot();
        assert!(check_privacy(s).is_empty());
        let agent = s
            .occupants
            .values()
            .find(|o| {
                matches!(
                    o.profile.kind,
                    city_contracts::OccupantKind::PersonalAgent { .. }
                )
            })
            .expect("synthetic city has personal agents");
        let mut p = crate::project(s, &city_contracts::Viewer::Public);
        let mut planted = crate::project(s, &city_contracts::Viewer::Operator).rooms[0]
            .occupants
            .first()
            .cloned()
            .expect("someone present");
        planted.id = agent.profile.id.clone();
        planted.kind = agent.profile.kind.clone();
        p.rooms[0].occupants.push(planted);
        assert!(
            check_projection(s, &city_contracts::Viewer::Public, &p)
                .iter()
                .any(|v| v.invariant == 3)
        );
    }

    #[test]
    fn expiry_checker_catches_a_stale_value_shown_as_current() {
        let w = run_to(30);
        let mut s = w.snapshot().clone();
        let (_, o) = s
            .occupants
            .iter_mut()
            .find(|(_, o)| o.presence.task.is_some())
            .expect("someone has a task");
        o.presence.task.as_mut().unwrap().stamp.expires_at = 0;
        o.shown.task = city_contracts::ShownTask::Working;
        assert!(check_expiry(&s).iter().any(|v| v.invariant == 4));
    }

    #[test]
    fn unknown_task_checker_catches_working_without_a_task() {
        let w = run_to(30);
        let mut s = w.snapshot().clone();
        let (_, o) = s
            .occupants
            .iter_mut()
            .find(|(_, o)| !matches!(o.location, city_contracts::Location::Away))
            .expect("someone present");
        o.presence.task = None;
        o.shown.process = city_contracts::ShownProcess::Running;
        o.shown.task = city_contracts::ShownTask::Working;
        assert!(check_unknown_task(&s).iter().any(|v| v.invariant == 5));
    }

    #[test]
    fn release_checker_catches_a_kept_seat() {
        let mut w = run_to(1);
        for _ in 0..200 {
            let before = w.snapshot().clone();
            let ev = w.step();
            let departed = ev.iter().find_map(|e| match &e.kind {
                city_contracts::EventKind::Departed { from: Some(_), .. } => e.occupant.clone(),
                _ => None,
            });
            let Some(id) = departed else { continue };
            let held = match &before.occupants[&id].location {
                city_contracts::Location::InRoom {
                    room,
                    seat: Some(seat),
                } => Some((room.clone(), seat.clone())),
                _ => None,
            };
            let Some((room, seat)) = held else { continue };
            let mut after = w.snapshot().clone();
            *after
                .rooms
                .get_mut(&room)
                .unwrap()
                .seats
                .get_mut(&seat)
                .unwrap() = Some(id);
            assert!(
                check_release(&before, &after, &ev)
                    .iter()
                    .any(|v| v.invariant == 7)
            );
            return;
        }
        panic!("no seated departure within 200 ticks");
    }

    #[test]
    fn inference_checker_catches_a_hidden_occupant_holding_a_seat() {
        let w = run_to(25);
        let mut s = w.snapshot().clone();
        let hidden = s
            .occupants
            .iter()
            .find(|(_, o)| !crate::project::visible(&city_contracts::Viewer::Public, o))
            .map(|(id, _)| id.clone())
            .expect("synthetic city has hidden occupants");
        let (room_id, seat) = s
            .rooms
            .iter()
            .find_map(|(r, st)| {
                st.seats
                    .iter()
                    .find(|(_, h)| h.is_none())
                    .map(|(seat, _)| (r.clone(), seat.clone()))
            })
            .expect("a free seat");
        *s.rooms
            .get_mut(&room_id)
            .unwrap()
            .seats
            .get_mut(&seat)
            .unwrap() = Some(hidden);
        assert!(
            crate::invariants::check_inference(&s)
                .iter()
                .any(|v| v.invariant == 3)
        );
    }

    // ---- Movement (8–11) ----

    fn walking_world(ticks: u64) -> World {
        use city_contracts::{Command, FeedEntry, FeedHeader};
        let entries = (0..4)
            .map(|n| FeedEntry {
                at: 1,
                fixture: true,
                command: Command::Arrive {
                    occupant: format!("person:{n}").into(),
                    room: Some("room:p".into()),
                    profile: Some(city_contracts::OccupantProfile {
                        id: format!("person:{n}").into(),
                        kind: city_contracts::OccupantKind::Human {
                            tier: city_contracts::HumanTier::Registered,
                        },
                        display_name: format!("P{n}"),
                        role: String::new(),
                        department: None,
                        home: None,
                        work: None,
                        shared_with: Default::default(),
                        appearance: Default::default(),
                    }),
                    player: false,
                },
            })
            .collect();
        let feed = crate::Feed {
            header: FeedHeader {
                schema_version: 1,
                source: "fixture:test".into(),
                fixture: true,
                description: String::new(),
            },
            entries,
        };
        let mut w = World::new(crate::index::fixtures::layout_base(), feed, 1).unwrap();
        w.run(ticks);
        w
    }

    #[test]
    fn cell_checkers_catch_sharing_and_walls() {
        let w = walking_world(3);
        let nav = w.nav().unwrap();
        assert!(check_cells(w.snapshot(), nav).is_empty());
        let mut s = w.snapshot().clone();
        let ids: Vec<CityId> = s.occupants.keys().cloned().collect();
        let p0 = s.occupants[&ids[0]].pos;
        s.occupants.get_mut(&ids[1]).unwrap().pos = p0;
        assert!(check_cells(&s, nav).iter().any(|v| v.invariant == 8));
        let mut s = w.snapshot().clone();
        s.occupants.get_mut(&ids[0]).unwrap().pos = Some(city_contracts::Point { x: 600, z: 100 });
        assert!(check_cells(&s, nav).iter().any(|v| v.invariant == 9));
    }

    #[test]
    fn step_checker_catches_a_jump() {
        let w = walking_world(3);
        let nav = w.nav().unwrap();
        let before = w.snapshot().clone();
        let mut after = before.clone();
        let id = after.occupants.keys().next().unwrap().clone();
        let p = after.occupants[&id].pos.unwrap();
        after.occupants.get_mut(&id).unwrap().pos = Some(city_contracts::Point {
            x: p.x + 500,
            z: p.z,
        });
        assert!(
            check_steps(&before, &after, nav)
                .iter()
                .any(|v| v.invariant == 10)
        );
        assert!(check_steps(&before, &before, nav).is_empty());
    }

    #[test]
    fn queue_checker_catches_a_head_left_waiting_beside_space() {
        let w = walking_world(3);
        let mut s = w.snapshot().clone();
        let id = s.occupants.keys().next().unwrap().clone();
        let room = city_contracts::PlaceId::from("room:a");
        s.rooms.get_mut(&room).unwrap().waitlist.push(id.clone());
        for r in s.rooms.values_mut() {
            r.occupants.retain(|o| o != &id);
        }
        s.occupants.get_mut(&id).unwrap().location = Location::Waitlisted { room: room.clone() };
        let index = w.index();
        assert!(
            check_queues(&s, &s, &[], index)
                .iter()
                .any(|v| v.invariant == 11)
        );
    }

    #[test]
    fn seat_checker_catches_a_walk_across_a_seat() {
        use city_contracts::{Walk, WalkPurpose};
        let w = walking_world(2);
        let nav = w.nav().unwrap();
        // `seat:a1` is at (100, 100), cell (4, 4).
        let seat = crate::nav::Cell { i: 4, j: 4 };
        assert!(nav.is_seat_cell(seat));
        let at = |i: i32, j: i32| nav.centre(crate::nav::Cell { i, j });
        let id = w.snapshot().occupants.keys().next().unwrap().clone();
        let mut s = w.snapshot().clone();
        let o = s.occupants.get_mut(&id).unwrap();
        o.walk = None;
        o.trail = vec![at(4, 5), at(4, 4), at(4, 3)];
        o.pos = Some(at(4, 3));
        assert!(
            check_seat_trails(&s, nav).iter().any(|v| v.invariant == 24),
            "across the seat"
        );
        let o = s.occupants.get_mut(&id).unwrap();
        o.trail = vec![at(4, 5), at(4, 4)];
        o.pos = Some(at(4, 4));
        assert!(check_seat_trails(&s, nav).is_empty(), "onto it, to sit");
        let o = s.occupants.get_mut(&id).unwrap();
        o.walk = Some(Walk {
            path: vec![at(4, 3)],
            purpose: WalkPurpose::ToSpot,
            blocked: 0,
        });
        assert!(
            check_seat_trails(&s, nav).iter().any(|v| v.invariant == 24),
            "onto it, and on beyond next tick"
        );
        let o = s.occupants.get_mut(&id).unwrap();
        o.walk = None;
        o.trail = vec![at(4, 3), at(4, 2)];
        o.pos = Some(at(4, 2));
        assert!(check_seat_trails(&s, nav).is_empty(), "off it");
    }

    // ---- Players (12, 13) ----

    #[test]
    fn steer_checker_catches_a_wall_crossing_and_a_long_trail() {
        use city_contracts::Point;
        let mut w = walking_world(2);
        let before = w.snapshot().clone();
        w.step();
        let nav = w.nav().unwrap();
        assert!(
            check_steer(&before, w.snapshot(), nav).is_empty(),
            "a real tick"
        );
        let at = |i: i32, j: i32| nav.centre(crate::nav::Cell { i, j });
        let id = before.occupants.keys().next().unwrap().clone();
        let mut b = before.clone();
        for o in b.occupants.values_mut() {
            o.trail.clear();
        }
        b.occupants.get_mut(&id).unwrap().pos = Some(at(1, 15));
        let mut a = b.clone();
        let o = a.occupants.get_mut(&id).unwrap();
        o.trail = vec![at(1, 16)];
        o.pos = Some(at(1, 16));
        assert!(
            check_steer(&b, &a, nav).iter().any(|v| v.invariant == 12),
            "through the wall between the rooms"
        );
        let o = a.occupants.get_mut(&id).unwrap();
        o.trail = vec![at(7, 15), at(7, 16)];
        assert!(
            check_steer(&b, &a, nav).iter().any(|v| v.invariant == 12),
            "not adjacent"
        );
        let mut ok = b.clone();
        let o = ok.occupants.get_mut(&id).unwrap();
        o.pos = Some(at(7, 14));
        let mut after = ok.clone();
        let o = after.occupants.get_mut(&id).unwrap();
        o.trail = (15..=20).map(|j| at(7, j)).collect::<Vec<Point>>();
        o.pos = o.trail.last().copied();
        assert!(
            check_steer(&ok, &after, nav)
                .iter()
                .any(|v| v.invariant == 12 && v.detail.contains("6 cells")),
            "{:?}",
            check_steer(&ok, &after, nav)
        );
        after.occupants.get_mut(&id).unwrap().trail.truncate(5);
        after.occupants.get_mut(&id).unwrap().pos = Some(at(7, 19));
        assert!(
            check_steer(&ok, &after, nav).is_empty(),
            "five steps through the door"
        );
    }

    #[test]
    fn observer_checker_catches_a_seat_or_a_queue_place() {
        let w = walking_world(3);
        let base = w.snapshot().clone();
        let id = base.occupants.keys().next().unwrap().clone();
        let mut s = base.clone();
        {
            let o = s.occupants.get_mut(&id).unwrap();
            o.profile.kind = city_contracts::OccupantKind::Human {
                tier: HumanTier::Observer,
            };
        }
        for r in s.rooms.values_mut() {
            r.occupants.retain(|o| o != &id);
        }
        let clean = s.clone();
        assert!(check_observer_private(&clean).is_empty());
        let room = PlaceId::from("room:a");
        let seat = PlaceId::from("seat:a1");
        s.occupants.get_mut(&id).unwrap().location = Location::InRoom {
            room: room.clone(),
            seat: Some(seat.clone()),
        };
        let r = s.rooms.get_mut(&room).unwrap();
        r.occupants.push(id.clone());
        *r.seats.get_mut(&seat).unwrap() = Some(id.clone());
        assert!(check_observer_private(&s).iter().any(|v| v.invariant == 13));
        let mut q = clean.clone();
        q.occupants.get_mut(&id).unwrap().location = Location::Waitlisted { room: room.clone() };
        q.rooms.get_mut(&room).unwrap().waitlist.push(id.clone());
        assert!(check_observer_private(&q).iter().any(|v| v.invariant == 13));
    }

    #[test]
    fn reserved_checker_covers_players() {
        let w = walking_world(3);
        let mut s = w.snapshot().clone();
        s.manifest.city.districts[0].facilities[0].rooms[0].seats[0].reserved_for =
            Some(CityId::from("agent:owner"));
        *s.rooms
            .get_mut(&PlaceId::from("room:a"))
            .unwrap()
            .seats
            .get_mut(&PlaceId::from("seat:a1"))
            .unwrap() = Some(CityId::from("person:you"));
        assert!(check_reserved(&s).iter().any(|v| v.invariant == 2));
    }

    // ---- Vehicles (15–17) ----

    fn tram_world(ticks: u64) -> World {
        let feed = crate::Feed {
            header: city_contracts::FeedHeader {
                schema_version: 1,
                source: "fixture:test".into(),
                fixture: true,
                description: String::new(),
            },
            entries: Vec::new(),
        };
        let mut w = World::new(crate::index::fixtures::tram_street(), feed, 1).unwrap();
        w.run(ticks);
        w
    }

    #[test]
    fn vehicle_checkers_catch_disorder_and_a_step_back() {
        // At tick 32 east:1 runs at 1400 and west:1 at 0.
        let w = tram_world(32);
        let s = w.snapshot();
        assert_eq!(s.vehicles.len(), 2);
        assert!(check_vehicle_order(s).is_empty());
        let mut swapped = s.clone();
        swapped.vehicles.reverse();
        assert!(
            check_vehicle_order(&swapped)
                .iter()
                .any(|v| v.invariant == 15)
        );
        let mut twice = s.clone();
        twice.vehicles[1] = twice.vehicles[0].clone();
        assert!(
            check_vehicle_order(&twice)
                .iter()
                .any(|v| v.invariant == 15)
        );

        let before = tram_world(31).snapshot().clone();
        assert!(check_vehicle_progress(&before, s).is_empty());
        let mut east_back = s.clone();
        east_back.vehicles[0].along = before.vehicles[0].along - 25;
        assert!(
            check_vehicle_progress(&before, &east_back)
                .iter()
                .any(|v| v.invariant == 16)
        );
        let mut west_back = s.clone();
        west_back.vehicles[1].along = before.vehicles[1].along + 25;
        assert!(
            check_vehicle_progress(&before, &west_back)
                .iter()
                .any(|v| v.invariant == 16)
        );
    }

    #[test]
    fn vehicle_order_compares_numbers_as_numbers() {
        let w = tram_world(32);
        let mut s = w.snapshot().clone();
        let mut nine = s.vehicles[0].clone();
        nine.id = "vehicle:boulevard:east:9".into();
        let mut ten = nine.clone();
        ten.id = "vehicle:boulevard:east:10".into();
        s.vehicles = vec![nine.clone(), ten.clone()];
        assert!(check_vehicle_order(&s).is_empty(), "9 comes before 10");
        s.vehicles = vec![ten, nine];
        assert!(check_vehicle_order(&s).iter().any(|v| v.invariant == 15));
    }

    #[test]
    fn spacing_checker_catches_overlapping_bodies_on_one_track() {
        // At tick 32 east:1's body spans 200..1400 (1200 cm long).
        let w = tram_world(32);
        let s = w.snapshot();
        assert!(check_vehicle_spacing(s).is_empty());
        let follower = |along: i32| {
            let mut s = s.clone();
            let mut v = s.vehicles[0].clone();
            v.id = "vehicle:boulevard:east:2".into();
            v.along = along;
            s.vehicles.insert(1, v);
            assert!(check_vehicle_order(&s).is_empty());
            s
        };
        // A follower capped exactly at the leader's rear touches, not overlaps.
        assert!(check_vehicle_spacing(&follower(200)).is_empty());
        assert!(
            check_vehicle_spacing(&follower(201))
                .iter()
                .any(|v| v.invariant == 18)
        );
        // The other track's vehicle, level with it, is no overlap.
        let mut level = s.clone();
        level.vehicles[1].along = level.vehicles[0].along;
        assert!(check_vehicle_spacing(&level).is_empty());
    }

    #[test]
    fn footprint_checker_catches_a_walker_under_a_vehicle() {
        use city_contracts::{
            HumanTier, OccupantProfile, OccupantState, Point, PresenceRecord, ShownPresence,
        };
        // At tick 34 east:1 stands centred on the stop, over x 1400–2600.
        let w = tram_world(34);
        let nav = w.nav().unwrap();
        assert!(check_vehicle_footprints(w.snapshot(), nav, w.index()).is_empty());
        let plant = |tier: HumanTier| {
            let mut s = w.snapshot().clone();
            let id = CityId::from("person:under");
            s.occupants.insert(
                id.clone(),
                OccupantState {
                    profile: OccupantProfile {
                        id,
                        kind: OccupantKind::Human { tier },
                        display_name: "Under".into(),
                        role: String::new(),
                        department: None,
                        home: None,
                        work: None,
                        shared_with: Default::default(),
                        appearance: Default::default(),
                    },
                    location: Location::Arriving {
                        room: "room:street".into(),
                    },
                    presence: PresenceRecord::default(),
                    shown: ShownPresence::default(),
                    pos: Some(Point { x: 2012, z: 312 }),
                    facing: 0,
                    walk: None,
                    trail: Vec::new(),
                    goal: None,
                    using: None,
                },
            );
            s
        };
        let public = plant(HumanTier::Registered);
        assert!(
            check_vehicle_footprints(&public, nav, w.index())
                .iter()
                .any(|v| v.invariant == 17)
        );
        // An observer holds no cell, so none is under the tram.
        let hidden = plant(HumanTier::Observer);
        assert!(check_vehicle_footprints(&hidden, nav, w.index()).is_empty());
    }

    // ---- Riders (19–22) ----

    fn rider(id: &str, kind: OccupantKind, location: Location) -> city_contracts::OccupantState {
        city_contracts::OccupantState {
            profile: city_contracts::OccupantProfile {
                id: id.into(),
                kind,
                display_name: id.into(),
                role: String::new(),
                department: None,
                home: None,
                work: None,
                shared_with: Default::default(),
                appearance: Default::default(),
            },
            location,
            presence: city_contracts::PresenceRecord::default(),
            shown: city_contracts::ShownPresence::default(),
            pos: None,
            facing: 0,
            walk: None,
            trail: Vec::new(),
            goal: None,
            using: None,
        }
    }

    const EAST_1: &str = "vehicle:boulevard:east:1";

    fn aboard(slot: u32) -> Location {
        Location::Aboard {
            vehicle: EAST_1.into(),
            slot,
        }
    }

    fn public() -> OccupantKind {
        OccupantKind::Human {
            tier: HumanTier::Registered,
        }
    }

    /// East:1 (at tick 32, running, capacity 1) carrying a public rider in
    /// slot 0 and a hidden one with no slot.
    fn carrying() -> Snapshot {
        let mut s = tram_world(32).snapshot().clone();
        s.manifest.lines[0].vehicle.capacity = 1;
        for (id, kind, slot) in [
            ("person:a", public(), 0),
            (
                "pa:b",
                OccupantKind::PersonalAgent {
                    owner: "person:a".into(),
                },
                u32::MAX,
            ),
        ] {
            s.occupants.insert(id.into(), rider(id, kind, aboard(slot)));
            s.vehicles[0].riders.push(id.into());
        }
        assert_eq!(s.vehicles[0].id.as_str(), EAST_1);
        s
    }

    fn has(violations: Vec<Violation>, invariant: u8) -> bool {
        violations.iter().any(|v| v.invariant == invariant)
    }

    #[test]
    fn rider_checker_catches_an_overload_and_a_bad_slot() {
        let s = carrying();
        assert!(check_riders(&s).is_empty(), "{:?}", check_riders(&s));
        let mut over = s.clone();
        over.occupants
            .insert("person:c".into(), rider("person:c", public(), aboard(1)));
        over.vehicles[0].riders.push("person:c".into());
        assert!(
            has(check_riders(&over), 19),
            "two public riders, capacity 1"
        );
        let mut shared = s.clone();
        shared.manifest.lines[0].vehicle.capacity = 2;
        shared
            .occupants
            .insert("person:c".into(), rider("person:c", public(), aboard(0)));
        shared.vehicles[0].riders.push("person:c".into());
        assert!(has(check_riders(&shared), 19), "two riders in slot 0");
        let mut slotted = s.clone();
        slotted
            .occupants
            .get_mut(&CityId::from("pa:b"))
            .unwrap()
            .location = aboard(3);
        assert!(
            has(check_riders(&slotted), 19),
            "a hidden rider with a slot"
        );
    }

    #[test]
    fn rider_checker_catches_an_occupant_in_two_places_or_none() {
        let s = carrying();
        let mut unlisted = s.clone();
        unlisted.vehicles[0]
            .riders
            .retain(|r| r.as_str() != "person:a");
        assert!(has(check_riders(&unlisted), 20), "aboard but not listed");
        let mut listed = s.clone();
        listed
            .occupants
            .get_mut(&CityId::from("person:a"))
            .unwrap()
            .location = Location::Away;
        assert!(has(check_riders(&listed), 20), "listed but away");
        let mut twice = s.clone();
        twice.vehicles[1].riders.push("person:a".into());
        assert!(has(check_riders(&twice), 20), "listed by two vehicles");
        let mut ghost = s.clone();
        ghost
            .occupants
            .get_mut(&CityId::from("person:a"))
            .unwrap()
            .location = Location::Aboard {
            vehicle: "vehicle:boulevard:east:9".into(),
            slot: 0,
        };
        assert!(
            has(check_riders(&ghost), 20),
            "aboard a vehicle not on the line"
        );
        let mut nowhere = s.clone();
        nowhere.occupants.insert(
            "person:w".into(),
            rider(
                "person:w",
                public(),
                Location::WaitingFor {
                    stop: "stop:nowhere".into(),
                    direction: None,
                },
            ),
        );
        assert!(has(check_riders(&nowhere), 20), "waiting at no stop");
        let mut queued = s.clone();
        queued.occupants.insert(
            "person:w".into(),
            rider(
                "person:w",
                public(),
                Location::WaitingFor {
                    stop: "stop:mid".into(),
                    direction: None,
                },
            ),
        );
        assert!(check_riders(&queued).is_empty());
        queued.admission_queue.push("person:w".into());
        assert!(
            has(check_riders(&queued), 20),
            "waiting and queued for a room"
        );
    }

    #[test]
    fn rider_checker_catches_a_rider_on_the_ground_and_cells_ignore_riders() {
        let mut s = carrying();
        let nav_world = tram_world(32);
        let nav = nav_world.nav().unwrap();
        let spot = city_contracts::Point { x: 512, z: 112 };
        for id in ["person:a", "pa:b"] {
            s.occupants.get_mut(&CityId::from(id)).unwrap().pos = Some(spot);
        }
        assert!(has(check_riders(&s), 22), "a rider holds a ground cell");
        s.occupants
            .get_mut(&CityId::from("pa:b"))
            .unwrap()
            .profile
            .kind = public();
        assert!(!has(check_cells(&s, nav), 8), "riders share no cells");
    }

    #[test]
    fn doors_checker_catches_boarding_a_moving_vehicle() {
        let event = |kind: EventKind, tick: Tick| Event {
            tick,
            seq: 0,
            fixture: true,
            occupant: Some("person:a".into()),
            kind,
        };
        let boarded = || EventKind::Boarded {
            vehicle: EAST_1.into(),
        };
        let alighted = |stop: &str| EventKind::Alighted {
            vehicle: EAST_1.into(),
            stop: stop.into(),
        };
        // Running at 32; standing at the stop, doors open, 34 to 45.
        let running = tram_world(32).snapshot().clone();
        assert!(has(check_doors_open(&running, &[event(boarded(), 32)]), 21));
        assert!(has(
            check_doors_open(&running, &[event(alighted("stop:mid"), 32)]),
            21
        ));
        let standing = tram_world(34).snapshot().clone();
        assert!(
            check_doors_open(
                &standing,
                &[event(boarded(), 34), event(alighted("stop:mid"), 34)]
            )
            .is_empty()
        );
        assert!(has(
            check_doors_open(&standing, &[event(alighted("stop:elsewhere"), 34)]),
            21
        ));
        let gone = tram_world(50).snapshot().clone();
        assert!(
            has(check_doors_open(&gone, &[event(boarded(), 50)]), 21),
            "no such vehicle"
        );
    }
}
