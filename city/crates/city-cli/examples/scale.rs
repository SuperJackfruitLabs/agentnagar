//! Scale runs: time each tick of a synthetic city, or of the walking
//! district with a crowd.
//!
//! `cargo run -p city-cli --release --example scale [OCCUPANTS...]`
//! (default 100 1000 10000; no layout, 100 ticks), or
//! `... --example scale -- --district [CROWD...]` (default 60 300 1000;
//! the district fixture, one 600-tick day). Timing uses the host clock
//! here, in the tool, never in the core.

use city_contracts::Manifest;
use city_core::{Feed, World, crowd, merge, parse_feed, synthetic};
use std::time::Instant;

fn time(label: &str, n: u32, mut world: World, ticks: usize) {
    let mut micros: Vec<u128> = Vec::with_capacity(ticks);
    let mut events = 0usize;
    for _ in 0..ticks {
        let start = Instant::now();
        events += world.step().len();
        micros.push(start.elapsed().as_micros());
    }
    let mean = micros.iter().sum::<u128>() / ticks as u128;
    let mut sorted = micros.clone();
    sorted.sort_unstable();
    let p95 = sorted[ticks * 95 / 100 - 1];
    let max = *sorted.last().expect("ticks ran");
    println!(
        "{}",
        serde_json::json!({"mode": label, "occupants": n, "ticks": ticks, "events": events,
                           "mean_us": mean as u64, "p95_us": p95 as u64, "max_us": max as u64})
    );
}

fn main() {
    let mut args: Vec<String> = std::env::args().skip(1).collect();
    let district = args.first().is_some_and(|a| a == "--district");
    if district {
        args.remove(0);
    }
    let sizes: Vec<u32> = args
        .iter()
        .map(|a| a.parse().expect("counts are integers"))
        .collect();
    if district {
        let manifest: Manifest =
            serde_json::from_str(include_str!("../../../fixtures/district/manifest.json"))
                .expect("district manifest parses");
        let story: Feed = parse_feed(include_str!("../../../fixtures/district/feed.jsonl"))
            .expect("district feed parses");
        let sizes = if sizes.is_empty() {
            vec![60, 300, 1_000]
        } else {
            sizes
        };
        for n in sizes {
            let feed = merge(story.clone(), crowd(&manifest, n, 1).expect("layout"))
                .expect("both are fixtures");
            let world = World::new(manifest.clone(), feed, 1).expect("district is valid");
            time("district", n, world, 600);
        }
    } else {
        let sizes = if sizes.is_empty() {
            vec![100, 1_000, 10_000]
        } else {
            sizes
        };
        for n in sizes {
            let (manifest, feed) = synthetic(n, 1);
            let world = World::new(manifest, feed, 1).expect("synthetic cities are valid");
            time("synthetic", n, world, 100);
        }
    }
}
