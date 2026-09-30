//! A synthetic crowd over any manifest with a layout. Every entry it makes
//! is labelled as a fixture.

use crate::feed::Feed;
use crate::project::time_of_day;
use city_contracts::{
    CityId, Clock, Command, ConnectionState, FeedEntry, FeedHeader, HumanTier, Manifest,
    Observation, Observed, OccupantKind, OccupantProfile, PlaceId, ProcessState, SCHEMA_VERSION,
    Stamp, TaskReport, TaskState, Tick,
};
use rand_chacha::ChaCha8Rng;
use rand_core::{Rng, SeedableRng};
use std::collections::BTreeMap;

const DEFAULT_CLOCK: Clock = Clock {
    ticks_per_day: 600,
    start_minute: 420,
};

fn between(rng: &mut ChaCha8Rng, lo: u64, hi: u64) -> u64 {
    lo + rng.next_u64() % (hi - lo)
}

/// Rooms suited to the time of day: a café at lunch, the reading room or
/// the park in the afternoon, the square, commons or park otherwise.
fn preferred(minute: u32) -> &'static [&'static str] {
    match minute / 60 {
        11..=13 => &["cafe", "cafe-terrace"],
        14..=17 => &["reading-room", "park"],
        _ => &["plaza", "commons", "park"],
    }
}

fn stamp(at: Tick, expires_at: Tick) -> Stamp {
    Stamp {
        observed_at: at,
        fetched_at: at,
        expires_at,
        source: "fixture:crowd".into(),
        source_version: "1".into(),
    }
}

/// A crowd of `count` occupants coming and going through the entrances over
/// one day. Kinds cycle every twenty: twelve simulated citizens, four
/// registered people, two residents, one anonymous observer and one private
/// agent owned by the person before it.
pub fn crowd(manifest: &Manifest, count: u32, seed: u64) -> Result<Feed, String> {
    if !manifest.has_layout() {
        return Err("a crowd needs a manifest with a layout".into());
    }
    let clock = manifest.clock.unwrap_or(DEFAULT_CLOCK);
    let mut by_template: BTreeMap<String, Vec<PlaceId>> = BTreeMap::new();
    let mut all_rooms = Vec::new();
    for r in manifest
        .city
        .districts
        .iter()
        .flat_map(|d| &d.facilities)
        .flat_map(|f| &f.rooms)
    {
        all_rooms.push(r.id.clone());
        if let Some(t) = &r.template {
            by_template.entry(t.clone()).or_default().push(r.id.clone());
        }
    }
    let fallback = by_template
        .get("plaza")
        .and_then(|v| v.first().cloned())
        .or_else(|| all_rooms.first().cloned())
        .ok_or("the manifest has no rooms")?;
    let mut rng = ChaCha8Rng::seed_from_u64(seed ^ 0xC20D);
    let pick = |rng: &mut ChaCha8Rng, tick: Tick, avoid: Option<&PlaceId>| -> PlaceId {
        let options: Vec<&PlaceId> = preferred(time_of_day(clock, tick))
            .iter()
            .filter_map(|t| by_template.get(*t))
            .flatten()
            .filter(|r| Some(*r) != avoid)
            .collect();
        match options.len() {
            0 => fallback.clone(),
            n => options[(rng.next_u64() % n as u64) as usize].clone(),
        }
    };

    let day = u64::from(clock.ticks_per_day.max(1));
    let mut entries: Vec<FeedEntry> = Vec::new();
    let mut push = |at: Tick, command: Command| {
        entries.push(FeedEntry {
            at,
            fixture: true,
            command,
        })
    };
    for i in 0..count {
        let id = CityId::from(format!("crowd:{i:04}"));
        let kind = match i % 20 {
            0..=11 => OccupantKind::SimCitizen,
            12..=15 => OccupantKind::Human {
                tier: HumanTier::Registered,
            },
            16..=17 => OccupantKind::Human {
                tier: HumanTier::Resident,
            },
            18 => OccupantKind::Human {
                tier: HumanTier::Observer,
            },
            _ => OccupantKind::PersonalAgent {
                owner: format!("crowd:{:04}", i - 1).into(),
            },
        };
        let mut appearance = BTreeMap::new();
        appearance.insert("palette".to_string(), (rng.next_u64() % 8).to_string());
        appearance.insert("hair".to_string(), (rng.next_u64() % 4).to_string());
        let at = rng.next_u64() % day;
        let stay = between(&mut rng, 60, 300);
        let room = pick(&mut rng, at, None);
        let profile = OccupantProfile {
            id: id.clone(),
            kind: kind.clone(),
            display_name: format!("Visitor {i}"),
            role: String::new(),
            department: None,
            home: None,
            work: None,
            shared_with: Default::default(),
            appearance,
        };
        push(
            at,
            Command::Arrive {
                occupant: id.clone(),
                profile: Some(profile),
                room: Some(room.clone()),
                player: false,
            },
        );
        let leave = at + stay;
        match kind {
            OccupantKind::Human { .. } => push(
                at,
                Command::Observe {
                    occupant: id.clone(),
                    observation: Observation::Connection(Observed {
                        value: ConnectionState::Connected,
                        stamp: stamp(at, leave + 10),
                    }),
                },
            ),
            OccupantKind::PersonalAgent { .. } => {
                push(
                    at,
                    Command::Observe {
                        occupant: id.clone(),
                        observation: Observation::Process(Observed {
                            value: ProcessState::Running,
                            stamp: stamp(at, leave + 10),
                        }),
                    },
                );
                push(
                    at,
                    Command::Observe {
                        occupant: id.clone(),
                        observation: Observation::Task(Observed {
                            value: TaskReport {
                                state: TaskState::Working,
                                summary: Some(format!("Errand for crowd:{:04}", i - 1)),
                                summary_public: false,
                            },
                            stamp: stamp(at, leave + 10),
                        }),
                    },
                );
            }
            _ => {}
        }
        if rng.next_u64() % 2 == 0 {
            let midway = at + stay / 2;
            let to = pick(&mut rng, midway, Some(&room));
            if to != room {
                push(
                    midway,
                    Command::Move {
                        occupant: id.clone(),
                        to,
                    },
                );
            }
        }
        push(
            leave,
            Command::Depart {
                occupant: id,
                player: false,
            },
        );
    }
    entries.sort_by_key(|e| e.at);
    Ok(Feed {
        header: FeedHeader {
            schema_version: SCHEMA_VERSION,
            source: "fixture:crowd".into(),
            fixture: true,
            description: format!("Synthetic crowd of {count}, seed {seed}. Not real agent state."),
        },
        entries,
    })
}

