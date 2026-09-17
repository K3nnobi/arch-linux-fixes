#!/usr/bin/env bash
set -Eeuo pipefail

UUID='dash-to-dock@micxgx.gmail.com'
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
DASH_JS="$EXT_DIR/dash.js"
METADATA="$EXT_DIR/metadata.json"
STATE_DIR="$HOME/.local/state/arch-linux-fixes/gnome-drag-hover-raise"
BACKUP="$STATE_DIR/dash.js.before"
VERSION_FILE="$STATE_DIR/dash-to-dock-version"
TESTED_VERSION='105'

info() { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
err()  { printf '[ERR ] %s\n' "$*" >&2; }

[[ -f /etc/arch-release ]] || { err 'This script requires Arch Linux.'; exit 1; }
[[ "$EUID" -ne 0 ]] || { err 'Run this script as your normal user, not as root.'; exit 1; }
[[ -f "$DASH_JS" ]] || { err "User-installed Dash to Dock was not found at: $DASH_JS"; exit 2; }
[[ -f "$METADATA" ]] || { err "metadata.json was not found at: $METADATA"; exit 2; }

if ! command -v python >/dev/null 2>&1; then
    info 'Python is required to apply the source patch. Installing it...'
    sudo pacman -S --needed python
fi

version="$(python - "$METADATA" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    data = json.load(f)
print(data.get('version', ''))
PY
)"

[[ "$version" == "$TESTED_VERSION" ]] || {
    err "Unsupported Dash to Dock version: ${version:-unknown}."
    err "This patch is intentionally limited to the tested version $TESTED_VERSION."
    exit 3
}

has_dock=0
has_window=0
grep -q 'ARCH_LINUX_FIXES_DRAG_HOVER_PATCH' "$DASH_JS" && has_dock=1
grep -q 'ARCH_LINUX_FIXES_WINDOW_HOVER_PATCH' "$DASH_JS" && has_window=1

if [[ "$has_dock" -eq 1 && "$has_window" -eq 1 ]]; then
    ok 'GNOME drag-hover patch is already installed.'
    exit 0
fi

if [[ "$has_dock" -ne "$has_window" ]]; then
    err 'A partial patch was detected. Refusing to modify dash.js further.'
    err 'Restore a known-good file or use the rollback script if this repository created the backup.'
    exit 4
fi

mkdir -p "$STATE_DIR"
cp -a "$DASH_JS" "$BACKUP"
printf '%s\n' "$version" > "$VERSION_FILE"
chmod 600 "$BACKUP" "$VERSION_FILE"

info "Backed up original dash.js to: $BACKUP"

python - "$DASH_JS" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
src = p.read_text(encoding='utf-8')

if 'ARCH_LINUX_FIXES_DRAG_HOVER_PATCH' in src or 'ARCH_LINUX_FIXES_WINDOW_HOVER_PATCH' in src:
    raise SystemExit('Patch marker already present; no changes made.')

init_anchor = "        this.connect('destroy', this._onDestroy.bind(this));\n"
destroy_anchor = """    _onDestroy() {
        this.iconAnimator.destroy();
"""

if init_anchor not in src:
    raise SystemExit('Expected _init anchor was not found; no changes made.')
if destroy_anchor not in src:
    raise SystemExit('Expected _onDestroy anchor was not found; no changes made.')

init_patch = init_anchor + """
        // ARCH_LINUX_FIXES_DRAG_HOVER_PATCH
        // Raise a running application after hovering a dragged file over its dock icon.
        this._dragHoverPollId = 0;
        this._dragHoverAppId = null;
        this._dragHoverSince = 0;
        this._dragHoverActivatedAppId = null;
        this._startExternalDragHover();
"""
src = src.replace(init_anchor, init_patch, 1)

