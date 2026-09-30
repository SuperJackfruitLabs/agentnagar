//! Transit: the Vehicles phase, which runs every line's vehicles to its
//! timetable.
//!
//! A vehicle's `along` is where its front is, in centimetres from the west
//! end of its own track: the same measure as `StopInfo::stand`, and the
//! distance along the centreline wherever the line runs straight. An
//! eastbound vehicle's front is its east end, so its body spans
//! `along - length .. along`; a westbound one's is its west end, so its
//! body spans `along .. along + length`. Bodies are half-open: a follower
//! whose front is exactly at the rear of the vehicle ahead does not overlap
//! it. A vehicle standing at a stop is centred on the stop's `at`, not
//! fronted on it.
//!
//! **Vehicle order.** Vehicles are stored and act in vehicle order: by
//! line, then direction (east first), then their number `n`, compared as a
//! number, so `east:9` comes before `east:10`. Vehicles on one track
//! therefore act from the one that entered first, which is the one ahead.
//!
//! Each tick, after the walkers have stepped, every vehicle on a line acts
//! in vehicle order:
//!
//! - one standing at a stop keeps its doors open until its dwell is over,
//!   then closes them and runs on;
//! - one running advances `speed` cells, stopping exactly where its centre
//!   meets the next stop's `at`, and never closer than the rear of the
//!   vehicle ahead of it on its track;
//! - it never moves onto a cell a public walker holds: blocked, it is held
//!   where it is and tries again next tick, and once held
//!   [`STEP_ASIDE_AFTER`] ticks in a row the walkers in its way are stepped
//!   aside, off the track (`SteppedAside`), so no one holds it for long;
//! - once its rear has passed the far portal, it leaves the line.
//!
//! Then vehicles due on this tick's timetable join their portal's waiting
//! list, and the first waiting at each portal enters, once no vehicle's body
//! still reaches past that portal. All of it is integer arithmetic over
//! ordered stores, with no random draws.
//!
//! **Riders.** On every tick a vehicle stands at a stop with its doors
//! open, first its riders bound for that stop step off, in slot order, and
//! then the stop's waiters for its direction board, first come, first
//! served (by the tick each began waiting, then by city ID):
//!
//! - public riders take the lowest free slot, `0..capacity`, and board only
//!   while one is free; a player takes the free seat nearest the middle
//!   instead (the first and last rows are in the cabs);
//! - hidden riders (private personal agents, anonymous observers) board
//!   whatever the load, with no slot (`u32::MAX`), and count against
//!   nothing, so the public never sees their effect;
//! - a rider steps off onto the free platform cell nearest the door nearest
//!   its slot, within 2 m of it, and is placed in the platform room at once
//!   (see `alight`); with no such cell, or no room on the platform, it
//!   stays aboard, and if the doors close first it rides on to the next
//!   stop;
//! - as the doors close on a full vehicle, each public waiter still there
//!   is logged `LeftBehind`;
//! - a vehicle leaving the line takes its riders out of the city with it,
//!   `Departed { via }`.
//!
//! Riders hold no ground cell. Each rider's destination, and each waiter's
//! start tick, are kept here in [`Riders`], by city ID.
//!
//! **Destinations.** A rider rides to a stop ahead of it, or out of the
//! city. One bound for a stop never rides out: if it cannot step off there
//! it rides on to the next stop. At the last stop in its direction the
//! doors stay open, and it may step off anywhere on the platform, for at
//! most one dwell past their closing time; then it steps off onto the
//! nearest free standing cell a walk from the doors reaches, wherever that
//! is, and the doors close. Capacity never keeps a rider aboard: the only
//! riders bound for a stop are players and arrivals, who are there in
//! person once off, so a room may briefly hold more than its capacity.
//! Capacity gates walkers entering a platform from the street, and waiters
//! count towards it. Every platform has somewhere off the track to stand,
//! or the world refuses to build.
//!
//! **Arrivals and departures by tram** (`arrivals = "tram"`, with a line
//! and a layout):
//!
//! - an `Arrive` queues the occupant at a portal of the first line, public
//!   and hidden arrivals each alternating east and west by their own
//!   count; the next vehicle entering there takes it aboard, bound for the
//!   stop whose platform on its side is the shortest walk from the target
//!   room, and once off it walks to that room as after a `Go`;
//! - a player joining (`Arrive` with `player`) takes whichever vehicle
//!   brings it soonest instead (for a stop's platform, the first to stand
//!   at that stop), and, joining for a stop's platform, steps off
//!   at that stop and stays on its platform on the vehicle's side;
//! - a public `Depart` on the ground walks to a platform of the nearest
//!   stop (`ToPlatform`), the one where the first vehicle it can catch
//!   stands, waits there, boards and rides out;
//! - a `Depart` while waiting or aboard rides out; a hidden occupant
//!   departs at once, as today, and so does a player leaving (a `Depart`
//!   with `player`, from its session's `leave`), from wherever it is: the
//!   one exception to departures riding out.
//!
//! **Players' commands.** `Board` on a platform waits there for the next
//! vehicle, which with its doors open boards the player on the same tick,
//! bound for the last stop ahead (a full one leaves it waiting, and
//! `LeftBehind`); `Alight` steps off a vehicle standing with its doors open.
//! A player once off stands where it stepped off: it is never walked on to
//! the room it joined for.

use crate::index::{LineInfo, PlaceIndex, StopInfo, TrackGeometry};
use crate::nav::{CELL, Cell, NavGrid};
use crate::project::shares_capacity;
use crate::world::World;
use city_contracts::{
    Arrivals, Catalogue, CityId, Class, Direction, EventKind, Location, PlaceId, Point,
    PresenceRecord, Rect, RejectReason, ShownPresence, Target, Tick, VehicleSpec, VehicleState,
    VehicleStatus, WalkPurpose,
};
use std::collections::{BTreeMap, BTreeSet, VecDeque};

/// The vehicles due to enter each line's track at its portal, by line and
/// direction, as their numbers in timetable order.
pub type WaitingEntries = BTreeMap<(PlaceId, Direction), VecDeque<u64>>;

/// The catalogue kind a line's vehicles are when its `VehicleSpec` names
/// none.
pub const DEFAULT_VEHICLE_KIND: &str = "tram";

/// Why a line's vehicle kind gives no width.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VehicleKindError {
    /// The catalogue carries no kind of that name.
    NotInCatalogue,
    /// The kind is not of the `vehicle` class.
    NotAVehicle,
    /// A vehicle kind the catalogue gives no width.
    NoWidth,
}

/// Half the width (cm) of the vehicles `spec` describes, from the
/// `vehicle`-class kind it names in `catalogue` (`tram` when it names
/// none).
pub fn vehicle_half_width(
    catalogue: &Catalogue,
    spec: &VehicleSpec,
) -> Result<i64, VehicleKindError> {
    let name = spec.kind.as_deref().unwrap_or(DEFAULT_VEHICLE_KIND);
    let kind = catalogue
        .kind(name)
        .ok_or(VehicleKindError::NotInCatalogue)?;
    if kind.class != Class::Vehicle {
        return Err(VehicleKindError::NotAVehicle);
    }
    let width = kind.width.ok_or(VehicleKindError::NoWidth)?;
    Ok(i64::from(width) / 2)
}

/// Half the width (cm) of `line`'s vehicles: a vehicle's footprint is the
/// ground within this distance of its track. A tram's is 125, so it is
/// 2.5 m wide in all. Read from the catalogue once, when the line is built.
pub fn half_width(line: &LineInfo) -> i64 {
    line.half_width
}

/// How far from its door (cm) a rider may step off onto a platform.
pub const ALIGHT_REACH: i64 = 200;

/// After this many ticks held in a row, a vehicle has the public walkers in
/// its way stepped aside, off the track (`World::step_aside`), so a walker
/// standing still on the rails (a player with its menu open, say) never
/// holds the line for long.
pub const STEP_ASIDE_AFTER: u32 = 5;

/// Where a rider, or a platform waiter once aboard, rides to.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Destination {
    /// Step off at this stop.
    Stop(PlaceId),
    /// Ride past the far portal, out of the city.
    RideOut,
}

/// The transit state of riders and waiters that the snapshot does not
/// carry, each store ordered by city ID.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Riders {
    /// Where each rider, and each waiter once aboard, rides to.
    pub destinations: BTreeMap<CityId, Destination>,
    /// The tick each platform waiter began waiting: boarding is first
    /// come, first served. Every waiter has one, and no one else.
    pub waiting_since: BTreeMap<CityId, Tick>,
    /// Arrivals by tram, from their `Arrive` until they step off: the room
    /// each is bound for.
    pub arrivals: BTreeMap<CityId, PlaceId>,
    /// Arrivals queued at each portal (by line and direction) for the next
    /// vehicle entering there, in arrival order.
    pub arrival_queues: BTreeMap<(PlaceId, Direction), Vec<CityId>>,
    /// How many public, then hidden, arrivals have come by tram. Each kind
    /// alternates portals by its own count, east first, so hidden arrivals
    /// never shift a public one's.
    pub arrival_counts: [u64; 2],
    /// Vehicles holding their doors open at the last stop for riders still
    /// to step off, each with the tick its doors were due to close.
    pub holds: BTreeMap<CityId, Tick>,
    /// Vehicles held by walkers in their way, each with how many ticks in
    /// a row it has been held (see [`STEP_ASIDE_AFTER`]).
    pub held_for: BTreeMap<CityId, u32>,
    /// Players: occupants that joined as one (`Arrive` with `player`) or
    /// asked to `Board`. A player sits mid-car (see `take_aboard`), and
    /// walks only where it is told (it takes no arrival walk once off).
    pub players: BTreeSet<CityId>,
}

const DIRECTIONS: [Direction; 2] = [Direction::East, Direction::West];

/// Which way along the track a direction runs: +1 east, -1 west.
pub(crate) fn sign(direction: Direction) -> i64 {
    match direction {
        Direction::East => 1,
        Direction::West => -1,
    }
}

fn word(direction: Direction) -> &'static str {
    match direction {
        Direction::East => "east",
        Direction::West => "west",
    }
}

/// The ID of the `n`th vehicle (counting from 1) to enter `line` running
/// `direction`: `vehicle:<line without its "line:" prefix>:<east|west>:<n>`.
pub fn vehicle_id(line: &PlaceId, direction: Direction, n: u64) -> CityId {
    let name = line.as_str().strip_prefix("line:").unwrap_or(line.as_str());
    CityId::from(format!("vehicle:{name}:{}:{n}", word(direction)))
}

/// The number `n` of a vehicle, from the last part of its ID; 0 for an ID
/// not made by [`vehicle_id`].
pub fn vehicle_number(id: &CityId) -> u64 {
    id.as_str()
        .rsplit(':')
        .next()
        .and_then(|n| n.parse().ok())
        .unwrap_or(0)
}

/// Where a vehicle sorts in vehicle order: by line, direction, then number.
pub fn vehicle_key(vehicle: &VehicleState) -> (&PlaceId, Direction, u64) {
    (
        &vehicle.line,
        vehicle.direction,
        vehicle_number(&vehicle.id),
    )
}

/// The length (cm) of `line`'s track for `direction`.
fn track_length(line: &LineInfo, direction: Direction) -> i64 {
    *line.tracks[direction.index()]
        .lengths
        .last()
        .expect("a track has at least one point")
}

/// The along a vehicle's front enters at: its own portal, the west end for
/// eastbound vehicles and the east end for westbound ones.
fn portal(line: &LineInfo, direction: Direction) -> i64 {
    match direction {
        Direction::East => 0,
        Direction::West => track_length(line, direction),
    }
}

/// The stretch of track a vehicle `length` cm long covers with its front at
/// `front`, as a half-open span `from .. to`, `from ≤ to`.
pub fn body(front: i64, length: i64, direction: Direction) -> (i64, i64) {
    match direction {
        Direction::East => (front - length, front),
        Direction::West => (front, front + length),
    }
}

/// The along of a vehicle's centre when its front is at `front`.
pub fn centre_along(front: i64, length: i64, direction: Direction) -> i64 {
    front - sign(direction) * (length / 2)
}

/// Where a vehicle's front stands when its centre is on `at`.
fn front_at(at: i64, length: i64, direction: Direction) -> i64 {
    at + sign(direction) * (length / 2)
}

/// Whether a vehicle whose front is at `front` has wholly passed its far
/// portal.
fn gone(line: &LineInfo, front: i64, length: i64, direction: Direction) -> bool {
    match direction {
        Direction::East => front - length >= track_length(line, direction),
        Direction::West => front + length <= 0,
    }
}

/// The ground cells a vehicle covers now: the walkable cells whose centres
/// lie within its line's [`half_width`] of its track, along its body. Parts
/// of the body beyond either portal cover nothing.
pub fn footprint(index: &PlaceIndex, nav: &NavGrid, vehicle: &VehicleState) -> BTreeSet<Cell> {
    let Some(line) = index.lines.get(&vehicle.line) else {
        return BTreeSet::new();
    };
    let length = i64::from(line.vehicle.length);
    let (from, to) = body(i64::from(vehicle.along), length, vehicle.direction);
    band_cells(
        &line.tracks[vehicle.direction.index()],
        from,
        to,
        half_width(line),
        nav,
    )
}

/// The walkable cells whose centres lie within `half_width` of `track`
/// over the half-open span `from .. to` cm along it, clipped to the
/// track's extent.
///
/// Each stretch of a segment is a rectangle: a cell is in it when its
/// centre projects onto the stretch's half-open length (its start, not its
/// end) and lies no further than `half_width` from it, both compared exactly
/// in integers. Two bodies that meet end to end therefore share no cell. A disc round each bend
/// inside the span fills the outside of the corner.
pub fn band_cells(
    track: &TrackGeometry,
    from: i64,
    to: i64,
    half_width: i64,
    nav: &NavGrid,
) -> BTreeSet<Cell> {
    let total = *track
        .lengths
        .last()
        .expect("a track has at least one point");
    let (from, to) = (from.max(0), to.min(total));
    let mut out = BTreeSet::new();
    if from >= to {
        return out;
    }
    for i in 0..track.points.len().saturating_sub(1) {
        let (start, end) = (track.lengths[i], track.lengths[i + 1]);
        if end <= from || start >= to {
            continue;
        }
        let a = track.point_at(from.max(start));
        let b = track.point_at(to.min(end));
        stretch_cells(a, b, half_width, nav, &mut out);
        if end < to && i + 2 < track.points.len() {
            disc_cells(track.points[i + 1], half_width, nav, &mut out);
        }
    }
    out
}

/// The walkable cells in the box round `a`–`b`, widened by `half_width`,
/// that satisfy `keep` (given each cell's centre).
fn cells_near(
    a: Point,
    b: Point,
    half_width: i64,
    nav: &NavGrid,
    keep: impl Fn(Point) -> bool,
) -> Vec<Cell> {
    let hw = i32::try_from(half_width).expect("a vehicle's width fits in i32");
    let low = nav.cell_of(Point {
        x: a.x.min(b.x) - hw,
        z: a.z.min(b.z) - hw,
    });
    let high = nav.cell_of(Point {
        x: a.x.max(b.x) + hw,
        z: a.z.max(b.z) + hw,
    });
    let mut out = Vec::new();
    for j in low.j..=high.j {
        for i in low.i..=high.i {
            let c = Cell { i, j };
            if nav.walkable(c) && keep(nav.centre(c)) {
                out.push(c);
            }
        }
    }
    out
}

/// Adds the cells of the rectangle `half_width` either side of `a`–`b`.
fn stretch_cells(a: Point, b: Point, half_width: i64, nav: &NavGrid, out: &mut BTreeSet<Cell>) {
    let (dx, dz) = (i128::from(b.x - a.x), i128::from(b.z - a.z));
    let squared = dx * dx + dz * dz;
    if squared == 0 {
        return;
    }
    let hw = i128::from(half_width);
    out.extend(cells_near(a, b, half_width, nav, |q| {
        let (wx, wz) = (i128::from(q.x - a.x), i128::from(q.z - a.z));
        let t = wx * dx + wz * dz;
        let cross = wx * dz - wz * dx;
        (0..squared).contains(&t) && cross * cross <= hw * hw * squared
    }));
}

/// Adds the cells within `half_width` of `p`.
fn disc_cells(p: Point, half_width: i64, nav: &NavGrid, out: &mut BTreeSet<Cell>) {
    out.extend(cells_near(p, p, half_width, nav, |q| {
        let (wx, wz) = (i64::from(q.x - p.x), i64::from(q.z - p.z));
        wx * wx + wz * wz <= half_width * half_width
    }));
}

/// Every cell any vehicle of any line can cover: both tracks of every
/// line, end to end.
pub fn track_cells(index: &PlaceIndex, nav: &NavGrid) -> BTreeSet<Cell> {
    index
        .lines
        .values()
        .flat_map(|line| line.tracks.iter().map(move |track| (line, track)))
        .flat_map(|(line, track)| {
            let total = *track
                .lengths
                .last()
                .expect("a track has at least one point");
            band_cells(track, 0, total, half_width(line), nav)
        })
        .collect()
}

/// What one vehicle does this tick.
struct Outcome {
    along: i32,
    status: VehicleStatus,
    events: Vec<EventKind>,
    leaves: bool,
    /// Held: the public walkers' cells in its way.
    blocked_by: Vec<Cell>,
}

/// The Vehicles phase: every vehicle acts in vehicle order, then vehicles
/// due on the timetable queue at their portals and the first waiting at
/// each clear portal enters. It runs after Transition, so walkers have
/// stepped this tick and vehicles yield to them.
pub(crate) fn step_vehicles(world: &mut World, tick: Tick) {
    if world.index.lines.is_empty() {
        return;
    }
    reach_platforms(world);
    let walkers = world.public_walker_cells();
    let ids: Vec<CityId> = world.state.vehicles.iter().map(|v| v.id.clone()).collect();
    for id in ids {
        let Some(k) = world.state.vehicles.iter().position(|v| v.id == id) else {
            continue;
        };
        if let VehicleStatus::Standing { stop, .. } = &world.state.vehicles[k].status
            && doors_open_at(&world.state.vehicles[k], tick).is_none()
        {
            // Its dwell is over: the doors close this tick.
            let stop = stop.clone();
            close_doors(world, k, &stop);
        }
        let outcome = act(world, &world.state.vehicles[k], tick, &walkers);
        if outcome.status == VehicleStatus::Held {
            let held = world.riders.held_for.entry(id.clone()).or_default();
            *held += 1;
            if *held >= STEP_ASIDE_AFTER {
                step_aside(world, &outcome.blocked_by);
            }
        } else {
            world.riders.held_for.remove(&id);
        }
        let vehicle = &mut world.state.vehicles[k];
        vehicle.trail = if outcome.along == vehicle.along {
            Vec::new()
        } else {
            vec![vehicle.along, outcome.along]
        };
        vehicle.along = outcome.along;
        vehicle.status = outcome.status;
        for kind in outcome.events {
            world.push(None, kind);
        }
        if outcome.leaves {
            world.riders.holds.remove(&id);
            world.riders.held_for.remove(&id);
            let vehicle = world.state.vehicles.remove(k);
            ride_out(world, &vehicle);
            world.push(None, EventKind::VehicleLeft { vehicle: id });
        } else if let Some(stop) = doors_open_at(&world.state.vehicles[k], tick) {
            let held = world.riders.holds.contains_key(&id);
            exchange(world, k, &stop, held);
            hold_or_step_off(world, k, &stop, tick);
        }
    }
    enter(world, tick);
}

/// Steps aside, off the track, each public walker holding one of `cells`
/// (a held vehicle's way), in city-ID order.
fn step_aside(world: &mut World, cells: &[Cell]) {
    let holders = world.walker_cells();
    let walkers: BTreeSet<CityId> = cells
        .iter()
        .filter_map(|c| holders.get(c).cloned())
        .collect();
    for occ in walkers {
        world.step_aside(&occ);
    }
}

