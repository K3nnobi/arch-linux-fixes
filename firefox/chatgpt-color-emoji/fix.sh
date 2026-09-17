#!/usr/bin/env bash
set -euo pipefail

PATCH_ID="chatgpt-color-emoji"
BEGIN_CSS='/* ARCH-LINUX-FIXES-CHATGPT-EMOJI-BEGIN */'
END_CSS='/* ARCH-LINUX-FIXES-CHATGPT-EMOJI-END */'
BEGIN_JS='// ARCH-LINUX-FIXES-CHATGPT-EMOJI-BEGIN'
END_JS='// ARCH-LINUX-FIXES-CHATGPT-EMOJI-END'
FIREFOX_ROOT="${HOME}/.mozilla/firefox"
PROFILES_INI="${FIREFOX_ROOT}/profiles.ini"
BACKUP_ROOT="${HOME}/.local/share/arch-linux-fixes/backups/${PATCH_ID}"

info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
error() { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; }

find_default_profile() {
    local section="" path="" is_relative="1" is_default="0"
    local fallback=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"

        if [[ "$line" =~ ^\[Profile[0-9]+\]$ ]]; then
            if [[ -n "$path" ]]; then
                if [[ "$is_relative" == "1" ]]; then
                    fallback="${fallback:-${FIREFOX_ROOT}/${path}}"
                else
                    fallback="${fallback:-${path}}"
                fi
            fi
            section="$line"
            path=""
            is_relative="1"
            is_default="0"
            continue
        fi

        [[ -z "$section" ]] && continue

        case "$line" in
            Path=*) path="${line#Path=}" ;;
            IsRelative=*) is_relative="${line#IsRelative=}" ;;
            Default=1) is_default="1" ;;
        esac

        if [[ "$is_default" == "1" && -n "$path" ]]; then
            if [[ "$is_relative" == "1" ]]; then
                printf '%s\n' "${FIREFOX_ROOT}/${path}"
            else
                printf '%s\n' "$path"
            fi
            return 0
        fi
    done < "$PROFILES_INI"

    if [[ -n "$path" ]]; then
        if [[ "$is_relative" == "1" ]]; then
            fallback="${fallback:-${FIREFOX_ROOT}/${path}}"
        else
            fallback="${fallback:-${path}}"
        fi
    fi

    if [[ -n "$fallback" ]]; then
        printf '%s\n' "$fallback"
        return 0
    fi

    return 1
}

backup_file() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    mkdir -p "$BACKUP_ROOT"
    cp -a -- "$file" "$BACKUP_ROOT/$(basename "$file").bak"
}

replace_managed_block() {
    local file="$1" begin="$2" end="$3" block="$4"
    local tmp
    tmp="$(mktemp)"

    if [[ -f "$file" ]]; then
        awk -v begin="$begin" -v end="$end" '
            $0 == begin {skip=1; next}
            $0 == end   {skip=0; next}
            !skip       {print}
        ' "$file" > "$tmp"
    fi

    {
        cat "$tmp"
        [[ -s "$tmp" ]] && printf '\n'
        printf '%s\n' "$block"
    } > "$file"

    rm -f "$tmp"
}

if [[ ! -d "$FIREFOX_ROOT" || ! -f "$PROFILES_INI" ]]; then
    error "Firefox profile data was not found at $FIREFOX_ROOT"
    error "Start Firefox once, then run this patch again."
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    error "pacman was not found. This patch is intended for Arch Linux and Arch-based systems."
    exit 1
fi

if ! pacman -Q noto-fonts-emoji >/dev/null 2>&1; then
    info "Installing noto-fonts-emoji..."
    sudo pacman -S --needed noto-fonts-emoji
else
    ok "Noto Color Emoji package is already installed"
fi

info "Refreshing font cache..."
fc-cache -f >/dev/null
ok "Font cache refreshed"

PROFILE="$(find_default_profile || true)"
if [[ -z "$PROFILE" || ! -d "$PROFILE" ]]; then
    error "Could not detect a valid Firefox profile from $PROFILES_INI"
    exit 1
fi

ok "Firefox profile detected: $PROFILE"

CHROME_DIR="$PROFILE/chrome"
USER_CONTENT="$CHROME_DIR/userContent.css"
USER_JS="$PROFILE/user.js"
mkdir -p "$CHROME_DIR"

backup_file "$USER_CONTENT"
backup_file "$USER_JS"

CSS_BLOCK=$(cat <<'EOF'
/* ARCH-LINUX-FIXES-CHATGPT-EMOJI-BEGIN */
@-moz-document domain("chatgpt.com"), domain("chat.openai.com") {
    div[data-message-author-role="assistant"],
    div[data-message-author-role="assistant"] *,
    div[data-message-author-role="user"],
    div[data-message-author-role="user"] * {
        font-family: "OpenAI Sans", "Noto Color Emoji", "Adwaita Sans", sans-serif !important;
    }
}
/* ARCH-LINUX-FIXES-CHATGPT-EMOJI-END */
EOF
)

JS_BLOCK=$(cat <<'EOF'
// ARCH-LINUX-FIXES-CHATGPT-EMOJI-BEGIN
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// ARCH-LINUX-FIXES-CHATGPT-EMOJI-END
EOF
)

replace_managed_block "$USER_CONTENT" "$BEGIN_CSS" "$END_CSS" "$CSS_BLOCK"
replace_managed_block "$USER_JS" "$BEGIN_JS" "$END_JS" "$JS_BLOCK"

ok "ChatGPT emoji CSS rule installed"
ok "Firefox custom stylesheets enabled through user.js"

if fc-match "Noto Color Emoji" | grep -qi 'Noto.*Color.*Emoji'; then
    ok "Noto Color Emoji detected by fontconfig"
else
    warn "Noto Color Emoji was installed, but fontconfig verification was inconclusive"
fi

if pgrep -x firefox >/dev/null 2>&1; then
    warn "Firefox is currently running. Close all Firefox windows and start it again to apply the fix."
else
    info "Start Firefox to load the new configuration."
fi

printf '\nTest in ChatGPT after restart:\n'
printf '😄 😎 😂 🤔 🥰 ❤️ 🔥 👍 👌 ✅ 🚀\n'
