//! Using things: the rules of the one `Use` command, for sitting, reading,
//! boarding and going in, and what ends a use.
//!
//! A use is recorded on the occupant (`OccupantState::using`) only when a
//! `Use` began it, so a world where no one sends `Use` (every agent) keeps
//! its snapshots and events. A seat taken any other way (by `Go` or the
//! seat policy) is shown as a use in projections, from the seat itself.

use crate::footprint;
use crate::nav::{Cell, NavGrid};
use crate::project::shares_capacity;
use crate::walk::facing_of;
use crate::world::World;
use city_contracts::{
    AnchorType, Catalogue, CityId, EventKind, Kind, Location, PlaceId, Point, RejectReason, Target,
    Using,
};

/// The capabilities whose use the core keeps. Everything else a kind offers
/// (`inspect` above all) changes nothing, so the client handles it alone.
const SIT: &str = "sit";
const READ: &str = "read";
const USE: &str = "use";
const BOARD: &str = "board";
const ENTER: &str = "enter";

/// What a `Use` names.
enum Found {
    /// A room seat: a seat is its furniture's own instance.
    Seat {
        room: PlaceId,
        seat: PlaceId,
        kind: Option<&'static Kind>,
        /// Which anchor of its kind the seat is (see [`seat_anchor`]).
        anchor: u32,
        reserved_for: Option<CityId>,
        pos: Option<Point>,
        facing: i32,
    },
    /// A placement, with its kind and where it stands.
    Placement {
        kind: &'static Kind,
        at: Point,
        facing: i32,
    },
    /// A line, or one of its vehicles: boarded at its kind's `enter` anchor.
    Line { kind: &'static Kind },
    /// A room, gone into through its door. Building kinds carry no `enter`
    /// anchors yet, and the room behind the door is what `Go` admits to, so
    /// a room offers `enter` at its door, anchor 0.
    Room { room: PlaceId },
}

/// Which anchor of its kind a room seat is: the one it names, else its
/// kind's first `sit` anchor, else 0 (a seat with no furniture).
pub fn seat_anchor(kind: Option<&str>, anchor: Option<u32>) -> u32 {
    anchor.unwrap_or_else(|| {
        kind.and_then(|k| Catalogue::builtin().kind(k))
            .and_then(|k| k.anchors.iter().position(|a| a.kind == AnchorType::Sit))
            .map_or(0, |k| k as u32)
    })
}

/// Whether anchor `anchor` of seat furniture `kind` is the room seat whose
/// own anchor is `own`: that anchor, or a `use` anchor at its very point (a
/// workstation's chair, where one sits and uses the computer). Sitting and
/// using there are one place, so whoever holds one holds both, under the
/// seat's rules.
fn is_seat_anchor(kind: &Kind, own: u32, anchor: u32) -> bool {
    if anchor == own {
        return true;
    }
    match (
        kind.anchors.get(anchor as usize),
        kind.anchors.get(own as usize),
    ) {
        (Some(a), Some(seat)) => a.kind == AnchorType::Use && a.at == seat.at,
        _ => false,
    }
}

/// Where a use happens: an anchor's type, cell and facing in the world,
/// and, for a display, the cells of its kind's stand anchors (where one
/// stands to read it).
pub struct Spot {
    pub kind: AnchorType,
    pub cell: Cell,
    /// Degrees clockwise from north. For `sit`, `use` and `stand` anchors,
    /// the user's own facing there; for a `display`, the surface's outward
    /// normal.
    pub facing: i32,
    pub stands: Vec<Cell>,
}

impl Spot {
    /// Anchor `anchor` of `kind`, placed at `at` turned to `facing`.
    fn of(nav: &NavGrid, kind: &Kind, at: Point, facing: i32, anchor: usize) -> Option<Spot> {
        let cell_of =
            |a: &city_contracts::Anchor| nav.cell_of(footprint::world_point(at, facing, a.at));
        let a = kind.anchors.get(anchor)?;
        Some(Spot {
            kind: a.kind,
            cell: cell_of(a),
            facing: (facing + a.facing).rem_euclid(360),
            stands: kind
                .anchors
                .iter()
                .filter(|s| s.kind == AnchorType::Stand)
                .map(cell_of)
                .collect(),
        })
    }

