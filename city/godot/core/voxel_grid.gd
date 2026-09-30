## A sparse grid of coloured voxels that meshes to only its exposed faces,
## each voxel a touch lighter or darker than its colour so surfaces read as
## blocks. Cell (i, j, k) covers [i, i + 1) × [j, j + 1) × [k, k + 1) cells
## of `size` metres.
extends RefCounted
class_name VoxelGrid

const DIRS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var size := 0.5
## Vector3i -> Color
var cells := {}


func _init(cell_size := 0.5) -> void:
	size = cell_size


func cell_of(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / size + 0.001), floori(p.y / size + 0.001), floori(p.z / size + 0.001))


func put(v: Vector3i, colour: Color) -> void:
	cells[v] = colour


func erase(v: Vector3i) -> void:
	cells.erase(v)


## Fills the box from `from` to `to` (metres; `to` exclusive).
func fill(from: Vector3, to: Vector3, colour: Color) -> void:
	var a := cell_of(from)
	var b := cell_of(to)
	for i in range(a.x, maxi(b.x, a.x + 1)):
		for j in range(a.y, maxi(b.y, a.y + 1)):
			for k in range(a.z, maxi(b.z, a.z + 1)):
				cells[Vector3i(i, j, k)] = colour


## One node with a surface per shade, holding only the faces with no voxel
## beside them. `jitter` is how far a voxel's shade may stray.
func build(name_: String, jitter := 0.05, shadows := true) -> Node3D:
	var batch := MeshBatch.new()
	for v in cells:
		var colour: Color = cells[v]
		var shade := (hash(v) % 3) - 1
		var m := MeshBatch.material(colour.lightened(jitter) if shade > 0 else (colour.darkened(jitter) if shade < 0 else colour), 0.9)
		var o := Vector3(v) * size
		for d in DIRS:
			if cells.has(v + d):
				continue
			_face(batch, o, d, m)
	return batch.build(name_, shadows)


func _face(batch: MeshBatch, o: Vector3, d: Vector3i, m: Material) -> void:
	var s := size
	var n := Vector3(d)
	var c := o + Vector3(s, s, s) / 2.0 + n * s / 2.0
	var u: Vector3
	var w: Vector3
	if d.x != 0:
		u = Vector3(0, s / 2.0, 0)
		w = Vector3(0, 0, s / 2.0)
	elif d.y != 0:
		u = Vector3(s / 2.0, 0, 0)
		w = Vector3(0, 0, s / 2.0)
	else:
		u = Vector3(s / 2.0, 0, 0)
		w = Vector3(0, s / 2.0, 0)
	batch.quad(c - u - w, c + u - w, c + u + w, c - u + w, m, n)
