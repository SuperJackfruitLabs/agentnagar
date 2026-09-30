//! The world: fixed ticks over ordered state.

use crate::feed::Feed;
use crate::index::PlaceIndex;
use crate::nav::{Cell, NavGrid};
use crate::placement::{self, Change, Layout, Reach};
use crate::policy::choose_seat;
use crate::presence::{apply_observation, derive_shown, is_expired};
use crate::project::shares_capacity;
use crate::walk::{facing_of, spot_hash};
use city_contracts::{
    Catalogue, CityId, Command, CommandType, Dimension, Event, EventKind, FeedEntry, FeedHeader,
    GridChange, Location, Manifest, OccupantKind, OccupantProfile, OccupantState, PlaceId,
    PlacementChange, Point, PresenceRecord, RejectReason, RoomState, SCHEMA_VERSION,
    ShownConnection, ShownPresence, ShownProcess, ShownTask, Snapshot, Target, Tick,
    ValidationIssue, Walk, WalkPurpose,
};
use std::collections::{BTreeMap, BTreeSet};

/// The most grid cells a walker crosses in one tick.
pub const STEPS_PER_TICK: usize = 5;
/// Blocked ticks before a walker plans a way around.
pub const REPLAN_AFTER: u32 = 3;
/// Queue places kept clear of people standing about.
const QUEUE_KEEP_CLEAR: usize = 8;
/// How far, in cells, a queued occupant may step from its queue place and
/// still keep it: a tap aside keeps the place, walking off leaves it.
const QUEUE_LEASH: i32 = 8;
/// How close to its door, in cells, a held-up walker counts as arrived.
const DOOR_REACH: usize = 3;
/// How close to an entrance, in cells, a leaver has left the city.
const EXIT_RADIUS: i32 = 4;
/// How many cells a re-plan around a crowd may search before waiting again.
const REPLAN_BUDGET: usize = 4_000;
use rand_chacha::ChaCha8Rng;
use rand_core::{Rng, SeedableRng};

/// A deterministic simulation of who is where in the city.
///
/// Each tick applies, in order: Ingest, Expire, Admit, Allocate, Transition,
/// Vehicles, Depart, Emit. The same manifest, feed and seed always give the
/// same log.
pub struct World {
    pub(crate) index: PlaceIndex,
    pub(crate) state: Snapshot,
    rng: ChaCha8Rng,
    entries: Vec<FeedEntry>,
    cursor: usize,
    events: Vec<Event>,
    /// Steers accepted at Ingest, carried out at Transition in order.
    steers: Vec<PendingSteer>,
    /// Live commands submitted for the next tick, in order.
    live: Vec<Command>,
    /// Every live command, as the feed entry that would replay it.
    input_log: Vec<FeedEntry>,
    /// Present when the manifest has a layout; occupants then walk.
    pub(crate) nav: Option<NavGrid>,
    /// Queue places outside every room, kept clear of people standing about.
    queue_cells: BTreeSet<Cell>,
    /// Every cell a vehicle can cover, kept clear of people standing about
    /// so no one settles on the rails.
    pub(crate) track_cells: BTreeSet<Cell>,
    /// Vehicles due on the timetable that wait for their portal to clear.
    pub(crate) waiting_entries: crate::transit::WaitingEntries,
    /// Riders' destinations and when each platform waiter began waiting.
    pub(crate) riders: crate::transit::Riders,
    /// Walking cost from every cell to each room's threshold. A
    /// platform's field is the walking distance to it that tram departures
    /// are planned by.
    room_fields: BTreeMap<PlaceId, Vec<u32>>,
    /// Each room's thresholds: the sources its field was made from, kept so
    /// a placement change mends the field rather than remaking it.
    room_sources: BTreeMap<PlaceId, BTreeSet<Cell>>,
    /// The entrances' cells: the exit field's sources.
    exit_sources: BTreeSet<Cell>,
    /// Which cells the entrances reach, for placement changes.
    reach: Option<Reach>,
    /// For each cell a placement command changed this tick, by row then
    /// column, whether it was walkable when the tick began.
    grid_origins: BTreeMap<(i32, i32), bool>,
    /// Every line platform's walkable cells off the track, for measuring
    /// the walk from a platform to a room. None is empty: `new` refuses a
    /// platform with nowhere to stand.
    platform_cells: BTreeMap<PlaceId, Vec<Cell>>,
    /// Walking cost from every cell to the nearest entrance.
    exit_field: Vec<u32>,
}

/// What an occupant just placed in a room does about its own goal.
enum Choice {
    /// Stand at the point it chose.
    Stand,
    /// Sit in the seat it chose.
    Seat(PlaceId),
    /// Let the room's policy seat it or find it a spot.
    Policy,
}

/// A steer accepted at Ingest and carried out at Transition.
struct PendingSteer {
    occupant: CityId,
    cells: Vec<Point>,
}

/// A move queued at Ingest and carried out at Transition.
struct PendingMove {
    occupant: CityId,
    to: PlaceId,
}

impl World {
    pub fn new(manifest: Manifest, feed: Feed, seed: u64) -> Result<World, Vec<ValidationIssue>> {
        let index = PlaceIndex::build(&manifest)?;
        let occupants = index
            .occupants
            .values()
            .map(|p| (p.id.clone(), fresh(p.clone())))
            .collect();
        let rooms = index
            .rooms
            .values()
            .map(|r| {
                let seats = r.seats.iter().map(|s| (s.id.clone(), None)).collect();
                (
                    r.id.clone(),
                    RoomState {
                        occupants: Vec::new(),
                        seats,
                        waitlist: Vec::new(),
                    },
                )
            })
            .collect();
        let state = Snapshot {
            schema_version: SCHEMA_VERSION,
            tick: 0,
            seed,
            fixture: feed.header.fixture,
            manifest,
            occupants,
            rooms,
            admission_queue: Vec::new(),
            next_seq: 0,
            vehicles: Vec::new(),
            grid_changes: Vec::new(),
        };
        let mut nav = index.layout.then(|| NavGrid::build(&index));
        let track_cells = nav
            .as_ref()
            .map(|n| crate::transit::track_cells(&index, n))
            .unwrap_or_default();
        // No one queues on the rails, where a tram would hold for them.
        if let Some(n) = nav.as_mut() {
            n.keep_queues_off(track_cells.clone());
        }
        let queue_cells = nav
            .as_ref()
            .map(|n| {
                index
                    .rooms
                    .keys()
                    .flat_map(|r| n.queue_slots(r, QUEUE_KEEP_CLEAR))
                    .collect()
            })
            .unwrap_or_default();
        let platform_cells: BTreeMap<PlaceId, Vec<Cell>> = nav
            .as_ref()
            .map(|n| {
                index
                    .lines
                    .values()
                    .flat_map(|line| &line.stops)
                    .flat_map(|stop| stop.platforms.iter())
                    .map(|p| {
                        let cells = n
                            .cells_in(p)
                            .into_iter()
                            .filter(|c| n.walkable(*c) && !track_cells.contains(c))
                            .collect();
                        (p.clone(), cells)
                    })
                    .collect()
            })
            .unwrap_or_default();
        // Riders step off onto a platform and waiters stand on it, so every
        // platform needs somewhere off the track to stand.
        let nowhere: Vec<ValidationIssue> = platform_cells
            .iter()
            .filter(|(_, cells)| cells.is_empty())
            .map(|(p, _)| ValidationIssue {
                code: "line-platform-no-standing".into(),
                place: Some(p.to_string()),
                message: format!("Platform {p} has no cell off the track to stand on."),
            })
            .collect();
        if !nowhere.is_empty() {
            return Err(nowhere);
        }
        let room_sources: BTreeMap<PlaceId, BTreeSet<Cell>> = match &nav {
            Some(n) => index
                .rooms
                .keys()
                .map(|r| (r.clone(), n.thresholds(r).into_iter().collect()))
                .collect(),
            None => BTreeMap::new(),
        };
        let exit_sources: BTreeSet<Cell> = match &nav {
            Some(n) => index.entrances.iter().filter_map(|e| n.snap(*e)).collect(),
            None => BTreeSet::new(),
        };
        let (room_fields, exit_field) = match &nav {
            Some(n) => (
                room_sources
                    .iter()
                    .map(|(r, sources)| {
                        (
                            r.clone(),
                            n.field_from(&sources.iter().copied().collect::<Vec<_>>()),
                        )
                    })
                    .collect(),
                n.field_from(&exit_sources.iter().copied().collect::<Vec<_>>()),
            ),
            None => (BTreeMap::new(), Vec::new()),
        };
        let reach = nav.as_ref().map(|n| Reach::of(&index, n));
        Ok(World {
            nav,
            queue_cells,
            track_cells,
            waiting_entries: Default::default(),
            riders: Default::default(),
            room_fields,
            room_sources,
            exit_sources,
            reach,
            grid_origins: BTreeMap::new(),
            platform_cells,
            exit_field,
            index,
            state,
            rng: ChaCha8Rng::seed_from_u64(seed),
            entries: feed.entries,
            cursor: 0,
            events: Vec::new(),
            steers: Vec::new(),
            live: Vec::new(),
            input_log: Vec::new(),
        })
    }

    pub fn snapshot(&self) -> &Snapshot {
        &self.state
    }

    pub fn index(&self) -> &PlaceIndex {
        &self.index
    }

    /// The navigation grid, when the manifest has a layout.
    pub fn nav(&self) -> Option<&NavGrid> {
        self.nav.as_ref()
    }

    /// The walking cost from every cell (by [`NavGrid::slot`]) to `room`'s
    /// threshold, when the manifest has a layout.
    pub fn room_field(&self, room: &PlaceId) -> Option<&[u32]> {
        self.room_fields.get(room).map(Vec::as_slice)
    }

    /// The walking cost from every cell (by [`NavGrid::slot`]) to the
    /// nearest entrance; empty without a layout.
    pub fn exit_field(&self) -> &[u32] {
        &self.exit_field
    }

    /// Riders' destinations, waiters' places in line and arrivals by tram:
    /// the transit state the snapshot does not carry.
    pub fn riders(&self) -> &crate::transit::Riders {
        &self.riders
    }

    /// The walking cost from `c` to `platform`: 0 on it, `u32::MAX` where
    /// no way leads there.
    pub(crate) fn walk_to_platform(&self, c: Cell, platform: &PlaceId) -> u32 {
        let nav = self.nav_ref();
        if nav.room_at(c) == Some(platform) {
            return 0;
        }
        nav.slot(c)
            .map_or(u32::MAX, |k| self.room_fields[platform][k])
    }

    /// The shortest walk from `platform` to `room`'s threshold, from any of
    /// its cells off the track: 0 when they are one room, `u32::MAX` where
    /// no way leads there.
    pub(crate) fn walk_from_platform(&self, platform: &PlaceId, room: &PlaceId) -> u32 {
        if platform == room {
            return 0;
        }
        let nav = self.nav_ref();
        let field = &self.room_fields[room];
        self.platform_cells
            .get(platform)
            .into_iter()
            .flatten()
            .filter_map(|c| nav.slot(*c).map(|k| field[k]))
            .min()
            .unwrap_or(u32::MAX)
    }

    /// Queues a live command for the next tick. At that tick's Ingest it
    /// runs after the feed's entries, in the order submitted. It is logged
    /// at once as the feed entry that would replay it.
    pub fn submit(&mut self, command: Command) {
        self.input_log.push(FeedEntry {
            at: self.state.tick + 1,
            fixture: self.state.fixture,
            command: command.clone(),
        });
        self.live.push(command);
    }

    /// Every live command so far, as feed entries.
    pub fn input_log(&self) -> &[FeedEntry] {
        &self.input_log
    }

    /// The input log as a feed, labelled like the world's own. Merged with
    /// the original feed (see [`crate::merge`]) it replays the session byte
    /// for byte.
    pub fn input_log_feed(&self) -> Feed {
        Feed {
            header: FeedHeader {
                schema_version: SCHEMA_VERSION,
                source: "input-log".into(),
                fixture: self.state.fixture,
                description: "Live commands recorded by the world.".into(),
            },
            entries: self.input_log.clone(),
        }
    }