    /// The way a user of this anchor faces: its own facing, or, at a
    /// display, towards the surface (its normal reversed).
    fn user_facing(&self) -> i32 {
        match self.kind {
            AnchorType::Display => (self.facing + 180).rem_euclid(360),
            _ => self.facing,
        }
    }
}

/// Whether an occupant standing on `here` is where `spot` asks it to be to
/// use it. An anchor's facing is its user's own facing there, except a
/// display's, which is the surface's outward normal.
///
/// - `sit` and `use`: on the anchor's own cell;
/// - `display` (reading): on one of its kind's stand anchors, or on a
///   walkable one of the display anchor's eight neighbours lying within 45°
///   of its normal, that is, in front of the surface;
/// - `stand`: on the anchor's cell, or, with `overflow`, on a walkable
///   neighbour of it. A new use overflows only while someone else holds the
///   anchor's cell; a use already under way stays valid beside it;
/// - `enter`: nowhere in particular, since boarding waits on a platform and
///   going in walks to the door, each by its own rule.
pub fn at_anchor(nav: &NavGrid, spot: &Spot, here: Cell, overflow: bool) -> bool {
    let (di, dj) = (here.i - spot.cell.i, here.j - spot.cell.j);
    let beside = di.abs().max(dj.abs()) == 1 && nav.walkable(here);
    match spot.kind {
        AnchorType::Sit | AnchorType::Use => here == spot.cell,
        AnchorType::Display => {
            let off = (facing_of(di, dj) - spot.facing).rem_euclid(360);
            spot.stands.contains(&here) || (beside && off.min(360 - off) <= 45)
        }
        AnchorType::Stand => here == spot.cell || (overflow && beside),
        AnchorType::Enter => true,
    }
}

/// How many may use one anchor of this type at once. Sitting and using hold
/// one; a display is read by as many as stand round it, each on a cell of
/// their own; a stand anchor's own cell holds one, and its neighbours the
/// overflow.
fn capacity(kind: AnchorType) -> Option<usize> {
    match kind {
        AnchorType::Sit | AnchorType::Use | AnchorType::Stand => Some(1),
        AnchorType::Display | AnchorType::Enter => None,
    }
}

/// What `target` names: a room seat first (seat furniture shares its seat's
/// ID), then a placement, a line or vehicle, and a room.
fn find(world: &World, target: &PlaceId) -> Option<Found> {
    let catalogue = Catalogue::builtin();
    if let Some((room, s)) = world
        .index
        .rooms
        .values()
        .find_map(|r| r.seats.iter().find(|s| &s.id == target).map(|s| (r, s)))
    {
        return Some(Found::Seat {
            room: room.id.clone(),
            seat: s.id.clone(),
            kind: s.kind.as_deref().and_then(|k| catalogue.kind(k)),
            anchor: seat_anchor(s.kind.as_deref(), s.anchor),
            reserved_for: s.reserved_for.clone(),
            pos: s.pos,
            facing: s.facing,
        });
    }
    if let Some(p) = world.index.placed(target) {
        return Some(Found::Placement {
            kind: p.kind,
            at: p.placed.at,
            facing: p.placed.facing,
        });
    }
    let line = world.index.lines.get(target).or_else(|| {
        world
            .state
            .vehicles
            .iter()
            .find(|v| v.id.as_str() == target.as_str())
            .and_then(|v| world.index.lines.get(&v.line))
    });
    if let Some(line) = line {
        let kind = catalogue.kind(line.vehicle.kind.as_deref().unwrap_or("tram"))?;
        return Some(Found::Line { kind });
    }
    world.index.rooms.contains_key(target).then(|| Found::Room {
        room: target.clone(),
    })
}

/// The type of `anchor` in `kind`, when `kind` offers `capability` there.
fn offered(kind: &Kind, capability: &str, anchor: u32) -> Option<AnchorType> {
    let a = kind.anchors.get(anchor as usize)?;
    kind.capabilities
        .iter()
        .any(|c| c.name == capability && c.at == Some(a.kind))
        .then_some(a.kind)
}

/// The `Use` command: `occupant` uses `capability` at anchor `anchor` of
/// `target`. It is refused for an unknown occupant (`UnknownOccupant`) or
/// one not present (`NotPresent`), and otherwise checks, in order:
///
/// 1. the target resolves (`UnknownTarget`);
/// 2. its kind offers the capability at that anchor's type, and the
///    capability is one the core keeps (`NoSuchCapability`);
/// 3. the occupant, in a room, is where the anchor asks (see [`at_anchor`];
///    `NotInRoom`, `NotAtAnchor`);
/// 4. the anchor is free within its capacity (`AnchorTaken`); only public
///    occupants hold anchors, as only they hold seats and cells;
/// 5. the capability's own rule: `sit` on a room seat, or `use` at a
///    workstation seat's `use` anchor (the chair's own point), takes the
///    seat as the seat rules allow (`NotYourSeat` for another's
///    reservation, or for anyone hidden, who never takes a seat); `sit`
///    elsewhere (a perch), `read` and `use` begin the use; `board` is
///    `transit::board`; `enter` is `Go` to the room.
///
/// Sitting, reading and using record `using`, turn the occupant the way
/// the anchor's user faces (see [`Spot`]), and emit `Using`, after `Seated`
/// for a room seat. Any use already under way ends first, as a move would
/// end it: a seat elsewhere is got up from (`SeatReleased`), and a recorded
/// use stopped (`StoppedUsing`), so `using` always names one thing. The
/// seat one sits in is kept, so switching between sitting at a workstation
/// and using it is `StoppedUsing` then `Using`, with the seat held
/// throughout. Boarding and going in emit what `Board` and `Go` do, and
/// end any use as they do. Returns the events the command caused.
pub fn apply(
    world: &mut World,
    occupant: &CityId,
    target: &PlaceId,
    capability: &str,
    anchor: u32,
) -> Result<Vec<EventKind>, RejectReason> {
    let start = world.event_count();
    let o = world
        .state
        .occupants
        .get(occupant)
        .ok_or(RejectReason::UnknownOccupant)?;
    if matches!(o.location, Location::Away | Location::Leaving { .. }) {
        return Err(RejectReason::NotPresent);
    }
    let found = find(world, target).ok_or(RejectReason::UnknownTarget)?;
    match (capability, &found) {
        (BOARD, Found::Line { kind }) => {
            offered(kind, BOARD, anchor).ok_or(RejectReason::NoSuchCapability)?;
            crate::transit::board(world, occupant)?;
            release_on_move(world, occupant);
        }
        (ENTER, Found::Room { room }) => {
            if anchor != 0 {
                return Err(RejectReason::NoSuchCapability);
            }
            let tick = world.state.tick;
            world.go(occupant.clone(), Target::Room { room: room.clone() }, tick)?;
            release_on_move(world, occupant);
        }
        (SIT | READ | USE, Found::Seat { .. } | Found::Placement { .. }) => {
            hold(world, occupant, target, capability, anchor, found)?;
        }
        _ => return Err(RejectReason::NoSuchCapability),
    }
    Ok(world.events_since(start))
}

/// Steps 2 to 5 for sitting, reading and using.
fn hold(
    world: &mut World,
    occupant: &CityId,
    target: &PlaceId,
    capability: &str,
    anchor: u32,
    found: Found,
) -> Result<(), RejectReason> {
    // Step 2: the kind offers the capability at this anchor.
    match &found {
        Found::Seat {
            kind, anchor: own, ..
        } => {
            // A seat is one of its furniture's anchors: that one alone, and a
            // `use` anchor at its point (see [`is_seat_anchor`]).
            let offers = match kind {
                Some(kind) => {
                    matches!(
                        offered(kind, capability, anchor),
                        Some(AnchorType::Sit | AnchorType::Use)
                    ) && is_seat_anchor(kind, *own, anchor)
                }
                None => capability == SIT && anchor == *own,
            };
            if !offers {
                return Err(RejectReason::NoSuchCapability);
            }
        }
        Found::Placement { kind, .. } => {
            offered(kind, capability, anchor).ok_or(RejectReason::NoSuchCapability)?;
        }
        Found::Line { .. } | Found::Room { .. } => unreachable!("matched by the caller"),
    }
    let nav = world.nav.as_ref().ok_or(RejectReason::NotAtAnchor)?;
    // Where the anchor is, and what using it holds.
    let (spot, found) = match found {
        Found::Seat {
            room,
            seat,
            reserved_for,
            pos,
            facing,
            ..
        } => {
            let spot = Spot {
                kind: AnchorType::Sit,
                cell: nav.cell_of(pos.ok_or(RejectReason::NotAtAnchor)?),
                facing,
                stands: Vec::new(),
            };
            let held = Held::Seat {
                room,
                seat,
                reserved_for,
            };
            (spot, held)
        }
        Found::Placement { kind, at, facing } => {
            let spot = Spot::of(nav, kind, at, facing, anchor as usize).expect("offered above");
            // A seat furniture's sit or use anchor on a room seat's cell is
            // that seat, so the seat's rules apply however it is named;
            // named as another of the furniture's anchors, it is not where
            // one sits.
            let seat = (matches!(spot.kind, AnchorType::Sit | AnchorType::Use)
                && nav.is_seat_cell(spot.cell))
            .then(|| {
                world.index.rooms.values().find_map(|r| {
                    r.seats
                        .iter()
                        .find(|s| s.pos.is_some_and(|p| nav.cell_of(p) == spot.cell))
                        .map(|s| (r, s))
                })
            })
            .flatten();
            match seat {
                Some((_, s))
                    if !is_seat_anchor(kind, seat_anchor(s.kind.as_deref(), s.anchor), anchor) =>
                {
                    return Err(RejectReason::NotAtAnchor);
                }
                Some((r, s)) => {
                    let held = Held::Seat {
                        room: r.id.clone(),
                        seat: s.id.clone(),
                        reserved_for: s.reserved_for.clone(),
                    };
                    (spot, held)
                }
                None => (spot, Held::Anchor),
            }
        }
        Found::Line { .. } | Found::Room { .. } => unreachable!("matched by the caller"),
    };
    let using = Using {
        target: match &found {
            Held::Seat { seat, .. } => seat.clone(),
            Held::Anchor => target.clone(),
        },
        capability: capability.to_string(),
        anchor,
    };

    // Step 3.
    let o = &world.state.occupants[occupant];
    let Location::InRoom {
        room: in_room,
        seat,
    } = o.location.clone()
    else {
        return Err(RejectReason::NotInRoom);
    };
    let here = o
        .pos
        .map(|p| nav.cell_of(p))
        .ok_or(RejectReason::NotAtAnchor)?;
    let public = shares_capacity(&o.profile.kind);
    let others = holders(world, occupant, &using.target, anchor);
    // A new use overflows a stand anchor only while another holds its cell.
    if !at_anchor(nav, &spot, here, others.contains(&spot.cell)) {
        return Err(RejectReason::NotAtAnchor);
    }
    let centre = nav.centre(here);
    if o.using.as_ref() == Some(&using) {
        return Ok(());
    }

    // Steps 4 and 5.
    match &found {
        Held::Seat {
            room,
            seat: wanted,
            reserved_for,
        } => {
            let holder = world.state.rooms[room].seats[wanted].as_ref();
            if holder.is_some_and(|h| h != occupant) {
                return Err(RejectReason::AnchorTaken);
            }
            if !public || reserved_for.as_ref().is_some_and(|r| r != occupant) {
                return Err(RejectReason::NotYourSeat);
            }
            if in_room != *room {
                return Err(RejectReason::NotAtAnchor);
            }
            // Any new use first ends the one under way, a seat elsewhere
            // included, as a move would.
            let sits_here = seat.as_ref() == Some(wanted);
            if !sits_here {
                world.stand_up(occupant);
            }
            end_use(world, occupant);
            if !sits_here {
                world.take_seat(occupant, room, wanted.clone());
            }
            let o = world.state.occupants.get_mut(occupant).expect("present");
            o.facing = spot.facing;
            o.walk = None;
            o.goal = None;
        }
        Held::Anchor => {
            let over = capacity(spot.kind).is_some_and(|n| {
                let on_anchor = |c: &Cell| spot.kind != AnchorType::Stand || *c == spot.cell;
                others.iter().filter(|c| on_anchor(c)).count() >= n
            });
            // One overflowing a stand anchor holds its own cell, not the
            // anchor's.
            let overflow = spot.kind == AnchorType::Stand && here != spot.cell;
            if over && !overflow {
                return Err(RejectReason::AnchorTaken);
            }
            // Any new use first ends the one under way, a seat included
            // (`SeatReleased`, then `StoppedUsing` for one sat in by
            // `Use`), as a move would: `using` names one thing.
            world.stand_up(occupant);
            end_use(world, occupant);
            let o = world.state.occupants.get_mut(occupant).expect("present");
            o.facing = spot.user_facing();
            // It stays where it is: no walk goes on, and no policy spot
            // pulls it away.
            o.walk = None;
            o.goal = Some(Target::Point { pos: centre });
        }
    }
    world
        .state
        .occupants
        .get_mut(occupant)
        .expect("present")
        .using = Some(using.clone());
    world.push(
        Some(occupant),
        EventKind::Using {
            target: using.target,
            capability: using.capability,
            anchor: using.anchor,
        },
    );
    Ok(())
}

/// What a sitting, reading or using `Use` holds.
enum Held {
    /// A room seat, under the seat rules.
    Seat {
        room: PlaceId,
        seat: PlaceId,
        reserved_for: Option<CityId>,
    },
    /// A placement's anchor.
    Anchor,
}

/// The cells of the public occupants other than `occupant` using anchor
/// `anchor` of `target`.
fn holders(world: &World, occupant: &CityId, target: &PlaceId, anchor: u32) -> Vec<Cell> {
    let Some(nav) = world.nav.as_ref() else {
        return Vec::new();
    };
    world
        .state
        .occupants
        .iter()
        .filter(|(id, o)| *id != occupant && shares_capacity(&o.profile.kind))
        .filter(|(_, o)| {
            o.using
                .as_ref()
                .is_some_and(|u| &u.target == target && u.anchor == anchor)
        })
        .filter_map(|(_, o)| o.pos.map(|p| nav.cell_of(p)))
        .collect()
}

/// Ends `occupant`'s recorded use, if any: `StoppedUsing`. A seat it holds
/// stays held; the seat's own release ends a use of it (see
/// [`seat_released`]).
pub(crate) fn end_use(world: &mut World, occupant: &CityId) {
    let Some(o) = world.state.occupants.get_mut(occupant) else {
        return;
    };
    if let Some(using) = o.using.take() {
        world.push(
            Some(occupant),
            EventKind::StoppedUsing {
                target: using.target,
            },
        );
    }
}

/// Ends a use of `seat`, which `occupant` just got up from or left.
pub(crate) fn seat_released(world: &mut World, occupant: &CityId, seat: &PlaceId) {
    let uses_it = world.state.occupants[occupant]
        .using
        .as_ref()
        .is_some_and(|u| &u.target == seat);
    if uses_it {
        end_use(world, occupant);
    }
}

/// Ends `occupant`'s use as it moves off, leaves or boards: any use but of
/// a seat it still holds, whose release (as the move takes it out of the
/// seat) ends it instead, so a `Go` to the seat it sits in keeps it.
pub(crate) fn release_on_move(world: &mut World, occupant: &CityId) {
    let o = &world.state.occupants[occupant];
    let seated_in = match &o.location {
        Location::InRoom { seat, .. } => seat.as_ref(),
        _ => None,
    };
    let keeps = o
        .using
        .as_ref()
        .is_some_and(|u| Some(&u.target) == seated_in);
    if !keeps {
        end_use(world, occupant);
    }
}

/// Ends every use of `target`, which a placement command just moved or
/// removed, so no one uses an anchor that is no longer where they stand.
pub(crate) fn target_changed(world: &mut World, target: &PlaceId) {
    let users: Vec<CityId> = world
        .state
        .occupants
        .iter()
        .filter(|(_, o)| o.using.as_ref().is_some_and(|u| &u.target == target))
        .map(|(id, _)| id.clone())
        .collect();
    for occupant in users {
        end_use(world, &occupant);
    }
}

/// What `occupant` uses as everyone sees it: its recorded use, or else the
/// seat it sits in, once there (not while it walks to it).
pub fn shown_using(
    o: &city_contracts::OccupantState,
    seat_anchor_of: &dyn Fn(&PlaceId) -> u32,
) -> Option<Using> {
    if o.using.is_some() {
        return o.using.clone();
    }
    match &o.location {
        Location::InRoom {
            seat: Some(seat), ..
        } if o.walk.is_none() => Some(Using {
            target: seat.clone(),
            capability: SIT.to_string(),
            anchor: seat_anchor_of(seat),
        }),
        _ => None,
    }
}

/// Whether `occupant`'s recorded use is one it may be holding now: it is in
/// a room (so neither aboard nor waiting), the target and anchor still
/// resolve, and it stands where the anchor asks. For the invariants.
pub fn use_holds(world: &World, occupant: &CityId) -> Result<(), String> {
    let o = &world.state.occupants[occupant];
    let Some(using) = &o.using else {
        return Ok(());
    };
    let Location::InRoom { seat, .. } = &o.location else {
        return Err(format!("uses {} while not in a room", using.target));
    };
    let nav = world.nav.as_ref().ok_or("uses something with no layout")?;
    let here = o
        .pos
        .map(|p| nav.cell_of(p))
        .ok_or("uses with no position")?;
    let spot = match find(world, &using.target) {
        Some(Found::Seat { seat: id, pos, .. }) => {
            if seat.as_ref() != Some(&id) {
                return Err(format!("uses seat {id} without holding it"));
            }
            Spot {
                kind: AnchorType::Sit,
                cell: nav.cell_of(pos.ok_or("uses a seat with no position")?),
                facing: 0,
                stands: Vec::new(),
            }
        }
        Some(Found::Placement { kind, at, facing }) => {
            Spot::of(nav, kind, at, facing, using.anchor as usize)
                .ok_or_else(|| format!("uses {} at no such anchor", using.target))?
        }
        _ => return Err(format!("uses {}, which is gone", using.target)),
    };
    // A stand use under way stays valid beside the anchor, whoever holds
    // its cell now.
    if at_anchor(nav, &spot, here, true) {
        Ok(())
    } else {
        Err(format!("uses {} away from its anchor", using.target))
    }
}

/// Whether more public occupants use one anchor than it holds. Returns the
/// over-full anchors, as target and anchor index.
pub fn overfull_anchors(world: &World) -> Vec<(PlaceId, u32)> {
    let mut count: std::collections::BTreeMap<(PlaceId, u32), (usize, usize)> = Default::default();
    let Some(nav) = world.nav.as_ref() else {
        return Vec::new();
    };
    for o in world.state.occupants.values() {
        let Some(u) = &o.using else { continue };
        if !shares_capacity(&o.profile.kind) {
            continue;
        }
        let Some(Found::Placement { kind, at, facing }) = find(world, &u.target) else {
            continue;
        };
        let Some(spot) = Spot::of(nav, kind, at, facing, u.anchor as usize) else {
            continue;
        };
        // Overflow beside a stand anchor holds its own cell.
        if spot.kind == AnchorType::Stand && o.pos.map(|p| nav.cell_of(p)) != Some(spot.cell) {
            continue;
        }
        if let Some(holds) = capacity(spot.kind) {
            count
                .entry((u.target.clone(), u.anchor))
                .or_insert((0, holds))
                .0 += 1;
        }
    }
    count
        .into_iter()
        .filter(|(_, (users, holds))| users > holds)
        .map(|(k, _)| k)
        .collect()
}

#[cfg(test)]
mod tests {
    //! The rules, on test kinds injected beside the built-in catalogue.
    //! What releases a use, and how uses look in projections and replays,
    //! is tested through the public API in `tests/interact.rs`.

