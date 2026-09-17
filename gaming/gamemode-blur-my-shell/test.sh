#!/usr/bin/env bash
set -Eeuo pipefail

readonly UUID='blur-my-shell@aunetx'
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly GAMEMODE_CONFIG="$CONFIG_HOME/gamemode.ini"
readonly HOOK="$HOME/.local/bin/arch-linux-fixes-gamemode-blur"
readonly BEGIN_MARKER='; BEGIN ARCH-LINUX-FIXES GAMEMODE BLUR'

info() { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
err()  { printf '[ERR ] %s\n' "$*" >&2; }

[[ "$EUID" -ne 0 ]] || { err 'Run this test as your normal user, not as root.'; exit 1; }
command -v gamemoderun >/dev/null 2>&1 || { err 'gamemoderun is unavailable.'; exit 2; }
command -v gnome-extensions >/dev/null 2>&1 || { err 'gnome-extensions is unavailable.'; exit 2; }
[[ -x "$HOOK" ]] || { err "Installed hook not found: $HOOK"; exit 3; }
[[ -f "$GAMEMODE_CONFIG" ]] || { err "GameMode config not found: $GAMEMODE_CONFIG"; exit 3; }
grep -Fxq "$BEGIN_MARKER" "$GAMEMODE_CONFIG" || { err 'Managed GameMode block is not configured. Run ./fix.sh first.'; exit 3; }

gnome-extensions list 2>/dev/null | grep -Fxq "$UUID" || { err 'Blur My Shell is not installed in this GNOME session.'; exit 4; }
gnome-extensions list --enabled 2>/dev/null | grep -Fxq "$UUID" || { err 'Enable Blur My Shell before running this test.'; exit 4; }

if command -v gamemoded >/dev/null 2>&1; then
    status="$(LC_ALL=C gamemoded -s 2>/dev/null || true)"
    if grep -Fqi 'gamemode is active' <<< "$status"; then
        err 'GameMode is already active. Close games/clients before testing.'
        exit 5
    fi
fi

# Force a deterministic config reload only while GameMode is known to be idle.
if command -v systemctl >/dev/null 2>&1 && systemctl --user cat gamemoded.service >/dev/null 2>&1; then
    systemctl --user restart gamemoded.service >/dev/null 2>&1 || true
else
    sleep 6
fi

info 'Starting a four-second GameMode test...'
gamemoderun sleep 4 &
pid=$!

disabled=0
restored=0

for _ in {1..30}; do
    if ! gnome-extensions list --enabled 2>/dev/null | grep -Fxq "$UUID"; then
        disabled=1
        break
    fi
    sleep 0.1
done

if ! wait "$pid"; then
    "$HOOK" recover >/dev/null 2>&1 || true
    err 'gamemoderun returned an error.'
    exit 6
fi

for _ in {1..30}; do
    if gnome-extensions list --enabled 2>/dev/null | grep -Fxq "$UUID"; then
        restored=1
        break
    fi
    sleep 0.1
done

if [[ "$disabled" -eq 1 && "$restored" -eq 1 ]]; then
    ok 'Blur My Shell disabled during GameMode and restored afterward.'
    exit 0
fi

"$HOOK" recover >/dev/null 2>&1 || true
[[ "$disabled" -eq 1 ]] || err 'Blur My Shell did not disable while GameMode was active.'
[[ "$restored" -eq 1 ]] || err 'Blur My Shell was not restored after GameMode ended.'
exit 7
