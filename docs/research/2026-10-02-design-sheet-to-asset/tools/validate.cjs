// validate.cjs FILE.glb [...]: the pinned Khronos validator (the kits' own: gltf-validator 2.0.0-dev.3.10) on
// each file; the kit tests fail a file on any error or warning. The validator is looked for in
// scratch/validator/node_modules (npm ci there from the checkout's prototypes/voxel-work-bay/tools/package*.json)
// and then in the checkout. Prints one line a file; exit 1 if any has an error or a warning.
const fs = require('node:fs');
const path = require('node:path');
const here = path.resolve(__dirname, '..');
const places = [path.join(here, 'scratch', 'validator')];
if (process.env.AGENTNAGAR) places.push(path.join(process.env.AGENTNAGAR, 'prototypes/voxel-work-bay/tools'));
let validator;
try {
  validator = require(require.resolve('gltf-validator', {paths: places}));
} catch (e) {
  console.log('validator not installed (looked in ' + places.join(', ') + ')');
  process.exit(2);
}
(async () => {
  let bad = 0;
  for (const file of process.argv.slice(2)) {
    const report = await validator.validateBytes(new Uint8Array(fs.readFileSync(file)), {uri: path.basename(file)});
    const {numErrors, numWarnings, numInfos, numHints} = report.issues;
    if (numErrors || numWarnings) bad += 1;
    console.log(`${file}: ${numErrors} errors, ${numWarnings} warnings, ${numInfos} infos, ${numHints} hints`);
    const seen = {};
    for (const m of report.issues.messages) {
      if (m.severity > 1) continue;                      // 0 error, 1 warning
      seen[m.code] = seen[m.code] || {n: 0, first: m};
      seen[m.code].n += 1;
    }
    for (const [code, v] of Object.entries(seen)) console.log(`   ${v.first.severity === 0 ? 'error' : 'warning'} ${code} x${v.n}: ${v.first.message} (${v.first.pointer || ''})`);
  }
  process.exitCode = bad ? 1 : 0;
})().catch(e => { console.error(e); process.exitCode = 1; });
