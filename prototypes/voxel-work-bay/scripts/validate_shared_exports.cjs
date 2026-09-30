// Validate the actual shared-workshop kit with the same pinned Khronos library.
const fs = require('node:fs');
const path = require('node:path');
const validator = require(require.resolve('gltf-validator', {paths: [path.resolve(__dirname, '../tools')]}));
const root = path.resolve(__dirname, '..');
const directory = path.join(root, 'godot/assets/workshop');
(async () => {
  const files = fs.readdirSync(directory).filter(name => name.endsWith('.glb')).sort();
  if (!files.length) throw new Error('No shared workshop exports to validate');
  const output = path.join(root, 'evidence/shared-validation');
  fs.mkdirSync(output, {recursive:true});
  let failures = 0;
  for (const name of files) {
    const report = await validator.validateBytes(new Uint8Array(fs.readFileSync(path.join(directory, name))), {uri:name});
    fs.writeFileSync(path.join(output, name.replace('.glb', '.json')), JSON.stringify(report, null, 2) + '\n');
    console.log(`${name}: ${report.issues.numErrors} errors, ${report.issues.numWarnings} warnings`);
    failures += report.issues.numErrors + report.issues.numWarnings;
  }
  process.exitCode = failures ? 1 : 0;
})().catch(error => { console.error(error); process.exitCode = 1; });
