//! Stable identifiers and simulation time.

use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use std::fmt;

/// Simulation time: a count of fixed ticks, never the host clock.
pub type Tick = u64;

macro_rules! id_type {
    ($(#[$doc:meta])* $name:ident) => {
        $(#[$doc])*
        #[derive(
            Debug, Clone, Default, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize, JsonSchema,
        )]
        #[serde(transparent)]
        pub struct $name(pub String);

        impl $name {
            pub fn as_str(&self) -> &str {
                &self.0
            }
        }

        impl From<&str> for $name {
            fn from(s: &str) -> Self {
                Self(s.to_string())
            }
        }

        impl From<String> for $name {
            fn from(s: String) -> Self {
                Self(s)
            }
        }

        impl fmt::Display for $name {
            fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
                f.write_str(&self.0)
            }
        }
    };
}

id_type!(
    /// An entity's stable city ID, such as `agent:coder-kai`. It never changes
    /// when the entity's runtime changes and never contains a runtime identifier.
    CityId
);
id_type!(
    /// A stable ID for a node in the place tree: city, district, facility,
    /// room, pod, seat or door.
    PlaceId
);
