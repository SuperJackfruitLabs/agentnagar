## audit_cells.gd: what the game's own collision audit holds each placement or seat of some kinds to, cell by
## cell, in the placement's own frame, and what the style draws for it in the walking band:
##   godot --headless --path <working copy>/city/godot --script <this file> -- STYLE OUT.json KIND[,KIND...]
## It boots the client as the audit does (tools/collision_audit/audit.gd), runs the audit with no day, and
## writes for every placement or seat of the kinds named:
##   - `pos`, `facing`, `kind`;
##   - `cells`: every cell whose centre lies within REACH metres of what is drawn or of the footprint, as
##     [x, z, state, nearest_cm, gated_cm]: the centre in the placement's frame (cm, the catalogue's axes),
##     `state` W walkable, B blocked, S its own seat cell, with a lower-case letter added when the audit counts
##     it (t through, n within 10 cm, r blocked with nothing drawn near), and o when the centre lies in the
##     placement's protected square; the distance to the nearest solid of any owner and to the nearest the
##     gates read (a seat's own furniture left out in its square), cm, 99 when beyond the audit's reach;
##   - `drawn`: the band slices of the solids the audit names as this placement's, as flat lists of points in
##     the same frame (cm), one list a slice;
##   - `fill`: the scale the game gave the piece and where its root stands.
## Nothing here is a rule of its own: every number is read from the audit's state.
extends SceneTree

const REACH := 0.6


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var style: String = args[0]
	var out_path: String = args[1]
	var kinds: PackedStringArray = args[2].split(",")
	var audit = CollisionAudit.new()
	audit.style = style
	audit.main = load("res://main.gd").new()
	root.add_child(audit.main)
	audit.main.boot_for_tool(PackedStringArray(["--crowd=%d" % CollisionAudit.CROWD, "--style=" + style]))
	audit.main.driver.pause()
	for i in 10:
		await process_frame
	audit.pack = audit.main.host.pack
	if audit.pack == null or audit.main.host.pack_dir.get_file() != style:
		push_error("audit_cells: style %s did not activate" % style)
		quit(1)
		return
	var result: Dictionary = await audit._audit(0, false, self)
	var nav = audit.nav
	# What the audit counted, by cell.
	var counted := {}
	for gate in [["through", "t"], ["within_10cm", "n"], ["reverse_blocked", "r"]]:
		for o in result[gate[0]]["offenders"]:
			var key := Vector2i(int(o["cell"][0]), int(o["cell"][1]))
			counted[key] = str(counted.get(key, "")) + gate[1]
	var by_owner := {}
	for solid in audit.solids:
		var id := str(solid.owner.get("placement_id", ""))
		if id != "":
			if not by_owner.has(id):
				by_owner[id] = []
			by_owner[id].append(solid)
	var out := {"style": style, "counts": {}, "placements": {}}
	for gate in CollisionAudit.GATES:
		out["counts"][gate] = result[gate]["count"]
	for id in audit.placed:
		var place: Dictionary = audit.placed[id]
		if not kinds.has(str(place["kind"])):
			continue
		var pos: Vector2 = place["pos"]
		var t := deg_to_rad(float(place["facing"]))
		var to_local := func(p: Vector2) -> Vector2:
			var d := p - pos
			return Vector2(d.x * cos(t) + d.y * sin(t), -d.x * sin(t) + d.y * cos(t)) * 100.0
		var drawn := []
		var box := Rect2(pos, Vector2.ZERO)
		for solid in by_owner.get(id, []):
			for piece in solid.pieces:
				var flat := []
				for q in solid.to_world * piece:
					var l: Vector2 = to_local.call(q)
					flat.append(snappedf(l.x, 0.01))
					flat.append(snappedf(l.y, 0.01))
					box = box.expand(q)
				drawn.append(flat)
		# The footprint's corners too, so a piece that draws nothing still gets its cells.
		var kind: Dictionary = StylePack.kinds().get(str(place["kind"]), {})
		for sh in kind.get("footprint", []):
			var r := float(sh.get("r", 0.0))
			for corner in [Vector2(sh["x"] - r, sh["z"] - r), Vector2(sh["x"] + sh.get("w", r), sh["z"] - r),
					Vector2(sh["x"] - r, sh["z"] + sh.get("d", r)), Vector2(sh["x"] + sh.get("w", r), sh["z"] + sh.get("d", r))]:
				box = box.expand(pos + Vector2(corner.x * cos(t) - corner.y * sin(t), corner.x * sin(t) + corner.y * cos(t)) / 100.0)
		box = box.grow(REACH)
		var a: Vector2i = nav.cell_of(box.position * 100.0)
		var b: Vector2i = nav.cell_of(box.end * 100.0)
		var cells := []
		for j in range(maxi(a.y, 0), mini(b.y, nav.rows - 1) + 1):
			for i in range(maxi(a.x, 0), mini(b.x, nav.cols - 1) + 1):
				var c := Vector2i(i, j)
				var k: int = j * nav.cols + i
				var centre: Vector2 = nav.centre(c) / 100.0
				var l: Vector2 = to_local.call(centre)
				var state := "W" if nav.walkable(c) else "B"
				if audit.seat_at.get(c, "") == id:
					state = "S"
				if CollisionAudit.in_own_square(place, centre):
					state += "o"
				state += str(counted.get(c, ""))
				var near: float = audit.nearest[k]
				var gated: float = audit.nearest_gated[k]
				cells.append([snappedf(l.x, 0.01), snappedf(l.y, 0.01), state,
					99 if is_inf(near) else snappedf(near * 100.0, 0.1), 99 if is_inf(gated) else snappedf(gated * 100.0, 0.1)])
		var node = audit.pack.placement_nodes.get(id) if "placement_nodes" in audit.pack else null
		var fill := {}
		if node is Node3D:
			fill = {"scale": [node.scale.x, node.scale.y, node.scale.z], "at": [node.global_position.x, node.global_position.y, node.global_position.z],
				"scene": str(node.scene_file_path)}
		out["placements"][id] = {"kind": place["kind"], "pos": [pos.x, pos.y], "facing": place["facing"], "cells": cells, "drawn": drawn, "fill": fill}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("audit_cells: %s, %d placements of %s -> %s" % [style, out["placements"].size(), ",".join(kinds), out_path])
	audit.main.free()
	await process_frame
	quit(0)
