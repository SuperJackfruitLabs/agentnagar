//! `city`: run and inspect the city world core from the command line.
//! Prints JSON on standard output; exits 0 on success, 1 on a domain
//! failure and 2 on bad input.

use city_cli::commands::{self, GridArgs, InspectArgs, PlaceArgs, RunArgs};
use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser)]
#[command(
    name = "city",
    version,
    about = "Run and inspect the Agentnagar city world core"
)]
struct Cli {
    #[command(subcommand)]
    command: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Check a manifest against its schema and structural rules
    Validate { manifest: PathBuf },
    /// Run headless; write the event log, snapshots and a summary
    Run {
        #[arg(long)]
        manifest: PathBuf,
        #[arg(long)]
        feed: PathBuf,
        #[arg(long)]
        seed: u64,
        #[arg(long)]
        ticks: u64,
        /// Also write a snapshot every K ticks
        #[arg(long)]
        snapshot_every: Option<u64>,
        /// Output directory; nothing is written outside it
        #[arg(long)]
        out: PathBuf,
        /// Add a generated fixture crowd of N occupants (needs a layout)
        #[arg(long, default_value_t = 0)]
        crowd: u32,
    },
    /// Read a viewer's projection of a snapshot, or one room, occupant or
    /// vehicle
    Inspect {
        snapshot: PathBuf,
        /// public, operator, or a person's city ID
        #[arg(long, default_value = "public")]
        viewer: String,
        /// Required for the operator viewer
        #[arg(long)]
        operator: bool,
        #[arg(long, conflicts_with_all = ["occupant", "vehicle"])]
        room: Option<String>,
        #[arg(long, conflicts_with = "vehicle")]
        occupant: Option<String>,
        /// A vehicle, with the riders aboard it this viewer may see
        #[arg(long)]
        vehicle: Option<String>,
    },
    /// Compare two snapshots (full state: needs --operator)
    Diff {
        a: PathBuf,
        b: PathBuf,
        /// Required: snapshots hold full state
        #[arg(long)]
        operator: bool,
    },
    /// Export JSON Schema for every contract
    Schema {
        #[arg(long)]
        out: Option<PathBuf>,
    },
    /// List the built-in catalogue's kinds, or one kind's JSON
    Catalogue {
        #[arg(long)]
        kind: Option<String>,
    },
    /// The walkable grid's cell, walkable and blocked-by-kind counts
    Grid {
        manifest: PathBuf,
        /// Also render the grid, 1 px per cell, to this PNG file
        #[arg(long)]
        png: Option<PathBuf>,
    },
    /// Validate a placement on a manifest, and print the result
    Place {
        manifest: PathBuf,
        #[arg(long)]
        kind: String,
        /// "x,z", in centimetres
        #[arg(long)]
        at: String,
        #[arg(long, default_value_t = 0)]
        facing: i32,
        /// "w,d", in centimetres; only for a sized kind
        #[arg(long)]
        size: Option<String>,
        /// Defaults to `placement:<kind>-<x>-<z>`
        #[arg(long)]
        id: Option<String>,
        /// Once accepted, rewrite the manifest with the placement added, in
        /// canonical form (contract field order; defaults omitted or
        /// filled as the contract serialises them). A hand-edited manifest
        /// will show a reformatting diff.
        #[arg(long)]
        write: bool,
    },
}

fn main() {
    let outcome = match Cli::parse().command {
        Cmd::Validate { manifest } => commands::validate(&manifest),
        Cmd::Run {
            manifest,
            feed,
            seed,
            ticks,
            snapshot_every,
            out,
            crowd,
        } => commands::run(&RunArgs {
            manifest,
            feed,
            seed,
            ticks,
            snapshot_every,
            out,
            crowd,
        }),
        Cmd::Inspect {
            snapshot,
            viewer,
            operator,
            room,
            occupant,
            vehicle,
        } => commands::inspect(&InspectArgs {
            snapshot,
            viewer,
            operator,
            room,
            occupant,
            vehicle,
        }),
        Cmd::Diff { a, b, operator } => commands::diff(&a, &b, operator),
        Cmd::Schema { out } => commands::schema(out.as_deref()),
        Cmd::Catalogue { kind } => commands::catalogue(kind.as_deref()),
        Cmd::Grid { manifest, png } => commands::grid(&GridArgs { manifest, png }),
        Cmd::Place {
            manifest,
            kind,
            at,
            facing,
            size,
            id,
            write,
        } => commands::place(&PlaceArgs {
            manifest,
            kind,
            at,
            facing,
            size,
            id,
            write,
        }),
    };
    println!(
        "{}",
        serde_json::to_string_pretty(&outcome.body).expect("JSON body serialises")
    );
    std::process::exit(outcome.status.exit_code());
}