/// Vehicle `k` stands at `stop`, the last ahead of it, on the last tick
/// its doors are open, and riders bound there are still aboard (the
/// platform had no cell for them). Riders bound for a stop never ride out,
/// so for a public one the doors stay open another tick, and while they are held open a
/// rider may step off anywhere on the platform. The hold lasts at most one
/// dwell past the tick the doors were due to close (kept in
/// [`Riders::holds`]): on its last tick, everyone still bound here steps
/// off onto the nearest free standing cell a walk from the doors reaches,
/// on the platform or not (see [`step_off_anywhere`]). The doors then close
/// on time, so a hold never stops the line for long. Hidden riders never
/// hold the doors (they count against nothing the public sees): with only
/// hidden ones still aboard, they step off anywhere at once.
fn hold_or_step_off(world: &mut World, k: usize, stop: &PlaceId, tick: Tick) {
    let vehicle = &world.state.vehicles[k];
    let VehicleStatus::Standing {
        doors_open_until, ..
    } = vehicle.status
    else {
        return;
    };
    let line = &world.index.lines[&vehicle.line];
    let last = line
        .stops
        .iter()
        .find(|s| &s.id == stop)
        .is_some_and(|info| next_stop(line, i64::from(info.at), vehicle.direction).is_none());
    let bound = Destination::Stop(stop.clone());
    let mut staying: Vec<(u32, usize, CityId)> = vehicle
        .riders
        .iter()
        .enumerate()
        .filter(|(_, r)| world.riders.destinations.get(*r) == Some(&bound))
        .map(|(order, r)| (slot_of(world, r), order, r.clone()))
        .collect();
    if tick + 1 != doors_open_until || !last || staying.is_empty() {
        return;
    }
    // Only public riders hold the doors: hidden ones count against nothing
    // the public sees, so they step off at once, wherever there is room.
    let public = staying
        .iter()
        .any(|(_, _, r)| shares_capacity(&world.state.occupants[r].profile.kind));
    if public {
        let dwell = u64::from(line.timetable.dwell);
        let id = vehicle.id.clone();
        let due = *world.riders.holds.entry(id).or_insert(doors_open_until);
        if doors_open_until < due + dwell {
            if let VehicleStatus::Standing {
                doors_open_until, ..
            } = &mut world.state.vehicles[k].status
            {
                *doors_open_until += 1;
            }
            return;
        }
    }
    staying.sort();
    for (_, _, rider) in staying {
        step_off_anywhere(world, k, stop, &rider);
    }
}

/// The stop `vehicle` stands at with its doors open on `tick`, if any.
fn doors_open_at(vehicle: &VehicleState, tick: Tick) -> Option<PlaceId> {
    match &vehicle.status {
        VehicleStatus::Standing {
            stop,
            doors_open_until,
        } if tick < *doors_open_until => Some(stop.clone()),
        _ => None,
    }
}

/// The line and stop with ID `stop`.
pub(crate) fn find_stop<'a>(
    index: &'a PlaceIndex,
    stop: &PlaceId,
) -> Option<(&'a LineInfo, &'a StopInfo)> {
    index
        .lines
        .values()
        .find_map(|line| line.stops.iter().find(|s| &s.id == stop).map(|s| (line, s)))
}

/// The platform room of `stop` for vehicles running `direction`.
pub(crate) fn platform_of<'a>(
    index: &'a PlaceIndex,
    stop: &PlaceId,
    direction: Direction,
) -> Option<&'a PlaceId> {
    find_stop(index, stop).map(|(_, info)| &info.platforms[direction.index()])
}

/// The last stop of `line` ahead of `at` (cm along it) for a vehicle
/// running `direction`: where a player who boards at `at` rides to.
fn last_stop_ahead(line: &LineInfo, at: i32, direction: Direction) -> Option<&StopInfo> {
    let s = sign(direction);
    line.stops
        .iter()
        .filter(|stop| s * (i64::from(stop.at) - i64::from(at)) > 0)
        .max_by_key(|stop| s * i64::from(stop.at))
}

/// The room under `occ`'s feet: by its cell with a layout, else the room
/// it is in.
fn underfoot(world: &World, occ: &CityId) -> Option<PlaceId> {
    let o = &world.state.occupants[occ];
    match (&world.nav, o.pos) {
        (Some(nav), Some(p)) => nav.room_at(nav.cell_of(p)).cloned(),
        _ => match &o.location {
            Location::InRoom { room, .. } => Some(room.clone()),
            _ => None,
        },
    }
}

/// How many public waiters wait on `room`, as a platform: they count
/// towards its capacity, as its occupants do.
pub(crate) fn waiters_on(world: &World, room: &PlaceId) -> u64 {
    world
        .riders
        .waiting_since
        .keys()
        .filter(|id| {
            let o = &world.state.occupants[*id];
            shares_capacity(&o.profile.kind)
                && matches!(&o.location, Location::WaitingFor { stop, direction: Some(d) }
                    if platform_of(&world.index, stop, *d) == Some(room))
        })
        .count() as u64
}

/// Queues `occ` on a platform of `stop` for the next vehicle running
/// `direction`, to ride to `destination` once aboard. With no direction
/// given, it waits for the vehicles of the platform it stands on (east
/// when one room is both).
///
/// This is crate-internal, not a command: the `Board` command builds on
/// it. It is refused with:
///
/// - `NotPresent` when the occupant is away or leaving;
/// - `NotOnPlatform` unless it stands on the stop's platform for that
///   direction, or when, not yet counted there (in the platform's room or
///   waiting on it), a public occupant finds the platform has no room for
///   it: waiters count towards its capacity;
/// - `NotYourDirection` when its destination is a stop that does not lie
///   ahead of this one in that direction.
///
/// Waiting is a place of its own: the occupant leaves the room it was in,
/// releasing any seat, and any waitlist or admission queue, and keeps its
/// cell on the platform. It waits from the current tick; one already
/// waiting at this stop keeps its place in the line.
pub(crate) fn wait_for(
    world: &mut World,
    occ: &CityId,
    stop: &PlaceId,
    direction: Option<Direction>,
    destination: Destination,
) -> Result<(), RejectReason> {
    let o = world
        .state
        .occupants
        .get(occ)
        .ok_or(RejectReason::UnknownOccupant)?;
    match &o.location {
        Location::Away | Location::Leaving { .. } => return Err(RejectReason::NotPresent),
        Location::Aboard { .. } | Location::InTransit { .. } => {
            return Err(RejectReason::NotOnPlatform);
        }
        _ => {}
    }
    let (line, info) = find_stop(&world.index, stop).ok_or(RejectReason::NotOnPlatform)?;
    let here = underfoot(world, occ);
    let direction = match direction {
        Some(d) => d,
        None => DIRECTIONS
            .into_iter()
            .find(|d| here.as_ref() == Some(&info.platforms[d.index()]))
            .ok_or(RejectReason::NotOnPlatform)?,
    };
    let platform = &info.platforms[direction.index()];
    if here.as_ref() != Some(platform) {
        return Err(RejectReason::NotOnPlatform);
    }
    if let Destination::Stop(to) = &destination {
        let ahead = line
            .stops
            .iter()
            .any(|s| &s.id == to && sign(direction) * (i64::from(s.at) - i64::from(info.at)) > 0);
        if !ahead {
            return Err(RejectReason::NotYourDirection);
        }
    }
    let counted = match &o.location {
        Location::InRoom { room, .. } => room == platform,
        Location::WaitingFor {
            stop: s,
            direction: Some(d),
        } => platform_of(&world.index, s, *d) == Some(platform),
        _ => false,
    };
    if !counted && shares_capacity(&o.profile.kind) && !world.may_enter(platform, occ) {
        return Err(RejectReason::NotOnPlatform);
    }
    let already = matches!(&o.location, Location::WaitingFor { stop: s, .. } if s == stop);
    match o.location.clone() {
        Location::InRoom { .. } => {
            world.leave_room(occ);
        }
        Location::Waitlisted { room } => {
            world
                .state
                .rooms
                .get_mut(&room)
                .expect("room exists")
                .waitlist
                .retain(|o| o != occ);
        }
        Location::Arriving { .. } => world.state.admission_queue.retain(|o| o != occ),
        _ => {}
    }
    begin_waiting(world, occ, stop, direction, destination, !already);
    Ok(())
}

/// Makes `occ`, already out of any room or queue, a waiter at `stop` for
/// vehicles running `direction`, bound for `destination`; `afresh` starts
/// its place in line at the current tick.
fn begin_waiting(
    world: &mut World,
    occ: &CityId,
    stop: &PlaceId,
    direction: Direction,
    destination: Destination,
    afresh: bool,
) {
    let tick = world.state.tick;
    let o = world.state.occupants.get_mut(occ).expect("occupant exists");
    o.location = Location::WaitingFor {
        stop: stop.clone(),
        direction: Some(direction),
    };
    o.walk = None;
    o.goal = None;
    let since = world
        .riders
        .waiting_since
        .entry(occ.clone())
        .or_insert(tick);
    if afresh {
        *since = tick;
    }
    world.riders.destinations.insert(occ.clone(), destination);
}

/// Forgets that `occ` waits on a platform: no place in line and no
/// destination. Its location is the caller's to set.
pub(crate) fn forget_waiting(world: &mut World, occ: &CityId) {
    world.riders.waiting_since.remove(occ);
    world.riders.destinations.remove(occ);
}

/// Ends `occ`'s wait on a platform, as going anywhere does: it is back in
/// the platform's room, an ordinary occupant there (`Admitted`). It was
/// counted there while waiting, so this takes no new place.
pub(crate) fn stop_waiting(world: &mut World, occ: &CityId) {
    let Location::WaitingFor {
        stop,
        direction: Some(direction),
    } = world.state.occupants[occ].location.clone()
    else {
        return;
    };
    forget_waiting(world, occ);
    let platform = platform_of(&world.index, &stop, direction)
        .expect("waiters wait at a stop of a line")
        .clone();
    world.place(occ, &platform);
}

/// Where slot `slot` sits along a vehicle, in cm from its front: the middle
/// of its row. Public slots fill a grid two across and `capacity / 2`
/// (rounded up) rows along the vehicle, front row first; a hidden rider's
/// slot (`u32::MAX`) is the middle of the vehicle.
pub fn slot_along(spec: &VehicleSpec, slot: u32) -> i64 {
    let length = i64::from(spec.length);
    if slot == u32::MAX {
        return length / 2;
    }
    let rows = i64::from(spec.capacity.div_ceil(2).max(1));
    let row = i64::from(slot / 2).min(rows - 1);
    (2 * row + 1) * length / (2 * rows)
}

/// The seat a player takes aboard a vehicle whose `taken` slots are
/// someone's: the free seated slot (see [`slot_seated`]) whose row lies
/// nearest the vehicle's middle, the lower slot first (the left, even one,
/// which is the platform side where platforms lie outside the tracks).
/// `None` when every seat is taken.
fn player_slot(spec: &VehicleSpec, taken: &BTreeSet<u32>) -> Option<u32> {
    let middle = i64::from(spec.length) / 2;
    (0..spec.capacity)
        .filter(|s| !taken.contains(s) && slot_seated(spec, *s))
        .min_by_key(|s| ((slot_along(spec, *s) - middle).abs(), *s))
}

/// Rows whose middle lies within this many cm of a door are standing room.
pub const DOOR_ROW: i64 = 65;

/// Whether a rider in `slot` sits: its row's middle lies more than
/// [`DOOR_ROW`] from every door (rows by the doors are standing room, and a
/// hidden rider stands in the aisle). The client (`CityGeometry`) and the
/// kits (`tram_layout.py`) pose riders by the same rule.
pub fn slot_seated(spec: &VehicleSpec, slot: u32) -> bool {
    if slot == u32::MAX {
        return false;
    }
    let along = slot_along(spec, slot);
    spec.doors
        .iter()
        .all(|d| (along - i64::from(*d)).abs() > DOOR_ROW)
}

/// The slot `occ` rides in, if it is aboard.
fn slot_of(world: &World, occ: &CityId) -> u32 {
    match world.state.occupants[occ].location {
        Location::Aboard { slot, .. } => slot,
        _ => u32::MAX,
    }
}

/// How many public riders vehicle `k` carries.
fn public_riders(world: &World, k: usize) -> usize {
    world.state.vehicles[k]
        .riders
        .iter()
        .filter(|r| shares_capacity(&world.state.occupants[*r].profile.kind))
        .count()
}

/// Whether vehicle `k` carries as many public riders as it can.
fn full(world: &World, k: usize) -> bool {
    let vehicle = &world.state.vehicles[k];
    let capacity = world.index.lines[&vehicle.line].vehicle.capacity;
    public_riders(world, k) as u64 >= u64::from(capacity)
}

/// The occupants waiting at `stop` for a vehicle running `direction`, first
/// come, first served: by the tick each began waiting, then by city ID.
fn waiters(world: &World, stop: &PlaceId, direction: Direction) -> Vec<CityId> {
    let mut waiting: Vec<(Tick, CityId)> = world
        .state
        .occupants
        .iter()
        .filter(|(_, o)| {
            matches!(&o.location, Location::WaitingFor { stop: s, direction: d }
                if s == stop && d.is_none_or(|d| d == direction))
        })
        .map(|(id, _)| {
            let since = *world
                .riders
                .waiting_since
                .get(id)
                .expect("every waiter has a start (invariant 23)");
            (since, id.clone())
        })
        .collect();
    waiting.sort();
    waiting.into_iter().map(|(_, id)| id).collect()
}

/// Puts `occ` aboard vehicle `k`: a public occupant in the lowest free
/// slot, a hidden one with no slot (`u32::MAX`). Aboard, it holds no ground
/// cell. The caller has already taken it out of any room, queue or
/// platform line and checked that the vehicle has a slot for it; nothing
/// is logged. Returns the slot.
///
/// A player takes a window seat mid-car instead (see [`player_slot`]): the
/// grid's first and last rows lie in the cabs' noses, walled but for a
/// sliver of window, and a player's first person looks out from its seat.
pub(crate) fn take_aboard(world: &mut World, k: usize, occ: &CityId) -> u32 {
    let slot = if shares_capacity(&world.state.occupants[occ].profile.kind) {
        let taken: BTreeSet<u32> = world.state.vehicles[k]
            .riders
            .iter()
            .map(|r| slot_of(world, r))
            .collect();
        let spec = &world.index.lines[&world.state.vehicles[k].line].vehicle;
        world
            .riders
            .players
            .contains(occ)
            .then(|| player_slot(spec, &taken))
            .flatten()
            .or_else(|| (0..u32::MAX).find(|s| !taken.contains(s)))
            .expect("a vehicle has fewer than u32::MAX riders")
    } else {
        u32::MAX
    };
    let vehicle = &mut world.state.vehicles[k];
    vehicle.riders.push(occ.clone());
    let id = vehicle.id.clone();
    let o = world.state.occupants.get_mut(occ).expect("occupant exists");
    o.location = Location::Aboard { vehicle: id, slot };
    o.pos = None;
    o.walk = None;
    o.goal = None;
    slot
}

/// Vehicle `k` stands at `stop` with its doors open: its riders bound here
/// step off, in slot order (then boarding order), anywhere on the platform
/// when `anywhere` (the doors held open at the last stop), and then the
/// stop's waiters for its direction board, first come, first served, while
/// it has a slot for each public one. Hidden waiters always board.
fn exchange(world: &mut World, k: usize, stop: &PlaceId, anywhere: bool) {
    let bound_here = Destination::Stop(stop.clone());
    let mut leaving: Vec<(u32, usize, CityId)> = world.state.vehicles[k]
        .riders
        .iter()
        .enumerate()
        .filter(|(_, r)| world.riders.destinations.get(*r) == Some(&bound_here))
        .map(|(order, r)| (slot_of(world, r), order, r.clone()))
        .collect();
    leaving.sort();
    for (_, _, rider) in leaving {
        alight(world, k, stop, &rider, anywhere);
    }
    let vehicle = world.state.vehicles[k].id.clone();
    let direction = world.state.vehicles[k].direction;
    for occ in waiters(world, stop, direction) {
        if shares_capacity(&world.state.occupants[&occ].profile.kind) && full(world, k) {
            continue;
        }
        take_aboard(world, k, &occ);
        world.riders.waiting_since.remove(&occ);
        world
            .riders
            .destinations
            .entry(occ.clone())
            .or_insert(Destination::RideOut);
        world.push(
            Some(&occ),
            EventKind::Boarded {
                vehicle: vehicle.clone(),
            },
        );
    }
}

/// Steps `rider` off vehicle `k` at `stop`, onto its platform for the
/// vehicle's direction, if it can, and returns whether it did. It needs a
/// free platform cell within [`ALIGHT_REACH`] of the door nearest its slot
/// (anywhere on the platform when `anywhere`); a hidden rider, which holds
/// nothing, needs only a platform cell there. Otherwise it stays aboard.
///
/// The platform's capacity never keeps a rider aboard: riders step off
/// only at their own stop (players and arrivals) or on a player's `Alight`,
/// and they are on the platform in person once off (see the module notes).
///
/// Stepping off is a direct placement, not a walk to the threshold: the
/// rider is admitted to the platform room on the spot (`Alighted`, then
/// `Admitted`), so it is never queued while standing inside. An arrival
/// then walks on to the room it came for, as after a `Go`; anyone else,
/// players among them (carried past their stop, say), stands where it
/// stepped off until its next move.
fn alight(world: &mut World, k: usize, stop: &PlaceId, rider: &CityId, anywhere: bool) -> bool {
    let vehicle = &world.state.vehicles[k];
    let line = &world.index.lines[&vehicle.line];
    let info = line
        .stops
        .iter()
        .find(|s| &s.id == stop)
        .expect("vehicles stand only at their line's stops");
    let platform = info.platforms[vehicle.direction.index()].clone();
    let public = shares_capacity(&world.state.occupants[rider].profile.kind);
    let cell = match world.nav.as_ref() {
        Some(nav) => {
            let door = door_point(
                line,
                vehicle,
                slot_of(world, rider),
                world.index.rooms[&platform].rect,
            );
            let held = if public {
                world.public_walker_cells()
            } else {
                BTreeSet::new()
            };
            let reach = (!anywhere).then_some(ALIGHT_REACH);
            let Some(c) = alighting_cell(nav, door, &platform, &world.track_cells, &held, reach)
            else {
                return false;
            };
            Some(c)
        }
        None => None,
    };
    let vehicle_id = vehicle.id.clone();
    world.state.vehicles[k].riders.retain(|r| r != rider);
    world.riders.destinations.remove(rider);
    world.push(
        Some(rider),
        EventKind::Alighted {
            vehicle: vehicle_id,
            stop: stop.clone(),
        },
    );
    if let Some(c) = cell {
        world.set_pos(rider, c);
    }
    world.place(rider, &platform);
    if let Some(target) = world.riders.arrivals.remove(rider)
        && target != platform
        && !world.riders.players.contains(rider)
    {
        // With no way to the room, it stays on the platform.
        let tick = world.state.tick;
        let _ = world.go(rider.clone(), Target::Room { room: target }, tick);
    }
    true
}

/// The platform cell a rider steps off onto from a door at `door`: the
/// nearest walkable cell of `platform` within `reach` of it (anywhere on
/// the platform without one) that is neither track nor `held`. Ties go to
/// the lower cell (row, then column).
fn alighting_cell(
    nav: &NavGrid,
    door: Point,
    platform: &PlaceId,
    track: &BTreeSet<Cell>,
    held: &BTreeSet<Cell>,
    reach: Option<i64>,
) -> Option<Cell> {
    let candidates = match reach {
        Some(reach) => {
            let r = reach as i32;
            let low = nav.cell_of(Point {
                x: door.x - r,
                z: door.z - r,
            });
            let high = nav.cell_of(Point {
                x: door.x + r,
                z: door.z + r,
            });
            (low.j..=high.j)
                .flat_map(|j| (low.i..=high.i).map(move |i| Cell { i, j }))
                .collect()
        }
        None => nav.cells_in(platform),
    };
    let mut best: Option<(i64, Cell)> = None;
    for c in candidates {
        if nav.room_at(c) != Some(platform) || track.contains(&c) || held.contains(&c) {
            continue;
        }
        let q = nav.centre(c);
        let (dx, dz) = (i64::from(q.x - door.x), i64::from(q.z - door.z));
        let d = dx * dx + dz * dz;
        if reach.is_none_or(|r| d <= r * r) && best.is_none_or(|b| (d, c) < b) {
            best = Some((d, c));
        }
    }
    best.map(|(_, c)| c)
}

