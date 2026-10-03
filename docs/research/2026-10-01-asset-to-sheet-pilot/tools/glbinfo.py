import json, struct, sys
def info(path):
    d = open(path, 'rb').read()
    n = struct.unpack('<I', d[12:16])[0]
    j = json.loads(d[20:20 + n])
    acc = j.get('accessors', [])
    tris = 0
    for m in j.get('meshes', []):
        for p in m['primitives']:
            if 'indices' in p: tris += acc[p['indices']]['count'] // 3
            else: tris += acc[p['attributes']['POSITION']]['count'] // 3
    nodes = [(nd.get('name'), 'mesh' if 'mesh' in nd else '', nd.get('extras')) for nd in j.get('nodes', [])]
    mats = [(m.get('name'), [round(c, 3) for c in m.get('pbrMetallicRoughness', {}).get('baseColorFactor', [])][:3],
             'tex' if 'baseColorTexture' in m.get('pbrMetallicRoughness', {}) else '', m.get('emissiveFactor'), m.get('alphaMode')) for m in j.get('materials', [])]
    attrs = sorted({a for m in j.get('meshes', []) for p in m['primitives'] for a in p['attributes']})
    # bounds from POSITION accessors
    mn = [1e9] * 3; mx = [-1e9] * 3
    for m in j.get('meshes', []):
        for p in m['primitives']:
            a = acc[p['attributes']['POSITION']]
            for i in range(3):
                mn[i] = min(mn[i], a['min'][i]); mx[i] = max(mx[i], a['max'][i])
    print(f"{path}: {len(d)/1024:.0f} KiB, {tris} tris, {len(j.get('meshes', []))} meshes, images {len(j.get('images', []))}, anims {len(j.get('animations', []))}")
    print('  nodes:', [f"{a}{'*' if b else ''}" for a, b, c in nodes][:14], '(… %d)' % len(nodes) if len(nodes) > 14 else '')
    print('  extras:', [(a, c) for a, b, c in nodes if c][:4])
    print('  materials:', mats[:10])
    print('  attributes:', attrs, '| local bounds (not node-transformed):', [round(x, 2) for x in mn], [round(x, 2) for x in mx])
for p in sys.argv[1:]: info(p)
