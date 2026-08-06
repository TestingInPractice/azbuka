#!/usr/bin/env bash
# Godot Web export: patch Bus.addAt(-1) guard — silent audio fix.
# Bug: godotengine/godot#119026 (Sample playback + 2+ buses => Master disconnected
# from ctx.destination => no sound, playing=true, peak=-inf). Fix: PR #119027.
# Usage: bash scripts/patch-web-audio-bus-bug.sh path/to/exported/index.js
set -euo pipefail

IDX="${1:?usage: patch-web-audio-bus-bug.sh <index.js>}"
[[ -f "$IDX" ]] || { echo "NOT FOUND: $IDX" >&2; exit 1; }

BUGGY='if(index!==newBus.getId()){GodotAudio.Bus.move(newBus.getId(),index)}'
FIXED='if(index!==-1&&index!==newBus.getId()){GodotAudio.Bus.move(newBus.getId(),index)}'

if grep -qF "$BUGGY" "$IDX"; then
    python3 - "$IDX" "$BUGGY" "$FIXED" <<'EOF'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
data = open(path, encoding='utf-8').read()
n = data.count(old)
assert n == 1, f"expected 1 occurrence of buggy addAt guard, found {n}"
open(path, 'w', encoding='utf-8').write(data.replace(old, new))
print(f"PATCHED: {path} (Bus.addAt -1 guard, {n} occurrence)")
EOF
elif grep -qF "$FIXED" "$IDX"; then
    echo "ALREADY PATCHED: $IDX"
else
    echo "UNRECOGNIZED: addAt guard pattern not found in $IDX" >&2
    exit 2
fi