/// The hold on vehicle `k` at `stop` has run its course and `rider`,
/// bound there, still cannot step off onto the platform: it steps off onto
/// the free standing cell (not track, seat, door span, queue place or
/// entrance approach; for a public rider, held by no public walker)
/// nearest its vehicle's doors by walking cost, wherever a walk from any
/// door reaches, and is placed in that room whatever its load, as a rider
/// stepping off onto a full platform is (`Alighted`, then `Admitted`). An
/// arrival other than a player then walks on to its room. Only with no
/// such cell anywhere does
/// it stay aboard, and then it rides on.
fn step_off_anywhere(world: &mut World, k: usize, stop: &PlaceId, rider: &CityId) {
    if alight(world, k, stop, rider, true) {
        return;
    }
    let Some(nav) = world.nav.as_ref() else {
        return;
    };
    let vehicle = &world.state.vehicles[k];
    let line = &world.index.lines[&vehicle.line];
    let platform = line
        .stops
        .iter()
        .find(|s| &s.id == stop)
        .map(|info| info.platforms[vehicle.direction.index()].clone())
        .expect("vehicles stand only at their line's stops");
    let rect = world.index.rooms[&platform].rect;
    let doors: Vec<Cell> = line
        .vehicle
        .doors
        .iter()
        .filter_map(|d| nav.snap(door_point_at(line, vehicle, i64::from(*d), rect)))
        .collect();
    let field = nav.field_from(&doors);
    let held = if shares_capacity(&world.state.occupants[rider].profile.kind) {
        world.public_walker_cells()
    } else {
        BTreeSet::new()
    };
    let Some(cell) = nav
        .cells_by_cost(&field)
        .find(|c| world.good_to_stand(*c) && !held.contains(c))
    else {
        return;
    };
    let room = nav
        .room_at(cell)
        .expect("standing cells are in rooms")
        .clone();
    let vehicle_id = vehicle.id.clone();
    world.state.vehicles[k].riders.retain(|r| r != rider);
    world.riders.destinations.remove(rider);
    world.push(
        Some(rider),
        EventKind::Alighted {
            vehicle: vehicle_id,
            stop: stop.clone(),
        },
    );
    world.set_pos(rider, cell);
    world.place(rider, &room);
    if let Some(target) = world.riders.arrivals.remove(rider)
        && target != room
        && !world.riders.players.contains(rider)
    {
        let tick = world.state.tick;
        let _ = world.go(rider.clone(), Target::Room { room: target }, tick);
    }
}

/// Where the door nearest `slot` opens: on the vehicle's side facing the
/// platform whose floor is `platform`, [`half_width`] out from its track.
/// Doors are measured from the vehicle's front; ties go to the one nearer
/// the front.
fn door_point(line: &LineInfo, vehicle: &VehicleState, slot: u32, platform: Option<Rect>) -> Point {
    let spec = &line.vehicle;
    let seat = slot_along(spec, slot);
    let door = spec
        .doors
        .iter()
        .map(|d| i64::from(*d))
        .min_by_key(|d| ((d - seat).abs(), *d))
        .unwrap_or(i64::from(spec.length) / 2);
    door_point_at(line, vehicle, door, platform)
}

/// Where the door `door` cm from the vehicle's front opens: on its side
/// facing the platform whose floor is `platform`, [`half_width`] out from
/// its track: the step down from the vehicle, at its edge.
fn door_point_at(
    line: &LineInfo,
    vehicle: &VehicleState,
    door: i64,
    platform: Option<Rect>,
) -> Point {
    let direction = vehicle.direction;
    let track = &line.tracks[direction.index()];
    let along = i64::from(vehicle.along) - sign(direction) * door;
    let p = track.point_at(along);
    let Some(rect) = platform else {
        return p;
    };
    // The segment the door lies on, and a normal to it half the vehicle's
    // width long.
    let total = *track
        .lengths
        .last()
        .expect("a track has at least one point");
    let along = along.clamp(0, total);
    let Some(i) = (0..track.points.len().saturating_sub(1))
        .find(|&i| along <= track.lengths[i + 1] && track.lengths[i + 1] > track.lengths[i])
    else {
        return p;
    };
    let (a, b) = (track.points[i], track.points[i + 1]);
    let length = track.lengths[i + 1] - track.lengths[i];
    let hw = half_width(line);
    let nx = i64::from(a.z - b.z) * hw / length;
    let nz = i64::from(b.x - a.x) * hw / length;
    let centre = (
        i64::from(rect.x) + i64::from(rect.w) / 2,
        i64::from(rect.z) + i64::from(rect.d) / 2,
    );
    let side = |s: i64| {
        let q = (i64::from(p.x) + s * nx, i64::from(p.z) + s * nz);
        let d = (q.0 - centre.0).pow(2) + (q.1 - centre.1).pow(2);
        (d, q)
    };
    let (near, far) = (side(1), side(-1));
    let (x, z) = if far.0 < near.0 { far.1 } else { near.1 };
    Point {
        x: i32::try_from(x).expect("door points fit in i32"),
        z: i32::try_from(z).expect("door points fit in i32"),
    }
}

/// Vehicle `k`'s dwell at `stop` is over and its doors close: riders still
/// bound here (the platform had no cell for them) ride on to the next stop
/// (at the last there is none, and they have all stepped off, see
/// `hold_or_step_off`); and if it is full, each public waiter still at the
/// stop for it is logged `LeftBehind`.
fn close_doors(world: &mut World, k: usize, stop: &PlaceId) {
    let id = world.state.vehicles[k].id.clone();
    world.riders.holds.remove(&id);
    let vehicle = &world.state.vehicles[k];
    let line = &world.index.lines[&vehicle.line];
    let direction = vehicle.direction;
    let next = line
        .stops
        .iter()
        .find(|s| &s.id == stop)
        .and_then(|info| next_stop(line, i64::from(info.at), direction))
        .map_or(Destination::RideOut, |s| Destination::Stop(s.id.clone()));
    let bound_here = Destination::Stop(stop.clone());
    for rider in &vehicle.riders {
        if let Some(to) = world.riders.destinations.get_mut(rider)
            && *to == bound_here
        {
            *to = next.clone();
        }
    }
    if !full(world, k) {
        return;
    }
    let vehicle_id = world.state.vehicles[k].id.clone();
    for occ in waiters(world, stop, direction) {
        if shares_capacity(&world.state.occupants[&occ].profile.kind) {
            world.push(
                Some(&occ),
                EventKind::LeftBehind {
                    stop: stop.clone(),
                    vehicle: vehicle_id.clone(),
                },
            );
        }
    }
}

/// `vehicle` has left the line: its riders leave the city with it, as a
/// departure does, `Departed { via }`, in boarding order.
fn ride_out(world: &mut World, vehicle: &VehicleState) {
    for rider in &vehicle.riders {
        world.riders.destinations.remove(rider);
        let o = world.state.occupants.get_mut(rider).expect("riders exist");
        o.location = Location::Away;
        o.presence = PresenceRecord::default();
        o.shown = ShownPresence::default();
        o.pos = None;
        o.facing = 0;
        o.walk = None;
        o.goal = None;
        world.push(
            Some(rider),
            EventKind::Departed {
                from: None,
                via: Some(vehicle.id.clone()),
            },
        );
    }
}

/// Works out what `vehicle` does this tick, without changing anything.
fn act(world: &World, vehicle: &VehicleState, tick: Tick, walkers: &BTreeSet<Cell>) -> Outcome {
    let line = &world.index.lines[&vehicle.line];
    let direction = vehicle.direction;
    let s = sign(direction);
    let length = i64::from(line.vehicle.length);
    let front = i64::from(vehicle.along);
    let mut events = Vec::new();
    let stay = |status: VehicleStatus, events: Vec<EventKind>, blocked_by: Vec<Cell>| Outcome {
        along: vehicle.along,
        status,
        events,
        leaves: false,
        blocked_by,
    };

    if let VehicleStatus::Standing {
        stop,
        doors_open_until,
    } = &vehicle.status
    {
        if tick < *doors_open_until {
            return stay(vehicle.status.clone(), events, Vec::new());
        }
        events.push(EventKind::DoorsClosed {
            vehicle: vehicle.id.clone(),
            stop: stop.clone(),
        });
    }

    // Run `speed` cells, but stop with the centre on the next stop, and
    // never pass the rear of the vehicle ahead on this track.
    let speed = i64::from(line.timetable.speed) * i64::from(CELL);
    let mut to = front + s * speed;
    let next = next_stop(line, centre_along(front, length, direction), direction)
        .map(|stop| (stop, front_at(i64::from(stop.at), length, direction)));
    if let Some((_, stop_front)) = next
        && s * (to - stop_front) > 0
    {
        to = stop_front;
    }
    if let Some(limit) = rear_ahead(world, vehicle, length)
        && s * (to - limit) > 0
    {
        to = limit;
    }
    if s * (to - front) < 0 {
        to = front;
    }

    // Held if anywhere it would cover, or pass over, is a public walker's.
    if to != front
        && let Some(nav) = world.nav.as_ref()
    {
        let track = &line.tracks[direction.index()];
        let (from, until) = body(to, length, direction);
        let hw = half_width(line);
        let swept = band_cells(track, front.min(to), front.max(to), hw, nav);
        let covered = band_cells(track, from, until, hw, nav);
        let blocked_by: Vec<Cell> = swept
            .union(&covered)
            .filter(|c| walkers.contains(c))
            .copied()
            .collect();
        if !blocked_by.is_empty() {
            if vehicle.status != VehicleStatus::Held {
                events.push(EventKind::VehicleHeld {
                    vehicle: vehicle.id.clone(),
                });
            }
            return stay(VehicleStatus::Held, events, blocked_by);
        }
    }

    let status = match next {
        Some((stop, stop_front)) if stop_front == to => {
            events.push(EventKind::DoorsOpened {
                vehicle: vehicle.id.clone(),
                stop: stop.id.clone(),
            });
            VehicleStatus::Standing {
                stop: stop.id.clone(),
                doors_open_until: tick + u64::from(line.timetable.dwell),
            }
        }
        _ => VehicleStatus::Running,
    };
    Outcome {
        along: i32::try_from(to).expect("track positions fit in i32"),
        status,
        events,
        leaves: gone(line, to, length, direction),
        blocked_by: Vec::new(),
    }
}

/// The first stop ahead of a vehicle whose centre is at `centre`: one it
/// has not yet stood at. Stops are at least a vehicle length apart, so
/// ties never arise.
fn next_stop(line: &LineInfo, centre: i64, direction: Direction) -> Option<&StopInfo> {
    let s = sign(direction);
    line.stops
        .iter()
        .filter(|stop| s * (i64::from(stop.at) - centre) > 0)
        .min_by_key(|stop| s * i64::from(stop.at))
}

/// The rear of the nearest vehicle ahead of `vehicle` on its own track. A
/// vehicle level with it counts as ahead, so two vehicles that somehow
/// share a front never run through each other.
fn rear_ahead(world: &World, vehicle: &VehicleState, length: i64) -> Option<i64> {
    let s = sign(vehicle.direction);
    world
        .state
        .vehicles
        .iter()
        .filter(|o| {
            o.id != vehicle.id && o.line == vehicle.line && o.direction == vehicle.direction
        })
        .map(|o| i64::from(o.along))
        .filter(|&along| s * (along - i64::from(vehicle.along)) >= 0)
        .min_by_key(|&along| s * along)
        .map(|along| along - s * length)
}

/// Queues a vehicle at its portal for every line and direction whose
/// timetable falls on `tick` (`tick >= offset` and `tick - offset` a whole
/// number of headways), then enters the first vehicle waiting at each
/// portal that is clear. An entering vehicle's front is at its portal and
/// its body wholly outside the line; it moves from the next tick. It enters
/// only when no vehicle on its track still has its rear short of the
/// portal, so vehicles never overlap there, and `VehicleEntered` is logged
/// on the tick it actually enters. Numbers follow the timetable, so they
/// stay in sequence however long a vehicle waits.
fn enter(world: &mut World, tick: Tick) {
    for line in world.index.lines.values() {
        let headway = u64::from(line.timetable.headway);
        for direction in DIRECTIONS {
            let offset = u64::from(line.timetable.offset[direction.index()]);
            if headway == 0 || tick < offset || !(tick - offset).is_multiple_of(headway) {
                continue;
            }
            // Ticks run from 1, so an offset of 0 never enters at tick 0:
            // the first vehicle then enters a headway later, still as 1.
            let n = (tick - offset) / headway + u64::from(offset > 0);
            world
                .waiting_entries
                .entry((line.id.clone(), direction))
                .or_default()
                .push_back(n);
        }
    }
    let mut entering = Vec::new();
    for ((line_id, direction), waiting) in &mut world.waiting_entries {
        let line = &world.index.lines[line_id];
        let direction = *direction;
        let length = i64::from(line.vehicle.length);
        let portal = portal(line, direction);
        let clear = world
            .state
            .vehicles
            .iter()
            .filter(|v| v.line == *line_id && v.direction == direction)
            .all(|v| {
                let (from, to) = body(i64::from(v.along), length, direction);
                match direction {
                    Direction::East => from >= portal,
                    Direction::West => to <= portal,
                }
            });
        if !clear {
            continue;
        }
        let Some(n) = waiting.pop_front() else {
            continue;
        };
        entering.push(VehicleState {
            id: vehicle_id(line_id, direction, n),
            line: line_id.clone(),
            direction,
            along: i32::try_from(portal).expect("track lengths fit in i32"),
            status: VehicleStatus::Running,
            riders: Vec::new(),
            trail: Vec::new(),
        });
    }
    world
        .waiting_entries
        .retain(|_, waiting| !waiting.is_empty());
    let mut entered = Vec::new();
    for vehicle in entering {
        world.push(
            None,
            EventKind::VehicleEntered {
                vehicle: vehicle.id.clone(),
            },
        );
        entered.push(vehicle.id.clone());
        world.state.vehicles.push(vehicle);
    }
    world
        .state
        .vehicles
        .sort_by(|a, b| vehicle_key(a).cmp(&vehicle_key(b)));
    for id in entered {
        take_arrivals(world, &id);
    }
}

// ---- Arrivals and departures by tram ----

/// Whether arrivals come, and public departures leave, by tram: the
/// manifest asks for it (`arrivals = "tram"`), and it has a layout and a
/// line with a stop. Otherwise everything is as with `"direct"`.
pub(crate) fn by_tram(world: &World) -> bool {
    world.state.manifest.city.arrivals == Arrivals::Tram
        && world.nav.is_some()
        && world
            .index
            .lines
            .values()
            .next()
            .is_some_and(|line| !line.stops.is_empty())
}

/// Queues `occ`, just arrived for `target`, at a portal of the first line:
/// the next vehicle entering there takes it aboard. A player joining takes
/// whichever vehicle brings it soonest, either way (see [`soonest_entry`]),
/// and when its room is a stop's platform it rides to that stop and stays
/// on its platform on the vehicle's side. Everyone else (agents, a crowd)
/// alternates portals, east first, public and hidden arrivals each by
/// their own count, which spreads them over both directions.
pub(crate) fn queue_arrival(world: &mut World, occ: &CityId, target: &PlaceId, player: bool) {
    let line = world
        .index
        .lines
        .keys()
        .next()
        .expect("arrivals by tram have a line")
        .clone();
    let kind = world.state.occupants[occ].profile.kind.clone();
    if player {
        world.riders.players.insert(occ.clone());
    }
    let direction = if player {
        soonest_entry(world, &line, target)
    } else {
        let count = &mut world.riders.arrival_counts[usize::from(!shares_capacity(&kind))];
        let direction = DIRECTIONS[(*count % 2) as usize];
        *count += 1;
        direction
    };
    let target = match player
        .then(|| platform_stop(world, &line, direction, target))
        .flatten()
    {
        Some((stop, platform)) => {
            world
                .riders
                .destinations
                .insert(occ.clone(), Destination::Stop(stop));
            platform
        }
        None => target.clone(),
    };
    world.riders.arrivals.insert(occ.clone(), target);
    world
        .riders
        .arrival_queues
        .entry((line, direction))
        .or_default()
        .push(occ.clone());
}

/// The direction whose next entering vehicle brings a player joining for
/// `room` soonest: when `room` is a stop's platform, the one that stands at
/// that stop first (its entry, then its run from the portal, standing at
/// each stop between, as [`catch_tick`] estimates it); otherwise the one
/// that enters first. A vehicle already waiting at its portal enters now,
/// otherwise the next the timetable brings. Ties go east.
fn soonest_entry(world: &World, line: &PlaceId, room: &PlaceId) -> Direction {
    let info = &world.index.lines[line];
    let now = world.state.tick;
    let headway = u64::from(info.timetable.headway).max(1);
    let stop = info.stops.iter().find(|s| s.platforms.contains(room));
    DIRECTIONS
        .into_iter()
        .min_by_key(|d| {
            let run = stop.map_or(0, |stop| run_from_portal(info, stop, *d));
            let offset = u64::from(info.timetable.offset[d.index()]);
            let queued = world
                .waiting_entries
                .get(&(line.clone(), *d))
                .is_some_and(|q| !q.is_empty());
            let next = if queued {
                now
            } else if now <= offset {
                offset
            } else {
                offset + (now - offset).div_ceil(headway) * headway
            };
            (next + run, d.index())
        })
        .expect("two directions")
}

/// Ticks a vehicle running `direction` takes from entering at its portal
/// to standing at `stop`, standing at each stop between: an estimate, as
/// in [`catch_tick`].
fn run_from_portal(line: &LineInfo, stop: &StopInfo, direction: Direction) -> u64 {
    let s = sign(direction);
    let length = i64::from(line.vehicle.length);
    let speed = (i64::from(line.timetable.speed) * i64::from(CELL)).max(1) as u64;
    let front = portal(line, direction);
    let centre = centre_along(front, length, direction);
    let between = line
        .stops
        .iter()
        .filter(|x| {
            s * (i64::from(x.at) - centre) > 0 && s * (i64::from(stop.at) - i64::from(x.at)) > 0
        })
        .count() as u64;
    let stop_front = front_at(i64::from(stop.at), length, direction);
    ((s * (stop_front - front)).max(0) as u64).div_ceil(speed)
        + between * u64::from(line.timetable.dwell)
}

/// For a player joining for `room`, a stop's platform: that stop, and its
/// platform on the `direction` side (the room itself when it is that
/// side's), where the player steps off and stays. `None` when `room` is no
/// platform of `line`.
fn platform_stop(
    world: &World,
    line: &PlaceId,
    direction: Direction,
    room: &PlaceId,
) -> Option<(PlaceId, PlaceId)> {
    let stops = &world.index.lines[line].stops;
    stops
        .iter()
        .find(|s| &s.platforms[direction.index()] == room)
        .or_else(|| stops.iter().find(|s| s.platforms.contains(room)))
        .map(|s| (s.id.clone(), s.platforms[direction.index()].clone()))
}

/// Vehicle `id` has just entered its line: the arrivals queued at its
/// portal board it in arrival order, public ones while it has a slot and
/// hidden ones always, each bound for the stop nearest the room it came
/// for (see [`stop_for`]), or a joining player for the stop it was given
/// when it was queued. The rest wait for the next. Nothing is logged:
/// they were logged `Arrived`, and no one sees a portal.
fn take_arrivals(world: &mut World, id: &CityId) {
    let k = world
        .state
        .vehicles
        .iter()
        .position(|v| &v.id == id)
        .expect("it just entered");
    let key = (
        world.state.vehicles[k].line.clone(),
        world.state.vehicles[k].direction,
    );
    let Some(queue) = world.riders.arrival_queues.remove(&key) else {
        return;
    };
    let mut left = Vec::new();
    for occ in queue {
        if shares_capacity(&world.state.occupants[&occ].profile.kind) && full(world, k) {
            left.push(occ);
            continue;
        }
        take_aboard(world, k, &occ);
        if !world.riders.destinations.contains_key(&occ) {
            let stop = stop_for(world, &key.0, key.1, &world.riders.arrivals[&occ]);
            world
                .riders
                .destinations
                .insert(occ, Destination::Stop(stop));
        }
    }
    if !left.is_empty() {
        world.riders.arrival_queues.insert(key, left);
    }
}

/// The stop of `line` where an arrival bound for `target` steps off from a
/// vehicle running `direction`: the one whose platform on that side is the
/// shortest walk from `target`. Ties go to the stop reached first.
fn stop_for(world: &World, line: &PlaceId, direction: Direction, target: &PlaceId) -> PlaceId {
    let line = &world.index.lines[line];
    line.stops
        .iter()
        .min_by_key(|stop| {
            (
                world.walk_from_platform(&stop.platforms[direction.index()], target),
                sign(direction) * i64::from(stop.at),
            )
        })
        .expect("lines carrying arrivals have a stop")
        .id
        .clone()
}