    use super::*;
    use crate::Feed;
    use crate::footprint::Placed;
    use crate::index::PlacedInfo;
    use crate::invariants::{check_using, check_world};
    use city_contracts::{
        Command, CommandType, Event, FeedHeader, HumanTier, OccupantKind, OccupantProfile,
        OccupantState, Placement, PresenceRecord, ShownPresence, Viewer,
    };
    use serde_json::json;

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

    fn public() -> OccupantKind {
        OccupantKind::Human {
            tier: HumanTier::Registered,
        }
    }

    /// An anonymous observer: hidden from the public, holding no cell.
    fn hidden() -> OccupantKind {
        OccupantKind::Human {
            tier: HumanTier::Observer,
        }
    }

    fn profile(id: &str, kind: OccupantKind) -> OccupantProfile {
        OccupantProfile {
            id: id.into(),
            kind,
            display_name: id.into(),
            role: String::new(),
            department: None,
            home: None,
            work: None,
            shared_with: Default::default(),
            appearance: Default::default(),
        }
    }

    fn at(x: i32, z: i32) -> Point {
        Point { x, z }
    }

    fn cell(w: &World, p: Point) -> Cell {
        w.nav().unwrap().cell_of(p)
    }

    /// The centre of the cell `di` east and `dj` south of the one holding
    /// `p`.
    fn beside(w: &World, p: Point, di: i32, dj: i32) -> Point {
        let c = cell(w, p);
        w.nav().unwrap().centre(Cell {
            i: c.i + di,
            j: c.j + dj,
        })
    }

