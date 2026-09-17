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

[[ -f /etc/arch-release ]] || { err 'This script requires Arch Linux.'; exit 1; }
[[ "$EUID" -ne 0 ]] || { err 'Run this script as your normal user, not as root.'; exit 1; }

mkdir -p "$STATE_DIR"

if sudo test -f "$CONFIG" && sudo grep -q "$MARKER" "$CONFIG"; then
    ok 'Caps Lock no-delay patch is already installed.'
    exit 0
fi

# Never replace an existing Caps Lock mapping automatically.
if sudo test -f "$CONFIG" && sudo grep -Eq '^[[:space:]]*caps(lock)?[[:space:]]*=' "$CONFIG"; then
    err "A Caps Lock mapping already exists in $CONFIG."
    err 'No changes were made. Review the existing keyd configuration manually.'
    exit 2
fi

had_config=0
if sudo test -f "$CONFIG"; then
    had_config=1
    info "Saving existing keyd configuration to $BACKUP"
    sudo cat "$CONFIG" > "$BACKUP"
    chmod 600 "$BACKUP"
fi

keyd_was_installed=0
if pacman -Q keyd >/dev/null 2>&1; then
    keyd_was_installed=1
fi

keyd_was_enabled=0
if systemctl is-enabled keyd >/dev/null 2>&1; then
    keyd_was_enabled=1
fi

keyd_was_active=0
if systemctl is-active keyd >/dev/null 2>&1; then
    keyd_was_active=1
fi

cat > "$STATE_FILE" <<EOF
had_config=$had_config
keyd_was_installed=$keyd_was_installed
keyd_was_enabled=$keyd_was_enabled
keyd_was_active=$keyd_was_active
EOF
chmod 600 "$STATE_FILE"

info 'Installing keyd if needed...'
sudo pacman -S --needed keyd
sudo mkdir -p /etc/keyd

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

if [[ "$had_config" -eq 0 ]]; then
    cat > "$tmp" <<'EOF'
[global]
# ARCH_LINUX_FIXES_CAPSLOCK_NODELAY_GLOBAL_BEGIN
macro_timeout = 600000
# ARCH_LINUX_FIXES_CAPSLOCK_NODELAY_GLOBAL_END

[ids]
*

[main]
# ARCH_LINUX_FIXES_CAPSLOCK_NODELAY_MAIN_BEGIN
capslock = macro(capslock)
# ARCH_LINUX_FIXES_CAPSLOCK_NODELAY_MAIN_END
EOF
else
    sudo cat "$CONFIG" > "$tmp.original"

    # Insert managed settings into existing sections, creating sections only when absent.
    awk '
    BEGIN {
        in_global=0; in_main=0;
        saw_global=0; saw_main=0;
        global_done=0; main_done=0;
        saw_macro_timeout=0;
    }
    function close_global() {
        if (in_global && !global_done && !saw_macro_timeout) {
            print "# ARCH_LINUX_FIXES_CAPSLOCK_NODELAY_GLOBAL_BEGIN";
            print "macro_timeout = 600000";
            print "# ARCH_LINUX_FIXES_CAPSLOCK_NODELAY_GLOBAL_END";
            global_done=1;
        }
        in_global=0;
    }
    function close_main() {
        if (in_main && !main_done) {
            print "# ARCH_LINUX_FIXES_CAPSLOCK_NODELAY_MAIN_BEGIN";
            print "capslock = macro(capslock)";
            print "# ARCH_LINUX_FIXES_CAPSLOCK_NODELAY_MAIN_END";
            main_done=1;
        }
        in_main=0;
    }
    /^\[[^]]+\][[:space:]]*$/ {
        close_global();
        close_main();
        if ($0 ~ /^\[global\][[:space:]]*$/) { in_global=1; saw_global=1; saw_macro_timeout=0; }
        if ($0 ~ /^\[main\][[:space:]]*$/)   { in_main=1; saw_main=1; }
        print;
        next;
    }
    {
        if (in_global && $0 ~ /^[[:space:]]*macro_timeout[[:space:]]*=/) saw_macro_timeout=1;
        print;
    }
    END {
        close_global();
        close_main();
        if (!saw_global) {
            print "";
            print "[global]";
            print "# ARCH_LINUX_FIXES_CAPSLOCK_NODELAY_GLOBAL_BEGIN";
            print "macro_timeout = 600000";
            print "# ARCH_LINUX_FIXES_CAPSLOCK_NODELAY_GLOBAL_END";
        }
        if (!saw_main) {
            print "";
            print "[main]";
            print "# ARCH_LINUX_FIXES_CAPSLOCK_NODELAY_MAIN_BEGIN";
            print "capslock = macro(capslock)";
            print "# ARCH_LINUX_FIXES_CAPSLOCK_NODELAY_MAIN_END";
        }
    }
    ' "$tmp.original" > "$tmp"
    rm -f "$tmp.original"
fi

sudo install -m 0644 "$tmp" "$CONFIG"

info 'Enabling and starting keyd...'
sudo systemctl enable --now keyd
sudo keyd reload || sudo systemctl restart keyd

if ! sudo grep -q 'capslock = macro(capslock)' "$CONFIG"; then
    err 'Verification failed: Caps Lock rule was not found.'
    exit 3
fi

ok 'Caps Lock no-delay patch installed.'
printf '\nTest by quickly toggling Caps Lock off and immediately typing lowercase text.\n'
