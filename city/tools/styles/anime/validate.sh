#!/usr/bin/env bash
# Validates every anime GLB with the pinned Khronos validator (installed
# with: npm ci --prefix prototypes/voxel-work-bay/tools). Fails on any error
# or warning.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../../.." && pwd)"
REPO="$repo" node - "$here/../../../godot/styles/anime_cel/assets" <<'JS'
const fs = require('node:fs');
const path = require('node:path');
const repo = process.env.REPO;
const validator = require(require.resolve('gltf-validator', {paths: [path.join(repo, 'prototypes/voxel-work-bay/tools')]}));
const dir = process.argv[2];
(async () => {
  const files = fs.readdirSync(dir).filter(n => n.endsWith('.glb')).sort();
  if (!files.length) throw new Error('no GLBs in ' + dir);
  let bad = 0;
  for (const name of files) {
    const report = await validator.validateBytes(new Uint8Array(fs.readFileSync(path.join(dir, name))), {uri: name});
    const {numErrors, numWarnings} = report.issues;
    if (numErrors || numWarnings) {
      bad += 1;
      console.log(`${name}: ${numErrors} errors, ${numWarnings} warnings`);
      for (const m of report.issues.messages.slice(0, 5)) console.log('  ', m.code, m.message);
    }
  }
  console.log(`${files.length} GLBs checked, ${bad} with issues`);
  process.exitCode = bad ? 1 : 0;
})().catch(e => { console.error(e); process.exitCode = 1; });
JS