    /// Puts `id` in `room`, standing still at `pos` (a cell's centre on a
    /// layout), as one admitted there that chose that spot.
    fn put_at(w: &mut World, id: &str, kind: OccupantKind, room: &str, pos: Option<Point>) {
        let (id, room) = (CityId::from(id), PlaceId::from(room));
        w.state
            .rooms
            .get_mut(&room)
            .expect("room exists")
            .occupants
            .push(id.clone());
        w.state.occupants.insert(
            id.clone(),
            OccupantState {
                profile: profile(id.as_str(), kind),
                location: Location::InRoom { room, seat: None },
                presence: PresenceRecord::default(),
                shown: ShownPresence::default(),
                pos,
                facing: 0,
                walk: None,
                trail: Vec::new(),
                goal: pos.map(|pos| Target::Point { pos }),
                using: None,
            },
        );
    }

    /// Puts `id` in `room` on the centre of the cell holding `p`.
    fn put(w: &mut World, id: &str, kind: OccupantKind, room: &str, p: Point) {
        let pos = beside(w, p, 0, 0);
        put_at(w, id, kind, room, Some(pos));
    }

    /// A kind the catalogue does not carry yet, for these tests alone.
    fn test_kind(kind: serde_json::Value) -> &'static Kind {
        Box::leak(Box::new(serde_json::from_value(kind).expect("a kind")))
    }

