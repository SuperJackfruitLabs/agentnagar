//! A synthetic city for scale runs and tests. Everything it makes is
//! labelled as a fixture.

use crate::feed::Feed;
use city_contracts::{
    Catalogue, City, Command, ConnectionState, District, Door, Facility, FeedEntry, FeedHeader,
    HumanTier, MANIFEST_SCHEMA_VERSION, Manifest, Observation, Observed, OccupantKind,
    OccupantProfile, PlaceId, Pod, ProcessState, Room, SCHEMA_VERSION, Seat, SeatPolicyName, Stamp,
    TaskReport, TaskState, Tick, TickRange,
};
use rand_chacha::ChaCha8Rng;
use rand_core::{Rng, SeedableRng};

const DEPARTMENTS: [&str; 4] = ["making", "knowledge", "civic", "play"];
const ROOMS_PER_FACILITY: usize = 4;

fn between(rng: &mut ChaCha8Rng, lo: u64, hi: u64) -> u64 {
    lo + rng.next_u64() % (hi - lo)
}

fn stamp(at: Tick, expires_at: Tick) -> Stamp {
    Stamp {
        observed_at: at,
        fetched_at: at,
        expires_at,
        source: "fixture:synthetic".into(),
        source_version: "1".into(),
    }
}

/// A city sized for `occupants`, and a fixture feed in which each of them
/// arrives, reports presence, may move once and leaves.
///
/// Kinds cycle every ten occupants: six Guild agents, one city-role agent,
/// one personal agent, one simulated citizen and one human. Personal agents
/// and humans register themselves on arrival; the rest are in the manifest.
pub fn synthetic(occupants: u32, seed: u64) -> (Manifest, Feed) {
    let mut rng = ChaCha8Rng::seed_from_u64(seed);
    let facilities = (occupants as usize / 200).max(1);
    let mut rooms_all = Vec::new();
    let facilities: Vec<Facility> = (0..facilities)
        .map(|f| {
            let ids: Vec<PlaceId> = (0..ROOMS_PER_FACILITY)
                .map(|r| PlaceId::from(format!("room:{f:03}-{r}")))
                .collect();
            let rooms = ids
                .iter()
                .enumerate()
                .map(|(r, id)| {
                    let pods: Vec<Pod> = (0..5)
                        .map(|p| Pod {
                            id: format!("pod:{f:03}-{r}-{p}").into(),
                            department: Some(DEPARTMENTS[(r + p) % DEPARTMENTS.len()].into()),
                        })
                        .collect();
                    let seats = (0..50)
                        .map(|s| Seat {
                            id: format!("seat:{f:03}-{r}-{s:02}").into(),
                            pod: Some(pods[s / 10].id.clone()),
                            ..Default::default()
                        })
                        .collect();
                    let mut doors = Vec::new();
                    for (label, other) in [("next", r + 1), ("prev", r.wrapping_sub(1))] {
                        if let Some(to) = ids.get(other) {
                            doors.push(Door {
                                id: format!("door:{f:03}-{r}-{label}").into(),
                                to: to.clone(),
                                transit: TickRange { min: 1, max: 4 },
                                ..Default::default()
                            });
                        }
                    }
                    Room {
                        id: id.clone(),
                        name: format!("Room {f}-{r}"),
                        capacity: 60,
                        pods,
                        seats,
                        overflow: ids.get(r + 1).cloned(),
                        doors,
                        ..Default::default()
                    }
                })
                .collect();
            rooms_all.extend(ids);
            Facility {
                id: format!("facility:{f:03}").into(),
                name: format!("Facility {f}"),
                rooms,
                ..Default::default()
            }
        })
        .collect();

    let mut profiles = Vec::new();
    let mut manifest_occupants = Vec::new();
    for i in 0..occupants {
        let (id, kind) = match i % 10 {
            0..=5 => (format!("agent:{i:05}"), OccupantKind::GuildAgent),
            6 => (format!("role:{i:05}"), OccupantKind::CityRoleAgent),
            7 => (
                format!("pa:{i:05}"),
                OccupantKind::PersonalAgent {
                    owner: "person:00009".into(),
                },
            ),
            8 => (format!("sim:{i:05}"), OccupantKind::SimCitizen),
            _ => {
                let tier = [
                    HumanTier::Observer,
                    HumanTier::Registered,
                    HumanTier::Resident,
                ][(i / 10) as usize % 3];
                (format!("person:{i:05}"), OccupantKind::Human { tier })
            }
        };
        let work = rooms_all[(rng.next_u64() % rooms_all.len() as u64) as usize].clone();
        let profile = OccupantProfile {
            id: id.into(),
            kind,
            display_name: format!("Occupant {i}"),
            role: String::new(),
            department: Some(DEPARTMENTS[i as usize % DEPARTMENTS.len()].into()),
            home: None,
            work: Some(work),
            shared_with: Default::default(),
            appearance: Default::default(),
        };
        let registers_on_arrival = matches!(
            profile.kind,
            OccupantKind::PersonalAgent { .. } | OccupantKind::Human { .. }
        );
        if !registers_on_arrival {
            manifest_occupants.push(profile.clone());
        }
        profiles.push((profile, registers_on_arrival));
    }

    let mut entries: Vec<FeedEntry> = Vec::new();
    let entry = |at: Tick, command: Command| FeedEntry {
        at,
        fixture: true,
        command,
    };
    for (profile, registers) in &profiles {
        let id = profile.id.clone();
        let at = between(&mut rng, 0, 20);
        entries.push(entry(
            at,
            Command::Arrive {
                occupant: id.clone(),
                profile: registers.then(|| profile.clone()),
                room: None,
                player: false,
            },
        ));
        if matches!(profile.kind, OccupantKind::Human { .. }) {
            let exp = at + between(&mut rng, 10, 60);
            entries.push(entry(
                at,
                Command::Observe {
                    occupant: id.clone(),
                    observation: Observation::Connection(Observed {
                        value: ConnectionState::Connected,
                        stamp: stamp(at, exp),
                    }),
                },
            ));
        } else {
            let exp = at + between(&mut rng, 10, 60);
            entries.push(entry(
                at,
                Command::Observe {
                    occupant: id.clone(),
                    observation: Observation::Process(Observed {
                        value: ProcessState::Running,
                        stamp: stamp(at, exp),
                    }),
                },
            ));
            if rng.next_u64() % 5 != 0 {
                let state = [TaskState::Working, TaskState::Idle, TaskState::Waiting]
                    [(rng.next_u64() % 3) as usize];
                let exp = at + between(&mut rng, 5, 40);
                entries.push(entry(
                    at,
                    Command::Observe {
                        occupant: id.clone(),
                        observation: Observation::Task(Observed {
                            value: TaskReport {
                                state,
                                summary: Some(format!("synthetic task for {id}")),
                                summary_public: false,
                            },
                            stamp: stamp(at, exp),
                        }),
                    },
                ));
            }
        }
        if rng.next_u64() % 4 == 0 {
            let work = profile
                .work
                .as_ref()
                .expect("synthetic occupants have work");
            let r: usize = work
                .as_str()
                .rsplit('-')
                .next()
                .and_then(|n| n.parse().ok())
                .unwrap_or(0);
            let neighbour = if r + 1 < ROOMS_PER_FACILITY {
                r + 1
            } else {
                r - 1
            };
            let prefix = work
                .as_str()
                .rsplit_once('-')
                .map(|(p, _)| p)
                .unwrap_or_default();
            entries.push(entry(
                at + between(&mut rng, 2, 10),
                Command::Move {
                    occupant: id.clone(),
                    to: format!("{prefix}-{neighbour}").into(),
                },
            ));
        }
        entries.push(entry(
            between(&mut rng, 40, 80),
            Command::Depart {
                occupant: id,
                player: false,
            },
        ));
    }
    entries.sort_by_key(|e| e.at);

    let manifest = Manifest {
        weather: None,
        lines: Vec::new(),
        schema_version: MANIFEST_SCHEMA_VERSION,
        city: City {
            id: "city:synthetic".into(),
            name: "Synthetic city".into(),
            districts: vec![District {
                id: "district:synthetic".into(),
                name: "Synthetic district".into(),
                facilities,
                placements: Vec::new(),
            }],
            ..Default::default()
        },
        seat_policy: SeatPolicyName::DepartmentFirst,
        occupants: manifest_occupants,
        clock: None,
        scenery: Vec::new(),
        catalogue: Some(Catalogue::builtin().version),
    };
    let feed = Feed {
        header: FeedHeader {
            schema_version: SCHEMA_VERSION,
            source: "fixture:synthetic".into(),
            fixture: true,
            description: format!(
                "Synthetic fixture: {occupants} occupants, seed {seed}. Not real agent state."
            ),
        },
        entries,
    };
    (manifest, feed)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn synthetic_is_valid_and_deterministic() {
        let (m, f) = synthetic(250, 3);
        assert!(
            crate::index::validate(&m).valid,
            "{:?}",
            crate::index::validate(&m)
        );
        assert!(f.header.fixture);
        assert_eq!(synthetic(250, 3).1.entries, f.entries);
        assert_eq!(m.city.districts[0].facilities.len(), 1);
        assert_eq!(m.occupants.len(), 250 - 250 / 10 * 2);
        assert!(f.entries.windows(2).all(|w| w[0].at <= w[1].at));
    }

    #[test]
    fn synthetic_scales_facilities() {
        let (m, _) = synthetic(1000, 1);
        assert_eq!(m.city.districts[0].facilities.len(), 5);
    }
}
