#!/usr/bin/env bash
set -Eeuo pipefail

SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE="$SERVICE_DIR/nvibrant.service"
STATE_DIR="$HOME/.local/state/arch-linux-fixes/nvibrant-autoload"
BACKUP="$STATE_DIR/nvibrant.service.before"
STATE_FILE="$STATE_DIR/state"
MARKER='ARCH_LINUX_FIXES_NVIBRANT_AUTOLOAD'

info() { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
err()  { printf '[ERR ] %s\n' "$*" >&2; }

[[ "$EUID" -ne 0 ]] || { err 'Run this script as your normal user, not as root.'; exit 1; }
[[ -f "$STATE_FILE" ]] || { err "Rollback state not found: $STATE_FILE"; exit 2; }

# shellcheck disable=SC1090
source "$STATE_FILE"

if [[ -f "$SERVICE" ]] && ! grep -q "$MARKER" "$SERVICE"; then
    err 'The current nvibrant.service is not the service created by this patch.'
    err 'Refusing to overwrite or delete it.'
    exit 3
fi

info 'Disabling the managed nvibrant autoload service...'
systemctl --user disable --now nvibrant.service >/dev/null 2>&1 || true

if [[ "${had_service:-0}" -eq 1 ]]; then
    [[ -f "$BACKUP" ]] || { err "Original service backup not found: $BACKUP"; exit 4; }
    info 'Restoring the nvibrant.service that existed before this patch...'
    mkdir -p "$SERVICE_DIR"
    cp -a "$BACKUP" "$SERVICE"
else
    info 'Removing the service created by this patch...'
    rm -f "$SERVICE"
fi

systemctl --user daemon-reload
systemctl --user reset-failed nvibrant.service >/dev/null 2>&1 || true

if [[ "${had_service:-0}" -eq 1 ]]; then
    if [[ "${was_enabled:-0}" -eq 1 ]]; then
        systemctl --user enable nvibrant.service >/dev/null
    fi

    if [[ "${was_active:-0}" -eq 1 ]]; then
        systemctl --user start nvibrant.service || {
            err 'The original service was restored but failed to start.'
            exit 5
        }
    fi
fi

ok 'NVIDIA vibrance autoload rollback completed.'
printf '%s\n' 'The nvibrant package was not removed and the current display value was not changed.'
