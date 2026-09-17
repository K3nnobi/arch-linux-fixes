#!/usr/bin/env bash
set -Eeuo pipefail

VALUE="${1:-512}"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE="$SERVICE_DIR/nvibrant.service"
STATE_DIR="$HOME/.local/state/arch-linux-fixes/nvibrant-autoload"
BACKUP="$STATE_DIR/nvibrant.service.before"
STATE_FILE="$STATE_DIR/state"
MARKER='ARCH_LINUX_FIXES_NVIBRANT_AUTOLOAD'

info() { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
err()  { printf '[ERR ] %s\n' "$*" >&2; }

[[ -f /etc/arch-release ]] || { err 'This script requires Arch Linux.'; exit 1; }
[[ "$EUID" -ne 0 ]] || { err 'Run this script as your normal user, not as root.'; exit 1; }

[[ "$VALUE" =~ ^[0-9]+$ ]] || { err 'Intensity must be an integer from 0 to 1023.'; exit 2; }
(( VALUE >= 0 && VALUE <= 1023 )) || { err 'Intensity must be between 0 and 1023.'; exit 2; }

if ! command -v nvibrant >/dev/null 2>&1; then
    err 'nvibrant is not installed.'
    err 'Install it from the AUR first, for example: yay -S nvibrant'
    exit 3
fi

NVIBRANT="$(command -v nvibrant)"
NVIBRANT="$(readlink -f "$NVIBRANT")"

nvidia_found=0
if [[ -d /proc/driver/nvidia ]]; then
    nvidia_found=1
elif command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
    nvidia_found=1
elif command -v lspci >/dev/null 2>&1 && lspci -nn | grep -qi 'NVIDIA'; then
    nvidia_found=1
fi

[[ "$nvidia_found" -eq 1 ]] || {
    err 'No NVIDIA GPU/driver was detected. No changes were made.'
    exit 4
}

mkdir -p "$SERVICE_DIR" "$STATE_DIR"
chmod 700 "$STATE_DIR"

managed_existing=0
if [[ -f "$SERVICE" ]] && grep -q "$MARKER" "$SERVICE"; then
    managed_existing=1
fi

# Preserve the state from before the first installation. Re-running this patch
# to change intensity must never replace the original backup/state.
if [[ "$managed_existing" -eq 0 ]]; then
    had_service=0
    if [[ -f "$SERVICE" ]]; then
        had_service=1
        info "Backing up existing service to: $BACKUP"
        cp -a "$SERVICE" "$BACKUP"
        chmod 600 "$BACKUP"
    else
        rm -f "$BACKUP"
    fi

    was_enabled=0
    if systemctl --user is-enabled nvibrant.service >/dev/null 2>&1; then
        was_enabled=1
    fi

    was_active=0
    if systemctl --user is-active nvibrant.service >/dev/null 2>&1; then
        was_active=1
    fi

    cat > "$STATE_FILE" <<EOF
had_service=$had_service
was_enabled=$was_enabled
was_active=$was_active
EOF
    chmod 600 "$STATE_FILE"
else
    [[ -f "$STATE_FILE" ]] || {
        err 'Managed service exists, but rollback state is missing.'
        err 'Refusing to overwrite it because the original state cannot be reconstructed safely.'
        exit 5
    }
fi

cat > "$SERVICE" <<EOF
# $MARKER
[Unit]
Description=Apply NVIDIA Digital Vibrance
After=graphical.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 5
ExecStart=$NVIBRANT $VALUE

[Install]
WantedBy=default.target
EOF

info 'Reloading the user systemd manager...'
systemctl --user daemon-reload

info "Enabling nvibrant autoload at intensity $VALUE..."
systemctl --user enable nvibrant.service >/dev/null

# Start now as a real verification of the configured command. The service is
# oneshot, so an inactive state after successful completion is normal.
if ! systemctl --user restart nvibrant.service; then
    err 'nvibrant.service failed to run.'
    err 'Inspect: journalctl --user -u nvibrant.service -b'
    exit 6
fi

ok "NVIDIA Digital Vibrance autoload configured at $VALUE."
printf '%s\n' 'The service will run automatically after future logins.'
