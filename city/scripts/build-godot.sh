#!/usr/bin/env bash
# Builds the city Godot extension for this Linux x86_64 machine and places it
# where the client loads it (see godot/city.gdextension). Other platforms are
# built by scripts/package.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
cargo build -p city-godot --release
mkdir -p godot/bin
cp target/release/libcity_godot.so godot/bin/libcity_godot.linux.x86_64.so
echo "city: extension built into godot/bin/"
