#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly GAMEMODE_CONFIG="$CONFIG_HOME/gamemode.ini"
readonly POLICY_DIR="$CONFIG_HOME/arch-linux-fixes/gamemode-blur"
readonly POLICY_FILE="$POLICY_DIR/extensions.conf"
readonly BIN_DIR="$HOME/.local/bin"
readonly INSTALLED_HOOK="$BIN_DIR/arch-linux-fixes-gamemode-blur"
readonly STATE_DIR="$HOME/.local/state/arch-linux-fixes/gamemode-blur"
readonly CONFIG_BACKUP="$STATE_DIR/gamemode.ini.before"
readonly HOOK_BACKUP="$STATE_DIR/helper.before"
readonly STATE_FILE="$STATE_DIR/install-state"
readonly BEGIN_MARKER='; BEGIN ARCH-LINUX-FIXES GAMEMODE BLUR'
readonly END_MARKER='; END ARCH-LINUX-FIXES GAMEMODE BLUR'
readonly POLICY_BEGIN='# BEGIN ARCH-LINUX-FIXES GAMEMODE BLUR DEFAULT'
readonly POLICY_END='# END ARCH-LINUX-FIXES GAMEMODE BLUR DEFAULT'
readonly DEFAULT_EXTENSION='blur-my-shell@aunetx'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SOURCE_HOOK="$SCRIPT_DIR/gamemode-blur.sh"

info() { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err()  { printf '[ERR ] %s\n' "$*" >&2; }

[[ -f /etc/arch-release ]] || { err 'This script requires Arch Linux.'; exit 1; }
[[ "$EUID" -ne 0 ]] || { err 'Run this script as your normal user, not as root.'; exit 1; }
[[ -f "$SOURCE_HOOK" && ! -L "$SOURCE_HOOK" ]] || { err "Runtime hook not found: $SOURCE_HOOK"; exit 2; }

if [[ -L "$CONFIG_HOME" || -L "$GAMEMODE_CONFIG" || -L "$POLICY_DIR" || -L "$POLICY_FILE" ]]; then
    err 'A symbolic-link configuration target was detected. Refusing to modify it automatically.'
    exit 3
fi

mkdir -p "$CONFIG_HOME" "$POLICY_DIR" "$BIN_DIR" "$STATE_DIR"
chmod 700 "$STATE_DIR" 2>/dev/null || true

managed=0
if [[ -f "$GAMEMODE_CONFIG" ]] && grep -Fxq "$BEGIN_MARKER" "$GAMEMODE_CONFIG"; then
    managed=1
fi

if [[ "$managed" -eq 0 && ! -f "$STATE_FILE" ]]; then
    had_config=0
    had_hook=0

    if [[ -f "$GAMEMODE_CONFIG" ]]; then
        had_config=1
        cp -a -- "$GAMEMODE_CONFIG" "$CONFIG_BACKUP"
        chmod 600 "$CONFIG_BACKUP" 2>/dev/null || true
    fi

    if [[ -e "$INSTALLED_HOOK" ]]; then
        [[ -f "$INSTALLED_HOOK" && ! -L "$INSTALLED_HOOK" ]] || {
            err "Unsafe existing helper path refused: $INSTALLED_HOOK"
            exit 4
        }
        had_hook=1
        cp -a -- "$INSTALLED_HOOK" "$HOOK_BACKUP"
        chmod 600 "$HOOK_BACKUP" 2>/dev/null || true
    fi

    cat > "$STATE_FILE" <<EOF
had_config=$had_config
had_hook=$had_hook
EOF
    chmod 600 "$STATE_FILE"
fi

info 'Installing GameMode packages if needed...'
if ! sudo pacman -S --needed gamemode lib32-gamemode; then
    err 'GameMode packages could not be installed.'
    err 'If lib32-gamemode is unavailable, verify that the multilib repository is enabled.'
    exit 5
fi

if ! command -v gnome-extensions >/dev/null 2>&1; then
    warn 'gnome-extensions is currently unavailable. The integration can be installed, but cannot be tested in this session.'
elif ! gnome-extensions list 2>/dev/null | grep -Fxq "$DEFAULT_EXTENSION"; then
    warn 'Blur My Shell is not installed in this GNOME session. The hook will remain ready if it is installed later.'
fi

info "Installing runtime hook to: $INSTALLED_HOOK"
install -m 0755 "$SOURCE_HOOK" "$INSTALLED_HOOK"

# Add a managed default extension entry without overwriting user policy.
touch "$POLICY_FILE"
if ! grep -Fxq "$POLICY_BEGIN" "$POLICY_FILE"; then
    cat >> "$POLICY_FILE" <<EOF

$POLICY_BEGIN
$DEFAULT_EXTENSION
$POLICY_END
EOF
fi
chmod 600 "$POLICY_FILE" 2>/dev/null || true

strip_managed_block() {
    local source="$1" destination="$2"
    awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
        $0 == begin { inside=1; next }
        $0 == end   { inside=0; next }
        !inside {
            # Remove only the exact legacy ArchMind prototype helper entries.
            if ($0 ~ /^[[:space:]]*(start|end)[[:space:]]*=/ &&
                $0 ~ /\/\.local\/bin\/gamemode-blur[[:space:]]+(start|end)[[:space:]]*$/) {
                next
            }
            lines[++count]=$0
        }
        END {
            while (count > 0 && lines[count] ~ /^[[:space:]]*$/) count--
            for (i=1; i<=count; i++) print lines[i]
        }
    ' "$source" > "$destination"
}

shell_quote() {
    local value="$1"
    value=${value//\'/\'\\\'\'}
    printf "'%s'" "$value"
}

tmp="$(mktemp "$CONFIG_HOME/.gamemode.ini.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

if [[ -f "$GAMEMODE_CONFIG" ]]; then
    strip_managed_block "$GAMEMODE_CONFIG" "$tmp"
    chmod --reference="$GAMEMODE_CONFIG" "$tmp" 2>/dev/null || chmod 600 "$tmp"
else
    : > "$tmp"
    chmod 600 "$tmp"
fi

quoted_hook="$(shell_quote "$INSTALLED_HOOK")"
cat >> "$tmp" <<EOF

$BEGIN_MARKER
[custom]
start=$quoted_hook start
end=$quoted_hook end
$END_MARKER
EOF

if [[ ! -f "$GAMEMODE_CONFIG" ]] || ! cmp -s "$tmp" "$GAMEMODE_CONFIG"; then
    mv -- "$tmp" "$GAMEMODE_CONFIG"
    trap - EXIT
fi

ok 'GameMode + Blur My Shell integration configured.'
printf '\nSteam launch option for games that do not request GameMode themselves:\n\n'
printf '  gamemoderun %%command%%\n\n'
printf 'Before relying on it, close active games and run:\n\n'
printf '  %s/test.sh\n' "$SCRIPT_DIR"
