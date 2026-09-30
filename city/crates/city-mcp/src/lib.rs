//! The city operations as MCP tools. Every tool calls the same function as
//! the `city` command line, so the two interfaces cannot disagree.

use city_cli::commands::{self, CheckPlacementArgs, InspectArgs, Outcome, RunArgs, Status};
use city_contracts::Placement;
use rmcp::handler::server::wrapper::Parameters;
use rmcp::model::{CallToolResult, ContentBlock};
use rmcp::{schemars, tool, tool_handler, tool_router};
use serde::Deserialize;
use std::path::PathBuf;

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct ValidateParams {
    /// Path to a place manifest (JSON)
    pub manifest_path: PathBuf,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct RunParams {
    /// Path to a place manifest (JSON)
    pub manifest_path: PathBuf,
    /// Path to a presence feed (JSON Lines)
    pub feed_path: PathBuf,
    /// Seed for the world's random number generator
    pub seed: u64,
    /// Number of ticks to run (at least 1)
    pub ticks: u64,
    /// Also write a snapshot every K ticks
    #[serde(default)]
    pub snapshot_every: Option<u64>,
    /// Output directory; nothing is written outside it
    pub out_dir: PathBuf,
    /// Add a generated fixture crowd of this many occupants (needs a layout)
    #[serde(default)]
    pub crowd: u32,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct InspectParams {
    /// Path to a snapshot written by `run`
    pub snapshot_path: PathBuf,
    /// `public` (default), `operator`, or a person's city ID
    #[serde(default)]
    pub viewer: Option<String>,
    /// Must be true to use the operator viewer
    #[serde(default)]
    pub operator: bool,
    /// Return only this room
    #[serde(default)]
    pub room: Option<String>,
    /// Return only this occupant
    #[serde(default)]
    pub occupant: Option<String>,
    /// Return only this vehicle, with the riders aboard it this viewer may
    /// see
    #[serde(default)]
    pub vehicle: Option<String>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct DiffParams {
    /// The earlier snapshot
    pub a_path: PathBuf,
    /// The later snapshot
    pub b_path: PathBuf,
    /// Must be true: snapshots hold full state
    #[serde(default)]
    pub operator: bool,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct SchemaParams {
    /// Also write `<name>.schema.json` files into this directory
    #[serde(default)]
    pub out_dir: Option<PathBuf>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct CatalogueParams {
    /// Return only this kind's JSON, instead of every kind as a table
    #[serde(default)]
    pub kind: Option<String>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct CheckPlacementParams {
    /// Path to a place manifest (JSON)
    pub manifest_path: PathBuf,
    /// The placement to validate; never written to the manifest
    pub placement: Placement,
}

fn respond(outcome: Outcome) -> CallToolResult {
    let body = serde_json::to_string_pretty(&outcome.body).expect("JSON body serialises");
    match outcome.status {
        Status::Ok => CallToolResult::success(vec![ContentBlock::text(body)]),
        Status::Failed | Status::BadInput => CallToolResult::error(vec![ContentBlock::text(body)]),
    }
}

#[derive(Debug, Clone, Default)]
pub struct CityServer;

impl CityServer {
    pub fn new() -> Self {
        Self
    }
}

#[tool_router]
impl CityServer {
    #[tool(description = "Check a place manifest against its schema and structural rules.")]
    fn validate(&self, Parameters(p): Parameters<ValidateParams>) -> CallToolResult {
        respond(commands::validate(&p.manifest_path))
    }

    #[tool(
        description = "Run the city world headless from a manifest, a fixture feed and a seed. Writes events.jsonl, snapshots, final.json and summary.json inside out_dir only."
    )]
    fn run(&self, Parameters(p): Parameters<RunParams>) -> CallToolResult {
        respond(commands::run(&RunArgs {
            manifest: p.manifest_path,
            feed: p.feed_path,
            seed: p.seed,
            ticks: p.ticks,
            snapshot_every: p.snapshot_every,
            out: p.out_dir,
            crowd: p.crowd,
        }))
    }

    #[tool(
        description = "Read a viewer's projection of a snapshot, or one room, occupant or vehicle in it; a vehicle comes with the riders aboard it that the viewer may see. The operator viewer requires operator: true."
    )]
    fn inspect(&self, Parameters(p): Parameters<InspectParams>) -> CallToolResult {
        respond(commands::inspect(&InspectArgs {
            snapshot: p.snapshot_path,
            viewer: p.viewer.unwrap_or_else(|| "public".into()),
            operator: p.operator,
            room: p.room,
            occupant: p.occupant,
            vehicle: p.vehicle,
        }))
    }

    #[tool(
        description = "Compare two snapshots and report what changed. Snapshots hold full state, so this requires operator: true."
    )]
    fn diff(&self, Parameters(p): Parameters<DiffParams>) -> CallToolResult {
        respond(commands::diff(&p.a_path, &p.b_path, p.operator))
    }

    #[tool(description = "Export JSON Schema for every city contract.")]
    fn schema(&self, Parameters(p): Parameters<SchemaParams>) -> CallToolResult {
        respond(commands::schema(p.out_dir.as_deref()))
    }

    #[tool(
        description = "List the built-in catalogue's kinds as a table, or, with kind, that one kind's full JSON."
    )]
    fn catalogue(&self, Parameters(p): Parameters<CatalogueParams>) -> CallToolResult {
        respond(commands::catalogue(p.kind.as_deref()))
    }

    #[tool(
        description = "Validate a proposed placement against a manifest without writing it. Loads the manifest into a world, submits the placement as the operator and steps once: PlacementChanged gives ok: true and the cells it changed (changed_cells); Rejected gives ok: false and the core's reason."
    )]
    fn check_placement(&self, Parameters(p): Parameters<CheckPlacementParams>) -> CallToolResult {
        respond(commands::check_placement(&CheckPlacementArgs {
            manifest: p.manifest_path,
            placement: p.placement,
        }))
    }
}

#[tool_handler(
    name = "agentnagar-city",
    version = "0.1.0",
    instructions = "Run and inspect the Agentnagar city world core. Every feed declares whether it is a fixture, and every event carries that flag; the core itself fetches nothing and reads only the files it is given."
)]
impl rmcp::ServerHandler for CityServer {}
