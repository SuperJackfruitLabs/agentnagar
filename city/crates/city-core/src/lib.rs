//! The pure, deterministic rules of the Agentnagar city world.
//!
//! No file, network, clock, thread or environment use: the same core runs on
//! a server, in WebAssembly or inside a test.

pub mod crowd;
pub mod diff;
pub mod feed;
pub mod footprint;
pub mod index;
pub mod interact;
pub mod invariants;
pub mod nav;
pub mod placement;
pub mod policy;
pub mod presence;
pub mod project;
pub mod synth;
pub mod transit;
pub mod walk;
pub mod world;

pub use crowd::{crowd, merge};
pub use diff::diff;
pub use feed::{Feed, FeedError, parse_feed};
pub use index::{PlaceIndex, validate};
pub use policy::choose_seat;
pub use presence::{apply_observation, derive_shown, is_expired};
pub use project::{project, visible};
pub use synth::synthetic;
pub use world::World;
