#!/usr/bin/env bash
set -euo pipefail

BEGIN_CSS='/* ARCH-LINUX-FIXES-CHATGPT-EMOJI-BEGIN */'
END_CSS='/* ARCH-LINUX-FIXES-CHATGPT-EMOJI-END */'
BEGIN_JS='// ARCH-LINUX-FIXES-CHATGPT-EMOJI-BEGIN'
END_JS='// ARCH-LINUX-FIXES-CHATGPT-EMOJI-END'
FIREFOX_ROOT="${HOME}/.mozilla/firefox"
PROFILES_INI="${FIREFOX_ROOT}/profiles.ini"

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

    [[ -n "$fallback" ]] && printf '%s\n' "$fallback"
}

remove_managed_block() {
    local file="$1" begin="$2" end="$3"
    local tmp
    [[ -f "$file" ]] || return 0

    tmp="$(mktemp)"
    awk -v begin="$begin" -v end="$end" '
        $0 == begin {skip=1; next}
        $0 == end   {skip=0; next}
        !skip       {print}
    ' "$file" > "$tmp"

    mv "$tmp" "$file"
}

if [[ ! -f "$PROFILES_INI" ]]; then
    error "Firefox profile data was not found."
    exit 1
fi

PROFILE="$(find_default_profile || true)"
if [[ -z "$PROFILE" || ! -d "$PROFILE" ]]; then
    error "Could not detect a valid Firefox profile."
    exit 1
fi

USER_CONTENT="$PROFILE/chrome/userContent.css"
USER_JS="$PROFILE/user.js"

remove_managed_block "$USER_CONTENT" "$BEGIN_CSS" "$END_CSS"
remove_managed_block "$USER_JS" "$BEGIN_JS" "$END_JS"

ok "Managed ChatGPT emoji CSS block removed"
ok "Managed Firefox stylesheet preference removed"

warn "The package noto-fonts-emoji was not removed because it may be used by other applications."

if pgrep -x firefox >/dev/null 2>&1; then
    warn "Firefox is currently running. Restart Firefox to complete the rollback."
else
    info "Rollback complete."
fi