    /// Runs `ticks` ticks and returns all their events.
    pub fn run(&mut self, ticks: Tick) -> Vec<Event> {
        (0..ticks).flat_map(|_| self.step()).collect()
    }

    /// Advances one tick and returns that tick's events in order.
    pub fn step(&mut self) -> Vec<Event> {
        self.state.tick += 1;
        let t = self.state.tick;
        self.state.grid_changes.clear();
        self.grid_origins.clear();
        let (moves, departures) = self.ingest(t);
        self.expire(t);
        self.admit(t);
        self.allocate(t);
        self.transition(t, moves);
        crate::transit::step_vehicles(self, t);
        self.depart(departures);
        self.emit_presence(t);
        std::mem::take(&mut self.events)
    }

    pub(crate) fn push(&mut self, occupant: Option<&CityId>, kind: EventKind) {
        let event = Event {
            tick: self.state.tick,
            seq: self.state.next_seq,
            fixture: self.state.fixture,
            occupant: occupant.cloned(),
            kind,
        };
        self.state.next_seq += 1;
        self.events.push(event);
    }

    fn reject(&mut self, occupant: &CityId, command: CommandType, reason: RejectReason) {
        self.push(Some(occupant), EventKind::Rejected { command, reason });
    }

    // ---- 1. Ingest ----

    fn ingest(&mut self, t: Tick) -> (Vec<PendingMove>, Vec<(CityId, bool)>) {
        let mut moves = Vec::new();
        let mut departures: Vec<(CityId, bool)> = Vec::new();
        while self.cursor < self.entries.len() && self.entries[self.cursor].at <= t {
            let command = self.entries[self.cursor].command.clone();
            self.cursor += 1;
            let kind = command.command_type();
            let who = command.occupant().cloned();
            if let Err(reason) = self.apply(command, t, &mut moves, &mut departures) {
                self.push(
                    who.as_ref(),
                    EventKind::Rejected {
                        command: kind,
                        reason,
                    },
                );
            }
        }
        for command in std::mem::take(&mut self.live) {
            let kind = command.command_type();
            let who = command.occupant().cloned();
            if let Err(reason) = self.apply(command, t, &mut moves, &mut departures) {
                self.push(
                    who.as_ref(),
                    EventKind::Rejected {
                        command: kind,
                        reason,
                    },
                );
            }
        }
        (moves, departures)
    }

    fn apply(
        &mut self,
        command: Command,
        t: Tick,
        moves: &mut Vec<PendingMove>,
        departures: &mut Vec<(CityId, bool)>,
    ) -> Result<(), RejectReason> {
        match command {
            Command::Arrive {
                occupant,
                profile,
                room,
                player,
            } => self.arrive(occupant, profile, room, player),
            Command::Depart { occupant, player } => {
                let o = self.occupant(&occupant)?;
                if matches!(o.location, Location::Away | Location::Leaving { .. }) {
                    return Err(RejectReason::NotPresent);
                }
                // Departing twice in a tick is once; a player's leaves at once.
                match departures.iter_mut().find(|(id, _)| *id == occupant) {
                    Some((_, at_once)) => *at_once |= player,
                    None => departures.push((occupant, player)),
                }
                Ok(())
            }
            Command::Move { occupant, to } => {
                let o = self.occupant(&occupant)?;
                let Location::InRoom { room, .. } = &o.location else {
                    return Err(RejectReason::NotInRoom);
                };
                if !self.index.rooms.contains_key(&to) {
                    return Err(RejectReason::UnknownRoom);
                }
                if let Some(nav) = &self.nav {
                    // With a layout, any room a path reaches will do.
                    if *room == to {
                        return Err(RejectReason::NoDoor);
                    }
                    let from = o
                        .pos
                        .map(|p| nav.cell_of(p))
                        .ok_or(RejectReason::NotInRoom)?;
                    let _ = nav;
                    if self.walk_into(from, &to).is_none() {
                        return Err(RejectReason::Unreachable);
                    }
                } else if !self.index.rooms[room].doors.contains_key(&to) {
                    return Err(RejectReason::NoDoor);
                }
                crate::interact::release_on_move(self, &occupant);
                moves.push(PendingMove { occupant, to });
                Ok(())
            }
            Command::Observe {
                occupant,
                observation,
            } => {
                let o = self.occupant_mut(&occupant)?;
                if matches!(o.location, Location::Away) {
                    return Err(RejectReason::NotPresent);
                }
                apply_observation(&mut o.presence, observation, t).map(|_| ())
            }
            Command::Share { occupant, grantee } => {
                let o = self.occupant_mut(&occupant)?;
                if !matches!(o.profile.kind, OccupantKind::PersonalAgent { .. }) {
                    return Err(RejectReason::NotPersonalAgent);
                }
                o.profile.shared_with.insert(grantee.clone());
                self.push(Some(&occupant), EventKind::Shared { grantee });
                Ok(())
            }
            Command::Unshare { occupant, grantee } => {
                let o = self.occupant_mut(&occupant)?;
                if !matches!(o.profile.kind, OccupantKind::PersonalAgent { .. }) {
                    return Err(RejectReason::NotPersonalAgent);
                }
                o.profile.shared_with.remove(&grantee);
                self.push(Some(&occupant), EventKind::Unshared { grantee });
                Ok(())
            }
            Command::Go { occupant, to } => {
                self.go(occupant.clone(), to, t)?;
                crate::interact::release_on_move(self, &occupant);
                Ok(())
            }
            Command::Steer { occupant, cells } => {
                let o = self.occupant(&occupant)?;
                if self.nav.is_none() {
                    return Err(RejectReason::Unreachable);
                }
                if matches!(o.location, Location::Away | Location::Leaving { .. })
                    || o.pos.is_none()
                {
                    return Err(RejectReason::NotPresent);
                }
                self.steers.push(PendingSteer { occupant, cells });
                Ok(())
            }
            Command::Board { occupant } => {
                crate::transit::board(self, &occupant)?;
                crate::interact::release_on_move(self, &occupant);
                Ok(())
            }
            Command::Alight { occupant } => crate::transit::alight_now(self, &occupant),
            Command::Use {
                occupant,
                target,
                capability,
                anchor,
            } => crate::interact::apply(self, &occupant, &target, &capability, anchor).map(|_| ()),
            Command::StopUsing { occupant } => self.stop_using(occupant),
            Command::Place { .. }
            | Command::MovePlacement { .. }
            | Command::RemovePlacement { .. } => {
                let (id, change) = match &command {
                    Command::Place { placement, .. } => {
                        (placement.id.clone(), PlacementChange::Placed)
                    }
                    Command::MovePlacement { id, .. } => (id.clone(), PlacementChange::Moved),
                    Command::RemovePlacement { id, .. } => (id.clone(), PlacementChange::Removed),
                    _ => unreachable!("matched above"),
                };
                self.apply_placement(&command)?;
                self.push(
                    None,
                    EventKind::PlacementChanged {
                        id: id.clone(),
                        change,
                    },
                );
                // An anchor moved or gone is no longer where its users
                // stand.
                if change != PlacementChange::Placed {
                    crate::interact::target_changed(self, &id);
                }
                Ok(())
            }
        }
    }

    /// The `StopUsing` command. One sitting in a seat stands up and steps
    /// off it at Transition, as a `Steer` with no cells does (at once
    /// without a layout, where there is nowhere to step); anything else it
    /// uses ends now. Nothing in use is no error.
    fn stop_using(&mut self, occupant: CityId) -> Result<(), RejectReason> {
        let o = self.occupant(&occupant)?;
        if matches!(o.location, Location::Away | Location::Leaving { .. }) {
            return Err(RejectReason::NotPresent);
        }
        if matches!(o.location, Location::InRoom { seat: Some(_), .. }) {
            if self.nav.is_some() {
                self.steers.push(PendingSteer {
                    occupant,
                    cells: Vec::new(),
                });
            } else {
                self.stand_up(&occupant);
            }
            return Ok(());
        }
        crate::interact::end_use(self, &occupant);
        Ok(())
    }

    /// How many events this tick has emitted so far.
    pub(crate) fn event_count(&self) -> usize {
        self.events.len()
    }

    /// The kinds of the events emitted this tick from the `start`th on.
    pub(crate) fn events_since(&self, start: usize) -> Vec<EventKind> {
        self.events[start..]
            .iter()
            .map(|e| e.kind.clone())
            .collect()
    }

    // ---- Placement commands ----

    /// Carries out a placement command now, between ticks: Ingest calls it
    /// for every one fed or submitted, in order, and records the event. It
    /// goes through [`placement::apply`], so it is refused for everything
    /// that refuses there, for a player (`NotOperator`), and when it would
    /// cover a cell someone stands on or a vehicle covers, or leave a
    /// platform with no cell off the track to stand on, or shut someone in,
    /// or off from where they walk to. Once made, the
    /// manifest in the snapshot carries it, the walking fields, queue
    /// places and platforms follow the grid, walkers whose way it blocked
    /// plan afresh, and the tick's `grid_changes` gain the cells it
    /// changed. Returns those cells. Only Ingest calls it, so every change
    /// is logged and replays.
    pub(crate) fn apply_placement(&mut self, command: &Command) -> Result<Vec<Cell>, RejectReason> {
        let (change, by) = match command {
            Command::Place { placement, by } => (Change::Place(placement.clone()), by),
            Command::MovePlacement { id, at, facing, by } => (
                Change::Move {
                    id: id.clone(),
                    at: *at,
                    facing: *facing,
                },
                by,
            ),
            Command::RemovePlacement { id, by } => (Change::Remove { id: id.clone() }, by),
            _ => unreachable!("Ingest passes placement commands only"),
        };
        if by.is_some() {
            return Err(RejectReason::NotOperator);
        }
        let (held, people) = self.held_cells();
        let (Some(nav), Some(reach)) = (self.nav.as_mut(), self.reach.as_mut()) else {
            let id = match &change {
                Change::Place(p) => p.id.clone(),
                Change::Move { id, .. } | Change::Remove { id } => id.clone(),
            };
            return Err(RejectReason::PlacementInvalid {
                code: "no-layout".into(),
                place: id,
            });
        };
        let (tracks, platforms) = (&self.track_cells, &self.platform_cells);
        let allow = |grid: &NavGrid, changed: &[Cell]| {
            if changed
                .iter()
                .any(|c| !grid.walkable(*c) && held.contains(c))
            {
                return Err(RejectReason::PlacementCoversOccupant);
            }
            let stands = |p: &PlaceId, c: &Cell| {
                grid.walkable(*c) && grid.room_at(*c) == Some(p) && !tracks.contains(c)
            };
            if let Some((p, _)) = platforms
                .iter()
                .find(|(p, cells)| !cells.iter().chain(changed).any(|c| stands(p, c)))
            {
                return Err(RejectReason::PlacementInvalid {
                    code: "line-platform-no-standing".into(),
                    place: p.clone(),
                });
            }
            Ok(())
        };
        let layout = Layout {
            index: &mut self.index,
            grid: nav,
            tracks,
            reach,
            people: &people,
        };
        let changed = placement::apply(layout, Catalogue::builtin(), &change, &allow)?;
        self.record_placement(&change);
        self.follow_grid(&changed);
        Ok(changed)
    }

    /// The cells a placement may not newly cover (where anyone present
    /// stands, and what the vehicles cover), and the cells it may not cut
    /// off from the entrances (where anyone present stands, and where each
    /// walker is going).
    fn held_cells(&self) -> (BTreeSet<Cell>, BTreeSet<Cell>) {
        let Some(nav) = &self.nav else {
            return Default::default();
        };
        let present = || {
            self.state
                .occupants
                .values()
                .filter(|o| !matches!(o.location, Location::Away))
        };
        let standing: BTreeSet<Cell> = present()
            .filter_map(|o| o.pos.map(|p| nav.cell_of(p)))
            .collect();
        let mut held = standing.clone();
        for vehicle in &self.state.vehicles {
            held.extend(crate::transit::footprint(&self.index, nav, vehicle));
        }
        let mut people = standing;
        people.extend(present().filter_map(|o| {
            o.walk
                .as_ref()
                .and_then(|w| w.path.last())
                .map(|p| nav.cell_of(*p))
        }));
        (held, people)
    }