/// Both feeds' entries in tick order, `a`'s first on ties, under `a`'s
/// header. A fixture feed never merges with a real one.
pub fn merge(a: Feed, b: Feed) -> Result<Feed, String> {
    if a.header.fixture != b.header.fixture {
        return Err("a fixture feed cannot be merged with a real feed".into());
    }
    let mut entries = a.entries;
    entries.extend(b.entries);
    entries.sort_by_key(|e| e.at);
    Ok(Feed {
        header: a.header,
        entries,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::index::fixtures::layout_base;

    #[test]
    fn crowd_is_deterministic_and_fixture_labelled() {
        let m = layout_base();
        let a = crowd(&m, 40, 7).unwrap();
        assert_eq!(a.entries, crowd(&m, 40, 7).unwrap().entries);
        assert_ne!(a.entries, crowd(&m, 40, 8).unwrap().entries);
        assert!(a.header.fixture && a.entries.iter().all(|e| e.fixture));
        assert!(a.entries.windows(2).all(|w| w[0].at <= w[1].at));
        let arrivals = a
            .entries
            .iter()
            .filter(|e| matches!(e.command, Command::Arrive { .. }))
            .count();
        assert_eq!(arrivals, 40);
    }

    #[test]
    fn crowd_needs_a_layout() {
        let mut m = layout_base();
        for r in m.city.districts[0]
            .facilities
            .iter_mut()
            .flat_map(|f| f.rooms.iter_mut())
        {
            r.rect = None;
        }
        assert!(crowd(&m, 5, 1).is_err());
    }

    #[test]
    fn crowd_mixes_kinds_with_private_agents_owned_by_people() {
        let f = crowd(&layout_base(), 40, 3).unwrap();
        let kinds: Vec<OccupantKind> = f
            .entries
            .iter()
            .filter_map(|e| match &e.command {
                Command::Arrive {
                    profile: Some(p), ..
                } => Some(p.kind.clone()),
                _ => None,
            })
            .collect();
        assert_eq!(kinds.len(), 40);
        assert!(
            kinds
                .iter()
                .filter(|k| matches!(k, OccupantKind::SimCitizen))
                .count()
                >= 20
        );
        assert!(kinds.iter().any(|k| matches!(
            k,
            OccupantKind::Human {
                tier: HumanTier::Observer
            }
        )));
        assert!(kinds.iter().any(|k| matches!(k, OccupantKind::PersonalAgent { owner } if owner.as_str().starts_with("crowd:"))));
    }

    #[test]
    fn merge_keeps_the_first_feed_first_on_ties() {
        let m = layout_base();
        let a = crowd(&m, 3, 1).unwrap();
        let b = crowd(&m, 3, 2).unwrap();
        let merged = merge(a.clone(), b.clone()).unwrap();
        assert_eq!(merged.entries.len(), a.entries.len() + b.entries.len());
        assert!(merged.entries.windows(2).all(|w| w[0].at <= w[1].at));
        assert_eq!(merged.header, a.header);
        let mut real = b;
        real.header.fixture = false;
        assert!(merge(a, real).is_err(), "fixture and real feeds never mix");
    }
}
