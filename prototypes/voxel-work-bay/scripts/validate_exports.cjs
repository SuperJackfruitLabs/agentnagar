// Real Khronos validation, with one report per delivered GLB.
// npm ci --prefix tools && npm run --prefix tools validate
//
// Reads every top-level .glb in godot/assets/ (the shared-workshop kit lives
// one level down in godot/assets/workshop and has its own validator,
// validate_shared_exports.cjs, which this file now mirrors) so that adding a
// resident to character.RESIDENTS gets it validated with no further edit here.
const fs = require('node:fs');
const path = require('node:path');
const validator = require(require.resolve('gltf-validator', {paths: [path.resolve(__dirname, '../tools')]}));
const root = path.resolve(__dirname, '..');
const directory = path.join(root, 'godot', 'assets');

(async () => {
  const files = fs.readdirSync(directory).filter(name => name.endsWith('.glb')).sort();
  if (!files.length) throw new Error('No exports to validate');
  let errors = 0;
  for (const name of files) {
    const file = path.join(directory, name);
    const report = await validator.validateBytes(new Uint8Array(fs.readFileSync(file)), {uri: name});
    fs.mkdirSync(path.join(root, 'evidence'), {recursive: true});
    fs.writeFileSync(path.join(root, 'evidence', name.replace('.glb', '-validation.json')), JSON.stringify(report, null, 2) + '\n');
    console.log(`${name}: ${report.issues.numErrors} errors, ${report.issues.numWarnings} warnings`);
    errors += report.issues.numErrors + report.issues.numWarnings;
  }
  process.exitCode = errors ? 1 : 0;
})().catch(error => { console.error(error); process.exitCode = 1; });
