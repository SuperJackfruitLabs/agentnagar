//! Tool outputs: validation reports, snapshot diffs and run summaries.

use crate::{CityId, Location, ShownPresence, Tick};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ValidationIssue {
    pub code: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub place: Option<String>,
    pub message: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ValidationReport {
    pub valid: bool,
    pub issues: Vec<ValidationIssue>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct SnapshotDiff {
    pub from_tick: Tick,
    pub to_tick: Tick,
    pub changes: Vec<Change>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "type")]
pub enum Change {
    OccupantAdded {
        occupant: CityId,
    },
    LocationChanged {
        occupant: CityId,
        from: Location,
        to: Location,
    },
    PresenceChanged {
        occupant: CityId,
        from: ShownPresence,
        to: ShownPresence,
    },
    ProfileChanged {
        occupant: CityId,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct RunSummary {
    pub schema_version: u32,
    pub seed: u64,
    pub ticks: Tick,
    pub fixture: bool,
    pub events: u64,
    pub rejected: u64,
    /// Occupants present at the end of the run.
    pub present: u64,
    /// Snapshot files written, relative to the output directory.
    pub snapshots: Vec<String>,
}
