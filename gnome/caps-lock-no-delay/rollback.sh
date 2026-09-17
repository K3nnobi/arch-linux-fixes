#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG="/etc/keyd/default.conf"
STATE_DIR="$HOME/.local/state/arch-linux-fixes/caps-lock-no-delay"
BACKUP="$STATE_DIR/default.conf.before"
STATE_FILE="$STATE_DIR/state"
MARKER="ARCH_LINUX_FIXES_CAPSLOCK_NODELAY"

info() { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
err()  { printf '[ERR ] %s\n' "$*" >&2; }

[[ -f "$STATE_FILE" ]] || { err "Rollback state not found: $STATE_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$STATE_FILE"

if [[ "${had_config:-0}" -eq 1 ]]; then
    [[ -f "$BACKUP" ]] || { err "Saved configuration not found: $BACKUP"; exit 2; }
    info 'Restoring the keyd configuration that existed before this patch...'
    sudo install -m 0644 "$BACKUP" "$CONFIG"
else
    if sudo test -f "$CONFIG" && sudo grep -q "$MARKER" "$CONFIG"; then
        info 'Removing the keyd configuration created by this patch...'
        sudo rm -f "$CONFIG"
    else
        err 'Current configuration does not contain this patch marker; refusing to delete it.'
        exit 3
    fi
fi

if pacman -Q keyd >/dev/null 2>&1; then
    if [[ "${keyd_was_enabled:-0}" -eq 1 ]]; then
        sudo systemctl enable keyd >/dev/null
    else
        sudo systemctl disable keyd >/dev/null 2>&1 || true
    fi

    if [[ "${keyd_was_active:-0}" -eq 1 ]]; then
        sudo systemctl restart keyd
    else
        sudo systemctl stop keyd >/dev/null 2>&1 || true
    fi
fi

ok 'Rollback completed.'
printf '%s\n' 'The keyd package was not automatically removed. Remove it manually only if nothing else uses it.'
