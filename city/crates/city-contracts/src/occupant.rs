//! Occupants: anything that can be present in a place.

use crate::{CityId, PlaceId};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct OccupantProfile {
    pub id: CityId,
    pub kind: OccupantKind,
    pub display_name: String,
    #[serde(default)]
    pub role: String,
    #[serde(default)]
    pub department: Option<String>,
    #[serde(default)]
    pub home: Option<PlaceId>,
    #[serde(default)]
    pub work: Option<PlaceId>,
    /// People a personal agent is shared with. Ignored for other kinds.
    #[serde(default)]
    pub shared_with: BTreeSet<CityId>,
    /// Opaque to the core; a style pack interprets it.
    #[serde(default)]
    pub appearance: BTreeMap<String, String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "type")]
pub enum OccupantKind {
    GuildAgent,
    CityRoleAgent,
    /// Visible only to its owner and those it is shared with (RD12).
    PersonalAgent {
        owner: CityId,
    },
    /// Scenery and routines; never counted as attendance.
    SimCitizen,
    Human {
        tier: HumanTier,
    },
}

impl OccupantKind {
    pub fn is_agent(&self) -> bool {
        matches!(
            self,
            Self::GuildAgent | Self::CityRoleAgent | Self::PersonalAgent { .. }
        )
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub enum HumanTier {
    Observer,
    Registered,
    Resident,
}