    /// Writes a change made into the snapshot's manifest, so the snapshot
    /// carries the placements as they stand.
    fn record_placement(&mut self, change: &Change) {
        let district = self
            .index
            .rooms
            .values()
            .find(|r| r.rect.is_some())
            .map(|r| r.district.clone());
        let districts = &mut self.state.manifest.city.districts;
        match change {
            Change::Place(p) => {
                if let Some(d) = districts
                    .iter_mut()
                    .find(|d| Some(&d.id) == district.as_ref())
                {
                    d.placements.push(p.clone());
                }
            }
            Change::Move { id, at, facing } => {
                if let Some(p) = districts
                    .iter_mut()
                    .flat_map(|d| d.placements.iter_mut())
                    .find(|p| &p.id == id)
                {
                    p.at = *at;
                    p.facing = *facing;
                }
            }
            Change::Remove { id } => {
                for d in districts.iter_mut() {
                    d.placements.retain(|p| &p.id != id);
                }
            }
        }
    }

    /// Brings everything derived from the grid up to date after `changed`
    /// cells changed walkability: the tick's grid changes, each room's
    /// walking field and the exit field, the queue places kept clear, the
    /// platforms' standing cells, and every walk that now crosses a blocked
    /// cell or takes a step no longer allowed.
    fn follow_grid(&mut self, changed: &[Cell]) {
        if changed.is_empty() {
            return;
        }
        let nav = self.nav.as_ref().expect("placement changes need a layout");
        for c in changed {
            self.grid_origins
                .entry((c.j, c.i))
                .or_insert(!nav.walkable(*c));
        }
        self.state.grid_changes = self
            .grid_origins
            .iter()
            .filter(|((j, i), was)| nav.walkable(Cell { i: *i, j: *j }) != **was)
            .map(|((j, i), was)| GridChange {
                i: *i,
                j: *j,
                walkable: !was,
                room: nav.room_index(Cell { i: *i, j: *j }),
            })
            .collect();

        let near = nav.around(changed);
        for (room, sources) in &mut self.room_sources {
            let (mut removed, mut added) = (Vec::new(), Vec::new());
            for c in &near {
                match (sources.contains(c), nav.is_threshold(*c, room)) {
                    (true, false) => removed.push(*c),
                    (false, true) => added.push(*c),
                    _ => {}
                }
            }
            for c in &removed {
                sources.remove(c);
            }
            sources.extend(added.iter().copied());
            let field = self.room_fields.get_mut(room).expect("a field per room");
            nav.repair_field(field, sources, &removed, &added, changed);
        }
        let exits: BTreeSet<Cell> = self
            .index
            .entrances
            .iter()
            .filter_map(|e| nav.snap(*e))
            .collect();
        let removed: Vec<Cell> = self.exit_sources.difference(&exits).copied().collect();
        let added: Vec<Cell> = exits.difference(&self.exit_sources).copied().collect();
        nav.repair_field(&mut self.exit_field, &exits, &removed, &added, changed);
        self.exit_sources = exits;

        self.queue_cells = self
            .index
            .rooms
            .keys()
            .flat_map(|r| nav.queue_slots(r, QUEUE_KEEP_CLEAR))
            .collect();
        for (platform, cells) in &mut self.platform_cells {
            *cells = nav
                .cells_in(platform)
                .into_iter()
                .filter(|c| nav.walkable(*c) && !self.track_cells.contains(c))
                .collect();
        }
        self.replan_blocked_walks();
    }

    /// Plans afresh every walk whose way on crosses a cell that is no
    /// longer walkable, or takes a step no longer allowed: to the same
    /// goal where it can, else as its purpose asks.
    fn replan_blocked_walks(&mut self) {
        let walkers: Vec<CityId> = self
            .state
            .occupants
            .iter()
            .filter(|(_, o)| o.walk.is_some())
            .map(|(id, _)| id.clone())
            .collect();
        for occ in walkers {
            let nav = self.nav_ref();
            let o = &self.state.occupants[&occ];
            let (Some(walk), Some(from)) = (&o.walk, o.pos.map(|p| nav.cell_of(p))) else {
                continue;
            };
            let mut at = from;
            let open = walk.path.iter().all(|p| {
                let c = nav.cell_of(*p);
                let fine = nav.walkable(c) && (c == at || nav.can_step(at, c));
                at = c;
                fine
            });
            if open {
                continue;
            }
            let purpose = walk.purpose.clone();
            let goal = walk.path.last().map(|p| nav.cell_of(*p));
            let path = goal
                .filter(|g| nav.walkable(*g))
                .and_then(|g| nav.path_to(from, g, &|_| false))
                .or_else(|| match &purpose {
                    WalkPurpose::ToDoor { target } => self.walk_into(from, target),
                    WalkPurpose::ToExit => self.exit_path(from),
                    _ => None,
                });
            let points: Option<Vec<Point>> =
                path.map(|p| p.iter().map(|c| nav.centre(*c)).collect());
            let o = self.state.occupants.get_mut(&occ).expect("occupant exists");
            let walk = o.walk.as_mut().expect("a walker");
            walk.blocked = 0;
            match (points, purpose) {
                (Some(points), _) => walk.path = points,
                // Arrived at its door as near as it can get, or planned
                // afresh by the transit phase.
                (None, WalkPurpose::ToDoor { .. } | WalkPurpose::ToPlatform { .. }) => {
                    walk.path.clear()
                }
                // Stands where it is: Allocate and the queues give it
                // somewhere new, and a leaver departs from here.
                (None, _) => o.walk = None,
            }
        }
    }

    fn occupant(&self, id: &CityId) -> Result<&OccupantState, RejectReason> {
        self.state
            .occupants
            .get(id)
            .ok_or(RejectReason::UnknownOccupant)
    }

    fn occupant_mut(&mut self, id: &CityId) -> Result<&mut OccupantState, RejectReason> {
        self.state
            .occupants
            .get_mut(id)
            .ok_or(RejectReason::UnknownOccupant)
    }

    fn arrive(
        &mut self,
        id: CityId,
        profile: Option<OccupantProfile>,
        room: Option<PlaceId>,
        player: bool,
    ) -> Result<(), RejectReason> {
        if let Some(p) = &profile
            && p.id != id
        {
            return Err(RejectReason::ProfileMismatch);
        }
        let known = self.state.occupants.get(&id);
        if known.is_none() && profile.is_none() {
            return Err(RejectReason::UnknownOccupant);
        }
        if let Some(o) = known
            && !matches!(o.location, Location::Away)
        {
            return Err(RejectReason::AlreadyPresent);
        }
        let profile = profile.unwrap_or_else(|| known.expect("known").profile.clone());
        let target = room
            .or_else(|| profile.work.clone())
            .ok_or(RejectReason::NoTargetRoom)?;
        if !self.index.rooms.contains_key(&target) {
            return Err(RejectReason::UnknownRoom);
        }
        let hidden = !shares_capacity(&profile.kind);
        if crate::transit::by_tram(self) {
            // It rides in: queued at a portal, off the ground, until a
            // vehicle takes it aboard.
            let mut state = fresh(profile);
            state.location = Location::Arriving {
                room: target.clone(),
            };
            self.state.occupants.insert(id.clone(), state);
            crate::transit::queue_arrival(self, &id, &target, player);
            self.push(Some(&id), EventKind::Arrived { room: target });
            return Ok(());
        }
        let walk_in = match &self.nav {
            Some(_) => Some(
                self.entrance_for(&target)
                    .ok_or(RejectReason::Unreachable)?,
            ),
            None => None,
        };
        let mut state = fresh(profile);
        state.location = Location::Arriving {
            room: target.clone(),
        };
        self.state.occupants.insert(id.clone(), state);
        // Public arrivals start on the free cell nearest the entrance and plan
        // from there; hidden ones start on the entrance itself.
        let walk_in = match walk_in {
            Some((entrance, _)) if !hidden => {
                let taken = self.reserved_cells();
                let start = self
                    .nav_ref()
                    .nearest_free(entrance, &|c| taken.contains_key(&c))
                    .unwrap_or(entrance);
                let path = self.walk_into(start, &target).unwrap_or_default();
                Some((start, path))
            }
            other => other,
        };
        match walk_in {
            Some((start, path)) if !path.is_empty() => {
                self.set_pos(&id, start);
                self.set_walk(
                    &id,
                    path,
                    WalkPurpose::ToDoor {
                        target: target.clone(),
                    },
                );
            }
            Some((start, _)) => {
                self.set_pos(&id, start);
                self.state.admission_queue.push(id.clone());
            }
            None => self.state.admission_queue.push(id.clone()),
        }
        self.push(Some(&id), EventKind::Arrived { room: target });
        Ok(())
    }

    // ---- Players: Go ----

    /// Walks `occ` to a target. In its own room it stands up and heads
    /// there at once; a target in another room is admitted there first,
    /// through the room's threshold, and `goal` carries the rest. One
    /// waiting on a platform stops waiting and goes from the platform's
    /// room; one riding cannot walk (`NotInRoom`).
    pub(crate) fn go(&mut self, occ: CityId, to: Target, t: Tick) -> Result<(), RejectReason> {
        let o = self.occupant(&occ)?;
        if self.nav.is_none() {
            return Err(RejectReason::Unreachable);
        }
        let location = o.location.clone();
        match &location {
            Location::Away | Location::Leaving { .. } => return Err(RejectReason::NotPresent),
            Location::InTransit { .. } | Location::Aboard { .. } => {
                return Err(RejectReason::NotInRoom);
            }
            _ => {}
        }
        let cur = self.cell_of_occ(&occ).ok_or(RejectReason::NotPresent)?;
        let (room, cell, goal) = self.resolve_target(&occ, to)?;
        let reachable = match cell {
            Some(c) => self.nav_ref().path_to(cur, c, &|_| false).is_some(),
            None => self.walk_into(cur, &room).is_some(),
        };
        if !reachable {
            return Err(RejectReason::Unreachable);
        }
        let location = if let Location::WaitingFor { .. } = location {
            crate::transit::stop_waiting(self, &occ);
            self.state.occupants[&occ].location.clone()
        } else {
            location
        };
        match location {
            Location::InRoom { room: here, seat } if here == room => {
                let Some(goal) = goal else {
                    // Already in the room it asked for.
                    return Ok(());
                };
                if let Target::Seat { seat: wanted } = &goal
                    && seat.as_ref() == Some(wanted)
                {
                    self.occupant_mut(&occ)?.goal = None;
                    return Ok(());
                }
                self.stand_up(&occ);
                let o = self.occupant_mut(&occ)?;
                o.walk = None;
                o.goal = None;
                match goal {
                    Target::Seat { seat } => self.take_seat(&occ, &room, seat),
                    point => self.occupant_mut(&occ)?.goal = Some(point),
                }
            }
            Location::InRoom { room: from, .. } => {
                let path = self
                    .walk_into(cur, &room)
                    .ok_or(RejectReason::Unreachable)?;
                self.occupant_mut(&occ)?.walk = None;
                self.walk_to_room(&occ, from, room, path, t);
                self.occupant_mut(&occ)?.goal = goal;
            }
            Location::Arriving { room: target } | Location::Waitlisted { room: target }
                if target == room =>
            {
                // Already on its way in, or queued: keep the place.
                self.occupant_mut(&occ)?.goal = goal;
            }
            Location::Waitlisted { room: target } => {
                let path = self
                    .walk_into(cur, &room)
                    .ok_or(RejectReason::Unreachable)?;
                self.state
                    .rooms
                    .get_mut(&target)
                    .expect("room exists")
                    .waitlist
                    .retain(|o| o != &occ);
                self.head_in(&occ, room, path);
                self.occupant_mut(&occ)?.goal = goal;
            }
            Location::Arriving { .. } => {
                let path = self
                    .walk_into(cur, &room)
                    .ok_or(RejectReason::Unreachable)?;
                self.head_in(&occ, room, path);
                self.occupant_mut(&occ)?.goal = goal;
            }
            Location::Away
            | Location::Leaving { .. }
            | Location::InTransit { .. }
            | Location::WaitingFor { .. }
            | Location::Aboard { .. } => {
                unreachable!("refused above")
            }
        }
        Ok(())
    }

