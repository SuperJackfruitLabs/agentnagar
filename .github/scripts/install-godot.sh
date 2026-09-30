#!/usr/bin/env bash
# Installs the Godot editor and some of its export templates on a CI runner
# (Linux, macOS, or Windows under Git Bash), for city/scripts/package.sh.
#
#   GODOT_VERSION, GODOT_STATUS  the release, e.g. 4.6.3 and stable
#   EDITOR_SUFFIX                the editor download: linux.x86_64, win64.exe
#                                or macos.universal
#   TEMPLATES                    the template files wanted, space separated
#
# Writes GODOT (the editor command) and GODOT_TEMPLATES to $GITHUB_ENV.
set -euo pipefail
: "${GODOT_VERSION:?}" "${GODOT_STATUS:?}" "${EDITOR_SUFFIX:?}" "${TEMPLATES:?}"
release="$GODOT_VERSION-$GODOT_STATUS"
base="https://github.com/godotengine/godot/releases/download/$release"
tmp="${RUNNER_TEMP:-$HOME/.cache}"
case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*)
        os=windows
        tmp="$(cygpath -u "$tmp")"
        ;;
    Darwin) os=macos ;;
    *) os=linux ;;
esac

dir="$tmp/godot"
mkdir -p "$dir"
cd "$dir"
editor="Godot_v${release}_$EDITOR_SUFFIX"
echo "install-godot: $base/$editor.zip"
curl -fsSL -o editor.zip "$base/$editor.zip"
if [[ "$os" == windows ]]; then
    7z x -y -bd editor.zip >/dev/null
else
    unzip -q -o editor.zip
fi
rm editor.zip
case "$os" in
    linux)
        godot="$dir/$editor"
        chmod +x "$godot"
        home="$HOME/.local/share/godot/export_templates"
        ;;
    macos)
        godot="$dir/Godot.app/Contents/MacOS/Godot"
        home="$HOME/Library/Application Support/Godot/export_templates"
        ;;
    windows)
        # The console build, so its output reaches the log.
        godot="$dir/${editor%.exe}_console.exe"
        home="$(cygpath -u "$APPDATA")/Godot/export_templates"
        ;;
esac

dest="$home/$GODOT_VERSION.$GODOT_STATUS"
mkdir -p "$dest"
echo "install-godot: $base/Godot_v${release}_export_templates.tpz ($TEMPLATES)"
curl -fsSL -o templates.tpz "$base/Godot_v${release}_export_templates.tpz"
members=(templates/version.txt)
for f in $TEMPLATES; do
    members+=("templates/$f")
done
if [[ "$os" == windows ]]; then
    7z e -y -bd -o"$dest" templates.tpz "${members[@]}" >/dev/null
else
    unzip -q -o -j templates.tpz "${members[@]}" -d "$dest"
fi
rm templates.tpz

"$godot" --headless --version
ls -la "$dest"
{
    echo "GODOT=$godot"
    echo "GODOT_TEMPLATES=$dest"
} >>"${GITHUB_ENV:-/dev/null}"
