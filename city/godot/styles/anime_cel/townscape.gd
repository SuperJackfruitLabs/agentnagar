## The cel-shaded anime city: the low-poly townscape's assembly (bays
## along each side, a door bay at each opening, the sawtooth roof, blocks
## on their lots, streets, water, bridge, tram) with the anime kit's
## pieces, and the library under the sheets' silver barrel vault instead
## of a dome.
extends "res://styles/lowpoly_tropical/townscape.gd"


func _init(palette: Dictionary, loader: Callable, kit_prefix := "assets/") -> void:
	super(palette, loader, kit_prefix)
	# The river runs lower between its quays, so the bridge's arches stand
	# clear of the water as the sheets draw them.
	water_y = -2.0


## The barrel vault over the whole library, its glazed arched end to the
## west over the entrance, fitted to the footprint.
func _library_roof(roof: Node3D, fp: Rect2) -> void:
	var sx := (fp.size.x + 0.4) / 20.4
	var sz := (fp.size.y + 0.4) / 18.4
	piece(roof, "lib_vault", Vector3(fp.get_center().x, LIB_H, fp.get_center().y), Vector2(0, -1), Vector3(sx, 1.0, sz))


## Blocks as the low-poly city lays them, with the anime kit's third house
## and second tower for variety.
func block(rect: Rect2, height_class: String, seed_: String, toward := Vector2.ZERO, street := Vector2.INF) -> Node3D:
	var root := super(rect, height_class, seed_, toward, street)
	for n in root.get_children():
		var name_ := str(n.get_meta("piece", ""))
		if name_ == "house_b" and _hash01(seed_ + str(n.get_index())) < 0.4:
			_swap(n, "house_c")
		elif name_ == "tower_a" and _hash01(seed_) < 0.5:
			_swap(n, "tower_b")
	return root


func _swap(n: Node3D, name_: String) -> void:
	var fresh := piece(n.get_parent(), name_, n.position, Vector2(0, -1), n.scale)
	fresh.transform = n.transform
	n.get_parent().remove_child(n)
	n.free()