    /// The room a target lies in, the cell to walk to (none for a room),
    /// and the goal to keep. A seat is checked for its holder and
    /// reservation; a point, or a seat asked for by someone who takes no
    /// seat, moves to the nearest fine place to stand.
    fn resolve_target(
        &self,
        occ: &CityId,
        to: Target,
    ) -> Result<(PlaceId, Option<Cell>, Option<Target>), RejectReason> {
        let nav = self.nav_ref();
        let stand_at =
            |pos: Point| -> Result<(PlaceId, Option<Cell>, Option<Target>), RejectReason> {
                let c = self
                    .standing_near(occ, pos)
                    .ok_or(RejectReason::Unreachable)?;
                let room = nav.room_at(c).expect("standing cells are walkable").clone();
                let pos = nav.centre(c);
                Ok((room, Some(c), Some(Target::Point { pos })))
            };
        match to {
            Target::Room { room } => {
                if !self.index.rooms.contains_key(&room) {
                    return Err(RejectReason::UnknownRoom);
                }
                Ok((room, None, None))
            }
            Target::Point { pos } => stand_at(pos),
            Target::Seat { seat } => {
                let (room, info) = self
                    .index
                    .rooms
                    .values()
                    .find_map(|r| r.seats.iter().find(|s| s.id == seat).map(|s| (&r.id, s)))
                    .ok_or(RejectReason::UnknownRoom)?;
                let pos = info.pos.ok_or(RejectReason::Unreachable)?;
                if !self.shares(occ) {
                    // Hidden occupants never take a seat; they stand beside it.
                    return stand_at(pos);
                }
                if info.reserved_for.as_ref().is_some_and(|o| o != occ) {
                    return Err(RejectReason::NotYourSeat);
                }
                if self.state.rooms[room].seats[&seat]
                    .as_ref()
                    .is_some_and(|h| h != occ)
                {
                    return Err(RejectReason::SeatTaken);
                }
                Ok((
                    room.clone(),
                    Some(nav.cell_of(pos)),
                    Some(Target::Seat { seat }),
                ))
            }
        }
    }

    /// The fine place to stand nearest `pos`: in the room whose floor holds
    /// `pos` when there is one there, else anywhere. Public occupants also
    /// avoid cells other public occupants hold or are heading to.
    fn standing_near(&self, occ: &CityId, pos: Point) -> Option<Cell> {
        let nav = self.nav_ref();
        let taken = self.taken_by_others(occ);
        let ok = |c: Cell| self.good_to_stand(c) && !taken.contains(&c);
        let intended = self
            .index
            .rooms
            .values()
            .find(|r| r.rect.is_some_and(|x| x.contains(pos)))
            .map(|r| &r.id);
        intended
            .and_then(|room| nav.nearest(pos, &|c| nav.room_at(c) == Some(room) && ok(c)))
            .or_else(|| nav.nearest(pos, &ok))
    }

    /// Whether `c` is a fine place to stand in any room: walkable, and not
    /// a door span, seat, queue place, track or entrance approach.
    pub(crate) fn good_to_stand(&self, c: Cell) -> bool {
        let nav = self.nav_ref();
        nav.walkable(c)
            && !nav.in_door_span(c)
            && !self.queue_cells.contains(&c)
            && !self.track_cells.contains(&c)
            && !nav.is_seat_cell(c)
            && !self.near_entrance(c)
    }

    /// For a public occupant, the cells other public occupants hold or are
    /// heading to; nothing for a hidden one.
    pub(crate) fn taken_by_others(&self, occ: &CityId) -> BTreeSet<Cell> {
        let mut taken = BTreeSet::new();
        if !self.shares(occ) {
            return taken;
        }
        let nav = self.nav_ref();
        for (id, o) in &self.state.occupants {
            if id == occ || matches!(o.location, Location::Away) || !self.shares(id) {
                continue;
            }
            if let Some(p) = o.pos {
                taken.insert(nav.cell_of(p));
            }
            if let Some(end) = o.walk.as_ref().and_then(|w| w.path.last()) {
                taken.insert(nav.cell_of(*end));
            }
        }
        taken
    }

    /// Gets up from the seat `occ` holds, if any, keeping it in the room,
    /// and ends a `Use` of it.
    pub(crate) fn stand_up(&mut self, occ: &CityId) {
        let Location::InRoom {
            room,
            seat: Some(seat),
        } = self.state.occupants[occ].location.clone()
        else {
            return;
        };
        *self
            .state
            .rooms
            .get_mut(&room)
            .expect("room exists")
            .seats
            .get_mut(&seat)
            .expect("seat exists") = None;
        self.state
            .occupants
            .get_mut(occ)
            .expect("occupant exists")
            .location = Location::InRoom {
            room: room.clone(),
            seat: None,
        };
        self.push(
            Some(occ),
            EventKind::SeatReleased {
                room,
                seat: seat.clone(),
            },
        );
        crate::interact::seat_released(self, occ, &seat);
    }

    /// Gives `seat` in `room` to `occ`, who is in the room without one.
    pub(crate) fn take_seat(&mut self, occ: &CityId, room: &PlaceId, seat: PlaceId) {
        *self
            .state
            .rooms
            .get_mut(room)
            .expect("room exists")
            .seats
            .get_mut(&seat)
            .expect("seat exists") = Some(occ.clone());
        self.state
            .occupants
            .get_mut(occ)
            .expect("occupant exists")
            .location = Location::InRoom {
            room: room.clone(),
            seat: Some(seat.clone()),
        };
        self.push(
            Some(occ),
            EventKind::Seated {
                room: room.clone(),
                seat,
            },
        );
    }

    /// Points an occupant that is not in a room at `room`: it walks `path`
    /// to the threshold, or is admitted at the next Admit when already there.
    fn head_in(&mut self, occ: &CityId, room: PlaceId, path: Vec<Cell>) {
        // Entering means admission: one standing on the room's floor that
        // cannot be admitted (crossing it, say) first walks out to where its
        // queue forms, and asks there.
        let mut path = path;
        if path.is_empty()
            && self.nav.is_some()
            && self.shares(occ)
            && !self.may_enter(&room, occ)
            && let Some(c) = self.cell_of_occ(occ)
        {
            let nav = self.nav_ref();
            if nav.room_at(c) == Some(&room) && !nav.in_door_span(c) {
                path = nav
                    .queue_slots(&room, 1)
                    .first()
                    .and_then(|slot| nav.path_to(c, *slot, &|_| false))
                    .unwrap_or_default();
            }
        }
        self.state.admission_queue.retain(|o| o != occ);
        let o = self.state.occupants.get_mut(occ).expect("occupant exists");
        o.location = Location::Arriving { room: room.clone() };
        o.walk = None;
        if path.is_empty() {
            self.state.admission_queue.push(occ.clone());
        } else {
            self.set_walk(occ, path, WalkPurpose::ToDoor { target: room });
        }
    }

    // ---- Walking helpers ----

    /// Cells held by public occupants: where they stand, sit, queue or walk.
    /// Hidden occupants hold nothing.
    pub(crate) fn walker_cells(&self) -> BTreeMap<Cell, CityId> {
        let Some(nav) = &self.nav else {
            return BTreeMap::new();
        };
        self.state
            .occupants
            .iter()
            .filter(|(_, o)| !matches!(o.location, Location::Away))
            .filter(|(_, o)| shares_capacity(&o.profile.kind))
            .filter_map(|(id, o)| o.pos.map(|p| (nav.cell_of(p), id.clone())))
            .collect()
    }

    /// The cells public walkers hold, which vehicles never move onto.
    pub(crate) fn public_walker_cells(&self) -> BTreeSet<Cell> {
        self.walker_cells().into_keys().collect()
    }

    /// Cells no public walker may step onto: those public occupants hold,
    /// and those vehicles cover, each named by its holder. A walker blocked
    /// by a vehicle waits, then plans round it, as round a crowd.
    fn reserved_cells(&self) -> BTreeMap<Cell, CityId> {
        let mut reserved = self.walker_cells();
        if let Some(nav) = &self.nav {
            for vehicle in &self.state.vehicles {
                for c in crate::transit::footprint(&self.index, nav, vehicle) {
                    reserved.entry(c).or_insert_with(|| vehicle.id.clone());
                }
            }
        }
        reserved
    }

    fn nav_ref(&self) -> &NavGrid {
        self.nav.as_ref().expect("only called with a layout")
    }

    fn cell_of_occ(&self, occ: &CityId) -> Option<Cell> {
        let nav = self.nav.as_ref()?;
        self.state.occupants[occ].pos.map(|p| nav.cell_of(p))
    }

    pub(crate) fn set_pos(&mut self, occ: &CityId, c: Cell) {
        let p = self.nav_ref().centre(c);
        self.state
            .occupants
            .get_mut(occ)
            .expect("occupant exists")
            .pos = Some(p);
    }

    pub(crate) fn set_walk(&mut self, occ: &CityId, cells: Vec<Cell>, purpose: WalkPurpose) {
        let path: Vec<Point> = cells.iter().map(|c| self.nav_ref().centre(*c)).collect();
        self.state
            .occupants
            .get_mut(occ)
            .expect("occupant exists")
            .walk = Some(Walk {
            path,
            purpose,
            blocked: 0,
        });
    }

    /// A cheapest walk from `from` to `room`'s threshold, down that room's
    /// distance field; empty when already inside.
    fn walk_into(&self, from: Cell, room: &PlaceId) -> Option<Vec<Cell>> {
        let nav = self.nav_ref();
        if nav.room_at(from) == Some(room) {
            return Some(Vec::new());
        }
        nav.descend(&self.room_fields[room], from)
    }

    /// The entrance with the cheapest walk to `target`'s threshold, and that
    /// walk. Ties go to the entrance listed first.
    fn entrance_for(&self, target: &PlaceId) -> Option<(Cell, Vec<Cell>)> {
        let nav = self.nav_ref();
        let field = &self.room_fields[target];
        let mut best: Option<(u32, Cell)> = None;
        for e in &self.index.entrances {
            let Some(start) = nav.snap(*e) else { continue };
            let cost = if nav.room_at(start) == Some(target) {
                0
            } else {
                field[nav.slot(start).expect("snapped cells are in bounds")]
            };
            if cost != u32::MAX && best.is_none_or(|(b, _)| cost < b) {
                best = Some((cost, start));
            }
        }
        let (_, start) = best?;
        Some((start, self.walk_into(start, target)?))
    }

    /// A cheapest walk from `from` to an entrance.
    /// Leavers leave the city within a metre of an entrance, so they never
    /// crowd the entrance cell that new arrivals step onto.
    fn exit_path(&self, from: Cell) -> Option<Vec<Cell>> {
        let nav = self.nav_ref();
        let mut path = nav.descend(&self.exit_field, from)?;
        let near = |c: Cell| self.near_entrance(c);
        if near(from) {
            return Some(Vec::new());
        }
        if let Some(k) = path.iter().position(|c| near(*c)) {
            path.truncate(k + 1);
        }
        Some(path)
    }

    // ---- 2. Expire ----

    fn expire(&mut self, t: Tick) {
        let mut expired = Vec::new();
        for (id, o) in &self.state.occupants {
            if matches!(o.location, Location::Away) {
                continue;
            }
            let p = &o.presence;
            if p.connection
                .as_ref()
                .is_some_and(|c| is_expired(&c.stamp, t))
                && o.shown.connection != ShownConnection::Stale
            {
                expired.push((id.clone(), Dimension::Connection));
            }
            if p.process.as_ref().is_some_and(|c| is_expired(&c.stamp, t))
                && o.shown.process != ShownProcess::Stale
            {
                expired.push((id.clone(), Dimension::Process));
            }
            if p.task.as_ref().is_some_and(|c| is_expired(&c.stamp, t))
                && o.shown.task != ShownTask::Stale
            {
                expired.push((id.clone(), Dimension::Task));
            }
        }
        for (id, dimension) in expired {
            self.push(Some(&id), EventKind::ObservationExpired { dimension });
        }
    }

    // ---- 3. Admit ----

    fn shares(&self, occ: &CityId) -> bool {
        shares_capacity(&self.state.occupants[occ].profile.kind)
    }