/// A public departure walking to a platform (`ToPlatform`) that has come to
/// the end of its walk, or stands held up on the platform, begins waiting
/// there for the next vehicle on that platform's side, bound out of the
/// city, once the platform has room for it; until then it stands there.
/// One whose walk ended off the platform plans again, or, with no way to
/// any platform, walks out of the city instead.
fn reach_platforms(world: &mut World) {
    let walking: Vec<(CityId, PlaceId)> = world
        .state
        .occupants
        .iter()
        .filter(|(_, o)| matches!(o.location, Location::Leaving { .. }))
        .filter_map(|(id, o)| match &o.walk.as_ref()?.purpose {
            WalkPurpose::ToPlatform { stop } => Some((id.clone(), stop.clone())),
            _ => None,
        })
        .collect();
    for (occ, stop) in walking {
        let Some(nav) = world.nav.as_ref() else {
            return;
        };
        let o = &world.state.occupants[&occ];
        let Some(here) = o.pos.map(|p| nav.cell_of(p)) else {
            continue;
        };
        let Some((_, info)) = find_stop(&world.index, &stop) else {
            continue;
        };
        let side = DIRECTIONS
            .into_iter()
            .find(|d| nav.room_at(here) == Some(&info.platforms[d.index()]));
        let walk = o.walk.as_ref().expect("walking to a platform");
        let held_up = o.trail.is_empty() && side.is_some() && !world.track_cells.contains(&here);
        if !walk.path.is_empty() && !held_up {
            continue;
        }
        match side {
            Some(d) if world.may_enter(&info.platforms[d.index()], &occ) => {
                begin_waiting(world, &occ, &stop, d, Destination::RideOut, true);
            }
            Some(_) => {
                // The platform is full: stand here until it has room.
                let o = world
                    .state
                    .occupants
                    .get_mut(&occ)
                    .expect("occupant exists");
                o.walk.as_mut().expect("walking").path.clear();
            }
            None => match plan_platform_walk(world, &occ) {
                Some((stop, path)) => {
                    world.set_walk(&occ, path, WalkPurpose::ToPlatform { stop });
                }
                None => world.walk_to_depart(&occ),
            },
        }
    }
}

/// Where a public departure standing on the ground at `occ`'s cell walks
/// to wait for a vehicle: a platform of the nearest stop (the shortest walk
/// to either of its platforms, then the nearest standing point, for a
/// platform several stops share), on the side where the first vehicle it can
/// catch arrives (one still standing there when it gets there, by the
/// vehicles on the line and then the timetable). Ties go to the shorter
/// walk, then east. Returns the stop and the walk to the free standing
/// cell of that platform nearest the occupant, or `None` when no platform
/// can be reached.
pub(crate) fn plan_platform_walk(world: &World, occ: &CityId) -> Option<(PlaceId, Vec<Cell>)> {
    let nav = world.nav.as_ref()?;
    let here = nav.cell_of(world.state.occupants[occ].pos?);
    let (line, info, _) = world
        .index
        .lines
        .values()
        .flat_map(|line| line.stops.iter().map(move |stop| (line, stop)))
        .map(|(line, stop)| {
            // The shorter walk to either platform; for a platform shared
            // by several stops, the stop standing nearest.
            let key = DIRECTIONS
                .into_iter()
                .map(|d| {
                    let q = stop.stand[d.index()];
                    let p = nav.centre(here);
                    (
                        world.walk_to_platform(here, &stop.platforms[d.index()]),
                        i64::from(p.x - q.x).pow(2) + i64::from(p.z - q.z).pow(2),
                    )
                })
                .min()
                .expect("two directions");
            (line, stop, key)
        })
        .filter(|(_, _, (cost, _))| *cost != u32::MAX)
        .min_by_key(|(_, _, key)| *key)?;
    let now = world.state.tick;
    let taken = world.taken_by_others(occ);
    let mut best: Option<((Tick, u32, usize), Vec<Cell>)> = None;
    for d in DIRECTIONS {
        let platform = &info.platforms[d.index()];
        let cost = world.walk_to_platform(here, platform);
        if cost == u32::MAX {
            continue;
        }
        let spot = nav.nearest(nav.centre(here), &|c| {
            nav.room_at(c) == Some(platform) && world.good_to_stand(c) && !taken.contains(&c)
        });
        let Some(path) = spot.and_then(|c| nav.path_to(here, c, &|_| false)) else {
            continue;
        };
        let ready = now + (path.len() as u64).div_ceil(crate::world::STEPS_PER_TICK as u64);
        let key = (
            catch_tick(world, line, info, d, now, ready),
            cost,
            d.index(),
        );
        if best.as_ref().is_none_or(|(b, _)| key < *b) {
            best = Some((key, path));
        }
    }
    best.map(|(_, path)| (info.id.clone(), path))
}

/// When the first vehicle running `direction` that still stands at `stop`
/// at `ready` (when a walker gets there) reaches it: by the vehicles on
/// the line now, and after them by the timetable. It is an estimate, in
/// whole ticks: a vehicle runs `speed` cells a tick and stands `dwell`
/// ticks at each stop on the way, and holds are not foreseen.
fn catch_tick(
    world: &World,
    line: &LineInfo,
    stop: &StopInfo,
    direction: Direction,
    now: Tick,
    ready: Tick,
) -> Tick {
    let s = sign(direction);
    let length = i64::from(line.vehicle.length);
    let speed = (i64::from(line.timetable.speed) * i64::from(CELL)).max(1) as u64;
    let dwell = u64::from(line.timetable.dwell);
    let stop_front = front_at(i64::from(stop.at), length, direction);
    // Ticks to run from a front at `front` to the stop, standing at each
    // stop between.
    let run = |front: i64| -> u64 {
        let centre = centre_along(front, length, direction);
        let between = line
            .stops
            .iter()
            .filter(|x| {
                s * (i64::from(x.at) - centre) > 0 && s * (i64::from(stop.at) - i64::from(x.at)) > 0
            })
            .count() as u64;
        ((s * (stop_front - front)).max(0) as u64).div_ceil(speed) + between * dwell
    };
    let mut best: Option<Tick> = None;
    for v in world
        .state
        .vehicles
        .iter()
        .filter(|v| v.line == line.id && v.direction == direction)
    {
        let front = i64::from(v.along);
        let (arrives, leaves) = match &v.status {
            VehicleStatus::Standing {
                stop: here,
                doors_open_until,
            } if *here == stop.id => (now, *doors_open_until),
            status => {
                if s * (i64::from(stop.at) - centre_along(front, length, direction)) <= 0 {
                    continue;
                }
                let standing = match status {
                    VehicleStatus::Standing {
                        doors_open_until, ..
                    } => doors_open_until.saturating_sub(now),
                    _ => 0,
                };
                let arrives = now + standing + run(front);
                (arrives, arrives + dwell)
            }
        };
        if leaves > ready {
            best = Some(best.map_or(arrives, |b| b.min(arrives)));
        }
    }
    if let Some(arrives) = best {
        return arrives;
    }
    let headway = u64::from(line.timetable.headway).max(1);
    let offset = u64::from(line.timetable.offset[direction.index()]);
    let from_portal = run(portal(line, direction));
    let mut entry = if now < offset {
        offset.max(1)
    } else {
        offset + ((now - offset) / headway + 1) * headway
    };
    loop {
        let arrives = entry + from_portal;
        if arrives + dwell > ready {
            return arrives;
        }
        entry += headway;
    }
}

/// A `Depart` for `occ` while it waits on a platform or rides: a public
/// one rides out on its vehicle (its destination becomes the far portal),
/// and a hidden one, or a player leaving (`at_once`, see `Command::Depart`),
/// leaves at once, as hidden departures do (`Departed`, from nowhere).
/// Returns whether that settled it. An arrival still queued at a portal
/// just leaves the queue, and the ordinary departure then takes it out of
/// the city at once: no one has seen it.
pub(crate) fn depart_riding(world: &mut World, occ: &CityId, at_once: bool) -> bool {
    let o = &world.state.occupants[occ];
    let public = shares_capacity(&o.profile.kind);
    match o.location.clone() {
        Location::WaitingFor { .. } | Location::Aboard { .. } if public && !at_once => {
            world.riders.arrivals.remove(occ);
            world
                .riders
                .destinations
                .insert(occ.clone(), Destination::RideOut);
            true
        }
        location @ (Location::WaitingFor { .. } | Location::Aboard { .. }) => {
            if let Location::Aboard { vehicle, .. } = &location
                && let Some(v) = world.state.vehicles.iter_mut().find(|v| &v.id == vehicle)
            {
                v.riders.retain(|r| r != occ);
            }
            forget_waiting(world, occ);
            world.riders.arrivals.remove(occ);
            let o = world.state.occupants.get_mut(occ).expect("occupant exists");
            o.location = Location::Away;
            o.presence = PresenceRecord::default();
            o.shown = ShownPresence::default();
            o.pos = None;
            o.facing = 0;
            o.walk = None;
            o.goal = None;
            world.push(
                Some(occ),
                EventKind::Departed {
                    from: None,
                    via: None,
                },
            );
            true
        }
        _ => {
            world.riders.destinations.remove(occ);
            if world.riders.arrivals.remove(occ).is_some() {
                for queue in world.riders.arrival_queues.values_mut() {
                    queue.retain(|o| o != occ);
                }
                world.riders.arrival_queues.retain(|_, q| !q.is_empty());
            }
            false
        }
    }
}

// ---- The players' commands ----

/// The stop and direction whose platform `occ` stands on. A room serving
/// several stops, or both sides of one, counts as the platform of a stop
/// and side with a stop ahead to ride to where there is one, and of those
/// the one whose standing point is nearest (then east).
fn platform_under(world: &World, occ: &CityId) -> Option<(PlaceId, Direction)> {
    let room = underfoot(world, occ)?;
    let pos = world.state.occupants[occ].pos;
    world
        .index
        .lines
        .values()
        .flat_map(|line| line.stops.iter().map(move |stop| (line, stop)))
        .flat_map(|(line, stop)| {
            DIRECTIONS
                .into_iter()
                .filter(|d| stop.platforms[d.index()] == room)
                .map(move |d| (line, stop, d))
        })
        .min_by_key(|(line, stop, d)| {
            let nowhere = last_stop_ahead(line, stop.at, *d).is_none();
            let distance = pos.map_or(0, |p| {
                let q = stop.stand[d.index()];
                i64::from(p.x - q.x).pow(2) + i64::from(p.z - q.z).pow(2)
            });
            (nowhere, distance, d.index())
        })
        .map(|(_, stop, d)| (stop.id.clone(), d))
}

/// The `Board` command. Standing on a platform, `occ` waits there for the
/// next vehicle on that platform's side, bound for the last stop ahead: a
/// player never rides out. With a vehicle standing there with its doors
/// open, the Vehicles phase boards it on this same tick. It is refused:
///
/// - `NotOnPlatform` off a platform, or riding;
/// - `NotYourDirection` where no stop lies ahead on that side.
///
/// A full vehicle standing there does not refuse it: the occupant waits for
/// the next one, as anyone waiting there does, and the full one leaves it
/// behind (`LeftBehind`) as its doors close.
pub(crate) fn board(world: &mut World, occ: &CityId) -> Result<(), RejectReason> {
    let o = world
        .state
        .occupants
        .get(occ)
        .ok_or(RejectReason::UnknownOccupant)?;
    let waiting = match &o.location {
        Location::Away | Location::Leaving { .. } => return Err(RejectReason::NotPresent),
        Location::Aboard { .. } | Location::InTransit { .. } => {
            return Err(RejectReason::NotOnPlatform);
        }
        Location::WaitingFor {
            stop,
            direction: Some(d),
        } => Some((stop.clone(), *d)),
        _ => None,
    };
    let (stop, direction) = match waiting {
        Some(at) => at,
        None => platform_under(world, occ).ok_or(RejectReason::NotOnPlatform)?,
    };
    let (line, info) = find_stop(&world.index, &stop).expect("platforms belong to stops");
    let last = last_stop_ahead(line, info.at, direction)
        .ok_or(RejectReason::NotYourDirection)?
        .id
        .clone();
    wait_for(world, occ, &stop, Some(direction), Destination::Stop(last))?;
    world.riders.players.insert(occ.clone());
    Ok(())
}

/// The `Alight` command: `occ` steps off the vehicle it rides, standing at
/// a stop with its doors open, as a rider bound there would. It is refused
/// with `NotAboard` when not riding, and with `NotStanding` when the
/// vehicle is not standing with its doors open or no platform cell by a
/// door is free; then it stays aboard.
pub(crate) fn alight_now(world: &mut World, occ: &CityId) -> Result<(), RejectReason> {
    let o = world
        .state
        .occupants
        .get(occ)
        .ok_or(RejectReason::UnknownOccupant)?;
    let Location::Aboard { vehicle, .. } = &o.location else {
        return Err(RejectReason::NotAboard);
    };
    let k = world
        .state
        .vehicles
        .iter()
        .position(|v| &v.id == vehicle)
        .expect("riders ride a vehicle on the line");
    let stop = doors_open_at(&world.state.vehicles[k], world.state.tick)
        .ok_or(RejectReason::NotStanding)?;
    if alight(world, k, &stop, occ, false) {
        Ok(())
    } else {
        Err(RejectReason::NotStanding)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::Feed;
    use crate::invariants::check_world;
    use city_contracts::{
        CityId, Command, Direction, Event, EventKind, FeedHeader, HumanTier, Location,
        OccupantKind, OccupantProfile, Point, RejectReason, Target, VehicleStatus,
    };

    fn empty_feed() -> Feed {
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

    fn world() -> World {
        World::new(crate::index::fixtures::tram_street(), empty_feed(), 1)
            .expect("the tram street is valid")
    }

    fn vehicle<'a>(w: &'a World, id: &str) -> Option<&'a VehicleState> {
        w.snapshot().vehicles.iter().find(|v| v.id.as_str() == id)
    }

    fn player() -> Command {
        Command::Arrive {
            occupant: "person:you".into(),
            profile: Some(OccupantProfile {
                id: "person:you".into(),
                kind: OccupantKind::Human {
                    tier: HumanTier::Registered,
                },
                display_name: "You".into(),
                role: String::new(),
                department: None,
                home: None,
                work: None,
                shared_with: Default::default(),
                appearance: Default::default(),
            }),
            room: Some("room:north".into()),
            player: false,
        }
    }

    fn pos_of(w: &World, id: &str) -> Point {
        w.snapshot().occupants[&CityId::from(id)]
            .pos
            .expect("present")
    }

    /// Steps once, checking every invariant, and returns the tick's events.
    fn checked_step(w: &mut World) -> Vec<Event> {
        let before = w.snapshot().clone();
        let events = w.step();
        let violations = check_world(&before, w, &events);
        assert!(
            violations.is_empty(),
            "tick {}: {violations:?}",
            w.snapshot().tick
        );
        events
    }

    #[test]
    fn vehicles_enter_on_the_timetable_in_both_directions() {
        let mut w = world();
        let mut entered = Vec::new();
        for _ in 0..90 {
            for e in checked_step(&mut w) {
                if let EventKind::VehicleEntered { vehicle } = e.kind {
                    entered.push((e.tick, vehicle.to_string()));
                }
            }
        }
        let expected: Vec<(u64, String)> = [
            (15, "vehicle:boulevard:west:1"),
            (30, "vehicle:boulevard:east:1"),
            (45, "vehicle:boulevard:west:2"),
            (60, "vehicle:boulevard:east:2"),
            (75, "vehicle:boulevard:west:3"),
            (90, "vehicle:boulevard:east:3"),
        ]
        .into_iter()
        .map(|(t, id)| (t, id.to_string()))
        .collect();
        assert_eq!(entered, expected);
        // Each enters at its own portal, facing its own way.
        let east = vehicle(&w, "vehicle:boulevard:east:3").expect("just entered");
        assert_eq!((east.direction, east.along), (Direction::East, 0));
        let west = vehicle(&w, "vehicle:boulevard:west:3").expect("still running");
        assert_eq!(west.direction, Direction::West);
    }

    #[test]
    fn a_vehicle_stops_exactly_at_its_stop_and_stands_for_the_dwell() {
        let mut w = world();
        let id = "vehicle:boulevard:east:1";
        let mut standing = Vec::new();
        let mut opened = Vec::new();
        let mut closed = Vec::new();
        let mut alongs = Vec::new();
        for _ in 0..60 {
            for e in checked_step(&mut w) {
                match e.kind {
                    EventKind::DoorsOpened { vehicle, stop } if vehicle.as_str() == id => {
                        opened.push((e.tick, stop.to_string()));
                    }
                    EventKind::DoorsClosed { vehicle, stop } if vehicle.as_str() == id => {
                        closed.push((e.tick, stop.to_string()));
                    }
                    _ => {}
                }
            }
            if let Some(v) = vehicle(&w, id) {
                alongs.push(v.along);
                if let VehicleStatus::Standing { stop, .. } = &v.status {
                    assert_eq!(stop.as_str(), "stop:mid");
                    // Standing, it is centred on the stop: its front is half
                    // its length past the stop's `at`.
                    assert_eq!(
                        v.along,
                        2000 + 600,
                        "the front is half a length past the stop"
                    );
                    standing.push(w.snapshot().tick);
                }
            }
        }
        // Entering at 30 at the portal, it runs 7 m a tick: 700, 1400, 2100,
        // then stops short of 2800 with its centre on the stop at tick 34.
        assert_eq!(&alongs[..5], &[0, 700, 1400, 2100, 2600]);
        assert_eq!(standing, (34..46).collect::<Vec<_>>(), "stands 12 ticks");
        assert_eq!(opened, vec![(34, "stop:mid".to_string())]);
        assert_eq!(closed, vec![(46, "stop:mid".to_string())]);
        assert!(
            alongs.windows(2).all(|p| p[0] <= p[1]),
            "an eastbound front never goes back: {alongs:?}"
        );
    }

    #[test]
    fn a_vehicle_leaves_past_the_far_portal_and_is_removed() {
        let mut w = world();
        let mut left = Vec::new();
        let mut last_seen = None;
        for _ in 0..60 {
            for e in checked_step(&mut w) {
                if let EventKind::VehicleLeft { vehicle } = e.kind {
                    left.push((e.tick, vehicle.to_string()));
                }
            }
            if let Some(v) = vehicle(&w, "vehicle:boulevard:east:1") {
                last_seen = Some((w.snapshot().tick, v.along));
            }
        }
        // West:1 stands 19–30 and leaves once its rear passes along 0; east:1
        // runs 3300, 4000, 4700 after closing its doors at 46 and has gone
        // at 49, when its rear would pass 4000.
        assert_eq!(
            left,
            vec![
                (34, "vehicle:boulevard:west:1".to_string()),
                (49, "vehicle:boulevard:east:1".to_string()),
            ]
        );
        assert_eq!(last_seen, Some((48, 4700)));
        assert!(
            w.snapshot()
                .vehicles
                .iter()
                .all(|v| !v.id.as_str().ends_with(":1")),
            "both first vehicles are gone: {:?}",
            w.snapshot().vehicles
        );
    }

    /// Joins the player on the north platform and walks them to stand at
    /// (`x`, 162), just north of the eastbound track, where they arrive on
    /// the cell centred at `at`.
    fn player_standing_at(x: i32, at: Point) -> World {
        let mut w = world();
        w.submit(player());
        checked_step(&mut w);
        w.submit(Command::Go {
            occupant: "person:you".into(),
            to: Target::Point {
                pos: Point { x, z: 162 },
            },
        });
        for _ in 0..22 {
            checked_step(&mut w);
        }
        let o = &w.snapshot().occupants[&CityId::from("person:you")];
        assert!(o.walk.is_none(), "the player has arrived: {o:?}");
        assert_eq!(pos_of(&w, "person:you"), at);
        w
    }

    /// The player standing just north of the eastbound track at the stop.
    fn player_by_the_track() -> World {
        player_standing_at(2000, Point { x: 2012, z: 162 })
    }

    fn steer(w: &mut World, to: Point) {
        w.submit(Command::Steer {
            occupant: "person:you".into(),
            cells: vec![to],
        });
    }

    #[test]
    fn a_walker_on_the_track_holds_the_tram_until_it_steps_off() {
        let mut w = player_by_the_track();
        assert_eq!(w.snapshot().tick, 23);
        // Step onto the eastbound track, where the tram will stand.
        let on_track = Point { x: 2012, z: 187 };
        steer(&mut w, on_track);
        checked_step(&mut w);
        assert_eq!(pos_of(&w, "person:you"), on_track);

        let id = "vehicle:boulevard:east:1";
        let mut held_events = Vec::new();
        let mut held_along = None;
        while w.snapshot().tick < 35 {
            for e in checked_step(&mut w) {
                if let EventKind::VehicleHeld { vehicle } = e.kind {
                    held_events.push((e.tick, vehicle.to_string()));
                }
            }
            let v = vehicle(&w, id);
            if w.snapshot().tick >= 33 {
                let v = v.expect("east:1 is on the line");
                assert_eq!(v.status, VehicleStatus::Held, "tick {}", w.snapshot().tick);
                held_along.get_or_insert(v.along);
                assert_eq!(Some(v.along), held_along, "a held tram stands still");
            }
        }
        // The walker still stands on the track: held once, for one spell.
        assert_eq!(held_events, vec![(33, id.to_string())]);
        assert_eq!(pos_of(&w, "person:you"), on_track);

        // The walker steps off; the tram moves on within ten ticks.
        steer(&mut w, Point { x: 2012, z: 162 });
        let stepped_off = w.snapshot().tick + 1;
        let mut moved_at = None;
        for _ in 0..10 {
            checked_step(&mut w);
            let v = vehicle(&w, id).expect("still on the line");
            if Some(v.along) != held_along {
                moved_at = Some(w.snapshot().tick);
                break;
            }
        }
        let moved_at = moved_at.expect("the tram moved on within ten ticks");
        assert!(moved_at < stepped_off + 10);
        assert_eq!(pos_of(&w, "person:you"), Point { x: 2012, z: 162 });
    }

    #[test]
    fn a_walker_who_stays_on_the_track_is_stepped_aside_after_five_held_ticks() {
        // The player stands on the eastbound track and does nothing more (its
        // menu is open, say). After five ticks held, the core steps it to the
        // nearest good place to stand off the track, and the tram moves on
        // the tick after: nothing holds the line for ever.
        let run = || {
            let mut w = player_by_the_track();
            let on_track = Point { x: 2012, z: 187 };
            steer(&mut w, on_track);
            checked_step(&mut w);
            assert_eq!(pos_of(&w, "person:you"), on_track);
            let id = "vehicle:boulevard:east:1";
            let mut log = Vec::new();
            let (mut first_held, mut moved_at) = (None, None);
            while w.snapshot().tick < 60 && moved_at.is_none() {
                let events = checked_step(&mut w);
                match vehicle(&w, id).map(|v| &v.status) {
                    Some(VehicleStatus::Held) => {
                        first_held.get_or_insert(w.snapshot().tick);
                    }
                    Some(_) if first_held.is_some() => moved_at = Some(w.snapshot().tick),
                    _ => {}
                }
                log.extend(events);
            }
            let first_held = first_held.expect("the tram was held");
            let moved_at = moved_at.expect("the tram moved on");
            assert!(
                moved_at <= first_held + 5,
                "held from {first_held}, moved at {moved_at}"
            );
            let aside: Vec<(Tick, Point, Point)> = log
                .iter()
                .filter_map(|e| match &e.kind {
                    EventKind::SteppedAside { from, to } => Some((e.tick, *from, *to)),
                    _ => None,
                })
                .collect();
            assert_eq!(aside.len(), 1, "{aside:?}");
            let (tick, from, to) = aside[0];
            assert_eq!((tick, from), (first_held + 4, on_track));
            let nav = w.nav().unwrap();
            assert!(!w.track_cells.contains(&nav.cell_of(to)), "off the track");
            assert_eq!(pos_of(&w, "person:you"), to, "it stays where it was put");
            assert!(
                w.snapshot().occupants[&CityId::from("person:you")]
                    .walk
                    .is_none()
            );
            log.iter()
                .map(|e| serde_json::to_string(e).unwrap())
                .collect::<Vec<_>>()
        };
        assert_eq!(run(), run(), "replay is byte-identical");
    }

    #[test]
    fn walkers_may_not_step_onto_a_standing_tram() {
        let mut w = player_by_the_track();
        while w.snapshot().tick < 34 {
            checked_step(&mut w);
        }
        let v = vehicle(&w, "vehicle:boulevard:east:1").expect("standing");
        assert!(matches!(v.status, VehicleStatus::Standing { .. }));
        let fp = footprint(w.index(), w.nav().unwrap(), v);
        let onto = Point { x: 2012, z: 187 };
        assert!(fp.contains(&w.nav().unwrap().cell_of(onto)));
        steer(&mut w, onto);
        let events = checked_step(&mut w);
        assert!(events.iter().any(|e| matches!(
            e.kind,
            EventKind::Rejected {
                reason: RejectReason::BlockedStep,
                ..
            }
        )));
        assert_eq!(pos_of(&w, "person:you"), Point { x: 2012, z: 162 });
    }

    #[test]
    fn a_footprint_is_the_track_cells_along_the_vehicle_two_and_a_half_metres_wide() {
        let mut w = world();
        while w.snapshot().tick < 34 {
            w.step();
        }
        let v = vehicle(&w, "vehicle:boulevard:east:1").expect("standing");
        let nav = w.nav().unwrap();
        assert_eq!(
            half_width(&w.index().lines[&v.line]),
            125,
            "the tram kind's"
        );
        let fp = footprint(w.index(), nav, v);
        // 1200 cm long (48 cells, x 1400–2600) by 250 cm wide (10 cells,
        // z 175–425) on the eastbound track at z = 300.
        assert_eq!(fp.len(), 48 * 10);
        for c in &fp {
            let p = nav.centre(*c);
            assert!(
                (1400..=2600).contains(&p.x) && (175..=425).contains(&p.z),
                "{p:?}"
            );
        }
    }

    #[test]
    fn a_platform_150_cm_from_its_track_stays_clear_of_the_footprint() {
        let w = world();
        let nav = w.nav().unwrap();
        let line = &w.index().lines[&PlaceId::from("line:boulevard")];
        let clearance = half_width(line) + crate::footprint::MARGIN;
        let tracks = track_cells(w.index(), nav);
        for (platform, track_z) in [("room:north", 300), ("room:south", 600)] {
            let cells = nav.cells_in(&PlaceId::from(platform));
            assert!(!cells.is_empty());
            for c in cells {
                assert!(!tracks.contains(&c), "{platform}: {c:?} is under a tram");
                let off = i64::from((nav.centre(c).z - track_z).abs());
                assert!(
                    off > clearance,
                    "{platform}: {c:?} is {off} cm from its track"
                );
            }
        }
    }

    #[test]
    fn the_same_run_gives_a_byte_identical_log() {
        let run = || {
            let mut w = world();
            w.submit(player());
            let mut log = Vec::new();
            for t in 0..120u64 {
                if t == 3 {
                    w.submit(Command::Go {
                        occupant: "person:you".into(),
                        to: Target::Room {
                            room: "room:south".into(),
                        },
                    });
                }
                log.extend(checked_step(&mut w));
            }
            assert!(matches!(
                w.snapshot().occupants[&CityId::from("person:you")].location,
                Location::InRoom { .. }
            ));
            log.iter()
                .map(|e| serde_json::to_string(e).unwrap())
                .collect::<Vec<_>>()
        };
        let log = run();
        assert!(log.iter().any(|l| l.contains("VehicleLeft")));
        assert_eq!(log, run());
    }
}