methods = """    _startExternalDragHover() {
        if (this._dragHoverPollId)
            return;

        this._dragHoverPollId = GLib.timeout_add(
            GLib.PRIORITY_DEFAULT,
            100,
            () => {
                this._checkExternalDragHover();
                return GLib.SOURCE_CONTINUE;
            }
        );
    }

    _resetExternalDragHover() {
        this._dragHoverAppId = null;
        this._dragHoverSince = 0;
        this._dragHoverActivatedAppId = null;
    }

    _checkExternalDragHover() {
        const [x, y, mods] = global.get_pointer();

        if (!(mods & Clutter.ModifierType.BUTTON1_MASK)) {
            this._resetExternalDragHover();
            return;
        }

        // Meta.SelectionType.DND = 2.
        let mimeTypes = [];

        try {
            const selection = global.display.get_selection();
            mimeTypes = selection.get_mimetypes(2) ?? [];
        } catch (e) {
            this._resetExternalDragHover();
            return;
        }

        const isFileDrag = mimeTypes.some(mime =>
            mime === 'text/uri-list' ||
            mime === 'x-special/gnome-icon-list' ||
            mime === 'application/octet-stream' ||
            mime === 'application/vnd.portal.filetransfer' ||
            mime.startsWith('image/')
        );

        if (!isFileDrag) {
            this._resetExternalDragHover();
            return;
        }

        for (const appIcon of this.getAppIcons()) {
            if (!appIcon.app)
                continue;

            const [ok, lx, ly] = appIcon.transform_stage_point(x, y);

            if (!ok ||
                lx < 0 ||
                ly < 0 ||
                lx > appIcon.width ||
                ly > appIcon.height)
                continue;

            const appId = appIcon.app.get_id();

            if (this._dragHoverAppId !== appId) {
                this._dragHoverAppId = appId;
                this._dragHoverSince = GLib.get_monotonic_time();
                this._dragHoverActivatedAppId = null;
                return;
            }

            if (this._dragHoverActivatedAppId === appId)
                return;

            const elapsed =
                (GLib.get_monotonic_time() - this._dragHoverSince) / 1000;

            if (elapsed < 400)
                return;

            if (appIcon.app.state === Shell.AppState.RUNNING) {
                const windows = appIcon.getInterestingWindows();

                if (windows.length > 0) {
                    Main.activateWindow(windows[0]);
                    this._dragHoverActivatedAppId = appId;
                }
            }

            return;
        }

        // ARCH_LINUX_FIXES_WINDOW_HOVER_PATCH
        // Do not geometrically select a window while the pointer is over the dock itself.
        const [dockOk, dockX, dockY] = this.transform_stage_point(x, y);

        if (dockOk &&
            dockX >= 0 &&
            dockY >= 0 &&
            dockX <= this.width &&
            dockY <= this.height) {
            this._resetExternalDragHover();
            return;
        }

        const workspace =
            global.workspace_manager.get_active_workspace();
        let windows = global.display.list_all_windows();

        windows = windows.filter(win => {
            if (!win)
                return false;
            if (!win.showing_on_its_workspace())
                return false;
            if (!win.located_on_workspace(workspace))
                return false;
            if (win.is_skip_taskbar())
                return false;
            return true;
        });

        windows = global.display.sort_windows_by_stacking(windows);

        let targetWindow = null;
        for (let i = windows.length - 1; i >= 0; i--) {
            const win = windows[i];
            const rect = win.get_frame_rect();

            if (x >= rect.x &&
                x < rect.x + rect.width &&
                y >= rect.y &&
                y < rect.y + rect.height) {
                targetWindow = win;
                break;
            }
        }

        if (!targetWindow) {
            this._resetExternalDragHover();
            return;
        }

        const windowId = `window:${targetWindow.get_id()}`;

        if (this._dragHoverAppId !== windowId) {
            this._dragHoverAppId = windowId;
            this._dragHoverSince = GLib.get_monotonic_time();
            this._dragHoverActivatedAppId = null;
            return;
        }

        if (this._dragHoverActivatedAppId === windowId)
            return;

        const windowElapsed =
            (GLib.get_monotonic_time() - this._dragHoverSince) / 1000;

        if (windowElapsed < 400)
            return;

        Main.activateWindow(targetWindow);
        this._dragHoverActivatedAppId = windowId;
    }

    _onDestroy() {
        this.iconAnimator.destroy();

        if (this._dragHoverPollId) {
            GLib.source_remove(this._dragHoverPollId);
            this._dragHoverPollId = 0;
        }
"""

src = src.replace(destroy_anchor, methods, 1)
p.write_text(src, encoding='utf-8')
PY

if ! grep -q 'ARCH_LINUX_FIXES_DRAG_HOVER_PATCH' "$DASH_JS" || \
   ! grep -q 'ARCH_LINUX_FIXES_WINDOW_HOVER_PATCH' "$DASH_JS"; then
    err 'Patch verification failed. Restoring the original dash.js...'
    cp -a "$BACKUP" "$DASH_JS"
    exit 5
fi

ok 'GNOME drag-hover patch installed.'
printf '\nWayland requires a GNOME logout/login to reload the extension.\n'
printf '%s\n' 'Save all work before logging out. This script will not log you out automatically.'
