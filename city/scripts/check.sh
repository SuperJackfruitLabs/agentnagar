#!/usr/bin/env bash
# Every check the city workspace must pass: formatting, lints, tests, the
# WebAssembly build of the pure core, the release-only scale gate, the
# district fixture against its generator, the third-party notices against
# Cargo.lock and the bundled fonts, the style kits' tests, the
# packaging and bench scripts' logic and, when Godot is installed, the client's headless tests against
# a freshly built extension and the frame-rate benchmark.
set -euo pipefail
cd "$(dirname "$0")/.."
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
cargo build -p city-core --target wasm32-unknown-unknown
cargo test --release -p city-core -- --ignored scale_district
python3 fixtures/district/generate.py --check
python3 scripts/third_party_notices.py --check
for t in tools/styles/*/test_*.py; do
    python3 -m unittest "$t"
done
scripts/test_package.sh
scripts/test_bench.sh
if command -v godot >/dev/null 2>&1; then
    scripts/build-godot.sh
    godot --headless --path godot --import --quit >/dev/null 2>&1 || true
    godot --headless --path godot --script res://tests/run_all.gd
    scripts/bench.sh
else
    echo "city: godot not found; skipping the client tests"
fi
echo "city: all checks passed"