    /// A perch: two sit anchors a metre apart, sat on facing south.
    fn steps() -> &'static Kind {
        test_kind(json!({
            "id": "test-steps", "name": "Steps", "description": "Stone steps.",
            "class": "fixture", "snap": 25, "height": 40,
            "anchors": [{"type": "sit", "at": {"x": 0, "z": 0}, "facing": 180},
                        {"type": "sit", "at": {"x": 100, "z": 0}, "facing": 180}],
            "capabilities": [{"name": "sit", "at": "sit"}, {"name": "inspect", "at": "sit"}]
        }))
    }

    /// A noticeboard whose surface faces north (its display's normal), with
    /// a stand anchor three cells in front of it, where a reader faces
    /// south, towards the board.
    fn noticeboard() -> &'static Kind {
        test_kind(json!({
            "id": "test-noticeboard", "name": "Noticeboard", "description": "A board.",
            "class": "fixture", "snap": 25, "height": 180,
            "anchors": [{"type": "display", "at": {"x": 0, "z": 0}, "facing": 0},
                        {"type": "stand", "at": {"x": 0, "z": -75}, "facing": 180}],
            "capabilities": [{"name": "read", "at": "display"}, {"name": "inspect", "at": "display"}]
        }))
    }

    /// A workstation whose user faces east at it.
    fn workstation() -> &'static Kind {
        test_kind(json!({
            "id": "test-workstation", "name": "Workstation", "description": "A computer.",
            "class": "fixture", "snap": 25, "height": 75,
            "anchors": [{"type": "use", "at": {"x": 0, "z": 0}, "facing": 90}],
            "capabilities": [{"name": "use", "at": "use"}]
        }))
    }

    /// A plaque read from a stand anchor in front of it.
    fn plaque() -> &'static Kind {
        test_kind(json!({
            "id": "test-plaque", "name": "Plaque", "description": "A plaque.",
            "class": "fixture", "snap": 25, "height": 120,
            "anchors": [{"type": "stand", "at": {"x": 0, "z": 0}, "facing": 0}],
            "capabilities": [{"name": "read", "at": "stand"}]
        }))
    }

    /// Seat furniture with two sit anchors a metre apart.
    fn sofa() -> &'static Kind {
        test_kind(json!({
            "id": "test-sofa", "name": "Sofa", "description": "A sofa for two.",
            "class": "seat", "snap": 1, "height": 45,
            "anchors": [{"type": "sit", "at": {"x": 0, "z": 0}, "facing": 0},
                        {"type": "sit", "at": {"x": 100, "z": 0}, "facing": 0}],
            "capabilities": [{"name": "sit", "at": "sit"}]
        }))
    }

    /// Stands a placement of `kind` at `p`, with no footprint, as an
    /// accepted placement would be listed.
    fn place(w: &mut World, id: &str, kind: &'static Kind, p: Point, facing: i32) {
        let district = w.index.rooms.values().next().unwrap().district.clone();
        w.index.add_placement(PlacedInfo {
            id: id.into(),
            kind,
            placed: Placed {
                shapes: Vec::new(),
                at: p,
                facing,
            },
            level: 0,
            district,
            record: Placement {
                id: id.into(),
                kind: kind.id.clone(),
                at: p,
                facing,
                ..Default::default()
            },
        });
    }

    const STEPS: Point = Point { x: 600, z: 700 };
    const BOARD: Point = Point { x: 400, z: 700 };
    const DESK: Point = Point { x: 300, z: 600 };
    const PLAQUE: Point = Point { x: 500, z: 500 };
    const A1: Point = Point { x: 100, z: 100 };

    /// `layout_base`, with room `a` given a second desk, reserved for
    /// `person:owner`, and the plaza given steps, a noticeboard, a
    /// workstation and a plaque.
    fn plaza() -> World {
        let mut m = crate::index::fixtures::layout_base();
        m.city.districts[0].facilities[0].rooms[0].seats.push(
            serde_json::from_value(json!({"id": "seat:a2", "pos": {"x": 300, "z": 100},
                "facing": 0, "kind": "desk", "reserved_for": "person:owner"}))
            .unwrap(),
        );
        m.occupants.push(profile("person:owner", public()));
        let mut w = World::new(m, feed(), 1).expect("valid");
        place(&mut w, "placement:steps", steps(), STEPS, 0);
        place(&mut w, "placement:board", noticeboard(), BOARD, 0);
        place(&mut w, "placement:desk", workstation(), DESK, 0);
        place(&mut w, "placement:plaque", plaque(), PLAQUE, 0);
        w
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

    fn submit_use(w: &mut World, who: &str, target: &str, capability: &str, anchor: u32) {
        w.submit(Command::Use {
            occupant: who.into(),
            target: target.into(),
            capability: capability.into(),
            anchor,
        });
    }

    /// The kinds of `who`'s events.
    fn of(events: &[Event], who: &str) -> Vec<EventKind> {
        events
            .iter()
            .filter(|e| e.occupant.as_ref().is_some_and(|o| o.as_str() == who))
            .map(|e| e.kind.clone())
            .collect()
    }

    fn refused(command: CommandType, reason: RejectReason) -> Vec<EventKind> {
        vec![EventKind::Rejected { command, reason }]
    }

    fn use_refused(reason: RejectReason) -> Vec<EventKind> {
        refused(CommandType::Use, reason)
    }

    fn using(target: &str, capability: &str, anchor: u32) -> Using {
        Using {
            target: target.into(),
            capability: capability.into(),
            anchor,
        }
    }

    fn began(target: &str, capability: &str, anchor: u32) -> EventKind {
        EventKind::Using {
            target: target.into(),
            capability: capability.into(),
            anchor,
        }
    }

    fn stopped(target: &str) -> EventKind {
        EventKind::StoppedUsing {
            target: target.into(),
        }
    }

    fn seated(room: &str, seat: &str) -> EventKind {
        EventKind::Seated {
            room: room.into(),
            seat: seat.into(),
        }
    }

    fn released(room: &str, seat: &str) -> EventKind {
        EventKind::SeatReleased {
            room: room.into(),
            seat: seat.into(),
        }
    }

    fn occupant<'a>(w: &'a World, who: &str) -> &'a OccupantState {
        &w.snapshot().occupants[&CityId::from(who)]
    }

    fn uses(w: &World, who: &str) -> Option<Using> {
        occupant(w, who).using.clone()
    }

    fn holder(w: &World, room: &str, seat: &str) -> Option<CityId> {
        w.snapshot().rooms[&PlaceId::from(room)].seats[&PlaceId::from(seat)].clone()
    }

    fn shown(w: &World, who: &str) -> Option<Using> {
        let p = crate::project(w.snapshot(), &Viewer::Operator);
        p.rooms
            .iter()
            .flat_map(|r| &r.occupants)
            .find(|o| o.id.as_str() == who)
            .expect("shown")
            .using
            .clone()
    }

    #[test]
    fn sitting_on_a_perch_holds_its_anchor_against_a_second_sitter() {
        let mut w = plaza();
        let second = beside(&w, STEPS, 4, 0);
        let off = beside(&w, STEPS, 0, 2);
        put(&mut w, "person:a", public(), "room:p", STEPS);
        put(&mut w, "person:b", public(), "room:p", second);
        // Hidden occupants hold no cell, so one can stand on a's.
        put(&mut w, "person:h", hidden(), "room:p", STEPS);
        put(&mut w, "person:c", public(), "room:p", off);
        submit_use(&mut w, "person:a", "placement:steps", "sit", 0);
        submit_use(&mut w, "person:h", "placement:steps", "sit", 0);
        submit_use(&mut w, "person:b", "placement:steps", "sit", 1);
        submit_use(&mut w, "person:c", "placement:steps", "sit", 0);
        let events = step(&mut w);
        assert_eq!(
            of(&events, "person:a"),
            vec![began("placement:steps", "sit", 0)]
        );
        assert_eq!(
            of(&events, "person:h"),
            use_refused(RejectReason::AnchorTaken)
        );
        assert_eq!(
            of(&events, "person:b"),
            vec![began("placement:steps", "sit", 1)]
        );
        assert_eq!(
            of(&events, "person:c"),
            use_refused(RejectReason::NotAtAnchor)
        );
        assert_eq!(
            uses(&w, "person:a"),
            Some(using("placement:steps", "sit", 0))
        );
        // A perch turns its sitter the anchor's way, and takes nothing from
        // the room's capacity: no seat is held.
        let a = occupant(&w, "person:a");
        assert_eq!(a.facing, 180);
        assert_eq!(
            a.location,
            Location::InRoom {
                room: "room:p".into(),
                seat: None
            }
        );
        assert_eq!(
            shown(&w, "person:a"),
            Some(using("placement:steps", "sit", 0))
        );
        // Sitting lasts: the next ticks keep it where it sat.
        for _ in 0..5 {
            step(&mut w);
        }
        assert_eq!(
            uses(&w, "person:a"),
            Some(using("placement:steps", "sit", 0))
        );
    }

    #[test]
    fn a_use_the_core_does_not_keep_or_cannot_find_is_refused() {
        let mut w = plaza();
        put(&mut w, "person:a", public(), "room:p", STEPS);
        for (target, capability, anchor, reason) in [
            // The client inspects on its own; `inspect` never reaches the
            // core as a use.
            (
                "placement:steps",
                "inspect",
                0,
                RejectReason::NoSuchCapability,
            ),
            ("placement:steps", "read", 0, RejectReason::NoSuchCapability),
            ("placement:steps", "sit", 7, RejectReason::NoSuchCapability),
            ("placement:nowhere", "sit", 0, RejectReason::UnknownTarget),
            ("room:a", "sit", 0, RejectReason::NoSuchCapability),
            ("room:a", "enter", 1, RejectReason::NoSuchCapability),
            ("line:none", "board", 0, RejectReason::UnknownTarget),
        ] {
            submit_use(&mut w, "person:a", target, capability, anchor);
            let events = step(&mut w);
            assert_eq!(
                of(&events, "person:a"),
                use_refused(reason),
                "{target} {capability} {anchor}"
            );
        }
        assert_eq!(uses(&w, "person:a"), None);
    }

    #[test]
    fn without_a_layout_what_is_not_offered_is_still_no_such_capability() {
        // The two-room fixture has no layout, so no one has a place to
        // stand: a capability the seat does not offer is refused for that,
        // before anything asks where the occupant stands.
        let manifest: city_contracts::Manifest =
            serde_json::from_str(include_str!("../../../fixtures/two-room/manifest.json")).unwrap();
        let mut w = World::new(manifest, feed(), 1).expect("valid");
        assert!(w.nav().is_none());
        put_at(&mut w, "person:a", public(), "room:workshop", None);
        submit_use(&mut w, "person:a", "seat:w1", "read", 0);
        submit_use(&mut w, "person:a", "seat:w1", "sit", 0);
        let events = w.step();
        // (Allocate then seats it by the policy, as ever.)
        assert_eq!(
            of(&events, "person:a")[..2],
            [
                use_refused(RejectReason::NoSuchCapability),
                use_refused(RejectReason::NotAtAnchor)
            ]
            .concat()
        );
    }

    #[test]
    fn sitting_in_a_room_seat_through_use_keeps_the_seat_rules() {
        let mut w = plaza();
        let a2 = at(300, 100);
        put(&mut w, "person:a", public(), "room:a", A1);
        put(&mut w, "person:b", public(), "room:a", a2);
        put(&mut w, "person:h", hidden(), "room:a", A1);
        submit_use(&mut w, "person:a", "seat:a1", "sit", 0);
        // a2 is reserved for someone else: refused as `Go` refuses it.
        submit_use(&mut w, "person:b", "seat:a2", "sit", 0);
        submit_use(&mut w, "person:h", "seat:a1", "sit", 0);
        let events = step(&mut w);
        assert_eq!(
            of(&events, "person:a"),
            vec![seated("room:a", "seat:a1"), began("seat:a1", "sit", 0)]
        );
        assert_eq!(
            of(&events, "person:b"),
            use_refused(RejectReason::NotYourSeat)
        );
        assert_eq!(
            of(&events, "person:h"),
            use_refused(RejectReason::AnchorTaken)
        );
        assert_eq!(
            holder(&w, "room:a", "seat:a1"),
            Some(CityId::from("person:a"))
        );
        assert_eq!(shown(&w, "person:a"), Some(using("seat:a1", "sit", 0)));

        // Stopping stands it up and steps it off the seat, as a Steer with
        // no cells does, and frees the seat.
        w.submit(Command::StopUsing {
            occupant: "person:a".into(),
        });
        let events = step(&mut w);
        assert_eq!(
            of(&events, "person:a"),
            vec![released("room:a", "seat:a1"), stopped("seat:a1")]
        );
        assert_eq!(uses(&w, "person:a"), None);
        assert_ne!(
            cell(&w, occupant(&w, "person:a").pos.unwrap()),
            cell(&w, A1),
            "stepped off the seat"
        );
        assert_eq!(holder(&w, "room:a", "seat:a1"), None);
    }

    #[test]
    fn a_furniture_anchor_on_a_room_seat_is_that_seat_under_its_own_index() {
        // A sofa whose second sit anchor falls on seat a1's cell, and one
        // whose first does. The desk seat a1 is its furniture's anchor 0.
        let run = |at_sofa: Point, anchor: u32| {
            let mut w = plaza();
            place(&mut w, "placement:sofa", sofa(), at_sofa, 0);
            put(&mut w, "person:a", public(), "room:a", A1);
            submit_use(&mut w, "person:a", "placement:sofa", "sit", anchor);
            let events = step(&mut w);
            (of(&events, "person:a"), holder(&w, "room:a", "seat:a1"))
        };
        assert_eq!(
            run(at(0, 100), 1),
            (use_refused(RejectReason::NotAtAnchor), None),
            "the seat is anchor 0, not 1"
        );
        assert_eq!(
            run(A1, 0),
            (
                vec![seated("room:a", "seat:a1"), began("seat:a1", "sit", 0)],
                Some(CityId::from("person:a"))
            )
        );
    }

    #[test]
    fn a_noticeboard_is_read_in_front_of_its_surface_or_on_its_stand_anchor() {
        let mut w = plaza();
        let north = beside(&w, BOARD, 0, -1);
        let north_east = beside(&w, BOARD, 1, -1);
        let east = beside(&w, BOARD, 1, 0);
        let south = beside(&w, BOARD, 0, 1);
        let two_north = beside(&w, BOARD, 0, -2);
        let stand = beside(&w, BOARD, 0, -3);
        put(&mut w, "person:front", public(), "room:p", north);
        put(&mut w, "person:slant", public(), "room:p", north_east);
        put(&mut w, "person:stand", public(), "room:p", stand);
        put(&mut w, "person:side", public(), "room:p", east);
        put(&mut w, "person:behind", public(), "room:p", south);
        put(&mut w, "person:far", public(), "room:p", two_north);
        put(&mut w, "person:on", public(), "room:p", BOARD);
        let readers = ["person:front", "person:slant", "person:stand"];
        let refused = ["person:side", "person:behind", "person:far", "person:on"];
        for who in readers.iter().chain(&refused) {
            submit_use(&mut w, who, "placement:board", "read", 0);
        }
        let events = step(&mut w);
        for who in readers {
            assert_eq!(
                of(&events, who),
                vec![began("placement:board", "read", 0)],
                "{who}"
            );
            // Each turns to face the board: its normal (north) reversed.
            assert_eq!(occupant(&w, who).facing, 180, "{who}");
        }
        for who in refused {
            assert_eq!(
                of(&events, who),
                use_refused(RejectReason::NotAtAnchor),
                "{who}"
            );
        }
    }

    #[test]
    fn a_workstation_is_used_on_its_own_cell_facing_its_way() {
        let mut w = plaza();
        let north = beside(&w, DESK, 0, -1);
        put(&mut w, "person:front", public(), "room:p", north);
        put(&mut w, "person:on", public(), "room:p", DESK);
        submit_use(&mut w, "person:front", "placement:desk", "use", 0);
        submit_use(&mut w, "person:on", "placement:desk", "use", 0);
        let events = step(&mut w);
        assert_eq!(
            of(&events, "person:front"),
            use_refused(RejectReason::NotAtAnchor)
        );
        assert_eq!(
            of(&events, "person:on"),
            vec![began("placement:desk", "use", 0)]
        );
        assert_eq!(occupant(&w, "person:on").facing, 90);
    }

    #[test]
    fn a_stand_anchor_holds_one_and_its_neighbours_the_overflow() {
        let mut w = plaza();
        let north = beside(&w, PLAQUE, 0, -1);
        let away = beside(&w, PLAQUE, 0, 1);
        put(&mut w, "person:b", public(), "room:p", north);
        submit_use(&mut w, "person:b", "placement:plaque", "read", 0);
        let events = step(&mut w);
        assert_eq!(
            of(&events, "person:b"),
            use_refused(RejectReason::NotAtAnchor),
            "the anchor's own cell comes first"
        );
        put(&mut w, "person:a", public(), "room:p", PLAQUE);
        submit_use(&mut w, "person:a", "placement:plaque", "read", 0);
        submit_use(&mut w, "person:b", "placement:plaque", "read", 0);
        let events = step(&mut w);
        assert_eq!(
            of(&events, "person:a"),
            vec![began("placement:plaque", "read", 0)]
        );
        assert_eq!(
            of(&events, "person:b"),
            vec![began("placement:plaque", "read", 0)],
            "overflow beside a held stand anchor"
        );
        // The holder steps away: the overflow reader's use, under way, stays
        // valid beside the anchor (`step` checks every invariant).
        w.submit(Command::Steer {
            occupant: "person:a".into(),
            cells: vec![away],
        });
        let events = step(&mut w);
        assert_eq!(of(&events, "person:a"), vec![stopped("placement:plaque")]);
        for _ in 0..3 {
            step(&mut w);
        }
        assert_eq!(
            uses(&w, "person:b"),
            Some(using("placement:plaque", "read", 0))
        );
    }

    #[test]
    fn two_takers_of_one_anchor_in_a_tick_go_by_command_order() {
        // One on seat a1's cell asks to sit there with `Use` while another
        // asks for the seat with `Go`: the first command wins, and the other
        // is refused.
        let run = |use_first: bool| {
            let mut w = plaza();
            put(&mut w, "person:on", public(), "room:a", A1);
            put(&mut w, "person:go", public(), "room:a", at(300, 300));
            let go = Command::Go {
                occupant: "person:go".into(),
                to: Target::Seat {
                    seat: "seat:a1".into(),
                },
            };
            if !use_first {
                w.submit(go.clone());
            }
            submit_use(&mut w, "person:on", "seat:a1", "sit", 0);
            if use_first {
                w.submit(go);
            }
            let events = step(&mut w);
            (
                of(&events, "person:on"),
                of(&events, "person:go"),
                holder(&w, "room:a", "seat:a1"),
            )
        };
        assert_eq!(
            run(true),
            (
                vec![seated("room:a", "seat:a1"), began("seat:a1", "sit", 0)],
                refused(CommandType::Go, RejectReason::SeatTaken),
                Some(CityId::from("person:on"))
            )
        );
        let (on, go, held) = run(false);
        assert_eq!(on, use_refused(RejectReason::AnchorTaken));
        assert_eq!(go, vec![seated("room:a", "seat:a1")]);
        assert_eq!(held, Some(CityId::from("person:go")));
    }

    #[test]
    fn a_new_use_ends_the_one_under_way_a_seat_included() {
        // A noticeboard in room a, facing south onto seat a1, so one in the
        // seat can read it.
        let mut w = plaza();
        let over_a1 = beside(&w, A1, 0, -1);
        place(&mut w, "placement:notes", noticeboard(), over_a1, 180);
        put(&mut w, "person:a", public(), "room:a", A1);
        submit_use(&mut w, "person:a", "seat:a1", "sit", 0);
        step(&mut w);
        submit_use(&mut w, "person:a", "placement:notes", "read", 0);
        let events = step(&mut w);
        assert_eq!(
            of(&events, "person:a"),
            vec![
                released("room:a", "seat:a1"),
                stopped("seat:a1"),
                began("placement:notes", "read", 0),
            ]
        );
        assert_eq!(holder(&w, "room:a", "seat:a1"), None);
        assert_eq!(
            shown(&w, "person:a"),
            Some(using("placement:notes", "read", 0))
        );
        // StopUsing stops only what `using` names: the reading.
        w.submit(Command::StopUsing {
            occupant: "person:a".into(),
        });
        let events = step(&mut w);
        assert_eq!(of(&events, "person:a"), vec![stopped("placement:notes")]);

        // Seated by `Go`, nothing is recorded, so only the seat is released.
        let mut w = plaza();
        let over_a1 = beside(&w, A1, 0, -1);
        place(&mut w, "placement:notes", noticeboard(), over_a1, 180);
        put(&mut w, "person:a", public(), "room:a", A1);
        w.submit(Command::Go {
            occupant: "person:a".into(),
            to: Target::Seat {
                seat: "seat:a1".into(),
            },
        });
        step(&mut w);
        assert_eq!(shown(&w, "person:a"), Some(using("seat:a1", "sit", 0)));
        submit_use(&mut w, "person:a", "placement:notes", "read", 0);
        let events = step(&mut w);
        assert_eq!(
            of(&events, "person:a"),
            vec![
                released("room:a", "seat:a1"),
                began("placement:notes", "read", 0),
            ]
        );
    }

    #[test]
    fn one_pushed_off_the_track_by_a_tram_stops_using() {
        // A perch left on the eastbound track: a test kind with no
        // footprint, since no valid placement can stand on the rails, so
        // this stays a unit test. The tram, held by its sitter, steps it
        // aside.
        let mut w = World::new(crate::index::fixtures::tram_street(), feed(), 1)
            .expect("the tram street is valid");
        let on_track = at(2012, 187);
        place(&mut w, "placement:steps", steps(), on_track, 0);
        put(&mut w, "person:you", public(), "room:street", on_track);
        submit_use(&mut w, "person:you", "placement:steps", "sit", 0);
        let mut log = step(&mut w);
        assert_eq!(
            of(&log, "person:you"),
            vec![began("placement:steps", "sit", 0)]
        );
        while w.snapshot().tick < 60 && uses(&w, "person:you").is_some() {
            log.extend(step(&mut w));
        }
        let mine = of(&log, "person:you");
        let pushed = mine
            .iter()
            .position(|e| matches!(e, EventKind::SteppedAside { .. }))
            .expect("stepped aside");
        assert_eq!(mine[pushed - 1], stopped("placement:steps"));
        assert_eq!(uses(&w, "person:you"), None);
    }

    fn sat(w: &mut World) {
        put(w, "person:a", public(), "room:p", STEPS);
        submit_use(w, "person:a", "placement:steps", "sit", 0);
        let events = step(w);
        assert_eq!(
            of(&events, "person:a"),
            vec![began("placement:steps", "sit", 0)]
        );
    }

    #[test]
    fn the_invariant_catches_a_use_held_where_it_may_not_be() {
        let mut w = plaza();
        sat(&mut w);
        assert!(check_using(&w).is_empty());
        let a = CityId::from("person:a");
        // Away from its anchor.
        let away = beside(&w, STEPS, 0, 3);
        w.state.occupants.get_mut(&a).unwrap().pos = Some(away);
        assert!(check_using(&w).iter().any(|v| v.invariant == 25));
        // Aboard, or anywhere but a room.
        let back = beside(&w, STEPS, 0, 0);
        w.state.occupants.get_mut(&a).unwrap().pos = Some(back);
        w.state.occupants.get_mut(&a).unwrap().location = Location::WaitingFor {
            stop: "stop:x".into(),
            direction: None,
        };
        assert!(check_using(&w).iter().any(|v| v.invariant == 25));
        // Two public users of an anchor that holds one.
        let mut w = plaza();
        sat(&mut w);
        put(&mut w, "person:b", public(), "room:p", STEPS);
        w.state
            .occupants
            .get_mut(&CityId::from("person:b"))
            .unwrap()
            .using = Some(using("placement:steps", "sit", 0));
        assert!(
            check_using(&w)
                .iter()
                .any(|v| v.invariant == 25 && v.detail.contains("more users"))
        );
    }

    // ---- Workstations: the catalogue's own kind, a room seat ----

    /// `layout_base` with seat a1 a workstation, and a second, a2, reserved
    /// for `person:owner`. A workstation's anchors: 0 sit, 1 use (the same
    /// point), 2 display, 3 stand.
    fn workstations() -> World {
        let mut m = crate::index::fixtures::layout_base();
        let seats = &mut m.city.districts[0].facilities[0].rooms[0].seats;
        seats[0].kind = Some("workstation".into());
        seats.push(
            serde_json::from_value(json!({"id": "seat:a2", "pos": {"x": 300, "z": 100},
                "facing": 0, "kind": "workstation", "reserved_for": "person:owner"}))
            .unwrap(),
        );
        m.occupants.push(profile("person:owner", public()));
        World::new(m, feed(), 1).expect("valid")
    }

    const A2: Point = Point { x: 300, z: 100 };

    #[test]
    fn using_a_workstation_takes_its_seat_under_the_seat_rules() {
        let mut w = workstations();
        put(&mut w, "person:a", public(), "room:a", A1);
        put(&mut w, "person:b", public(), "room:a", A2);
        put(&mut w, "person:h", hidden(), "room:a", A1);
        submit_use(&mut w, "person:a", "seat:a1", "use", 1);
        // a2 is reserved for someone else: refused as `Go` refuses it.
        submit_use(&mut w, "person:b", "seat:a2", "use", 1);
        submit_use(&mut w, "person:h", "seat:a1", "use", 1);
        let events = step(&mut w);
        assert_eq!(
            of(&events, "person:a"),
            vec![seated("room:a", "seat:a1"), began("seat:a1", "use", 1)]
        );
        assert_eq!(
            of(&events, "person:b"),
            use_refused(RejectReason::NotYourSeat)
        );
        assert_eq!(
            of(&events, "person:h"),
            use_refused(RejectReason::AnchorTaken)
        );
        assert_eq!(
            holder(&w, "room:a", "seat:a1"),
            Some(CityId::from("person:a"))
        );
        assert_eq!(uses(&w, "person:a"), Some(using("seat:a1", "use", 1)));
        assert_eq!(shown(&w, "person:a"), Some(using("seat:a1", "use", 1)));
        assert_eq!(occupant(&w, "person:a").facing, 0, "facing the monitor");
        // Using lasts, as sitting does.
        for _ in 0..5 {
            step(&mut w);
        }
        assert_eq!(uses(&w, "person:a"), Some(using("seat:a1", "use", 1)));

        // Its owner uses a2; one hidden never takes a free seat.
        let mut w = workstations();
        put(&mut w, "person:owner", public(), "room:a", A2);
        put(&mut w, "person:h", hidden(), "room:a", A1);
        submit_use(&mut w, "person:owner", "seat:a2", "use", 1);
        submit_use(&mut w, "person:h", "seat:a1", "use", 1);
        let events = step(&mut w);
        assert_eq!(
            of(&events, "person:owner"),
            vec![seated("room:a", "seat:a2"), began("seat:a2", "use", 1)]
        );
        assert_eq!(
            of(&events, "person:h"),
            use_refused(RejectReason::NotYourSeat)
        );
    }

    #[test]
    fn a_workstation_offers_each_capability_at_its_own_anchor_and_never_watch() {
        let mut w = workstations();
        put(&mut w, "person:a", public(), "room:a", A1);
        for (capability, anchor) in [
            ("use", 0),
            ("sit", 1),
            ("use", 2),
            ("use", 3),
            ("read", 2),
            // Looking over a shoulder is the client's alone, as inspecting
            // is: the core keeps nothing of it.
            ("watch", 3),
            ("watch", 1),
            ("inspect", 3),
        ] {
            submit_use(&mut w, "person:a", "seat:a1", capability, anchor);
            let events = step(&mut w);
            assert_eq!(
                of(&events, "person:a"),
                use_refused(RejectReason::NoSuchCapability),
                "{capability} {anchor}"
            );
        }
        assert_eq!(uses(&w, "person:a"), None);
        assert_eq!(holder(&w, "room:a", "seat:a1"), None);
    }

    #[test]
    fn switching_between_sitting_and_using_a_workstation_keeps_the_seat() {
        let mut w = workstations();
        put(&mut w, "person:a", public(), "room:a", A1);
        submit_use(&mut w, "person:a", "seat:a1", "sit", 0);
        let events = step(&mut w);
        assert_eq!(
            of(&events, "person:a"),
            vec![seated("room:a", "seat:a1"), began("seat:a1", "sit", 0)]
        );
        // Sitting to using, and back: no seat released or taken again.
        for (capability, anchor) in [("use", 1), ("sit", 0), ("use", 1)] {
            let was = uses(&w, "person:a").unwrap();
            submit_use(&mut w, "person:a", "seat:a1", capability, anchor);
            let events = step(&mut w);
            assert_eq!(
                of(&events, "person:a"),
                vec![stopped("seat:a1"), began("seat:a1", capability, anchor)],
                "{} to {capability}",
                was.capability
            );
            assert_eq!(
                holder(&w, "room:a", "seat:a1"),
                Some(CityId::from("person:a"))
            );
            assert_eq!(
                uses(&w, "person:a"),
                Some(using("seat:a1", capability, anchor))
            );
        }
        // Using what it uses already changes nothing.
        submit_use(&mut w, "person:a", "seat:a1", "use", 1);
        assert!(of(&step(&mut w), "person:a").is_empty());

        // Seated by `Go`, nothing is recorded: using only begins.
        let mut w = workstations();
        put(&mut w, "person:a", public(), "room:a", A1);
        w.submit(Command::Go {
            occupant: "person:a".into(),
            to: Target::Seat {
                seat: "seat:a1".into(),
            },
        });
        step(&mut w);
        assert_eq!(shown(&w, "person:a"), Some(using("seat:a1", "sit", 0)));
        submit_use(&mut w, "person:a", "seat:a1", "use", 1);
        let events = step(&mut w);
        assert_eq!(of(&events, "person:a"), vec![began("seat:a1", "use", 1)]);
    }

    #[test]
    fn a_held_workstation_is_refused_at_either_anchor() {
        // One walking to the seat by `Go` holds it already: another on its
        // cell asks for it by `Use`, and the hidden one too, at either
        // anchor.
        let mut w = workstations();
        put(&mut w, "person:go", public(), "room:a", at(300, 300));
        put(&mut w, "person:on", public(), "room:a", A1);
        put(&mut w, "person:h", hidden(), "room:a", A1);
        w.submit(Command::Go {
            occupant: "person:go".into(),
            to: Target::Seat {
                seat: "seat:a1".into(),
            },
        });
        submit_use(&mut w, "person:on", "seat:a1", "use", 1);
        submit_use(&mut w, "person:h", "seat:a1", "sit", 0);
        let events = step(&mut w);
        assert_eq!(of(&events, "person:go"), vec![seated("room:a", "seat:a1")]);
        assert_eq!(
            of(&events, "person:on"),
            use_refused(RejectReason::AnchorTaken)
        );
        assert_eq!(
            of(&events, "person:h"),
            use_refused(RejectReason::AnchorTaken)
        );
        submit_use(&mut w, "person:on", "seat:a1", "sit", 0);
        submit_use(&mut w, "person:h", "seat:a1", "use", 1);
        let events = step(&mut w);
        assert_eq!(
            of(&events, "person:on"),
            use_refused(RejectReason::AnchorTaken)
        );
        assert_eq!(
            of(&events, "person:h"),
            use_refused(RejectReason::AnchorTaken)
        );
        assert_eq!(
            holder(&w, "room:a", "seat:a1"),
            Some(CityId::from("person:go"))
        );
    }

    #[test]
    fn a_workstation_placement_on_a_room_seat_is_that_seat_at_either_anchor() {
        let run = |capability: &str, anchor: u32| {
            let mut w = workstations();
            place(
                &mut w,
                "placement:station",
                Catalogue::builtin().kind("workstation").unwrap(),
                A1,
                0,
            );
            put(&mut w, "person:a", public(), "room:a", A1);
            submit_use(&mut w, "person:a", "placement:station", capability, anchor);
            let events = step(&mut w);
            (of(&events, "person:a"), holder(&w, "room:a", "seat:a1"))
        };
        assert_eq!(
            run("use", 1),
            (
                vec![seated("room:a", "seat:a1"), began("seat:a1", "use", 1)],
                Some(CityId::from("person:a"))
            )
        );
        assert_eq!(
            run("sit", 0),
            (
                vec![seated("room:a", "seat:a1"), began("seat:a1", "sit", 0)],
                Some(CityId::from("person:a"))
            )
        );
    }
}
