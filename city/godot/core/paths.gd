## Where the client finds the city fixtures and its licence texts. From a
## checkout the fixtures are read beside the project (city/fixtures) and the
## licence texts from the repository's root (LICENSE,
## THIRD-PARTY-NOTICES.txt); an exported package carries its own copies,
## which scripts/package.sh stages as res://fixtures and res://licenses
## before export.
extends RefCounted
class_name CityPaths

const BUNDLED := "res://fixtures"
## Where a package carries the licence texts.
const LICENSES := "res://licenses"
## Each licence text as it is staged in a package, and its name at the
## repository's root.
const LICENSE_FILES := {
	"LICENSE.txt": "LICENSE",
	"THIRD-PARTY-NOTICES.txt": "THIRD-PARTY-NOTICES.txt",
}


static func fixtures_dir() -> String:
	if OS.has_feature("template"):
		return BUNDLED
	return ProjectSettings.globalize_path("res://").path_join("../fixtures")


static func read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## The district fixture's folder: its manifest, feed and sample panels.
static func district_dir() -> String:
	return fixtures_dir().path_join("district")


static func district_manifest() -> String:
	return read(district_dir().path_join("manifest.json"))


static func district_feed() -> String:
	return read(district_dir().path_join("feed.jsonl"))


## The repository's root, two folders above the project (city/godot).
static func repo_root() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()


## Where to look for the licence text `staged` (a key of LICENSE_FILES), in
## order: the package's copy, then, run from a checkout, the repository's.
static func licence_paths(staged: String) -> Array[String]:
	var paths: Array[String] = [LICENSES.path_join(staged)]
	if not OS.has_feature("template"):
		paths.append(repo_root().path_join(LICENSE_FILES.get(staged, staged)))
	return paths


## The first of `paths` that can be read, or "" when none can.
static func read_first(paths: Array) -> String:
	for path in paths:
		if FileAccess.file_exists(path):
			var text := read(path)
			if text != "":
				return text
	return ""
