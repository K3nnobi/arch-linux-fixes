#!/usr/bin/env bash
set -Eeuo pipefail

MODE="${1:---install}"
PACKAGE="gnome-rounded-blur"
EXT_UUID="blur-my-shell@aunetx"
ROUNDED_BLUR_KEY='/org/gnome/shell/extensions/blur-my-shell/rounded-blur-found'
STATE_DIR="$HOME/.local/state/arch-linux-fixes/blur-my-shell-rounded-corners"
STATE_FILE="$STATE_DIR/state"

info() { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err()  { printf '[ERR ] %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: ./fix.sh [--install|--rebuild|--check]

  --install   Install gnome-rounded-blur from the AUR (default)
  --rebuild   Rebuild/reinstall it after GNOME Shell or Mutter updates
  --check     Check package and Blur My Shell detection state
EOF
}

[[ -f /etc/arch-release ]] || { err 'This script requires Arch Linux.'; exit 1; }
[[ "$EUID" -ne 0 ]] || { err 'Run this script as your normal user, not as root.'; exit 1; }

command -v gnome-shell >/dev/null 2>&1 || {
    err 'GNOME Shell was not found.'
    exit 2
}

if ! command -v gnome-extensions >/dev/null 2>&1; then
    err 'gnome-extensions was not found.'
    exit 2
fi

if ! gnome-extensions info "$EXT_UUID" >/dev/null 2>&1; then
    err 'Blur My Shell is not installed for this user/system.'
    err "Expected extension UUID: $EXT_UUID"
    exit 3
fi

helper=''
if command -v yay >/dev/null 2>&1; then
    helper='yay'
elif command -v paru >/dev/null 2>&1; then
    helper='paru'
fi

check_state() {
    local detected=''

    if pacman -Q "$PACKAGE" >/dev/null 2>&1; then
        ok "$PACKAGE is installed."
    else
        warn "$PACKAGE is not installed."
        return 1
    fi

    if command -v dconf >/dev/null 2>&1; then
        detected="$(dconf read "$ROUNDED_BLUR_KEY" 2>/dev/null || true)"
        if [[ "$detected" == 'true' ]]; then
            ok 'Blur My Shell detected rounded blur support.'
            printf 'rounded-blur-found=true\n'
            return 0
        fi

        warn "Blur My Shell has not detected rounded blur yet: ${detected:-unset}"
        warn 'Log out and back in, then run ./fix.sh --check again.'
        return 2
    fi

    warn 'dconf is unavailable, so Blur My Shell detection could not be checked.'
    return 2
}

case "$MODE" in
    --check)
        check_state
        exit $?
        ;;
    --install|--rebuild)
        ;;
    --help|-h)
        usage
        exit 0
        ;;
    *)
        usage
        exit 64
        ;;
esac

[[ -n "$helper" ]] || {
    err 'No supported AUR helper was found.'
    err 'Install yay or paru first, then run this script again.'
    exit 4
}

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

if [[ ! -f "$STATE_FILE" ]]; then
    was_installed=0
    pacman -Q "$PACKAGE" >/dev/null 2>&1 && was_installed=1

    cat > "$STATE_FILE" <<EOF
package_was_installed=$was_installed
EOF
    chmod 600 "$STATE_FILE"
fi

if [[ "$MODE" == '--rebuild' ]]; then
    info "Rebuilding $PACKAGE with $helper..."
    "$helper" -S --rebuild --needed "$PACKAGE"
else
    info "Installing $PACKAGE with $helper..."
    "$helper" -S --needed "$PACKAGE"
fi

pacman -Q "$PACKAGE" >/dev/null 2>&1 || {
    err "$PACKAGE was not installed successfully."
    exit 5
}

ok "$PACKAGE is installed."

if check_state; then
    ok 'Rounded dynamic blur support is ready.'
else
    warn 'Installation completed, but GNOME Shell may need to reload the library.'
fi

printf '\n%s\n' 'Log out and back in to GNOME, then run: ./fix.sh --check'
