//! Versioned data contracts for the Agentnagar city world core.
//!
//! Every type here is plain data with `serde` and JSON Schema derives. The
//! rules live in `city-core`; this crate only says what crosses a boundary.

mod catalogue;
mod event;
mod feed;
mod ids;
mod manifest;
mod occupant;
mod panel;
mod presence;
mod projection;
mod report;
mod snapshot;

pub use catalogue::*;
pub use event::*;
pub use feed::*;
pub use ids::*;
pub use manifest::*;
pub use occupant::*;
pub use panel::*;
pub use presence::*;
pub use projection::*;
pub use report::*;
pub use snapshot::*;

use std::collections::BTreeMap;

pub(crate) fn is_zero(v: &i32) -> bool {
    *v == 0
}

pub(crate) fn is_false(v: &bool) -> bool {
    !*v
}

/// The version every contract in this crate carries, but the manifest.
pub const SCHEMA_VERSION: u32 = 1;

/// The manifest's version. Schema 2 lays everything solid out as district
/// placements; schema 1's room obstacles and props, facility exteriors,
/// and tree-row and block scenery are gone.
pub const MANIFEST_SCHEMA_VERSION: u32 = 2;

/// JSON Schema for every contract, keyed by contract name.
pub fn all_schemas() -> BTreeMap<String, serde_json::Value> {
    let mut m = BTreeMap::new();
    let mut put = |k: &str, s: schemars::Schema| {
        m.insert(k.to_string(), s.to_value());
    };
    put("catalogue", schemars::schema_for!(Catalogue));
    put("manifest", schemars::schema_for!(Manifest));
    put("feed-record", schemars::schema_for!(FeedRecord));
    put("command", schemars::schema_for!(Command));
    put("event", schemars::schema_for!(Event));
    put("snapshot", schemars::schema_for!(Snapshot));
    put("viewer", schemars::schema_for!(Viewer));
    put("projection", schemars::schema_for!(Projection));
    put("snapshot-diff", schemars::schema_for!(SnapshotDiff));
    put("validation-report", schemars::schema_for!(ValidationReport));
    put("run-summary", schemars::schema_for!(RunSummary));
    put("vehicle-detail", schemars::schema_for!(VehicleDetail));
    put("panel", schemars::schema_for!(Panel));
    m
}
