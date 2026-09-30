extends SceneTree
## The collision audit, run by hand (CollisionAudit, in
## tools/collision_audit/audit.gd, is the library; tests/
## test_collision_audit.gd gates every style with it):
##   godot --headless --path city/godot --script res://tools/collision_audit.gd -- [options]
## Options:
##   --audit-style=<style>   one style (default: all six)
##   --audit-ticks=<n>       the day's length (default 600, the spike's day,
##                           which the test runs too)
##   --audit-out=<dir>       where each style's report.json and overlay.png
##                           go (default ~/.cache/agentnagar-collision)
##   --measure-kinds         measure every kind's walking-band silhouette in
##                           all six styles and write evidence/
##                           placement-kind-sizes.json (no day; not with
##                           --write-budget)
##   --write-budget          write the counts as evidence/placement-budget.json
## Neither writes when a MultiMesh's pieces could not be placed.
## The overlay draws each cell 4 px: walkable floor green, blocked grey,
## seat cells yellow, within 10 cm orange, through red, and blocked cells
## that look open blue.

const SIZES := "res://evidence/placement-kind-sizes.json"
const BUDGET := "res://evidence/placement-budget.json"


func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
		if a == "--" + key:
			return "true"
	return fallback


func _init():
	await process_frame
	var one := _arg("audit-style", "")
	var styles: Array = [one] if one != "" else CollisionAudit.STYLES
	var measure := _arg("measure-kinds", "") != ""
	var budget := _arg("write-budget", "") != ""
	if measure and budget:
		# Measuring reads no day, and a budget written without one would
		# hold no passes.
		push_error("collision audit: --measure-kinds and --write-budget are separate runs")
		quit(1)
		return
	if measure or budget:
		styles = CollisionAudit.STYLES
	var ticks := int(_arg("audit-ticks", str(CollisionAudit.DAY_TICKS)))
	if budget:
		ticks = CollisionAudit.DAY_TICKS
	if measure:
		ticks = 0
	var out := _arg("audit-out", OS.get_environment("HOME") + "/.cache/agentnagar-collision")
	var counts := {}
	var sizes := {}
	var results := {}
	for style in styles:
		var t0 := Time.get_ticks_msec()
		var dir: String = out + "/" + style
		DirAccess.make_dir_recursive_absolute(dir)
		var result: Dictionary = await CollisionAudit.run(style, {"ticks": ticks, "measure": measure, "overlay": dir + "/overlay.png"})
		if result.has("error"):
			quit(1)
			return
		var f := FileAccess.open(dir + "/report.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(result, " "))
		f.close()
		counts[style] = {}
		for gate in CollisionAudit.GATES:
			counts[style][gate] = result[gate]["count"]
		print("collision audit: %s in %d ms: %s; reverse outside rooms %d; unmeasured sprites %s -> %s" % [style,
			Time.get_ticks_msec() - t0, counts[style], result["info"]["reverse_outside_rooms"],
			result["info"]["unmeasured_sprites"], dir])
		if measure:
			sizes[style] = result["kinds"]
		results[style] = {"info": result["info"]}
	var why := CollisionAudit.unwritable(results)
	if (measure or budget) and why != "":
		push_error("collision audit: nothing written: " + why)
		quit(1)
		return
	if measure:
		_write(SIZES, CollisionAudit.kind_sizes(sizes))
		print("collision audit: kind sizes -> ", ProjectSettings.globalize_path(SIZES))
	if budget:
		_write(BUDGET, counts)
		print("collision audit: budget -> ", ProjectSettings.globalize_path(BUDGET))
	quit()


func _write(path: String, data) -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  ") + "\n")
	f.close()
