#!/usr/bin/env bash
set -Eeuo pipefail

THUMB_DIR="$HOME/.local/share/thumbnailers"
THUMB_FILE="$THUMB_DIR/exe-thumbnailer.thumbnailer"
GTK_DIR="$HOME/.config/gtk-4.0"
GTK_FILE="$GTK_DIR/gtk.css"
STATE_DIR="$HOME/.local/state/arch-linux-fixes/nautilus-exe-thumbnails"
THUMB_BACKUP="$STATE_DIR/exe-thumbnailer.thumbnailer.before"
STATE_FILE="$STATE_DIR/state"
THUMB_MARKER='ARCH_LINUX_FIXES_EXE_THUMBNAILER'
CSS_BEGIN='/* ARCH_LINUX_FIXES_NAUTILUS_TRANSPARENT_THUMBNAILS_BEGIN */'
CSS_END='/* ARCH_LINUX_FIXES_NAUTILUS_TRANSPARENT_THUMBNAILS_END */'

info() { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
err()  { printf '[ERR ] %s\n' "$*" >&2; }

[[ -f /etc/arch-release ]] || { err 'This script requires Arch Linux.'; exit 1; }
[[ "$EUID" -ne 0 ]] || { err 'Run this script as your normal user, not as root.'; exit 1; }

info 'Installing official dependencies...'
sudo pacman -S --needed python-pillow icoutils

if ! command -v exe-thumbnailer >/dev/null 2>&1; then
    err 'exe-thumbnailer was not found.'
    err 'Install icoextract from the AUR first, for example: yay -S icoextract'
    exit 2
fi

mkdir -p "$THUMB_DIR" "$GTK_DIR" "$STATE_DIR"
chmod 700 "$STATE_DIR"

authored_thumb=0
if [[ -f "$THUMB_FILE" ]] && grep -q "$THUMB_MARKER" "$THUMB_FILE"; then
    authored_thumb=1
fi

# Save pre-patch state only on the first installation. Re-running the patch
# must not replace the user's original thumbnailer backup.
if [[ "$authored_thumb" -eq 0 ]]; then
    had_thumb=0
    if [[ -f "$THUMB_FILE" ]]; then
        had_thumb=1
        cp -a "$THUMB_FILE" "$THUMB_BACKUP"
        chmod 600 "$THUMB_BACKUP"
        info "Backed up existing thumbnailer registration to: $THUMB_BACKUP"
    else
        rm -f "$THUMB_BACKUP"
    fi

    gtk_existed=0
    [[ -f "$GTK_FILE" ]] && gtk_existed=1

    cat > "$STATE_FILE" <<EOF
had_thumb=$had_thumb
gtk_existed=$gtk_existed
EOF
    chmod 600 "$STATE_FILE"
else
    [[ -f "$STATE_FILE" ]] || {
        err 'Managed thumbnailer exists, but rollback state is missing.'
        err 'Refusing to continue because the original state cannot be reconstructed safely.'
        exit 3
    }
fi

cat > "$THUMB_FILE" <<EOF
# $THUMB_MARKER
[Thumbnailer Entry]
TryExec=exe-thumbnailer
Exec=exe-thumbnailer -s %s %i %o
MimeType=application/x-ms-dos-executable;application/x-msdownload;application/vnd.microsoft.portable-executable;application/x-dosexec;application/x-wine-extension-exe;
EOF

# Add the CSS only once. Existing GTK customizations are preserved.
touch "$GTK_FILE"
if ! grep -Fq "$CSS_BEGIN" "$GTK_FILE"; then
    cat >> "$GTK_FILE" <<EOF

$CSS_BEGIN
.nautilus-window.view .thumbnail {
    background: none;
    box-shadow: none;
}
$CSS_END
EOF
fi

info 'Clearing the user thumbnail cache so Nautilus can regenerate thumbnails...'
mkdir -p "$HOME/.cache/thumbnails"
find "$HOME/.cache/thumbnails" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true

ok 'Nautilus Windows EXE thumbnail configuration installed.'
printf '%s\n' 'If Nautilus is open, close and reopen it to load the new thumbnailer configuration.'
