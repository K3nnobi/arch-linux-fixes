#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly GAMEMODE_CONFIG="$CONFIG_HOME/gamemode.ini"
readonly POLICY_FILE="$CONFIG_HOME/arch-linux-fixes/gamemode-blur/extensions.conf"
readonly HOOK="$HOME/.local/bin/arch-linux-fixes-gamemode-blur"
readonly STATE_DIR="$HOME/.local/state/arch-linux-fixes/gamemode-blur"
readonly HOOK_BACKUP="$STATE_DIR/helper.before"
readonly STATE_FILE="$STATE_DIR/install-state"
readonly BEGIN_MARKER='; BEGIN ARCH-LINUX-FIXES GAMEMODE BLUR'
readonly END_MARKER='; END ARCH-LINUX-FIXES GAMEMODE BLUR'
readonly POLICY_BEGIN='# BEGIN ARCH-LINUX-FIXES GAMEMODE BLUR DEFAULT'
readonly POLICY_END='# END ARCH-LINUX-FIXES GAMEMODE BLUR DEFAULT'

info() { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err()  { printf '[ERR ] %s\n' "$*" >&2; }

[[ "$EUID" -ne 0 ]] || { err 'Run this script as your normal user, not as root.'; exit 1; }

had_hook=0
if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
fi

if [[ -x "$HOOK" ]]; then
    info 'Attempting to restore any pending GNOME extension state...'
    "$HOOK" recover || warn 'A pending extension state could not be fully restored.'
fi

remove_block() {
    local file="$1" begin="$2" end="$3"
    [[ -f "$file" ]] || return 0

    local tmp
    tmp="$(mktemp "$(dirname "$file")/.rollback.XXXXXX")"
    awk -v begin="$begin" -v end="$end" '
        $0 == begin { inside=1; next }
        $0 == end   { inside=0; next }
        !inside { print }
    ' "$file" > "$tmp"

    # Trim trailing blank lines without touching unrelated content.
    awk '
        { lines[NR]=$0 }
        END {
            n=NR
            while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--
            for (i=1; i<=n; i++) print lines[i]
        }
    ' "$tmp" > "$tmp.trimmed"
    mv "$tmp.trimmed" "$tmp"

    if [[ ! -s "$tmp" ]]; then
        rm -f -- "$file" "$tmp"
    else
        chmod --reference="$file" "$tmp" 2>/dev/null || chmod 600 "$tmp"
        mv -- "$tmp" "$file"
    fi
}

if [[ -f "$GAMEMODE_CONFIG" ]] && grep -Fxq "$BEGIN_MARKER" "$GAMEMODE_CONFIG"; then
    info 'Removing the managed GameMode block...'
    remove_block "$GAMEMODE_CONFIG" "$BEGIN_MARKER" "$END_MARKER"
fi

if [[ -f "$POLICY_FILE" ]] && grep -Fxq "$POLICY_BEGIN" "$POLICY_FILE"; then
    info 'Removing the managed default extension policy block...'
    remove_block "$POLICY_FILE" "$POLICY_BEGIN" "$POLICY_END"
fi

if [[ "${had_hook:-0}" -eq 1 ]]; then
    if [[ -f "$HOOK_BACKUP" ]]; then
        info 'Restoring the helper that existed before this patch...'
        install -m 0755 "$HOOK_BACKUP" "$HOOK"
    else
        err "Pre-existing helper backup is missing: $HOOK_BACKUP"
        exit 2
    fi
else
    if [[ -f "$HOOK" ]]; then
        if grep -Fq 'Arch Linux Fixes GameMode' "$HOOK"; then
            info 'Removing the helper created by this patch...'
            rm -f -- "$HOOK"
        else
            warn 'Current helper does not look like the file created by this patch; leaving it untouched.'
        fi
    fi
fi

ok 'GameMode + Blur My Shell managed integration removed.'
printf '%s\n' 'GameMode packages were intentionally left installed.'