    /// Whether `occ` may enter `room` now. Only occupants who share capacity
    /// count, and a platform's waiters count as its occupants do. Capacity
    /// is held for reserved-seat owners who are absent, so strangers never
    /// lock an owner out.
    fn has_room(&self, room: &PlaceId, occ: &CityId) -> bool {
        let info = &self.index.rooms[room];
        let state = &self.state.rooms[room];
        let present = state.occupants.iter().filter(|o| self.shares(o)).count() as u64
            + crate::transit::waiters_on(self, room);
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

    /// Sends `occ`, standing past `room`'s door span, back out over its
    /// threshold on its way in; false if it is not inside or no way leads out.
    fn walk_out_of(&mut self, occ: &CityId, room: &PlaceId) -> bool {
        let (Some(nav), Some(c)) = (self.nav.as_ref(), self.cell_of_occ(occ)) else {
            return false;
        };
        if nav.room_at(c) != Some(room) || nav.in_door_span(c) {
            return false;
        }
        let outside = |x: Cell| nav.room_at(x) != Some(room) && !nav.in_door_span(x);
        let Some(slot) = nav.queue_slots(room, 1).first().copied() else {
            return false;
        };
        let Some(path) = nav
            .path_to(c, slot, &|_| false)
            .filter(|p| p.iter().any(|x| outside(*x)))
        else {
            return false;
        };
        self.set_walk(
            occ,
            path,
            WalkPurpose::ToDoor {
                target: room.clone(),
            },
        );
        true
    }

    /// Whether `c` is within the leash of `occ`'s place in `room`'s queue.
    fn near_queue_place(&self, occ: &CityId, room: &PlaceId, c: Cell) -> bool {
        let list = &self.state.rooms[room].waitlist;
        let Some(k) = list.iter().position(|o| o == occ) else {
            return false;
        };
        let slots = self.nav_ref().queue_slots(room, k + 1);
        slots
            .get(k)
            .is_some_and(|slot| (slot.i - c.i).abs().max((slot.j - c.j).abs()) <= QUEUE_LEASH)
    }

    /// Whether a newcomer may be admitted to `room` now: it has a place for
    /// `occ` and no one is waiting (a newcomer never overtakes a waitlist).
    pub(crate) fn may_enter(&self, room: &PlaceId, occ: &CityId) -> bool {
        self.has_room(room, occ) && self.state.rooms[room].waitlist.is_empty()
    }

    pub(crate) fn place(&mut self, occ: &CityId, room: &PlaceId) {
        self.state
            .rooms
            .get_mut(room)
            .expect("room exists")
            .occupants
            .push(occ.clone());
        self.state
            .occupants
            .get_mut(occ)
            .expect("occupant exists")
            .location = Location::InRoom {
            room: room.clone(),
            seat: None,
        };
        if self.nav.is_some() {
            // Allocate gives the newly placed occupant somewhere to walk.
            self.state
                .occupants
                .get_mut(occ)
                .expect("occupant exists")
                .walk = None;
        }
        self.push(Some(occ), EventKind::Admitted { room: room.clone() });
    }

    /// The first room in `target`'s overflow chain that `occ` may enter.
    fn first_open(&self, target: &PlaceId, occ: &CityId) -> Option<PlaceId> {
        self.index.rooms[target]
            .chain
            .iter()
            .find(|r| self.has_room(r, occ))
            .cloned()
    }

    fn place_via(&mut self, occ: &CityId, target: &PlaceId, room: &PlaceId) {
        if room != target {
            self.push(
                Some(occ),
                EventKind::Overflowed {
                    from: target.clone(),
                    to: room.clone(),
                },
            );
        }
        self.place(occ, room);
    }

    /// Completes transits due by `t`, queueing their occupants for admission
    /// in this same phase so no one is ever between places at a tick's end.
    fn complete_transits(&mut self, t: Tick) {
        let arrived: Vec<(CityId, PlaceId)> = self
            .state
            .occupants
            .iter()
            .filter_map(|(id, o)| match &o.location {
                Location::InTransit { to, arrives_at, .. } if *arrives_at <= t => {
                    Some((id.clone(), to.clone()))
                }
                _ => None,
            })
            .collect();
        for (occ, to) in arrived {
            self.state
                .occupants
                .get_mut(&occ)
                .expect("occupant exists")
                .location = Location::Arriving { room: to.clone() };
            self.state.admission_queue.push(occ.clone());
            self.push(Some(&occ), EventKind::TransitEnded { to });
        }
    }

    fn admit(&mut self, t: Tick) {
        self.complete_transits(t);

        // Waitlists first, strictly in order: the head may take any room in
        // its original room's overflow chain; if it cannot, no one behind it
        // is served from that list.
        let rooms: Vec<PlaceId> = self.state.rooms.keys().cloned().collect();
        for target in &rooms {
            while let Some(head) = self.state.rooms[target].waitlist.first().cloned() {
                let Some(room) = self.first_open(target, &head) else {
                    break;
                };
                self.state
                    .rooms
                    .get_mut(target)
                    .expect("room exists")
                    .waitlist
                    .remove(0);
                self.place_via(&head, target, &room);
            }
        }

        let queue = std::mem::take(&mut self.state.admission_queue);
        for occ in queue {
            let Location::Arriving { room: target } = self.state.occupants[&occ].location.clone()
            else {
                continue;
            };
            // Occupants hidden from the public take no shared capacity, so
            // they never overflow or wait.
            if !self.shares(&occ) {
                self.place(&occ, &target);
                continue;
            }
            // A newcomer never overtakes a waitlist, unless it is the owner of
            // a reserved seat in the room, whose capacity is held for it.
            let queue_ahead = !self.state.rooms[&target].waitlist.is_empty();
            let owner_fits = self.index.rooms[&target].reserved.contains_key(&occ)
                && self.has_room(&target, &occ);
            let open = if queue_ahead && !owner_fits {
                None
            } else {
                self.first_open(&target, &occ)
            };
            match open {
                Some(room) => self.place_via(&occ, &target, &room),
                // Standing on the room's floor when its last place went to
                // someone else this tick: walk out to its door and ask there.
                None if self.walk_out_of(&occ, &target) => {}
                None => {
                    let waitlist = &mut self
                        .state
                        .rooms
                        .get_mut(&target)
                        .expect("room exists")
                        .waitlist;
                    waitlist.push(occ.clone());
                    let position = waitlist.len() as u32;
                    self.state
                        .occupants
                        .get_mut(&occ)
                        .expect("occupant exists")
                        .location = Location::Waitlisted {
                        room: target.clone(),
                    };
                    self.push(
                        Some(&occ),
                        EventKind::Waitlisted {
                            room: target,
                            position,
                        },
                    );
                }
            }
        }
        if self.nav.is_some() {
            self.walk_queues();
        }
    }

    /// Sends every waiting occupant to their place in the queue outside the
    /// room's main door, so queues advance as people are admitted.
    fn walk_queues(&mut self) {
        let rooms: Vec<PlaceId> = self.state.rooms.keys().cloned().collect();
        for room in rooms {
            let waiting = self.state.rooms[&room].waitlist.clone();
            if waiting.is_empty() {
                continue;
            }
            let slots = self.nav_ref().queue_slots(&room, waiting.len());
            for (occ, slot) in waiting.iter().zip(slots) {
                let Some(cur) = self.cell_of_occ(occ) else {
                    continue;
                };
                let o = &self.state.occupants[occ];
                let heading = o.walk.as_ref().and_then(|w| w.path.last()).copied();
                let slot_point = self.nav_ref().centre(slot);
                if cur == slot && o.walk.is_none() || heading == Some(slot_point) {
                    continue;
                }
                // The way to a queue place goes round the room queued for,
                // never across its floor: entering means admission.
                // (One already inside, which admission avoids, may leave
                // across it.)
                let nav = self.nav_ref();
                let inside = |c: Cell| nav.room_at(c) == Some(&room) && !nav.in_door_span(c);
                let starts_inside = inside(cur);
                let blocked = |c: Cell| !starts_inside && inside(c);
                if let Some(path) = nav.path_to(cur, slot, &blocked) {
                    if path.is_empty() {
                        self.state
                            .occupants
                            .get_mut(occ)
                            .expect("occupant exists")
                            .walk = None;
                    } else {
                        self.set_walk(occ, path, WalkPurpose::ToQueue);
                    }
                }
            }
        }
    }

    // ---- 4. Allocate ----

    fn allocate(&mut self, t: Tick) {
        let rooms: Vec<PlaceId> = self.state.rooms.keys().cloned().collect();
        for room in rooms {
            let present = self.state.rooms[&room].occupants.clone();
            for occ in present {
                let Location::InRoom { seat: None, .. } = self.state.occupants[&occ].location
                else {
                    continue;
                };
                if !self.shares(&occ) {
                    continue;
                }
                // The occupant's own choice comes before the room's policy.
                match self.own_choice(&occ, &room) {
                    Choice::Stand => continue,
                    Choice::Seat(seat) => {
                        self.take_seat(&occ, &room, seat);
                        continue;
                    }
                    Choice::Policy => {}
                }
                let info = &self.index.rooms[&room];
                let held = &self.state.rooms[&room].seats;
                let chosen = match info.reserved.get(&occ) {
                    Some(seat) => held[seat].is_none().then(|| seat.clone()),
                    None => {
                        let free: Vec<_> = info
                            .seats
                            .iter()
                            .filter(|s| s.reserved_for.is_none() && held[&s.id].is_none())
                            .collect();
                        let department = self.state.occupants[&occ].profile.department.as_deref();
                        choose_seat(self.index.seat_policy, department, &free)
                    }
                };
                if let Some(seat) = chosen {
                    *self
                        .state
                        .rooms
                        .get_mut(&room)
                        .expect("room exists")
                        .seats
                        .get_mut(&seat)
                        .expect("seat exists") = Some(occ.clone());
                    self.state
                        .occupants
                        .get_mut(&occ)
                        .expect("occupant exists")
                        .location = Location::InRoom {
                        room: room.clone(),
                        seat: Some(seat.clone()),
                    };
                    self.push(
                        Some(&occ),
                        EventKind::Seated {
                            room: room.clone(),
                            seat,
                        },
                    );
                }
            }
        }
        if self.nav.is_some() {
            self.walk_to_places(t);
        }
    }

    /// Settles the goal of `occ`, just placed in `room` without a seat: a
    /// point in this room means it stands there; a seat here that is still
    /// free and its own to take is taken, and one that is not is refused
    /// now. Any other goal is dropped, and the room's policy applies.
    fn own_choice(&mut self, occ: &CityId, room: &PlaceId) -> Choice {
        let goal = self.state.occupants[occ].goal.clone();
        let choice = match &goal {
            Some(Target::Point { pos }) => {
                let here = self
                    .nav
                    .as_ref()
                    .is_some_and(|n| n.room_at(n.cell_of(*pos)) == Some(room));
                if here {
                    return Choice::Stand;
                }
                Choice::Policy
            }
            Some(Target::Seat { seat }) => {
                match self.index.rooms[room].seats.iter().find(|s| &s.id == seat) {
                    Some(info) => {
                        let reason = if info.reserved_for.as_ref().is_some_and(|o| o != occ) {
                            Some(RejectReason::NotYourSeat)
                        } else if self.state.rooms[room].seats[seat].is_some() {
                            Some(RejectReason::SeatTaken)
                        } else {
                            None
                        };
                        match reason {
                            None => Choice::Seat(seat.clone()),
                            Some(reason) => {
                                self.reject(occ, CommandType::Go, reason);
                                Choice::Policy
                            }
                        }
                    }
                    // Admitted elsewhere in the overflow chain.
                    None => Choice::Policy,
                }
            }
            Some(Target::Room { .. }) | None => Choice::Policy,
        };
        self.state
            .occupants
            .get_mut(occ)
            .expect("occupant exists")
            .goal = None;
        choice
    }

    /// The point `occ` chose to stand at in `room`, if it chose one there.
    fn chosen_spot(&self, occ: &CityId, room: &PlaceId) -> Option<Cell> {
        let nav = self.nav.as_ref()?;
        match &self.state.occupants[occ].goal {
            Some(Target::Point { pos }) => {
                let c = nav.cell_of(*pos);
                (nav.room_at(c) == Some(room)).then_some(c)
            }
            _ => None,
        }
    }

    /// Gives every placed occupant a walk to their seat, or, without one, to
    /// the spot it chose or a standing spot inside the room.
    fn walk_to_places(&mut self, t: Tick) {
        let rooms: Vec<PlaceId> = self.state.rooms.keys().cloned().collect();
        for room in rooms {
            for occ in self.state.rooms[&room].occupants.clone() {
                let Some(cur) = self.cell_of_occ(&occ) else {
                    continue;
                };
                let o = &self.state.occupants[&occ];
                let Location::InRoom { seat, .. } = &o.location else {
                    continue;
                };
                let purpose = o.walk.as_ref().map(|w| w.purpose.clone());
                if let Some(seat) = seat {
                    let Some(pos) = self.index.rooms[&room]
                        .seats
                        .iter()
                        .find(|s| &s.id == seat)
                        .and_then(|s| s.pos)
                    else {
                        continue;
                    };
                    let target = self.nav_ref().cell_of(pos);
                    if cur != target
                        && purpose != Some(WalkPurpose::ToSeat)
                        && let Some(path) = self.nav_ref().path_to(cur, target, &|_| false)
                    {
                        self.set_walk(&occ, path, WalkPurpose::ToSeat);
                    }
                } else if let Some(spot) = self.chosen_spot(&occ, &room) {
                    if purpose.is_none()
                        && cur != spot
                        && let Some(path) = self.nav_ref().path_to(cur, spot, &|_| false)
                    {
                        self.set_walk(&occ, path, WalkPurpose::ToSpot);
                    }
                } else if purpose.is_none()
                    && !self.stands_well(cur, &room)
                    && let Some(spot) = self.standing_spot(&room, &occ, t)
                    && let Some(path) = self.nav_ref().path_to(cur, spot, &|_| false)
                {
                    self.set_walk(&occ, path, WalkPurpose::ToSpot);
                }
            }
        }
    }

    /// Whether `c` is a fine place to stand in `room`: inside it, and not a
    /// door span, seat, queue place, track or entrance approach.
    fn stands_well(&self, c: Cell, room: &PlaceId) -> bool {
        let nav = self.nav_ref();
        nav.room_at(c) == Some(room)
            && !nav.in_door_span(c)
            && !self.queue_cells.contains(&c)
            && !self.track_cells.contains(&c)
            && !self.near_entrance(c)
            && !nav.is_seat_cell(c)
    }

    fn near_entrance(&self, c: Cell) -> bool {
        let nav = self.nav_ref();
        self.index
            .entrances
            .iter()
            .filter_map(|e| nav.snap(*e))
            .any(|e| (e.i - c.i).abs().max((e.j - c.j).abs()) <= EXIT_RADIUS)
    }

    /// A free cell to stand in: never a door span, seat or track, and, for
    /// public occupants, never a cell another public occupant holds or is
    /// heading to. The choice uses a per-occupant hash, so hidden occupants cannot
    /// shift anyone's spot.
    fn standing_spot(&self, room: &PlaceId, occ: &CityId, t: Tick) -> Option<Cell> {
        let nav = self.nav_ref();
        let taken = self.taken_by_others(occ);
        let free: Vec<Cell> = nav
            .cells_in(room)
            .into_iter()
            .filter(|c| {
                !nav.in_door_span(*c)
                    && !nav.is_seat_cell(*c)
                    && !self.queue_cells.contains(c)
                    && !self.track_cells.contains(c)
                    && !self.near_entrance(*c)
                    && !taken.contains(c)
            })
            .collect();
        if free.is_empty() {
            return None;
        }
        let k = spot_hash(self.state.seed, occ, t) % free.len() as u64;
        Some(free[k as usize])
    }

    // ---- 5. Transition ----

    /// Starts this tick's moves through their doors. Arrivals complete at
    /// the Admit phase of the tick they are due.
    fn transition(&mut self, t: Tick, moves: Vec<PendingMove>) {
        if self.nav.is_some() {
            self.start_walks(t, moves);
            let steers = std::mem::take(&mut self.steers);
            self.step_walkers(steers);
            return;
        }
        for PendingMove { occupant, to } in moves {
            let Location::InRoom { room: from, .. } =
                self.state.occupants[&occupant].location.clone()
            else {
                continue;
            };
            let Some(door) = self.index.rooms[&from].doors.get(&to).cloned() else {
                continue;
            };
            self.leave_room(&occupant);
            let span = door.transit.max - door.transit.min + 1;
            let arrives_at = t
                .saturating_add(door.transit.min)
                .saturating_add(self.rng.next_u64() % span);
            self.state
                .occupants
                .get_mut(&occupant)
                .expect("occupant exists")
                .location = Location::InTransit {
                from: from.clone(),
                to: to.clone(),
                door: door.id.clone(),
                arrives_at,
            };
            self.push(
                Some(&occupant),
                EventKind::TransitStarted {
                    from,
                    to,
                    door: door.id,
                    arrives_at,
                },
            );
        }
    }

    /// Starts moves between rooms as walks to the new room's threshold.
    fn start_walks(&mut self, t: Tick, moves: Vec<PendingMove>) {
        for PendingMove { occupant, to } in moves {
            let Location::InRoom { room: from, .. } =
                self.state.occupants[&occupant].location.clone()
            else {
                continue;
            };
            let Some(cur) = self.cell_of_occ(&occupant) else {
                continue;
            };
            let Some(path) = self.walk_into(cur, &to) else {
                continue;
            };
            self.state
                .occupants
                .get_mut(&occupant)
                .expect("occupant exists")
                .goal = None;
            self.walk_to_room(&occupant, from, to, path, t);
        }
    }

    /// Leaves `from` and walks `path` to `to`'s threshold, to be admitted
    /// there.
    fn walk_to_room(
        &mut self,
        occupant: &CityId,
        from: PlaceId,
        to: PlaceId,
        path: Vec<Cell>,
        t: Tick,
    ) {
        self.leave_room(occupant);
        let door = self.index.rooms[&from]
            .doors
            .get(&to)
            .map(|d| d.id.clone())
            .or_else(|| {
                self.index.rooms[&to]
                    .doors
                    .values()
                    .map(|d| d.id.clone())
                    .min()
            })
            .unwrap_or_else(|| to.clone());
        let arrives_at = t + (path.len() as u64).div_ceil(STEPS_PER_TICK as u64);
        self.state
            .occupants
            .get_mut(occupant)
            .expect("occupant exists")
            .location = Location::Arriving { room: to.clone() };
        if path.is_empty() {
            self.state.admission_queue.push(occupant.clone());
        } else {
            self.set_walk(occupant, path, WalkPurpose::ToDoor { target: to.clone() });
        }
        self.push(
            Some(occupant),
            EventKind::TransitStarted {
                from,
                to,
                door,
                arrives_at,
            },
        );
    }

    /// Moves every walker up to five cells along its path, in city-ID order.
    /// A public walker never enters a cell another public occupant holds or a
    /// vehicle covers; it waits, and after three blocked ticks plans a way
    /// around them. Two
    /// public walkers who each want the other's cell swap places, so a
    /// head-on meeting in a doorway always resolves. Hidden walkers pass
    /// through everyone and hold nothing.
    fn step_walkers(&mut self, steers: Vec<PendingSteer>) {
        for o in self.state.occupants.values_mut() {
            o.trail.clear();
        }
        let mut reserved = self.reserved_cells();
        let mut steps: BTreeMap<CityId, usize> = BTreeMap::new();
        // Steered steps come first, in the order they were given, and
        // count against the same five cells a tick.
        for PendingSteer { occupant, cells } in steers {
            self.steer(&occupant, &cells, &mut reserved, &mut steps);
        }
        let walkers: Vec<CityId> = self
            .state
            .occupants
            .iter()
            .filter(|(_, o)| o.walk.is_some())
            .map(|(id, _)| id.clone())
            .collect();
        for occ in walkers {
            if self.state.occupants[&occ].walk.is_none() {
                continue;
            }
            let public = self.shares(&occ);
            let (mut moved, oncoming) = self.advance(&occ, public, &mut reserved, &mut steps);
            if let Some(other) = oncoming
                && self.swap(&occ, &other, &mut reserved, &mut steps)
            {
                moved = true;
                self.settle(&other, true, &reserved);
            }
            self.settle(&occ, moved, &reserved);
        }
    }

    /// Steps `occ` along steered cells: it stands up first, for free, and
    /// drops any walk or goal in progress. Each step must be one the grid
    /// allows from the last (adjacent, walkable, through door spans, no
    /// corner cutting), within the tick's five cells, and, for a public
    /// occupant, onto no cell another public occupant holds and into no room
    /// it is not admitted to that is full or that others queue for (a
    /// steered entry tries only the room it walks into, so it never waits
    /// or overflows: `Go` queues). The first refused step ends the steer:
    /// with `Seat` for a step onto a seat's cell (a seat is sat in by `Go`,
    /// never stepped onto), with `RoomFull` for a step from outside into
    /// such a room, onto its door span or over an open-air edge, which
    /// leaves it at the threshold, and otherwise with `BlockedStep`.
    fn steer(
        &mut self,
        occ: &CityId,
        cells: &[Point],
        reserved: &mut BTreeMap<Cell, CityId>,
        steps: &mut BTreeMap<CityId, usize>,
    ) {
        let o = &self.state.occupants[occ];
        if matches!(o.location, Location::Away | Location::Leaving { .. }) || o.pos.is_none() {
            return;
        }
        let public = self.shares(occ);
        let was_seated = matches!(
            self.state.occupants[occ].location,
            Location::InRoom { seat: Some(_), .. }
        );
        // Rooms this occupant may not step into past the door: every room
        // it is not admitted to that has no space for it, and the room it
        // queues for.
        let closed: BTreeSet<PlaceId> = if public {
            let loc = &self.state.occupants[occ].location;
            // A waiter is counted on its platform, as if admitted there.
            let waiting_on = match loc {
                Location::WaitingFor {
                    stop,
                    direction: Some(d),
                } => crate::transit::platform_of(&self.index, stop, *d),
                _ => None,
            };
            self.index
                .rooms
                .keys()
                .filter(|r| {
                    let admitted = matches!(loc, Location::InRoom { room, .. } if room == *r)
                        || waiting_on == Some(*r);
                    let queued = matches!(loc, Location::Waitlisted { room } if room == *r);
                    !admitted && (queued || !self.may_enter(r, occ))
                })
                .cloned()
                .collect()
        } else {
            BTreeSet::new()
        };
        self.stand_up(occ);
        // A step, or standing up, ends whatever it was using.
        crate::interact::end_use(self, occ);
        let nav = self.nav.as_ref().expect("layout");
        let o = self.state.occupants.get_mut(occ).expect("occupant exists");
        o.walk = None;
        o.goal = None;
        let mut at = nav.cell_of(o.pos.expect("present occupants have a position"));
        let taken = steps.entry(occ.clone()).or_default();
        let mut moved = false;
        let mut refused = None;
        for p in cells {
            let next = nav.cell_of(*p);
            let free = !public || reserved.get(&next).is_none_or(|h| h == occ);
            // Any step from outside into a closed room is where it turns
            // the occupant away, on its door span or, for open-air rooms
            // that join along any edge, off it. Past that step, off the
            // span, the closed room's floor is simply not walked on.
            let full = nav
                .room_at(next)
                .filter(|r| closed.contains(*r) && nav.room_at(at) != Some(*r))
                .cloned();
            let shut =
                !nav.in_door_span(next) && nav.room_at(next).is_some_and(|r| closed.contains(r));
            refused = if *taken >= STEPS_PER_TICK || !nav.can_step(at, next) {
                Some(RejectReason::BlockedStep)
            } else if nav.is_seat_cell(next) {
                Some(RejectReason::Seat)
            } else if let Some(room) = full {
                Some(RejectReason::RoomFull { room })
            } else if !free || shut {
                Some(RejectReason::BlockedStep)
            } else {
                None
            };
            if refused.is_some() {
                break;
            }
            if public {
                if reserved.get(&at) == Some(occ) {
                    reserved.remove(&at);
                }
                reserved.insert(next, occ.clone());
            }
            let c = nav.centre(next);
            o.facing = facing_of(next.i - at.i, next.j - at.j);
            o.pos = Some(c);
            o.trail.push(c);
            at = next;
            moved = true;
            *taken += 1;
        }
        // Standing up without stepping anywhere steps off the seat, onto a
        // free cell beside it in the same room, so the seat's cell is free
        // for whoever sits there next.
        if was_seated && !moved {
            let room = nav.room_at(at).cloned();
            let beside = [
                (0, 1),
                (1, 0),
                (-1, 0),
                (0, -1),
                (1, 1),
                (-1, 1),
                (1, -1),
                (-1, -1),
            ]
            .into_iter()
            .map(|(di, dj)| Cell {
                i: at.i + di,
                j: at.j + dj,
            })
            .find(|c| {
                nav.can_step(at, *c)
                    && nav.room_at(*c).cloned() == room
                    && !nav.is_seat_cell(*c)
                    && (!public || reserved.get(c).is_none_or(|h| h == occ))
            });
            if let Some(next) = beside {
                if public {
                    if reserved.get(&at) == Some(occ) {
                        reserved.remove(&at);
                    }
                    reserved.insert(next, occ.clone());
                }
                let o = self.state.occupants.get_mut(occ).expect("occupant exists");
                let c = nav.centre(next);
                o.pos = Some(c);
                o.trail.push(c);
                // The step off counts against the tick's budget like any other.
                *steps.entry(occ.clone()).or_default() += 1;
            }
        }
        self.follow_steps(occ, moved, true);
        if let Some(reason) = refused {
            self.reject(occ, CommandType::Steer, reason);
        }
    }

    /// Brings a steered occupant's place in line with where it now stands.
    /// Stepping out of its room leaves the room, out of the line it queued
    /// in leaves the queue, and off the platform it waited on stops its
    /// waiting; either way, and for one on its way in, it is admitted afresh
    /// to the room underfoot at the next Admit, as a walk arriving at the
    /// threshold would be. It then keeps to the spot it stepped to, so no
    /// policy seat or standing spot pulls it away. A `steered` step into a
    /// room with a place for it is admitted on the step, even onto the
    /// door span, so nothing admitted later in the tick can leave it
    /// waiting for or overflowed from the room it walked into.
    fn follow_steps(&mut self, occ: &CityId, moved: bool, steered: bool) {
        let nav = self.nav_ref();
        let Some(here) = self.cell_of_occ(occ) else {
            return;
        };
        let Some(underfoot) = nav.room_at(here).cloned() else {
            return;
        };
        let spot = nav.centre(here);
        let past_door = !nav.in_door_span(here);
        match self.state.occupants[occ].location.clone() {
            Location::InRoom { room, .. } if room != underfoot && moved => {
                self.leave_room(occ);
                self.head_in(occ, underfoot.clone(), Vec::new());
            }
            Location::WaitingFor {
                stop,
                direction: Some(d),
            } if moved
                && crate::transit::platform_of(&self.index, &stop, d) != Some(&underfoot) =>
            {
                crate::transit::forget_waiting(self, occ);
                self.head_in(occ, underfoot.clone(), Vec::new());
            }
            Location::Waitlisted { room }
                if room != underfoot && moved && !self.near_queue_place(occ, &room, here) =>
            {
                self.state
                    .rooms
                    .get_mut(&room)
                    .expect("room exists")
                    .waitlist
                    .retain(|o| o != occ);
                self.head_in(occ, underfoot.clone(), Vec::new());
            }
            // One on its way in heads into the room it stepped into, if
            // it stepped there; standing still, or crossing a room it may
            // not enter, it resumes its way to its own room.
            Location::Arriving { room: target } => {
                let enterable = !past_door || !self.shares(occ) || self.may_enter(&underfoot, occ);
                if underfoot == target || (moved && enterable) {
                    self.head_in(occ, underfoot.clone(), Vec::new());
                } else {
                    let path = self.walk_into(here, &target).unwrap_or_default();
                    self.head_in(occ, target, path);
                }
            }
            _ => {}
        }
        // Stepped past the door span onto the floor of a room with a place
        // for it (see steer), or steered onto its span, it is admitted on the
        // step: nothing admitted later in the tick can leave it standing
        // inside a room it waits for, or send a steered entry elsewhere.
        let open = !self.shares(occ) || self.may_enter(&underfoot, occ);
        if moved
            && (past_door || steered)
            && open
            && matches!(&self.state.occupants[occ].location, Location::Arriving { room } if *room == underfoot)
        {
            self.state.admission_queue.retain(|o| o != occ);
            self.place(occ, &underfoot);
        }
        let o = self.state.occupants.get_mut(occ).expect("occupant exists");
        if matches!(
            o.location,
            Location::InRoom { .. } | Location::Arriving { .. }
        ) {
            o.goal = Some(Target::Point { pos: spot });
        }
    }

    /// Steps `occ` along its path within its remaining budget for the tick.
    /// Returns whether it moved and, if a public walker coming the other
    /// way blocked it, who.
    fn advance(
        &mut self,
        occ: &CityId,
        public: bool,
        reserved: &mut BTreeMap<Cell, CityId>,
        steps: &mut BTreeMap<CityId, usize>,
    ) -> (bool, Option<CityId>) {
        let nav = self.nav.as_ref().expect("layout");
        let o = self.state.occupants.get_mut(occ).expect("occupant exists");
        let walk = o.walk.as_mut().expect("walker");
        let mut at = o.pos.map(|p| nav.cell_of(p));
        let mut moved = false;
        let taken = steps.entry(occ.clone()).or_default();
        while *taken < STEPS_PER_TICK {
            let Some(&next) = walk.path.first() else {
                break;
            };
            let next_cell = nav.cell_of(next);
            if public && let Some(holder) = reserved.get(&next_cell).filter(|h| *h != occ) {
                return (moved, Some(holder.clone()));
            }
            walk.path.remove(0);
            if let Some(prev) = at {
                o.facing = facing_of(next_cell.i - prev.i, next_cell.j - prev.j);
                if public && reserved.get(&prev) == Some(occ) {
                    reserved.remove(&prev);
                }
            }
            if public {
                reserved.insert(next_cell, occ.clone());
            }
            o.pos = Some(next);
            o.trail.push(next);
            at = Some(next_cell);
            moved = true;
            *taken += 1;
        }
        (moved, None)
    }

    /// Swaps two public walkers who each want the other's cell, if both
    /// still have a step left this tick. A vehicle never swaps.
    fn swap(
        &mut self,
        a: &CityId,
        b: &CityId,
        reserved: &mut BTreeMap<Cell, CityId>,
        steps: &mut BTreeMap<CityId, usize>,
    ) -> bool {
        let nav = self.nav.as_ref().expect("layout");
        if !self.state.occupants.contains_key(b) || !self.shares(b) {
            return false;
        }
        let (oa, ob) = (&self.state.occupants[a], &self.state.occupants[b]);
        let (Some(pa), Some(pb)) = (oa.pos, ob.pos) else {
            return false;
        };
        let (ca, cb) = (nav.cell_of(pa), nav.cell_of(pb));
        let wants = |o: &OccupantState, c: Cell| {
            o.walk
                .as_ref()
                .and_then(|w| w.path.first())
                .is_some_and(|p| nav.cell_of(*p) == c)
        };
        let budget = |id: &CityId| steps.get(id).copied().unwrap_or(0) < STEPS_PER_TICK;
        if !(wants(oa, cb) && wants(ob, ca) && budget(a) && budget(b)) {
            return false;
        }
        for (id, from, to) in [(a, ca, cb), (b, cb, ca)] {
            let o = self.state.occupants.get_mut(id).expect("occupant exists");
            let walk = o.walk.as_mut().expect("walker");
            let next = walk.path.remove(0);
            walk.blocked = 0;
            o.facing = facing_of(to.i - from.i, to.j - from.j);
            o.pos = Some(next);
            o.trail.push(next);
            reserved.insert(to, id.clone());
            *steps.entry(id.clone()).or_default() += 1;
        }
        true
    }

    /// After a walker's turn: counts blocked ticks, re-plans around a crowd,
    /// treats a held-up walker near its door as arrived, and finishes walks
    /// whose paths are done.
    fn settle(&mut self, occ: &CityId, moved: bool, reserved: &BTreeMap<Cell, CityId>) {
        let nav = self.nav.as_ref().expect("layout");
        // One queued goes round the room it waits for, never across it.
        let queued_for = match &self.state.occupants[occ].location {
            Location::Waitlisted { room } => Some(room.clone()),
            _ => None,
        };
        let o = self.state.occupants.get_mut(occ).expect("occupant exists");
        let Some(walk) = o.walk.as_mut() else {
            return;
        };
        let at = o.pos.map(|p| nav.cell_of(p));
        if moved {
            walk.blocked = 0;
        } else if !walk.path.is_empty() {
            walk.blocked += 1;
            if walk.blocked >= REPLAN_AFTER {
                walk.blocked = 0;
                let starts_inside = at.is_some_and(|c| {
                    queued_for
                        .as_ref()
                        .is_some_and(|r| nav.room_at(c) == Some(r))
                        && !nav.in_door_span(c)
                });
                let others = |c: Cell| {
                    reserved.get(&c).is_some_and(|h| h != occ)
                        || (!starts_inside
                            && queued_for
                                .as_ref()
                                .is_some_and(|r| nav.room_at(c) == Some(r))
                            && !nav.in_door_span(c))
                };
                // A* toward where the walk was going: a guided search finds
                // a way round a crowd well within budget, where a blind
                // search for any threshold cell would not.
                let replanned = at.and_then(|from| {
                    walk.path.last().and_then(|goal| {
                        nav.path_bounded(from, nav.cell_of(*goal), &others, REPLAN_BUDGET)
                    })
                });
                // A departure whose platform cell someone else now holds,
                // or that finds no way round, plans its walk afresh (see
                // `transit::reach_platforms`).
                let goal_taken = walk
                    .path
                    .last()
                    .is_some_and(|g| reserved.get(&nav.cell_of(*g)).is_some_and(|h| h != occ));
                let to_platform = matches!(walk.purpose, WalkPurpose::ToPlatform { .. });
                match replanned {
                    _ if to_platform && goal_taken => walk.path.clear(),
                    Some(path) if !path.is_empty() => {
                        walk.path = path.iter().map(|c| nav.centre(*c)).collect();
                    }
                    _ if to_platform => walk.path.clear(),
                    _ => {}
                }
            }
        }
        // A walker held up within a few cells of its door has arrived: it is
        // admitted or queued there rather than waiting behind the people
        // crowding the threshold. Not one still on the floor of the room it
        // walks out of to queue for: asked again there, it would be sent
        // out again, tick after tick, or queued inside the room. It waits,
        // and plans round whoever holds it up.
        let on_target_floor = |target: &PlaceId| {
            at.is_some_and(|c| nav.room_at(c) == Some(target) && !nav.in_door_span(c))
        };
        if !moved
            && matches!(&walk.purpose, WalkPurpose::ToDoor { target } if !on_target_floor(target))
            && walk.path.len() <= DOOR_REACH
        {
            walk.path.clear();
        }
        if !walk.path.is_empty() {
            return;
        }
        if matches!(walk.purpose, WalkPurpose::ToPlatform { .. }) {
            // A departure's walk to its platform ends only when it begins
            // waiting there (see `transit::reach_platforms`).
            return;
        }
        let purpose = walk.purpose.clone();
        o.walk = None;
        match purpose {
            WalkPurpose::ToDoor { .. } => self.state.admission_queue.push(occ.clone()),
            WalkPurpose::ToSeat => {
                if let Location::InRoom {
                    room,
                    seat: Some(seat),
                } = &o.location
                    && let Some(f) = self.index.rooms[room]
                        .seats
                        .iter()
                        .find(|s| &s.id == seat)
                        .map(|s| s.facing)
                {
                    o.facing = f;
                }
            }
            WalkPurpose::ToSpot
            | WalkPurpose::ToQueue
            | WalkPurpose::ToExit
            | WalkPurpose::ToPlatform { .. } => {}
        }
    }

    /// Takes an occupant out of its room, releasing any seat it held and
    /// ending a `Use` of it.
    pub(crate) fn leave_room(&mut self, occ: &CityId) -> Option<PlaceId> {
        let Location::InRoom { room, seat } = self.state.occupants[occ].location.clone() else {
            return None;
        };
        let state = self.state.rooms.get_mut(&room).expect("room exists");
        state.occupants.retain(|o| o != occ);
        if let Some(seat) = seat {
            *state.seats.get_mut(&seat).expect("seat exists") = None;
            self.push(
                Some(occ),
                EventKind::SeatReleased {
                    room: room.clone(),
                    seat: seat.clone(),
                },
            );
            crate::interact::seat_released(self, occ, &seat);
        }
        Some(room)
    }

    // ---- 6. Depart ----

    fn depart(&mut self, departures: Vec<(CityId, bool)>) {
        if self.nav.is_some() {
            self.depart_walking(departures);
            return;
        }
        for (occ, at_once) in departures {
            if crate::transit::depart_riding(self, &occ, at_once) {
                continue;
            }
            let from = match self.state.occupants[&occ].location.clone() {
                Location::Away | Location::WaitingFor { .. } | Location::Aboard { .. } => continue,
                Location::InRoom { .. } => {
                    let from = self.leave_room(&occ);
                    crate::interact::end_use(self, &occ);
                    from
                }
                Location::Waitlisted { room } => {
                    self.state
                        .rooms
                        .get_mut(&room)
                        .expect("room exists")
                        .waitlist
                        .retain(|o| o != &occ);
                    None
                }
                Location::Arriving { .. } => {
                    self.state.admission_queue.retain(|o| o != &occ);
                    None
                }
                Location::InTransit { .. } | Location::Leaving { .. } => None,
            };
            let o = self.state.occupants.get_mut(&occ).expect("occupant exists");
            o.location = Location::Away;
            o.presence = PresenceRecord::default();
            o.shown = ShownPresence::default();
            o.goal = None;
            self.push(Some(&occ), EventKind::Departed { from, via: None });
        }
    }

    /// With a layout, leaving is a walk: the seat or queue place is given up
    /// at once, and the occupant departs on reaching an entrance, or, by
    /// tram, walks to a platform to ride out (see `transit`). Waiters and
    /// riders ride out with their vehicle. A player's departure (`at_once`)
    /// is the exception: it leaves at once, from wherever it is.
    fn depart_walking(&mut self, departures: Vec<(CityId, bool)>) {
        let by_tram = crate::transit::by_tram(self);
        for (occ, at_once) in departures {
            if crate::transit::depart_riding(self, &occ, at_once) {
                continue;
            }
            let to_platform = if by_tram && self.shares(&occ) && !at_once {
                crate::transit::plan_platform_walk(self, &occ)
            } else {
                None
            };
            let from = match self.state.occupants[&occ].location.clone() {
                Location::Away
                | Location::Leaving { .. }
                | Location::WaitingFor { .. }
                | Location::Aboard { .. } => continue,
                Location::InRoom { .. } => {
                    let from = self.leave_room(&occ);
                    crate::interact::end_use(self, &occ);
                    from
                }
                Location::Waitlisted { room } => {
                    self.state
                        .rooms
                        .get_mut(&room)
                        .expect("room exists")
                        .waitlist
                        .retain(|o| o != &occ);
                    None
                }
                Location::Arriving { .. } | Location::InTransit { .. } => {
                    self.state.admission_queue.retain(|o| o != &occ);
                    None
                }
            };
            let o = self.state.occupants.get_mut(&occ).expect("occupant exists");
            o.location = Location::Leaving { from };
            o.walk = None;
            o.goal = None;
            match to_platform {
                Some((stop, path)) => self.set_walk(&occ, path, WalkPurpose::ToPlatform { stop }),
                // With no walk, it departs below, this tick.
                None if at_once => {}
                None => self.walk_to_depart(&occ),
            }
        }
        let gone: Vec<(CityId, Option<PlaceId>)> = self
            .state
            .occupants
            .iter()
            .filter_map(|(id, o)| match &o.location {
                Location::Leaving { from } if o.walk.is_none() => Some((id.clone(), from.clone())),
                _ => None,
            })
            .collect();
        for (occ, from) in gone {
            let o = self.state.occupants.get_mut(&occ).expect("occupant exists");
            o.location = Location::Away;
            o.presence = PresenceRecord::default();
            o.shown = ShownPresence::default();
            o.pos = None;
            o.facing = 0;
            self.push(Some(&occ), EventKind::Departed { from, via: None });
        }
    }

    /// Sets `occ`, leaving, walking to the nearest entrance to depart there;
    /// with no walk left, it departs at the end of this Depart phase.
    pub(crate) fn walk_to_depart(&mut self, occ: &CityId) {
        let path = self
            .cell_of_occ(occ)
            .and_then(|c| self.exit_path(c))
            .unwrap_or_default();
        self.state
            .occupants
            .get_mut(occ)
            .expect("occupant exists")
            .walk = None;
        if !path.is_empty() {
            self.set_walk(occ, path, WalkPurpose::ToExit);
        }
    }

    /// Steps `occ`, a public walker that has stood in a held vehicle's way
    /// for `transit::STEP_ASIDE_AFTER` ticks, to the nearest good place to
    /// stand (see `good_to_stand`: off the track), within the steps it has
    /// left this tick and through no cell anyone else holds or a vehicle
    /// covers: `SteppedAside { from, to }`. A walk that led onto the track
    /// ends there (as does any goal on it: it keeps to where it was put); a
    /// walk to somewhere else plans afresh from where it now stands.
    /// Stepping into another room is followed as a steered step is. Returns
    /// whether it moved; with no such place near enough it stays, and the
    /// vehicle tries again next tick.
    pub(crate) fn step_aside(&mut self, occ: &CityId) -> bool {
        let Some(from) = self.cell_of_occ(occ) else {
            return false;
        };
        let budget = STEPS_PER_TICK.saturating_sub(self.state.occupants[occ].trail.len());
        let reserved = self.reserved_cells();
        let nav = self.nav_ref();
        let blocked = |c: Cell| reserved.get(&c).is_some_and(|h| h != occ);
        let ok = |c: Cell| self.good_to_stand(c) && !blocked(c);
        let Some(path) = nav.nearest_within(from, budget, &blocked, &ok) else {
            return false;
        };
        let Some(&to) = path.last() else {
            return false;
        };
        let centres: Vec<Point> = path.iter().map(|c| nav.centre(*c)).collect();
        let on_track = |p: &Point| self.track_cells.contains(&nav.cell_of(*p));
        let walk_ends_on_track = self.state.occupants[occ]
            .walk
            .as_ref()
            .is_none_or(|w| w.path.last().is_none_or(on_track));
        let replanned = if walk_ends_on_track {
            None
        } else {
            let goal = self.state.occupants[occ]
                .walk
                .as_ref()
                .and_then(|w| w.path.last())
                .map(|p| nav.cell_of(*p))
                .expect("a walk to somewhere");
            Some(
                nav.path_to(to, goal, &|_| false)
                    .unwrap_or_default()
                    .iter()
                    .map(|c| nav.centre(*c))
                    .collect::<Vec<Point>>(),
            )
        };
        let room_before = nav.room_at(from).cloned();
        let room_after = nav.room_at(to).cloned();
        let goal_on_track = matches!(
            self.state.occupants[occ].goal,
            Some(Target::Point { pos }) if on_track(&pos)
        );
        let o = self.state.occupants.get_mut(occ).expect("occupant exists");
        let mut at = from;
        for (c, p) in path.iter().zip(&centres) {
            o.facing = facing_of(c.i - at.i, c.j - at.j);
            o.pos = Some(*p);
            o.trail.push(*p);
            at = *c;
        }
        match replanned {
            Some(rest) => {
                if let Some(walk) = o.walk.as_mut() {
                    walk.path = rest;
                    walk.blocked = 0;
                }
            }
            None => {
                o.walk = None;
                if goal_on_track {
                    o.goal = None;
                }
            }
        }
        if walk_ends_on_track || room_before != room_after {
            self.follow_steps(occ, true, false);
        }
        // Pushed aside, it no longer stands where it was using anything.
        crate::interact::end_use(self, occ);
        let from = self.nav_ref().centre(from);
        let to = self.nav_ref().centre(to);
        self.push(Some(occ), EventKind::SteppedAside { from, to });
        true
    }

    // ---- 7. Emit ----

    fn emit_presence(&mut self, t: Tick) {
        let mut changed = Vec::new();
        for (id, o) in self.state.occupants.iter_mut() {
            if matches!(o.location, Location::Away) {
                continue;
            }
            let shown = derive_shown(&o.profile.kind, &o.presence, t);
            if shown != o.shown {
                o.shown = shown;
                changed.push((id.clone(), shown));
            }
        }
        for (id, shown) in changed {
            self.push(Some(&id), EventKind::PresenceChanged { shown });
        }
    }
}

fn fresh(profile: OccupantProfile) -> OccupantState {
    OccupantState {
        profile,
        location: Location::Away,
        presence: PresenceRecord::default(),
        shown: ShownPresence::default(),
        pos: None,
        facing: 0,
        walk: None,
        trail: Vec::new(),
        goal: None,
        using: None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use city_contracts::HumanTier;

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

    /// Puts a public `id` on cell `c` as `location`, standing still there,
    /// and lists it in `room` when it is admitted there.
    fn put(w: &mut World, id: &str, location: Location, c: Cell) {
        let pos = w.nav_ref().centre(c);
        let id = CityId::from(id);
        let mut state = fresh(OccupantProfile {
            id: id.clone(),
            kind: OccupantKind::Human {
                tier: HumanTier::Registered,
            },
            display_name: id.to_string(),
            role: String::new(),
            department: None,
            home: None,
            work: None,
            shared_with: Default::default(),
            appearance: Default::default(),
        });
        if let Location::InRoom { room, .. } = &location {
            w.state
                .rooms
                .get_mut(room)
                .expect("room exists")
                .occupants
                .push(id.clone());
            state.goal = Some(Target::Point { pos });
        }
        state.location = location;
        state.pos = Some(pos);
        w.state.occupants.insert(id, state);
    }

    #[test]
    fn one_on_a_full_rooms_floor_is_never_queued_inside_it_even_with_the_door_held() {
        // `room:a`, made to hold six, is full: its six stand on its side of
        // the door's span, and six more hold the plaza's side. One arriving
        // for it stands on its floor past the span. It cannot be admitted,
        // and it cannot get out: it must not be put in the queue where it
        // stands, which would be inside the room it queues for.
        let mut m = crate::index::fixtures::layout_base();
        m.city.districts[0].facilities[0].rooms[0].capacity = 6;
        let mut w = World::new(m, feed(), 1).expect("valid");
        let (a, p) = (PlaceId::from("room:a"), PlaceId::from("room:p"));
        let span: Vec<Cell> = {
            let nav = w.nav_ref();
            nav.cells_in(&a)
                .into_iter()
                .chain(nav.cells_in(&p))
                .filter(|c| nav.in_door_span(*c))
                .collect()
        };
        assert_eq!(span.len(), 12);
        for (k, c) in span.into_iter().enumerate() {
            let room = w.nav_ref().room_at(c).expect("walkable").clone();
            let location = Location::InRoom { room, seat: None };
            put(&mut w, &format!("person:holder-{k:02}"), location, c);
        }
        assert_eq!(w.state.rooms[&a].occupants.len(), 6, "full");
        let inside = Cell { i: 3, j: 10 };
        put(
            &mut w,
            "person:x",
            Location::Arriving { room: a.clone() },
            inside,
        );
        w.state.admission_queue.push("person:x".into());
        for _ in 0..12 {
            let before = w.snapshot().clone();
            let events = w.step();
            let violations = crate::invariants::check_world(&before, &w, &events);
            assert!(
                violations.is_empty(),
                "tick {}: {violations:?}",
                w.state.tick
            );
            let x = &w.state.occupants[&CityId::from("person:x")];
            assert!(
                !matches!(x.location, Location::Waitlisted { .. }),
                "tick {}: queued inside the room at {:?}",
                w.state.tick,
                x.pos
            );
        }
    }
}
