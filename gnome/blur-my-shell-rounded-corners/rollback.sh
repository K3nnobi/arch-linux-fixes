#!/usr/bin/env bash
set -Eeuo pipefail

PACKAGE="gnome-rounded-blur"
STATE_DIR="$HOME/.local/state/arch-linux-fixes/blur-my-shell-rounded-corners"
STATE_FILE="$STATE_DIR/state"

info() { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err()  { printf '[ERR ] %s\n' "$*" >&2; }

[[ -f /etc/arch-release ]] || { err 'This script requires Arch Linux.'; exit 1; }
[[ "$EUID" -ne 0 ]] || { err 'Run this script as your normal user, not as root.'; exit 1; }
[[ -f "$STATE_FILE" ]] || {
    err "Rollback state not found: $STATE_FILE"
    err 'Refusing to guess whether the package existed before this patch.'
    exit 2
}

# shellcheck disable=SC1090
source "$STATE_FILE"

if [[ "${package_was_installed:-1}" -eq 1 ]]; then
    ok "$PACKAGE already existed before this patch; leaving it installed."
    exit 0
fi

if ! pacman -Q "$PACKAGE" >/dev/null 2>&1; then
    ok "$PACKAGE is already absent."
    exit 0
fi

info "Removing $PACKAGE installed by this patch..."
if ! sudo pacman -Rns "$PACKAGE"; then
    err 'Pacman refused the removal. The package may now be required by something else.'
    err 'No dependency was forcibly removed.'
    exit 3
fi

ok "$PACKAGE removed."
printf '\n%s\n' 'Log out and back in so GNOME Shell reloads without the rounded blur compatibility library.'
