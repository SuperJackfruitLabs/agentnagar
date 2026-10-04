const fs=require('fs'),path=require('path'),crypto=require('crypto');
const validator=require('../../../../prototypes/voxel-work-bay/tools/node_modules/gltf-validator');
(async()=>{const root=path.resolve(__dirname,'..');let rows=[];
for(const name of fs.readdirSync(path.join(root,'assets/lowpoly_tropical')).filter(n=>n.endsWith('.glb')).sort()){
 const p=path.join(root,'assets/lowpoly_tropical',name),b=fs.readFileSync(p),j=JSON.parse(b.subarray(20,20+b.readUInt32LE(12)).toString().trim());
 const result=await validator.validateBytes(new Uint8Array(b),{uri:name});
 const tris=j.meshes.flatMap(m=>m.primitives).reduce((a,p)=>a+j.accessors[p.indices].count/3,0);
 rows.push({name,bytes:b.length,triangles:tris,nodes:j.nodes.map(n=>n.name),materials:j.materials.map(m=>m.name),textures:(j.textures||[]).length,sha256:crypto.createHash('sha256').update(b).digest('hex'),errors:result.issues.numErrors,warnings:result.issues.numWarnings,infos:result.issues.numInfos,messages:result.issues.messages});
}
fs.writeFileSync(path.join(root,'reports/glb-validation.json'),JSON.stringify(rows,null,2));console.log(JSON.stringify({files:rows.length,errors:rows.reduce((s,x)=>s+x.errors,0),warnings:rows.reduce((s,x)=>s+x.warnings,0),triangles:rows.reduce((s,x)=>s+x.triangles,0),bytes:rows.reduce((s,x)=>s+x.bytes,0)},null,2));process.exitCode=rows.some(x=>x.errors||x.warnings)?1:0;
})();
