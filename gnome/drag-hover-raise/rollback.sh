#!/usr/bin/env bash
set -Eeuo pipefail

UUID='dash-to-dock@micxgx.gmail.com'
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
DASH_JS="$EXT_DIR/dash.js"
METADATA="$EXT_DIR/metadata.json"
STATE_DIR="$HOME/.local/state/arch-linux-fixes/gnome-drag-hover-raise"
BACKUP="$STATE_DIR/dash.js.before"
VERSION_FILE="$STATE_DIR/dash-to-dock-version"

info() { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
err()  { printf '[ERR ] %s\n' "$*" >&2; }

[[ -f "$DASH_JS" ]] || { err "Current dash.js not found: $DASH_JS"; exit 1; }
[[ -f "$METADATA" ]] || { err "Current metadata.json not found: $METADATA"; exit 1; }
[[ -f "$BACKUP" ]] || { err "Patch backup not found: $BACKUP"; exit 2; }
[[ -f "$VERSION_FILE" ]] || { err "Saved version information not found: $VERSION_FILE"; exit 2; }

if ! command -v python >/dev/null 2>&1; then
    err 'Python is required to read the current extension version.'
    exit 3
fi

saved_version="$(cat "$VERSION_FILE")"
current_version="$(python - "$METADATA" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    data = json.load(f)
print(data.get('version', ''))
PY
)"

if [[ "$current_version" != "$saved_version" ]]; then
    err "Dash to Dock changed from version $saved_version to $current_version."
    err 'Refusing to restore an older dash.js over a different extension version.'
    exit 4
fi

if ! grep -q 'ARCH_LINUX_FIXES_DRAG_HOVER_PATCH' "$DASH_JS" && \
   ! grep -q 'ARCH_LINUX_FIXES_WINDOW_HOVER_PATCH' "$DASH_JS"; then
    err 'Patch markers are not present in the current dash.js.'
    err 'Refusing to overwrite the file because it may have been updated or replaced.'
    exit 5
fi

info 'Restoring the exact pre-patch dash.js...'
cp -a "$BACKUP" "$DASH_JS"

ok 'GNOME drag-hover patch rolled back.'
printf '\nWayland requires a GNOME logout/login to reload the extension.\n'
printf '%s\n' 'Save all work before logging out.'
