## The lit styles' city (solarpunk, neon noir): the anime townscape's
## assembly (the low-poly bays, blocks with a third house and a second
## tower, the lower river) with the style kit's pieces, and the library
## under the kit's lib_roof, fitted to its footprint: solarpunk's glass and
## solar dome on a planted rim, neon noir's lit drum and dome.
extends "res://styles/anime_cel/townscape.gd"


func _library_roof(roof: Node3D, fp: Rect2) -> void:
	var sx := (fp.size.x + 0.4) / 20.4
	var sz := (fp.size.y + 0.4) / 18.4
	piece(roof, "lib_roof", Vector3(fp.get_center().x, LIB_H, fp.get_center().y), Vector2(0, -1), Vector3(sx, 1.0, sz))