#[cfg(test)]
mod boarding_tests {
    use super::*;
    use crate::Feed;
    use crate::invariants::check_world;
    use city_contracts::{
        Command, CommandType, Event, FeedHeader, HumanTier, Location, OccupantKind,
        OccupantProfile, OccupantState, PresenceRecord, RejectReason, ShownPresence, Snapshot,
        Target, WalkPurpose,
    };
    use proptest::prelude::*;

    const EAST_1: &str = "vehicle:boulevard:east:1";
    const EAST_2: &str = "vehicle:boulevard:east:2";

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

    /// The one-stop tram street, its vehicles carrying `capacity` public
    /// riders.
    fn street(capacity: u32) -> World {
        let mut m = crate::index::fixtures::tram_street();
        m.lines[0].vehicle.capacity = capacity;
        World::new(m, feed(), 1).expect("the tram street is valid")
    }

    fn three_stops() -> World {
        World::new(crate::index::fixtures::tram_three_stops(), feed(), 1)
            .expect("the three-stop street is valid")
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

    /// Puts `id` in `room`, standing still on the cell holding `at`.
    fn plant(w: &mut World, id: &str, kind: OccupantKind, room: &str, at: Point) {
        let nav = w.nav().expect("a layout");
        let pos = nav.centre(nav.cell_of(at));
        assert_eq!(
            nav.room_at(nav.cell_of(pos)).map(|r| r.as_str()),
            Some(room)
        );
        let id = CityId::from(id);
        let room = PlaceId::from(room);
        w.state.occupants.insert(
            id.clone(),
            OccupantState {
                profile: profile(id.as_str(), kind),
                location: Location::InRoom {
                    room: room.clone(),
                    seat: None,
                },
                presence: PresenceRecord::default(),
                shown: ShownPresence::default(),
                pos: Some(pos),
                facing: 0,
                walk: None,
                trail: Vec::new(),
                goal: Some(Target::Point { pos }),
                using: None,
            },
        );
        w.state
            .rooms
            .get_mut(&room)
            .expect("room exists")
            .occupants
            .push(id);
    }

    fn at(x: i32, z: i32) -> Point {
        Point { x, z }
    }

    /// Steps once, checking every invariant, and returns the tick's events.
    fn step(w: &mut World) -> Vec<Event> {
        let before = w.snapshot().clone();
        let events = w.step();
        let violations = check_world(&before, w, &events);
        assert!(
            violations.is_empty(),
            "tick {}: {violations:?}",
            w.snapshot().tick
        );
        events
    }

    /// Steps, checked, until `tick` is done, returning every event.
    fn run_to(w: &mut World, tick: Tick) -> Vec<Event> {
        let mut out = Vec::new();
        while w.snapshot().tick < tick {
            out.extend(step(w));
        }
        out
    }

    fn wait(w: &mut World, id: &str, stop: &str, direction: Option<Direction>, to: Destination) {
        wait_for(w, &CityId::from(id), &PlaceId::from(stop), direction, to)
            .expect("standing on the platform");
    }

    fn location(w: &World, id: &str) -> Location {
        w.snapshot().occupants[&CityId::from(id)].location.clone()
    }

    fn aboard(vehicle: &str, slot: u32) -> Location {
        Location::Aboard {
            vehicle: vehicle.into(),
            slot,
        }
    }

    /// (tick, occupant, vehicle) of every `Boarded`.
    fn boarded(events: &[Event]) -> Vec<(Tick, String, String)> {
        events
            .iter()
            .filter_map(|e| match &e.kind {
                EventKind::Boarded { vehicle } => Some((
                    e.tick,
                    e.occupant.as_ref().expect("a rider").to_string(),
                    vehicle.to_string(),
                )),
                _ => None,
            })
            .collect()
    }

    /// (tick, occupant, stop) of every `Alighted`.
    fn alighted(events: &[Event]) -> Vec<(Tick, String, String)> {
        events
            .iter()
            .filter_map(|e| match &e.kind {
                EventKind::Alighted { stop, .. } => Some((
                    e.tick,
                    e.occupant.as_ref().expect("a rider").to_string(),
                    stop.to_string(),
                )),
                _ => None,
            })
            .collect()
    }

    fn row(tick: Tick, who: &str, what: &str) -> (Tick, String, String) {
        (tick, who.to_string(), what.to_string())
    }

    #[test]
    fn waiters_board_first_come_first_served_up_to_capacity() {
        let mut w = street(2);
        plant(
            &mut w,
            "pa:mine",
            personal_agent(),
            "room:north",
            at(400, 100),
        );
        for k in 0..4 {
            let id = format!("person:w{k}");
            plant(&mut w, &id, public(), "room:north", at(500 + 100 * k, 100));
        }
        let east = Some(Direction::East);
        let out = || Destination::RideOut;
        run_to(&mut w, 3);
        wait(&mut w, "person:w3", "stop:mid", east, out());
        wait(&mut w, "pa:mine", "stop:mid", east, out());
        run_to(&mut w, 4);
        wait(&mut w, "person:w2", "stop:mid", east, out());
        wait(&mut w, "person:w1", "stop:mid", east, out());
        run_to(&mut w, 5);
        wait(&mut w, "person:w0", "stop:mid", east, out());
        assert_eq!(
            location(&w, "person:w0"),
            Location::WaitingFor {
                stop: "stop:mid".into(),
                direction: east
            }
        );

        // East:1 opens its doors at 34: first come, first served, by the
        // tick each started waiting, then by ID. The hidden agent boards
        // without taking a place.
        let events = run_to(&mut w, 34);
        assert_eq!(
            boarded(&events),
            vec![
                row(34, "pa:mine", EAST_1),
                row(34, "person:w3", EAST_1),
                row(34, "person:w1", EAST_1),
            ]
        );
        assert_eq!(location(&w, "pa:mine"), aboard(EAST_1, u32::MAX));
        assert_eq!(location(&w, "person:w3"), aboard(EAST_1, 0));
        assert_eq!(location(&w, "person:w1"), aboard(EAST_1, 1));
        for id in ["person:w3", "person:w1", "pa:mine"] {
            assert_eq!(w.snapshot().occupants[&CityId::from(id)].pos, None);
        }
        assert!(matches!(
            location(&w, "person:w2"),
            Location::WaitingFor { .. }
        ));

        // It closes full at 46: the two still waiting are left behind.
        let events = run_to(&mut w, 60);
        let left: Vec<(Tick, String)> = events
            .iter()
            .filter_map(|e| match &e.kind {
                EventKind::LeftBehind { stop, vehicle } => {
                    assert_eq!((stop.as_str(), vehicle.as_str()), ("stop:mid", EAST_1));
                    Some((e.tick, e.occupant.clone().unwrap().to_string()))
                }
                _ => None,
            })
            .collect();
        assert_eq!(
            left,
            vec![(46, "person:w2".to_string()), (46, "person:w0".to_string())]
        );
        // Riding out, its riders leave the city with it when it goes at 49.
        let departed: Vec<(Tick, String)> = events
            .iter()
            .filter_map(|e| match &e.kind {
                EventKind::Departed { from: None, via } => {
                    assert_eq!(via.as_ref().map(|v| v.as_str()), Some(EAST_1));
                    Some((e.tick, e.occupant.clone().unwrap().to_string()))
                }
                _ => None,
            })
            .collect();
        assert_eq!(
            departed,
            vec![
                (49, "pa:mine".to_string()),
                (49, "person:w3".to_string()),
                (49, "person:w1".to_string()),
            ]
        );
        assert_eq!(location(&w, "person:w3"), Location::Away);
        assert!(
            !w.riders
                .destinations
                .contains_key(&CityId::from("person:w3"))
        );

        // The next tram takes the two left behind, in the same order.
        let events = run_to(&mut w, 64);
        assert_eq!(
            boarded(&events),
            vec![row(64, "person:w2", EAST_2), row(64, "person:w0", EAST_2)]
        );
        assert_eq!(location(&w, "person:w2"), aboard(EAST_2, 0));
        assert_eq!(location(&w, "person:w0"), aboard(EAST_2, 1));
    }

    #[test]
    fn hidden_riders_take_no_slot_and_never_fill_the_vehicle() {
        let mut w = street(1);
        plant(
            &mut w,
            "pa:mine",
            personal_agent(),
            "room:north",
            at(400, 100),
        );
        plant(&mut w, "person:obs", observer(), "room:north", at(500, 100));
        plant(&mut w, "person:w0", public(), "room:north", at(600, 100));
        plant(&mut w, "person:w1", public(), "room:north", at(700, 100));
        run_to(&mut w, 1);
        for id in ["person:w1", "person:w0", "person:obs", "pa:mine"] {
            wait(
                &mut w,
                id,
                "stop:mid",
                Some(Direction::East),
                Destination::RideOut,
            );
        }
        let events = run_to(&mut w, 46);
        assert_eq!(
            boarded(&events),
            vec![
                row(34, "pa:mine", EAST_1),
                row(34, "person:obs", EAST_1),
                row(34, "person:w0", EAST_1),
            ]
        );
        assert_eq!(location(&w, "pa:mine"), aboard(EAST_1, u32::MAX));
        assert_eq!(location(&w, "person:obs"), aboard(EAST_1, u32::MAX));
        assert_eq!(location(&w, "person:w0"), aboard(EAST_1, 0));
        let left: Vec<String> = events
            .iter()
            .filter(|e| matches!(e.kind, EventKind::LeftBehind { .. }))
            .map(|e| e.occupant.clone().unwrap().to_string())
            .collect();
        assert_eq!(left, vec!["person:w1".to_string()]);
    }

    #[test]
    fn riders_alight_in_slot_order_and_a_boarder_takes_the_lowest_free_slot() {
        let mut w = three_stops();
        plant(&mut w, "person:r0", public(), "room:north-a", at(900, 100));
        plant(&mut w, "person:r1", public(), "room:north-a", at(1100, 100));
        plant(&mut w, "person:c0", public(), "room:tiny", at(3310, 110));
        let east = Some(Direction::East);
        run_to(&mut w, 1);
        wait(
            &mut w,
            "person:r0",
            "stop:a",
            east,
            Destination::Stop("stop:b".into()),
        );
        wait(
            &mut w,
            "person:r1",
            "stop:a",
            east,
            Destination::Stop("stop:c".into()),
        );
        wait(
            &mut w,
            "person:c0",
            "stop:b",
            east,
            Destination::Stop("stop:c".into()),
        );

        let events = run_to(&mut w, 33);
        assert_eq!(
            boarded(&events),
            vec![row(33, "person:r0", EAST_1), row(33, "person:r1", EAST_1)]
        );
        assert_eq!(location(&w, "person:r0"), aboard(EAST_1, 0));
        assert_eq!(location(&w, "person:r1"), aboard(EAST_1, 1));

        // At B, r0 steps off first, beside the front door, then c0 boards
        // into the slot r0 left.
        let events = run_to(&mut w, 47);
        let kinds: Vec<&str> = events
            .iter()
            .filter(|e| e.tick == 47)
            .filter_map(|e| match &e.kind {
                EventKind::DoorsOpened { vehicle, .. } if vehicle.as_str() == EAST_1 => {
                    Some("opened")
                }
                EventKind::Alighted { .. } => Some("alighted"),
                EventKind::Admitted { .. } => Some("admitted"),
                EventKind::Boarded { .. } => Some("boarded"),
                _ => None,
            })
            .collect();
        assert_eq!(kinds, vec!["opened", "alighted", "admitted", "boarded"]);
        assert_eq!(alighted(&events), vec![row(47, "person:r0", "stop:b")]);
        assert_eq!(
            location(&w, "person:r0"),
            Location::InRoom {
                room: "room:tiny".into(),
                seat: None
            }
        );
        let pos = w.snapshot().occupants[&CityId::from("person:r0")]
            .pos
            .expect("on the platform");
        let (dx, dz) = (i64::from(pos.x - 3400), i64::from(pos.z - 200));
        assert!(
            dx * dx + dz * dz <= 200 * 200,
            "within 2 m of the door: {pos:?}"
        );
        assert_eq!(location(&w, "person:c0"), aboard(EAST_1, 0));

        // At C both step off, in slot order.
        let events = run_to(&mut w, 61);
        assert_eq!(
            alighted(&events),
            vec![
                row(61, "person:c0", "stop:c"),
                row(61, "person:r1", "stop:c")
            ]
        );
        for id in ["person:c0", "person:r1"] {
            assert_eq!(
                location(&w, id),
                Location::InRoom {
                    room: "room:north-c".into(),
                    seat: None
                }
            );
        }
        assert!(w.riders.destinations.is_empty());
        assert!(w.snapshot().vehicles.iter().all(|v| v.riders.is_empty()));
    }

    #[test]
    fn a_full_platform_keeps_the_rider_aboard_to_the_next_stop() {
        let mut w = three_stops();
        let tiny: Vec<Point> = {
            let nav = w.nav().unwrap();
            nav.cells_in(&"room:tiny".into())
                .into_iter()
                .map(|c| nav.centre(c))
                .collect()
        };
        assert_eq!(tiny.len(), 16);
        for (k, p) in tiny.into_iter().enumerate() {
            plant(
                &mut w,
                &format!("sim:{k:02}"),
                OccupantKind::SimCitizen,
                "room:tiny",
                p,
            );
        }
        plant(&mut w, "person:r0", public(), "room:north-a", at(900, 100));
        run_to(&mut w, 1);
        let to_b = Destination::Stop("stop:b".into());
        wait(
            &mut w,
            "person:r0",
            "stop:a",
            Some(Direction::East),
            to_b.clone(),
        );

        run_to(&mut w, 33);
        assert_eq!(location(&w, "person:r0"), aboard(EAST_1, 0));
        // Standing at B from 47 to 58, every cell by the door is taken: the
        // rider stays aboard throughout, and rides on to C.
        let mut events = Vec::new();
        while w.snapshot().tick < 58 {
            events.extend(step(&mut w));
            assert_eq!(location(&w, "person:r0"), aboard(EAST_1, 0));
            assert_eq!(w.riders.destinations[&CityId::from("person:r0")], to_b);
        }
        events.extend(run_to(&mut w, 59));
        assert_eq!(
            w.riders.destinations[&CityId::from("person:r0")],
            Destination::Stop("stop:c".into())
        );
        events.extend(run_to(&mut w, 61));
        assert_eq!(alighted(&events), vec![row(61, "person:r0", "stop:c")]);
        assert_eq!(
            location(&w, "person:r0"),
            Location::InRoom {
                room: "room:north-c".into(),
                seat: None
            }
        );
        let present = w
            .snapshot()
            .occupants
            .values()
            .filter(|o| o.location != Location::Away)
            .count();
        assert_eq!(present, 17, "no one lost or duplicated");
    }

    #[test]
    fn waiting_needs_a_platform_of_that_stop_and_direction() {
        let mut w = three_stops();
        plant(&mut w, "person:s", public(), "room:street", at(1000, 250));
        plant(&mut w, "person:p", public(), "room:south", at(1000, 800));
        let refused = |w: &mut World, id: &str, stop: &str, d: Option<Direction>| {
            wait_for(
                w,
                &CityId::from(id),
                &PlaceId::from(stop),
                d,
                Destination::RideOut,
            )
        };
        assert_eq!(
            refused(&mut w, "person:s", "stop:a", None),
            Err(RejectReason::NotOnPlatform)
        );
        assert_eq!(
            refused(&mut w, "person:p", "stop:a", Some(Direction::East)),
            Err(RejectReason::NotOnPlatform)
        );
        assert_eq!(
            refused(&mut w, "person:p", "stop:nowhere", None),
            Err(RejectReason::NotOnPlatform)
        );
        assert_eq!(
            refused(&mut w, "person:p", "stop:a", Some(Direction::West)),
            Ok(())
        );
        // Waiting is a place of its own: out of the room's list.
        assert!(
            !w.snapshot().rooms[&PlaceId::from("room:south")]
                .occupants
                .contains(&CityId::from("person:p"))
        );
        run_to(&mut w, 2);
    }

    // ---- Task 5: arrivals, departures and the players' commands ----

    const WEST_1: &str = "vehicle:boulevard:west:1";

    /// The three-stop street with `arrivals: "tram"` and a shop north of C.
    fn by_tram() -> World {
        World::new(crate::index::fixtures::tram_arrivals(), feed(), 1)
            .expect("the tram arrivals street is valid")
    }

    /// The three-stop street with `room`'s capacity set to `capacity`.
    fn three_stops_with(room: &str, capacity: u32) -> World {
        let mut m = crate::index::fixtures::tram_three_stops();
        for r in m.city.districts[0].facilities[0].rooms.iter_mut() {
            if r.id.as_str() == room {
                r.capacity = capacity;
            }
        }
        World::new(m, feed(), 1).expect("valid")
    }

    fn arrive(w: &mut World, id: &str, kind: OccupantKind, room: &str) {
        w.submit(Command::Arrive {
            occupant: id.into(),
            profile: Some(profile(id, kind)),
            room: Some(room.into()),
            player: false,
        });
    }

    /// A player joins for `room`, as the bridge's `join` does.
    fn join(w: &mut World, id: &str, room: &str) {
        w.submit(Command::Arrive {
            occupant: id.into(),
            profile: Some(profile(id, public())),
            room: Some(room.into()),
            player: true,
        });
    }

    fn board(w: &mut World, id: &str) {
        w.submit(Command::Board {
            occupant: id.into(),
        });
    }

    fn alight_command(w: &mut World, id: &str) {
        w.submit(Command::Alight {
            occupant: id.into(),
        });
    }

    fn depart(w: &mut World, id: &str) {
        w.submit(Command::Depart {
            occupant: id.into(),
            player: false,
        });
    }

    /// (occupant, command, reason) of every `Rejected`.
    fn rejected(events: &[Event]) -> Vec<(String, CommandType, RejectReason)> {
        events
            .iter()
            .filter_map(|e| match &e.kind {
                EventKind::Rejected { command, reason } => Some((
                    e.occupant.as_ref().expect("a commander").to_string(),
                    *command,
                    reason.clone(),
                )),
                _ => None,
            })
            .collect()
    }

    /// (tick, occupant, vehicle or "-") of every `Departed`.
    fn departed(events: &[Event]) -> Vec<(Tick, String, String)> {
        events
            .iter()
            .filter_map(|e| match &e.kind {
                EventKind::Departed { via, .. } => Some((
                    e.tick,
                    e.occupant.as_ref().expect("a leaver").to_string(),
                    via.as_ref().map_or("-".to_string(), ToString::to_string),
                )),
                _ => None,
            })
            .collect()
    }

    fn waiting(stop: &str, direction: Direction) -> Location {
        Location::WaitingFor {
            stop: stop.into(),
            direction: Some(direction),
        }
    }

    fn in_room(room: &str) -> Location {
        Location::InRoom {
            room: room.into(),
            seat: None,
        }
    }

    fn destination(w: &World, id: &str) -> Option<Destination> {
        w.riders.destinations.get(&CityId::from(id)).cloned()
    }

    /// The cells from `id`'s cell one row at a time towards +z, `n` of them.
    fn steps_south(w: &World, id: &str, n: i32) -> Vec<Point> {
        let nav = w.nav().unwrap();
        let from = nav.cell_of(pos_of(w, id));
        (1..=n)
            .map(|k| {
                nav.centre(Cell {
                    i: from.i,
                    j: from.j + k,
                })
            })
            .collect()
    }

    fn pos_of(w: &World, id: &str) -> Point {
        w.snapshot().occupants[&CityId::from(id)]
            .pos
            .expect("on the ground")
    }

    #[test]
    fn arrivals_ride_in_and_step_off_at_the_stop_nearest_their_room() {
        let mut w = by_tram();
        // Agents alternate portals, east first; the hidden agent alternates
        // on its own, so it comes from the east too.
        arrive(&mut w, "person:e", OccupantKind::GuildAgent, "room:shop");
        arrive(&mut w, "person:w", OccupantKind::GuildAgent, "room:shop");
        arrive(&mut w, "pa:mine", personal_agent(), "room:shop");
        let ids = ["person:e", "person:w", "pa:mine"];
        let mut events = Vec::new();
        let mut stepped_off: BTreeSet<String> = BTreeSet::new();
        while w.snapshot().tick < 160 {
            let now = step(&mut w);
            for e in &now {
                if let EventKind::Alighted { .. } = e.kind {
                    stepped_off.insert(e.occupant.clone().unwrap().to_string());
                }
            }
            // No arrival is on the ground before it steps off a tram.
            for id in ids {
                if !stepped_off.contains(id) {
                    assert_eq!(
                        w.snapshot().occupants[&CityId::from(id)].pos,
                        None,
                        "{id} on the ground at tick {}",
                        w.snapshot().tick
                    );
                }
            }
            match w.snapshot().tick {
                1 => {
                    for id in ids {
                        assert_eq!(
                            location(&w, id),
                            Location::Arriving {
                                room: "room:shop".into()
                            }
                        );
                    }
                }
                15 => assert_eq!(location(&w, "person:w"), aboard(WEST_1, 0)),
                30 => {
                    assert_eq!(location(&w, "person:e"), aboard(EAST_1, 0));
                    assert_eq!(location(&w, "pa:mine"), aboard(EAST_1, u32::MAX));
                }
                _ => {}
            }
            events.extend(now);
        }
        // `Arrived` is logged at once, for the room each is bound for.
        let arrived: Vec<(Tick, String, String)> = events
            .iter()
            .filter_map(|e| match &e.kind {
                EventKind::Arrived { room } => Some(row(
                    e.tick,
                    e.occupant.as_ref().unwrap().as_str(),
                    room.as_str(),
                )),
                _ => None,
            })
            .collect();
        assert_eq!(
            arrived,
            vec![
                row(1, "person:e", "room:shop"),
                row(1, "person:w", "room:shop"),
                row(1, "pa:mine", "room:shop"),
            ]
        );
        // C's platforms are the nearest the shop on both sides: west:1
        // stands there at 18, east:1 at 61.
        assert_eq!(
            alighted(&events),
            vec![
                row(18, "person:w", "stop:c"),
                row(61, "person:e", "stop:c"),
                row(61, "pa:mine", "stop:c"),
            ]
        );
        // Each then walks in as after an ordinary Go: out of the platform
        // and admitted to the shop.
        let story: Vec<String> = events
            .iter()
            .filter(|e| {
                e.occupant
                    .as_ref()
                    .is_some_and(|o| o.as_str() == "person:e")
            })
            .filter_map(|e| match &e.kind {
                EventKind::Arrived { .. } => Some("arrived".to_string()),
                EventKind::Alighted { .. } => Some("alighted".to_string()),
                EventKind::Admitted { room } => Some(format!("admitted {room}")),
                EventKind::TransitStarted { to, .. } => Some(format!("walking to {to}")),
                _ => None,
            })
            .collect();
        assert_eq!(
            story,
            [
                "arrived",
                "alighted",
                "admitted room:north-c",
                "walking to room:shop",
                "admitted room:shop"
            ]
        );
        for id in ids {
            assert_eq!(location(&w, id), in_room("room:shop"), "{id}");
        }
        assert!(w.riders.arrivals.is_empty());
    }

    #[test]
    fn a_departure_walks_to_the_platform_of_the_first_tram_it_can_catch() {
        let mut w = by_tram();
        plant(&mut w, "person:d", public(), "room:north-c", at(5000, 100));
        plant(
            &mut w,
            "pa:mine",
            personal_agent(),
            "room:north-c",
            at(5200, 100),
        );
        run_to(&mut w, 1);
        depart(&mut w, "person:d");
        depart(&mut w, "pa:mine");
        let mut events = step(&mut w);
        let o = &w.snapshot().occupants[&CityId::from("person:d")];
        assert_eq!(
            o.location,
            Location::Leaving {
                from: Some("room:north-c".into())
            }
        );
        let walk = o.walk.as_ref().expect("walking to a platform");
        assert_eq!(
            walk.purpose,
            WalkPurpose::ToPlatform {
                stop: "stop:c".into()
            }
        );
        // West:1 stands at C from 18 to 30, after a walk of a few ticks
        // across the street; east:1 not until 61. So the south platform.
        let nav = w.nav().unwrap();
        let end = nav.cell_of(*walk.path.last().expect("a path"));
        assert_eq!(nav.room_at(end).map(|r| r.as_str()), Some("room:south"));
        // A hidden occupant walks out as today.
        assert_eq!(
            w.snapshot().occupants[&CityId::from("pa:mine")]
                .walk
                .as_ref()
                .map(|w| w.purpose.clone()),
            Some(WalkPurpose::ToExit)
        );
        let mut waited = None;
        while w.snapshot().tick < 120 {
            events.extend(step(&mut w));
            if waited.is_none() && location(&w, "person:d") == waiting("stop:c", Direction::West) {
                waited = Some(w.snapshot().tick);
                assert_eq!(destination(&w, "person:d"), Some(Destination::RideOut));
            }
        }
        assert!(waited.is_some_and(|t| t < 18), "waiting by {waited:?}");
        assert_eq!(boarded(&events), vec![row(18, "person:d", WEST_1)]);
        let gone: Vec<(Tick, String, String)> = departed(&events)
            .into_iter()
            .filter(|d| d.1 == "person:d")
            .collect();
        assert_eq!(gone.len(), 1);
        assert_eq!(gone[0].2, WEST_1, "it rides out on the tram it boarded");
        assert_eq!(location(&w, "person:d"), Location::Away);
    }

    #[test]
    fn a_player_who_boards_rides_to_the_last_stop_and_never_rides_out() {
        let mut w = three_stops_with("room:north-c", 1);
        plant(
            &mut w,
            "sim:c",
            OccupantKind::SimCitizen,
            "room:north-c",
            at(5800, 100),
        );
        plant(&mut w, "person:you", public(), "room:north-a", at(900, 100));
        run_to(&mut w, 1);
        board(&mut w, "person:you");
        let mut events = step(&mut w);
        assert_eq!(
            location(&w, "person:you"),
            waiting("stop:a", Direction::East)
        );
        assert_eq!(
            destination(&w, "person:you"),
            Some(Destination::Stop("stop:c".into()))
        );
        events.extend(run_to(&mut w, 60));
        let before = w.snapshot().clone();
        let at_c = w.step();
        assert_eq!(boarded(&events), vec![row(33, "person:you", EAST_1)]);
        // It passes B, and steps off at C although C's platform is at its
        // capacity: a rider steps off wherever a cell is free.
        assert_eq!(alighted(&at_c), vec![row(61, "person:you", "stop:c")]);
        assert_eq!(location(&w, "person:you"), in_room("room:north-c"));
        assert_eq!(
            w.snapshot().rooms[&PlaceId::from("room:north-c")]
                .occupants
                .len(),
            2
        );
        assert_eq!(check_world(&before, &w, &at_c), vec![]);
        // Without the alighting to account for it, the room is over its
        // capacity.
        let unexplained: Vec<Event> = at_c
            .iter()
            .filter(|e| !matches!(e.kind, EventKind::Alighted { .. }))
            .cloned()
            .collect();
        assert!(
            crate::invariants::check_all(&before, w.snapshot(), &unexplained)
                .iter()
                .any(|v| v.invariant == 1)
        );
        events.extend(at_c);
        events.extend(run_to(&mut w, 120));
        assert!(departed(&events).is_empty());
    }

    #[test]
    fn a_rider_bound_for_the_last_stop_holds_the_doors_until_a_cell_frees() {
        let mut m = crate::index::fixtures::tram_three_stops();
        m.lines[0].stops.pop();
        let mut w = World::new(m, feed(), 1).expect("valid without C");
        let tiny: Vec<Point> = {
            let nav = w.nav().unwrap();
            nav.cells_in(&"room:tiny".into())
                .into_iter()
                .map(|c| nav.centre(c))
                .collect()
        };
        for (k, p) in tiny.into_iter().enumerate() {
            plant(
                &mut w,
                &format!("sim:{k:02}"),
                OccupantKind::SimCitizen,
                "room:tiny",
                p,
            );
        }
        plant(&mut w, "person:you", public(), "room:north-a", at(900, 100));
        run_to(&mut w, 1);
        // In the front row, by the door the tiny platform lies beside.
        wait(
            &mut w,
            "person:you",
            "stop:a",
            Some(Direction::East),
            Destination::Stop("stop:b".into()),
        );
        let mut events = run_to(&mut w, 47);
        assert_eq!(
            destination(&w, "person:you"),
            Some(Destination::Stop("stop:b".into()))
        );
        // B is the last stop east: the doors stay open past the dwell (59)
        // while the rider cannot step off.
        while w.snapshot().tick < 62 {
            events.extend(step(&mut w));
            assert_eq!(location(&w, "person:you"), aboard(EAST_1, 0));
            assert!(matches!(
                &vehicle_state(&w, EAST_1).status,
                VehicleStatus::Standing { stop, .. } if stop.as_str() == "stop:b"
            ));
        }
        // The platform's only way off is under the tram: a cell frees when
        // a waiter there boards it.
        wait(
            &mut w,
            "sim:00",
            "stop:b",
            Some(Direction::East),
            Destination::RideOut,
        );
        events.extend(run_to(&mut w, 90));
        assert_eq!(
            boarded(&events),
            vec![row(33, "person:you", EAST_1), row(63, "sim:00", EAST_1)]
        );
        let off = alighted(&events);
        assert_eq!(off, vec![row(64, "person:you", "stop:b")]);
        let closed_at_b: Vec<Tick> = events
            .iter()
            .filter_map(|e| match &e.kind {
                EventKind::DoorsClosed { vehicle, stop }
                    if vehicle.as_str() == EAST_1 && stop.as_str() == "stop:b" =>
                {
                    Some(e.tick)
                }
                _ => None,
            })
            .collect();
        assert_eq!(closed_at_b.len(), 1);
        assert!(closed_at_b[0] > off[0].0, "the doors close after it is off");
        assert_eq!(location(&w, "person:you"), in_room("room:tiny"));
        assert!(
            departed(&events).iter().all(|d| d.1 != "person:you"),
            "it never rides out"
        );
    }

    /// The three-stop street without C, so B (the tiny platform) is the
    /// last stop east, its every cell held by a sim, and vehicles carrying
    /// `capacity`.
    fn packed_terminal(capacity: u32) -> World {
        let mut m = crate::index::fixtures::tram_three_stops();
        m.lines[0].stops.pop();
        m.lines[0].vehicle.capacity = capacity;
        let mut w = World::new(m, feed(), 1).expect("valid without C");
        let tiny: Vec<Point> = {
            let nav = w.nav().unwrap();
            nav.cells_in(&"room:tiny".into())
                .into_iter()
                .map(|c| nav.centre(c))
                .collect()
        };
        for (k, p) in tiny.into_iter().enumerate() {
            plant(
                &mut w,
                &format!("sim:{k:02}"),
                OccupantKind::SimCitizen,
                "room:tiny",
                p,
            );
        }
        w
    }

    #[test]
    fn a_held_tram_leaves_within_one_dwell_and_the_line_runs_on() {
        let mut w = packed_terminal(4);
        let riders = ["person:p0", "person:p1", "person:p2", "person:p3"];
        for (k, id) in riders.iter().enumerate() {
            plant(
                &mut w,
                id,
                public(),
                "room:north-a",
                at(600 + 200 * k as i32, 100),
            );
        }
        run_to(&mut w, 1);
        for id in riders {
            board(&mut w, id);
        }
        let events = run_to(&mut w, 160);
        assert_eq!(boarded(&events).len(), 4, "a full tram");
        // The dwell at B ends at 59; the doors stay open one dwell more,
        // and then everyone bound there steps off wherever there is room.
        let closed: Vec<Tick> = events
            .iter()
            .filter_map(|e| match &e.kind {
                EventKind::DoorsClosed { vehicle, stop }
                    if vehicle.as_str() == EAST_1 && stop.as_str() == "stop:b" =>
                {
                    Some(e.tick)
                }
                _ => None,
            })
            .collect();
        assert_eq!(closed, vec![71]);
        let off = alighted(&events);
        assert_eq!(off.len(), 4);
        for (tick, id, stop) in &off {
            assert_eq!((*tick, stop.as_str()), (70, "stop:b"), "{id}");
            assert!(matches!(location(&w, id), Location::InRoom { .. }), "{id}");
        }
        assert!(departed(&events).is_empty(), "no one rides out");
        // The line runs on: the trams behind enter and leave in turn.
        let happened = |what: &str, id: &str| {
            events.iter().any(|e| match &e.kind {
                EventKind::VehicleEntered { vehicle } => what == "in" && vehicle.as_str() == id,
                EventKind::VehicleLeft { vehicle } => what == "out" && vehicle.as_str() == id,
                _ => false,
            })
        };
        for id in [EAST_1, EAST_2, "vehicle:boulevard:east:3"] {
            assert!(happened("in", id), "{id} entered");
        }
        assert!(happened("out", EAST_1) && happened("out", EAST_2));
        assert!(w.riders.holds.is_empty());
    }

    #[test]
    fn a_vehicle_waits_at_a_blocked_portal_and_enters_once_it_clears() {
        // A tram every 6 ticks each way, standing 2 at the stop. A walker on
        // the eastbound track 2 m in from the west portal holds east:1 as it
        // enters at 6, its body still wholly outside the line, until the
        // walker is stepped aside after five ticks held (at 11). East:1 runs
        // to 700 at 12, its rear still short of the portal, so east:2, due
        // then, waits there; east:1 clears the portal at 13 and east:2
        // enters behind it, keeping its number. East:3 is on time at 18.
        // Every tick is checked, spacing included.
        let mut m = crate::index::fixtures::tram_street();
        m.lines[0].timetable.headway = 6;
        m.lines[0].timetable.dwell = 2;
        m.lines[0].timetable.offset = [0, 3];
        let mut w = World::new(m, feed(), 1).expect("valid");
        plant(&mut w, "person:you", public(), "room:street", at(212, 312));
        let mut events = run_to(&mut w, 12);
        let east: Vec<(i32, VehicleStatus)> = w
            .snapshot()
            .vehicles
            .iter()
            .filter(|v| v.direction == Direction::East)
            .map(|v| (v.along, v.status.clone()))
            .collect();
        assert_eq!(east, vec![(700, VehicleStatus::Running)], "east:2 waits");
        events.extend(run_to(&mut w, 20));
        let entered: Vec<(Tick, String)> = events
            .iter()
            .filter_map(|e| match &e.kind {
                EventKind::VehicleEntered { vehicle } if vehicle.as_str().contains(":east:") => {
                    Some((e.tick, vehicle.to_string()))
                }
                _ => None,
            })
            .collect();
        assert_eq!(
            entered,
            vec![
                (6, "vehicle:boulevard:east:1".to_string()),
                (13, "vehicle:boulevard:east:2".to_string()),
                (18, "vehicle:boulevard:east:3".to_string()),
            ]
        );
        let aside: Vec<Tick> = events
            .iter()
            .filter(|e| matches!(e.kind, EventKind::SteppedAside { .. }))
            .map(|e| e.tick)
            .collect();
        assert_eq!(aside, vec![11]);
    }

    #[test]
    fn a_hidden_rider_never_holds_the_doors_open() {
        // A personal agent bound for B, the last stop east, finds no platform
        // cell within reach of its door (the tiny platform is by the front
        // door). Hidden riders count against nothing the public sees, so it
        // never holds the doors: they close when the dwell ends, and it steps
        // off wherever there is room as they do.
        let mut w = packed_terminal(40);
        plant(
            &mut w,
            "pa:mine",
            personal_agent(),
            "room:north-a",
            at(900, 100),
        );
        run_to(&mut w, 1);
        wait(
            &mut w,
            "pa:mine",
            "stop:a",
            Some(Direction::East),
            Destination::Stop("stop:b".into()),
        );
        let events = run_to(&mut w, 90);
        assert_eq!(boarded(&events), vec![row(33, "pa:mine", EAST_1)]);
        let closed_at_b: Vec<Tick> = events
            .iter()
            .filter_map(|e| match &e.kind {
                EventKind::DoorsClosed { vehicle, stop }
                    if vehicle.as_str() == EAST_1 && stop.as_str() == "stop:b" =>
                {
                    Some(e.tick)
                }
                _ => None,
            })
            .collect();
        assert_eq!(closed_at_b, vec![59], "the dwell, and no longer");
        assert_eq!(alighted(&events), vec![row(58, "pa:mine", "stop:b")]);
        assert!(matches!(location(&w, "pa:mine"), Location::InRoom { .. }));
        assert!(departed(&events).is_empty(), "it never rides out");
        assert!(w.riders.holds.is_empty());
    }

    #[test]
    fn alight_works_while_the_doors_are_held_open() {
        let mut w = packed_terminal(40);
        plant(&mut w, "person:h", public(), "room:north-a", at(900, 100));
        plant(&mut w, "person:p", public(), "room:north-a", at(1100, 100));
        run_to(&mut w, 1);
        // Both ride in the front row, by the door the tiny platform lies
        // beside.
        for id in ["person:h", "person:p"] {
            wait(
                &mut w,
                id,
                "stop:a",
                Some(Direction::East),
                Destination::Stop("stop:b".into()),
            );
        }
        run_to(&mut w, 40);
        // p means to ride out now; h is bound for B, the last stop.
        depart(&mut w, "person:p");
        run_to(&mut w, 62);
        // A sim boards at 63, freeing a cell by the front door after h has
        // tried for one; p asks to step off at 64, while the doors are
        // held open for h, and takes it.
        wait(
            &mut w,
            "sim:00",
            "stop:b",
            Some(Direction::East),
            Destination::RideOut,
        );
        run_to(&mut w, 63);
        alight_command(&mut w, "person:p");
        let events = step(&mut w);
        assert!(rejected(&events).is_empty(), "{:?}", rejected(&events));
        assert_eq!(alighted(&events), vec![row(64, "person:p", "stop:b")]);
        assert_eq!(location(&w, "person:p"), in_room("room:tiny"));
        assert_eq!(location(&w, "person:h"), aboard(EAST_1, 0));
    }

    #[test]
    fn every_platform_needs_somewhere_off_the_track_to_stand() {
        let mut m = crate::index::fixtures::tram_street();
        // A platform stands clear of its own line's trams (validation sees
        // to that), but another line's may run over it. Here a second line,
        // with no stops, runs its eastbound track along the north platform,
        // 75 cm in: all of that platform lies under its trams.
        let mut cross = m.lines[0].clone();
        cross.id = "line:cross".into();
        cross.points = vec![Point { x: 0, z: -75 }, Point { x: 4000, z: -75 }];
        cross.tracks = [150, -150];
        cross.stops.clear();
        m.lines.push(cross);
        m.city.entrances = vec![Point { x: 0, z: 850 }];
        assert!(
            crate::validate(&m).valid,
            "{:?}",
            crate::validate(&m).issues
        );
        let Err(issues) = World::new(m, feed(), 1) else {
            panic!("a platform with nowhere to stand is refused");
        };
        assert_eq!(issues.len(), 1);
        assert_eq!(issues[0].code, "line-platform-no-standing");
        assert_eq!(issues[0].place.as_deref(), Some("room:north"));
    }

    #[test]
    fn a_joining_player_takes_the_tram_that_reaches_its_stop_first() {
        let mut w = by_tram();
        // An agent comes first, on east:1, so the alternation would send the
        // next arrival west.
        arrive(&mut w, "agent:a", OccupantKind::GuildAgent, "room:shop");
        run_to(&mut w, 19);
        // At 20 east:1 (entering at 30) reaches A at 33, long before west:2
        // (45): the player takes it, while a person in the crowd takes its
        // turn, west.
        join(&mut w, "person:you", "room:north-a");
        arrive(&mut w, "person:crowd", public(), "room:north-a");
        let mut events = run_to(&mut w, 30);
        // A player sits mid-car, in the seat nearest the tram's middle.
        assert_eq!(location(&w, "person:you"), aboard(EAST_1, 16));
        events.extend(run_to(&mut w, 45));
        assert_eq!(
            location(&w, "person:crowd"),
            aboard("vehicle:boulevard:west:2", 0)
        );
        events.extend(run_to(&mut w, 50));
        assert!(alighted(&events).contains(&row(33, "person:you", "stop:a")));
        assert_eq!(location(&w, "person:you"), in_room("room:north-a"));
        // At 61 west:3 enters first (75), but it stands at C and B before
        // A: east:3 (entering at 90) reaches A at 93, first. Joining for C,
        // west:3 reaches it at 78, long before east:3 (after A and B). Each
        // steps off on its tram's side.
        run_to(&mut w, 60);
        join(&mut w, "person:two", "room:north-a");
        join(&mut w, "person:three", "room:north-c");
        let events = run_to(&mut w, 160);
        let rode = |who: &str| -> Vec<(String, String)> {
            events
                .iter()
                .filter(|e| e.occupant.as_ref().is_some_and(|o| o.as_str() == who))
                .filter_map(|e| match &e.kind {
                    EventKind::Alighted { vehicle, stop } => {
                        Some((vehicle.to_string(), stop.to_string()))
                    }
                    _ => None,
                })
                .collect()
        };
        assert_eq!(
            rode("person:two"),
            vec![("vehicle:boulevard:east:3".to_string(), "stop:a".to_string())]
        );
        assert_eq!(location(&w, "person:two"), in_room("room:north-a"));
        assert_eq!(
            rode("person:three"),
            vec![("vehicle:boulevard:west:3".to_string(), "stop:c".to_string())]
        );
        assert_eq!(location(&w, "person:three"), in_room("room:south"));
    }

    #[test]
    fn a_joining_player_carried_past_its_stop_stays_where_it_steps_off() {
        // Joining for B's tiny platform, every cell of it held: the player
        // cannot step off there and rides on to C. It stays on C's platform,
        // where it stepped off, rather than walking back to B by itself: a
        // player's walks are its own.
        let mut w = by_tram();
        let tiny: Vec<Point> = {
            let nav = w.nav().unwrap();
            nav.cells_in(&"room:tiny".into())
                .into_iter()
                .map(|c| nav.centre(c))
                .collect()
        };
        for (k, p) in tiny.into_iter().enumerate() {
            plant(
                &mut w,
                &format!("sim:{k:02}"),
                OccupantKind::SimCitizen,
                "room:tiny",
                p,
            );
        }
        // At 16 east:1 (entering at 30) reaches B first, west:2 (45) not
        // till after C.
        run_to(&mut w, 16);
        join(&mut w, "person:you", "room:tiny");
        let events = run_to(&mut w, 90);
        let off: Vec<(Tick, String, String)> = alighted(&events)
            .into_iter()
            .filter(|(_, who, _)| who == "person:you")
            .collect();
        assert_eq!(off.len(), 1, "{off:?}");
        assert_eq!(off[0].2, "stop:c", "carried past B");
        assert_eq!(location(&w, "person:you"), in_room("room:north-c"));
        let o = &w.snapshot().occupants[&CityId::from("person:you")];
        assert!(o.walk.is_none(), "it does not walk back to B: {:?}", o.walk);
        assert!(!w.riders.arrivals.contains_key(&CityId::from("person:you")));
    }

    #[test]
    fn a_player_sits_mid_car_at_a_window_and_never_in_a_cab() {
        // The slot grid's first and last rows lie in the cabs' noses, walled
        // but for a sliver of window. A player takes the free seat nearest
        // the middle of the tram instead, on the left (the platform side on
        // these tracks); the crowd keeps taking the lowest free slot.
        let mut w = three_stops();
        plant(
            &mut w,
            "person:crowd",
            public(),
            "room:north-a",
            at(700, 100),
        );
        plant(&mut w, "person:you", public(), "room:north-a", at(900, 100));
        plant(
            &mut w,
            "person:zoe",
            public(),
            "room:north-a",
            at(1100, 100),
        );
        run_to(&mut w, 1);
        wait(
            &mut w,
            "person:crowd",
            "stop:a",
            Some(Direction::East),
            Destination::RideOut,
        );
        board(&mut w, "person:you");
        board(&mut w, "person:zoe");
        run_to(&mut w, 34);
        assert_eq!(location(&w, "person:crowd"), aboard(EAST_1, 0));
        // 40 riders in 20 rows 60 cm apart on a 12 m tram: rows 8 (510 cm
        // behind the front) and 11 (690 cm) are the seats nearest its middle
        // door (600 cm), rows 9 and 10 being standing room by that door.
        assert_eq!(location(&w, "person:you"), aboard(EAST_1, 16));
        assert_eq!(location(&w, "person:zoe"), aboard(EAST_1, 17));
        let spec = &w.index().lines[&PlaceId::from("line:boulevard")].vehicle;
        for slot in [16, 17] {
            assert!(slot_seated(spec, slot), "slot {slot} is a seat");
            let along = slot_along(spec, slot);
            assert!(
                (spec.length / 4..=spec.length * 3 / 4).contains(&(along as i32)),
                "slot {slot} is mid-car, {along} cm behind the front"
            );
        }
    }

    /// Two stops on an island platform between the tracks, which is both
    /// platforms of each: `stop:m` at 30 m and `stop:e` at 50 m. The tracks
    /// run at z = 185 (eastbound) and z = 615 (westbound), the island from
    /// z = 320 to 480, 135 cm from each: a tram and the body clearance.
    fn island() -> World {
        let m: city_contracts::Manifest = serde_json::from_value(serde_json::json!({
            "schema_version": 2,
            "catalogue": 1,
            "clock": {"ticks_per_day": 600, "start_minute": 420},
            "city": {"id": "city:i", "name": "I", "entrances": [{"x": 0, "z": 100}], "districts": [
                {"id": "district:i", "name": "I", "facilities": [
                    {"id": "facility:ground", "name": "Ground", "rooms": [
                        {"id": "room:north", "name": "North", "capacity": 50, "template": "ground",
                         "outdoor": true, "rect": {"x": 0, "z": 0, "w": 6000, "d": 200}},
                        {"id": "room:road-n", "name": "Road north", "capacity": 50, "template": "ground",
                         "outdoor": true, "rect": {"x": 0, "z": 200, "w": 6000, "d": 120}},
                        {"id": "room:island", "name": "Island", "capacity": 50, "template": "ground",
                         "outdoor": true, "rect": {"x": 0, "z": 320, "w": 6000, "d": 160}},
                        {"id": "room:road-s", "name": "Road south", "capacity": 50, "template": "ground",
                         "outdoor": true, "rect": {"x": 0, "z": 480, "w": 6000, "d": 320}}
                    ]}
                ]}
            ]},
            "lines": [{
                "id": "line:boulevard", "name": "Boulevard tram", "mode": "tram",
                "points": [{"x": 0, "z": 400}, {"x": 6000, "z": 400}],
                "tracks": [-215, 215],
                "stops": [
                    {"id": "stop:m", "name": "M", "at": 3000, "platforms": ["room:island", "room:island"]},
                    {"id": "stop:e", "name": "E", "at": 5000, "platforms": ["room:island", "room:island"]}
                ],
                "timetable": {"headway": 30, "offset": [0, 15], "speed": 28, "dwell": 12},
                "vehicle": {"capacity": 40, "length": 1200, "doors": [200, 600, 1000]}
            }]
        }))
        .unwrap();
        World::new(m, feed(), 1).expect("the island is valid")
    }

    #[test]
    fn board_prefers_a_direction_with_a_stop_ahead() {
        let mut w = island();
        // Nearer the eastbound track at E, where nothing lies ahead east.
        plant(&mut w, "person:e", public(), "room:island", at(5000, 340));
        // Nearer the eastbound track at M, with E ahead.
        plant(&mut w, "person:m", public(), "room:island", at(3000, 340));
        run_to(&mut w, 1);
        board(&mut w, "person:e");
        board(&mut w, "person:m");
        let events = step(&mut w);
        assert!(rejected(&events).is_empty(), "{:?}", rejected(&events));
        assert_eq!(location(&w, "person:e"), waiting("stop:e", Direction::West));
        assert_eq!(location(&w, "person:m"), waiting("stop:m", Direction::East));
    }

    #[test]
    fn a_departure_whose_platform_cell_is_taken_finds_another() {
        let mut w = by_tram();
        plant(&mut w, "person:d", public(), "room:north-c", at(5000, 100));
        run_to(&mut w, 1);
        depart(&mut w, "person:d");
        run_to(&mut w, 2);
        let goal = *w.snapshot().occupants[&CityId::from("person:d")]
            .walk
            .as_ref()
            .expect("walking to a platform")
            .path
            .last()
            .unwrap();
        // Someone else takes the cell it was walking to, at the platform's
        // edge.
        plant(
            &mut w,
            "sim:x",
            OccupantKind::SimCitizen,
            "room:south",
            goal,
        );
        run_to(&mut w, 14);
        assert_eq!(location(&w, "person:d"), waiting("stop:c", Direction::West));
    }

    fn vehicle_state<'a>(w: &'a World, id: &str) -> &'a VehicleState {
        w.snapshot()
            .vehicles
            .iter()
            .find(|v| v.id.as_str() == id)
            .expect("on the line")
    }

    #[test]
    fn board_waits_for_the_next_tram_or_boards_one_standing_there() {
        let mut w = three_stops();
        plant(&mut w, "person:p0", public(), "room:north-a", at(900, 100));
        plant(&mut w, "person:p1", public(), "room:north-a", at(1100, 100));
        run_to(&mut w, 1);
        board(&mut w, "person:p0");
        let events = run_to(&mut w, 34);
        assert_eq!(boarded(&events), vec![row(33, "person:p0", EAST_1)]);
        assert_eq!(location(&w, "person:p1"), in_room("room:north-a"));
        // East:1 stands at A with its doors open until 45: Board takes p1
        // aboard on the tick it is given.
        board(&mut w, "person:p1");
        let events = step(&mut w);
        assert_eq!(boarded(&events), vec![row(35, "person:p1", EAST_1)]);
        // Players sit mid-car: p0 took the seat nearest the middle (16),
        // p1 the one across the aisle from it.
        assert_eq!(location(&w, "person:p1"), aboard(EAST_1, 17));
        assert!(rejected(&events).is_empty());
    }

    #[test]
    fn board_is_refused_off_a_platform_and_with_no_stop_ahead_and_waits_for_a_full_tram() {
        let mut m = crate::index::fixtures::tram_three_stops();
        m.lines[0].vehicle.capacity = 1;
        let mut w = World::new(m, feed(), 1).unwrap();
        // The street is all track: s stands where no tram comes by 35.
        plant(&mut w, "person:s", public(), "room:street", at(5900, 250));
        plant(&mut w, "person:f", public(), "room:north-a", at(900, 100));
        plant(&mut w, "person:q", public(), "room:north-a", at(1100, 100));
        plant(&mut w, "person:c", public(), "room:north-c", at(5000, 100));
        run_to(&mut w, 1);
        for id in ["person:s", "person:f", "person:c"] {
            board(&mut w, id);
        }
        let events = step(&mut w);
        assert_eq!(
            rejected(&events),
            vec![
                (
                    "person:s".to_string(),
                    CommandType::Board,
                    RejectReason::NotOnPlatform
                ),
                // C is the last stop east: no stop lies ahead of it.
                (
                    "person:c".to_string(),
                    CommandType::Board,
                    RejectReason::NotYourDirection
                ),
            ]
        );
        assert_eq!(location(&w, "person:f"), waiting("stop:a", Direction::East));
        run_to(&mut w, 34);
        assert_eq!(location(&w, "person:f"), aboard(EAST_1, 0));
        // East:1 stands at A full: Board waits for the next tram, as the
        // notice says, and the full one leaves q behind as its doors close.
        board(&mut w, "person:q");
        board(&mut w, "person:f");
        let events = step(&mut w);
        assert_eq!(
            rejected(&events),
            vec![(
                "person:f".to_string(),
                CommandType::Board,
                RejectReason::NotOnPlatform
            ),]
        );
        assert_eq!(location(&w, "person:q"), waiting("stop:a", Direction::East));
        let events = run_to(&mut w, 70);
        let left: Vec<(Tick, String)> = events
            .iter()
            .filter_map(|e| match &e.kind {
                EventKind::LeftBehind { vehicle, .. } => Some((
                    e.tick,
                    format!("{} by {vehicle}", e.occupant.as_ref().unwrap()),
                )),
                _ => None,
            })
            .collect();
        assert_eq!(left, vec![(45, format!("person:q by {EAST_1}"))]);
        assert_eq!(boarded(&events), vec![row(63, "person:q", EAST_2)]);
    }

    #[test]
    fn alight_steps_off_at_a_stop_and_is_refused_otherwise() {
        let mut w = three_stops();
        plant(&mut w, "person:p", public(), "room:north-a", at(900, 100));
        run_to(&mut w, 1);
        alight_command(&mut w, "person:p");
        let events = step(&mut w);
        assert_eq!(
            rejected(&events),
            vec![(
                "person:p".to_string(),
                CommandType::Alight,
                RejectReason::NotAboard
            )]
        );
        // It rides in the front row, by the front door that B's tiny
        // platform lies beside (a player would sit mid-car).
        wait(
            &mut w,
            "person:p",
            "stop:a",
            Some(Direction::East),
            Destination::Stop("stop:c".into()),
        );
        run_to(&mut w, 45);
        assert_eq!(location(&w, "person:p"), aboard(EAST_1, 0));
        // East:1 closed its doors at 45 and runs on to B.
        alight_command(&mut w, "person:p");
        let events = step(&mut w);
        assert_eq!(
            rejected(&events),
            vec![(
                "person:p".to_string(),
                CommandType::Alight,
                RejectReason::NotStanding
            )]
        );
        run_to(&mut w, 47);
        alight_command(&mut w, "person:p");
        let events = step(&mut w);
        assert_eq!(alighted(&events), vec![row(48, "person:p", "stop:b")]);
        assert_eq!(location(&w, "person:p"), in_room("room:tiny"));
        assert_eq!(destination(&w, "person:p"), None);
    }

    #[test]
    fn alight_onto_a_packed_platform_is_refused_and_the_rider_rides_on() {
        let mut w = three_stops();
        let tiny: Vec<Point> = {
            let nav = w.nav().unwrap();
            nav.cells_in(&"room:tiny".into())
                .into_iter()
                .map(|c| nav.centre(c))
                .collect()
        };
        for (k, p) in tiny.into_iter().enumerate() {
            plant(
                &mut w,
                &format!("sim:{k:02}"),
                OccupantKind::SimCitizen,
                "room:tiny",
                p,
            );
        }
        plant(&mut w, "person:p", public(), "room:north-a", at(900, 100));
        run_to(&mut w, 1);
        // In the front row, by the door the tiny platform lies beside.
        wait(
            &mut w,
            "person:p",
            "stop:a",
            Some(Direction::East),
            Destination::Stop("stop:c".into()),
        );
        run_to(&mut w, 47);
        alight_command(&mut w, "person:p");
        let events = step(&mut w);
        assert_eq!(
            rejected(&events),
            vec![(
                "person:p".to_string(),
                CommandType::Alight,
                RejectReason::NotStanding
            )]
        );
        assert_eq!(location(&w, "person:p"), aboard(EAST_1, 0));
        let events = run_to(&mut w, 62);
        assert_eq!(alighted(&events), vec![row(61, "person:p", "stop:c")]);
    }

    #[test]
    fn stepping_or_going_off_the_platform_stops_waiting() {
        let mut w = three_stops();
        plant(&mut w, "person:s", public(), "room:north-a", at(900, 100));
        plant(&mut w, "person:g", public(), "room:north-a", at(1500, 100));
        run_to(&mut w, 1);
        board(&mut w, "person:s");
        board(&mut w, "person:g");
        run_to(&mut w, 2);
        // A step along the platform keeps the place in line.
        let aside = steps_south(&w, "person:s", 1);
        w.submit(Command::Steer {
            occupant: "person:s".into(),
            cells: aside,
        });
        run_to(&mut w, 3);
        assert_eq!(location(&w, "person:s"), waiting("stop:a", Direction::East));
        assert_eq!(w.riders.waiting_since[&CityId::from("person:s")], 2);
        // Stepping off onto the street is no longer waiting.
        let off = steps_south(&w, "person:s", 4);
        w.submit(Command::Steer {
            occupant: "person:s".into(),
            cells: off,
        });
        // Going anywhere is not waiting either.
        w.submit(Command::Go {
            occupant: "person:g".into(),
            to: Target::Point { pos: at(2000, 100) },
        });
        run_to(&mut w, 4);
        let nav = w.nav().unwrap();
        assert_eq!(
            nav.room_at(nav.cell_of(pos_of(&w, "person:s")))
                .map(|r| r.as_str()),
            Some("room:street")
        );
        for id in ["person:s", "person:g"] {
            assert!(
                !matches!(location(&w, id), Location::WaitingFor { .. }),
                "{id}"
            );
            assert!(!w.riders.waiting_since.contains_key(&CityId::from(id)));
            assert_eq!(destination(&w, id), None);
        }
        assert_eq!(location(&w, "person:g"), in_room("room:north-a"));
        let events = run_to(&mut w, 40);
        assert!(boarded(&events).is_empty());
    }

    #[test]
    fn departing_while_waiting_or_aboard_rides_out() {
        let mut w = three_stops();
        plant(&mut w, "person:a", public(), "room:north-a", at(900, 100));
        plant(&mut w, "person:b", public(), "room:north-a", at(1100, 100));
        run_to(&mut w, 1);
        board(&mut w, "person:a");
        board(&mut w, "person:b");
        run_to(&mut w, 2);
        depart(&mut w, "person:a");
        run_to(&mut w, 3);
        assert_eq!(location(&w, "person:a"), waiting("stop:a", Direction::East));
        assert_eq!(destination(&w, "person:a"), Some(Destination::RideOut));
        run_to(&mut w, 34);
        depart(&mut w, "person:b");
        run_to(&mut w, 35);
        assert_eq!(location(&w, "person:b"), aboard(EAST_1, 17));
        assert_eq!(destination(&w, "person:b"), Some(Destination::RideOut));
        let events = run_to(&mut w, 120);
        assert!(alighted(&events).is_empty());
        let gone = departed(&events);
        assert_eq!(gone.len(), 2);
        assert!(gone.iter().all(|d| d.2 == EAST_1 && d.0 == gone[0].0));
    }

    #[test]
    fn hidden_occupants_depart_at_once_even_when_waiting_or_aboard() {
        let mut w = three_stops();
        plant(
            &mut w,
            "person:obs",
            observer(),
            "room:north-a",
            at(900, 100),
        );
        plant(
            &mut w,
            "pa:mine",
            personal_agent(),
            "room:north-a",
            at(1100, 100),
        );
        run_to(&mut w, 1);
        board(&mut w, "person:obs");
        run_to(&mut w, 46);
        assert_eq!(location(&w, "person:obs"), aboard(EAST_1, u32::MAX));
        board(&mut w, "pa:mine");
        run_to(&mut w, 47);
        assert_eq!(location(&w, "pa:mine"), waiting("stop:a", Direction::East));
        depart(&mut w, "person:obs");
        depart(&mut w, "pa:mine");
        let events = step(&mut w);
        assert_eq!(
            departed(&events),
            vec![row(48, "person:obs", "-"), row(48, "pa:mine", "-")]
        );
        for id in ["person:obs", "pa:mine"] {
            assert_eq!(location(&w, id), Location::Away);
            assert_eq!(destination(&w, id), None);
            assert!(!w.riders.waiting_since.contains_key(&CityId::from(id)));
        }
        assert!(vehicle_state(&w, EAST_1).riders.is_empty());
    }

    #[test]
    fn waiters_count_toward_their_platforms_capacity() {
        let mut w = three_stops_with("room:north-a", 2);
        plant(&mut w, "person:w0", public(), "room:north-a", at(900, 100));
        plant(&mut w, "person:w1", public(), "room:north-a", at(1100, 100));
        plant(&mut w, "person:x", public(), "room:street", at(2000, 250));
        run_to(&mut w, 1);
        board(&mut w, "person:w0");
        board(&mut w, "person:w1");
        run_to(&mut w, 2);
        w.submit(Command::Go {
            occupant: "person:x".into(),
            to: Target::Room {
                room: "room:north-a".into(),
            },
        });
        run_to(&mut w, 20);
        assert_eq!(
            location(&w, "person:x"),
            Location::Waitlisted {
                room: "room:north-a".into()
            }
        );
        assert!(!w.may_enter(&"room:north-a".into(), &"person:x".into()));
        // Once one steps off the platform, there is room.
        let off = steps_south(&w, "person:w0", 4);
        w.submit(Command::Steer {
            occupant: "person:w0".into(),
            cells: off,
        });
        run_to(&mut w, 25);
        assert_eq!(location(&w, "person:x"), in_room("room:north-a"));
    }

    #[test]
    fn the_waiter_invariant_catches_a_waiter_out_of_place() {
        use crate::invariants::check_waiters;
        let mut w = three_stops();
        plant(&mut w, "person:p", public(), "room:north-a", at(900, 100));
        run_to(&mut w, 1);
        wait(
            &mut w,
            "person:p",
            "stop:a",
            Some(Direction::East),
            Destination::Stop("stop:c".into()),
        );
        let check = |s: &Snapshot, r: &Riders| check_waiters(s, r, w.nav());
        assert_eq!(check(w.snapshot(), &w.riders), vec![]);
        let p = CityId::from("person:p");
        // A waiter with no direction.
        let mut s = w.snapshot().clone();
        s.occupants.get_mut(&p).unwrap().location = Location::WaitingFor {
            stop: "stop:a".into(),
            direction: None,
        };
        assert!(check(&s, &w.riders).iter().any(|v| v.invariant == 23));
        // A waiter with no start.
        let mut r = w.riders.clone();
        r.waiting_since.clear();
        assert!(check(w.snapshot(), &r).iter().any(|v| v.invariant == 23));
        // A start for someone not waiting.
        let mut r = w.riders.clone();
        r.waiting_since.insert("person:ghost".into(), 1);
        assert!(check(w.snapshot(), &r).iter().any(|v| v.invariant == 23));
        // A waiter off its platform.
        let mut s = w.snapshot().clone();
        s.occupants.get_mut(&p).unwrap().pos = Some(at(1012, 262));
        assert!(check(&s, &w.riders).iter().any(|v| v.invariant == 23));
        // A destination behind the stop.
        let mut r = w.riders.clone();
        r.destinations
            .insert(p.clone(), Destination::Stop("stop:a".into()));
        assert!(check(w.snapshot(), &r).iter().any(|v| v.invariant == 23));
    }

    /// The converse of the portal-queue check: in tram mode an arrival off
    /// the ground, walking nowhere and queued at no door is queued at a
    /// portal. The projection hides exactly these as riding in, so one
    /// dropped from its queue would vanish for good.
    #[test]
    fn an_arrival_queued_nowhere_breaks_the_waiter_invariant() {
        use crate::invariants::check_waiters;
        let mut w = by_tram();
        arrive(&mut w, "person:e", OccupantKind::GuildAgent, "room:shop");
        run_to(&mut w, 1);
        assert!(matches!(
            location(&w, "person:e"),
            Location::Arriving { .. }
        ));
        let check = |r: &Riders| check_waiters(w.snapshot(), r, w.nav());
        assert_eq!(check(&w.riders), vec![]);
        // Dropped from its portal's queue, and so from the arrivals by
        // tram too: no other check sees it, as nothing refers to it.
        let e = CityId::from("person:e");
        let mut r = w.riders.clone();
        for queue in r.arrival_queues.values_mut() {
            queue.retain(|id| id != &e);
        }
        r.arrivals.remove(&e);
        let found = check(&r);
        assert!(
            found
                .iter()
                .any(|v| v.invariant == 23 && v.detail.contains("person:e")),
            "{found:?}"
        );
    }

    #[test]
    fn a_destination_behind_the_stop_is_refused() {
        let mut w = three_stops();
        plant(&mut w, "person:c", public(), "room:north-c", at(5000, 100));
        plant(&mut w, "person:a", public(), "room:north-a", at(900, 100));
        let try_wait = |w: &mut World, id: &str, stop: &str, to: &str| {
            wait_for(
                w,
                &CityId::from(id),
                &PlaceId::from(stop),
                Some(Direction::East),
                Destination::Stop(to.into()),
            )
        };
        assert_eq!(
            try_wait(&mut w, "person:c", "stop:c", "stop:a"),
            Err(RejectReason::NotYourDirection)
        );
        assert_eq!(
            try_wait(&mut w, "person:c", "stop:c", "stop:c"),
            Err(RejectReason::NotYourDirection)
        );
        assert_eq!(location(&w, "person:c"), in_room("room:north-c"));
        assert_eq!(try_wait(&mut w, "person:a", "stop:a", "stop:b"), Ok(()));
        // A waiter given no direction takes its platform's.
        plant(&mut w, "person:s", public(), "room:south", at(1000, 800));
        wait_for(
            &mut w,
            &CityId::from("person:s"),
            &PlaceId::from("stop:a"),
            None,
            Destination::RideOut,
        )
        .expect("on A's west platform");
        assert_eq!(location(&w, "person:s"), waiting("stop:a", Direction::West));
        run_to(&mut w, 2);
    }

    /// One generated waiter: (tick it starts waiting, stop index, direction
    /// (0 east, 1 west, 2 either), destination (a stop index, or 3 to ride
    /// out), hidden).
    type RawWaiter = (u64, u8, u8, u8, bool);

    /// A generated run of the three-stop street: its timetable and
    /// capacity, the waiters, and how many cells of the B platform are
    /// filled. Returns the run's event log as JSON lines.
    fn generated_run(
        timetable: (u32, u32, u32, u32, u32),
        capacity: u32,
        waiters: &[RawWaiter],
        blockers: usize,
    ) -> Vec<String> {
        let (headway, east, west, speed, dwell) = timetable;
        let mut m = crate::index::fixtures::tram_three_stops();
        m.lines[0].timetable = city_contracts::Timetable {
            headway,
            offset: [east % headway, west % headway],
            speed,
            dwell: 1 + dwell % ((headway - 1) / 2),
        };
        m.lines[0].vehicle.capacity = capacity;
        let mut w = World::new(m, feed(), 1).expect("valid");
        let stops = ["stop:a", "stop:b", "stop:c"];
        let east_platforms = ["room:north-a", "room:tiny", "room:north-c"];
        let mut used: BTreeSet<Cell> = BTreeSet::new();
        let mut free_cell = |w: &World, room: &str| -> Option<Point> {
            let nav = w.nav().unwrap();
            let c = nav
                .cells_in(&room.into())
                .into_iter()
                .find(|c| !used.contains(c))?;
            used.insert(c);
            Some(nav.centre(c))
        };
        for k in 0..blockers {
            let p = free_cell(&w, "room:tiny").expect("16 cells");
            plant(
                &mut w,
                &format!("sim:{k:02}"),
                OccupantKind::SimCitizen,
                "room:tiny",
                p,
            );
        }
        let mut plan = Vec::new();
        for (k, &(start, stop, direction, to, hidden)) in waiters.iter().enumerate() {
            let stop = stop as usize % 3;
            let direction = match direction % 3 {
                0 => Some(Direction::East),
                1 => Some(Direction::West),
                _ => None,
            };
            let room = match direction {
                Some(Direction::West) => "room:south",
                _ => east_platforms[stop],
            };
            let Some(p) = free_cell(&w, room) else {
                continue;
            };
            let id = format!("person:{k:02}");
            let kind = if hidden { personal_agent() } else { public() };
            plant(&mut w, &id, kind, room, p);
            let to = match to % 4 {
                3 => Destination::RideOut,
                s => Destination::Stop(stops[s as usize].into()),
            };
            plan.push((start, id, stops[stop], direction, to));
        }
        let mut log = Vec::new();
        for t in 0..200u64 {
            for (_, id, stop, direction, to) in plan.iter().filter(|p| p.0 == t) {
                let result = wait_for(
                    &mut w,
                    &CityId::from(id.as_str()),
                    &PlaceId::from(*stop),
                    *direction,
                    to.clone(),
                );
                // A destination that is not ahead of the stop is refused.
                assert!(
                    matches!(result, Ok(()) | Err(RejectReason::NotYourDirection)),
                    "{id}: {result:?}"
                );
            }
            log.extend(step(&mut w));
        }
        log.iter()
            .map(|e| serde_json::to_string(e).unwrap())
            .collect()
    }

    /// One generated visitor in tram mode: (tick it arrives, target room
    /// index, hidden, ticks it stays before departing, 0 to stay).
    type RawVisitor = (u64, u8, bool, u64);

    /// A generated run of the three-stop street in tram mode: visitors
    /// arrive by tram for a room and later depart by tram. Every tick is
    /// checked, and no public occupant appears on the ground but by
    /// stepping off a tram, or leaves it but by boarding one. Returns the
    /// run's events.
    fn tram_run(capacity: u32, visitors: &[RawVisitor]) -> Vec<Event> {
        let mut m = crate::index::fixtures::tram_arrivals();
        m.lines[0].vehicle.capacity = capacity;
        let mut w = World::new(m, feed(), 1).expect("valid");
        let rooms = [
            "room:north-a",
            "room:north-c",
            "room:shop",
            "room:street",
            "room:south",
        ];
        let mut log = Vec::new();
        for t in 0..260u64 {
            for (k, &(at, room, hidden, stay)) in visitors.iter().enumerate() {
                let id = format!("person:{k:02}");
                if at == t {
                    let kind = match (hidden, k % 2) {
                        (true, _) => observer(),
                        (false, 0) => OccupantKind::GuildAgent,
                        (false, _) => public(),
                    };
                    arrive(&mut w, &id, kind, rooms[room as usize % rooms.len()]);
                }
                if stay > 0 && at + stay == t {
                    depart(&mut w, &id);
                }
            }
            let before = w.snapshot().clone();
            let events = step(&mut w);
            let did = |id: &CityId, what: fn(&EventKind) -> bool| {
                events
                    .iter()
                    .any(|e| e.occupant.as_ref() == Some(id) && what(&e.kind))
            };
            for (id, o) in &w.snapshot().occupants {
                if !shares_capacity(&o.profile.kind) {
                    continue;
                }
                let was = before.occupants.get(id).and_then(|b| b.pos).is_some();
                let is = o.pos.is_some();
                if is && !was {
                    assert!(
                        did(id, |k| matches!(k, EventKind::Alighted { .. })),
                        "{id} appeared on the ground at tick {t}"
                    );
                }
                if was && !is {
                    assert!(
                        did(id, |k| matches!(k, EventKind::Boarded { .. })),
                        "{id} vanished from the ground at tick {t}"
                    );
                }
            }
            log.extend(events);
        }
        log
    }

    fn lines(events: &[Event]) -> Vec<String> {
        events
            .iter()
            .map(|e| serde_json::to_string(e).unwrap())
            .collect()
    }

    #[test]
    fn in_tram_mode_everyone_public_arrives_and_departs_by_tram() {
        // (arrives, room, hidden, stays): the shop, A's platform, the south
        // platform and the shop again, one hidden; all but one leave.
        let visitors = [
            (0, 2, false, 110),
            (2, 0, false, 90),
            (4, 4, false, 70),
            (6, 2, true, 60),
            (8, 1, false, 0),
        ];
        let events = tram_run(2, &visitors);
        for (k, &(_, _, hidden, stay)) in visitors.iter().enumerate() {
            let id = format!("person:{k:02}");
            let mine = |what: fn(&EventKind) -> bool| {
                events
                    .iter()
                    .filter(|e| e.occupant.as_ref().is_some_and(|o| o.as_str() == id))
                    .filter(|e| what(&e.kind))
                    .count()
            };
            assert_eq!(mine(|k| matches!(k, EventKind::Alighted { .. })), 1, "{id}");
            let left = if hidden {
                |k: &EventKind| matches!(k, EventKind::Departed { via: None, .. })
            } else {
                |k: &EventKind| matches!(k, EventKind::Departed { via: Some(_), .. })
            };
            assert_eq!(mine(left), usize::from(stay > 0), "{id}");
        }
    }

    proptest! {
        #![proptest_config(ProptestConfig { cases: 24, .. ProptestConfig::default() })]

        #[test]
        fn tram_mode_keeps_every_invariant_and_replays(
            capacity in 1u32..=4,
            visitors in prop::collection::vec(
                (0u64..100, 0u8..5, prop::bool::weighted(0.2), prop_oneof![Just(0u64), 1u64..150]),
                0..14,
            ),
        ) {
            let log = lines(&tram_run(capacity, &visitors));
            prop_assert_eq!(&log, &lines(&tram_run(capacity, &visitors)));
        }
    }

    proptest! {
        #![proptest_config(ProptestConfig { cases: 48, .. ProptestConfig::default() })]

        #[test]
        fn riders_keep_every_invariant_on_generated_lines(
            timetable in (20u32..=40, 0u32..40, 0u32..40, 6u32..=28, any::<u32>()),
            capacity in 1u32..=4,
            waiters in prop::collection::vec(
                (0u64..80, 0u8..3, 0u8..3, 0u8..4, prop::bool::weighted(0.2)),
                0..12,
            ),
            blockers in 0usize..=16,
        ) {
            let log = generated_run(timetable, capacity, &waiters, blockers);
            prop_assert_eq!(&log, &generated_run(timetable, capacity, &waiters, blockers));
        }
    }
}
