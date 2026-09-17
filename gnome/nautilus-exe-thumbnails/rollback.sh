#!/usr/bin/env bash
set -Eeuo pipefail

THUMB_FILE="$HOME/.local/share/thumbnailers/exe-thumbnailer.thumbnailer"
GTK_FILE="$HOME/.config/gtk-4.0/gtk.css"
STATE_DIR="$HOME/.local/state/arch-linux-fixes/nautilus-exe-thumbnails"
THUMB_BACKUP="$STATE_DIR/exe-thumbnailer.thumbnailer.before"
STATE_FILE="$STATE_DIR/state"
THUMB_MARKER='ARCH_LINUX_FIXES_EXE_THUMBNAILER'
CSS_BEGIN='/* ARCH_LINUX_FIXES_NAUTILUS_TRANSPARENT_THUMBNAILS_BEGIN */'
CSS_END='/* ARCH_LINUX_FIXES_NAUTILUS_TRANSPARENT_THUMBNAILS_END */'

info() { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
err()  { printf '[ERR ] %s\n' "$*" >&2; }

[[ "$EUID" -ne 0 ]] || { err 'Run this script as your normal user, not as root.'; exit 1; }
[[ -f "$STATE_FILE" ]] || { err "Rollback state not found: $STATE_FILE"; exit 2; }

# shellcheck disable=SC1090
source "$STATE_FILE"

if [[ -f "$THUMB_FILE" ]] && ! grep -q "$THUMB_MARKER" "$THUMB_FILE"; then
    err 'The current exe-thumbnailer.thumbnailer is not managed by this patch.'
    err 'Refusing to overwrite or delete it.'
    exit 3
fi

if [[ "${had_thumb:-0}" -eq 1 ]]; then
    [[ -f "$THUMB_BACKUP" ]] || { err "Original thumbnailer backup not found: $THUMB_BACKUP"; exit 4; }
    info 'Restoring the pre-patch thumbnailer registration...'
    mkdir -p "$(dirname "$THUMB_FILE")"
    cp -a "$THUMB_BACKUP" "$THUMB_FILE"
else
    info 'Removing the thumbnailer registration created by this patch...'
    rm -f "$THUMB_FILE"
fi

if [[ -f "$GTK_FILE" ]] && grep -Fq "$CSS_BEGIN" "$GTK_FILE"; then
    info 'Removing the managed GTK CSS block...'
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    awk -v begin="$CSS_BEGIN" -v end="$CSS_END" '
        $0 == begin { skip=1; next }
        $0 == end   { skip=0; next }
        !skip { print }
    ' "$GTK_FILE" > "$tmp"
    cat "$tmp" > "$GTK_FILE"

    if [[ "${gtk_existed:-1}" -eq 0 ]] && ! grep -q '[^[:space:]]' "$GTK_FILE"; then
        rm -f "$GTK_FILE"
    fi
fi

info 'Clearing the user thumbnail cache so Nautilus can regenerate thumbnails...'
mkdir -p "$HOME/.cache/thumbnails"
find "$HOME/.cache/thumbnails" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true

ok 'Nautilus EXE thumbnail rollback completed.'
printf '%s\n' 'If Nautilus is open, close and reopen it. Installed packages were not removed.'
